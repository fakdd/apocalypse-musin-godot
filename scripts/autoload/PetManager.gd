extends Node
## 펫 관리 — 보유 목록과 현재 동행 펫을 관리한다.

signal pets_changed
signal active_pet_changed(pet_type: String)

const PET_SCRIPT := "res://scripts3d/Pet3D.gd"

## 보유한 펫 종류 (중복 없음)
var owned: Array[String] = []
var active: String = ""
var _instance: Node3D = null

## ── 전투·패시브·뽑기 (data/pets.json) ──
var levels: Dictionary = {}      ## pet_type -> 레벨 (1 부터)
var pity := 0                    ## 연속 미당첨 횟수

const PETS_PATH := "res://data/pets.json"
var _defs: Dictionary = {}

func defs() -> Dictionary:
	if not _defs.is_empty():
		return _defs
	var f := FileAccess.open(PETS_PATH, FileAccess.READ)
	if f == null:
		_defs = {"pets": {}, "grades": {}, "gacha": {}}
		return _defs
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	_defs = j if typeof(j) == TYPE_DICTIONARY else {"pets": {}, "grades": {}, "gacha": {}}
	return _defs

func pet_def(t: String) -> Dictionary:
	return defs().get("pets", {}).get(t, {})

func grade_of(t: String) -> String:
	return String(pet_def(t).get("grade", "D"))

func level_of(t: String) -> int:
	return maxi(1, int(levels.get(t, 1)))

func max_level() -> int:
	return int(defs().get("max_level", 5))

## 레벨 보정 배율 — 등급이 높을수록 한 단계의 값이 크다
func level_mult(t: String) -> float:
	var step := float(defs().get("grades", {}).get(grade_of(t), {}).get("step", 0.08))
	return 1.0 + step * float(level_of(t) - 1)

## 공격 설정 (레벨 반영). Pet3D 가 읽는다.
func attack_of(t: String) -> Dictionary:
	var a: Dictionary = pet_def(t).get("attack", {}).duplicate()
	if a.is_empty():
		return {}
	a["damage"] = float(a.get("damage", 0.4)) * level_mult(t)
	return a

## 장착 중인 펫의 패시브 값 (없으면 0)
func passive(key: String) -> float:
	if active == "":
		return 0.0
	var pv: Dictionary = pet_def(active).get("passive", {})
	return float(pv.get(key, 0.0)) * level_mult(active)

# ══════════════════════════════════════════════
#  뽑기
# ══════════════════════════════════════════════
signal gacha_result(pet_type: String, is_new: bool, leveled: bool, refund: int)

func gacha_cost() -> int:
	return int(defs().get("gacha", {}).get("cost", 150))

func can_gacha() -> bool:
	return CraftManager.essence >= gacha_cost()

## 한 번 뽑는다. 마석이 모자라면 빈 문자열.
func gacha() -> String:
	if not can_gacha():
		SoundManager.play("ui_deny", -8.0)
		return ""
	CraftManager.add_essence(-gacha_cost())

	var g: Dictionary = defs().get("gacha", {})
	var weights: Dictionary = g.get("weights", {})
	var pity_conf: Dictionary = g.get("pity", {})
	var need := int(pity_conf.get("count", 0))
	var good: Array = pity_conf.get("grades", [])

	# 천장 — 오래 안 나오면 확정으로 좋은 것만 후보에 둔다
	var pool := {}
	if need > 0 and pity >= need:
		for t in weights:
			if grade_of(String(t)) in good:
				pool[t] = weights[t]
	if pool.is_empty():
		pool = weights

	var total := 0.0
	for t in pool:
		total += float(pool[t])
	var pick := ""
	var roll := randf() * maxf(total, 0.0001)
	var acc := 0.0
	for t in pool:
		acc += float(pool[t])
		if roll <= acc:
			pick = String(t)
			break
	if pick == "":
		pick = String(pool.keys()[0])

	if grade_of(pick) in good:
		pity = 0
	else:
		pity += 1

	var is_new := not owned.has(pick)
	var leveled := false
	var refund := 0
	if is_new:
		grant(pick)
		levels[pick] = 1
	elif level_of(pick) < max_level():
		levels[pick] = level_of(pick) + 1
		leveled = true
	else:
		# 최대 레벨이면 마석으로 돌려준다 — 뽑기가 완전히 헛되지 않게
		refund = int(defs().get("gacha", {}).get("refund", 60))
		CraftManager.add_essence(refund)

	AchievementManager.bump("pet_gacha")
	SaveGame.save()
	gacha_result.emit(pick, is_new, leveled, refund)
	return pick

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

func to_save() -> Dictionary:
	return {"owned": owned, "active": active, "levels": levels, "pity": pity}

func from_save(d: Dictionary) -> void:
	owned.clear()
	for t in d.get("owned", []):
		owned.append(String(t))
	active = String(d.get("active", ""))
	var lv = d.get("levels", {})
	levels = lv if typeof(lv) == TYPE_DICTIONARY else {}
	pity = int(d.get("pity", 0))

func reset() -> void:
	levels.clear()
	pity = 0
	owned.clear()
	active = ""
	if _instance and is_instance_valid(_instance):
		_instance.queue_free()
	_instance = null
	grant("sprite")
