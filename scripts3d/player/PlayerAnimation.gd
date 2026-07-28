extends Node
class_name PlayerAnimation
## 애니메이션 재생·절차적 2차 모션·피격 플래시·무기 부착.
## Player3D(owner)의 상태를 읽고 쓰는 행동 모듈이다.

var owner_player: CharacterBody3D

func setup(p: CharacterBody3D) -> void:
	owner_player = p

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var found := _find_anim_player(c)
		if found:
			return found
	return null

func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		owner_player.mesh_instances.append(node)
	for c in node.get_children():
		_collect_meshes(c)

func _play_anim(name: String) -> void:
	if owner_player.anim == null:
		return
	if not owner_player.anim.has_animation(name):
		return
	if owner_player.anim.current_animation == name:
		return
	owner_player.anim.play(name)

## 절차적 2차 모션 — 애니메이션 클립을 늘리지 않고도 "살아있는" 느낌을 만든다.
##  1) 가속/감속에 따라 몸이 앞뒤로 기운다
##  2) 방향을 틀 때 몸이 안쪽으로 기운다 (뱅킹)
##  3) 착지 시 스쿼시
##  4) 걸을 때 상체(척추)가 조준 방향으로 비틀린다 — 탑다운 게임의 핵심 트릭
func _update_procedural_motion(delta: float, planar: float) -> void:
	if owner_player.model == null:
		return

	var accel_vec: Vector3 = (owner_player.velocity - owner_player.prev_velocity) / maxf(delta, 0.0001)
	owner_player.prev_velocity = owner_player.velocity

	# 진행 방향 기준 전후/좌우 가속 성분
	var fwd := Vector3(sin(owner_player.model_yaw), 0, cos(owner_player.model_yaw))
	var right := Vector3(fwd.z, 0, -fwd.x)
	var a_fwd: float = clampf(accel_vec.dot(fwd) * 0.006, -0.22, 0.22)
	var a_side: float = clampf(accel_vec.dot(right) * 0.005, -0.20, 0.20)

	owner_player.lean_pitch = lerpf(owner_player.lean_pitch, a_fwd, clampf(delta * 9.0, 0.0, 1.0))
	owner_player.lean_roll = lerpf(owner_player.lean_roll, -a_side, clampf(delta * 9.0, 0.0, 1.0))

	# 착지 스쿼시
	var on_floor := owner_player.is_on_floor()
	if on_floor and not owner_player.was_on_floor:
		owner_player.land_squash = 0.25
	owner_player.was_on_floor = on_floor
	if owner_player.land_squash > 0.0:
		owner_player.land_squash = maxf(0.0, owner_player.land_squash - delta * 2.2)

	owner_player.model.rotation.x = owner_player.lean_pitch
	owner_player.model.rotation.z = owner_player.lean_roll
	# 원본 스케일에 곱한다 (덮어쓰면 92.5배 스케일이 사라져 캐릭터가 안 보인다)
	var squash := Vector3(1.0 + owner_player.land_squash * 0.25, 1.0 - owner_player.land_squash * 0.5, 1.0 + owner_player.land_squash * 0.25)
	owner_player.model.scale = owner_player.base_scale * squash

	# 상체를 조준 방향으로 비틀기 — 애니메이션이 만든 현재 포즈 위에 얹는다
	if owner_player.skel and owner_player.spine_bones.size() > 0:
		var twist: float = wrapf(owner_player.facing_angle - owner_player.model_yaw, -PI, PI)
		twist = clampf(twist, -0.9, 0.9)
		var per_bone: float = twist / float(owner_player.spine_bones.size())
		for bi in owner_player.spine_bones:
			var cur: Quaternion = owner_player.skel.get_bone_pose_rotation(bi)
			owner_player.skel.set_bone_pose_rotation(bi, cur * Quaternion(Vector3.UP, per_bone))

func _flash() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.35, 0.35)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.2, 0.2)
	m.emission_energy_multiplier = 1.5
	for mi in owner_player.mesh_instances:
		if is_instance_valid(mi):
			mi.material_override = m
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(func():
		for mi in owner_player.mesh_instances:
			if is_instance_valid(mi):
				mi.material_override = null
	)

## 오른손 본에 무기를 부착한다 (장착 무기 스킨이 실제로 손에 들린다)
func _setup_weapon_attach() -> void:
	if owner_player.skel == null:
		return
	var hand: int = owner_player.skel.find_bone("mixamorig_RightHand")
	if hand < 0:
		hand = owner_player.skel.find_bone("mixamorig_RightHandIndex1")
	if hand < 0:
		return
	owner_player.weapon_attach = BoneAttachment3D.new()
	owner_player.weapon_attach.bone_idx = hand
	owner_player.skel.add_child(owner_player.weapon_attach)

	owner_player.weapon_mesh = MeshInstance3D.new()
	# 손 기준 위치/방향 보정
	owner_player.weapon_mesh.position = Vector3(0.0, 0.06, 0.02)
	owner_player.weapon_mesh.rotation_degrees = Vector3(-78, 0, 0)
	owner_player.weapon_attach.add_child(owner_player.weapon_mesh)

