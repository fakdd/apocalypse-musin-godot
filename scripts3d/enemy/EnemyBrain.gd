extends Node
class_name EnemyBrain
## 적 AI — 명시적 State Machine.
##
## 이전 구조:
##   `_select_target()` 로 목표만 고르고 매 프레임 직선으로 달려갔다. 그래서
##   · 모든 적이 플레이어 **정면 한 점**으로 뭉쳤다 (협공이 없음)
##   · 벽 뒤에 있어도 벽에 몸을 비비며 붙었다 (시야 개념이 없음)
##   · 원거리형도 코앞까지 붙었다 (거리 유지가 없음)
##   · 공격이 헛나가도 같은 각도로 계속 밀어붙였다 (재배치가 없음)
##   · 할 일이 없을 때 완전히 정지했다 (Idle 연출이 없음)
##
## 지금 구조:
##   상태를 명시하고 `_decide_state()` 에서만 전이한다. 각 상태는 "이번 프레임 어디로
##   움직일지(intent)"만 만들고, 실제 이동/벽 회피는 EnemyMovement 가 실행한다.
##   → 새 행동을 추가할 때 State 하나만 추가하면 되고, 기존 상태에 영향이 없다.
##
## 티어별 AI:
##   NORMAL — 기본 추적/협공
##   ELITE  — 반응이 빠르고 거리 유지를 적극적으로 하며 헛스윙 후 반드시 재배치 (is_siege 계열)
##   BOSS   — 페이즈(HP 구간)에 따라 패턴 우선순위가 바뀌는 별도 분기

enum State { IDLE, CHASE, FLANK, SPACING, WINDUP, REPOSITION, SIEGE, STUNNED, SEARCH }

## 상태 이름 (디버그/보고용)
const STATE_NAMES := ["IDLE", "CHASE", "FLANK", "SPACING", "WINDUP", "REPOSITION", "SIEGE", "STUNNED", "SEARCH"]

var owner_enemy: CharacterBody3D

## ── 상태 ──
var state: int = State.IDLE
var state_time := 0.0            ## 현재 상태에 머문 시간
var tier := 0                    ## 0=NORMAL 1=ELITE 2=BOSS

## ── 시야 / 기억 ──
var can_see_player := false
var last_known_pos := Vector3.ZERO
var has_last_known := false
var _los_timer := 0.0            ## 시야 판정은 매 프레임 하지 않는다 (레이캐스트 비용)
var lost_sight_time := 0.0
var _hear_timer := 0.0           ## 청각 판정 간격
var heard_player := false        ## 이번 판정에서 인기척을 들었는가 (디버그/연출용)
var _last_player_pos := Vector3.ZERO   ## 플레이어 이동량 추정용 (빨리 움직이면 더 들린다)

## ── 협공 ──
var slot_angle := NAN            ## Battlefield 가 배분한 접근 각도
var _slot_timer := 0.0

## ── 재배치 ──
var reposition_dir := 0.0        ## 좌/우 중 어느 쪽으로 돌 것인가 (-1 / +1)
var whiff_count := 0             ## 연속 헛스윙 횟수

## ── 랜덤 Idle ──
var idle_variant := 0
var idle_next := 0.0
var idle_face := 0.0

## ── 보스 페이즈 ──
var boss_phase := 0              ## 0: HP>66%, 1: 66~33%, 2: <33%

## 이번 프레임의 이동 의도. EnemyMovement 가 읽는다.
var move_target := Vector3.ZERO
var has_move := false
var speed_mult := 1.0
var face_dir := Vector3.ZERO     ## 이동과 다른 방향을 보고 싶을 때 (거리 유지 중 후진 등)

func setup(e: CharacterBody3D) -> void:
	owner_enemy = e
	idle_next = randf_range(1.0, 2.5)
	reposition_dir = 1.0 if randf() < 0.5 else -1.0

## 티어를 (재)계산한다.
## setup() 은 Enemy3D._ready() 에서 불리는데, 그 시점에는 enemy_type 이 아직 "grunt" 이고
## is_siege 도 false 다. 실제 타입은 Enemy3D.setup(type, wave) 에서 정해지므로
## 거기서 이 함수를 다시 불러야 보스/엘리트가 올바른 티어를 받는다.
func refresh_tier() -> void:
	tier = _resolve_tier()

func _resolve_tier() -> int:
	if owner_enemy.is_boss_type():
		return 2
	if owner_enemy.is_siege:
		return 1          ## 파괴자/저거너트 = 엘리트
	return 0

