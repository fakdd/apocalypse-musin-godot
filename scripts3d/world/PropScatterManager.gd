extends WorldSystem
class_name PropScatterManager
## 소품과 분위기 — 잔해/차량/가로등/침식 결정/파티클(먼지·재·연기·불티).

## 소품·차량·가로등·침식 결정을 배치한다.
## 침식 결정 / 이끼는 전용 MultiMesh 로 묶는다 (공유 메시 + per-instance 색)
var _shard_mm_xforms: Array[Transform3D] = []
var _shard_mm_colors: Array[Color] = []
var _moss_mm_xforms: Array[Transform3D] = []

func build_scatter_and_detail() -> void:
	_build_scatter()
	_build_street_detail()
	_build_corruption()
	_commit_corruption()
	# 정적 소품 전체를 MultiMesh 로 확정한다
	batch_commit("PropBatch")

## 침식 결정과 이끼를 각각 MultiMeshInstance3D 하나로 만든다.
func _commit_corruption() -> void:
	if _shard_mm_xforms.size() > 0:
		var pm := PrismMesh.new()
		pm.size = Vector3(0.2, 0.6, 0.2)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.30, 0.05, 0.09)
		m.emission_enabled = true
		m.emission = Color(0.45, 0.06, 0.10)
		m.emission_energy_multiplier = 0.2
		m.roughness = 0.5
		m.vertex_color_use_as_albedo = true
		_commit_mm(pm, m, _shard_mm_xforms, _shard_mm_colors, "CorruptionShards")

	if _moss_mm_xforms.size() > 0:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.0
		cyl.bottom_radius = 1.0
		cyl.height = 0.04
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(0.2, 0.03, 0.07, 0.75)
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.roughness = 1.0
		_commit_mm(cyl, mm, _moss_mm_xforms, [], "CorruptionMoss")

func _commit_mm(mesh: Mesh, mat: Material, xforms: Array, colors: Array, node_name: String) -> void:
	var mmesh := MultiMesh.new()
	mmesh.transform_format = MultiMesh.TRANSFORM_3D
	mmesh.use_colors = colors.size() > 0
	mmesh.mesh = mesh
	mmesh.instance_count = xforms.size()
	for i in range(xforms.size()):
		mmesh.set_instance_transform(i, xforms[i])
		if colors.size() > i:
			mmesh.set_instance_color(i, colors[i])
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mmesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)

## 대기 파티클(먼지/재/낙엽) + 연기 기둥 + 모닥불
func build_atmosphere() -> void:
	_build_atmosphere()

func _build_scatter() -> void:
	var center := world_center()
	var props = [
		"res://assets3d/models/truck-grey.glb",
		"res://assets3d/models/truck-green-cargo.glb",
		"res://assets3d/models/detail-dumpster-closed.glb",
		"res://assets3d/models/scaffolding-structure.glb",
	]
	var placed := 0
	var attempts := 0
	while placed < 30 and attempts < 900:
		attempts += 1
		var pos := Vector3(randf_range(4, ARENA_W - 4), 0, randf_range(4, ARENA_H - 4))
		if pos.distance_to(center) < 12.0:
			continue
		# 큰 소품은 반경 3.2 를 차지한다
		if not _claim_spot(pos, 3.2):
			continue
		# 트럭류만 실제 장애물로 두고, 나머지는 통과 가능하게 (걸림 방지)
		var chosen: String = props[randi() % props.size()]
		if "truck" in chosen:
			_add_static_obstacle(chosen, pos, randf() * TAU, Vector3(2.4, 2.0, 2.4), 1.5)
		else:
			bake(chosen, pos, randf() * TAU, Vector3(1.5, 1.5, 1.5))
		placed += 1

	var small = [
		"res://assets3d/models/barrel.glb",
		"res://assets3d/models/box-large.glb",
		"res://assets3d/models/rock-a.glb",
		"res://assets3d/models/rock-b.glb",
		"res://assets3d/models/detail-barrier-type-a.glb",
		"res://assets3d/models/detail-barrier-strong-damaged.glb",
		"res://assets3d/models/pallet.glb",
	]
	for i in range(85):
		var pos := _free_spot(center, 6.0, 1.5)
		if pos == Vector3.INF:
			continue
		var ss := randf_range(1.0, 1.6)
		bake(small[randi() % small.size()], pos, randf() * TAU, Vector3(ss, ss, ss))

	var trees = ["res://assets3d/models/tree-large.glb", "res://assets3d/models/tree-pine-large.glb", "res://assets3d/models/tree-shrub.glb"]
	for i in range(45):
		var pos := _free_spot(center, 10.0, 2.2)
		if pos == Vector3.INF:
			continue
		var ts := randf_range(1.4, 2.2)
		bake(trees[randi() % trees.size()], pos, randf() * TAU, Vector3(ts, ts, ts))

	for i in range(40):
		var pos := _free_spot(center, 7.0, 2.0)
		if pos == Vector3.INF:
			continue
		bake("res://assets3d/models/detail-light-single.glb", pos, randf() * TAU, Vector3(1.8, 1.8, 1.8))
		var light := OmniLight3D.new()
		light.position = pos + Vector3(0, 4.4, 0)
		light.light_color = Color(1.0, 0.72, 0.4)
		light.light_energy = 0.0
		light.omni_range = 13.0
		light.add_to_group("street_lights")
		world.add_child(light)
