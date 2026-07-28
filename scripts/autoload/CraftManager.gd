extends Node
## 아이템 합성 & 강화 시스템 (Autoload 싱글톤)
##
## 합성(Combine): 같은 등급 3개 -> 확률적으로 한 단계 위 등급 1개
## 강화(Enhance) : '마석(정수)'을 소비해 장비를 +1, +2 ... 로 강화

signal essence_changed(amount: int)
signal craft_result(success: bool, message: String, item: ItemData)

## 보유 마석
var essence: int = 0

## 합성 성공률 (등급이 높을수록 낮다). 실패 시 재료는 소모되고 같은 등급 1개를 돌려받는다.
const MERGE_CHANCE := {
	RarityEnums.Rarity.F:   0.80,
	RarityEnums.Rarity.E:   0.70,
	RarityEnums.Rarity.D:   0.60,
	RarityEnums.Rarity.C:   0.50,
	RarityEnums.Rarity.B:   0.40,
	RarityEnums.Rarity.A:   0.30,
	RarityEnums.Rarity.S:   0.20,
	RarityEnums.Rarity.SS:  0.10,
}

const MERGE_COST := 3          ## 필요한 동일 등급 아이템 수
const MAX_ENHANCE := 10

func add_essence(n: int) -> void:
	# 획득에만 배율을 건다 (소모는 그대로여야 가격이 흔들리지 않는다)
	if n > 0:
		n = int(round(float(n) * UpgradeManager.mult("resource_gain")))
	essence = maxi(0, essence + n)
	essence_changed.emit(essence)

## 몬스터가 떨어뜨리는 마석 (등급이 높은 몹일수록 많이)
func roll_essence_drop(tier_bonus: int = 0) -> int:
	var n := 1 + randi() % 2 + tier_bonus
	# 월드 티어 · 자원 획득 강화 — 후반 챕터에서 수입이 늘지 않던 문제
	# 후반 챕터는 몹이 두꺼워지므로 보상도 같이 커진다 (pacing.json tempo.reward)
	return maxi(1, int(round(float(n) * SaveGame.tier_mult("essence")
		* UpgradeManager.mult("resource_gain") * CombatFeel.tempo("reward", 1.0))))

## ── 합성 ──
## 인벤토리에서 지정 등급의 아이템 3개를 소모해 상위 등급 1개를 시도한다.
## 주운 직후 자동 합성.
## 인벤토리가 같은 등급으로 꽉 차는 것을 막는다 — 조건이 되는 동안 계속 위로 올린다.
## data/pacing.json 의 auto_merge 로 켜고 끈다 (기본 켜짐).
func auto_merge_from(rarity: int) -> int:
	if not auto_merge_enabled():
		return 0
	var made := 0
	var r := rarity
	while r < RarityEnums.Rarity.SSS and can_merge(r):
		if not merge(r):
			break
		made += 1
		r += 1          ## 올라간 등급이 또 3개가 되면 한 번 더
	return made

func auto_merge_enabled() -> bool:
	return bool(CombatFeel.pacing().get("auto_merge", {}).get("enabled", true))

func can_merge(rarity: int) -> bool:
	if rarity >= RarityEnums.Rarity.SSS:
		return false
	return _count_in_inventory(rarity) >= MERGE_COST

func merge(rarity: int) -> bool:
	if not can_merge(rarity):
		craft_result.emit(false, "%s급 아이템이 %d개 필요합니다" % [
			RarityEnums.get_rarity_name(rarity), MERGE_COST], null)
		return false

	# 재료 소모 (강화 수치가 낮은 것부터)
	var idxs := _find_in_inventory(rarity, MERGE_COST)
	idxs.sort()
	idxs.reverse()
	for i in idxs:
		PlayerStats.inventory.remove_at(i)

	var chance: float = MERGE_CHANCE.get(rarity, 0.1)
	var success := randf() < chance
	var out_rarity: int = (rarity + 1) if success else rarity
	var item := LootManager.generate_item(out_rarity)
	PlayerStats.inventory.append(item)
	PlayerStats.inventory_changed.emit()

	var msg := ""
	if success:
		msg = "합성 성공! %s 획득" % item.get_display_name()
		SoundManager.play("ultimate", -14.0)
	else:
		msg = "합성 실패… %s 로 되돌아왔다" % item.get_display_name()
		SoundManager.play("error", -10.0)
	craft_result.emit(success, msg, item)
	return success

func _count_in_inventory(rarity: int) -> int:
	var n := 0
	for it in PlayerStats.inventory:
		if it.rarity == rarity:
			n += 1
	return n

func _find_in_inventory(rarity: int, need: int) -> Array:
	var out := []
	for i in range(PlayerStats.inventory.size()):
		if PlayerStats.inventory[i].rarity == rarity:
			out.append(i)
			if out.size() >= need:
				break
	return out

## 등급별 보유 수량 (UI 표기용)
func inventory_counts() -> Dictionary:
	var out := {}
	for it in PlayerStats.inventory:
		out[it.rarity] = out.get(it.rarity, 0) + 1
	return out

## ── 강화 ──
## 다음 강화에 필요한 마석 수
func enhance_cost(item: ItemData) -> int:
	if item == null:
		return 0
	var base := 3 + item.rarity * 2
	return base + item.enhance_level * (2 + item.rarity)

## 강화 성공률 (단계가 오를수록 하락)
func enhance_chance(item: ItemData) -> float:
	if item == null:
		return 0.0
	return clampf(0.95 - item.enhance_level * 0.08, 0.25, 0.95)

func can_enhance(item: ItemData) -> bool:
	if item == null or item.enhance_level >= MAX_ENHANCE:
		return false
	return essence >= enhance_cost(item)

## 실패해도 강화 단계는 내려가지 않는다 (마석만 소모).
func enhance(item: ItemData) -> bool:
	if item == null:
		return false
	if item.enhance_level >= MAX_ENHANCE:
		craft_result.emit(false, "이미 최대 강화입니다 (+%d)" % MAX_ENHANCE, item)
		return false
	var cost := enhance_cost(item)
	if essence < cost:
		craft_result.emit(false, "마석이 부족합니다 (%d/%d)" % [essence, cost], item)
		SoundManager.play("error", -10.0)
		return false

	add_essence(-cost)
	var success := randf() < enhance_chance(item)
	if success:
		item.enhance_level += 1
		PlayerStats.stats_changed.emit()
		PlayerStats.inventory_changed.emit()
		craft_result.emit(true, "강화 성공! %s" % item.get_display_name(), item)
		SoundManager.play("build", -12.0)
	else:
		craft_result.emit(false, "강화 실패… 마석 %d 소모" % cost, item)
		SoundManager.play("error", -12.0)
	return success

func reset() -> void:
	essence = 0
	essence_changed.emit(essence)
