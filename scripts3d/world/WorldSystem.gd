extends Node
class_name WorldSystem
## 모든 월드 매니저의 공통 베이스.
##
## 매니저들은 World3D 의 자식 노드로 붙으며, 생성한 3D 오브젝트는
## 전부 world(=World3D) 아래에 놓인다. 이렇게 해야 기존 씬 트리 구조와
## 그룹 조회 결과가 리팩토링 전과 동일하게 유지된다.

var world: Node3D = null

## 월드가 공유하는 배치 상태 (World3D 가 소유, 매니저는 참조만)
var occupied_cells: Dictionary:
	get: return world.occupied_cells
var _placed_props: Array:
	get: return world._placed_props

func setup(p_world: Node3D) -> void:
	world = p_world

# ── 상수 프록시 (잘라온 코드가 그대로 동작하도록) ──────────────
const TILE := WorldConfig.TILE
const COLS := WorldConfig.COLS
const ROWS := WorldConfig.ROWS
const ARENA_W := WorldConfig.ARENA_W
const ARENA_H := WorldConfig.ARENA_H
const ZONE_SAFE := WorldConfig.ZONE_SAFE
const ZONE_CITY := WorldConfig.ZONE_CITY
const ZONE_RIFT := WorldConfig.ZONE_RIFT
const SAFE_RADIUS := WorldConfig.SAFE_RADIUS
const RIFT_BAND := WorldConfig.RIFT_BAND
const DAY_SKY_TOP := WorldConfig.DAY_SKY_TOP
const DAY_SKY_HORIZON := WorldConfig.DAY_SKY_HORIZON
const NIGHT_SKY_TOP := WorldConfig.NIGHT_SKY_TOP
const NIGHT_SKY_HORIZON := WorldConfig.NIGHT_SKY_HORIZON
const DAY_FOG := WorldConfig.DAY_FOG
const NIGHT_FOG := WorldConfig.NIGHT_FOG

# ── 격자 판정 프록시 ────────────────────────────────────────
func world_center() -> Vector3: return WorldConfig.world_center()
func zone_of(pos: Vector3) -> int: return WorldConfig.zone_of(pos)
func zone_luck(pos: Vector3) -> float: return WorldConfig.zone_luck(pos)
func _is_horizontal_road(z: int) -> bool: return WorldConfig.is_horizontal_road(z)
func _is_vertical_road(x: int) -> bool: return WorldConfig.is_vertical_road(x)
func _is_road(x: int, z: int) -> bool: return WorldConfig.is_road(x, z)
func _in_base_zone(x: int, z: int) -> bool: return WorldConfig.in_base_zone(x, z)
func _adjacent_to_main_road(x: int, z: int) -> bool: return WorldConfig.adjacent_to_main_road(x, z)
func _is_skyline_cell(x: int, z: int) -> bool: return WorldConfig.is_skyline_cell(x, z)

# ── 오브젝트 생성 헬퍼 (전부 world 아래에 붙는다) ──────────────
func _add_model(path: String, pos: Vector3, rot_y: float = 0.0, scale_f: float = 1.0) -> Node3D:
	return _add_model_v(path, pos, rot_y, Vector3(scale_f, scale_f, scale_f))

func _add_model_v(path: String, pos: Vector3, rot_y: float, scale_v: Vector3) -> Node3D:
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var inst: Node3D = packed.instantiate()
	inst.position = pos
	inst.rotation.y = rot_y
	inst.scale = scale_v
	world.add_child(inst)
	return inst

## ── 정적 배경 배치 (MultiMesh) ──────────────────────────────
## 움직이지 않고 지워지지도 않는 배경 모델은 개별 노드 대신 배치기에 넣는다.
## 매니저는 `bake(...)` 로 모으고, 마지막에 `batch_commit()` 를 부른다.
var batch := MeshBatcher.new()

## 배칭 스위치 — 성능 비교 측정용.
## false 로 두면 최적화 이전과 동일하게 모델마다 개별 노드를 만든다.
## (같은 빌드에서 A/B 를 재실행할 수 있어야 측정이 정직해진다)
static var BATCH_ENABLED := true

## 정적 배경 모델을 배치한다. BATCH_ENABLED 가 false 면 개별 노드로 만든다.
func bake(path: String, pos: Vector3, rot_y: float, scale_v: Vector3, tint: float = 1.0) -> void:
	if BATCH_ENABLED:
		batch.add(path, pos, rot_y, scale_v, tint)
		return
	var n := _add_model_v(path, pos, rot_y, scale_v)
	if not is_equal_approx(tint, 1.0):
		_tint_node(n, tint)

## 배치 대기열을 MultiMeshInstance3D 로 확정한다.
func batch_commit(prefix: String = "Batch") -> int:
	if not BATCH_ENABLED:
		return 0
	return batch.commit(world, prefix)

## 모델의 모든 메시에 밝기 배율을 적용해 같은 모델이 반복되는 느낌을 줄인다.
func _tint_node(node: Node, factor: float) -> void:
	if node == null or is_equal_approx(factor, 1.0):
		return
	var stack: Array = [node]
	var ws_guard := 0
	while stack.size() > 0 and ws_guard < 20000:
		ws_guard += 1
		var cur = stack.pop_back()
		if cur is MeshInstance3D:
			var base_mat: Material = cur.get_active_material(0)
			if base_mat is StandardMaterial3D:
				var dup: StandardMaterial3D = base_mat.duplicate()
				dup.albedo_color = Color(
					clampf(dup.albedo_color.r * factor, 0.0, 1.0),
					clampf(dup.albedo_color.g * factor, 0.0, 1.0),
					clampf(dup.albedo_color.b * factor, 0.0, 1.0),
					dup.albedo_color.a)
				cur.material_override = dup
		for c in cur.get_children():
			stack.append(c)

