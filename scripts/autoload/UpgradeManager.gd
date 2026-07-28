extends Node
## 영구 강화 — 정의는 data/upgrades.json, 저장은 SaveGame.upgrades.
##
## 이 파일이 **강화의 유일한 창구**다.
##   구매      UpgradeManager.purchase(id)
##   효과 조회 UpgradeManager.value(id)   ← 다른 코드는 배율을 직접 계산하지 않는다
##
## 비용·효과는 JSON 의 수식 문자열이다 (Godot Expression 으로 평가).
## 그래서 새 강화를 넣거나 곡선을 바꿀 때 코드를 고치지 않는다.
##
##   "cost_formula":  "round(60 * pow(1.45, level))"   ← level = 현재 단계
##   "value_formula": "level * 0.08"                    ← level = 현재 단계
##
## 챕터를 넘어도 유지된다 — SaveGame 에 들어 있고, 챕터 이동은 세이브를 지우지 않는다.

const PATH := "res://data/upgrades.json"

signal purchased(id: String, level: int)
signal changed()

## id → 정의
var defs := {}
## 카테고리 [{id, name}]
var categories: Array = []
var _order: Array[String] = []
## id → 컴파일된 Expression (매번 파싱하지 않는다)
var _cost_exp := {}
var _value_exp := {}
## id → level → 값 (수식 평가 결과 캐시. 전투 루프에서 매 프레임 불린다)
var _cache := {}

func _ready() -> void:
	_load_defs()
	SaveGame.loaded.connect(func(): _cache.clear())

func _load_defs() -> void:
	if not FileAccess.file_exists(PATH):
		push_warning("[Upg] 강화 정의가 없습니다: %s" % PATH)
		return
	var raw = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(raw) != TYPE_DICTIONARY:
		push_error("[Upg] 강화 정의를 읽지 못했습니다 (형식 오류)")
		return
	categories = raw.get("categories", [])
	for u in raw.get("upgrades", []):
		if typeof(u) != TYPE_DICTIONARY:
			continue
		var id := String(u.get("id", ""))
		if id == "":
			continue
		defs[id] = u
		_order.append(id)
		_cost_exp[id] = _compile(String(u.get("cost_formula", "0")), id, "cost")
		_value_exp[id] = _compile(String(u.get("value_formula", "0")), id, "value")

func _compile(src: String, id: String, what: String) -> Expression:
	var e := Expression.new()
	if e.parse(src, ["level"]) != OK:
		push_error("[Upg] %s 의 %s_formula 를 해석하지 못했습니다: %s"
			% [id, what, src])
		return null
	return e

func _eval(e: Expression, level: int) -> float:
	if e == null:
		return 0.0
	var r = e.execute([level])
	if e.has_execute_failed():
		return 0.0
	return float(r)

# ══════════════════════════════════════════════
#  조회
# ══════════════════════════════════════════════
func ids() -> Array[String]:
	return _order

func has(id: String) -> bool:
	return defs.has(id)

func level(id: String) -> int:
	return SaveGame.upgrade_level(id)

func max_level(id: String) -> int:
	return int(defs.get(id, {}).get("max_level", 0))

func is_maxed(id: String) -> bool:
	return level(id) >= max_level(id)

## 현재 단계의 효과값. **다른 코드는 이 함수만 쓴다.**
##   unit "pct"  — 0.08 이면 +8%
##   unit "flat" — 12 이면 +12
func value(id: String) -> float:
	var lv := level(id)
	if lv <= 0 or not defs.has(id):
		return 0.0
	var per: Dictionary = _cache.get(id, {})
	if per.has(lv):
		return per[lv]
	var v := _eval(_value_exp.get(id), lv)
	per[lv] = v
	_cache[id] = per
	return v

## 다음 1단계를 올리는 데 드는 마석. 최대면 -1.
func next_cost(id: String) -> int:
	if not defs.has(id) or is_maxed(id):
		return -1
	return int(round(_eval(_cost_exp.get(id), level(id))))

## 다음 단계의 효과값 (UI 에서 "지금 → 다음" 을 보여 준다)
func next_value(id: String) -> float:
	if not defs.has(id) or is_maxed(id):
		return value(id)
	return _eval(_value_exp.get(id), level(id) + 1)

