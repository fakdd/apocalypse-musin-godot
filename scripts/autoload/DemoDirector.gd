extends Node
## 버티컬 슬라이스 디렉터 — 10~15분 데모 한 판의 흐름을 관리한다.
##
## 왜 필요한가:
##   기존 게임은 "봉인 5개 → 최종 보스"의 장기 루프라, 처음 10분만 잘라내면
##   시작도 끝도 없는 조각처럼 느껴진다. 데모는 **완결된 한 판**이어야 한다.
##
## 이 디렉터가 하는 일 (새 시스템을 만들지 않는다):
##   1) 기존 상수(낮 길이·웨이브 수·봉인 목표)를 데모 길이에 맞게 조율한다
##   2) 정해진 순간에 기존 기능(배너·토스트·보스 스폰·승리 화면)을 호출한다
##   3) 각 단계 전환을 기록해 플레이 시간을 측정할 수 있게 한다
##
## 데모 비활성화 시(DEMO_MODE=false) 게임은 원래의 장기 캠페인으로 돌아간다.

signal beat_changed(beat: int)

## 데모 진행 단계
enum Beat {
	INTRO,        ## 각성 — 특성 뽑기 화면
	TUTORIAL,     ## 조작 익히기 (안전지대)
	EXPLORE,      ## 첫 탐험 — 랜드마크 찾기
	LANDMARK,     ## 첫 랜드마크 클리어
	NIGHT_PREP,   ## 밤 예고
	WAVE,         ## 첫 웨이브
	BOSS,         ## 첫 보스
	REWARD,       ## 첫 보상 — 전리품 정산
	OUTRO,        ## 마무리 — "계속" 유도
}

const DEMO_MODE := true

## ── 데모 페이싱 (합계 10~15분) ──
## 낮 90초 + (웨이브 45초 + 정비 20초) + 웨이브 45초 + 보스 ~90초 + 정산 30초
## ≈ 5분 20초의 "정해진" 시간 + 플레이어의 자유 탐험 시간 = 실측 10~15분
const DEMO_DAY_DURATION := 90.0        ## 첫 낮: 탐험할 시간을 넉넉히
const DEMO_WAVE_DURATION := 45.0       ## 원본 32초 → 살짝 길게 (전투를 충분히 맛보게)
const DEMO_REST_DURATION := 20.0
const DEMO_WAVES_TONIGHT := 2          ## 데모는 2웨이브 뒤 바로 보스
const DEMO_SEALS_NEEDED := 1           ## 봉인 1개 = 데모 클리어 조건
const DEMO_BASE_HP := 320.0            ## 첫 플레이는 관대하게 (죽어서 끝나면 안 된다)

var beat: int = Beat.INTRO
var elapsed := 0.0
var beat_log: Array = []               ## [[beat_name, elapsed_sec], …] — 플레이타임 검증용
var boss_spawned := false
var _first_item := false
var _first_kill := false

func _ready() -> void:
	if not DEMO_MODE:
		return
	GameManager.base_max_hp = DEMO_BASE_HP
	GameManager.base_hp = DEMO_BASE_HP
	# 기존 시그널에 얹기만 한다 (새 상태 기계를 만들지 않는다)
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.night_state_changed.connect(_on_night_state_changed)
	LandmarkRegistry.landmark_explored.connect(_on_landmark_explored)
	LandmarkRegistry.landmark_cleared.connect(_on_landmark_cleared)
	LootManager.item_collected.connect(_on_item_collected)

func _process(delta: float) -> void:
	if not DEMO_MODE:
		return
	elapsed += delta

func set_beat(b: int) -> void:
	if b == beat or b < beat:
		return          ## 뒤로 가지 않는다
	beat = b
	beat_log.append([Beat.keys()[b], snappedf(elapsed, 0.1)])
	beat_changed.emit(b)

## 데모용 낮/밤 길이를 반환한다 (World3D/DayNightManager 가 물어본다)
func day_duration() -> float:
	return DEMO_DAY_DURATION if DEMO_MODE else GameManager.DAY_DURATION

func wave_duration() -> float:
	return DEMO_WAVE_DURATION if DEMO_MODE else GameManager.WAVE_DURATION

func rest_duration() -> float:
	return DEMO_REST_DURATION if DEMO_MODE else GameManager.REST_DURATION

func waves_tonight() -> int:
	return DEMO_WAVES_TONIGHT if DEMO_MODE else GameManager.waves_for_day(GameManager.day_count)

func seals_needed() -> int:
	return DEMO_SEALS_NEEDED if DEMO_MODE else GameManager.SEALS_NEEDED

## ── 기존 시그널에 반응해 연출을 얹는다 ──

func _on_phase_changed(phase: int) -> void:
	var hud: Node = _hud()
	if phase == GameManager.Phase.NIGHT:
		set_beat(Beat.NIGHT_PREP)
		if hud:
			hud.show_banner("🌙 해가 진다 — 균열이 열린다")
			hud.show_toast("좌클릭 3타 콤보 · Shift 회피 · F 반로환동", Color(1, 0.85, 0.5))
	else:
		set_beat(Beat.EXPLORE)