## 이 타입이 유지하고 싶은 거리
func preferred_range() -> float:
	match owner_enemy.pattern:
		"ranged":
			return EnemyConfig.RANGE_KEEP_RANGED
		"charge":
			return EnemyConfig.RANGE_KEEP_CHARGE
		"boss":
			return EnemyConfig.RANGE_KEEP_BOSS
		_:
			return owner_enemy.hit_radius + EnemyConfig.RANGE_KEEP_MELEE

## ══════════════════════════════════════════════
##  매 물리 프레임 — EnemyMovement 가 호출한다
## ══════════════════════════════════════════════
func think(delta: float) -> void:
	state_time += delta
	_slot_timer -= delta
	_los_timer -= delta

	var player := Battlefield.live_player()
	_update_vision(player, delta)
	_update_hearing(player, delta)
	if tier == 2:
		_update_boss_phase()

	_decide_state(player)
	_run_state(player, delta)

## ── 시야 판정 ──
## 플레이어와 자기 사이에 지형(레이어 1)이 있으면 "안 보인다".
## 안 보이면 마지막으로 본 위치로 향하고, 일정 시간이 지나면 탐색/Idle 로 돌아간다.
func _update_vision(player: Node3D, delta: float) -> void:
	if player == null:
		can_see_player = false
		lost_sight_time += delta
		return

	# 레이캐스트는 비싸다 — LOS_INTERVAL 간격으로만 갱신한다
	if _los_timer > 0.0:
		if not can_see_player:
			lost_sight_time += delta
		return
	_los_timer = EnemyConfig.LOS_INTERVAL

	var eye: Vector3 = owner_enemy.global_position + Vector3(0, owner_enemy.hover_height + owner_enemy.hit_radius, 0)
	var tgt: Vector3 = player.global_position + Vector3(0, 1.0, 0)
	var dist: float = eye.distance_to(tgt)

	if dist > EnemyConfig.SIGHT_RANGE:
		can_see_player = false
		lost_sight_time += EnemyConfig.LOS_INTERVAL
		return

	# 시야각 — 등 뒤는 보이지 않는다. 단 코앞이면 각도와 무관하게 알아챈다.
	if dist > EnemyConfig.SIGHT_NEAR and not _in_fov(player):
		can_see_player = false
		lost_sight_time += EnemyConfig.LOS_INTERVAL
		return

	var space := owner_enemy.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(eye, tgt)
	q.collision_mask = 1                       ## 지형/건물만
	q.exclude = [owner_enemy.get_rid()]
	var hit := space.intersect_ray(q)
	can_see_player = hit.is_empty()

	if can_see_player:
		last_known_pos = player.global_position
		has_last_known = true
		lost_sight_time = 0.0
	else:
		lost_sight_time += EnemyConfig.LOS_INTERVAL

## 몸이 향한 방향 기준 시야각 안에 있는가.
func _in_fov(player: Node3D) -> bool:
	var e := owner_enemy
	if e.model == null:
		return true
	var facing := Vector3(sin(e.model.rotation.y), 0, cos(e.model.rotation.y))
	var to_player: Vector3 = player.global_position - e.global_position
	to_player.y = 0
	if to_player.length_squared() < 0.01:
		return true
	return facing.angle_to(to_player.normalized()) <= EnemyConfig.SIGHT_FOV * 0.5

## ── 소리 감지 ──
## 보이지 않아도 가까이서 움직이면 인기척으로 위치를 잡는다.
## 그래서 등 뒤로 돌아가도 코앞에서는 들킨다 — 벽 뒤 잠입은 여전히 통한다.
func _update_hearing(player: Node3D, delta: float) -> void:
	heard_player = false
	if player == null or can_see_player:
		_last_player_pos = player.global_position if player else _last_player_pos
		return
	_hear_timer -= delta
	if _hear_timer > 0.0:
		return
	_hear_timer = EnemyConfig.HEAR_INTERVAL

	var moved: float = _last_player_pos.distance_to(player.global_position)
	_last_player_pos = player.global_position

	var reach: float = EnemyConfig.HEAR_RANGE
	# 빨리 움직일수록 발소리가 크다
	if moved / EnemyConfig.HEAR_INTERVAL > 4.0:
		reach *= EnemyConfig.HEAR_SPRINT_MULT
	# 가만히 서 있으면 소리가 나지 않는다
	elif moved < 0.15:
		return

	var d: float = owner_enemy.global_position.distance_to(player.global_position)
	if d > reach:
		return

	heard_player = true
	last_known_pos = player.global_position
	has_last_known = true
	# 본 것은 아니므로 기억 시간은 리셋하지 않고 절반만 되돌린다
	lost_sight_time = minf(lost_sight_time, EnemyConfig.MEMORY_TIME * 0.5)

