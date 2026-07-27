extends Node
class_name EnemyMovement
## 적의 물리 이동 실행 — 경직/돌진/브레인 의도 이동 + 벽 회피 + 넉백 감쇠 + 접촉 피해.
##
## 역할 분담:
##   EnemyBrain     "어디로 갈지" (목표점·속도배율·바라볼 방향)
##   EnemyMovement  "어떻게 갈지" (벽 회피, 중력, 넉백, 실제 move_and_slide, 접촉 판정)

var owner_enemy: CharacterBody3D

## ── 벽 회피 ──
var _avoid_timer := 0.0
var _avoid_steer := Vector3.ZERO      ## 회피 조향 벡터 (부드럽게 유지)

## ── 목적지 갱신 ──
## 브레인은 매 프레임 의도를 만들지만, 실제로 향하는 점은 간격을 두고 갱신한다.
## 매 프레임 갱신하면 목표가 미세하게 흔들려 몸이 좌우로 떠는 것처럼 보인다.
var _path_timer := 0.0
var _path_point := Vector3.ZERO
var _has_path := false

## ── 서로 겹치지 않기 ──
var _sep_timer := 0.0
var _sep_vec := Vector3.ZERO

## ── 발소리 ──
var _step_accum := 0.0

func setup(e: CharacterBody3D) -> void:
	owner_enemy = e

## 매 물리 프레임 호출.
func physics_step(delta: float) -> void:
	var e := owner_enemy
	if e.hit_cd > 0: e.hit_cd -= delta
	if e.attack_anim_timer > 0:
		e.attack_anim_timer -= delta
	if e.hurt_anim_timer > 0:
		e.hurt_anim_timer -= delta
	if e.attack_recover > 0:
		e.attack_recover -= delta
	_decay_knockback(delta)

	# ── 경직 ──
	if e.stun_timer > 0:
		e.stun_timer -= delta
		e.brain.think(delta)          ## 경직 중에도 시야/기억은 갱신한다
		_apply_planar(Vector3.ZERO)
		_apply_gravity(delta)
		e.move_and_slide()
		return

	if e.shoot_cd > 0: e.shoot_cd -= delta
	if e.charge_cd > 0: e.charge_cd -= delta

	# ── 돌진 예고 ──
	if e.charge_windup > 0.0:
		e.charge_windup -= delta
		e.brain.think(delta)
		_apply_planar(Vector3.ZERO)
		_apply_gravity(delta)
		e.move_and_slide()
		if e.charge_windup <= 0.0:
			e.charge_dash = EnemyConfig.CHARGE_DASH_TIME
			_charge_hit_landed = false
			if e.telegraph and is_instance_valid(e.telegraph):
				e.telegraph.queue_free()
				e.telegraph = null
		return

	# ── 돌진 ──
	if e.charge_dash > 0.0:
		e.charge_dash -= delta
		_apply_planar(e.charge_dir * e.speed * EnemyConfig.CHARGE_SPEED_MULT)
		if e.is_flying:
			e.velocity.y = e.knock_vel.y
		else:
			_apply_gravity(delta)
		e.move_and_slide()
		# 돌진 중 접촉 판정
		var pl := Battlefield.live_player()
		if pl and e.hit_cd <= 0:
			var fl: Vector3 = pl.global_position - e.global_position
			fl.y = 0
			if fl.length() < e.hit_radius + 1.1:
				e.hit_cd = 0.8
				_charge_hit_landed = true
				pl.take_damage(e.contact_damage * EnemyConfig.CHARGE_HIT_MULT, e.global_position)
		# 돌진이 끝났는데 아무것도 못 맞혔다 → 브레인에 알려 재배치하게 한다
		if e.charge_dash <= 0.0 and not _charge_hit_landed:
			e.brain.report_whiff()
		return

	# ══ 일반 이동 — 브레인의 의도를 실행한다 ══
	e.brain.think(delta)

	var moving := false
	var desired := Vector3.ZERO

	# 공격 직후에는 굳어 있다 (때리고 바로 따라붙지 않는다)
	if e.attack_recover > 0.0:
		_apply_planar(Vector3.ZERO)
		_apply_gravity(delta)
		e.move_and_slide()
		_face(e.brain.face_dir, delta)
		_update_anim(0.0, false)
		_contact_damage()
		return

	if _refresh_path(delta):
		var to_target: Vector3 = _path_point - e.global_position
		to_target.y = 0
		if to_target.length() > EnemyConfig.ARRIVE_EPSILON:
			var dir := to_target.normalized()
			# 벽 회피 조향을 더한다
			dir = _steer_around_walls(dir, delta)
			# 동료와 겹치지 않게 밀어낸다 (한 점에 뭉쳐 서로를 통과하는 것 방지)
			dir = (dir + _separation(delta) * EnemyConfig.SEPARATION_FORCE).normalized()
			desired = dir * e.speed * e.brain.speed_mult
			moving = true

	# 경사면을 따라간다 — 바닥 법선에 투영해야 오르막에서 몸이 뜨지 않는다
	if moving and not e.is_flying and e.is_on_floor():
		desired = _project_on_floor(desired)

	_apply_planar(desired)
	_apply_gravity(delta)
	e.move_and_slide()

	# ── 모델 방향 ──
	# 브레인이 바라볼 방향을 지정했으면 그것을 따른다 (후진하며 응시 등)
	_face(e.brain.face_dir if e.brain.face_dir.length_squared() > 0.01 else desired, delta)

	# ── 애니메이션 · 발소리 ──
	var planar := Vector2(e.velocity.x, e.velocity.z).length()
	_update_anim(planar, moving)
	_footsteps(planar, delta)

	_contact_damage()

