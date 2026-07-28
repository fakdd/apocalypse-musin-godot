extends WorldSystem
class_name BiomeBuilder
## 챕터별 자연 지형 — 나무·바위·풀·절벽·호수·거대 구조물.
##
## 왜 필요했나:
##   챕터마다 하늘색과 캠페인 JSON 은 달랐지만 **지형은 전부 폐허 도시**였다.
##   숲인데 아스팔트 도로와 빌딩이 서 있었다.
##
## 어떻게:
##   전용 3D 에셋이 없으므로 프리미티브(원기둥·구·상자)를 조합해 만든다.
##   기존 건물 생성과 같은 방식이다. 종류마다 메시 하나를 만들고
##   **MultiMesh 인스턴스 수천 개**로 뿌리므로 드로우콜은 종류 수만큼만 는다.
##
## 무엇을 읽나:
##   ChapterConfig.BIOMES[챕터] — 종류·개수·크기·색·호수·거대구조물·절벽
##   kind 가 "city" 면 아무것도 만들지 않는다 (기존 도시 생성이 그대로 돈다).

## 랜드마크·방주 근처에는 심지 않는다 (진입과 전투를 방해한다)
const CLEAR_BASE := 17.0        ## 중앙 안전지대 여유
const CLEAR_MARK := 9.0         ## 랜드마크 중심 여유
const EDGE := 2.0

var _mark_spots: Array[Vector3] = []

func build_biome() -> void:
	var n: int = GameManager.chapter
	if ChapterConfig.is_city(n):
		return                    ## 도시는 기존 생성이 담당한다

	var b: Dictionary = ChapterConfig.biome_of(n)
	_collect_marks()

	_build_cliffs(int(b.get("cliffs", 0)), b)
	_build_water(b.get("water", [0.0, Color.WHITE]))
	for spec in b.get("props", []):
		_scatter(spec)
	_build_hero(b.get("hero", ["", 0.0, Color.WHITE]))

	print("[Biome] %s — 소품 %d종 · 절벽 %d · 랜드마크 회피 %d곳"
		% [String(b.get("kind", "?")), b.get("props", []).size(),
		int(b.get("cliffs", 0)), _mark_spots.size()])

## 캠페인이 만든 랜드마크 위치를 모아 둔다 (그 위에는 심지 않는다).
func _collect_marks() -> void:
	_mark_spots.clear()
	for lm in LandmarkRegistry.landmarks:
		_mark_spots.append(lm.center)

func _blocked(pos: Vector3) -> bool:
	if pos.distance_to(world_center()) < CLEAR_BASE:
		return true
	for m in _mark_spots:
		if pos.distance_to(m) < CLEAR_MARK:
			return true
	return false

