extends SceneTree
## 임포트된 모델의 속을 들여다본다.
##   godot --headless --script res://tools/inspect_models.gd
##
## 메시 수 · 삼각형 수 · 스켈레톤/애니메이션 유무 · 원본 크기(AABB) 를 뽑아
## "이걸 플레이어로 쓸 수 있나 / 소품으로 쓸 수 있나 / 너무 무겁나" 를 판단한다.

const DIRS := ["res://assets3d/models/imported"]

func _init() -> void:
	for d in DIRS:
		_scan(d)
	quit()

func _scan(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		print("INS| 폴더 없음: %s" % dir_path)
		return
	print("INS| ══ %s ══" % dir_path)
	d.list_dir_begin()
	var fn := d.get_next()
	var names := []
	while fn != "":
		if not d.current_is_dir():
			var n := fn
			if n.ends_with(".import"):
				n = n.trim_suffix(".import")
			if n.get_extension().to_lower() in ["glb", "gltf", "fbx", "obj"] \
					and not names.has(n):
				names.append(n)
		fn = d.get_next()
	d.list_dir_end()
	names.sort()
	for n in names:
		_report(dir_path.path_join(n))

func _report(path: String) -> void:
	if not ResourceLoader.exists(path):
		print("INS|  ✘ %-24s 임포트 안 됨" % path.get_file())
		return
	var res = ResourceLoader.load(path)
	if res == null:
		print("INS|  ✘ %-24s 로드 실패" % path.get_file())
		return
	if res is Mesh:
		var box: AABB = res.get_aabb()
		print("INS|  · %-24s Mesh   삼각 %-8d 크기 %.1f×%.1f×%.1f m" % [
			path.get_file(), _tris_of(res), box.size.x, box.size.y, box.size.z])
		return
	if not (res is PackedScene):
		print("INS|  ✘ %-24s 알 수 없는 형식" % path.get_file())
		return

	var root = res.instantiate()
	var info := {"mesh": 0, "tris": 0, "skel": 0, "anim": 0, "clips": []}
	var box2 := AABB()
	_walk(root, info, box2)
	# AABB 는 참조로 안 넘어가므로 다시 모은다
	box2 = _bounds(root, 0)
	print("INS|  · %-24s Scene  메시 %-3d 삼각 %-8d 뼈대 %-2d 애니 %-2d 크기 %.1f×%.1f×%.1f m %s" % [
		path.get_file(), info["mesh"], info["tris"], info["skel"], info["anim"],
		box2.size.x, box2.size.y, box2.size.z,
		("  " + str(info["clips"]).substr(0, 60)) if info["anim"] > 0 else ""])
	root.queue_free()

func _tris_of(m: Mesh) -> int:
	var n := 0
	for i in range(m.get_surface_count()):
		var arr := m.surface_get_arrays(i)
		if arr.size() > Mesh.ARRAY_INDEX and arr[Mesh.ARRAY_INDEX] != null:
			n += arr[Mesh.ARRAY_INDEX].size() / 3
		elif arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
			n += arr[Mesh.ARRAY_VERTEX].size() / 3
	return n

func _walk(node: Node, info: Dictionary, _b: AABB) -> void:
	if node is MeshInstance3D and node.mesh != null:
		info["mesh"] += 1
		info["tris"] += _tris_of(node.mesh)
	elif node is Skeleton3D:
		info["skel"] += 1
	elif node is AnimationPlayer:
		info["anim"] += 1
		for c in node.get_animation_list():
			if info["clips"].size() < 6:
				info["clips"].append(String(c))
	for c in node.get_children():
		_walk(c, info, _b)

func _bounds(node: Node, depth: int) -> AABB:
	var out := AABB()
	var first := true
	if depth > 10:
		return out
	if node is MeshInstance3D and node.mesh != null:
		out = node.mesh.get_aabb()
		first = false
	for c in node.get_children():
		var sub := _bounds(c, depth + 1)
		if sub.size == Vector3.ZERO:
			continue
		if first:
			out = sub
			first = false
		else:
			out = out.merge(sub)
	return out