## 해금 조건을 만족하는가. 조건이 없으면 항상 true.
func is_unlocked(id: String) -> bool:
	var c = defs.get(id, {}).get("unlock_condition", null)
	if typeof(c) != TYPE_DICTIONARY:
		return true
	var kind := String(c.get("kind", ""))
	var need := int(c.get("level", 1))
	match kind:
		"upgrade":
			return level(String(c.get("id", ""))) >= need
		"counter":
			return SaveGame.counter(String(c.get("id", ""))) >= need
		"chapter":
			return GameManager.chapter >= need
	return true

func lock_reason(id: String) -> String:
	var c = defs.get(id, {}).get("unlock_condition", null)
	if typeof(c) != TYPE_DICTIONARY or is_unlocked(id):
		return ""
	var kind := String(c.get("kind", ""))
	var need := int(c.get("level", 1))
	match kind:
		"upgrade":
			var other := String(c.get("id", ""))
			return "%s %d단계 필요" % [
				String(defs.get(other, {}).get("name", other)), need]
		"counter":
			return "랜드마크 %d곳 클리어 필요" % need
		"chapter":
			return "%d장 도달 필요" % need
	return "잠김"

# ══════════════════════════════════════════════
#  구매
# ══════════════════════════════════════════════
## 성공하면 true. 마석 부족·최대·미해금이면 false.
func purchase(id: String) -> bool:
	if not defs.has(id) or is_maxed(id) or not is_unlocked(id):
		return false
	var cost := next_cost(id)
	if cost < 0 or CraftManager.essence < cost:
		return false

	CraftManager.add_essence(-cost)
	var lv := SaveGame.add_upgrade(id, 1)     ## add_upgrade 가 저장까지 한다
	_cache.erase(id)
	_apply_now(id)
	purchased.emit(id, lv)
	changed.emit()
	return true

## 즉시 반영이 필요한 것들 — 최대 체력처럼 값이 아니라 상태인 것
func _apply_now(id: String) -> void:
	PlayerStats.stats_changed.emit()
	if id == "hp":
		var p := Battlefield.live_player()
		if p:
			# 늘어난 만큼 지금 체력도 같이 올려 준다 (구매 직후 손해 보지 않게)
			p.hp = minf(p.max_hp, p.hp + value(id))

# ══════════════════════════════════════════════
#  효과 적용 헬퍼 — 소비 코드가 부른다
# ══════════════════════════════════════════════

## 배율 (1.0 + pct). 공격력·이동속도처럼 곱으로 쓰는 것.
func mult(id: String) -> float:
	return 1.0 + value(id)

## 감소 배율 (1.0 - pct, 하한 0.35). 쿨다운처럼 줄이는 것.
func reduce(id: String) -> float:
	var v := value(id)
	if id == "cooldown" or id == "attack_speed":
		v += PlayerStats.get_item_cdr()
		if PlayerStats.has_legendary("echo"):
			v += float(CombatFeel.pacing().get("legendary", {}).get("echo", {}).get("cooldown", 0.0))
	return maxf(0.35, 1.0 - v)

## 치명타 판정 — [배율, 터졌는가]
func roll_crit() -> Array:
	var rate := value("critical_rate") + PlayerStats.get_item_crit() \
		+ PlayerStats.wf("crit_bonus", 0.0)
	if rate <= 0.0 or randf() > rate:
		return [1.0, false]
	var cd := 1.5 + value("critical_damage")
	if PlayerStats.has_legendary("overflow"):
		cd += CombatFeel.pace("legendary", "overflow", 0.0) \
			if false else float(CombatFeel.pacing().get("legendary", {}).get("overflow", {}).get("crit_damage", 0.0))
	return [cd, true]

## 전체 초기화 (NEW GAME+ / 새 게임)
func reset() -> void:
	_cache.clear()
	changed.emit()

# ══════════════════════════════════════════════
#  빌드 안내 (data/builds.json) — 표시 전용
# ══════════════════════════════════════════════
const BUILD_PATH := "res://data/builds.json"
var _builds: Array = []

func builds() -> Array:
	if not _builds.is_empty():
		return _builds
	var f := FileAccess.open(BUILD_PATH, FileAccess.READ)
	if f == null:
		return []
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(j) == TYPE_DICTIONARY:
		_builds = j.get("builds", [])
	return _builds

## 태그별로 묶어 돌려준다 (UI 가 그대로 출력한다)
func builds_by_tag() -> Dictionary:
	var out := {}
	for b in builds():
		var t := String(b.get("tag", "기타"))
		if not out.has(t):
			out[t] = []
		out[t].append(b)
	return out
