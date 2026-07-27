extends CharacterBody3D

const DASH_SPEED := 26.0
const DASH_DURATION := 0.16
const DASH_COOLDOWN := 0.9
const ATTACK_COOLDOWN := 0.34
const ATTACK_RANGE := 4.2
const ATTACK_HALF_ANGLE := 1.0
const RANGED_COOLDOWN := 2.6
const RANGED_RANGE := 16.0
const PARRY_COOLDOWN := 4.0
const PARRY_WINDOW := 0.25
const ULT_RADIUS := 10.0
const GRAVITY := 24.0
const JUMP_SPEED := 9.0

signal died
signal hp_changed
signal ult_changed

var max_hp := 100.0
var hp := 100.0
var ult_gauge := 0.0
var ult_max := 100.0

var facing_angle := 0.0
var dash_dir := Vector3.ZERO
var dash_timer := 0.0
var dash_cd := 0.0
var atk_cd := 0.0
var ranged_cd := 0.0
var parry_cd := 0.0
var parry_timer := 0.0
var invuln_timer := 0.0
var attack_anim_timer := 0.0

var step_timer := 0.0
const STEP_INTERVAL := 0.34
const TURN_SPEED := 12.0      ## 모델 회전 보간 속도 (자연스러운 몸 돌리기)
const ACCEL := 22.0           ## 가감속 (즉시 정지/출발 방지)

## PlayerStats 연동 (특성/아이템이 실시간 반영됨)
var move_speed := 7.0
var slash_damage := 1.0

var model_yaw := 0.0
var model: Node3D
var skel: Skeleton3D
var spine_bones: Array[int] = []
var lean_pitch := 0.0        ## 가감속에 따른 앞뒤 기울기
var lean_roll := 0.0         ## 방향 전환에 따른 좌우 기울기
var prev_velocity := Vector3.ZERO
var land_squash := 0.0
var was_on_floor := true
var hit_anim_timer := 0.0
var jump_buffer := 0.0
var combo_step := 0
var combo_timer := 0.0
const COMBO_WINDOW := 0.85
var base_scale := Vector3.ONE
var weapon_attach: BoneAttachment3D = null
var weapon_mesh: MeshInstance3D = null   ## hero.tscn 에 구워진 원본 스케일 (덮어쓰면 캐릭터가 사라진다)
var anim: AnimationPlayer
var cam_rig: Node3D
var camera: Camera3D
var mesh_instances: Array = []

## ── 카메라 흔들림 (트라우마 모델) ──
## 이전에는 shake_time 동안 매 프레임 randf 로 오프셋을 찍어서 "지글거리는" 느낌이었다.
## 이제 trauma 를 쌓고 제곱으로 감쇠시켜, 강한 타격은 묵직하게 시작해 부드럽게 잦아든다.
const SHAKE_TRAUMA_GAIN := 2.2    ## mag → trauma 변환 계수
const SHAKE_MAX_OFFSET := 0.09    ## trauma 1.0 일 때 최대 화면 오프셋
const SHAKE_MAX_ROLL := 0.035     ## trauma 1.0 일 때 최대 롤(라디안)
const SHAKE_FREQ := 26.0          ## 흔들림 주파수
const SHAKE_KICK_GAIN := 0.16     ## 방향성 킥 세기
const SHAKE_KICK_DAMP := 9.0      ## 킥 복귀 속도

var shake_trauma := 0.0           ## 0~1
var shake_decay := 4.0            ## 초당 trauma 감소량
var shake_kick := Vector3.ZERO    ## 타격 방향 킥 (한 방향으로 밀리는 느낌)
var shake_kick_vel := Vector2.ZERO
var _shake_seed := 0.0
# 하위 호환 — 외부/구코드가 참조할 수 있는 필드
var shake_time := 0.0
var shake_mag := 0.0

