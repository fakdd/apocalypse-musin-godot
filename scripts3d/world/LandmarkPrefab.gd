extends RefCounted
class_name LandmarkPrefab
## 랜드마크 자리에 실제 구조물을 세운다.
##
## 왜 필요했나:
##   지금까지 랜드마크는 바닥 링 + 광주 + 이름표뿐이었다. "성모 종합병원"
##   이라고 적힌 빈 땅이었다. 지역이 달라도 눈에 보이는 건 같았다.
##
## 역할 분담 (기존 원칙 그대로):
##   캠페인 JSON — **무엇이 어디 있는가** (태양신전이 (60,21) 에 있다)
##   이 파일     — **그것이 어떻게 생겼는가** (신전은 기둥 + 박공 + 계단)
##   그래서 JSON 을 고치지 않아도 외형만 여기서 바꿀 수 있다.
##
## 전용 3D 에셋이 없으므로 프리미티브를 조합한다.
## 나중에 모델이 생기면 archetype 하나의 함수만 갈아 끼우면 된다.

## 랜드마크 id → 구조물 원형.
## 접두어로 찾으므로 구역(hospital_ward)도 본체(hospital)와 같은 원형을 쓴다.
const ARCHETYPES := {
	# ── 1장 숲 ──
	"guard_wood": "grove", "hunter_town": "village",
	"elder_altar": "altar", "spirit_lake": "shrine", "world_tree": "grove",
	# ── 2장 사막 ──
	"oasis": "shrine", "bazaar": "village", "canyon": "fortress",
	"sun_temple": "temple", "kings_tomb": "tomb",
	# ── 3장 설원 ──
	"frozen_lake": "shrine", "snow_fort": "fortress",
	"avalanche": "cave", "ice_cave": "cave", "ice_palace": "palace",
	# ── 4장 화산 ──
	"lava_river": "shrine", "fire_altar": "temple",
	"ash_fort": "fortress", "magma_cave": "cave", "dragon_nest": "nest",
	# ── 5장 도시 ──
	"park": "shrine", "subway": "cave", "hospital": "ruin",
	"dept_store": "ruin", "police_hq": "fortress", "school": "ruin",
	"broadcast": "tower", "highway": "ruin", "power_plant": "fortress",
	# ── 6장 천공 ──
	"cloud_bridge": "shrine", "angel_garden": "grove",
	"sky_temple": "temple", "hidden_vault": "tomb", "citadel": "palace",
	# ── 7장 심연 ──
	"soul_river": "shrine", "demon_altar": "altar",
	"abyss_keep": "palace", "void_cache": "tomb", "end_gate": "gate",
}

## 랜드마크 id 로 원형을 고른다. 모르는 id 는 폐허로 세운다.
static func archetype_for(landmark_id: String) -> String:
	if ARCHETYPES.has(landmark_id):
		return String(ARCHETYPES[landmark_id])
	# 구역 id (hospital_ward) 는 본체(hospital) 를 따른다
	for key in ARCHETYPES:
		if landmark_id.begins_with(String(key) + "_"):
			return String(ARCHETYPES[key])
	return "ruin"

## 구조물을 세운다. parent 는 LandmarkZone (중심에 서 있다) 이므로 로컬 좌표를 쓴다.
static func build(parent: Node3D, data: LandmarkData) -> void:
	var kind := archetype_for(data.id)
	var col: Color = data.minimap_color
	var r: float = data.radius

	var root := Node3D.new()
	root.name = "Prefab_" + kind
	parent.add_child(root)
	# 구역마다 조금씩 다르게 보이도록 회전을 준다
	root.rotation.y = float(hash(data.id) % 360) * 0.01745

	var stone := _mat(col.darkened(0.55), 0.9)
	var accent := _mat(col, 0.7)
	var glow := _emissive(col)

	match kind:
		"temple":
			_temple(root, r, stone, accent, glow)
		"fortress":
			_fortress(root, r, stone, accent)
		"palace":
			_palace(root, r, stone, accent, glow)
		"village":
			_village(root, r, stone, accent)
		"altar":
			_altar(root, r, stone, glow)
		"tomb":
			_tomb(root, r, stone, accent)
		"cave":
			_cave(root, r, stone)
		"nest":
			_nest(root, r, stone, glow)
		"grove":
			_grove(root, r, stone, accent)
		"shrine":
			_shrine(root, r, stone, glow)
		"gate":
			_gate(root, r, stone, glow)
		_:
			_ruin(root, r, stone, accent)

