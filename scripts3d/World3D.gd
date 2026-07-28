extends Node3D
## 월드 루트 — 조립(composition)과 페이즈 디스패치만 담당한다.
##
## 실제 로직은 자식 매니저들이 가진다:
##   EnvironmentManager  하늘·조명·안개·후처리
##   LandmarkManager     지형·도로·건물·방주
##   PropScatterManager  소품·잔해·파티클
##   PortalManager       차원의 균열
##   SpawnManager        플레이어·적·보스 스폰
##   DayNightManager     낮/밤 전환
##   WaveManager3D       밤 웨이브 진행
##
## 외부(Enemy3D / PetManager / LootManager / 툴)가 current_scene 을 통해
## 접근하는 API 는 이 클래스에 그대로 유지된다: zone_luck, world_center,
## hud, _make_enemy, skip_* 등.

# ── 격자/구역 상수 (WorldConfig 가 단일 출처, 여기서는 외부 호환용 별칭) ──
const TILE := WorldConfig.TILE
const COLS := WorldConfig.COLS
const ROWS := WorldConfig.ROWS
const ARENA_W := WorldConfig.ARENA_W
const ARENA_H := WorldConfig.ARENA_H
const ZONE_SAFE := WorldConfig.ZONE_SAFE
const ZONE_CITY := WorldConfig.ZONE_CITY
const ZONE_RIFT := WorldConfig.ZONE_RIFT
const SAFE_RADIUS := WorldConfig.SAFE_RADIUS
const RIFT_BAND := WorldConfig.RIFT_BAND

# ── 월드가 소유하는 공유 상태 (매니저들이 참조한다) ──
var player: CharacterBody3D
var base_core: Node3D
var hud: CanvasLayer
var sun: DirectionalLight3D
var env: WorldEnvironment

var day_timer := 0.0
var night_timer := 0.0
var spawn_timer := 0.0
var game_ended := false
var occupied_cells := {}
var _placed_props: Array = []
var trait_screen: CanvasLayer = null

# ── 매니저 ──
var environment_manager: EnvironmentManager
var landmark_manager: LandmarkManager
var prop_manager: PropScatterManager
var portal_manager: PortalManager
var spawn_manager: SpawnManager
var daynight_manager: WorldSystem
var wave_manager: WorldSystem
## 캠페인 — 랜드마크/NPC/웨이브/이벤트의 유일한 생성자 (JSON 이 데이터 소스)
var campaign_manager: CampaignManager
var biome_builder: BiomeBuilder

func _ready() -> void:
	randomize()

	# 세이브를 **가장 먼저** 읽는다.
	# 챕터에 따라 지형·테마·캠페인이 전부 달라지므로, 월드를 만들기 전에
	# GameManager.chapter 가 확정돼 있어야 한다.
	# (씬을 다시 읽는 경우 — 챕터 이동·재시작 — 에는 이미 상태가 서 있으므로 건너뛴다)
	if not SaveGame.has_save and SaveGame.exists():
		SaveGame.load_game()
	set_process(true)
	SoundManager.set_master_db(SaveGame.master_db)   ## 저장된 볼륨을 되살린다

	_create_managers()

	environment_manager.setup_environment()
	landmark_manager.build_all()          ## 지형만 (랜드마크는 만들지 않는다)
	prop_manager.build_scatter_and_detail()
	landmark_manager.build_base()
	portal_manager.build_rifts()
	prop_manager.build_atmosphere()
	spawn_manager.spawn_player()
	PetManager.spawn_into_world()

	hud = load("res://scripts3d/HUD3D.gd").new()
	add_child(hud)

	# 보스 러시 진행 중이면 일반 웨이브 대신 연전을 돌린다
	if SaveGame.rush_index >= 0:
		call_deferred("_rush_begin")
		return

	# 첫 실행(세이브 없음)이면 타이틀부터 보여준다.
	# 세이브가 있으면 예전처럼 바로 이어서 시작한다 — 기존 흐름 유지.
	if not SaveGame.has_save and not SaveGame.exists():
		hud.call_deferred("show_title")

	# ── 캠페인 ──
	# HUD 이후에 만든다: 진입 배너/토스트를 이벤트가 즉시 쓸 수 있어야 한다.
	# 랜드마크·NPC·웨이브·BGM·이벤트·퀘스트 잠금이 전부 여기서 나온다.
	campaign_manager.build()

	# 지형 소품은 캠페인 **이후**에 뿌린다 —
	# 랜드마크 위치를 알아야 그 위에 나무를 심지 않는다.
	biome_builder.build_biome()

	GameManager.game_over.connect(_on_game_over)

	day_timer = DemoDirector.day_duration()
	GameManager.phase_timer = day_timer

	# 특성 뽑기 화면.
	#
	# 첫 실행에는 타이틀 메뉴도 같이 뜬다. 둘이 겹치면 입력을 서로 먹어
	# "한 번에 시작이 안 되는" 상태가 된다 — 그래서 타이틀이 떠 있으면 미뤘다가,
	# 슬롯을 고르고 메뉴가 닫힌 뒤에 띄운다.
	if GameManager.day_count == 1:
		_trait_pending = true

