extends Node
class_name ItemSkins
## 아이템 스킨 — 3D 드랍 메시와 인벤토리 아이콘 모양을 한곳에서 정의한다.

## 스킨별 3D 메시를 생성한다.
static func build_mesh(skin: String) -> Mesh:
	match skin:
		# ── 무기 (6종, 형태가 모두 다르다) ──
		"blade_rust":
			return _blade(0.09, 0.85, 0.03)          # 짧고 얇은 단검
		"blade_steel":
			return _blade(0.14, 1.25, 0.05)          # 곧은 장검
		"blade_fang":
			return _cone(0.17, 1.15)                 # 송곳니형 (원뿔)
		"blade_crystal":
			return _prism(0.26, 1.35)                # 결정형 (각뿔)
		"blade_dragon":
			return _cylinder(0.05, 0.20, 1.55, 6)    # 굵은 참마도 (테이퍼)
		"blade_divine":
			return _torus(0.10, 0.42)                # 검강 고리 (신검)
		# ── 방어구 ──
		"armor_rag":
			return _box(0.5, 0.55, 0.18)
		"armor_vest":
			return _box(0.6, 0.65, 0.22)
		"armor_chitin":
			return _sphere(0.36, 6, 3)
		"armor_plate":
			return _box(0.7, 0.75, 0.3)
		"armor_aegis":
			return _cylinder(0.42, 0.42, 0.16, 8)
		# ── 장신구 ──
		"relic_shard":
			return _prism(0.18, 0.5)
		"relic_core":
			return _sphere(0.3, 8, 4)
		"relic_heart":
			return _sphere(0.34, 6, 3)
		"relic_key":
			return _cylinder(0.1, 0.1, 0.7, 6)
		"relic_seal":
			return _torus(0.18, 0.34)
	return _box(0.4, 0.4, 0.4)

## 스킨에 대응하는 아이콘 이미지 경로 (없으면 빈 문자열)
static func icon_path(skin: String) -> String:
	var p := "res://assets3d/icons/%s.svg" % skin
	if ResourceLoader.exists(p):
		return p
	return ""

## 인벤토리 아이콘용 — 스킨을 대표하는 단순 도형 이름
static func icon_shape(skin: String) -> String:
	if skin.begins_with("blade"):
		return "blade"
	if skin.begins_with("armor"):
		return "shield"
	return "gem"

static func _blade(w: float, h: float, d: float) -> Mesh:
	var m := BoxMesh.new()
	m.size = Vector3(w, h, d)
	return m

static func _box(x: float, y: float, z: float) -> Mesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m

static func _cone(r: float, h: float) -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 6
	return m

static func _prism(size: float, h: float) -> Mesh:
	var m := PrismMesh.new()
	m.size = Vector3(size, h, size)
	return m

static func _sphere(r: float, radial: int, rings: int) -> Mesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = radial
	m.rings = rings
	return m

static func _cylinder(top: float, bottom: float, h: float, seg: int) -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	return m

static func _torus(inner: float, outer: float) -> Mesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	return m

## 등급에 맞는 재질 (발광 강도가 등급에 비례)
static func build_material(rarity: int) -> StandardMaterial3D:
	var col: Color = RarityEnums.get_rarity_color(rarity)
	var glow: float = RarityEnums.get_rarity_glow(rarity)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = glow
	m.metallic = 0.6
	m.roughness = 0.25
	return m
