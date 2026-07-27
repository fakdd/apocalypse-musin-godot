extends Area3D
class_name LandmarkZone
## 랜드마크 진입 판정 영역 — 캠페인 노드 위에 얹히는 투명 Area3D.
##
## 진입 순간 하는 일:
##   1) 잠겨 있으면 막고 이유를 알린다 (퀘스트 잠금)
##   2) LandmarkRegistry 에 알린다 (BGM 전환 · 이벤트 · 탐험 진행도)
##   3 최초 진입이면) **캠페인 웨이브**대로 적을 소환하고 전리품을 배치한다
##
## 두 번째 진입부터는 아무것도 소환하지 않는다 —
## 안 그러면 랜드마크를 왕복하며 무한 파밍이 가능해진다.
##
## ⚠ 스폰 구성은 **캠페인 JSON 에서 온다.** 이 파일에는 몬스터 종류가 하드코딩되어 있지 않다.

var data: LandmarkData
var site = null                 ## CampaignData.Stage (없으면 웨이브 없이 동작)

var _spawned := false
var _looted := false            ## 전리품은 낮에도 한 번은 배치된다 (낮 = 탐험·채집)
var _player_inside := false     ## 밤으로 바뀌는 순간 안에 있었는지 판단하기 위해
var _wave_index := 0
var _wave_timer := 0.0
var _waves_running := false
var _blocked_notice := 0.0      ## 잠금 안내를 도배하지 않기 위한 쿨다운

func setup(p_data: LandmarkData, p_site = null) -> void:
	data = p_data
	site = p_site
	GameManager.phase_changed.connect(_on_phase_changed)
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2                     ## 플레이어 레이어만 감지
	global_position = data.center

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = data.radius
	cyl.height = 12.0
	shape.shape = cyl
	shape.position.y = 4.0
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_process(false)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	# ── 퀘스트 잠금 ──
	if LandmarkRegistry.is_locked(data.id):
		_notify_blocked()
		return

	_player_inside = true
	LandmarkRegistry.notify_enter(data)

	# ── [추가] 캠페인 이벤트 디스패처로 진입 이벤트 전송 ──
	var world = get_tree().current_scene
	if world and world.get("campaign_events") and site != null:
		world.campaign_events.fire(site, "on_enter")
		if not _looted:
			world.campaign_events.fire(site, "on_first_visit")

	# 전리품은 낮에도 놓인다 — 낮의 할 일이 탐험과 채집이기 때문이다
	if not _looted:
		_looted = true
		_scatter_loot()

	_try_start_combat()

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	LandmarkRegistry.notify_exit(data)

## 밤에만 몬스터를 만든다. 낮에는 구역 안으로 들어와도 절대 소환하지 않는다.
func _try_start_combat() -> void:
	if _spawned or GameManager.phase != GameManager.Phase.NIGHT:
		return
	_spawned = true
	_populate()

## 밤으로 바뀌는 순간 이미 구역 안에 있었다면 첫 웨이브를 자동으로 시작한다.
func _on_phase_changed(p: int) -> void:
	if p == GameManager.Phase.NIGHT:
		if _player_inside:
			_try_start_combat()
		return

	# ── 아침 ──
	# 밤에 소환된 적은 전부 삭제된다. 진행 중이던 웨이브를 여기서 되돌리지 않으면
	# 잔여 적 카운터가 남아 이 랜드마크는 영영 클리어되지 않는다.
	_waves_running = false
	_wave_index = 0
	_wave_timer = 0.0
	set_process(false)
	LandmarkRegistry.drop_pending(data.id)
	# 아직 못 깬 곳은 다음 밤에 다시 도전할 수 있어야 한다.
	# 이미 깬 곳은 다시 소환하지 않는다 (왕복 파밍 방지).
	if not data.cleared:
		_spawned = false

func _notify_blocked() -> void:
	if _blocked_notice > 0.0:
		return
	_blocked_notice = 3.0
	set_process(true)
	var need: String = LandmarkRegistry.lock_reason(data.id)
	LandmarkRegistry.landmark_blocked.emit(data.id, need)
	var world = get_tree().current_scene
	if world and world.hud:
		world.hud.show_toast("%s — 아직 들어갈 수 없다" % data.display_name,
			Color(1.0, 0.7, 0.4))

## ══════════════════════════════════════════════
##  밤 최초 진입 — 캠페인 웨이브 실행 (전리품은 _on_body_entered 가 따로 놓는다)
## ══════════════════════════════════════════════
func _populate() -> void:
	if site != null and site.waves.size() > 0:
		_start_waves()
	else:
		# 캠페인에 웨이브가 없으면 예전 방식(단일 스폰 테이블)으로 폴백한다
		_spawn_legacy_guards()

func _start_waves() -> void:
	_wave_index = 0
	_waves_running = true
	set_process(true)
	_spawn_wave(0)

