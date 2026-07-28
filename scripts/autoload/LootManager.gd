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
## 운의 상한. 이 위로는 등급 분포가 사실상 포화라 더 올려도 의미가 없다.
const LUCK_CAP := 420.0

func spawn_drop(global_pos: Vector3, drop_chance: float = 0.55, forced_rarity: int = -1, luck_override: float = -1.0) -> Node3D:
	# 운(luck): 특성 드랍률 + 구역 보정
	var luck: float = TraitManager.get_drop_pct() + UpgradeManager.value("drop_rate") \
		+ PlayerStats.get_item_luck()
	if luck_override >= 0.0:
		luck += luck_override

	# 드랍 자체가 발생할지 판정 (forced_rarity 를 준 경우는 확정 드랍)
	if forced_rarity < 0:
		var effective_chance: float = clampf(
			drop_chance * (1.0 + luck / 200.0) * SaveGame.tier_mult("drop"), 0.0, 0.95)
		if randf() > effective_chance:
			return null

	# 고등급 스케일링 보완 —
	#   기존: roll_rarity 가 luck 을 그대로 받아 S~SSS 확률이 완만하게만 올랐다.
	#   보완: 챕터·월드티어 보상 배율을 운에 함께 태우고, 상한을 둬 폭주를 막는다.
	var eff_luck: float = minf(
		luck * CombatFeel.tempo("reward", 1.0) * SaveGame.tier_mult("drop"),
		LUCK_CAP)
	var rarity: int = forced_rarity if forced_rarity >= 0 else RarityEnums.roll_rarity(eff_luck)
	var item := generate_item(rarity)
	_drop_tease(item.rarity)

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
	var uq := _roll_unique(rarity)
	if uq != null:
		return uq
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
	_roll_affixes(item, power)
	return item

# ══════════════════════════════════════════════
#  접사 · 세트 · 고유 (data/affixes.json)
# ══════════════════════════════════════════════
const AFFIX_PATH := "res://data/affixes.json"
var _affix: Dictionary = {}

func affix_data() -> Dictionary:
	if not _affix.is_empty():
		return _affix
	var f := FileAccess.open(AFFIX_PATH, FileAccess.READ)
	if f == null:
		_affix = {"prefixes": [], "suffixes": [], "uniques": [], "sets": []}
		return _affix
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	_affix = j if typeof(j) == TYPE_DICTIONARY else {}
	return _affix

## 고유 아이템 판정 — 일반 생성보다 먼저 굴린다.
func _roll_unique(rarity: int) -> ItemData:
	for u in affix_data().get("uniques", []):
		if int(u.get("rarity", 9)) > rarity:
			continue
		if randf() > float(u.get("chance", 0.0)):
			continue
		var it := ItemData.new()
		it.unique_id = String(u.get("id", ""))
		it.name = String(u.get("name", "고유 유물"))
		it.rarity = int(u.get("rarity", rarity))
		it.slot = String(u.get("slot", "weapon"))
		it.skin = String(u.get("skin", _pick_skin(it.slot, it.rarity)))
		it.set_id = String(u.get("set", ""))
		_apply_stats(it, u.get("stats", {}), 1.0)
		return it
	return null

func _apply_stats(item: ItemData, st: Dictionary, power: float) -> void:
	item.atk_bonus += float(st.get("atk", 0.0)) * power
	item.speed_bonus += float(st.get("speed", 0.0)) * power
	item.hp_bonus += float(st.get("hp", 0.0)) * power
	item.luck_bonus += float(st.get("luck", 0.0)) * power
	item.crit_bonus += float(st.get("crit", 0.0)) * power
	item.cdr_bonus += float(st.get("cdr", 0.0)) * power

func _pool_for(key: String, rarity: int) -> Array:
	var out := []
	for a in affix_data().get(key, []):
		if int(a.get("min_rarity", 0)) <= rarity:
			out.append(a)
	return out

## 등급에 따라 접두사/접미사를 붙이고 이름을 다시 만든다.
func _roll_affixes(item: ItemData, power: float) -> void:
	var d := affix_data()
	var counts: Array = d.get("affix_count", [])
	var n: int = int(counts[clampi(item.rarity, 0, counts.size() - 1)]) if counts.size() > 0 else 0
	if n <= 0:
		return

	var pre = null
	var suf = null
	var pp := _pool_for("prefixes", item.rarity)
	var sp := _pool_for("suffixes", item.rarity)
	if n >= 1 and not pp.is_empty():
		pre = pp[randi() % pp.size()]
	if n >= 2 and not sp.is_empty():
		suf = sp[randi() % sp.size()]

	if pre != null:
		_apply_stats(item, pre.get("stats", {}), power)
		item.affixes.append(String(pre.get("id", "")))
	if suf != null:
		_apply_stats(item, suf.get("stats", {}), power)
		item.affixes.append(String(suf.get("id", "")))

	# 전설 옵션 — 높은 등급에만
	var leg: Dictionary = d.get("legendary", {})
	if item.rarity >= int(leg.get("min_rarity", 99)):
		var opts: Array = leg.get("options", [])
		if not opts.is_empty():
			var o: Dictionary = opts[randi() % opts.size()]
			_apply_stats(item, o.get("stats", {}), power)
			item.legendary = String(o.get("flag", ""))
			item.affixes.append(String(o.get("id", "")))

	# 세트 소속
	if randf() < float(d.get("set_chance", 0.0)):
		for st in d.get("sets", []):
			if int(st.get("min_rarity", 9)) > item.rarity:
				continue
			if item.slot in st.get("pieces", []):
				item.set_id = String(st.get("id", ""))
				break

	var names := []

	if pre != null:
		names.append(String(pre.get("name", "")))
	names.append(item.name)
	if suf != null:
		names.append(String(suf.get("name", "")))
	item.name = " ".join(names)

