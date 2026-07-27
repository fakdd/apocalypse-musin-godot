extends WorldSystem
class_name LandmarkManager
## **지형 전용** — 바닥/도로/보도/도시 블록/외곽 스카이라인/경계벽/방주.
##
## ⚠ 이 매니저는 **랜드마크를 만들지 않습니다.**
##   랜드마크는 CampaignManager 가 캠페인 JSON 을 읽어 만듭니다
##   (res://data/campaigns/campaign_<id>.json 이 유일한 데이터 소스).
##
##   그래서 여기에는 랜드마크 위치·이름·스폰 테이블이 **하드코딩되어 있지 않습니다.**
##   노드를 추가/삭제/이동하려면 Campaign Builder 에서 고치고 다시 내보내면 됩니다.
##
## 도시 건물이 놓인 자리는 참고용으로 노출합니다 —
## 캠페인 좌표를 건물 위로 스냅하고 싶을 때 쓸 수 있습니다.
var building_spots: Array[Vector3] = []

## 지형과 건축물을 순서대로 만든다.
## (순서가 중요: 도시가 점유 칸을 등록해야 보도/소품이 그 위를 피한다)
func build_all() -> void:
	_build_ground()
	_build_city()
	_build_skyline()
	_build_sidewalks()
	_build_boundary()
	# 지형/건물/스카이라인의 정적 메시를 MultiMesh 로 확정한다.
	# (드로우콜 2만 → 수백 대로 줄어드는 지점)
	batch_commit("CityBatch")

## 방주 랜드마크 (소품 배치 이후에 세운다)
func build_base() -> void:
	_build_base_and_spots()

func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	world.add_child(ground)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ARENA_W + 20, 1.0, ARENA_H + 20)
	col.shape = box
	col.position = Vector3(ARENA_W * 0.5, -0.5, ARENA_H * 0.5)
	ground.add_child(col)

	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(ARENA_W + 30, ARENA_H + 30)
	# 노멀맵이 제대로 먹도록 면을 잘게 나눈다
	pm.subdivide_width = 24
	pm.subdivide_depth = 24
	plane.mesh = pm
	plane.material_override = _make_pbr_material(
		"res://assets3d/textures/asphalt_albedo.jpg",
		"res://assets3d/textures/asphalt_normal.jpg",
		"res://assets3d/textures/asphalt_rough.jpg",
		"res://assets3d/textures/asphalt_ao.jpg",
		Vector3(26, 26, 1), Color(0.56, 0.54, 0.53))
	var gm: StandardMaterial3D = plane.material_override
	gm.metallic = 0.12
	gm.metallic_specular = 0.35
	plane.position = Vector3(ARENA_W * 0.5, -0.02, ARENA_H * 0.5)
	world.add_child(plane)

	for x in range(COLS):
		for z in range(ROWS):
			if not _is_road(x, z):
				continue
			var pos := Vector3(x * TILE + TILE * 0.5, 0.0, z * TILE + TILE * 0.5)
			var path := "res://assets3d/models/road-asphalt-straight.glb"
			var rot := 0.0 if _is_horizontal_road(z) else PI * 0.5
			if randf() < 0.18:
				path = "res://assets3d/models/road-asphalt-damaged.glb"
				rot = float(randi() % 4) * PI * 0.5
			# 도로 모델은 1(X) x 2(Z) 이므로 X만 2배로 늘려 TILE(2x2)을 꽉 채운다
			bake(path, pos, rot, Vector3(TILE, 1.0, 1.0))
## 도로에 인접한 빈 칸에 보도블록을 깔아 도시 골격을 또렷하게 만든다.
## (건물은 이 다음에 세워지므로 겹치는 칸은 건물이 덮는다)
func _build_sidewalks() -> void:
	for x in range(COLS):
		for z in range(ROWS):
			if _is_road(x, z) or occupied_cells.has(Vector2i(x, z)):
				continue
			# 중앙 대로변에만 보도를 깐다 (모든 도로에 깔면 지면을 다 덮어버린다)
			if not _adjacent_to_main_road(x, z):
				continue
			# 일부는 비워둬 부서진 보도처럼 보이게 한다
			if randf() < 0.34:
				continue
			var ppos := Vector3(x * TILE + TILE * 0.5, 0.005, z * TILE + TILE * 0.5)
			# 밝은 콘크리트를 어둡게 눌러 도로/건물과 구분되되 튀지 않게
			bake("res://assets3d/models/road-asphalt-pavement.glb", ppos,
				float(randi() % 4) * PI * 0.5, Vector3(TILE, 1.0, 1.0),
				randf_range(0.45, 0.62))
