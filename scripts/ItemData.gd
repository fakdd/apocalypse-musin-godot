extends Resource
class_name ItemData
## 아이템 데이터 (Custom Resource)

@export var name: String = "이름 없는 유물"
@export var rarity: int = 0            ## RarityEnums.Rarity
@export var atk_bonus: float = 0.0     ## 공격력 추가값 (합산)
@export var speed_bonus: float = 0.0   ## 이동속도 추가값 (합산)
@export var slot: String = "weapon"    ## weapon / armor / relic
@export var skin: String = "sword"     ## 외형 스킨 키 (SKINS 참조)
@export var enhance_level: int = 0     ## 강화 단계 (+N)

## 슬롯별 스킨 목록 — 등급이 오를수록 뒤쪽(고급) 외형이 선택된다.
const SKINS := {
	"weapon": ["blade_rust", "blade_steel", "blade_fang", "blade_crystal", "blade_dragon", "blade_divine"],
	"armor":  ["armor_rag", "armor_vest", "armor_chitin", "armor_plate", "armor_aegis"],
	"relic":  ["relic_shard", "relic_core", "relic_heart", "relic_key", "relic_seal"],
}

const SLOT_NAMES := {"weapon": "무기", "armor": "방어구", "relic": "장신구"}

func _init(p_name: String = "", p_rarity: int = 0, p_atk: float = 0.0, p_speed: float = 0.0, p_slot: String = "weapon") -> void:
	if p_name != "":
		name = p_name
	rarity = p_rarity
	atk_bonus = p_atk
	speed_bonus = p_speed
	slot = p_slot

func slot_label() -> String:
	return SLOT_NAMES.get(slot, slot)

func get_display_name() -> String:
	var suffix := "" if enhance_level <= 0 else " +%d" % enhance_level
	return "%s %s%s" % [RarityEnums.get_rarity_tag(rarity), name, suffix]

func get_color() -> Color:
	return RarityEnums.get_rarity_color(rarity)

## 강화가 반영된 실제 공격력
func total_atk() -> float:
	return atk_bonus * (1.0 + enhance_level * 0.12)

## 강화가 반영된 실제 이동속도
func total_speed() -> float:
	return speed_bonus * (1.0 + enhance_level * 0.06)

## 종합 점수 — 장비 교체 판단에 사용
func power_score() -> float:
	return total_atk() + total_speed() * 6.0 + rarity * 2.0

func describe() -> String:
	return "%s  (공격 +%.0f · 속도 +%.2f)" % [get_display_name(), total_atk(), total_speed()]

func duplicate_item() -> ItemData:
	var it := ItemData.new()
	it.name = name
	it.rarity = rarity
	it.atk_bonus = atk_bonus
	it.speed_bonus = speed_bonus
	it.slot = slot
	it.skin = skin
	it.enhance_level = enhance_level
	return it