func _on_night_state_changed(state: int) -> void:
	if state == GameManager.NightState.WAVE:
		set_beat(Beat.WAVE)
	elif state == GameManager.NightState.DONE:
		# 모든 웨이브를 버텼다 → 데모의 클라이맥스인 첫 보스를 부른다
		_summon_demo_boss()

## 데모 보스 — 기존 overlord 를 쓴다 (새 적을 만들지 않는다)
func _summon_demo_boss() -> void:
	if boss_spawned or not DEMO_MODE:
		return
	boss_spawned = true
	set_beat(Beat.BOSS)
	var w = get_tree().current_scene
	if w == null or not w.has_method("_make_enemy"):
		return
	var hud: Node = _hud()
	if hud:
		hud.show_banner("⚠ 차원의 환수가 강림한다")
	SoundManager.set_bgm("boss")
	SoundManager.play("ultimate", -4.0)
	CombatFeel.screen_flash(Color(0.9, 0.1, 0.2), 0.4, 0.06, 0.6)

	# 밤이 끝나 아침이 오지 않게 타이머를 늘린다.
	# (원래 DONE 상태는 3초 뒤 밤을 끝낸다 — 그대로 두면 보스전 중에 아침이 온다)
	w.night_timer = 999.0
	GameManager.phase_timer = w.night_timer

	# 방주 앞쪽에 등장시켜 플레이어가 반드시 마주하게 한다
	var c: Vector3 = w.world_center()
	var boss = w._make_enemy("overlord", c + Vector3(0, 0, -22.0))
	if boss:
		boss.tree_exited.connect(_on_demo_boss_dead)
	else:
		# 보스 생성 실패 시 게임이 멈추지 않게 밤을 정상 종료시킨다
		w.night_timer = 3.0

func _on_demo_boss_dead() -> void:
	if beat >= Beat.REWARD:
		return
	set_beat(Beat.REWARD)
	# 봉인은 DayNightManager._end_night_phase() 가 처리한다.
	# 여기서 add_seal() 을 또 부르면 1개 목표에 2개가 쌓인다.
	# 대신 밤을 끝내도록 타이머만 풀어준다.
	var w = get_tree().current_scene
	if w:
		w.night_timer = 4.0
		GameManager.phase_timer = w.night_timer
	var hud: Node = _hud()
	if hud:
		hud.show_banner("◈ 첫 균열을 봉인했다")
	CombatFeel.slow_motion(1.2, 0.25)
	# 확정 보상 — 데모를 끝낸 플레이어는 반드시 강한 것을 손에 넣는다
	# live_player() 를 쓴다 — Battlefield.player 는 이미 해제된 인스턴스일 수 있다
	# (보스와 동시에 죽으면 여기서 그대로 터진다)
	var p := Battlefield.live_player()
	var pos: Vector3 = p.global_position if p else Vector3.ZERO
	LootManager.spawn_drop(pos + Vector3(1.5, 0, 0), 1.0, RarityEnums.Rarity.A)
	LootManager.spawn_drop(pos + Vector3(-1.5, 0, 0), 1.0, RarityEnums.Rarity.B)
	CraftManager.add_essence(120)
	_finish_after_reward()

## 보상을 줍고 나면 엔딩으로 — 조급하지 않게 시간을 준다
func _finish_after_reward() -> void:
	await get_tree().create_timer(26.0, true, false, true).timeout
	if beat >= Beat.OUTRO:
		return
	# 챕터 구조가 들어온 뒤로 보스 처치는 "다음 지역으로 가는 포탈"을 연다.
	# 마지막 챕터가 아니면 여기서 엔딩을 띄우면 안 된다.
	if not ChapterConfig.is_last(GameManager.chapter):
		return
	set_beat(Beat.OUTRO)
	var hud: Node = _hud()
	if hud and hud.has_method("show_victory"):
		hud.show_victory()

func _on_landmark_explored(_data: LandmarkData) -> void:
	set_beat(Beat.LANDMARK)

func _on_landmark_cleared(data: LandmarkData) -> void:
	var hud: Node = _hud()
	if hud:
		hud.show_toast("%s 을(를) 탈환했다 — 마석 +30" % data.display_name, Color(0.6, 1.0, 0.7))
	CraftManager.add_essence(30)

func _on_item_collected(item: ItemData) -> void:
	if _first_item:
		return
	_first_item = true
	set_beat(Beat.TUTORIAL)
	var hud: Node = _hud()
	if hud:
		hud.show_toast("I 키로 인벤토리를 열어 장착하세요", Color(1, 0.9, 0.6))

func _hud() -> Node:
	var w = get_tree().current_scene
	if w and "hud" in w:
		return w.hud
	return null

## 진행 기록 (플레이타임 검증용)
func report() -> String:
	var lines := ["=== 데모 진행 기록 ==="]
	for row in beat_log:
		lines.append("%-12s %6.1fs" % [row[0], row[1]])
	lines.append("총 경과 %.1fs (%.1f분)" % [elapsed, elapsed / 60.0])
	return "\n".join(lines)

func reset() -> void:
	beat = Beat.INTRO
	elapsed = 0.0
	beat_log.clear()
	boss_spawned = false
	_first_item = false
	_first_kill = false
