extends Node3D
## 대기 파티클 — 먼지 / 재 / 연기 / 불꽃 / 낙엽
## 플레이어를 따라다니는 것(먼지·재·낙엽)과 고정된 것(연기·불꽃)으로 나뉜다.

var follow_sets: Array[GPUParticles3D] = []

func _ready() -> void:
	add_to_group("atmosphere")
	_build_dust()
	_build_ash()
	_build_leaves()

func _process(_delta: float) -> void:
	# 플레이어 주변에만 파티클을 유지해 성능을 아낀다
	var player := Battlefield.player
	if player == null or not is_instance_valid(player):
		return
	for p in follow_sets:
		if is_instance_valid(p):
			p.global_position = player.global_position + Vector3(0, 6.0, 0)

func _quad(size: float, col: Color, emissive: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emissive
	q.material = m
	return q

## ── 먼지: 공중에 떠다니는 미세 입자 ──
func _build_dust() -> void:
	var p := GPUParticles3D.new()
	p.amount = 260
	p.lifetime = 9.0
	p.preprocess = 5.0
	p.visibility_aabb = AABB(Vector3(-22, -10, -22), Vector3(44, 24, 44))
	p.draw_pass_1 = _quad(0.05, Color(0.85, 0.75, 0.68, 0.35), 0.0)

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(20, 7, 20)
	m.direction = Vector3(0.4, -0.1, 0.2)
	m.spread = 60.0
	m.initial_velocity_min = 0.15
	m.initial_velocity_max = 0.6
	m.gravity = Vector3(0.15, -0.05, 0.1)
	m.scale_min = 0.5
	m.scale_max = 1.6
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.35
	m.turbulence_noise_scale = 1.6
	_fade_alpha(m, Color(0.85, 0.75, 0.68))
	p.process_material = m
	add_child(p)
	follow_sets.append(p)

## ── 재: 위에서 천천히 내려앉는 잿가루 ──
func _build_ash() -> void:
	var p := GPUParticles3D.new()
	p.amount = 200
	p.lifetime = 11.0
	p.preprocess = 6.0
	p.visibility_aabb = AABB(Vector3(-24, -14, -24), Vector3(48, 30, 48))
	p.draw_pass_1 = _quad(0.07, Color(0.95, 0.55, 0.38, 0.55), 1.2)

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(22, 1, 22)
	m.direction = Vector3(0.3, -1, 0.15)
	m.spread = 25.0
	m.initial_velocity_min = 0.5
	m.initial_velocity_max = 1.3
	m.gravity = Vector3(0.5, -0.55, 0.3)
	m.scale_min = 0.4
	m.scale_max = 1.3
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.5
	_fade_alpha(m, Color(1.0, 0.55, 0.32))
	p.process_material = m
	add_child(p)
	follow_sets.append(p)

## ── 낙엽: 바람에 굴러가는 잎 ──
func _build_leaves() -> void:
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 7.0
	p.preprocess = 3.0
	p.visibility_aabb = AABB(Vector3(-22, -10, -22), Vector3(44, 20, 44))
	p.draw_pass_1 = _quad(0.16, Color(0.72, 0.48, 0.22, 0.8), 0.0)

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(20, 0.4, 20)
	m.direction = Vector3(1, 0.15, 0.35)
	m.spread = 40.0
	m.initial_velocity_min = 1.6
	m.initial_velocity_max = 4.2
	m.gravity = Vector3(0.8, -0.6, 0.4)
	m.angular_velocity_min = -220.0
	m.angular_velocity_max = 220.0
	m.scale_min = 0.6
	m.scale_max = 1.4
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.8
	_fade_alpha(m, Color(0.72, 0.48, 0.22))
	p.process_material = m
	add_child(p)
	follow_sets.append(p)

## 수명에 따라 서서히 사라지게
func _fade_alpha(m: ParticleProcessMaterial, col: Color) -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(col.r, col.g, col.b, 0.0))
	grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	grad.add_point(0.18, Color(col.r, col.g, col.b, 1.0))
	grad.add_point(0.7, Color(col.r, col.g, col.b, 0.85))
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	m.color_ramp = tex

## ── 고정 연기 기둥 (폐허 곳곳) ──
static func make_smoke(height: float = 6.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 46
	p.lifetime = 5.0
	p.preprocess = 3.0
	p.visibility_aabb = AABB(Vector3(-5, 0, -5), Vector3(10, height + 6, 10))

	var q := QuadMesh.new()
	q.size = Vector2(1.5, 1.5)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(0.16, 0.13, 0.13, 0.30)
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	q.material = qm
	p.draw_pass_1 = q

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.6
	m.direction = Vector3(0.25, 1, 0.1)
	m.spread = 14.0
	m.initial_velocity_min = 0.8
	m.initial_velocity_max = 1.8
	m.gravity = Vector3(0.5, 0.35, 0.2)
	m.scale_min = 1.0
	m.scale_max = 3.4
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.4

	var grad := Gradient.new()
	grad.set_color(0, Color(0.2, 0.16, 0.15, 0.0))
	grad.set_color(1, Color(0.10, 0.08, 0.08, 0.0))
	grad.add_point(0.2, Color(0.22, 0.17, 0.16, 0.45))
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	m.color_ramp = tex
	p.process_material = m
	return p

## ── 불꽃(모닥불 위 튀는 불티) ──
static func make_embers() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 34
	p.lifetime = 2.2
	p.preprocess = 1.0
	p.visibility_aabb = AABB(Vector3(-3, 0, -3), Vector3(6, 9, 6))

	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(1.0, 0.55, 0.15)
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.emission_enabled = true
	qm.emission = Color(1.0, 0.5, 0.12)
	qm.emission_energy_multiplier = 6.0
	qm.vertex_color_use_as_albedo = true
	q.material = qm
	p.draw_pass_1 = q

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.35
	m.direction = Vector3(0.15, 1, 0.1)
	m.spread = 22.0
	m.initial_velocity_min = 1.6
	m.initial_velocity_max = 3.4
	m.gravity = Vector3(0.3, 0.8, 0.15)
	m.scale_min = 0.5
	m.scale_max = 1.5
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 1.2

	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.75, 0.3, 1.0))
	grad.set_color(1, Color(0.8, 0.15, 0.05, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	m.color_ramp = tex
	p.process_material = m
	return p
