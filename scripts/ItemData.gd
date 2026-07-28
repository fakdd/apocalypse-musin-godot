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

## ── 접사/세트/고유 (data/affixes.json) ──
## 기존 세이브에는 없던 필드다. 기본값이 있어 옛 아이템도 그대로 읽힌다.
@export var hp_bonus: float = 0.0
@export var luck_bonus: float = 0.0
@export var crit_bonus: float = 0.0
@export var cdr_bonus: float = 0.0
@export var affixes: Array = []        ## 붙은 접사 id 목록 (표시용)
@export var set_id: String = ""
@export var unique_id: String = ""
@export var legendary: String = ""     ## 전설 옵션 flag

## 슬롯별 스킨 목록 — 등급이 오를수록 뒤쪽(고급) 외형이 선택된다.
const SKINS := {
	"weapon": ["blade_rust", "blade_steel", "blade_fang", "blade_crystal", "blade_dragon", "blade_divine"],
	"armor":  ["armor_rag", "armor_vest", "armor_chitin", "armor_plate", "armor_aegis"],
	"relic":  ["relic_shard", "relic_core", "relic_heart", "relic_key", "relic_seal"],
}

const SLOT_NAMES := {"weapon": "무기", "armor": "방어구", "relic": "장신구"}

# ══════════════════════════════════════════════
#  무기 계열 (data/weapons.json)
# ══════════════════════════════════════════════
const WEAPON_PATH := "res://data/weapons.json"
static var _wpn: Dictionary = {}

static func weapon_data() -> Dictionary:
	if not _wpn.is_empty():
		return _wpn
	var f := FileAccess.open(WEAPON_PATH, FileAccess.READ)
	if f == null:
		_wpn = {"families": {}, "default": {}, "status_effects": {}}
		return _wpn
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	_wpn = j if typeof(j) == TYPE_DICTIONARY else {}
	return _wpn

## skin 접두사로 계열을 찾는다. 못 찾으면 빈 문자열.
static func family_of(skin_key: String) -> String:
	for fid in weapon_data().get("families", {}):
		var pre := String(weapon_data()["families"][fid].get("prefix", ""))
		if pre != "" and skin_key.begins_with(pre):
			return fid
	return ""

## 계열 정의 (없으면 default)
static func family_def(skin_key: String) -> Dictionary:
	var fid := family_of(skin_key)
	if fid == "":
		return weapon_data().get("default", {})
	return weapon_data()["families"][fid]

static func status_def(kind: String) -> Dictionary:
	return weapon_data().get("status_effects", {}).get(kind, {})

func _init(p_name: String = "", p_rarity: int = 0, p_atk: float = 0.0, p_speed: float = 0.0, p_slot: String = "weapon") -> void:
	if p_name != "":
		name = p_name
	rarity = p_rarity
	atk_bonus = p_atk
	speed_bonus = p_speed
	slot = p_slot

## 이 무기의 계열 정의 (무기가 아니면 default)
func family() -> Dictionary:
	if slot != "weapon":
		return weapon_data().get("default", {})
	return family_def(skin)

func family_name() -> String:
	return String(family().get("name", ""))

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
	# 접사가 생긴 뒤로 공격/속도만 보면 체력·치명타 위주 장비를 늘 버리게 된다.
	return total_atk() + total_speed() * 6.0 + rarity * 2.0 \
		+ hp_bonus * 0.15 + crit_bonus * 60.0 + cdr_bonus * 50.0 + luck_bonus * 0.08

func describe() -> String:
	return "%s  (공격 +%.0f · 속도 +%.2f)" % [get_display_name(), total_atk(), total_speed()]

## 툴팁 본문 — 붙은 옵션을 전부 보여준다. 값이 0 인 줄은 넣지 않는다.
func tooltip() -> String:
	var L := []
	L.append("[b][color=#%s]%s[/color][/b]" % [get_color().to_html(false), get_display_name()])
	L.append("[color=#8a8a92]%s[/color]" % slot_label())
	L.append("")
	if total_atk() != 0.0:
		L.append("공격력  [color=#8fd8a0]+%.0f[/color]" % total_atk())
	if total_speed() != 0.0:
		L.append("이동속도  [color=#8fd8a0]+%.2f[/color]" % total_speed())
	if hp_bonus != 0.0:
		L.append("최대 체력  [color=#8fd8a0]+%.0f[/color]" % hp_bonus)
	if crit_bonus != 0.0:
		L.append("치명타 확률  [color=#8fd8a0]+%.0f%%[/color]" % (crit_bonus * 100.0))
	if cdr_bonus != 0.0:
		L.append("쿨다운 감소  [color=#8fd8a0]+%.0f%%[/color]" % (cdr_bonus * 100.0))
	if luck_bonus != 0.0:
		L.append("운  [color=#8fd8a0]+%.0f[/color]" % luck_bonus)
	if slot == "weapon":
		var fm := family()
		if String(fm.get("tagline", "")) != "":
			L.append("\n[color=#c8b070]%s — %s[/color]" % [family_name(), String(fm.get("tagline", ""))])
			L.append("[color=#70707a]%s[/color]" % String(fm.get("desc", "")))
	if legendary != "":
		L.append("\n[color=#e8a04a]◆ 전설 옵션[/color]")
	if unique_id != "":
		L.append("\n[color=#d8763a]★ 고유 유물[/color]")
	if set_id != "":
		L.append("\n[color=#6ad8c8]■ %s 세트[/color]" % LootManager.set_label(set_id))
	return "\n".join(L)

func duplicate_item() -> ItemData:
	var it := ItemData.new()
	it.name = name
	it.rarity = rarity
	it.atk_bonus = atk_bonus
	it.speed_bonus = speed_bonus
	it.slot = slot
	it.skin = skin
	it.enhance_level = enhance_level
	it.hp_bonus = hp_bonus
	it.luck_bonus = luck_bonus
	it.crit_bonus = crit_bonus
	it.cdr_bonus = cdr_bonus
	it.affixes = affixes.duplicate()
	it.set_id = set_id
	it.unique_id = unique_id
	it.legendary = legendary
	return it
