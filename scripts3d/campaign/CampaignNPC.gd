extends Area3D
class_name CampaignNPC
## 캠페인 JSON 이 배치한 NPC.
##
## 랜드마크 주변에 서 있고, 가까이 가면 이름이 뜨고, E 로 상호작용한다.
## 대사와 보상은 **전부 JSON 에서 온다** — 이 스크립트는 표시하고 지급하는 방법만 안다.

const INTERACT_RANGE := 3.2

var npc_id := ""
var display_name := ""
var role := ""
var dialogue := ""
var reward := ""
var landmark_id := ""
## JSON 이 준 상태 (idle / quest / completed) 와 상태별 대사.
## 상태를 게임이 바꾸지는 않는다 — 진행 상황을 보고 **고를 뿐**이다.
var state := "idle"
var dialogue_quest := ""
var dialogue_completed := ""
var quest_id := ""

## 보상은 한 번만. 대화는 몇 번이든 된다 —
## 안 그러면 클리어 후 대사(dialogue_completed)를 볼 방법이 없다.
var _rewarded := false
var _player_near := false
var _label: Label3D
var _prompt: Label3D

func setup(data, p_landmark_id: String, pos: Vector3) -> void:
	## data: CampaignData.NPC
	npc_id = data.id
	display_name = data.display_name
	role = data.role
	dialogue = data.dialogue
	reward = data.reward
	landmark_id = p_landmark_id
	state = data.state
	dialogue_quest = data.dialogue_quest
	dialogue_completed = data.dialogue_completed

	name = "NPC_" + (npc_id if npc_id != "" else display_name)
	add_to_group("campaign_npcs")
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2                      ## 플레이어만 감지
	global_position = pos

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = INTERACT_RANGE
	shape.shape = sphere
	shape.position.y = 1.0
	add_child(shape)

	_build_visual()
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _build_visual() -> void:
	# 역할별 색 — 멀리서도 상인/생존자를 구분할 수 있게
	var col: Color = _role_color()

	# 몸체 (간단한 캡슐) — 전용 모델이 생기면 여기만 바꾸면 된다
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.32
	cap.height = 1.7
	body.mesh = cap
	body.material_override = SharedMaterials.unshaded_fade(
		Color(col.r, col.g, col.b, 0.9), 0.9)
	body.position.y = 0.95
	add_child(body)

	# 발밑 링 — "상호작용 가능한 것"이라는 공통 언어
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.7
	torus.outer_radius = 0.85
	ring.mesh = torus
	ring.material_override = SharedMaterials.unshaded_fade(
		Color(col.r, col.g, col.b, 0.35), 1.4)
	ring.position.y = 0.05
	add_child(ring)

	_label = Label3D.new()
	_label.text = "%s\n[%s]" % [display_name, role]
	_label.font_size = 32
	_label.pixel_size = 0.009
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = col
	_label.outline_size = 8
	_label.outline_modulate = Color(0, 0, 0, 0.85)
	_label.position.y = 2.35
	_label.visibility_range_end = 26.0
	add_child(_label)

	_prompt = Label3D.new()
	_prompt.text = "[E] 대화"
	_prompt.font_size = 28
	_prompt.pixel_size = 0.009
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.modulate = Color(1.0, 0.92, 0.6)
	_prompt.outline_size = 8
	_prompt.outline_modulate = Color(0, 0, 0, 0.85)
	_prompt.position.y = 1.9
	_prompt.visible = false
	add_child(_prompt)

func _role_color() -> Color:
	match role:
		"상인":
			return Color(1.0, 0.82, 0.45)
		"정보원":
			return Color(0.6, 0.85, 1.0)
		"부상자":
			return Color(1.0, 0.6, 0.6)
		"은둔자":
			return Color(0.75, 0.65, 1.0)
		_:
			return Color(0.7, 0.95, 0.8)     ## 생존자

func _on_enter(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = true
	_prompt.visible = true

func _on_exit(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = false
	_prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not _player_near:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_E:
		_interact()
		get_viewport().set_input_as_handled()

func _interact() -> void:
	var world = get_tree().current_scene
	# NPCManager 에 정의가 있으면 대화창을 연다 (선택지·상점·퀘스트)
	# 정의가 없는 NPC 는 기존처럼 한 줄 대사만 띄운다 — 회귀 없음
	if NPCManager.has(npc_id):
		if world and world.hud and world.hud.get("npc_ui") != null:
			world.hud.npc_ui.open(npc_id)
			LandmarkRegistry.notify_npc_talked(landmark_id, npc_id)
			return
	var line := _current_line()
	if world and world.hud:
		if line != "":
			world.hud.show_banner("%s: \"%s\"" % [display_name, line])
		else:
			world.hud.show_toast("%s 와(과) 대화했다" % display_name)
	# 보상은 최초 1회만 (재대화로 파밍할 수 없다)
	if not _rewarded:
		_rewarded = true
		_give_reward()
	LandmarkRegistry.notify_npc_talked(landmark_id, npc_id)

## 지금 진행 상황에 맞는 대사를 고른다.
##
## JSON 의 `state` 는 **기본값**이다. 이 랜드마크의 퀘스트가 이미 끝났으면
## completed 대사를, 아직이면 quest 대사를 우선한다 —
## 그래야 다시 찾아왔을 때 같은 말을 반복하지 않는다.
func _current_line() -> String:
	var effective := state
	var data := LandmarkRegistry.get_data(landmark_id)
	if data != null and data.cleared:
		effective = "completed"
	elif state == "idle" and data != null and data.explored:
		effective = "quest"
	match effective:
		"quest":
			return dialogue_quest if dialogue_quest != "" else dialogue
		"completed":
			return dialogue_completed if dialogue_completed != "" else dialogue
	return dialogue

## 보상 키를 실제 보상으로 바꾼다.
## 새 보상 종류는 여기에 분기를 더한다 (JSON 은 키만 안다).
func _give_reward() -> void:
	var world = get_tree().current_scene
	match reward:
		"heal":
			var player = Battlefield.live_player()
			if player:
				player.hp = minf(player.max_hp, player.hp + player.max_hp * 0.35)
				player.hp_changed.emit()
				if world and world.hud:
					world.hud.show_toast("체력을 회복했다", Color(0.6, 1.0, 0.7))
		"essence":
			CraftManager.add_essence(40)
			if world and world.hud:
				world.hud.show_toast("마석 +40", Color(0.55, 0.85, 1.0))
		"item":
			LootManager.spawn_drop(global_position + Vector3(0, 0, 1.2), 1.0, -1, 60.0)
		"":
			pass
		_:
			push_warning("알 수 없는 NPC 보상 키: %s" % reward)
