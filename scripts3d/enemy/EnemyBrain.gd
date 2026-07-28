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
var boss_phase := 0              ## data/bosses.json 의 phases 인덱스
var boss_def: Dictionary = {}    ## 이 보스의 전체 정의 (없으면 비어 있다)
var phase_def: Dictionary = {}   ## 현재 페이즈 정의
var nova_cd := 0.0
var sweep_cd := 0.0
var slam_cd := 0.0
var summon_cd := 0.0
var homing_cd := 0.0
var field_cd := 0.0
var boss_time := 0.0             ## 전투 시작 후 경과 (광폭화 판정)
var enraged := false
var weak_timer := 0.0            ## >0 이면 약점 노출 (받는 피해 증가)

## ── 전술 (data/ai.json) ──
var profile: Dictionary = {}     ## 이 몹의 최종 전술 프로필
var dodge_cd := 0.0              ## 회피 재사용 대기
var dodge_timer := 0.0           ## >0 이면 회피 중 (옆으로 빠지는 중)
var dodge_dir := Vector3.ZERO
var retreat_cd := 0.0
var retreat_timer := 0.0         ## >0 이면 후퇴 중
var pack_mult := 1.0             ## 같은 종류가 뭉칠수록 붙는 속도가 오른다
var _pack_next := 0.0

## ── 대표 행동 (data/monsters.json) ──
var behavior: Dictionary = {}
var sig_cd := 0.0
var enraged_low := false      ## frenzy — 체력이 낮아 광폭화했는가
var revived := false          ## revive_once — 이미 한 번 일어났는가

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
## 전술 프로필을 읽어 둔다. 몬스터 종류가 정해진 뒤 한 번만 부르면 된다.
func refresh_profile() -> void:
	profile = EnemyConfig.ai_profile(owner_enemy.enemy_type, owner_enemy.pattern)
	behavior = EnemyConfig.mon_behavior(owner_enemy.enemy_type)
	_apply_signature()

## 대표 행동 중 "항상 켜져 있는" 것들을 프로필에 녹인다.
## 이렇게 하면 상태기계를 건드리지 않고도 몹마다 움직임이 달라진다.
func _apply_signature() -> void:
	if behavior.is_empty():
		return
	match String(behavior.get("kind", "")):
		"pack":
			profile["pack_bonus"] = float(behavior.get("speed", 0.05))
			profile["pack_max"] = float(behavior.get("max", 1.3))
		"retreat":
			profile["retreat_hp"] = float(behavior.get("hp", 0.35))
		"flank":
			profile["flank_bias"] = float(behavior.get("bias", 0.8))
			profile["dodge_chance"] = float(behavior.get("dodge", 0.5))
		"keep":
			profile["keep"] = float(behavior.get("distance", 12.0))
			profile["cover"] = float(behavior.get("cover", 0.6))
		"track":
			profile["retreat_hp"] = 0.0
			profile["aggression"] = float(behavior.get("speed", 1.1))
		"immune":
			profile["dodge_chance"] = 0.0
			profile["flank_bias"] = 0.0

func prof(key: String, fallback: float) -> float:
	if profile.is_empty():
		refresh_profile()
	return float(profile.get(key, fallback))

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
	_update_tactics(delta)
	state_time += delta
	_slot_timer -= delta
	_los_timer -= delta

	var player := Battlefield.live_player()
	_update_vision(player, delta)
	_update_hearing(player, delta)
	if tier == 2:
		_update_boss_phase()
		_update_enrage(delta)
		nova_cd = maxf(0.0, nova_cd - delta)
		sweep_cd = maxf(0.0, sweep_cd - delta)
		slam_cd = maxf(0.0, slam_cd - delta)
		summon_cd = maxf(0.0, summon_cd - delta)
		homing_cd = maxf(0.0, homing_cd - delta)
		field_cd = maxf(0.0, field_cd - delta)
		weak_timer = maxf(0.0, weak_timer - delta)

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
	var t: String = owner_enemy.enemy_type
	if boss_def.is_empty():
		boss_def = EnemyConfig.boss_def(t)
	var r: float = owner_enemy.hp / maxf(owner_enemy.max_hp, 1.0)
	var p: int = EnemyConfig.boss_phase_index(t, r)
	phase_def = EnemyConfig.boss_phase_def(t, r)
	if p != boss_phase:
		boss_phase = p
		_announce_phase(p)