func _spawn_wave(index: int) -> void:
	if site == null or index >= site.waves.size():
		_waves_running = false
		return
	var wave = site.waves[index]
	var world = get_tree().current_scene
	if world == null or not world.has_method("_make_enemy"):
		_waves_running = false
		return

	LandmarkRegistry.notify_wave(data.id, index + 1, site.waves.size())
	if index > 0 and world.hud:
		world.hud.show_toast("%s — 웨이브 %d / %d"
			% [data.display_name, index + 1, site.waves.size()],
			data.minimap_color)

	var made := 0
	var slot := 0
	var total: int = maxi(1, wave.total_count())
	for etype in wave.composition:
		var count: int = int(wave.composition[etype])
		for k in range(count):
			var a := TAU * float(slot) / float(total) + randf_range(-0.25, 0.25)
			var r: float = data.spawn_radius * randf_range(0.55, 1.0)
			var pos: Vector3 = data.center + Vector3(cos(a) * r, 0, sin(a) * r)
			var enemy = world._make_enemy(String(etype), pos)
			slot += 1
			if enemy == null:
				continue
			# 웨이브 HP 배율을 적용한다 (난이도 편집기의 추천 레벨이 여기로 온다)
			if wave.hp_mult != 1.0:
				enemy.max_hp *= wave.hp_mult
				enemy.hp = enemy.max_hp
			enemy.landmark_id = data.id
			made += 1

	# 보스
	if wave.boss != "":
		var boss = world._make_enemy(String(wave.boss), data.center + Vector3(0, 0, -2.0))
		if boss != null:
			# 보스 HP 배율은 **구역**이 들고 있다 (웨이브에는 없다 — 참조하면 그 자리에서 죽는다).
			var raw = wave.get("boss_hp_mult")
			var bmult: float = float(raw) if raw != null else float(site.boss_hp_mult)
			if bmult != 1.0:
				boss.max_hp *= bmult
				boss.hp = boss.max_hp
			boss.landmark_id = data.id
			made += 1
			if world.hud:
				world.hud.show_banner("⚠ %s 강림" % wave.boss)

	LandmarkRegistry.register_spawns(data.id, made)
	if made == 0:
		# 아무것도 못 만들었으면 다음 웨이브로 넘어간다 (여기서 멈추면 클리어가 영원히 안 된다)
		_queue_next_wave()

func _queue_next_wave() -> void:
	_wave_index += 1
	if site == null or _wave_index >= site.waves.size():
		_waves_running = false
		set_process(false)
		return
	# 대기 시간이 0 이면 다음 프레임에 "타이머 만료 + 남은 적 없음" 으로 읽혀
	# 그 웨이브를 통째로 건너뛴다. 최소값을 둬 반드시 소환 경로를 타게 한다.
	_wave_timer = maxf(float(site.waves[_wave_index].delay), 0.05)

func _process(delta: float) -> void:
	if _blocked_notice > 0.0:
		_blocked_notice -= delta

	if not _waves_running:
		if _blocked_notice <= 0.0:
			set_process(false)
		return

	# 현재 웨이브의 적이 전부 죽으면 다음 웨이브를 예약한다
	if _wave_timer <= 0.0 and not LandmarkRegistry.has_pending(data.id):
		if _wave_index + 1 < (site.waves.size() if site else 0):
			_queue_next_wave()
		else:
			_waves_running = false
		return

	if _wave_timer > 0.0:
		_wave_timer -= delta
		if _wave_timer <= 0.0:
			_spawn_wave(_wave_index)

## 캠페인에 웨이브가 없을 때의 폴백 — 예전 단일 스폰 테이블
func _spawn_legacy_guards() -> void:
	if data.spawn_budget <= 0 or data.spawn_table.is_empty():
		return
	var world = get_tree().current_scene
	if world == null or not world.has_method("_make_enemy"):
		return
	var made := 0
	for i in range(data.spawn_budget):
		var etype := data.roll_spawn_type()
		if etype == "":
			continue
		var a := TAU * float(i) / float(data.spawn_budget) + randf_range(-0.3, 0.3)
		var r: float = data.spawn_radius * randf_range(0.55, 1.0)
		var pos: Vector3 = data.center + Vector3(cos(a) * r, 0, sin(a) * r)
		var e = world._make_enemy(etype, pos)
		if e == null:
			continue
		made += 1
		e.landmark_id = data.id
	LandmarkRegistry.register_spawns(data.id, made)

## 아이템 테이블대로 전리품을 배치한다.
func _scatter_loot() -> void:
	# 첫 클리어 확정 보상 — "여기 오길 잘했다"는 감각을 만든다
	if data.guaranteed_rarity >= 0:
		LootManager.spawn_drop(data.center + Vector3(0, 0, 1.2), 1.0, data.guaranteed_rarity)

	for i in range(data.item_count):
		var a := randf_range(0.0, TAU)
		var r: float = data.spawn_radius * randf_range(0.3, 1.0)
		var pos: Vector3 = data.center + Vector3(cos(a) * r, 0, sin(a) * r)
		# drop_chance 1.0 = 확정 배치. 등급은 랜드마크 운 보정을 받는다.
		LootManager.spawn_drop(pos, 1.0, -1, data.item_luck_bonus)