func _update_boss_phase() -> void:
	var r: float = owner_enemy.hp / maxf(owner_enemy.max_hp, 1.0)
	var p := 0
	if r < 0.33:
		p = 2
	elif r < 0.66:
		p = 1
	if p != boss_phase:
		boss_phase = p

## ── 상태 전이 ──
func _decide_state(player: Node3D) -> void:
	var e := owner_enemy

	# 경직은 모든 것을 덮어쓴다
	if e.stun_timer > 0.0:
		_set_state(State.STUNNED)
		return

	# 공성형(파괴자)은 방벽/방주를 노리는 전용 상태를 유지한다 (기존 역할 보존)
	if e.is_siege:
		# 다만 플레이어가 아주 가까우면 먼저 반응한다 (이전에는 플레이어를 완전히 무시했다)
		if player and can_see_player \
			and e.global_position.distance_to(player.global_position) < EnemyConfig.SIEGE_INTERRUPT_RANGE:
			_decide_combat_state(player)
			return
		_set_state(State.SIEGE)
		return

	if player == null:
		# 플레이어가 없으면 방주로 향한다 (기존 동작 유지)
		if Battlefield.live_base():
			_set_state(State.CHASE)
		else:
			_set_state(State.IDLE)
		return

	_decide_combat_state(player)

func _decide_combat_state(player: Node3D) -> void:
	var e := owner_enemy
	var dist: float = e.global_position.distance_to(player.global_position)

	# 돌진 예고/돌진 중에는 브레인이 이동을 건드리지 않는다 (EnemyMovement 가 전담)
	if e.charge_windup > 0.0 or e.charge_dash > 0.0:
		_set_state(State.WINDUP)
		return

	# 헛스윙 뒤에는 각도를 바꿔 다시 붙는다
	if state == State.REPOSITION and state_time < _reposition_duration():
		return

	if not can_see_player:
		# 시야를 잃었다 — 잠깐은 마지막 위치를 추적한다
		if has_last_known and lost_sight_time < EnemyConfig.MEMORY_TIME:
			_set_state(State.SEARCH)
		elif owner_enemy.landmark_id == "" and Battlefield.live_base():
			# 못 찾으면 방주로 진군한다.
			# 웨이브는 맵 가장자리(방주에서 약 37m)에 스폰되는데 시야는 30m 라,
			# 여기서 Idle 로 빠지면 웨이브가 기지까지 오지 못하고 제자리에서 배회한다.
			_set_state(State.CHASE)
		else:
			# 랜드마크 수호 몹은 자리를 지킨다 (흩어지면 클리어 판정이 영원히 안 난다)
			_set_state(State.IDLE)
		return

	var keep := preferred_range()

	# 너무 붙었다 — 원거리/보스는 물러난다
	if dist < keep * EnemyConfig.SPACING_INNER and _wants_spacing():
		_set_state(State.SPACING)
		return

	# 사거리 안 — 협공 슬롯을 받아 측면에서 접근한다
	if dist < EnemyConfig.FLANK_RANGE:
		_ensure_slot()
		if not is_nan(slot_angle):
			_set_state(State.FLANK)
			return

	_set_state(State.CHASE)

## 거리 유지를 하는 타입인가 (근접 몹은 무조건 붙는다 — 기존 위협도 유지)
func _wants_spacing() -> bool:
	return owner_enemy.pattern == "ranged" or owner_enemy.pattern == "boss" \
		or (tier >= 1 and owner_enemy.pattern == "charge")

func _reposition_duration() -> float:
	return EnemyConfig.REPOSITION_TIME * (0.7 if tier >= 1 else 1.0)

func _set_state(s: int) -> void:
	if s == state:
		return
	_exit_state(state)
	state = s
	state_time = 0.0
	_enter_state(s)

func _enter_state(s: int) -> void:
	match s:
		State.IDLE:
			idle_next = randf_range(0.8, 2.2)
			idle_variant = randi() % 3
			idle_face = randf_range(-PI, PI)
		State.REPOSITION:
			# 헛스윙이 반복되면 반대쪽으로 크게 돈다
			if whiff_count >= 2:
				reposition_dir = -reposition_dir
				whiff_count = 0
		State.FLANK:
			pass

func _exit_state(s: int) -> void:
	if s == State.FLANK:
		# 슬롯은 유지한다 (놓으면 다음 프레임에 다른 슬롯을 받아 경로가 튄다)
		pass