## 페이즈 전환 연출 — 무적이나 기절 없이 화면과 소리로만 알린다.
func _announce_phase(p: int) -> void:
	if p <= 0:
		return
	CombatFeel.impact("boss_phase")
	var world = owner_enemy.get_tree().current_scene
	if world and world.get("hud") != null:
		var nm: String = String(boss_def.get("name", ""))
		world.hud.show_banner("%s — %d단계" % [nm if nm != "" else "보스", p + 1])

## 광폭화 — 정해진 시간이 지나면 속도와 발사 빈도가 오른다.
func _update_enrage(delta: float) -> void:
	boss_time += delta
	if enraged:
		return
	var e = EnemyConfig.boss_field(owner_enemy.enemy_type, "enrage")
	if typeof(e) != TYPE_DICTIONARY:
		return
	# 시간이 다 됐거나, 체력이 임계 아래로 떨어지면 발동한다.
	# 시간만 보면 잘 싸우는 플레이어는 광폭화를 한 번도 못 본다.
	var ratio: float = owner_enemy.hp / maxf(owner_enemy.max_hp, 1.0)
	var by_time: bool = boss_time >= float(e.get("at", 999.0))
	var by_hp: bool = ratio <= float(e.get("hp_below", 0.0))
	if not by_time and not by_hp:
		return
	enraged = true
	owner_enemy.speed *= float(e.get("speed", 1.25))
	# 붉은 오라 — 멀리서도 "지금 세졌다" 가 보인다
	if bool(e.get("aura", true)):
		var tc2 = e.get("tint", [1.0, 0.35, 0.3])
		var col := Color(1.0, 0.35, 0.3)
		if typeof(tc2) == TYPE_ARRAY and tc2.size() >= 3:
			col = Color(float(tc2[0]), float(tc2[1]), float(tc2[2]))
		VfxPool.burst(owner_enemy.get_parent(),
			owner_enemy.global_position + Vector3(0, owner_enemy.hover_height, 0),
			col, 46, 5.0, 1.1, 0.22, -1.2)
		if owner_enemy.animation and owner_enemy.animation.has_method("_add_aura"):
			owner_enemy.animation._add_aura(col)
	CombatFeel.impact("boss_enrage")
	var world = owner_enemy.get_tree().current_scene
	if world and world.get("hud") != null:
		world.hud.show_banner("\u26a0 %s 광폭화" % String(boss_def.get("name", "보스")))

## 약점 — 돌진이 끝난 직후 잠깐 크게 아프다. 플레이어가 노릴 창구.
func open_weakness() -> void:
	var w = EnemyConfig.boss_field(owner_enemy.enemy_type, "weakness")
	if typeof(w) != TYPE_DICTIONARY:
		return
	weak_timer = float(w.get("window", 1.8))

func weakness_mult() -> float:
	if weak_timer <= 0.0:
		return 1.0
	var w = EnemyConfig.boss_field(owner_enemy.enemy_type, "weakness")
	if typeof(w) != TYPE_DICTIONARY:
		return 1.0
	return float(w.get("mult", 1.0))

# ══════════════════════════════════════════════
#  전술 — 회피 · 후퇴 · 무리
# ══════════════════════════════════════════════

