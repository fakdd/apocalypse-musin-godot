extends Node3D

var core: MeshInstance3D
var core_mat: StandardMaterial3D
var ring: MeshInstance3D
var ring_mat: StandardMaterial3D
var light: OmniLight3D
var active := false
var sealed := false
var spin := 0.0

const COL_A := Color(1.0, 0.12, 0.18)
const COL_B := Color(0.65, 0.15, 1.0)

func _ready() -> void:
	add_to_group("rifts")

	core = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.5
	sph.height = 3.6
	core.mesh = sph
	core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = Color(COL_A.r, COL_A.g, COL_A.b, 0.55)
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.emission_enabled = true
	core_mat.emission = COL_A
	core_mat.emission_energy_multiplier = 5.0
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	core.material_override = core_mat
	core.position.y = 2.4
	core.scale = Vector3(0.55, 1.35, 0.12)
	add_child(core)

	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.5
	torus.outer_radius = 1.95
	ring.mesh = torus
	ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(COL_B.r, COL_B.g, COL_B.b, 0.8)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled = true
	ring_mat.emission = COL_B
	ring_mat.emission_energy_multiplier = 6.0
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_mat
	ring.position.y = 2.4
	ring.rotation.x = PI * 0.5
	add_child(ring)

	light = OmniLight3D.new()
	light.position.y = 2.4
	light.light_color = COL_A
	light.light_energy = 0.6
	light.omni_range = 14.0
	add_child(light)

	_scatter_corruption()
	set_active(false)

func _scatter_corruption() -> void:
	for i in range(14):
		var shard := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(randf_range(0.25, 0.6), randf_range(0.7, 2.0), randf_range(0.25, 0.6))
		shard.mesh = pm
		var m := StandardMaterial3D.new()
		var t := randf()
		var c := Color(0.45, 0.06, 0.12).lerp(Color(0.28, 0.05, 0.22), t)
		m.albedo_color = c.darkened(0.6)
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.35
		m.roughness = 0.35
		shard.material_override = m
		var a := randf() * TAU
		var r := randf_range(1.6, 5.5)
		shard.position = Vector3(cos(a) * r, pm.size.y * 0.35, sin(a) * r)
		shard.rotation = Vector3(randf_range(-0.35, 0.35), randf() * TAU, randf_range(-0.35, 0.35))
		add_child(shard)

	var stain := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 6.0
	cyl.bottom_radius = 6.0
	cyl.height = 0.05
	stain.mesh = cyl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.14, 0.02, 0.06, 0.85)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.roughness = 1.0
	stain.material_override = sm
	stain.position.y = 0.03
	add_child(stain)

## 봉인 — 균열이 닫히고 더 이상 몬스터가 나오지 않는다
func seal() -> void:
	if sealed:
		return
	sealed = true
	remove_from_group("rifts")
	add_to_group("sealed_rifts")
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(core, "scale", Vector3(0.02, 0.02, 0.02), 1.2)
	tw.tween_property(light, "light_energy", 0.15, 1.2)
	tw.tween_property(core_mat, "emission_energy_multiplier", 0.0, 1.2)
	tw.tween_property(ring_mat, "emission_energy_multiplier", 0.4, 1.2)
	if ring_mat:
		tw.tween_property(ring_mat, "albedo_color", Color(0.35, 0.75, 1.0, 0.5), 1.2)

func set_active(on: bool) -> void:
	if sealed:
		return
	active = on
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(core, "scale", Vector3(1.0, 1.6, 0.18) if on else Vector3(0.35, 1.0, 0.1), 1.2)
	tw.tween_property(light, "light_energy", 4.5 if on else 0.5, 1.2)
	tw.tween_property(core_mat, "emission_energy_multiplier", 7.0 if on else 2.0, 1.2)
	tw.tween_property(ring_mat, "emission_energy_multiplier", 8.0 if on else 2.0, 1.2)

func _process(delta: float) -> void:
	if sealed:
		spin += delta * 0.2
		ring.rotation.y = spin
		return
	spin += delta * (1.6 if active else 0.4)
	ring.rotation.y = spin
	core.rotation.y = -spin * 0.6
	var pulse: float = 1.0 + sin(spin * 2.2) * (0.12 if active else 0.05)
	ring.scale = Vector3(pulse, pulse, pulse)

func spawn_burst() -> void:
	if sealed:
		return
	var burst := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	burst.mesh = sph
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(COL_A.r, COL_A.g, COL_A.b, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = COL_A
	m.emission_energy_multiplier = 7.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	burst.material_override = m
	burst.position = global_position + Vector3(0, 2.0, 0)
	get_parent().add_child(burst)
	var tw := create_tween()
	tw.tween_property(burst, "scale", Vector3(2.6, 2.6, 2.6), 0.4)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(burst.queue_free)
