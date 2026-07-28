extends Node3D
## 필드에 떨어진 아이템. Area3D 로 플레이어 근접을 감지하고 E 키로 파밍한다.

var item: ItemData
var area: Area3D
var mesh: MeshInstance3D
var label: Label3D
var player_near := false
var collected := false
var spin := 0.0

const PICKUP_RADIUS := 2.2

func setup(p_item: ItemData) -> void:
	item = p_item
	add_to_group("item_drops")

	var col: Color = item.get_color()
	var glow: float = RarityEnums.get_rarity_glow(item.rarity)

	# 아이템 스킨 메시 (부위/등급별로 외형이 다르다)
	mesh = MeshInstance3D.new()
	mesh.mesh = ItemSkins.build_mesh(item.skin)
	mesh.material_override = ItemSkins.build_material(item.rarity)
	mesh.position.y = 0.6
	add_child(mesh)

	# 등급별 색상 빛
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = clampf(glow * 0.6, 0.8, 6.0)
	light.omni_range = clampf(2.5 + glow, 3.0, 12.0)
	light.position.y = 0.6
	add_child(light)

	# 고등급은 하늘로 빛기둥이 선다 — 멀리서도 "저기 좋은 게 있다"가 보인다
	var td: Dictionary = CombatFeel.pacing().get("drop_tease", {})
	if item.rarity >= int(td.get("beam_from", 99)):
		var h := float(td.get("beam_height", {}).get(str(item.rarity), 5.0))
		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.16
		cyl.bottom_radius = 0.5
		cyl.height = h
		cyl.radial_segments = 8
		beam.mesh = cyl
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(col.r, col.g, col.b, 0.22)
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.emission_enabled = true
		bm.emission = col
		bm.emission_energy_multiplier = 2.5
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam.material_override = bm
		beam.position.y = h * 0.5
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam)

	# 고등급은 바닥 광륜 추가
	if item.rarity >= RarityEnums.Rarity.S:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.75
		torus.outer_radius = 1.0
		ring.mesh = torus
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(col.r, col.g, col.b, 0.6)
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.emission_enabled = true
		rm.emission = col
		rm.emission_energy_multiplier = glow
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = rm
		ring.position.y = 0.08
		add_child(ring)

	label = Label3D.new()
	label.text = item.get_display_name()
	label.font_size = 48
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = col
	label.outline_size = 12
	label.outline_modulate = Color(0, 0, 0)
	label.position.y = 1.5
	add_child(label)

	area = Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2   # 플레이어 레이어
	add_child(area)
	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = PICKUP_RADIUS
	shape.shape = sph
	shape.position.y = 0.5
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	# 등장 연출
	mesh.scale = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(mesh, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = true
		label.text = "%s\n[E] 획득" % item.get_display_name()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = false
		label.text = item.get_display_name()

func _process(delta: float) -> void:
	if collected:
		return
	spin += delta * 1.8
	mesh.rotation.y = spin
	mesh.position.y = 0.5 + sin(spin * 1.6) * 0.12

	if player_near and Input.is_key_pressed(KEY_E) and not _windows_open():
		_collect()

func _windows_open() -> bool:
	var world = get_tree().current_scene
	if world == null or world.get("hud") == null:
		return false
	return world.hud.windows_open()

## 펫이 원격으로 회수.
## 플레이어가 직접 주운 게 아니므로 화면 연출(히트스톱·플래시)은 넣지 않는다.
func pet_collect() -> void:
	_collect(true)

func _collect(by_pet: bool = false) -> void:
	if collected:
		return
	collected = true
	LootManager.collect(item, by_pet)
	SoundManager.play("pickup")

	if label:
		label.visible = false
	var tw := create_tween()
	tw.tween_property(mesh, "position:y", 2.0, 0.35)
	tw.parallel().tween_property(mesh, "scale", Vector3.ZERO, 0.35)
	tw.tween_callback(queue_free)
