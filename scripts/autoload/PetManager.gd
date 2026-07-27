extends Node
## 펫 관리 — 보유 목록과 현재 동행 펫을 관리한다.

signal pets_changed
signal active_pet_changed(pet_type: String)

const PET_SCRIPT := "res://scripts3d/Pet3D.gd"

## 보유한 펫 종류 (중복 없음)
var owned: Array[String] = []
var active: String = ""
var _instance: Node3D = null

func _ready() -> void:
	# 시작 시 기본 펫 1마리를 준다
	if owned.is_empty():
		grant("sprite")

func grant(pet_type: String) -> bool:
	var script_ref = load(PET_SCRIPT)
	if not script_ref.TYPES.has(pet_type):
		return false
	if pet_type in owned:
		return false
	owned.append(pet_type)
	pets_changed.emit()
	if active == "":
		set_active(pet_type)
	return true

## 아직 없는 펫 중 하나를 무작위로 준다 (보스 보상 등)
func grant_random_new() -> String:
	var script_ref = load(PET_SCRIPT)
	var pool: Array = []
	for k in script_ref.TYPES.keys():
		if not (k in owned):
			pool.append(k)
	if pool.is_empty():
		return ""
	var picked: String = pool[randi() % pool.size()]
	grant(picked)
	return picked

func set_active(pet_type: String) -> void:
	if not (pet_type in owned):
		return
	active = pet_type
	active_pet_changed.emit(pet_type)
	_respawn()

## 다음 보유 펫으로 순환 (P 키)
func cycle() -> String:
	if owned.size() <= 1:
		return active
	var idx := owned.find(active)
	idx = (idx + 1) % owned.size()
	set_active(owned[idx])
	return active

## 월드에 실제 펫 노드를 생성한다. 월드가 새로 로드될 때도 호출된다.
func spawn_into_world() -> void:
	_respawn()

func _respawn() -> void:
	if _instance and is_instance_valid(_instance):
		_instance.queue_free()
	_instance = null
	if active == "":
		return
	var world := get_tree().current_scene
	if world == null:
		return
	var player := Battlefield.player
	var pet: Node3D = Node3D.new()
	pet.set_script(load(PET_SCRIPT))
	world.add_child(pet)
	pet.setup(active)
	if player and is_instance_valid(player):
		pet.global_position = player.global_position + Vector3(1.5, 1.5, 0)
	_instance = pet

func get_info(pet_type: String) -> Dictionary:
	var script_ref = load(PET_SCRIPT)
	return script_ref.TYPES.get(pet_type, {})

func reset() -> void:
	owned.clear()
	active = ""
	if _instance and is_instance_valid(_instance):
		_instance.queue_free()
	_instance = null
	grant("sprite")