# ══════════════════════════════════════════════
#  원형들
# ══════════════════════════════════════════════
static func _temple(root: Node3D, r: float, stone: Material,
		accent: Material, glow: Material) -> void:
	## 신전 — 계단 + 기둥 열 + 박공
	var w: float = r * 1.05
	_part(root, _box(w, 0.6, w), stone, Vector3(0, 0.3, 0))
	_part(root, _box(w * 0.86, 0.6, w * 0.86), stone, Vector3(0, 0.9, 0))
	var cols := 8
	for i in range(cols):
		var a: float = TAU * float(i) / float(cols)
		_part(root, _cyl(0.34, 0.42, 5.0, 8), accent,
			Vector3(cos(a) * w * 0.36, 3.7, sin(a) * w * 0.36))
	_part(root, _box(w * 0.9, 0.7, w * 0.9), stone, Vector3(0, 6.5, 0))
	_part(root, _cyl(0.0, w * 0.5, 3.0, 4), accent, Vector3(0, 8.3, 0))
	_part(root, _cyl(0.5, 0.5, 1.2, 8), glow, Vector3(0, 1.8, 0))

static func _fortress(root: Node3D, r: float, stone: Material,
		accent: Material) -> void:
	## 요새 — 성벽 사각 + 모서리 탑
	var w: float = r * 0.92
	for s in [Vector3(0, 0, -w), Vector3(0, 0, w),
			Vector3(-w, 0, 0), Vector3(w, 0, 0)]:
		var horiz: bool = absf(s.x) < 0.01
		var size := Vector3(w * 2.0, 4.2, 1.1) if horiz \
			else Vector3(1.1, 4.2, w * 2.0)
		_part(root, _box(size.x, size.y, size.z), stone, s + Vector3(0, 2.1, 0))
	for cx in [-w, w]:
		for cz in [-w, w]:
			_part(root, _cyl(1.5, 1.8, 7.0, 8), accent, Vector3(cx, 3.5, cz))
			_part(root, _cyl(0.0, 2.0, 1.8, 8), stone, Vector3(cx, 7.9, cz))
	# 정문 — 벽 한 칸을 비우는 대신 문틀을 얹는다
	_part(root, _box(3.4, 0.8, 1.4), accent, Vector3(0, 4.6, -w))

static func _palace(root: Node3D, r: float, stone: Material,
		accent: Material, glow: Material) -> void:
	## 궁전 — 본채 + 높은 첨탑 여러 개
	var w: float = r * 0.8
	_part(root, _box(w * 1.6, 6.0, w * 1.2), stone, Vector3(0, 3.0, 0))
	_part(root, _box(w * 1.7, 0.6, w * 1.3), accent, Vector3(0, 6.3, 0))
	var spires := [[0.0, 13.0], [-w * 0.7, 10.0], [w * 0.7, 10.0]]
	for sp in spires:
		var x: float = sp[0]
		var h: float = sp[1]
		_part(root, _cyl(0.9, 1.5, h, 8), accent, Vector3(x, h * 0.5 + 6.0, 0))
		_part(root, _cyl(0.0, 1.6, 3.2, 8), stone, Vector3(x, h + 7.4, 0))
	_part(root, _box(2.6, 4.0, 0.4), glow, Vector3(0, 2.4, w * 0.62))