## ── 상태 실행 ──
func _run_state(player: Node3D, delta: float) -> void:
	has_move = false
	speed_mult = 1.0
	face_dir = Vector3.ZERO

	match state:
		State.STUNNED:
			pass                                  ## 이동 없음
		State.WINDUP:
			pass                                  ## 돌진 로직이 전담
		State.IDLE:
			_run_idle(delta)
		State.SEARCH:
			_run_search()
		State.SIEGE:
			_run_siege()
		State.CHASE:
			_run_chase(player)
		State.FLANK:
			_run_flank(player)
		State.SPACING:
			_run_spacing(player)
		State.REPOSITION:
			_run_reposition(player)

	# 패턴(원거리/돌진/보스) 발동 판단은 상태와 별개로 매 프레임 시도한다
	if can_see_player and state != State.STUNNED:
		_try_pattern(player)

## 랜덤 Idle — 가만히 서 있지 않고 주변을 둘러보거나 짧게 배회한다
func _run_idle(delta: float) -> void:
	idle_next -= delta
	if idle_next <= 0.0:
		idle_next = randf_range(1.2, 3.0)
		idle_variant = randi() % 3
		idle_face = randf_range(-PI, PI)

	match idle_variant:
		0:
			# 두리번거리기 — 제자리에서 방향만 바꾼다
			face_dir = Vector3(sin(idle_face), 0, cos(idle_face))
		1:
			# 짧은 배회 — 아주 느리게 주변을 걷는다
			move_target = owner_enemy.global_position + Vector3(sin(idle_face), 0, cos(idle_face)) * 3.0
			has_move = true
			speed_mult = EnemyConfig.IDLE_WANDER_SPEED
		_:
			# 정지 — 완전히 멈춰 숨 고르기
			pass

## 시야를 잃었을 때 — 마지막으로 본 위치까지 간다
func _run_search() -> void:
	if not has_last_known:
		return
	move_target = last_known_pos
	has_move = true
	speed_mult = EnemyConfig.SEARCH_SPEED

## 공성 — 방벽 우선, 없으면 방주 (기존 역할 그대로)
func _run_siege() -> void:
	var target := Battlefield.nearest_defense(owner_enemy.global_position)
	if target == null:
		target = Battlefield.live_base()
	if target:
		move_target = target.global_position
		has_move = true

## 정면 추격 — 협공 슬롯이 없거나 먼 거리
func _run_chase(player: Node3D) -> void:
	# 보이는 플레이어가 최우선. 안 보이면 방주를 목표로 삼는다
	# (그래야 시야 밖에서 스폰된 웨이브가 기지로 몰려온다)
	if player and can_see_player:
		move_target = player.global_position
		has_move = true
		return
	var b := Battlefield.live_base()
	if b:
		move_target = b.global_position
		has_move = true
	elif player:
		move_target = player.global_position
		has_move = true

## 협공 — 배분받은 각도에서 접근한다.
## 목표점은 "플레이어 + 슬롯 방향 × 선호거리". 그래서 여러 적이 서로 다른 방향에서 조여든다.
func _run_flank(player: Node3D) -> void:
	if player == null:
		_run_chase(player)
		return
	var keep := preferred_range()
	var slot_offset := Vector3(sin(slot_angle), 0, cos(slot_angle)) * keep
	move_target = player.global_position + slot_offset
	has_move = true
	# 슬롯 위치에 거의 도착했으면 플레이어를 향해 마지막 한 걸음
	if owner_enemy.global_position.distance_to(move_target) < 1.2:
		move_target = player.global_position
	face_dir = (player.global_position - owner_enemy.global_position)

## 거리 유지 — 너무 붙었으면 뒤로 물러나면서 계속 플레이어를 본다
func _run_spacing(player: Node3D) -> void:
	if player == null:
		return
	var away: Vector3 = owner_enemy.global_position - player.global_position
	away.y = 0
	if away.length() < 0.1:
		away = Vector3(1, 0, 0)
	var keep := preferred_range()
	move_target = player.global_position + away.normalized() * (keep * EnemyConfig.SPACING_TARGET)
	has_move = true
	speed_mult = EnemyConfig.SPACING_SPEED
	face_dir = -away          ## 후진하면서도 플레이어를 응시한다

## 공격 실패 후 재배치 — 옆으로 크게 돌아 다른 각도에서 다시 붙는다
func _run_reposition(player: Node3D) -> void:
	if player == null:
		return
	var to_me: Vector3 = owner_enemy.global_position - player.global_position
	to_me.y = 0
	if to_me.length() < 0.1:
		to_me = Vector3(1, 0, 0)
	var keep: float = preferred_range() * EnemyConfig.REPOSITION_ARC_RADIUS
	# 현재 각도에서 좌/우로 벌려 원호를 그린다
	var a := atan2(to_me.x, to_me.z) + reposition_dir * EnemyConfig.REPOSITION_ARC
	move_target = player.global_position + Vector3(sin(a), 0, cos(a)) * keep
	has_move = true
	speed_mult = EnemyConfig.REPOSITION_SPEED
	face_dir = (player.global_position - owner_enemy.global_position)