func _build_corruption() -> void:
	var center := world_center()
	# 이계의 결정체 — 건물 사이 그늘진 곳에 낮게 군집
	var clusters := 40
	for c_i in range(clusters):
		var gx := randi() % COLS
		var gz := randi() % ROWS
		if _is_road(gx, gz):
			continue
		var origin := Vector3(gx * TILE + TILE * 0.5, 0, gz * TILE + TILE * 0.5)
		if origin.distance_to(center) < 9.0:
			continue
		for i in range(randi() % 4 + 3):
			var h := randf_range(0.3, 0.9)
			var a := randf() * TAU
			var r := randf_range(0.2, 1.1)
			# 결정 하나하나 메시/재질을 새로 만들면 수백 개의 리소스가 생긴다.
			# 공유 메시 1개 + 공유 재질 1개에 스케일/색만 인스턴스별로 준다.
			_shard_mm_xforms.append(Transform3D(
				Basis(Vector3.UP, randf() * TAU).scaled(Vector3(
					randf_range(0.12, 0.3) / 0.2, h / 0.6, randf_range(0.12, 0.3) / 0.2)),
				origin + Vector3(cos(a) * r, h * 0.35, sin(a) * r)))
			_shard_mm_colors.append(Color(1.0, 1.0, 1.0).lerp(Color(0.75, 0.85, 1.5), randf()))

	# 검붉은 이끼 얼룩
	for i in range(90):
		var gx := randi() % COLS
		var gz := randi() % ROWS
		var pos := Vector3(gx * TILE + randf_range(-0.9, 0.9) + TILE * 0.5, 0, gz * TILE + randf_range(-0.9, 0.9) + TILE * 0.5)
		if pos.distance_to(center) < 7.0:
			continue
		var r := randf_range(0.7, 1.8)
		_moss_mm_xforms.append(Transform3D(
			Basis(Vector3.UP, randf() * TAU).scaled(Vector3(r, 1.0, r)),
			pos + Vector3(0, 0.02, 0)))
