extends RefCounted
class_name MeshBatcher
## 정적 모델을 MultiMesh 로 묶어 드로우콜을 줄인다.
##
## 왜 필요했나:
##   스카이라인 타워는 층마다 별도 MeshInstance3D 였다. 링 3겹 × 타워 수 × 5~16층 =
##   **수천 개의 노드와 드로우콜**. 도로 타일·보도블록·건물 모듈·소품도 모두 개별 노드였다.
##   측정 결과 드로우콜 23,410 / 렌더 오브젝트 28,722 / 씬 자식 3,993 개였다.
##
## 어떻게 동작하나:
##   1) add() 로 (모델 경로 + 월드 트랜스폼 + 색조)를 모아둔다 — 아직 노드를 만들지 않는다
##   2) commit() 에서 **같은 메시끼리 하나의 MultiMeshInstance3D** 로 합친다
##   색조는 MultiMesh 의 per-instance color 로 넣고, 재질에
##   vertex_color_use_as_albedo 를 켜서 기존 _tint_node 와 같은 결과를 낸다.
##
## 한계 (의도된 것):
##   · 개별 인스턴스를 나중에 지우거나 움직일 수 없다 → **정적 배경 전용**
##   · 충돌은 포함되지 않는다 → 충돌은 기존처럼 별도 StaticBody3D 가 담당한다

## 모델 경로 -> 그 모델을 구성하는 파트 목록 (프로세스 전체에서 공유)
static var _part_cache := {}

## 배치 키 -> {"mesh": Mesh, "mat": Material, "xforms": Array[Transform3D], "colors": Array[Color]}
var _buckets := {}
var _added := 0

## 모델 하나를 배치 대기열에 넣는다.
##   tint: 1.0 이면 원본 색. _tint_node 의 factor 와 같은 의미.
func add(path: String, pos: Vector3, rot_y: float, scale_v: Vector3, tint: float = 1.0) -> void:
	var parts: Array = _parts_for(path)
	if parts.is_empty():
		return
	var basis := Basis(Vector3.UP, rot_y).scaled(scale_v)
	var world_xform := Transform3D(basis, pos)
	var col := Color(tint, tint, tint, 1.0)

	for i in range(parts.size()):
		var part: Dictionary = parts[i]
		var key: String = "%s#%d" % [path, i]
		if not _buckets.has(key):
			_buckets[key] = {
				"mesh": part["mesh"],
				"mat": part["mat"],
				"xforms": [] as Array,
				"colors": [] as Array,
			}
		var b: Dictionary = _buckets[key]
		b["xforms"].append(world_xform * (part["xform"] as Transform3D))
		b["colors"].append(col)
	_added += 1

## 모아둔 것을 MultiMeshInstance3D 로 만들어 parent 에 붙인다.
## 반환: 생성된 노드 수 (원래는 _added 개의 씬 인스턴스였다)
func commit(parent: Node3D, name_prefix: String = "Batch") -> int:
	var made := 0
	for key in _buckets:
		var b: Dictionary = _buckets[key]
		var xforms: Array = b["xforms"]
		if xforms.is_empty():
			continue

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = b["mesh"]
		mm.instance_count = xforms.size()
		var colors: Array = b["colors"]
		for i in range(xforms.size()):
			mm.set_instance_transform(i, xforms[i])
			mm.set_instance_color(i, colors[i])

		var node := MultiMeshInstance3D.new()
		node.name = "%s_%d" % [name_prefix, made]
		node.multimesh = mm
		# 색조를 per-instance color 로 적용하려면 재질이 정점 색을 알베도로 써야 한다
		node.material_override = _batch_material(b["mat"])
		# 배경 대량 오브젝트는 그림자를 굽지 않는다 (그림자 패스가 드로우콜을 2배로 만든다)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
		made += 1
	_buckets.clear()
	return made

func pending_count() -> int:
	return _added

## ── 내부 ──

## 배치용 재질을 만든다. 원본 재질을 복제해 vertex_color_use_as_albedo 만 켠다.
## 같은 원본 재질에 대해서는 하나만 만들어 공유한다.
static var _mat_cache := {}

static func _batch_material(src: Material) -> Material:
	if src == null:
		var fallback := StandardMaterial3D.new()
		fallback.vertex_color_use_as_albedo = true
		return fallback
	var id := src.get_instance_id()
	if _mat_cache.has(id):
		return _mat_cache[id]
	var out: Material = src
	if src is StandardMaterial3D:
		var dup: StandardMaterial3D = src.duplicate()
		dup.vertex_color_use_as_albedo = true
		out = dup
	_mat_cache[id] = out
	return out

## 모델 파일에서 (메시, 로컬 트랜스폼, 재질) 목록을 뽑아낸다.
## .glb 는 루트 밑에 여러 MeshInstance3D 가 있을 수 있으므로 전부 수집한다.
static func _parts_for(path: String) -> Array:
	if _part_cache.has(path):
		return _part_cache[path]

	var parts: Array = []
	var res = load(path)
	if res == null:
		_part_cache[path] = parts
		return parts

	if res is Mesh:
		# .obj 처럼 Mesh 리소스로 바로 임포트되는 경우
		parts.append({"mesh": res, "xform": Transform3D.IDENTITY, "mat": null})
	elif res is PackedScene:
		var inst: Node = res.instantiate()
		_collect(inst, Transform3D.IDENTITY, parts)
		inst.free()          ## 파트만 뽑고 인스턴스는 버린다

	_part_cache[path] = parts
	return parts

static func _collect(node: Node, accum: Transform3D, out: Array) -> void:
	var here := accum
	if node is Node3D:
		here = accum * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			out.append({
				"mesh": mi.mesh,
				"xform": here,
				"mat": mi.get_active_material(0),
			})
	for c in node.get_children():
		_collect(c, here, out)