## ══════════════════════════════════════════════
##  소품 — 종류마다 MultiMesh 하나
## ══════════════════════════════════════════════
func _scatter(spec: Array) -> void:
	if spec.size() < 5:
		return
	var kind: String = String(spec[0])
	var count: int = int(spec[1])
	var lo: float = float(spec[2])
	var hi: float = float(spec[3])
	var col: Color = spec[4]

	# data/models.json 의 props 에 실제 모델이 있으면 그것을 쓴다.
	# 없으면 아래 기본 도형으로 돌아간다 — 일부만 교체해도 된다.
	var mesh: Mesh = null
	var model_mat: Material = null
	var mpath := String(VfxPool.models().get("props", {}).get(kind, ""))
	if mpath != "":
		var got := VfxPool.mesh_of(mpath)
		if got.size() >= 2:
			mesh = got[0]
			model_mat = got[1]
	# 받아 온 모델은 팩마다 단위가 달라 그대로 쓰면 거대한 검은 덩어리가 된다.
	# AABB 로 재서 목표 높이에 맞춘다.
	var fit := 1.0
	if mesh != null:
		var tgt := float(VfxPool.models().get("props_size", {}).get(kind, 0.0))
		if tgt > 0.0:
			fit = VfxPool.fit_scale(mesh, tgt)
	if mesh == null:
		mesh = _mesh_for(kind)
	if mesh == null:
		return

	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var tries := 0
	while xforms.size() < count and tries < count * 6:
		tries += 1
		var pos := Vector3(randf_range(EDGE, ARENA_W - EDGE), 0.0,
			randf_range(EDGE, ARENA_H - EDGE))
		if _blocked(pos):
			continue
		var s: float = randf_range(lo, hi) * fit
		var t := Transform3D(Basis(), pos)
		t = t.rotated_local(Vector3.UP, randf_range(0.0, TAU))
		# 가로세로를 살짝 다르게 줘 복제 티를 줄인다
		t = t.scaled_local(Vector3(s * randf_range(0.85, 1.15), s,
			s * randf_range(0.85, 1.15)))
		xforms.append(t)
		# 개체마다 색을 흔들어 "전부 같은 나무" 로 안 보이게 한다
		var v: float = randf_range(0.82, 1.18)
		colors.append(Color(col.r * v, col.g * v, col.b * v))

	if xforms.is_empty():
		return
	# 모델에 딸린 머티리얼이 있으면 그것을 쓴다 (색이 통짜로 죽지 않게).
	# 기본 도형일 때만 색 지정 머티리얼을 덮어쓴다.
	_commit(mesh, model_mat if model_mat != null else _mat(col),
		xforms, colors, "Biome_" + kind)

## 프리미티브를 조합해 종류별 메시를 만든다.
## ArrayMesh 로 합치지 않고 대표 형태 하나만 쓴다 — MultiMesh 는 메시 1개만 받는다.
func _mesh_for(kind: String) -> Mesh:
	match kind:
		"tree", "palm":
			# 둥근 수관 — 줄기는 아래에서 가려지므로 수관만으로 충분히 읽힌다
			var s := SphereMesh.new()
			s.radius = 1.0
			s.height = 2.6
			s.radial_segments = 6
			s.rings = 4
			return s
		"pine":
			var c := CylinderMesh.new()
			c.top_radius = 0.02
			c.bottom_radius = 1.0
			c.height = 3.2
			c.radial_segments = 6
			return c
		"dead_tree":
			var c2 := CylinderMesh.new()
			c2.top_radius = 0.12
			c2.bottom_radius = 0.34
			c2.height = 3.0
			c2.radial_segments = 5
			return c2
		"cactus":
			var c3 := CylinderMesh.new()
			c3.top_radius = 0.34
			c3.bottom_radius = 0.40
			c3.height = 2.4
			c3.radial_segments = 7
			return c3
		"rock", "boulder":
			var b := BoxMesh.new()
			b.size = Vector3(1.2, 0.9, 1.1)
			return b
		"grass", "bush":
			var b2 := BoxMesh.new()
			b2.size = Vector3(0.5, 0.7, 0.5)
			return b2
		"pillar":
			var c4 := CylinderMesh.new()
			c4.top_radius = 0.5
			c4.bottom_radius = 0.62
			c4.height = 3.0
			c4.radial_segments = 6
			return c4
		"spike", "crystal", "shard":
			var c5 := CylinderMesh.new()
			c5.top_radius = 0.02
			c5.bottom_radius = 0.46
			c5.height = 2.6
			c5.radial_segments = 5
			return c5
		"bone":
			var b3 := BoxMesh.new()
			b3.size = Vector3(0.22, 0.22, 1.4)
			return b3
	return null