func _build_city() -> void:
	# 낮은 건물은 Meshy 로 만든 폐허 블록(wartorn_block)을 우선 사용한다.
	var wartorn = load("res://assets3d/buildings/wartorn_block.obj")

	# 큐브형 모듈만 사용한다 (wall-*-flat 은 두께 0 인 평면이라 건물 블록으로 못 쓴다)
	var wall_kinds = [
		"res://assets3d/models/wall-a-window.glb",
		"res://assets3d/models/wall-b-window.glb",
	]
	var roofs = [
		"res://assets3d/models/wall-a-roof.glb",
		"res://assets3d/models/wall-b-roof.glb",
	]

	var block_seeds = []
	for bx in range(1, COLS - 1):
		for bz in range(1, ROWS - 1):
			if _is_road(bx, bz) or _in_base_zone(bx, bz):
				continue
			block_seeds.append(Vector2i(bx, bz))
	block_seeds.shuffle()

	var used := occupied_cells
	var buildings := 0
	for seed_cell in block_seeds:
		if buildings >= 22:
			break
		var w := 2 + randi() % 2
		var d := 2 + randi() % 2
		var ok := true
		for ox in range(w):
			for oz in range(d):
				var c := Vector2i(seed_cell.x + ox, seed_cell.y + oz)
				if used.has(c) or _is_road(c.x, c.y) or _in_base_zone(c.x, c.y) \
					or c.x < 1 or c.x >= COLS - 1 or c.y < 1 or c.y >= ROWS - 1:
					ok = false
					break
			if not ok:
				break
		if not ok:
			continue

		# 시야를 가리지 않도록 플레이 구역은 1층 폐허로만 짓는다.
		# 고층 빌딩은 맵 외곽(스카이라인)에만 세워 배경 역할만 하게 한다.
		var skyline := _is_skyline_cell(seed_cell.x, seed_cell.y)
		var floors: int = (3 + randi() % 4) if skyline else 1
		var kind: String = wall_kinds[randi() % wall_kinds.size()]
		var roof: String = roofs[randi() % roofs.size()]
		# 건물 전체가 하나의 방향을 공유해야 벽면이 이어져 보인다.
		var facing := float(randi() % 4) * PI * 0.5

		# 모듈 원본은 1x1x1 이므로 TILE(2.0) 만큼 확대해야 칸을 꽉 채워 서로 붙는다.
		# 플레이 구역 폐허는 층 높이를 낮춰(0.62배) 카메라 시야를 막지 않게 한다.
		var h_mult: float = 1.0 if skyline else 0.62
		var floor_h: float = TILE * h_mult
		var mod_scale := Vector3(TILE * 1.002, floor_h * 1.002, TILE * 1.002)
		# 건물마다 미묘하게 다른 색조 (같은 모델이 반복되는 느낌을 줄인다)
		var tint_shift: float = randf_range(0.78, 1.15)
		var roof_h: float = floor_h * 0.5

		for ox in range(w):
			for oz in range(d):
				var c := Vector2i(seed_cell.x + ox, seed_cell.y + oz)
				used[c] = true
				var base_pos := Vector3(c.x * TILE + TILE * 0.5, 0, c.y * TILE + TILE * 0.5)
				for f in range(floors):
					bake(kind, base_pos + Vector3(0, f * floor_h, 0), facing, mod_scale, tint_shift)
				bake(roof, base_pos + Vector3(0, floors * floor_h, 0), facing, mod_scale, tint_shift)

		# 낮은 폐허에는 부서진 벽체를 얹어 폐허 느낌을 살린다
		if not skyline:
			var broken = ["res://assets3d/models/wall-broken-type-a.glb", "res://assets3d/models/wall-broken-type-b.glb"]
			for k in range(1 + randi() % 3):
				var bx: int = seed_cell.x + randi() % w
				var bz: int = seed_cell.y + randi() % d
				bake(broken[randi() % 2],
					Vector3(bx * TILE + TILE * 0.5, floors * floor_h + roof_h * 0.4, bz * TILE + TILE * 0.5),
					float(randi() % 4) * PI * 0.5, Vector3(1.4, 1.4, 1.4))

		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = Vector3(
			(seed_cell.x + w * 0.5) * TILE,
			0,
			(seed_cell.y + d * 0.5) * TILE
		)
		world.add_child(body)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(w * TILE, floors * floor_h + roof_h, d * TILE)
		shape.shape = box
		shape.position.y = box.size.y * 0.5
		body.add_child(shape)
		buildings += 1

		# 플레이 구역의 낮은 폐허만 랜드마크 후보로 등록한다
		# (스카이라인 고층은 맵 밖 배경이라 들어갈 수 없다)
		if not skyline:
			building_spots.append(Vector3(body.position.x, 0.0, body.position.z))