## 매니저를 만들어 자식으로 붙이고 월드 참조를 넘긴다.
func _create_managers() -> void:
	environment_manager = _attach(EnvironmentManager.new(), "EnvironmentManager")
	landmark_manager = _attach(LandmarkManager.new(), "LandmarkManager")
	prop_manager = _attach(PropScatterManager.new(), "PropScatterManager")
	portal_manager = _attach(PortalManager.new(), "PortalManager")
	spawn_manager = _attach(SpawnManager.new(), "SpawnManager")
	daynight_manager = _attach(DayNightManager.new(), "DayNightManager")
	wave_manager = _attach(WaveManager3D.new(), "WaveManager3D")
	campaign_manager = _attach(CampaignManager.new(), "CampaignManager")
	biome_builder = _attach(BiomeBuilder.new(), "BiomeBuilder")

	# 매니저 간 연결 — 서로를 직접 참조하지 않고 월드를 통해 찾는다
	daynight_manager.wave = wave_manager
	daynight_manager.spawner = spawn_manager
	daynight_manager.environment = environment_manager
	daynight_manager.portals = portal_manager
	wave_manager.spawner = spawn_manager
	wave_manager.daynight = daynight_manager

func _attach(node: WorldSystem, node_name: String) -> WorldSystem:
	node.name = node_name
	node.setup(self)
	add_child(node)
	return node

## 타이틀이 닫힌 뒤에만 특성 화면을 띄운다.
##
## 예전에는 아직 열려 있으면 call_deferred 로 자기 자신을 다시 걸었다.
## 지연 호출은 같은 프레임 안에서 계속 비워지므로 **한 프레임에 무한히 반복**되어
## 엔진이 그대로 죽었다(디버거 메시지 없이 프로세스 종료).
## 프레임 단위로 확인하려면 _process 에서 봐야 한다.
var _trait_pending := false

func _tick_trait_screen() -> void:
	if not _trait_pending:
		return
	if hud == null or not is_instance_valid(hud):
		return
	if hud.get("menu_ui") != null and hud.menu_ui.is_open():
		return          ## 타이틀이 아직 떠 있다 — 다음 프레임에 다시 본다
	_trait_pending = false
	trait_screen = load("res://scripts3d/TraitScreen.gd").new()
	add_child(trait_screen)
	trait_screen.started.connect(_on_trait_screen_done)

func _on_trait_screen_done() -> void:
	trait_screen = null
	hud.show_tutorial()

# ── 공개 API (외부 코드가 current_scene 으로 호출한다. 시그니처 유지 필수) ──
func world_center() -> Vector3:
	return WorldConfig.world_center()

func zone_of(pos: Vector3) -> int:
	return WorldConfig.zone_of(pos)

## 구역별 드랍 운(luck) 보정 — Enemy3D 가 호출한다.
func zone_luck(pos: Vector3) -> float:
	return WorldConfig.zone_luck(pos)

func _make_enemy(etype: String, pos: Vector3) -> Node:
	return spawn_manager.make_enemy(etype, pos)

func _spawn_enemy() -> void:
	spawn_manager.spawn_enemy()

func _start_night_phase() -> void:
	daynight_manager.start_night_phase()

func _end_night_phase() -> void:
	daynight_manager.end_night_phase()

func skip_day() -> bool:
	return daynight_manager.skip_day()

func skip_rest() -> void:
	wave_manager.skip_rest()

func skip_night() -> bool:
	return wave_manager.skip_night()

# ── 입력 / 루프 ──
func _unhandled_input(event: InputEvent) -> void:
	if game_ended or GameManager.game_won:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_N:
			skip_rest()
		KEY_K:
			skip_night()
		KEY_J:
			skip_day()
		KEY_P:
			var t: String = PetManager.cycle()
			if t != "":
				var info: Dictionary = PetManager.get_info(t)
				hud.show_toast("동행: %s" % String(info.get("name", t)), Color(1, 0.9, 0.5))