## ── 행동 모듈 ──
var movement: PlayerMovement
var combat: PlayerCombat
var animation: PlayerAnimation
var input: PlayerInput
var skill: PlayerSkill


## 행동 모듈을 자식 노드로 붙인다. 상태는 이 클래스가 소유하고,
## 모듈은 owner_player 를 통해 읽고 쓴다.
func _create_modules() -> void:
	movement = PlayerMovement.new()
	movement.name = "PlayerMovement"
	movement.setup(self)
	add_child(movement)

	combat = PlayerCombat.new()
	combat.name = "PlayerCombat"
	combat.setup(self)
	add_child(combat)

	animation = PlayerAnimation.new()
	animation.name = "PlayerAnimation"
	animation.setup(self)
	add_child(animation)

	input = PlayerInput.new()
	input.name = "PlayerInput"
	input.setup(self)
	add_child(input)

	skill = PlayerSkill.new()
	skill.name = "PlayerSkill"
	skill.setup(self)
	add_child(skill)

func _ready() -> void:
	add_to_group("player")
	_create_modules()
	collision_layer = 2
	collision_mask = 1
	# 낮은 잔해에 걸리지 않게 계단 오르기를 허용한다
	floor_max_angle = deg_to_rad(60.0)
	floor_snap_length = 0.5
	safe_margin = 0.02

	max_hp = PlayerStats.get_final_max_hp()
	hp = max_hp
	PlayerStats.stats_changed.connect(_refresh_stats)
	_refresh_stats()

	var shape := CollisionShape3D.new()
	var caps := CapsuleShape3D.new()
	caps.radius = 0.45
	caps.height = 1.6
	shape.shape = caps
	shape.position.y = 0.8
	add_child(shape)

	var packed: PackedScene = load("res://assets3d/chars/hero.tscn")
	model = packed.instantiate()
	add_child(model)
	anim = animation._find_anim_player(model)
	animation._collect_meshes(model)
	base_scale = model.scale
	skel = model.find_child("Skeleton3D", true, false)
	if skel:
		for bone_name in ["mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2"]:
			var bi := skel.find_bone(bone_name)
			if bi >= 0:
				spine_bones.append(bi)
	animation._play_anim("idle")
	animation._setup_weapon_attach()
	PlayerStats.item_equipped.connect(func(_i, _s): animation._refresh_weapon_visual())
	animation._refresh_weapon_visual()

	cam_rig = Node3D.new()
	add_child(cam_rig)
	camera = Camera3D.new()
	camera.position = Vector3(0, 8.5, 7.0)
	camera.rotation_degrees = Vector3(-50, 0, 0)
	camera.fov = 62
	cam_rig.add_child(camera)
	camera.make_current()

## 특성이 뽑히거나 아이템을 장착할 때 호출되어 실시간 반영된다.
func _refresh_stats() -> void:
	move_speed = PlayerStats.get_final_speed()
	slash_damage = PlayerStats.get_slash_damage()
	var new_max := PlayerStats.get_final_max_hp()
	if new_max != max_hp:
		var ratio: float = (hp / max_hp) if max_hp > 0.0 else 1.0
		max_hp = new_max
		hp = clampf(max_hp * ratio, 1.0, max_hp)
		hp_changed.emit()