## 협공 슬롯 확보 (너무 자주 요청하면 경로가 흔들린다)
func _ensure_slot() -> void:
	if _slot_timer > 0.0 and not is_nan(slot_angle):
		return
	_slot_timer = EnemyConfig.SLOT_REFRESH
	slot_angle = Battlefield.claim_slot(owner_enemy)

## 외부에서 위치를 알려 준다 (피격 등). 시야각이 생긴 뒤로는 이게 없으면
## 등 뒤에서 맞은 적이 때린 쪽을 못 찾고 가만히 서 있는다.
func alert_to(pos: Vector3) -> void:
	last_known_pos = pos
	has_last_known = true
	lost_sight_time = 0.0
	if state == State.IDLE:
		_set_state(State.SEARCH)

## 공격이 헛나갔음을 알린다 (EnemyMovement 가 돌진 종료 시 호출)
func report_whiff() -> void:
	whiff_count += 1
	_set_state(State.REPOSITION)

## 노드가 사라질 때 슬롯을 반납한다 (안 하면 슬롯이 영구 점유된다)
func _exit_tree() -> void:
	if is_instance_valid(owner_enemy):
		Battlefield.release_slot(owner_enemy)

## ══════════════════════════════════════════════
##  패턴 발동 — 원거리 / 돌진 / 보스
##  발동 조건(거리·쿨다운)은 기존 값을 유지했다. 보스만 페이즈 분기를 추가했다.
## ══════════════════════════════════════════════
func _try_pattern(player) -> void:
	if player == null or not is_instance_valid(player) or player.hp <= 0:
		return
	var flat: Vector3 = player.global_position - owner_enemy.global_position
	flat.y = 0
	var dist := flat.length()

	match owner_enemy.pattern:
		"ranged":
			# 일정 거리에서 멈춰 원거리 기탄을 발사
			if dist < 16.0 and dist > 4.0 and owner_enemy.shoot_cd <= 0.0:
				owner_enemy.shoot_cd = 2.3
				owner_enemy.attack_anim_timer = EnemyConfig.ATTACK_ANIM_TIME
				owner_enemy.animation._play(owner_enemy.anim_attack, true)
				owner_enemy.attack._fire_projectile(flat.normalized())
		"charge":
			if dist < 13.0 and dist > 3.5 and owner_enemy.charge_cd <= 0.0:
				owner_enemy.charge_cd = 4.5
				owner_enemy.charge_dir = flat.normalized()
				owner_enemy.charge_windup = 0.65
				owner_enemy.attack._show_telegraph(owner_enemy.charge_dir)
		"boss":
			_try_boss_pattern(dist, flat)

## 보스 AI 기반 구조 — HP 페이즈에 따라 탄막 밀도와 돌진 빈도가 달라진다.
## 페이즈 0 은 기존 수치와 동일하다. 후반 페이즈만 더 공격적으로 만든다.
func _try_boss_pattern(dist: float, flat: Vector3) -> void:
	var e := owner_enemy
	var shoot_cd: float = [1.5, 1.25, 1.0][boss_phase]
	var charge_cd: float = [6.0, 5.0, 4.0][boss_phase]
	var extra_spread: int = boss_phase          ## 페이즈마다 탄이 1발씩 늘어난다

	if dist < 22.0 and e.shoot_cd <= 0.0:
		e.shoot_cd = shoot_cd
		var spread: int = (5 if e.enemy_type == "warlord" else 3) + extra_spread
		for i in range(spread):
			var a := (float(i) - (spread - 1) * 0.5) * 0.22
			e.attack._fire_projectile(flat.normalized().rotated(Vector3.UP, a))
	if dist < 16.0 and dist > 4.0 and e.charge_cd <= 0.0:
		e.charge_cd = charge_cd
		e.charge_dir = flat.normalized()
		e.charge_windup = 0.8
		e.attack._show_telegraph(e.charge_dir)

## ── 하위 호환 ──
## 기존 EnemyMovement 가 쓰던 API. 새 FSM 의 판단 결과를 같은 형태로 돌려준다.
func _select_target(player: Node) -> Dictionary:
	if has_move:
		return {"pos": move_target, "has": true}
	return {"pos": Vector3.ZERO, "has": false}

## 현재 상태 이름 (디버그)
func state_name() -> String:
	return STATE_NAMES[state]
