extends Area3D
class_name ChapterPortal
## 챕터 이동 포탈 — 지역 보스를 처치하면 열린다.
##
## 차원의 균열(Rift3D)과는 다른 것이다. 균열은 적이 쏟아지는 구멍이고,
## 이 포탈은 다음 지역으로 나가는 문이다. 그래서 그룹도 따로 쓴다.
##
## 들어가면 PortalManager.advance_to_next_chapter() 를 부른다.

const RADIUS := 2.6

var _label: Label3D
var _ring: MeshInstance3D
var _core: MeshInstance3D
var _spin := 0.0
var _used := false

func setup(next_name: String) -> void:
	add_to_group("chapter_portals")
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2                      ## 플레이어만 감지

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS
	cyl.height = 6.0
	shape.shape = cyl
	shape.position.y = 3.0
	add_child(shape)

	_build_visual(next_name)
	body_entered.connect(_on_body_entered)
	set_process(true)

func _build_visual(next_name: String) -> void:
	var col := Color(0.55, 0.85, 1.0)

	# 소용돌이 코어 — 납작한 구를 세워 "문"처럼 보이게 한다
	_core = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = RADIUS * 0.9
	sph.height = RADIUS * 3.2
	_core.mesh = sph
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(col.r, col.g, col.b, 0.55)
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.emission_enabled = true
	cm.emission = col
	cm.emission_energy_multiplier = 5.0
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_core.material_override = cm
	_core.scale = Vector3(1.0, 1.0, 0.25)   ## 얇게 눌러 평면 문 느낌
	_core.position.y = RADIUS * 1.5
	add_child(_core)

	# 테두리 링
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS * 0.95
	torus.outer_radius = RADIUS * 1.15
	_ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1.0, 0.92, 0.65)
	rm.emission_enabled = true
	rm.emission = Color(1.0, 0.85, 0.5)
	rm.emission_energy_multiplier = 4.0
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = rm
	_ring.rotation.x = PI * 0.5             ## 세워서 문틀처럼
	_ring.position.y = RADIUS * 1.5
	add_child(_ring)

	# 멀리서도 보이는 광주 — "저기 가면 된다"를 알린다
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = RADIUS * 0.7
	cyl.height = 26.0
	beam.mesh = cyl
	beam.material_override = SharedMaterials.unshaded_fade(
		Color(col.r, col.g, col.b, 0.13), 1.8)
	beam.position.y = 13.0
	add_child(beam)

	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 4.0
	light.omni_range = 18.0
	light.position.y = RADIUS * 1.5
	add_child(light)

	_label = Label3D.new()
	_label.text = "▼ %s 로 →" % next_name
	_label.font_size = 46
	_label.pixel_size = 0.012
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color(1.0, 0.95, 0.75)
	_label.outline_size = 12
	_label.outline_modulate = Color(0, 0, 0, 0.9)
	_label.position.y = RADIUS * 3.0
	add_child(_label)

	# 등장 연출 — 작게 시작해 부풀어 오른다
	scale = Vector3(0.05, 0.05, 0.05)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	_spin += delta
	if _core:
		_core.rotation.y = _spin * 1.6
	if _ring:
		_ring.rotation.y = -_spin * 0.9
		var pulse: float = 1.0 + sin(_spin * 2.4) * 0.05
		_ring.scale = Vector3(pulse, pulse, pulse)

func _on_body_entered(body: Node3D) -> void:
	if _used or not body.is_in_group("player"):
		return
	_used = true
	set_process(false)
	var world = get_tree().current_scene
	if world and world.get("portal_manager"):
		world.portal_manager.advance_to_next_chapter()
