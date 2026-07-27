extends SceneTree

const TARGET_HEIGHT := 1.85

const SOURCES := {
	"idle": "res://assets3d/chars/Idle.fbx",
	"walk": "res://assets3d/chars/Walking.fbx",
	"sprint": "res://assets3d/chars/Running.fbx",
	"die": "res://assets3d/chars/Dying.fbx",
	"attack-melee-right": "res://assets3d/chars/Sword And Shield Slash.fbx",
	"attack-melee-left": "res://assets3d/chars/Sword And Shield Attack.fbx",
}

const LOOPING := ["idle", "walk", "sprint"]
const IN_PLACE := ["walk", "sprint", "attack-melee-right", "attack-melee-left"]

func _init() -> void:
	var base_scene: PackedScene = load(SOURCES["idle"])
	var root: Node3D = base_scene.instantiate()
	root.name = "Hero"
	get_root().add_child(root)
	await process_frame

	var ap: AnimationPlayer = root.find_child("AnimationPlayer", true, false)
	if ap == null:
		push_error("no AnimationPlayer")
		quit(1)
		return

	var lib := AnimationLibrary.new()

	for key in SOURCES.keys():
		var anim: Animation = _grab_anim(key)
		if anim == null:
			print("SKIP (no anim): ", key)
			continue
		anim = anim.duplicate(true)
		if key in LOOPING:
			anim.loop_mode = Animation.LOOP_LINEAR
		else:
			anim.loop_mode = Animation.LOOP_NONE
		if key in IN_PLACE:
			var removed := _strip_horizontal_root_motion(anim)
			print("  in-place applied to %s (track %d)" % [key, removed])
		lib.add_animation(key, anim)
		print("baked: %s  len=%.2fs loop=%d" % [key, anim.length, anim.loop_mode])

	# replace all libraries with our single one
	for l in ap.get_animation_library_list():
		ap.remove_animation_library(l)
	ap.add_animation_library("", lib)

	# normalize scale so the character is TARGET_HEIGHT tall
	var mi := _find_mesh(root)
	if mi:
		var h: float = mi.get_aabb().size.y * root.scale.y
		if h > 0.0001:
			var factor: float = TARGET_HEIGHT / h
			root.scale = root.scale * factor
			print("scale normalized: mesh_h=%.4f factor=%.2f final_scale=%s" % [h, factor, str(root.scale)])

	# make every node owned by root so PackedScene.pack keeps them
	_set_owner_recursive(root, root)

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack failed %d" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, "res://assets3d/chars/hero.tscn")
	print("saved hero.tscn err=", err)
	print("final anims: ", ap.get_animation_list())
	quit(0)

func _grab_anim(key: String) -> Animation:
	var scn: PackedScene = load(SOURCES[key])
	if scn == null:
		return null
	var inst: Node = scn.instantiate()
	get_root().add_child(inst)
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	var result: Animation = null
	if ap:
		var names := ap.get_animation_list()
		if names.size() > 0:
			result = ap.get_animation(names[0])
	if result:
		result = result.duplicate(true)
	inst.free()
	return result

func _strip_horizontal_root_motion(anim: Animation) -> int:
	for i in range(anim.get_track_count()):
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var path := str(anim.track_get_path(i))
		if not ("Hips" in path or "hips" in path):
			continue
		var n := anim.track_get_key_count(i)
		if n == 0:
			continue
		var first: Vector3 = anim.track_get_key_value(i, 0)
		for k in range(n):
			var v: Vector3 = anim.track_get_key_value(i, k)
			anim.track_set_key_value(i, k, Vector3(first.x, v.y, first.z))
		return i
	return -1

func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var f := _find_mesh(c)
		if f:
			return f
	return null

func _set_owner_recursive(n: Node, owner_node: Node) -> void:
	for c in n.get_children():
		c.owner = owner_node
		_set_owner_recursive(c, owner_node)