func _physics_process(delta: float) -> void:
	if hp <= 0:
		return

	if atk_cd > 0: atk_cd -= delta
	if dash_cd > 0: dash_cd -= delta
	if ranged_cd > 0: ranged_cd -= delta
	if parry_cd > 0: parry_cd -= delta
	if invuln_timer > 0: invuln_timer -= delta
	if parry_timer > 0: parry_timer -= delta
	if attack_anim_timer > 0: attack_anim_timer -= delta
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_step = 0

	input.poll(delta)
	movement._aim_at_mouse()

	if Input.is_key_pressed(KEY_SHIFT) and dash_cd <= 0 and dash_timer <= 0:
		movement._start_dash()

	var target_h := Vector3.ZERO
	if dash_timer > 0:
		dash_timer -= delta
		target_h = dash_dir * DASH_SPEED
	elif input.move_dir.length() > 0:
		target_h = input.move_dir * move_speed

	# 가감속 보간 — 즉시 정지/출발하지 않아 움직임이 자연스러워진다
	var accel := ACCEL if dash_timer <= 0 else ACCEL * 4.0
	velocity.x = move_toward(velocity.x, target_h.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_h.z, accel * delta)
	if jump_buffer > 0.0:
		jump_buffer -= delta

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if jump_buffer > 0.0:
			velocity.y = JUMP_SPEED
			jump_buffer = 0.0
			SoundManager.play("dash", -14.0)
		else:
			velocity.y = 0.0

	move_and_slide()

	var planar := Vector2(velocity.x, velocity.z).length()
	var moving := planar > 0.4

	# 이동 중에는 진행 방향을 바라보고, 공격/정지 시에는 마우스를 바라본다
	var desired_yaw := facing_angle
	if moving and dash_timer <= 0 and attack_anim_timer <= 0:
		desired_yaw = atan2(velocity.x, velocity.z)
	elif dash_timer > 0:
		desired_yaw = atan2(dash_dir.x, dash_dir.z)
	model_yaw = lerp_angle(model_yaw, desired_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))
	if model:
		model.rotation.y = model_yaw

	if hit_anim_timer > 0:
		hit_anim_timer -= delta
	elif attack_anim_timer <= 0:
		if dash_timer > 0:
			animation._play_anim("sprint")
		elif moving:
			# 조준 방향과 이동 방향이 반대면 뒷걸음 클립을 쓴다
			var move_dir := Vector3(velocity.x, 0, velocity.z).normalized()
			var aim := facing_dir()
			if anim and anim.has_animation("walk_back") and move_dir.dot(aim) < -0.35:
				animation._play_anim("walk_back")
			else:
				animation._play_anim("walk")
		elif GameManager.phase == GameManager.Phase.NIGHT and anim and anim.has_animation("idle_combat"):
			animation._play_anim("idle_combat")
		else:
			animation._play_anim("idle")
		# 실제 속도에 맞춰 애니메이션 재생 속도를 맞춰 미끄러짐을 줄인다
		if anim and moving and dash_timer <= 0:
			anim.speed_scale = clampf(planar / 7.0, 0.6, 2.2)
		elif anim:
			anim.speed_scale = 1.0

	if moving:
		step_timer -= delta * clampf(planar / 7.0, 0.5, 2.5)
		if step_timer <= 0:
			step_timer = STEP_INTERVAL
			SoundManager.play("footstep", -10.0)

	# 어택 버퍼 + 인풋 큐를 거쳐 스킬을 발동한다
	skill.tick()

	animation._update_procedural_motion(delta, planar)

	cam_rig.global_position = global_position
	_update_shake(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		jump_buffer = 0.16

func facing_dir() -> Vector3:
	return Vector3(sin(facing_angle), 0, cos(facing_angle))

## ── 카메라 흔들림 ──
## trauma 를 쌓고 제곱 감쇠시킨다. mag 가 클수록 초기 진폭이 크고, 감쇠는 dur 로 조절한다.
func shake(mag: float, dur: float) -> void:
	shake_from(mag, dur, Vector3.ZERO)

## 방향성 킥이 있는 흔들림 — dir 방향으로 카메라가 한 번 밀린 뒤 되돌아온다.
## 정면에서 맞았는지 옆에서 맞았는지가 화면으로 읽힌다.
func shake_from(mag: float, dur: float, dir: Vector3) -> void:
	shake_trauma = clampf(maxf(shake_trauma, mag * SHAKE_TRAUMA_GAIN), 0.0, 1.0)
	shake_decay = clampf(1.0 / maxf(dur, 0.05), 1.2, 12.0)
	# 하위 호환 필드도 갱신
	shake_mag = maxf(shake_mag, mag)
	shake_time = maxf(shake_time, dur)
	if dir.length_squared() > 0.0001:
		var flat := Vector3(dir.x, 0, dir.z).normalized()
		# 월드 방향을 카메라 화면축(좌우/상하)으로 투영한다
		shake_kick_vel += Vector2(flat.x, -flat.z) * mag * SHAKE_KICK_GAIN

func _update_shake(delta: float) -> void:
	# 킥: 스프링으로 원점 복귀 (한 방향으로 밀렸다가 돌아온다)
	shake_kick_vel = shake_kick_vel.lerp(Vector2.ZERO, clampf(delta * SHAKE_KICK_DAMP, 0.0, 1.0))
	shake_kick.x = lerpf(shake_kick.x, shake_kick_vel.x, clampf(delta * 18.0, 0.0, 1.0))
	shake_kick.y = lerpf(shake_kick.y, shake_kick_vel.y, clampf(delta * 18.0, 0.0, 1.0))

	if shake_trauma > 0.0:
		shake_trauma = maxf(0.0, shake_trauma - shake_decay * delta)
		_shake_seed += delta * SHAKE_FREQ
		# 제곱 감쇠 — 끝맺음이 부드럽다 (선형이면 뚝 끊긴 느낌)
		var amp: float = shake_trauma * shake_trauma * SHAKE_MAX_OFFSET
		# 서로 다른 위상의 사인파 합 — 순수 난수보다 "카메라가 흔들리는" 느낌에 가깝다
		var ox := sin(_shake_seed * 1.00) * 0.6 + sin(_shake_seed * 2.31 + 1.7) * 0.4
		var oy := sin(_shake_seed * 1.37 + 2.4) * 0.6 + sin(_shake_seed * 2.91) * 0.4
		camera.h_offset = ox * amp + shake_kick.x
		camera.v_offset = oy * amp + shake_kick.y
		# 아주 약한 롤(기울기) — 큰 타격에서만 체감된다
		camera.rotation.z = sin(_shake_seed * 0.83) * shake_trauma * shake_trauma * SHAKE_MAX_ROLL
	else:
		shake_time = 0.0
		shake_mag = 0.0
		camera.h_offset = shake_kick.x
		camera.v_offset = shake_kick.y
		camera.rotation.z = lerpf(camera.rotation.z, 0.0, clampf(delta * 10.0, 0.0, 1.0))

## 피해를 받는다. from 이 주어지면 그 방향으로 카메라가 킥된다(어디서 맞았는지 읽힌다).
func take_damage(amount: float, from: Vector3 = Vector3.ZERO) -> void:
	if invuln_timer > 0 or hp <= 0:
		return
	if parry_timer > 0:
		combat._parry_success()
		return
	hp -= amount
	hp_changed.emit()
	invuln_timer = 0.35
	# 피해량이 클수록 더 크게 흔들린다 (전부 같은 세기로 흔들리면 위기감이 안 생긴다)
	var weight: float = clampf(amount / 25.0, 0.35, 1.6)
	var kick_dir := Vector3.ZERO
	if from.length_squared() > 0.0001:
		kick_dir = (global_position - from).normalized()   ## 맞은 반대쪽으로 밀린다
	shake_from(0.13 * weight, 0.18, kick_dir)
	# 큰 피해에는 붉은 화면 플래시로 위험을 즉시 알린다
	if amount >= 14.0:
		CombatFeel.screen_flash(Color(0.85, 0.05, 0.05), 0.2, 0.0, 0.22)
	SoundManager.play("player_hurt")
	animation._flash()
	if hp > 0 and anim and anim.has_animation("hit"):
		hit_anim_timer = 0.32
		anim.speed_scale = 1.6
		anim.play("hit")
	if hp <= 0:
		hp = 0
		animation._play_anim("die")
		died.emit()
