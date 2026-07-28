extends Node3D
## 마도 제단 — 안전지대 중앙. 마석을 지불해 특성을 재주사한다.

const REROLL_COST := 40

var prompt: Label3D
var ring: MeshInstance3D
var crystal: MeshInstance3D
var spin := 0.0
var cooldown := 0.0

func _ready() -> void:
	add_to_group("altars")

	# 받침
	var basec := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.1
	cyl.bottom_radius = 1.4
	cyl.height = 0.7
	basec.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.22, 0.22, 0.27)
	bm.roughness = 0.85
	basec.material_override = bm
	basec.position.y = 0.35
	add_child(basec)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var shape := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 1.3
	cs.height = 0.7
	shape.shape = cs
	shape.position.y = 0.35
	body.add_child(shape)

	# 부유하는 결정
	crystal = MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.6, 1.2, 0.6)
	crystal.mesh = pm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.55, 0.8, 1.0)
	cm.emission_enabled = true
	cm.emission = Color(0.45, 0.75, 1.0)
	cm.emission_energy_multiplier = 4.0
	cm.metallic = 0.5
	crystal.material_override = cm
	crystal.position.y = 1.7
	add_child(crystal)

	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.5
	torus.outer_radius = 1.75
	ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.5, 0.8, 1.0, 0.6)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.emission_enabled = true
	rm.emission = Color(0.45, 0.78, 1.0)
	rm.emission_energy_multiplier = 3.0
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	ring.position.y = 0.9
	add_child(ring)

	var light := OmniLight3D.new()
	light.position.y = 1.8
	light.light_color = Color(0.5, 0.8, 1.0)
	light.light_energy = 3.0
	light.omni_range = 12.0
	add_child(light)

	prompt = Label3D.new()
	prompt.font_size = 46
	prompt.pixel_size = 0.006
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.modulate = Color(0.7, 0.9, 1.0)
	prompt.outline_size = 10
	prompt.outline_modulate = Color(0, 0, 0)
	prompt.position.y = 3.0
	prompt.visible = false
	add_child(prompt)

func _process(delta: float) -> void:
	spin += delta
	crystal.rotation.y = spin * 1.4
	crystal.position.y = 1.7 + sin(spin * 1.8) * 0.15
	ring.rotation.y = -spin * 0.8
	if cooldown > 0.0:
		cooldown -= delta

	var player := Battlefield.player
	if player == null or not is_instance_valid(player):
		prompt.visible = false
		return
	var near: bool = global_position.distance_to(player.global_position) < 4.0
	prompt.visible = near
	if not near:
		return

	if CraftManager.essence >= REROLL_COST:
		prompt.text = "마도 제단\n[G] 영구 강화 · 동행 뽑기\n[F] 특성 재주사 (마석 %d)" % REROLL_COST
		prompt.modulate = Color(0.7, 0.95, 1.0)
	else:
		prompt.text = "마도 제단\n[G] 영구 강화 · 동행 뽑기\n[F] 재주사 — 마석 부족 (%d/%d)" \
			% [CraftManager.essence, REROLL_COST]
		prompt.modulate = Color(0.75, 0.6, 0.6)

	if Input.is_key_pressed(KEY_F) and cooldown <= 0.0:
		_try_reroll()

## 영구 강화 화면은 이벤트로 연다.
## 폴링으로 열면 같은 프레임에 UpgradeUI 가 G 를 닫기용으로 또 받아 즉시 닫힌다.
## 창이 열려 있으면 HUD 가 먼저 G 를 먹으므로 여기까지 오지 않는다.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_G:
		return
	var player := Battlefield.player
	if player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) >= 4.0:
		return
	var world = get_tree().current_scene
	if world and world.get("hud") != null and world.hud.get("upgrade_ui") != null:
		world.hud.upgrade_ui.toggle()
		get_viewport().set_input_as_handled()

func _try_reroll() -> void:
	cooldown = 0.6
	if CraftManager.essence < REROLL_COST:
		SoundManager.play("error", -12.0)
		return
	CraftManager.add_essence(-REROLL_COST)
	var t := TraitManager.reroll_trait()
	SoundManager.play("ultimate", -16.0)
	_burst(RarityEnums.get_rarity_color(int(t.get("rarity", 0))))

func _burst(col: Color) -> void:
	var mesh := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	mesh.mesh = sph
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 6.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = m
	mesh.position.y = 1.7
	add_child(mesh)
	var tw := create_tween()
	tw.tween_property(mesh, "scale", Vector3(3.2, 3.2, 3.2), 0.45)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.tween_callback(mesh.queue_free)
