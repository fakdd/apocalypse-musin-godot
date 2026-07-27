extends Node3D

var beacon: MeshInstance3D
var damage_light: OmniLight3D
var _station_node: Node3D = null
var _fires: Array = []

func _ready() -> void:
	add_to_group("base_core")

	_build_structure()
	_build_beacon()

func _build_structure() -> void:
	# ── 랜드마크: 센트럴 스테이션 (Meshy AI 제작 모델) ──
	# 원본은 2유닛으로 정규화되어 있어 크게 키워야 랜드마크가 된다.
	const STATION_SCALE := 4.2
	var station_res = load("res://assets3d/station/central_station.obj")
	if station_res != null:
		var mi := MeshInstance3D.new()
		if station_res is Mesh:
			mi.mesh = station_res
		else:
			var inst: Node3D = station_res.instantiate()
			add_child(inst)
			inst.scale = Vector3(STATION_SCALE, STATION_SCALE, STATION_SCALE)
			inst.position = Vector3(0, 0, -3.0)
			_station_node = inst
		if mi.mesh != null:
			mi.scale = Vector3(STATION_SCALE, STATION_SCALE, STATION_SCALE)
			# 모델 원점이 중앙이므로 바닥에 맞춰 올린다
			var h: float = mi.get_aabb().size.y * STATION_SCALE
			mi.position = Vector3(0, h * 0.5, -2.2)
			add_child(mi)
			_station_node = mi

	# 역 본체 충돌 (플레이어가 통과하지 못하게)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.5, 6.0, 5.0)
	shape.shape = box
	shape.position = Vector3(0, 3.0, -3.2)
	body.add_child(shape)

	# 광장 바닥 발광 링 (안전지대 표식)
	var glow := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 3.5
	ring.outer_radius = 3.9
	glow.mesh = ring
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.35, 0.8, 1.0, 0.55)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.emission_enabled = true
	gm.emission = Color(0.35, 0.8, 1.0)
	gm.emission_energy_multiplier = 3.0
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = gm
	glow.position = Vector3(0, 0.15, 3.0)
	add_child(glow)

	# 광장 앞 바리케이드 / 모래주머니
	var fence: PackedScene = load("res://assets3d/models/fence-fortified.glb")
	if fence:
		for i in range(10):
			var t := -1.0 + 2.0 * (float(i) / 9.0)
			var f: Node3D = fence.instantiate()
			f.position = Vector3(t * 5.0, 0, 3.4)
			f.scale = Vector3(1.5, 1.5, 1.5)
			add_child(f)

	var sandbags: PackedScene = load("res://assets3d/models/detail-barrier-strong-type-a.glb")
	if sandbags:
		for i in range(6):
			var a := PI * (0.15 + 0.7 * (float(i) / 5.0))
			var s: Node3D = sandbags.instantiate()
			s.position = Vector3(cos(a) * 4.6, 0, 2.4 + sin(a) * 2.2)
			s.rotation.y = -a
			s.scale = Vector3(1.6, 1.6, 1.6)
			add_child(s)

	# 역 앞 화톳불 (분위기)
	for side in [-1.0, 1.0]:
		var fire := OmniLight3D.new()
		fire.position = Vector3(side * 4.2, 1.2, 3.8)
		fire.light_color = Color(1.0, 0.55, 0.2)
		fire.light_energy = 3.2
		fire.omni_range = 10.0
		add_child(fire)
		_fires.append(fire)

func _build_beacon() -> void:
	beacon = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	beacon.mesh = sph
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.45, 0.85, 1.0)
	bm.emission_enabled = true
	bm.emission = Color(0.4, 0.8, 1.0)
	bm.emission_energy_multiplier = 6.0
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon.material_override = bm
	beacon.position = Vector3(0, 7.0, -3.0)
	add_child(beacon)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 7.0, -3.0)
	light.light_color = Color(0.45, 0.78, 1.0)
	light.light_energy = 4.0
	light.omni_range = 20.0
	add_child(light)
	damage_light = light

	var tw := create_tween().set_loops()
	tw.tween_property(beacon, "scale", Vector3(1.25, 1.25, 1.25), 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(beacon, "scale", Vector3(0.9, 0.9, 0.9), 1.1).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	# 화톳불 흔들림
	for fl in _fires:
		if is_instance_valid(fl):
			fl.light_energy = 3.2 + sin(Time.get_ticks_msec() * 0.008 + fl.position.x) * 0.7

func take_damage(amount: float) -> void:
	GameManager.base_hp = max(0.0, GameManager.base_hp - amount)
	GameManager.base_hp_changed.emit()

	var ratio: float = clamp(GameManager.base_hp / GameManager.base_max_hp, 0.0, 1.0)
	var col := Color(0.45, 0.78, 1.0).lerp(Color(1.0, 0.25, 0.15), 1.0 - ratio)
	if damage_light:
		damage_light.light_color = col
	if beacon:
		var bm: StandardMaterial3D = beacon.material_override
		bm.albedo_color = col
		bm.emission = col

	if GameManager.base_hp <= 0:
		GameManager.game_over.emit("base")