## 장착한 무기의 스킨을 손에 반영
func _refresh_weapon_visual() -> void:
	if owner_player.weapon_mesh == null:
		return
	var w: ItemData = PlayerStats.equipped.get("weapon", null)
	if w == null:
		owner_player.weapon_mesh.visible = false
		return
	owner_player.weapon_mesh.visible = true

	# data/models.json 의 weapons 에 실제 모델이 있으면 그것을 손에 쥔다.
	# 없으면 기존 절차 생성 스킨으로 돌아간다 — 일부 계열만 교체해도 된다.
	var wpath := String(VfxPool.models().get("weapons", {}).get(String(w.skin), ""))
	var got: Array = VfxPool.mesh_of(wpath) if wpath != "" else []
	var fit := 1.0
	if got.size() >= 2 and got[0] != null:
		owner_player.weapon_mesh.mesh = got[0]
		# 무기 팩마다 단위가 달라 길이 1m 기준으로 맞춘다
		fit = VfxPool.fit_scale(got[0],
			float(VfxPool.models().get("weapons", {}).get("_target_len", 1.0)), false)
		# 모델 자체 머티리얼을 쓰되, 등급 발광을 잃지 않게 등급 색을 덮는다
		owner_player.weapon_mesh.material_override = 			got[1] if w.rarity < RarityEnums.Rarity.A else ItemSkins.build_material(w.rarity)
	else:
		owner_player.weapon_mesh.mesh = ItemSkins.build_mesh(w.skin)
		owner_player.weapon_mesh.material_override = ItemSkins.build_material(w.rarity)
	# 본 어태치먼트는 모델 스케일(92.5배)을 상속하므로 역수로 되돌린다.
	# 이 보정을 빼면 거대한 발광 검이 화면 전체를 하얗게 태운다.
	var inv: float = 1.0 / maxf(owner_player.base_scale.x, 0.0001)
	var wscale := float(VfxPool.models().get("weapons", {}).get("_scale", 1.0))
	var s: float = (0.9 + w.rarity * 0.06) * inv * wscale * fit
	owner_player.weapon_mesh.scale = Vector3(s, s, s)
	owner_player.weapon_mesh.position = Vector3(0.0, 0.06, 0.02) * inv

## ── 검격 궤적(Slash Trail) ──
## 부채꼴 VFX(_spawn_slash_vfx)는 "베인 영역"을 보여주지만, 칼날이 지나간 **선**이 없어서
## 스윙이 순간적으로만 번쩍이고 궤적이 눈에 남지 않았다.
## 여기서는 칼끝 궤적을 얇은 리본(연속된 세그먼트)으로 그려 잔상을 만든다.
const TRAIL_SEGMENTS := 7
const TRAIL_ARC := 2.1          ## 궤적이 훑는 각도(라디안)
const TRAIL_LIFE := 0.20

func spawn_weapon_trail(combo_step: int = 0) -> void:
	if owner_player.model == null:
		return
	var r: float = PlayerConfig.ATTACK_RANGE * [0.62, 0.66, 0.78][combo_step]
	var base_yaw: float = owner_player.facing_angle
	# 3타는 흰금색, 1~2타는 붉은색
	var col := Color(1.0, 0.42, 0.3) if combo_step < 2 else Color(1.0, 0.85, 0.6)
	var glow: float = 5.0 if combo_step < 2 else 9.0

	var root := Node3D.new()
	owner_player.get_parent().add_child(root)
	root.global_position = owner_player.global_position + Vector3(0, 1.15, 0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = glow
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# 세그먼트를 각도 순으로 배치하고, 시간차를 두고 하나씩 켜서 "칼이 지나가는" 순서를 만든다
	for i in range(TRAIL_SEGMENTS):
		var t: float = float(i) / float(TRAIL_SEGMENTS - 1)
		var a: float = base_yaw - TRAIL_ARC * 0.5 + TRAIL_ARC * t
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		# 앞쪽(칼끝)이 두껍고 뒤로 갈수록 얇아진다 → 속도감
		var thick: float = lerpf(0.16, 0.045, t)
		bm.size = Vector3(thick, thick * 0.5, r * 0.42)
		seg.mesh = bm
		seg.material_override = mat
		seg.position = Vector3(sin(a), 0, cos(a)) * (r * 0.8)
		seg.rotation.y = a
		seg.visible = false
		root.add_child(seg)

		var tw := create_tween()
		tw.tween_interval(t * 0.055)
		tw.tween_callback(func(): if is_instance_valid(seg): seg.visible = true)

	var tw2 := create_tween()
	tw2.tween_interval(0.06)
	tw2.tween_property(mat, "albedo_color:a", 0.0, TRAIL_LIFE)
	tw2.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, TRAIL_LIFE)
	tw2.tween_callback(root.queue_free)

func _spawn_dash_trail() -> void:
	for i in range(4):
		var ghost := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.35
		cyl.bottom_radius = 0.35
		cyl.height = 1.6
		ghost.mesh = cyl
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.5, 0.8, 1.0, 0.35)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = Color(0.4, 0.7, 1.0)
		m.emission_energy_multiplier = 1.5
		ghost.material_override = m
		ghost.position = owner_player.global_position - owner_player.dash_dir * (i * 0.7) + Vector3(0, 0.8, 0)
		owner_player.get_parent().add_child(ghost)
		var tw := create_tween()
		tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
		tw.parallel().tween_property(ghost, "scale", Vector3(0.4, 1.0, 0.4), 0.25)
		tw.tween_callback(ghost.queue_free)