## ── 방향 보간 ──
## 즉시 회전은 로봇처럼 보인다. 각도를 보간해 몸이 돌아가는 것이 보이게 한다.
func _face(look: Vector3, delta: float) -> void:
	var e := owner_enemy
	if e.model == null or look.length_squared() <= 0.01:
		return
	var want := atan2(look.x, look.z)
	e.model.rotation.y = lerp_angle(e.model.rotation.y, want,
		clampf(EnemyConfig.TURN_SPEED * delta, 0.0, 1.0))

## ── 목적지 갱신 ──
## 간격을 두고 갱신하되, 목표가 크게 움직였으면 기다리지 않는다.
## 반환값: 향할 지점이 있는가.
func _refresh_path(delta: float) -> bool:
	var e := owner_enemy
	if not e.brain.has_move:
		_has_path = false
		return false
	_path_timer -= delta
	var slipped: bool = not _has_path \
		or _path_point.distance_to(e.brain.move_target) > EnemyConfig.REPATH_SLIP
	if _path_timer <= 0.0 or slipped:
		_path_timer = EnemyConfig.REPATH_INTERVAL
		_path_point = e.brain.move_target
		_has_path = true
	return _has_path

## ── 서로 겹치지 않기 ──
## 가까운 동료에게서 멀어지는 방향을 더한다. 이게 없으면 여러 마리가 완전히
## 같은 점을 향해 서로의 몸을 통과하며 한 덩어리로 뭉친다.
func _separation(delta: float) -> Vector3:
	_sep_timer -= delta
	if _sep_timer > 0.0:
		return _sep_vec
	_sep_timer = EnemyConfig.SEPARATION_INTERVAL

	var e := owner_enemy
	var push := Vector3.ZERO
	var seen := 0
	# Battlefield 가 이미 캐시해 둔 목록을 쓴다 (매번 그룹을 훑으면 최적화가 되돌아간다)
	for other in Battlefield.enemies:
		if other == e or not is_instance_valid(other) or other.dead:
			continue
		var away: Vector3 = e.global_position - other.global_position
		away.y = 0
		var d := away.length()
		if d > EnemyConfig.SEPARATION_RADIUS:
			continue
		if d < 0.05:
			# 완전히 겹쳤다 — 일관된 방향으로 흩는다 (매 프레임 랜덤이면 떤다)
			away = Vector3(sin(float(e.get_instance_id())), 0, cos(float(e.get_instance_id())))
			d = 0.05
		# 가까울수록 세게 민다
		push += away.normalized() * (1.0 - d / EnemyConfig.SEPARATION_RADIUS)
		seen += 1
		if seen >= EnemyConfig.SEPARATION_MAX_NEIGHBORS:
			break
	_sep_vec = push.limit_length(1.0)
	return _sep_vec

