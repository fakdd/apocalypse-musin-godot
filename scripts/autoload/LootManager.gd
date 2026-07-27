extends Node
## 아이템 & 드랍 파밍 시스템 (Autoload 싱글톤)
## 몬스터 처치 시 spawn_drop(global_position) 을 호출한다.

signal item_collected(item: ItemData)

const ITEM_DROP_SCENE_SCRIPT := "res://scripts3d/ItemDrop.gd"

## 등급별 기본 스탯 배수 (등급이 높을수록 급격히 강해짐)
const RARITY_POWER := {
	RarityEnums.Rarity.F:   1.0,
	RarityEnums.Rarity.E:   1.8,
	RarityEnums.Rarity.D:   3.0,
	RarityEnums.Rarity.C:   5.0,
	RarityEnums.Rarity.B:   8.0,
	RarityEnums.Rarity.A:  13.0,
	RarityEnums.Rarity.S:  21.0,
	RarityEnums.Rarity.SS: 34.0,
	RarityEnums.Rarity.SSS: 60.0,
}

## ── 아이템 이름: [수식어] + [종류] ──
## 등급대별로 수식어/종류 풀이 달라진다.
const MODIFIERS := {
	"low": ["녹슨", "낡은", "부러진", "그을린", "금 간", "버려진", "허름한"],
	"mid": ["흑철", "강화된", "변종 괴수", "이계", "합금", "각성한", "정제된"],
	"high": ["차원의", "환수의", "핏빛", "멸망의", "무신(武神)의", "차원 지배자의", "천외천의"],
}
const TYPES := {
	"weapon": {
		"low":  ["단검", "손도끼", "쇠파이프", "식칼"],
		"mid":  ["마도검", "척추도", "참마도", "장검"],
		"high": ["멸망검", "검강", "천마검", "참월도"],
	},
	"armor": {
		"low":  ["가죽 조각", "누더기 갑옷", "철판 조각", "사냥개 가죽"],
		"mid":  ["괴수 갑피", "강화 방탄복", "합금 흉갑", "변종 비늘갑"],
		"high": ["갑주", "방호구", "골갑", "전의"],
	},
	"relic": {
		"low":  ["조각", "부적", "깨진 코어", "이빨 목걸이"],
		"mid":  ["정수 반지", "에너지 코어", "균열 파편", "괴수 심장"],
		"high": ["사술구", "인장", "핵", "봉인구"],
	},
}

## 등급 -> 이름 티어 키
func _tier_key(rarity: int) -> String:
	if rarity <= RarityEnums.Rarity.D:
		return "low"
	if rarity <= RarityEnums.Rarity.A:
		return "mid"
	return "high"

## [수식어] + [종류] 조합으로 이름을 만든다.
func make_item_name(slot: String, rarity: int) -> String:
	var tier := _tier_key(rarity)
	var mods: Array = MODIFIERS[tier]
	var type_pool: Array = TYPES.get(slot, TYPES["weapon"])[tier]
	var m: String = mods[randi() % mods.size()]
	var t: String = type_pool[randi() % type_pool.size()]
	return "%s %s" % [m, t]

## 몬스터가 죽은 위치에 드랍 아이템을 생성한다.
## 플레이어 특성의 '아이템 드랍률 증가율'이 적용되어 고등급 확률이 상승한다.
func spawn_drop(global_pos: Vector3, drop_chance: float = 0.55, forced_rarity: int = -1, luck_override: float = -1.0) -> Node3D:
	# 운(luck): 특성 드랍률 + 구역 보정
	var luck: float = TraitManager.get_drop_pct()
	if luck_override >= 0.0:
		luck += luck_override

	# 드랍 자체가 발생할지 판정 (forced_rarity 를 준 경우는 확정 드랍)
	if forced_rarity < 0:
		var effective_chance: float = clampf(drop_chance * (1.0 + luck / 200.0), 0.0, 0.95)
		if randf() > effective_chance:
			return null

	var rarity: int = forced_rarity if forced_rarity >= 0 else RarityEnums.roll_rarity(luck)
	var item := generate_item(rarity)

	var world := _get_world()
	if world == null:
		return null

	var drop: Node3D = Node3D.new()
	drop.set_script(load(ITEM_DROP_SCENE_SCRIPT))
	world.add_child(drop)
	drop.global_position = global_pos + Vector3(0, 0.4, 0)
	drop.setup(item)
	return drop

## 등급에 맞는 아이템을 절차적으로 생성
func generate_item(rarity: int) -> ItemData:
	var power: float = RARITY_POWER.get(rarity, 1.0)
	var slot_roll := randi() % 3
	var item := ItemData.new()
	item.rarity = rarity

	match slot_roll:
		0:
			item.slot = "weapon"
			item.name = make_item_name("weapon", rarity)
			item.atk_bonus = snappedf(power * randf_range(1.6, 2.4), 1.0)
			item.speed_bonus = 0.0
		1:
			item.slot = "armor"
			item.name = make_item_name("armor", rarity)
			item.atk_bonus = snappedf(power * randf_range(0.3, 0.7), 1.0)
			item.speed_bonus = snappedf(power * randf_range(0.02, 0.06), 0.01)
		_:
			item.slot = "relic"
			item.name = make_item_name("relic", rarity)
			item.atk_bonus = snappedf(power * randf_range(0.6, 1.2), 1.0)
			item.speed_bonus = snappedf(power * randf_range(0.05, 0.12), 0.01)

	item.skin = _pick_skin(item.slot, rarity)
	return item

## 등급이 높을수록 고급 스킨이 배정된다.
func _pick_skin(slot: String, rarity: int) -> String:
	var pool: Array = ItemData.SKINS.get(slot, ["sword"])
	var t: float = float(rarity) / float(RarityEnums.Rarity.SSS)
	var idx: int = int(round(t * (pool.size() - 1)))
	return pool[clampi(idx, 0, pool.size() - 1)]

## 플레이어가 아이템을 획득했을 때 호출된다 (ItemDrop 에서 호출)
func collect(item: ItemData) -> void:
	PlayerStats.acquire_item(item)
	item_collected.emit(item)

func _get_world() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.current_scene
