extends Node
## 플레이어 스탯 통합 계산기 (Autoload 싱글톤)
##
## 최종 공격력   = (기본 공격력   + 장착 아이템 공격력)   * (1.0 + 특성 공격력 증가율)
## 최종 이동속도 = (기본 이동속도 + 장착 아이템 이동속도) * (1.0 + 특성 이동속도 증가율)

signal stats_changed
signal item_equipped(item: ItemData, slot: String)
signal inventory_changed

## ---- 기본 스탯 ----
const BASE_ATK := 10.0
const BASE_SPEED := 7.0
const BASE_HP := 100.0

## 슬롯별 장착 아이템 (slot -> ItemData)
var equipped: Dictionary = {}
## 장착하지 않은 여분 아이템
var inventory: Array[ItemData] = []

func _ready() -> void:
	TraitManager.trait_changed.connect(_on_trait_changed)
	# 맨손으로 시작하지 않게 기본 무기를 지급
	call_deferred("_grant_starter")

func _grant_starter() -> void:
	if equipped.has("weapon"):
		return
	var w: ItemData = LootManager.generate_item(RarityEnums.Rarity.F)
	w.slot = "weapon"
	w.name = "녹슨 진검"
	w.skin = "blade_rust"
	w.atk_bonus = 3.0
	w.speed_bonus = 0.0
	equipped["weapon"] = w
	stats_changed.emit()

func _on_trait_changed(_t: Dictionary) -> void:
	stats_changed.emit()

## ---- 최종 스탯 ----

func get_item_atk() -> float:
	var sum := 0.0
	for slot in equipped.keys():
		var it: ItemData = equipped[slot]
		if it:
			sum += it.total_atk()
	return sum

func get_item_speed() -> float:
	var sum := 0.0
	for slot in equipped.keys():
		var it: ItemData = equipped[slot]
		if it:
			sum += it.total_speed()
	return sum

func get_final_atk() -> float:
	# 영구 강화 배율은 UpgradeManager 만 계산한다 (여기서 직접 곱하지 않는다)
	var base: float = BASE_ATK + get_item_atk() + float(set_bonus().get("atk", 0.0))
	return base * (1.0 + TraitManager.get_atk_pct() / 100.0) \
		* UpgradeManager.mult("attack") * EventManager.buff_mult() \
		* (1.0 + PetManager.passive("atk"))

func get_final_speed() -> float:
	var v: float = (BASE_SPEED + get_item_speed() + float(set_bonus().get("speed", 0.0))) \
		* (1.0 + TraitManager.get_speed_pct() / 100.0) * UpgradeManager.mult("move_speed") \
		* (1.0 + PetManager.passive("speed"))
	return clampf(v, 1.5, 40.0)

func get_final_max_hp() -> float:
	return BASE_HP + GameManager.bonus_max_hp + UpgradeManager.value("hp") \
		+ item_stat("hp_bonus") + float(set_bonus().get("hp", 0.0))

## ── 접사 합산 (data/affixes.json) ──
## 장착 중인 아이템의 새 스탯을 더한다. 옛 아이템은 필드가 0 이라 영향이 없다.
func item_stat(field: String) -> float:
	var sum := 0.0
	for slot in ["weapon", "armor", "relic"]:
		var it: ItemData = equipped.get(slot, null)
		if it and field in it:
			sum += float(it.get(field))
	return sum

func set_bonus() -> Dictionary:
	var eq := []
	for slot in ["weapon", "armor", "relic"]:
		var it: ItemData = equipped.get(slot, null)
		if it:
			eq.append(it)
	return LootManager.set_bonus(eq)

## 아이템·세트에서 오는 추가 치명타 확률
func get_item_crit() -> float:
	return item_stat("crit_bonus") + float(set_bonus().get("crit", 0.0))

## 아이템·세트에서 오는 쿨다운 감소 (0.0~)
func get_item_cdr() -> float:
	return item_stat("cdr_bonus") + float(set_bonus().get("cdr", 0.0))

## 아이템·세트에서 오는 운
## 장착 아이템 중에 이 전설 flag 가 있는가 (affixes.json 의 legendary.flag)
## 장착 무기의 계열 정의. 없으면 default (모든 배율 1.0)
func weapon_family() -> Dictionary:
	var it: ItemData = equipped.get("weapon", null)
	if it == null:
		return ItemData.weapon_data().get("default", {})
	return it.family()

func wf(key: String, fallback: float) -> float:
	return float(weapon_family().get(key, fallback))

func has_legendary(flag: String) -> bool:
	for slot in ["weapon", "armor", "relic"]:
		var it: ItemData = equipped.get(slot, null)
		if it and String(it.legendary) == flag:
			return true
	return false

func get_item_luck() -> float:
	return item_stat("luck_bonus") + float(set_bonus().get("luck", 0.0))

## 검기 1회당 데미지 (기본 공격력을 데미지 단위로 환산)
func get_slash_damage() -> float:
	return maxf(1.0, get_final_atk() / 10.0)

## ---- 아이템 획득/장착 ----

## 주운 아이템을 처리한다. 같은 슬롯의 기존 장비보다 강하면 자동 장착.
func acquire_item(item: ItemData) -> bool:
	if item == null:
		return false
	var slot: String = item.slot
	var current: ItemData = equipped.get(slot, null)
	if current == null or item.power_score() > current.power_score():
		if current != null:
			inventory.append(current)
		equipped[slot] = item
		item_equipped.emit(item, slot)
		stats_changed.emit()
		inventory_changed.emit()
		return true
	inventory.append(item)
	inventory_changed.emit()
	return false

## 인벤토리의 아이템을 수동 장착
func equip_from_inventory(index: int) -> bool:
	if index < 0 or index >= inventory.size():
		return false
	var item: ItemData = inventory[index]
	inventory.remove_at(index)
	var slot: String = item.slot
	var current: ItemData = equipped.get(slot, null)
	if current != null:
		inventory.append(current)
	equipped[slot] = item
	item_equipped.emit(item, slot)
	stats_changed.emit()
	inventory_changed.emit()
	return true

## 슬롯에 직접 장착 (인벤토리 UI 에서 사용). 기존 장비는 보관함으로.
func equip_item(item: ItemData) -> bool:
	if item == null:
		return false
	var idx := inventory.find(item)
	if idx >= 0:
		inventory.remove_at(idx)
	var slot: String = item.slot
	var current: ItemData = equipped.get(slot, null)
	if current != null:
		inventory.append(current)
	equipped[slot] = item
	item_equipped.emit(item, slot)
	stats_changed.emit()
	inventory_changed.emit()
	return true

## 장착 해제 -> 보관함으로
func unequip_slot(slot: String) -> bool:
	var current: ItemData = equipped.get(slot, null)
	if current == null:
		return false
	equipped.erase(slot)
	inventory.append(current)
	stats_changed.emit()
	inventory_changed.emit()
	return true

func get_equipped_summary() -> String:
	if equipped.is_empty():
		return "장비 없음"
	var parts := []
	for slot in ["weapon", "armor", "relic"]:
		var it: ItemData = equipped.get(slot, null)
		if it:
			parts.append(it.get_display_name())
	return " / ".join(parts)

## 최고 등급 장착 아이템의 등급 (UI 강조용)
func get_best_rarity() -> int:
	var best := -1
	for slot in equipped.keys():
		var it: ItemData = equipped[slot]
		if it and it.rarity > best:
			best = it.rarity
	return best

func reset() -> void:
	equipped.clear()
	inventory.clear()
	call_deferred("_grant_starter")
	stats_changed.emit()
	inventory_changed.emit()