static func _village(root: Node3D, r: float, stone: Material,
		accent: Material) -> void:
	## 마을 — 오두막 여러 채 + 목책
	var huts := 5
	for i in range(huts):
		var a: float = TAU * float(i) / float(huts) + 0.4
		var d: float = r * 0.5
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		_part(root, _box(2.6, 2.2, 2.6), stone, p + Vector3(0, 1.1, 0))
		_part(root, _cyl(0.0, 2.2, 1.4, 4), accent, p + Vector3(0, 2.9, 0))
	# 목책
	var posts := 16
	for i in range(posts):
		var a2: float = TAU * float(i) / float(posts)
		_part(root, _box(0.22, 1.6, 0.22), accent,
			Vector3(cos(a2) * r * 0.92, 0.8, sin(a2) * r * 0.92))

static func _altar(root: Node3D, r: float, stone: Material,
		glow: Material) -> void:
	## 제단 — 낮은 원단 + 둘러선 선돌
	_part(root, _cyl(r * 0.5, r * 0.58, 0.7, 12), stone, Vector3(0, 0.35, 0))
	_part(root, _box(2.2, 1.0, 1.4), stone, Vector3(0, 1.2, 0))
	_part(root, _box(1.8, 0.18, 1.1), glow, Vector3(0, 1.8, 0))
	var stones := 7
	for i in range(stones):
		var a: float = TAU * float(i) / float(stones)
		var h: float = randf_range(2.6, 4.2)
		_part(root, _box(0.8, h, 0.6), stone,
			Vector3(cos(a) * r * 0.78, h * 0.5, sin(a) * r * 0.78))

static func _tomb(root: Node3D, r: float, stone: Material,
		accent: Material) -> void:
	## 무덤 — 반쯤 묻힌 입구 + 오벨리스크
	_part(root, _box(r * 1.1, 2.2, r * 0.9), stone, Vector3(0, 1.1, 0))
	_part(root, _box(3.0, 3.4, 1.2), accent, Vector3(0, 1.7, -r * 0.45))
	_part(root, _box(2.0, 2.6, 0.5), stone, Vector3(0, 1.3, -r * 0.52))
	for sx in [-1.0, 1.0]:
		_part(root, _box(0.9, 7.0, 0.9), accent,
			Vector3(sx * r * 0.62, 3.5, r * 0.2))
		_part(root, _cyl(0.0, 0.75, 1.3, 4), stone,
			Vector3(sx * r * 0.62, 7.6, r * 0.2))

static func _cave(root: Node3D, r: float, stone: Material) -> void:
	## 동굴 — 바위 아치 입구
	_part(root, _cyl(3.4, 5.4, 5.0, 7), stone, Vector3(0, 2.5, 0))
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.02, 0.02, 0.03)
	dark.roughness = 1.0
	_part(root, _box(2.6, 3.2, 1.0), dark, Vector3(0, 1.6, -3.2))
	for i in range(5):
		var a: float = TAU * float(i) / 5.0 + 0.6
		var s: float = randf_range(1.2, 2.4)
		_part(root, _box(s, s * 0.8, s), stone,
			Vector3(cos(a) * r * 0.7, s * 0.4, sin(a) * r * 0.7))

static func _nest(root: Node3D, r: float, stone: Material,
		glow: Material) -> void:
	## 둥지 — 테두리 둔덕 + 뼈 + 알
	_part(root, _cyl(r * 0.85, r * 0.95, 1.6, 14), stone, Vector3(0, 0.8, 0))
	for i in range(12):
		var a: float = TAU * float(i) / 12.0
		_part(root, _box(0.3, 0.3, randf_range(2.0, 3.6)), stone,
			Vector3(cos(a) * r * 0.6, 1.7, sin(a) * r * 0.6))
	for i in range(3):
		var a2: float = TAU * float(i) / 3.0
		_part(root, _sphere(1.1), glow,
			Vector3(cos(a2) * 1.8, 2.2, sin(a2) * 1.8))