## 맵 바깥에 고층 스카이라인을 세운다 — 배경 역할만 하고 플레이에 개입하지 않는다.
func _build_skyline() -> void:
	var wall_kinds = [
		"res://assets3d/models/wall-a-window.glb",
		"res://assets3d/models/wall-b-window.glb",
	]
	var roofs = [
		"res://assets3d/models/wall-a-roof.glb",
		"res://assets3d/models/wall-b-roof.glb",
	]
	var mod := TILE
	var mod_scale := Vector3(mod * 1.004, mod * 1.004, mod * 1.004)

	# 맵 경계 바깥으로 3겹의 타워 링
	for ring in range(3):
		var pad: float = 6.0 + ring * 9.0
		var step: float = 7.0 + ring * 2.0
		var x := -pad
		while x <= ARENA_W + pad:
			for side in [-pad, ARENA_H + pad]:
				if randf() < 0.28:
					x += step
					continue
				_place_tower(Vector3(x, 0, side), wall_kinds, roofs, mod, mod_scale, ring)
			x += step
		var z := -pad
		while z <= ARENA_H + pad:
			for side in [-pad, ARENA_W + pad]:
				if randf() < 0.28:
					z += step
					continue
				_place_tower(Vector3(side, 0, z), wall_kinds, roofs, mod, mod_scale, ring)
			z += step
func _place_tower(pos: Vector3, wall_kinds: Array, roofs: Array,
		mod: float, mod_scale: Vector3, ring: int) -> void:
	var floors: int = 5 + randi() % (8 + ring * 4)
	var w: int = 1 + randi() % 2
	var d: int = 1 + randi() % 2
	var kind: String = wall_kinds[randi() % wall_kinds.size()]
	var roof: String = roofs[randi() % roofs.size()]
	var facing := float(randi() % 4) * PI * 0.5
	var tint: float = randf_range(0.35, 0.62)   # 원경이라 어둡게

	for ox in range(w):
		for oz in range(d):
			var base_pos := pos + Vector3(ox * mod, 0, oz * mod)
			for f in range(floors):
				bake(kind, base_pos + Vector3(0, f * mod, 0), facing, mod_scale, tint)
			bake(roof, base_pos + Vector3(0, floors * mod, 0), facing, mod_scale, tint)
func _build_boundary() -> void:
	var wall_h := 4.0
	var thickness := 2.0
	var defs = [
		[Vector3(ARENA_W * 0.5, 0, -thickness * 0.5), Vector3(ARENA_W + thickness * 2, wall_h, thickness)],
		[Vector3(ARENA_W * 0.5, 0, ARENA_H + thickness * 0.5), Vector3(ARENA_W + thickness * 2, wall_h, thickness)],
		[Vector3(-thickness * 0.5, 0, ARENA_H * 0.5), Vector3(thickness, wall_h, ARENA_H + thickness * 2)],
		[Vector3(ARENA_W + thickness * 0.5, 0, ARENA_H * 0.5), Vector3(thickness, wall_h, ARENA_H + thickness * 2)],
	]
	for d in defs:
		var body := StaticBody3D.new()
		body.position = d[0]
		body.collision_layer = 1
		body.collision_mask = 0
		world.add_child(body)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = d[1]
		shape.shape = box
		shape.position.y = wall_h * 0.5
		body.add_child(shape)

	var models = ["res://assets3d/models/wall-broken-type-a.glb", "res://assets3d/models/wall-broken-type-b.glb"]
	var bs := Vector3(1.6, 1.6, 1.6)
	for x in range(COLS):
		bake(models[randi() % 2], Vector3(x * TILE + TILE * 0.5, 0, -0.6), 0.0, bs)
		bake(models[randi() % 2], Vector3(x * TILE + TILE * 0.5, 0, ARENA_H + 0.6), PI, bs)
	for z in range(ROWS):
		bake(models[randi() % 2], Vector3(-0.6, 0, z * TILE + TILE * 0.5), PI * 0.5, bs)
		bake(models[randi() % 2], Vector3(ARENA_W + 0.6, 0, z * TILE + TILE * 0.5), -PI * 0.5, bs)
func _build_base_and_spots() -> void:
	var center := world_center()
	world.base_core = load("res://scripts3d/BaseCore3D.gd").new()
	world.base_core.position = center
	world.add_child(world.base_core)

	# 마도 제단 (특성 재주사) — 방주 앞쪽
	var altar = load("res://scripts3d/Altar3D.gd").new()
	altar.position = center + Vector3(0, 0, 9.5)
	world.add_child(altar)

	# 안전지대 경계 표시 + 따뜻한 조명 (분위기: 상대적으로 안락함)
	var border := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = SAFE_RADIUS - 0.35
	torus.outer_radius = SAFE_RADIUS
	border.mesh = torus
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1.0, 0.78, 0.45, 0.35)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.72, 0.4)
	bm.emission_energy_multiplier = 2.0
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	border.material_override = bm
	border.position = center + Vector3(0, 0.08, 0)
	world.add_child(border)

	# 안전지대 횃불 (항상 켜짐)
	for i in range(8):
		var a := TAU * i / 8.0
		var tpos := center + Vector3(cos(a) * (SAFE_RADIUS - 1.5), 0, sin(a) * (SAFE_RADIUS - 1.5))
		_add_model("res://assets3d/models/detail-light-single.glb", tpos, -a, 1.7)
		var tl := OmniLight3D.new()
		tl.position = tpos + Vector3(0, 4.2, 0)
		tl.light_color = Color(1.0, 0.7, 0.38)
		tl.light_energy = 2.6
		tl.omni_range = 12.0
		world.add_child(tl)