## 거리 디테일 — 신호등·벤치·전선·천막·버려진 차량 군집
func _build_street_detail() -> void:
	var center := world_center()

	# 교차로 근처 신호등
	for i in range(18):
		var pos := _road_free(center, 12.0, 2.2)
		if pos == Vector3.INF:
			continue
		bake("res://assets3d/models/detail-light-traffic.glb", pos, float(randi() % 4) * PI * 0.5, Vector3(1.7, 1.7, 1.7))

	# 이중 가로등 (밤에 점등)
	for i in range(16):
		var pos := _road_free(center, 10.0, 2.2)
		if pos == Vector3.INF:
			continue
		_add_model("res://assets3d/models/detail-light-double.glb", pos, float(randi() % 4) * PI * 0.5, 1.7)
		var light := OmniLight3D.new()
		light.position = pos + Vector3(0, 4.6, 0)
		light.light_color = Color(1.0, 0.74, 0.42)
		light.light_energy = 0.0
		light.omni_range = 12.0
		light.add_to_group("street_lights")
		world.add_child(light)

	# 벤치 / 천막 / 전선
	var props = [
		"res://assets3d/models/detail-bench.glb",
		"res://assets3d/models/detail-awning-small.glb",
		"res://assets3d/models/detail-cables-type-a.glb",
		"res://assets3d/models/detail-cables-type-b.glb",
		"res://assets3d/models/wall-fence.glb",
		"res://assets3d/models/detail-beam.glb",
	]
	for i in range(40):
		var pos := _free_spot(center, 8.0, 1.6)
		if pos == Vector3.INF:
			continue
		_add_model(props[randi() % props.size()], pos, randf() * TAU, randf_range(1.2, 1.8))

	# 버려진 차량 군집 (도로 위에 2~4대씩)
	var cars = [
		"res://assets3d/models/truck-grey.glb",
		"res://assets3d/models/truck-green-cargo.glb",
	]
	# 차량은 무작위로 뿌리면 서로 파묻힌다. 도로 방향을 따라 일정 간격으로 줄지어 세운다.
	for c in range(10):
		var anchor := _road_free(center, 14.0, 4.5)
		if anchor == Vector3.INF:
			continue
		# 이 지점이 가로/세로 도로인지 판단해 그 방향으로 정렬
		var gx: int = int(anchor.x / TILE)
		var gz: int = int(anchor.z / TILE)
		var along := Vector3(1, 0, 0) if _is_horizontal_road(gz) else Vector3(0, 0, 1)
		var yaw := 0.0 if _is_horizontal_road(gz) else PI * 0.5

		var n := 2 + randi() % 3
		for k in range(n):
			# 차 길이(약 4)보다 넓은 간격으로 배치해 절대 겹치지 않게
			var pos := anchor + along * (k * 4.6) + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
			if not _claim_spot(pos, 2.3):
				continue
			_add_static_obstacle(cars[randi() % cars.size()], pos,
				yaw + randf_range(-0.18, 0.18), Vector3(2.4, 1.8, 2.4), 1.5)

	# 잡동사니 (통/상자/양동이/침구)
	var junk = [
		"res://assets3d/models/barrel-open.glb",
		"res://assets3d/models/box-open.glb",
		"res://assets3d/models/bucket.glb",
		"res://assets3d/models/bedroll.glb",
		"res://assets3d/models/rock-c.glb",
		"res://assets3d/models/patch-grass.glb",
	]
	for i in range(200):
		var pos := _free_spot(center, 5.0, 0.85)
		if pos == Vector3.INF:
			continue
		_add_model(junk[randi() % junk.size()], pos, randf() * TAU, randf_range(0.8, 1.7))

	# 바닥을 덮는 잔해 — 벽돌/파이프/철근/판자 (AAA 처럼 빈 바닥을 없앤다)
	var rubble = [
		"res://assets3d/models/detail-bricks-type-a.glb",
		"res://assets3d/models/planks.glb",
		"res://assets3d/models/detail-beam.glb",
		"res://assets3d/models/rock-a.glb",
		"res://assets3d/models/rock-b.glb",
		"res://assets3d/models/rock-c.glb",
	]
	for i in range(320):
		var gx := randi() % COLS
		var gz := randi() % ROWS
		var pos := Vector3(gx * TILE + randf_range(-0.9, 0.9) + TILE * 0.5, 0,
			gz * TILE + randf_range(-0.9, 0.9) + TILE * 0.5)
		if pos.distance_to(center) < 9.0 or occupied_cells.has(Vector2i(gx, gz)):
			continue
		var n := _add_model(rubble[randi() % rubble.size()], pos, randf() * TAU, randf_range(0.5, 1.2))
		_tint_node(n, randf_range(0.55, 0.95))

	# 핏자국 / 그을음 자국 (바닥 데칼 대용 평면)
	for i in range(34):
		var gx := randi() % COLS
		var gz := randi() % ROWS
		var pos := Vector3(gx * TILE + randf_range(-0.8, 0.8) + TILE * 0.5, 0.012,
			gz * TILE + randf_range(-0.8, 0.8) + TILE * 0.5)
		if pos.distance_to(center) < 8.0:
			continue
		var stain := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		var r := randf_range(0.5, 1.6)
		cyl.top_radius = r
		cyl.bottom_radius = r
		cyl.height = 0.02
		cyl.radial_segments = 10
		stain.mesh = cyl
		var sm := StandardMaterial3D.new()
		var blood := randf() < 0.45
		sm.albedo_color = Color(0.24, 0.02, 0.03, 0.8) if blood else Color(0.06, 0.05, 0.05, 0.75)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.roughness = 0.65 if blood else 1.0
		stain.material_override = sm
		stain.position = pos
		world.add_child(stain)
## 대기 파티클 (먼지/재/낙엽) + 폐허의 연기 기둥과 모닥불
func _build_atmosphere() -> void:
	var atmo = load("res://scripts3d/Atmosphere3D.gd").new()
	world.add_child(atmo)

	var center := world_center()
	var AtmoScript = load("res://scripts3d/Atmosphere3D.gd")

	# 연기 기둥 — 무너진 건물에서 피어오른다
	for i in range(14):
		var pos := _open_spot(center, 14.0)
		if pos == Vector3.INF:
			continue
		var smoke: GPUParticles3D = AtmoScript.make_smoke(7.0)
		smoke.position = pos + Vector3(0, 0.4, 0)
		world.add_child(smoke)

	# 모닥불 + 불티 (생존자 흔적)
	for i in range(10):
		var pos := _open_spot(center, 10.0)
		if pos == Vector3.INF:
			continue
		_add_model("res://assets3d/models/campfire-pit.glb", pos, randf() * TAU, 1.6)
		var em: GPUParticles3D = AtmoScript.make_embers()
		em.position = pos + Vector3(0, 0.5, 0)
		world.add_child(em)
		var fl := OmniLight3D.new()
		fl.position = pos + Vector3(0, 1.0, 0)
		fl.light_color = Color(1.0, 0.5, 0.18)
		fl.light_energy = 2.6
		fl.omni_range = 9.0
		fl.add_to_group("campfires")
		world.add_child(fl)