## 장착 중인 아이템들의 세트 보너스를 합산한다. PlayerStats 가 부른다.
func set_bonus(equipped: Array) -> Dictionary:
	var counts := {}
	for it in equipped:
		if it == null or String(it.set_id) == "":
			continue
		counts[it.set_id] = int(counts.get(it.set_id, 0)) + 1
	var out := {"atk": 0.0, "speed": 0.0, "hp": 0.0, "luck": 0.0, "crit": 0.0, "cdr": 0.0}
	for sid in counts:
		for st in affix_data().get("sets", []):
			if String(st.get("id", "")) != sid:
				continue
			var b: Dictionary = st.get("bonus", {})
			for k in b:
				if int(counts[sid]) >= int(k):
					for stat in b[k]:
						out[stat] = float(out.get(stat, 0.0)) + float(b[k][stat])
	return out

## 세트 이름 (UI 표시용)
func set_label(sid: String) -> String:
	for st in affix_data().get("sets", []):
		if String(st.get("id", "")) == sid:
			return String(st.get("name", sid))
	return sid

## 등급이 높을수록 고급 스킨이 배정된다.
func _pick_skin(slot: String, rarity: int) -> String:
	# 무기는 5계열 중 하나를 고른다 — 계열마다 플레이 스타일이 다르다
	if slot == "weapon":
		var fams: Array = ItemData.weapon_data().get("families", {}).keys()
		if not fams.is_empty():
			var fid := String(fams[randi() % fams.size()])
			var fp: Array = ItemData.weapon_data().get("skins", {}).get(fid, [])
			if not fp.is_empty():
				var t2: float = float(rarity) / float(RarityEnums.Rarity.SSS)
				var i2: int = int(round(t2 * (fp.size() - 1)))
				return String(fp[clampi(i2, 0, fp.size() - 1)])
	var pool: Array = ItemData.SKINS.get(slot, ["sword"])
	var t: float = float(rarity) / float(RarityEnums.Rarity.SSS)
	var idx: int = int(round(t * (pool.size() - 1)))
	return pool[clampi(idx, 0, pool.size() - 1)]

## 플레이어가 아이템을 획득했을 때 호출된다 (ItemDrop 에서 호출)
func collect(item: ItemData) -> void:
	# 줍는 순간에도 등급이 손에 잡히게 — 연출 강도를 등급에 비례시킨다
	var pop := float(CombatFeel.pacing().get("drop_tease", {})
		.get("pickup_pop", {}).get(str(item.rarity), 0.0))
	if pop > 0.0:
		CombatFeel.hit_stop(0.04 * pop)
		SoundManager.play_pitched("pickup", -4.0, 0.9 + 0.12 * pop)
	# 업적 — 주운 유물 수 (판정은 AchievementManager 가 한다)
	AchievementManager.bump("chest")
	PlayerStats.acquire_item(item)
	# 같은 등급 3개가 모이면 그 자리에서 상위 등급으로 합친다 (인벤토리 포화 방지)
	var made := CraftManager.auto_merge_from(item.rarity)
	if made > 0:
		CombatFeel.impact("crit")
	item_collected.emit(item)

func _get_world() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.current_scene

## 등급이 높을수록 떨어지는 순간이 요란해진다.
## "뭔가 좋은 게 떨어졌다"는 신호를 줍기 전에 준다.
func _drop_tease(rarity: int) -> void:
	var d: Dictionary = CombatFeel.pacing().get("drop_tease", {})
	if d.is_empty():
		return
	if rarity >= int(d.get("legend_from", 99)):
		CombatFeel.flash_array("drop_tease", "legend_flash")
		var sm = d.get("legend_slowmo", null)
		if typeof(sm) == TYPE_ARRAY and sm.size() >= 2:
			CombatFeel.slow_motion(float(sm[0]), float(sm[1]))
		SoundManager.play("loot_legend", -3.0)
	elif rarity >= int(d.get("epic_from", 99)):
		CombatFeel.flash_array("drop_tease", "epic_flash")
		SoundManager.play("loot_epic", -5.0)
	elif rarity >= int(d.get("rare_from", 99)):
		CombatFeel.flash_array("drop_tease", "rare_flash")
		SoundManager.play("loot_rare", -7.0)