static func _grove(root: Node3D, r: float, stone: Material,
		accent: Material) -> void:
	## 성소 — 거대한 그루터기 + 둘러선 나무
	_part(root, _cyl(2.6, 3.4, 6.0, 9), stone, Vector3(0, 3.0, 0))
	_part(root, _sphere(5.0), accent, Vector3(0, 8.0, 0))
	for i in range(6):
		var a: float = TAU * float(i) / 6.0
		var h: float = randf_range(5.0, 8.0)
		var p := Vector3(cos(a) * r * 0.75, 0, sin(a) * r * 0.75)
		_part(root, _cyl(0.4, 0.7, h, 6), stone, p + Vector3(0, h * 0.5, 0))
		_part(root, _sphere(2.4), accent, p + Vector3(0, h + 1.2, 0))

static func _shrine(root: Node3D, r: float, stone: Material,
		glow: Material) -> void:
	## 작은 사당 — 기단 + 지붕 + 빛나는 심
	_part(root, _cyl(r * 0.42, r * 0.48, 0.6, 10), stone, Vector3(0, 0.3, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_part(root, _cyl(0.22, 0.26, 3.2, 6), stone,
				Vector3(sx * 1.7, 1.9, sz * 1.7))
	_part(root, _cyl(0.0, 3.2, 1.6, 4), stone, Vector3(0, 4.2, 0))
	_part(root, _sphere(0.7), glow, Vector3(0, 1.9, 0))

static func _gate(root: Node3D, r: float, stone: Material,
		glow: Material) -> void:
	## 문 — 거대한 기둥 둘 + 상인방 + 그 사이의 빈 공간
	var h := 16.0
	for sx in [-1.0, 1.0]:
		_part(root, _box(2.4, h, 2.4), stone, Vector3(sx * r * 0.55, h * 0.5, 0))
	_part(root, _box(r * 1.4, 2.4, 2.8), stone, Vector3(0, h + 1.2, 0))
	_part(root, _box(r * 0.95, h * 0.9, 0.3), glow, Vector3(0, h * 0.46, 0))

static func _ruin(root: Node3D, r: float, stone: Material,
		accent: Material) -> void:
	## 폐허 — 부서진 벽과 기둥 (기본형)
	_part(root, _box(r * 1.2, 0.5, r * 1.0), stone, Vector3(0, 0.25, 0))
	var walls := [
		[Vector3(0, 0, -r * 0.5), Vector3(r * 1.1, 4.4, 0.8)],
		[Vector3(-r * 0.55, 0, 0), Vector3(0.8, 3.2, r * 0.8)],
		[Vector3(r * 0.5, 0, r * 0.2), Vector3(0.8, 2.2, r * 0.5)],
	]
	for w in walls:
		var p: Vector3 = w[0]
		var s: Vector3 = w[1]
		_part(root, _box(s.x, s.y, s.z), stone, p + Vector3(0, s.y * 0.5, 0))
	for i in range(3):
		var a: float = TAU * float(i) / 3.0 + 0.9
		var h: float = randf_range(2.0, 4.0)
		_part(root, _cyl(0.3, 0.36, h, 7), accent,
			Vector3(cos(a) * r * 0.62, h * 0.5, sin(a) * r * 0.62))

# ══════════════════════════════════════════════
#  헬퍼
# ══════════════════════════════════════════════
static func _part(root: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	# 구조물은 멀리서 이정표 역할을 하므로 넉넉히 보이게 둔다
	root.add_child(mi)

static func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.05
	return m

static func _emissive(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 3.2
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

static func _cyl(top: float, bottom: float, h: float, seg: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c

static func _sphere(rad: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = rad
	s.height = rad * 1.8
	s.radial_segments = 8
	s.rings = 5
	return s
