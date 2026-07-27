extends Node3D

var rescued := false
var prompt: Label3D
var anim: AnimationPlayer

func _ready() -> void:
	add_to_group("survivor_nodes")

	var choices = [
		"res://assets3d/npc/npc_a.gltf",
		"res://assets3d/npc/npc_b.gltf",
		"res://assets3d/npc/npc_c.gltf",
	]
	var packed: PackedScene = load(choices[randi() % choices.size()])
	if packed:
		var model: Node3D = packed.instantiate()
		model.scale = Vector3(0.5, 0.5, 0.5)
		add_child(model)
		anim = _find_anim_player(model)
		if anim:
			for name in ["Idle", "Dance", "Walk"]:
				if anim.has_animation(name):
					anim.play(name)
					break

	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 1.0, 0.6)
	light.light_energy = 1.8
	light.omni_range = 5.0
	light.position.y = 1.5
	add_child(light)

	prompt = Label3D.new()
	prompt.text = "[E] 생존자 구출"
	prompt.font_size = 52
	prompt.pixel_size = 0.006
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.modulate = Color(0.6, 1.0, 0.7)
	prompt.outline_size = 10
	prompt.outline_modulate = Color(0, 0, 0)
	prompt.position.y = 2.2
	prompt.visible = false
	add_child(prompt)

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var found := _find_anim_player(c)
		if found:
			return found
	return null

func _process(_delta: float) -> void:
	if rescued:
		return
	var player := Battlefield.player
	if player and is_instance_valid(player):
		prompt.visible = global_position.distance_to(player.global_position) < 3.0

func rescue() -> void:
	if rescued:
		return
	rescued = true
	GameManager.rescue_survivor()
	SoundManager.play("rescue")
	visible = false
