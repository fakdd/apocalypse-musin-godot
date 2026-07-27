extends Node
class_name PlayerCombat
## 검기·만천화우·기공파·반로환동 등 전투 행동과 그 이펙트.
## Player3D(owner)의 상태를 읽고 쓰는 행동 모듈이다.

var owner_player: CharacterBody3D

func setup(p: CharacterBody3D) -> void:
	owner_player = p

func _slash() -> void:
	# 3타 콤보 — 연속으로 이으면 피해와 범위가 커진다
	if owner_player.combo_timer > 0.0:
		owner_player.combo_step = (owner_player.combo_step + 1) % 3
	else:
		owner_player.combo_step = 0
	owner_player.combo_timer = PlayerConfig.COMBO_WINDOW

	var combo_mult: float = [1.0, 1.25, 1.9][owner_player.combo_step]
	var range_mult: float = [1.0, 1.05, 1.35][owner_player.combo_step]

	owner_player.atk_cd = PlayerConfig.ATTACK_COOLDOWN
	owner_player.attack_anim_timer = 0.30
	# 공격 중에는 마우스 방향으로 몸을 즉시 고정
	owner_player.model_yaw = owner_player.facing_angle
	if owner_player.model:
		owner_player.model.rotation.y = owner_player.model_yaw
	if owner_player.anim and owner_player.anim.has_animation("attack-melee-right"):
		owner_player.anim.speed_scale = 1.9   # Mixamo 검격은 느리므로 빠르게 재생
		owner_player.anim.play("attack-melee-right")
	# 베는 순간 살짝 앞으로 파고든다
	owner_player.velocity += owner_player.facing_dir() * 3.5
	_spawn_slash_vfx(range_mult, owner_player.combo_step)
	owner_player.animation.spawn_weapon_trail(owner_player.combo_step)
	var kills := 0
	var hits := 0
	var fwd: Vector3 = owner_player.facing_dir()
	var reach := PlayerConfig.ATTACK_RANGE * range_mult
	var hit_center := Vector3.ZERO
	# 매 프레임 그룹 검색 대신 Battlefield 캐시를 쓴다
	for enemy in Battlefield.enemies:
		if not is_instance_valid(enemy): continue
		var to_enemy: Vector3 = enemy.global_position - owner_player.global_position
		to_enemy.y = 0
		if to_enemy.length() > reach + enemy.hit_radius: continue
		if fwd.angle_to(to_enemy.normalized()) > PlayerConfig.ATTACK_HALF_ANGLE: continue
		hits += 1
		hit_center += enemy.global_position
		if enemy.take_damage(owner_player.slash_damage * combo_mult, to_enemy.normalized() * 4.0 * combo_mult):
			kills += 1

	# ── 명중/헛스윙 피드백 ──
	if hits > 0:
		hit_center /= float(hits)
		_hit_confirm(hits, kills, hit_center)
	else:
		_whiff_feedback()

## 명중 확정 — 히트스톱 · 카메라 킥 · 사운드 레이어 · 크리티컬 플래시를 한곳에서 처리한다.
##
## 사운드 타이밍 개선:
##   이전에는 명중 수와 콤보 단계에 상관없이 "hit" 하나를 같은 볼륨/피치로 재생했다.
##   3타 피니셔와 평타가 청각적으로 구분되지 않아 타격의 "무게"가 전달되지 않았다.
##   이제 콤보 단계에 따라 피치를 올리고(1타 낮음 → 3타 높음), 다중 명중은 볼륨을 키우고,
##   처치음은 한 프레임 뒤에 재생해 "베었다 → 죽었다"가 두 사건으로 들리게 한다.
func _hit_confirm(hits: int, kills: int, at: Vector3) -> void:
	var step: int = owner_player.combo_step
	var is_finisher := step == 2
	var kick_dir: Vector3 = (at - owner_player.global_position)

	# 타격음 — 콤보가 올라갈수록 피치가 높아지고 두꺼워진다
	var pitch_step: float = [0.92, 1.02, 1.16][step]
	var vol: float = -2.0 + minf(float(hits) * 1.2, 4.0) + (2.0 if is_finisher else 0.0)
	SoundManager.play_pitched("hit", vol, pitch_step, 0.06)

	# 히트스톱 — 콤보 단계와 처치 수에 따라 무게가 다르다
	var weight: float = CombatFeel.HS_LIGHT
	if step == 1:
		weight = CombatFeel.HS_MEDIUM
	if is_finisher:
		weight = CombatFeel.HS_HEAVY
	if kills > 0:
		weight = maxf(weight, CombatFeel.HS_KILL)
	CombatFeel.hit_stop(weight)

	# 카메라 — 명중 방향으로 킥
	var mag: float = 0.08 + 0.05 * float(step) + minf(float(hits) * 0.02, 0.08)
	if kills > 0:
		mag += 0.05
	owner_player.shake_from(mag, 0.16 + 0.06 * float(step), kick_dir)

	# 크리티컬 화면 플래시 — 피니셔/처치 순간에만 (남발하면 눈이 피로해진다)
	if is_finisher:
		CombatFeel.screen_flash(Color(1.0, 0.86, 0.62), 0.16, 0.0, 0.13)
	if kills > 0:
		CombatFeel.screen_flash(Color(1.0, 0.4, 0.28), 0.13, 0.0, 0.18)
		owner_player.ult_gauge = min(owner_player.ult_max, owner_player.ult_gauge + kills * 4)
		owner_player.ult_changed.emit()