func _add_static_obstacle(path: String, pos: Vector3, rot_y: float, size: Vector3, scale_f: float = 1.0) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	world.add_child(body)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	body.add_child(shape)

	var packed: PackedScene = load(path)
	if packed:
		var inst: Node3D = packed.instantiate()
		inst.rotation.y = rot_y
		inst.scale = Vector3(scale_f, scale_f, scale_f)
		body.add_child(inst)

## PBR 텍스처 세트로 재질을 만든다 (알베도 + 노멀 + 거칠기 + AO)
func _make_pbr_material(albedo_path: String, normal_path: String, rough_path: String,
		ao_path: String, uv_scale: Vector3, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.uv1_scale = uv_scale

	var alb := load(albedo_path)
	if alb:
		m.albedo_texture = alb
	var nrm := load(normal_path)
	if nrm:
		m.normal_enabled = true
		m.normal_texture = nrm
		m.normal_scale = 1.6
	var rgh := load(rough_path)
	if rgh:
		m.roughness_texture = rgh
	else:
		m.roughness = 0.9
	var ao := load(ao_path)
	if ao:
		m.ao_enabled = true
		m.ao_texture = ao
		m.ao_light_affect = 0.7
	return m

# ── 배치 자리 찾기 (겹침 방지) ────────────────────────────────
## 이미 놓인 소품과 겹치지 않는지 검사하고, 통과하면 등록한다.
func _claim_spot(pos: Vector3, radius: float) -> bool:
	for entry in _placed_props:
		var other_pos: Vector3 = entry[0]
		var other_r: float = entry[1]
		if pos.distance_to(other_pos) < (radius + other_r):
			return false
	_placed_props.append([pos, radius])
	return true

## 겹치지 않는 자리를 찾아준다 (실패하면 Vector3.INF)
func _free_spot(center: Vector3, min_center_dist: float, radius: float, tries: int = 30) -> Vector3:
	for i in range(tries):
		var pos := _open_spot(center, min_center_dist)
		if pos == Vector3.INF:
			continue
		if _claim_spot(pos, radius):
			return pos
	return Vector3.INF

func _open_spot(center: Vector3, min_center_dist: float) -> Vector3:
	for attempt in range(40):
		var gx := 1 + randi() % (COLS - 2)
		var gz := 1 + randi() % (ROWS - 2)
		if _is_road(gx, gz) or occupied_cells.has(Vector2i(gx, gz)):
			continue
		var pos := Vector3(gx * TILE + randf_range(-0.5, 0.5) + TILE * 0.5, 0, gz * TILE + randf_range(-0.5, 0.5) + TILE * 0.5)
		if pos.distance_to(center) < min_center_dist:
			continue
		return pos
	return Vector3.INF

## 도로 위의 겹치지 않는 자리
func _road_free(center: Vector3, min_center_dist: float, radius: float) -> Vector3:
	for i in range(30):
		var pos := _road_spot(center, min_center_dist)
		if pos == Vector3.INF:
			continue
		if _claim_spot(pos, radius):
			return pos
	return Vector3.INF

## 도로 위의 빈 자리
func _road_spot(center: Vector3, min_center_dist: float) -> Vector3:
	for attempt in range(40):
		var gx := 2 + randi() % (COLS - 4)
		var gz := 2 + randi() % (ROWS - 4)
		if not _is_road(gx, gz):
			continue
		var pos := Vector3(gx * TILE + TILE * 0.5 + randf_range(-0.6, 0.6), 0,
			gz * TILE + TILE * 0.5 + randf_range(-0.6, 0.6))
		if pos.distance_to(center) < min_center_dist:
			continue
		return pos
	return Vector3.INF

## 지정한 자리 주변의 소품을 치운다.
##
## 소품은 MultiMesh 로 뿌려지는데, 챕터 포탈은 소품을 다 심은 뒤에 생긴다.
## 그래서 바위·기둥이 포탈을 가려 "포탈이 안 보인다" 는 일이 생겼다.
## 인스턴스 크기를 0 으로 만들어 그 자리만 비운다 (노드를 지우지 않으므로 안전하다).
func clear_props_around(pos: Vector3, radius: float) -> int:
	var removed := 0
	var stack: Array = [world]
	var guard := 0
	while not stack.is_empty() and guard < 4000:
		guard += 1
		var n: Node = stack.pop_back()
		if n == null or not is_instance_valid(n):
			continue
		for c in n.get_children():
			stack.append(c)
		if not (n is MultiMeshInstance3D):
			continue
		var mm: MultiMesh = n.multimesh
		if mm == null:
			continue
		var base: Vector3 = n.global_position
		for i in range(mm.instance_count):
			var t: Transform3D = mm.get_instance_transform(i)
			var wp: Vector3 = base + t.origin
			if Vector2(wp.x - pos.x, wp.z - pos.z).length() > radius:
				continue
			if t.basis.get_scale().length_squared() < 0.0001:
				continue          ## 이미 치운 것
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), t.origin))
			removed += 1
	return removed