## 쿨다운·지속시간·무리 규모를 갱신한다. 매 프레임 그룹 검색을 하지 않으려고
## 무리 규모는 0.5초에 한 번만 다시 센다 (Battlefield 캐시 배열을 훑는다).
func _update_tactics(delta: float) -> void:
	sig_cd = maxf(0.0, sig_cd - delta)
	_tick_signature(delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	retreat_cd = maxf(0.0, retreat_cd - delta)
	dodge_timer = maxf(0.0, dodge_timer - delta)
	retreat_timer = maxf(0.0, retreat_timer - delta)

	_pack_next -= delta
	if _pack_next <= 0.0:
		_pack_next = 0.5
		var bonus := prof("pack_bonus", 0.0)
		if bonus <= 0.0:
			pack_mult = 1.0
		else:
			var n := 0
			for other in Battlefield.enemies:
				if not is_instance_valid(other) or other == owner_enemy or other.dead:
					continue
				if other.enemy_type != owner_enemy.enemy_type:
					continue
				if other.global_position.distance_to(owner_enemy.global_position) < 12.0:
					n += 1
			pack_mult = minf(1.0 + bonus * float(n), prof("pack_max", 1.3))

## 주기적으로 작동하는 대표 행동. 전부 기존 함수만 부른다.
func _tick_signature(_delta: float) -> void:
	if behavior.is_empty() or owner_enemy.dead:
		return
	var kind := String(behavior.get("kind", ""))

	# 광폭화 — 체력이 낮아지면 빨라진다 (라비저)
	if kind == "rage" and not enraged_low:
		if owner_enemy.hp / maxf(owner_enemy.max_hp, 1.0) < float(behavior.get("hp", 0.5)):
			enraged_low = true
			owner_enemy.speed *= float(behavior.get("speed", 1.3))
			_safe_flash(owner_enemy.animation)
		return

	if sig_cd > 0.0:
		return

	match kind:
		"heal_allies":
			sig_cd = float(behavior.get("cd", 3.5))
			var r := float(behavior.get("radius", 10.0))
			var pct := float(behavior.get("pct", 0.05))
			for o in Battlefield.enemies:
				if not is_instance_valid(o) or o.dead or o == owner_enemy:
					continue
				if o.global_position.distance_to(owner_enemy.global_position) > r:
					continue
				if o.hp < o.max_hp:
					o.hp = minf(o.max_hp, o.hp + o.max_hp * pct)
					_safe_flash(o.animation)
		"buff_allies":
			sig_cd = float(behavior.get("cd", 8.0))
			var r2 := float(behavior.get("radius", 10.0))
			var m := float(behavior.get("damage", 1.25))
			for o in Battlefield.enemies:
				if not is_instance_valid(o) or o.dead or o == owner_enemy:
					continue
				if o.global_position.distance_to(owner_enemy.global_position) > r2:
					continue
				if not o.get_meta("empowered", false):
					o.set_meta("empowered", true)
					o.contact_damage *= m
					_safe_flash(o.animation)
		"slam":
			var pl := Battlefield.live_player()
			if pl == null:
				return
			var rad := float(behavior.get("radius", 6.0)) * EnemyConfig.mon_chapter_scale("slam_radius")
			if owner_enemy.global_position.distance_to(pl.global_position) > rad:
				return
			sig_cd = float(behavior.get("cd", 6.0)) * EnemyConfig.mon_chapter_scale("slam_cd")
			owner_enemy.attack_anim_timer = maxf(owner_enemy.attack_anim_timer, 0.4)
			CombatFeel.impact("slam")
			pl.take_damage(owner_enemy.contact_damage * float(behavior.get("damage", 1.4)),
				owner_enemy.global_position)
		"summon":
			sig_cd = float(behavior.get("cd", 16.0))
			_summon(String(behavior.get("type", "hound")), int(behavior.get("count", 2)))
		"homing":
			var pl3 := Battlefield.live_player()
			if pl3 == null:
				return
			var to3: Vector3 = pl3.global_position - owner_enemy.global_position
			to3.y = 0.0
			if to3.length() > float(behavior.get("range", 20.0)):
				return
			sig_cd = float(behavior.get("cd", 4.5))
			fire_homing(int(behavior.get("count", 2)), to3.normalized())
		"field":
			var pl4 := Battlefield.live_player()
			if pl4 == null:
				return
			if owner_enemy.global_position.distance_to(pl4.global_position) \
					> float(behavior.get("range", 16.0)):
				return
			sig_cd = float(behavior.get("cd", 8.0)) * EnemyConfig.mon_chapter_scale("field_cd")
			spawn_field(float(behavior.get("radius", 4.0)) * EnemyConfig.mon_chapter_scale("field_radius"),
				float(behavior.get("life", 5.0)), pl4.global_position)
		"pierce_guard":
			# 방어 관통 — 예고 후 강하게 친다. 패링으로만 넘길 수 있다.
			var pl2 := Battlefield.live_player()
			if pl2 == null or owner_enemy.global_position.distance_to(pl2.global_position) > 4.5:
				return
			sig_cd = float(behavior.get("cd", 7.0))
			var d2: Vector3 = pl2.global_position - owner_enemy.global_position
			d2.y = 0.0
			owner_enemy.charge_dir = d2.normalized()
			owner_enemy.charge_windup = 0.7
			owner_enemy.attack._show_telegraph(owner_enemy.charge_dir)

## 플레이어가 큰 기술을 쓰려는 순간 옆으로 빠진다.
## PlayerCombat 이 예고할 때 Battlefield 를 통해 전체에 알린다.
func try_dodge(from: Vector3) -> void:
	if dodge_cd > 0.0 or owner_enemy.dead or owner_enemy.is_siege:
		return
	var chance := prof("dodge_chance", 0.0) * EnemyConfig.ai_tier_scale("dodge", tier)
	if randf() > chance:
		return
	dodge_cd = EnemyConfig.ai_num("dodge", "cooldown", 3.0)
	dodge_timer = EnemyConfig.ai_num("dodge", "window", 0.55)
	var away := owner_enemy.global_position - from
	away.y = 0.0
	if away.length_squared() < 0.001:
		away = Vector3.FORWARD
	# 뒤가 아니라 옆으로 빠진다 — 뒤로 빼면 그냥 도망처럼 보인다
	dodge_dir = away.normalized().cross(Vector3.UP).normalized() \
		* (1.0 if randf() < 0.5 else -1.0)

## 체력이 낮으면 잠깐 물러나 거리를 벌린다. 회복 수단은 없지만
## 플레이어에게 "몰아붙이는 맛"과 추격의 리듬을 준다.
func _should_retreat() -> bool:
	var th := prof("retreat_hp", 0.0) * EnemyConfig.ai_tier_scale("retreat", tier)
	if th <= 0.0 or retreat_cd > 0.0:
		return false
	return owner_enemy.hp / maxf(owner_enemy.max_hp, 1.0) < th

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

	# 회피 중 — 옆으로 빠지는 동안은 다른 판단을 하지 않는다
	if dodge_timer > 0.0:
		move_target = e.global_position \
			+ dodge_dir * EnemyConfig.ai_num("dodge", "distance", 4.5)
		has_move = true
		speed_mult = 1.6
		_set_state(State.REPOSITION)
		return

	# 후퇴 — 체력이 바닥나면 잠깐 물러난다
	if retreat_timer > 0.0:
		var back := (e.global_position - player.global_position)
		back.y = 0.0
		move_target = e.global_position + back.normalized() \
			* EnemyConfig.ai_num("retreat", "distance", 9.0)
		has_move = true
		speed_mult = 1.15
		_set_state(State.SPACING)
		return
	if _should_retreat():
		retreat_timer = EnemyConfig.ai_num("retreat", "duration", 2.2)
		retreat_cd = EnemyConfig.ai_num("retreat", "cooldown", 8.0)
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

	var keep := prof("keep", preferred_range())

	# 너무 붙었다 — 원거리/보스는 물러난다
	if dist < keep * EnemyConfig.SPACING_INNER and _wants_spacing():
		_set_state(State.SPACING)
		return

	# 사거리 안 — 협공 슬롯을 받아 측면에서 접근한다 (포위 거리는 프로필값)
	if dist < prof("surround", EnemyConfig.FLANK_RANGE):
		_ensure_slot()
		if not is_nan(slot_angle):
			_set_state(State.FLANK)
			return

	speed_mult = pack_mult * prof("aggression", 1.0)
	_set_state(State.CHASE)

## 거리 유지를 하는 타입인가 (근접 몹은 무조건 붙는다 — 기존 위협도 유지)
func _wants_spacing() -> bool:
	# 프로필에 keep 이 크게 잡혀 있으면 거리를 유지하는 타입으로 본다
	if prof("keep", 0.0) >= 5.0:
		return true
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
	var keep := prof("keep", preferred_range())
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
	var keep := prof("keep", preferred_range())
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
## 패턴은 전부 data/bosses.json 의 phases[n].patterns 에서 온다.
## 정의가 없는 보스는 예전 수치를 그대로 쓴다 (회귀 방지).
func _try_boss_pattern(dist: float, flat: Vector3) -> void:
	var e := owner_enemy
	if phase_def.is_empty():
		_legacy_boss_pattern(dist, flat)
		return

	var rate: float = 1.0
	if enraged:
		var en = EnemyConfig.boss_field(e.enemy_type, "enrage")
		if typeof(en) == TYPE_DICTIONARY:
			rate = float(en.get("rate", 1.0))

	var pats: Array = phase_def.get("patterns", [])
	var dir := flat.normalized()

	if pats.has("volley") and dist < 22.0 and e.shoot_cd <= 0.0:
		e.shoot_cd = float(phase_def.get("shoot_cd", 1.5)) / rate
		var spread: int = int(phase_def.get("spread", 3))
		for i in range(spread):
			var a := (float(i) - (spread - 1) * 0.5) * 0.22
			e.attack._fire_projectile(dir.rotated(Vector3.UP, a))

	if pats.has("nova") and dist < 26.0 and nova_cd <= 0.0:
		nova_cd = float(phase_def.get("nova_cd", 7.0)) / rate
		var n: int = int(phase_def.get("nova_count", 12))
		for i in range(n):
			e.attack._fire_projectile(Vector3.FORWARD.rotated(Vector3.UP, TAU * float(i) / float(n)))

	if pats.has("sweep") and dist < 26.0 and sweep_cd <= 0.0:
		sweep_cd = float(phase_def.get("sweep_cd", 8.0)) / rate
		_sweep(int(phase_def.get("sweep_count", 14)), dir)

	if pats.has("slam") and dist < float(phase_def.get("slam_radius", 7.0)) and slam_cd <= 0.0:
		slam_cd = float(phase_def.get("slam_cd", 5.0)) / rate
		_slam(float(phase_def.get("slam_radius", 7.0)))

	if pats.has("summon") and summon_cd <= 0.0:
		var sm = phase_def.get("summon", null)
		if typeof(sm) == TYPE_DICTIONARY:
			summon_cd = float(sm.get("cd", 12.0))
			_summon(String(sm.get("type", "hound")), int(sm.get("count", 2)))

	if pats.has("homing") and dist < 24.0 and homing_cd <= 0.0:
		homing_cd = float(phase_def.get("homing_cd", 6.0)) / rate
		fire_homing(int(phase_def.get("homing_count", 2)), dir)

	if pats.has("field") and dist < 22.0 and field_cd <= 0.0:
		field_cd = float(phase_def.get("field_cd", 9.0)) / rate
		spawn_field(float(phase_def.get("field_radius", 5.0)),
			float(phase_def.get("field_life", 5.0)))

	if pats.has("charge") and dist < 16.0 and dist > 4.0 and e.charge_cd <= 0.0:
		e.charge_cd = float(phase_def.get("charge_cd", 6.0)) / rate
		e.charge_dir = dir
		e.charge_windup = 0.8
		e.attack._show_telegraph(e.charge_dir)

func _legacy_boss_pattern(dist: float, flat: Vector3) -> void:
	var e := owner_enemy
	var idx: int = clampi(boss_phase, 0, 2)
	if dist < 22.0 and e.shoot_cd <= 0.0:
		e.shoot_cd = [1.5, 1.25, 1.0][idx]
		var spread: int = (5 if e.enemy_type == "warlord" else 3) + idx
		for i in range(spread):
			var a := (float(i) - (spread - 1) * 0.5) * 0.22
			e.attack._fire_projectile(flat.normalized().rotated(Vector3.UP, a))
	if dist < 16.0 and dist > 4.0 and e.charge_cd <= 0.0:
		e.charge_cd = [6.0, 5.0, 4.0][idx]
		e.charge_dir = flat.normalized()
		e.charge_windup = 0.8
		e.attack._show_telegraph(e.charge_dir)

## 회전 탄막 — 한 발씩 각도를 돌려 시간차로 쏜다.
func _sweep(count: int, base: Vector3) -> void:
	var e := owner_enemy
	var tree := e.get_tree()
	for i in range(count):
		if not is_instance_valid(e) or e.dead:
			return
		e.attack._fire_projectile(base.rotated(Vector3.UP, TAU * float(i) / float(count) * 0.9))
		await tree.create_timer(0.06, true, false, true).timeout

## 근접 충격파 — 반경 안의 플레이어만 때린다. 새 노드를 만들지 않는다.
func _slam(radius: float) -> void:
	var e := owner_enemy
	e.attack_anim_timer = maxf(e.attack_anim_timer, 0.45)
	CombatFeel.impact("slam")
	SoundManager.play("wall_break", -6.0)
	var pl := Battlefield.live_player()
	if pl and e.global_position.distance_to(pl.global_position) <= radius:
		pl.take_damage(e.contact_damage * 1.3, e.global_position)

## 잡몹 소환 — 월드의 기존 생성 경로를 그대로 쓴다.
func _summon(type: String, count: int) -> void:
	var e := owner_enemy
	var world = e.get_tree().current_scene
	if world == null or not world.has_method("_make_enemy"):
		return
	for i in range(count):
		var a := TAU * float(i) / float(maxi(1, count))
		world._make_enemy(type, e.global_position + Vector3(cos(a) * 4.0, 0, sin(a) * 4.0))
	SoundManager.play("night_start", -12.0)

## ── 하위 호환 ──
## 기존 EnemyMovement 가 쓰던 API. 새 FSM 의 판단 결과를 같은 형태로 돌려준다.
func _select_target(player: Node) -> Dictionary:
	if has_move:
		return {"pos": move_target, "has": true}
	return {"pos": Vector3.ZERO, "has": false}

## 현재 상태 이름 (디버그)
func state_name() -> String:
	return STATE_NAMES[state]

# ══════════════════════════════════════════════
#  신규 기믹 — 유도탄 / 장판
#  둘 다 기존 VfxPool · Projectile3D · take_damage 만 쓴다.
# ══════════════════════════════════════════════

## 유도탄 — 발사 후 플레이어 쪽으로 서서히 방향을 튼다.
## Projectile3D 에 유도 필드가 있으면 켜고, 없으면 일반 탄으로 나간다(회귀 없음).
func fire_homing(count: int, base_dir: Vector3) -> void:
	var e := owner_enemy
	var d := EnemyConfig.mon_behavior(e.enemy_type)
	var turn: float = float(d.get("turn", 2.6))
	var life: float = float(d.get("life", 3.2))
	var dmg_mult: float = float(d.get("damage", 0.8))
	for i in range(maxi(1, count)):
		var a := (float(i) - (count - 1) * 0.5) * 0.18
		var dir := base_dir.rotated(Vector3.UP, a)
		var proj := VfxPool.take_projectile(e.get_parent())
		if proj == null:
			continue
		proj.global_position = e.global_position + Vector3(0, 1.2, 0) + dir * 1.0
		if proj.has_method("setup"):
			proj.setup(dir, EnemyConfig.PROJECTILE_SPEED * 0.8,
				e.contact_damage * dmg_mult, life)
		if "homing_turn" in proj:
			proj.homing_turn = turn
		if "homing_target" in proj:
			proj.homing_target = Battlefield.live_player()
	SoundManager.play_pitched("turret_fire", -10.0, 0.85)

## 장판 — 지정 위치에 원판을 깔고, 안에 있는 플레이어를 주기적으로 때린다.
## 노드는 VfxPool 에서 빌려 쓰고 수명이 끝나면 돌려준다.
func spawn_field(radius: float, life: float, at: Vector3 = Vector3.INF) -> void:
	var e := owner_enemy
	var parent := e.get_parent()
	if parent == null:
		return
	var pos: Vector3 = at if at != Vector3.INF else e.global_position
	var d := EnemyConfig.mon_behavior(e.enemy_type)
	var col: Color = Color(0.9, 0.4, 0.3)
	var cd = d.get("color", null)
	if typeof(cd) == TYPE_ARRAY and cd.size() >= 3:
		col = Color(float(cd[0]), float(cd[1]), float(cd[2]))

	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.08
	disc.radial_segments = 16
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, 0.30)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 2.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var fx := VfxPool.take_fx(parent, disc, m)
	fx.global_position = Vector3(pos.x, pos.y + 0.06, pos.z)

	var tick: float = float(d.get("tick", 0.5))
	var dmg: float = e.contact_damage * float(d.get("damage", 0.35))
	var slow: float = float(d.get("slow", 1.0))
	var tree := e.get_tree()
	var elapsed := 0.0
	var guard := 0
	while elapsed < life and guard < 200:
		guard += 1
		await tree.create_timer(tick, true, false, true).timeout
		elapsed += tick
		if not is_instance_valid(fx):
			return
		var pl := Battlefield.live_player()
		if pl and pl.global_position.distance_to(fx.global_position) <= radius:
			pl.take_damage(dmg, fx.global_position)
			if slow < 1.0 and "slow_timer" in pl:
				pl.slow_timer = maxf(pl.slow_timer, tick * 1.5)
	VfxPool.give_fx(fx)

## 애니메이션 노드가 `_flash` 를 갖고 있을 때만 부른다.
## 모델을 교체하면 다른 애니메이션 스크립트가 붙을 수 있어, 없는 함수를 부르면 튕긴다.
func _safe_flash(a) -> void:
	if a != null and is_instance_valid(a) and a.has_method("_flash"):
		a._flash()