## 헛스윙 — 아무것도 못 맞히면 히트스톱 없이 바람 소리만 (명중과 확실히 구분된다)
func _whiff_feedback() -> void:
	SoundManager.play_pitched("dash", -20.0, 0.7, 0.08)

func _make_arc_mesh(radius: float, half_angle: float, inner: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var steps := 16
	for i in range(steps):
		var a0 := -half_angle + (half_angle * 2.0) * (float(i) / steps)
		var a1 := -half_angle + (half_angle * 2.0) * (float(i + 1) / steps)
		var o0 := Vector3(sin(a0), 0, cos(a0)) * radius
		var o1 := Vector3(sin(a1), 0, cos(a1)) * radius
		var i0 := Vector3(sin(a0), 0, cos(a0)) * inner
		var i1 := Vector3(sin(a1), 0, cos(a1)) * inner
		# 양면으로 두 삼각형씩
		verts.append_array([i0, o0, o1])
		verts.append_array([i0, o1, i1])
		verts.append_array([o1, o0, i0])
		verts.append_array([i1, o1, i0])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am

## 검기 — 칼이 지나간 부채꼴 궤적이 순간적으로 번쩍인다
func _spawn_slash_vfx(range_mult: float = 1.0, step: int = 0) -> void:
	var r := PlayerConfig.ATTACK_RANGE * range_mult
	var mesh := MeshInstance3D.new()
	mesh.mesh = _make_arc_mesh(r, PlayerConfig.ATTACK_HALF_ANGLE, r * 0.35)
	var m := StandardMaterial3D.new()
	# 3타째는 흰빛에 가깝게 강조
	m.albedo_color = Color(1.0, 0.35, 0.28, 0.85) if step < 2 else Color(1.0, 0.78, 0.5, 0.95)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(1.0, 0.22, 0.15)
	m.emission_energy_multiplier = 6.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = m
	owner_player.get_parent().add_child(mesh)
	mesh.global_position = owner_player.global_position + Vector3(0, 1.0, 0)
	mesh.rotation.y = owner_player.facing_angle

	# 베는 방향으로 궤적이 훑고 지나가는 느낌
	mesh.scale = Vector3(0.5, 1.0, 0.5)
	var tw := create_tween()
	tw.tween_property(mesh, "scale", Vector3(1.15, 1.0, 1.15), 0.09).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(mesh, "rotation:y", owner_player.facing_angle + 0.35, 0.09)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.14)
	tw.parallel().tween_property(m, "emission_energy_multiplier", 0.0, 0.14)
	tw.tween_callback(mesh.queue_free)

	# 칼끝 섬광
	var spark := OmniLight3D.new()
	spark.light_color = Color(1.0, 0.4, 0.3)
	spark.light_energy = 3.5
	spark.omni_range = 6.0
	spark.position = owner_player.global_position + owner_player.facing_dir() * (r * 0.5) + Vector3(0, 1.2, 0)
	owner_player.get_parent().add_child(spark)
	var tw2 := create_tween()
	tw2.tween_property(spark, "light_energy", 0.0, 0.16)
	tw2.tween_callback(spark.queue_free)

func _ultimate() -> void:
	owner_player.ult_gauge = 0
	owner_player.ult_changed.emit()
	SoundManager.play("ultimate")
	# 궁극기는 게임 내 가장 강한 순간 — 히트스톱 + 슬로모션 + 흰 플래시를 모두 쓴다
	CombatFeel.hit_stop(CombatFeel.HS_ULT)
	CombatFeel.slow_motion(0.5, 0.45)
	CombatFeel.screen_flash(Color(0.8, 0.92, 1.0), 0.42, 0.05, 0.4)
	owner_player.shake_from(0.4, 0.5, Vector3.ZERO)
	for enemy in Battlefield.enemies:
		if not is_instance_valid(enemy): continue
		var flat: Vector3 = enemy.global_position - owner_player.global_position
		flat.y = 0
		if flat.length() <= PlayerConfig.ULT_RADIUS:
			enemy.take_damage(999, flat.normalized() * 3.0)
	_spawn_ult_vfx()