## 수평 이동을 바닥 경사면에 투영한다.
func _project_on_floor(v: Vector3) -> Vector3:
	var n: Vector3 = owner_enemy.get_floor_normal()
	if n.length_squared() < 0.01:
		return v
	var out: Vector3 = v.slide(n)
	# 투영하면 길이가 줄어든다 — 오르막에서 느려지지 않게 원래 속력으로 되돌린다
	if out.length() > 0.01:
		out = out.normalized() * v.length()
	return out

## ── 애니메이션 ──
## 실제 이동 속력에 배속을 맞춘다. 느리게 걷는데 다리만 빨리 움직이면
## 발이 바닥을 긁는 것처럼 보인다 (미끄러지는 느낌의 절반은 여기서 온다).
func _update_anim(planar_speed: float, moving: bool) -> void:
	var e := owner_enemy
	if e.attack_anim_timer > 0 or e.hurt_anim_timer > 0:
		if e.anim:
			e.anim.speed_scale = 1.0
		return
	e.animation._play(e.anim_move if moving else e.anim_idle)
	if e.anim == null:
		return
	if moving:
		e.anim.speed_scale = clampf(planar_speed / EnemyConfig.ANIM_SPEED_REF,
			EnemyConfig.ANIM_SPEED_MIN, EnemyConfig.ANIM_SPEED_MAX)
	else:
		e.anim.speed_scale = 1.0

## ── 발소리 ──
## 시간이 아니라 **이동 거리**로 센다. 그래야 느리게 걸으면 발소리도 느려진다.
func _footsteps(planar_speed: float, delta: float) -> void:
	var e := owner_enemy
	if e.is_flying or not e.is_on_floor() or planar_speed < EnemyConfig.STEP_MIN_SPEED:
		return
	_step_accum += planar_speed * delta
	if _step_accum < EnemyConfig.STEP_STRIDE:
		return
	_step_accum = 0.0
	# 멀리 있는 적의 발소리까지 다 들리면 시끄럽다 — 거리로 볼륨을 깎는다
	var pl := Battlefield.live_player()
	if pl == null:
		return
	var d: float = e.global_position.distance_to(pl.global_position)
	if d > 22.0:
		return
	var vol: float = lerpf(-16.0, -34.0, clampf(d / 22.0, 0.0, 1.0))
	# 큰 몹일수록 낮은 소리
	var pitch: float = clampf(1.25 - e.hit_radius * 0.28, 0.6, 1.2)
	SoundManager.play_pitched("footstep", vol, pitch, 0.08)

## ── 이동 헬퍼 ──

## 수평 속도를 설정한다. 넉백 속도가 남아 있으면 그것이 더해진다.
func _apply_planar(target: Vector3) -> void:
	var e := owner_enemy
	e.velocity.x = target.x + e.knock_vel.x
	e.velocity.z = target.z + e.knock_vel.z

func _apply_gravity(delta: float) -> void:
	var e := owner_enemy
	if e.is_flying:
		e.velocity.y = e.knock_vel.y
	elif not e.is_on_floor():
		e.velocity.y -= EnemyConfig.GRAVITY * delta
	elif e.knock_vel.y > 0.0:
		e.velocity.y = e.knock_vel.y          ## 넉백으로 떠오르는 중
	else:
		# 접지 중에는 아래로 눌러 준다. 0 으로 두면 내리막·계단에서 몸이 뜨고,
		# 그 뜬 프레임이 이어져 공중을 미끄러지는 것처럼 보인다.
		e.velocity.y = -EnemyConfig.GROUND_STICK