func _mat(base: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = base
	m.vertex_color_use_as_albedo = true      ## per-instance 색을 쓴다
	m.roughness = 0.92
	m.metallic = 0.0
	return m

func _commit(mesh: Mesh, mat: Material, xforms: Array, colors: Array,
		node_name: String) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors.size() > 0
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
		if colors.size() > i:
			mm.set_instance_color(i, colors[i])
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	# 모델에 딸린 머티리얼이 있으면 그것을 쓴다 (색이 통짜로 죽지 않게).
	# 기본 도형일 때만 색 지정 머티리얼을 덮어쓴다.
	node.material_override = mat
	# 그림자를 끄면 수천 그루도 부담이 적다 (기존 소품과 같은 선택)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)

## ══════════════════════════════════════════════
##  절벽 — 맵 가장자리를 둘러 "여기가 지역의 끝" 을 보여 준다
## ══════════════════════════════════════════════
func _build_cliffs(count: int, b: Dictionary) -> void:
	if count <= 0:
		return
	var col: Color = Color(0.32, 0.30, 0.28)
	var props: Array = b.get("props", [])
	if props.size() > 0:
		col = props[0][4]
	col = col.darkened(0.35)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var cx: float = ARENA_W * 0.5
	var cz: float = ARENA_H * 0.5
	for i in range(count):
		var a: float = TAU * float(i) / float(count) + randf_range(-0.06, 0.06)
		var r: float = ARENA_W * 0.5 - randf_range(1.0, 4.0)
		var pos := Vector3(cx + cos(a) * r, 0.0, cz + sin(a) * r)
		var h: float = randf_range(9.0, 18.0)
		var w: float = randf_range(7.0, 13.0)
		var t := Transform3D(Basis(), pos + Vector3(0, h * 0.4, 0))
		t = t.rotated_local(Vector3.UP, a)
		t = t.scaled_local(Vector3(w, h, w * randf_range(0.6, 1.0)))
		xforms.append(t)
		var v: float = randf_range(0.85, 1.15)
		colors.append(Color(col.r * v, col.g * v, col.b * v))
	_commit(mesh, _mat(col), xforms, colors, "Biome_cliffs")

## ══════════════════════════════════════════════
##  물 — 호수 / 용암 / 검은 바다
## ══════════════════════════════════════════════
func _build_water(spec: Array) -> void:
	if spec.size() < 2 or float(spec[0]) <= 0.0:
		return
	var radius: float = float(spec[0])
	var col: Color = spec[1]

	# 랜드마크와 방주를 피한 자리에 놓는다
	var pos := world_center()
	for _i in range(60):
		var p := Vector3(randf_range(radius + 4.0, ARENA_W - radius - 4.0), 0.0,
			randf_range(radius + 4.0, ARENA_H - radius - 4.0))
		if p.distance_to(world_center()) < CLEAR_BASE + radius:
			continue
		var ok := true
		for m in _mark_spots:
			if p.distance_to(m) < CLEAR_MARK + radius:
				ok = false
				break
		if ok:
			pos = p
			break

	var plane := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = radius
	pm.bottom_radius = radius * 0.92
	pm.height = 0.35
	pm.radial_segments = 24
	plane.mesh = pm
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = col
	m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m2.roughness = 0.06
	m2.metallic = 0.25
	if col.r > 0.6 and col.g < 0.4:          ## 용암은 스스로 빛난다
		m2.emission_enabled = true
		m2.emission = col
		m2.emission_energy_multiplier = 2.6
	plane.material_override = m2
	plane.position = pos + Vector3(0, 0.1, 0)
	plane.name = "Biome_water"
	world.add_child(plane)

	# 용암/심연은 주변을 물들인다
	if m2.emission_enabled:
		var light := OmniLight3D.new()
		light.position = pos + Vector3(0, 3.0, 0)
		light.light_color = col
		light.light_energy = 3.0
		light.omni_range = radius * 2.4
		world.add_child(light)

## ══════════════════════════════════════════════
##  거대 구조물 — 멀리서 보이는 이정표
## ══════════════════════════════════════════════
func _build_hero(spec: Array) -> void:
	if spec.size() < 3 or String(spec[0]) == "":
		return
	var kind: String = String(spec[0])
	var height: float = float(spec[1])
	var col: Color = spec[2]

	# 방주에서 잘 보이도록 가장자리 쪽 빈 자리에 세운다
	var pos := world_center() + Vector3(0, 0, -ARENA_H * 0.32)
	for _i in range(50):
		var a := randf_range(0.0, TAU)
		var r := randf_range(ARENA_W * 0.26, ARENA_W * 0.36)
		var p := world_center() + Vector3(cos(a) * r, 0, sin(a) * r)
		var ok := true
		for m in _mark_spots:
			if p.distance_to(m) < 13.0:
				ok = false
				break
		if ok:
			pos = p
			break

	var root := Node3D.new()
	root.name = "Biome_hero_" + kind
	root.position = pos
	world.add_child(root)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85

	match kind:
		"worldtree":
			_part(root, _cyl(2.6, 4.2, height * 0.62, 8), mat,
				Vector3(0, height * 0.31, 0))
			var leaf := StandardMaterial3D.new()
			leaf.albedo_color = col.lightened(0.1)
			leaf.roughness = 0.9
			for i in range(3):
				var s := SphereMesh.new()
				s.radius = 9.0 - float(i) * 1.6
				s.height = s.radius * 1.5
				_part(root, s, leaf,
					Vector3(randf_range(-3, 3), height * (0.66 + 0.11 * i),
						randf_range(-3, 3)))
		"pyramid":
			# 상자를 층으로 쌓아 계단식 피라미드를 만든다
			var steps := 7
			for i in range(steps):
				var f: float = 1.0 - float(i) / float(steps)
				var b := BoxMesh.new()
				b.size = Vector3(24.0 * f, height / float(steps), 24.0 * f)
				_part(root, b, mat,
					Vector3(0, height * (float(i) + 0.5) / float(steps), 0))
		"spire", "tower":
			_part(root, _cyl(0.3, 5.0, height, 8), mat, Vector3(0, height * 0.5, 0))
			for i in range(3):
				_part(root, _cyl(0.2, 2.2, height * 0.5, 6), mat,
					Vector3(cos(TAU * i / 3.0) * 5.0, height * 0.25,
						sin(TAU * i / 3.0) * 5.0))
		"volcano":
			_part(root, _cyl(6.0, 20.0, height, 12), mat, Vector3(0, height * 0.5, 0))
			var lava := StandardMaterial3D.new()
			lava.albedo_color = Color(1.0, 0.42, 0.10)
			lava.emission_enabled = true
			lava.emission = Color(1.0, 0.35, 0.05)
			lava.emission_energy_multiplier = 4.0
			lava.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_part(root, _cyl(5.2, 5.2, 0.6, 12), lava, Vector3(0, height, 0))
			var gl := OmniLight3D.new()
			gl.position = Vector3(0, height + 2.0, 0)
			gl.light_color = Color(1.0, 0.45, 0.15)
			gl.light_energy = 6.0
			gl.omni_range = 40.0
			root.add_child(gl)
		"gate":
			# 하늘까지 닿는 문 — 기둥 둘 + 상인방
			_part(root, _box(3.0, height, 3.0), mat, Vector3(-7.0, height * 0.5, 0))
			_part(root, _box(3.0, height, 3.0), mat, Vector3(7.0, height * 0.5, 0))
			_part(root, _box(18.0, 3.0, 3.4), mat, Vector3(0, height, 0))
			var void_mat := StandardMaterial3D.new()
			void_mat.albedo_color = Color(col.r, col.g, col.b, 0.55)
			void_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			void_mat.emission_enabled = true
			void_mat.emission = col
			void_mat.emission_energy_multiplier = 3.0
			void_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_part(root, _box(11.0, height * 0.92, 0.4), void_mat,
				Vector3(0, height * 0.48, 0))

	# 이정표는 멀리서도 보여야 한다 — 약한 상승광
	var beam := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.4
	bm.bottom_radius = 3.0
	bm.height = height * 1.6
	beam.mesh = bm
	beam.material_override = SharedMaterials.unshaded_fade(
		Color(col.r, col.g, col.b, 0.07), 1.4)
	beam.position = Vector3(0, height * 0.8, 0)
	root.add_child(beam)

func _part(root: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)

func _cyl(top: float, bottom: float, h: float, seg: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c

func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b