func _spawn_ult_vfx() -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = PlayerConfig.ULT_RADIUS
	sphere.height = PlayerConfig.ULT_RADIUS * 2.0
	mesh.mesh = sphere
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.85, 1.0, 0.4)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.5, 0.8, 1.0)
	m.emission_energy_multiplier = 4.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = m
	mesh.position = owner_player.global_position + Vector3(0, 1.0, 0)
	mesh.scale = Vector3(0.15, 0.15, 0.15)
	owner_player.get_parent().add_child(mesh)

	var flash := OmniLight3D.new()
	flash.position = owner_player.global_position + Vector3(0, 1.5, 0)
	flash.light_color = Color(0.6, 0.85, 1.0)
	flash.light_energy = 8.0
	flash.omni_range = PlayerConfig.ULT_RADIUS * 2.0
	owner_player.get_parent().add_child(flash)

	var tw := create_tween()
	tw.tween_property(mesh, "scale", Vector3(1.1, 0.5, 1.1), 0.45)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.parallel().tween_property(flash, "light_energy", 0.0, 0.45)
	tw.tween_callback(mesh.queue_free)
	tw.tween_callback(flash.queue_free)

func _ranged_wave() -> void:
	owner_player.ranged_cd = PlayerConfig.RANGED_COOLDOWN
	owner_player.attack_anim_timer = 0.34
	owner_player.model_yaw = owner_player.facing_angle
	if owner_player.model:
		owner_player.model.rotation.y = owner_player.model_yaw
	if owner_player.anim and owner_player.anim.has_animation("attack-melee-left"):
		owner_player.anim.speed_scale = 1.6
		owner_player.anim.play("attack-melee-left")
	var half_width := 1.4
	var dir: Vector3 = owner_player.facing_dir()
	var kills := 0
	var hits := 0
	for enemy in Battlefield.enemies:
		if not is_instance_valid(enemy): continue
		var rel: Vector3 = enemy.global_position - owner_player.global_position
		rel.y = 0
		var proj := rel.dot(dir)
		if proj < 0 or proj > PlayerConfig.RANGED_RANGE: continue
		var perp := (rel - dir * proj).length()
		if perp > half_width + enemy.hit_radius: continue
		hits += 1
		if enemy.take_damage(owner_player.slash_damage * 2.0, dir * 3.0):
			kills += 1
	if hits > 0:
		SoundManager.play("hit", 0.0, 0.12)
	if kills > 0:
		owner_player.ult_gauge = min(owner_player.ult_max, owner_player.ult_gauge + kills * 4)
		owner_player.ult_changed.emit()
	_spawn_beam_vfx(dir)

func _spawn_beam_vfx(dir: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.4, 1.2, PlayerConfig.RANGED_RANGE)
	mesh.mesh = box
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.9, 1.0, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.45, 0.85, 1.0)
	m.emission_energy_multiplier = 4.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = m
	mesh.position = owner_player.global_position + dir * (PlayerConfig.RANGED_RANGE * 0.5) + Vector3(0, 1.0, 0)
	mesh.rotation.y = owner_player.facing_angle
	owner_player.get_parent().add_child(mesh)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(mesh.queue_free)

func _start_parry() -> void:
	owner_player.parry_cd = PlayerConfig.PARRY_COOLDOWN
	owner_player.parry_timer = PlayerConfig.PARRY_WINDOW
	_spawn_parry_vfx()

func _parry_success() -> void:
	owner_player.parry_timer = 0
	# 반로환동 성공 — 가장 만족스러워야 하는 순간이므로 강한 히트스톱 + 금색 플래시
	SoundManager.play_pitched("hit", 3.0, 1.3, 0.02)
	CombatFeel.hit_stop(CombatFeel.HS_PARRY)
	CombatFeel.screen_flash(Color(1.0, 0.9, 0.5), 0.3, 0.04, 0.28)
	owner_player.shake_from(0.24, 0.26, Vector3.ZERO)
	for enemy in Battlefield.enemies:
		if not is_instance_valid(enemy): continue
		var flat: Vector3 = enemy.global_position - owner_player.global_position
		flat.y = 0
		if flat.length() <= 6.0:
			enemy.stun(1.2)
			enemy.take_damage(owner_player.slash_damage, flat.normalized() * 7.0)

func _spawn_parry_vfx() -> void:
	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.3
	mesh.mesh = torus
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.9, 0.4, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(1.0, 0.85, 0.3)
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = m
	mesh.position = Vector3(0, 1.0, 0)
	add_child(mesh)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, PlayerConfig.PARRY_WINDOW + 0.15)
	tw.tween_callback(mesh.queue_free)