## 넉백 속도를 감쇠시킨다 (여러 프레임에 걸쳐 밀려나므로 맞은 것이 눈에 보인다)
func _decay_knockback(delta: float) -> void:
	var e := owner_enemy
	if e.knock_vel.length_squared() < 0.01:
		e.knock_vel = Vector3.ZERO
		return
	var f: float = 1.0 - clampf(EnemyConfig.KNOCKBACK_DAMP * delta, 0.0, 1.0)
	e.knock_vel *= f

## ── 벽 회피 ──
## 전방/좌/우로 짧은 레이를 쏴서 막힌 쪽을 피하도록 방향을 튼다.
## 목표를 향한 직선이 벽에 막혀 있으면, 열린 쪽으로 미끄러지듯 우회한다.
## (기존에는 벽에 몸을 비비며 제자리걸음을 했다)
func _steer_around_walls(dir: Vector3, delta: float) -> Vector3:
	var e := owner_enemy
	if e.is_flying:
		return dir            ## 비행 몹은 지형을 넘어간다

	_avoid_timer -= delta
	if _avoid_timer <= 0.0:
		_avoid_timer = EnemyConfig.AVOID_INTERVAL
		_avoid_steer = _probe_walls(dir)

	if _avoid_steer.length_squared() < 0.0001:
		return dir
	return (dir + _avoid_steer * EnemyConfig.AVOID_STRENGTH).normalized()

## 세 방향으로 레이를 쏴서 조향 벡터를 만든다.
func _probe_walls(dir: Vector3) -> Vector3:
	var e := owner_enemy
	var space := e.get_world_3d().direct_space_state
	var origin: Vector3 = e.global_position + Vector3(0, 0.8, 0)
	var right := Vector3(dir.z, 0, -dir.x)
	var steer := Vector3.ZERO

	var front := _ray_blocked(space, origin, dir * EnemyConfig.AVOID_PROBE)
	var left_b := _ray_blocked(space, origin, (-right + dir * 0.4).normalized() * EnemyConfig.AVOID_SIDE_PROBE)
	var right_b := _ray_blocked(space, origin, (right + dir * 0.4).normalized() * EnemyConfig.AVOID_SIDE_PROBE)

	if front:
		# 정면이 막혔다 — 열린 쪽으로 크게 튼다
		if left_b and not right_b:
			steer += right
		elif right_b and not left_b:
			steer -= right
		else:
			# 양쪽 다 막혔거나 양쪽 다 열렸다 — 일관된 방향으로 돈다 (좌우로 떠는 것 방지)
			steer += right * (1.0 if e.get_instance_id() % 2 == 0 else -1.0)
	else:
		# 측면만 스치는 경우 살짝만 밀어낸다
		if left_b:
			steer += right * 0.5
		if right_b:
			steer -= right * 0.5
	return steer

func _ray_blocked(space: PhysicsDirectSpaceState3D, origin: Vector3, offset: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(origin, origin + offset)
	q.collision_mask = 1          ## 지형/건물만
	q.exclude = [owner_enemy.get_rid()]
	return not space.intersect_ray(q).is_empty()

## ── 접촉 피해 ──
var _charge_hit_landed := false

func _contact_damage() -> void:
	var e := owner_enemy

	# 방벽/포탑과의 충돌
	for i in range(e.get_slide_collision_count()):
		var collision := e.get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and e.hit_cd <= 0 and collider.is_in_group("defenses") and collider.has_method("take_damage"):
			e.attack._attack()
			collider.take_damage(e.contact_damage)
			break

	# 플레이어 접촉 피해 — 어디서 맞았는지 카메라에 전달하기 위해 위치를 넘긴다
	var player := Battlefield.live_player()
	if player and e.hit_cd <= 0:
		var flat: Vector3 = player.global_position - e.global_position
		flat.y = 0
		if flat.length() < e.hit_radius + 0.9:
			e.attack._attack()
			player.take_damage(e.contact_damage, e.global_position)

	# 방주(기지 코어) 접촉 피해
	var base_node := Battlefield.live_base()
	if base_node and e.hit_cd <= 0:
		var flat2: Vector3 = base_node.global_position - e.global_position
		flat2.y = 0
		if flat2.length() < e.hit_radius + 2.4:
			e.attack._attack()
			base_node.take_damage(e.contact_damage)