func _process(delta: float) -> void:
	_tick_trait_screen()
	# 회차 누적 시간 — 스피드런 챌린지 판정. 저장은 기존 저장 지점에서 함께 된다.
	if not GameManager.game_won:
		SaveGame.run_seconds += delta
	if game_ended:
		return
	if trait_screen != null and is_instance_valid(trait_screen):
		return
	# 보스 러시 중에는 낮/밤 진행 대신 연전 루틴을 돌린다
	if SaveGame.rush_index >= 0:
		_rush_process(delta)
		return
	if GameManager.phase == GameManager.Phase.DAY:
		daynight_manager.process_day(delta)
	else:
		wave_manager.process_night(delta)

func _on_game_over(reason: String) -> void:
	if game_ended:
		return
	game_ended = true
	if is_instance_valid(player):
		player.set_physics_process(false)
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.set_physics_process(false)
	hud.show_game_over(reason)

# ══════════════════════════════════════════════
#  보스 러시 — data/endgame.json 의 order 를 순서대로 1대1
#  새 씬을 만들지 않는다. 기존 월드 위에서 보스만 갈아 끼운다.
# ══════════════════════════════════════════════
var rush_timer := 0.0
var _rush_boss: Node = null

func _rush_begin() -> void:
	GameManager.phase = GameManager.Phase.NIGHT
	GameManager.phase_timer = 9999.0
	night_timer = 9999.0
	set_process(true)
	if hud:
		hud.show_banner("◈ 보스 러시  —  %d 보스" % SaveGame.boss_rush_order().size())
	_rush_spawn()

func _rush_conf() -> Dictionary:
	return SaveGame.endgame().get("boss_rush", {})

func _rush_spawn() -> void:
	var order: Array = SaveGame.boss_rush_order()
	var i: int = SaveGame.rush_index
	if i < 0 or i >= order.size():
		_rush_finish(true)
		return

	var btype := String(order[i])
	var pos: Vector3 = world_center() + Vector3(0, 0, -12.0)
	_rush_boss = _make_enemy(btype, pos)
	if _rush_boss == null:
		_rush_finish(false)
		return
	_rush_boss.max_hp *= float(_rush_conf().get("hp_mult", 0.85))
	_rush_boss.hp = _rush_boss.max_hp

	if hud:
		var d := EnemyConfig.boss_def(btype)
		hud.show_banner("%s  —  %s" % [
			String(d.get("name", btype)),
			hud.menu_ui.txt("rush_progress", "보스 %d / %d") % [i + 1, order.size()]])
	CombatFeel.impact("boss_phase")

func _rush_process(delta: float) -> void:
	# 보스가 살아 있으면 진행도만 갱신한다
	if _rush_boss != null and is_instance_valid(_rush_boss) and not _rush_boss.dead:
		hud.wave_label.text = hud.menu_ui.txt("rush_progress", "보스 %d / %d") \
			% [SaveGame.rush_index + 1, SaveGame.boss_rush_order().size()]
		return

	# 플레이어가 죽었으면 실패
	if Battlefield.live_player() == null:
		_rush_finish(false)
		return

	# 처치 직후 — 휴식 타이머를 돌리고 회복시킨 뒤 다음 보스
	if _rush_boss != null:
		_rush_boss = null
		SaveGame.rush_index += 1
		rush_timer = float(_rush_conf().get("rest", 6.0))
		var pl := Battlefield.live_player()
		var heal := float(_rush_conf().get("heal_between", 0.5))
		if pl and heal > 0.0:
			pl.hp = minf(pl.max_hp, pl.hp + pl.max_hp * heal)
			pl.hp_changed.emit()
		CraftManager.add_essence(int(_rush_conf().get("essence", 60)))
		SaveGame.note_boss_rush(SaveGame.rush_index)
		if SaveGame.rush_index >= SaveGame.boss_rush_order().size():
			_rush_finish(true)
			return

	if rush_timer > 0.0:
		rush_timer -= delta
		hud.timer_label.text = hud.menu_ui.txt("rush_next", "다음 보스까지 %d초") \
			% int(ceil(rush_timer))
		if rush_timer <= 0.0:
			_rush_spawn()

func _rush_finish(cleared: bool) -> void:
	var total: int = SaveGame.boss_rush_order().size()
	var done: int = clampi(SaveGame.rush_index, 0, total)
	SaveGame.note_boss_rush(done)
	SaveGame.rush_index = -1
	SaveGame.save()
	if hud:
		var key := "rush_clear" if cleared else "rush_fail"
		var fb := "◈ 보스 러시 완파 — %d / %d" if cleared else "보스 러시 종료 — %d / %d"
		hud.show_banner(hud.menu_ui.txt(key, fb) % [done, total])
	CombatFeel.impact("boss_death" if cleared else "hurt")
	get_tree().create_timer(3.0, true, false, true).timeout.connect(
		func(): if hud and hud.menu_ui: hud.menu_ui.open_title())
