extends Node
## NPC — 정의는 data/npcs.json, 저장은 SaveGame.
##
## 이 파일이 **NPC 의 유일한 관리자**다.
##   대사      NPCManager.dialog_for(id)
##   선택지    NPCManager.choices_for(id) / choose(id, choice_id)
##   상점      NPCManager.shop_for(id) / buy(id, item_id)
##   퀘스트    NPCManager.accept_quest / quest_progress / try_complete
##   호감도    NPCManager.affinity(id) / add_affinity
##
## 이 파일에는 NPC id 도 대사도 하나도 하드코딩돼 있지 않다.
## 조건(kind) 처리만 알고, 무엇을 언제 말할지는 전부 JSON 이 정한다.
##
## 저장:
##   호감도        SaveGame.affinity[npc_id]
##   퀘스트 상태   SaveGame.counters["npcq_<id>"]  0 없음 · 1 진행 · 2 완료
##   대화 여부     SaveGame.counters["npct_<id>"]
##   구매 기록     SaveGame.counters["shop_<npc>_<item>"]

const PATH := "res://data/npcs.json"

signal talked(npc_id: String)
signal quest_started(npc_id: String, quest_id: String)
signal quest_completed(npc_id: String, quest_id: String)
signal affinity_changed(npc_id: String, value: int)
signal shop_bought(npc_id: String, item_id: String)

const QUEST_NONE := 0
const QUEST_ACTIVE := 1
const QUEST_DONE := 2

var defs := {}
var tiers: Array = []
var _order: Array[String] = []

func _ready() -> void:
	_load_defs()

func _load_defs() -> void:
	if not FileAccess.file_exists(PATH):
		push_warning("[NPC] 정의가 없습니다: %s" % PATH)
		return
	var raw = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(raw) != TYPE_DICTIONARY:
		push_error("[NPC] 정의를 읽지 못했습니다 (형식 오류)")
		return
	tiers = raw.get("affinity_tiers", [])
	for n in raw.get("npcs", []):
		if typeof(n) != TYPE_DICTIONARY:
			continue
		var id := String(n.get("id", ""))
		if id == "":
			continue
		defs[id] = n
		_order.append(id)

func ids() -> Array[String]:
	return _order

func has(id: String) -> bool:
	return defs.has(id)

func name_of(id: String) -> String:
	return String(defs.get(id, {}).get("name", id))

func portrait_of(id: String) -> String:
	return String(defs.get(id, {}).get("portrait", "◈"))

# ══════════════════════════════════════════════
#  조건 — 대사·선택지·상점 모두 이것을 쓴다
# ══════════════════════════════════════════════
func meets(npc_id: String, conditions) -> bool:
	if typeof(conditions) != TYPE_ARRAY:
		return true
	for c in conditions:
		if not _one(npc_id, c):
			return false
	return true

func _one(npc_id: String, c) -> bool:
	if typeof(c) != TYPE_DICTIONARY:
		return true
	var kind := String(c.get("kind", ""))
	var v = c.get("value", "")
	match kind:
		"achievement":
			return SaveGame.has_achievement(String(v))
		"puzzle":
			return SaveGame.is_puzzle_solved(String(v))
		"chapter":
			return GameManager.chapter >= int(v)
		"boss":
			return SaveGame.counter("boss") >= int(v)
		"affinity":
			return affinity(npc_id) >= int(v)
		"quest_done":
			return quest_state(npc_id, String(v)) == QUEST_DONE
		"quest_active":
			return quest_state(npc_id, String(v)) == QUEST_ACTIVE
		"counter":
			return SaveGame.counter(String(c.get("key", ""))) >= int(v)
		"essence":
			return CraftManager.essence >= int(v)
		"item":
			for slot in PlayerStats.equipped:
				var it = PlayerStats.equipped[slot]
				if it != null and (it.skin == String(v) or it.name == String(v)):
					return true
			for it2 in PlayerStats.inventory:
				if it2 != null and (it2.skin == String(v) or it2.name == String(v)):
					return true
			return false
	return true

# ══════════════════════════════════════════════
#  대화
# ══════════════════════════════════════════════
## 조건을 만족하는 **첫 줄**이 대사가 된다 (조건 없는 줄은 항상 참)
func dialog_for(id: String) -> String:
	for line in defs.get(id, {}).get("dialog", []):
		if meets(id, line.get("conditions", [])):
			return String(line.get("text", ""))
	return ""

## 지금 고를 수 있는 선택지
func choices_for(id: String) -> Array:
	var out := []
	for c in defs.get(id, {}).get("choices", []):
		if not meets(id, c.get("conditions", [])):
			continue
		# 이미 수락한/끝난 퀘스트를 다시 주지 않는다
		var q := String(c.get("start_quest", ""))
		if q != "" and quest_state(id, q) != QUEST_NONE:
			continue
		# 비용이 모자라면 목록에는 두되 표시로 알린다
		out.append(c)
	return out

func can_afford(c: Dictionary) -> bool:
	var cost = c.get("cost", null)
	if typeof(cost) != TYPE_DICTIONARY:
		return true
	return CraftManager.essence >= int(cost.get("essence", 0))

## 선택지를 고른다. 반환: 답변 대사 (실패면 빈 문자열)
## 이 선택지를 고르면 대화가 끝나는가 (data/npcs.json 의 closes)
func closes_talk(npc_id: String, choice_id: String) -> bool:
	for c in choices_for(npc_id):
		if String(c.get("id", "")) == choice_id:
			return bool(c.get("closes", false))
	return false

func choose(npc_id: String, choice_id: String) -> String:
	var pick: Dictionary = {}
	for c in choices_for(npc_id):
		if String(c.get("id", "")) == choice_id:
			pick = c
			break
	if pick.is_empty() or not can_afford(pick):
		return ""

	var cost = pick.get("cost", null)
	if typeof(cost) == TYPE_DICTIONARY and int(cost.get("essence", 0)) > 0:
		CraftManager.add_essence(-int(cost["essence"]))

	var gain := int(pick.get("affinity", 0))
	if gain > 0:
		add_affinity(npc_id, gain)

	var q := String(pick.get("start_quest", ""))
	if q != "":
		accept_quest(npc_id, q)

	_give(pick.get("reward", {}))
	var ach := String(pick.get("achievement", ""))
	if ach != "":
		AchievementManager.unlock(ach)

	if not SaveGame.counters.has("npct_" + npc_id):
		SaveGame.counters["npct_" + npc_id] = 1
		AchievementManager.bump("npc_talk")
	talked.emit(npc_id)
	SaveGame.save()
	return String(pick.get("reply", ""))

func opens_shop(npc_id: String, choice_id: String) -> bool:
	for c in defs.get(npc_id, {}).get("choices", []):
		if String(c.get("id", "")) == choice_id:
			return bool(c.get("open_shop", false))
	return false

# ══════════════════════════════════════════════
#  호감도
# ══════════════════════════════════════════════
func affinity(npc_id: String) -> int:
	return int(SaveGame.affinity.get(npc_id, 0))

func add_affinity(npc_id: String, amount: int) -> int:
	var v := SaveGame.add_affinity(npc_id, amount)
	affinity_changed.emit(npc_id, v)
	return v

func tier_name(npc_id: String) -> String:
	var v := affinity(npc_id)
	var out := "낯섦"
	for t in tiers:
		if v >= int(t.get("at", 0)):
			out = String(t.get("name", out))
	return out

## 호감도 할인율 (0.0~0.30)
func discount(npc_id: String) -> float:
	return minf(0.30, float(affinity(npc_id)) * 0.03)

# ══════════════════════════════════════════════
#  퀘스트
# ══════════════════════════════════════════════
func quests_of(npc_id: String) -> Array:
	return defs.get(npc_id, {}).get("quests", [])

func quest_def(npc_id: String, quest_id: String) -> Dictionary:
	for q in quests_of(npc_id):
		if String(q.get("id", "")) == quest_id:
			return q
	return {}

func quest_state(npc_id: String, quest_id: String) -> int:
	return int(SaveGame.counters.get("npcq_" + quest_id, QUEST_NONE))

func accept_quest(npc_id: String, quest_id: String) -> bool:
	if quest_def(npc_id, quest_id).is_empty():
		return false
	if quest_state(npc_id, quest_id) != QUEST_NONE:
		return false
	SaveGame.counters["npcq_" + quest_id] = QUEST_ACTIVE
	quest_started.emit(npc_id, quest_id)
	SaveGame.save()
	return true

## [현재, 목표] — 목표가 없으면 [0, 0]
func quest_progress(npc_id: String, quest_id: String) -> Array:
	var q := quest_def(npc_id, quest_id)
	var goal = q.get("goal", null)
	if typeof(goal) != TYPE_DICTIONARY:
		return [0, 0]
	match String(goal.get("kind", "")):
		"counter":
			return [SaveGame.counter(String(goal.get("key", ""))),
				int(goal.get("target", 1))]
		"puzzle":
			return [1 if SaveGame.is_puzzle_solved(String(goal.get("key", ""))) else 0, 1]
		"achievement":
			return [1 if SaveGame.has_achievement(String(goal.get("key", ""))) else 0, 1]
	return [0, 0]

func quest_ready(npc_id: String, quest_id: String) -> bool:
	if quest_state(npc_id, quest_id) != QUEST_ACTIVE:
		return false
	var p := quest_progress(npc_id, quest_id)
	return int(p[1]) > 0 and int(p[0]) >= int(p[1])

## 진행 중이고 목표를 채운 퀘스트를 완료 처리한다. 완료한 id 목록.
func try_complete(npc_id: String) -> Array:
	var done := []
	for q in quests_of(npc_id):
		var qid := String(q.get("id", ""))
		if not quest_ready(npc_id, qid):
			continue
		SaveGame.counters["npcq_" + qid] = QUEST_DONE
		_give(q.get("reward", {}))
		var af := int(q.get("reward", {}).get("affinity", 0))
		if af > 0:
			add_affinity(npc_id, af)
		AchievementManager.bump("npc_quest")
		quest_completed.emit(npc_id, qid)
		done.append(qid)
	if not done.is_empty():
		SaveGame.save()
	return done

## 이 NPC 가 지금 줄 수 있는/진행 중인 퀘스트 (UI 표시용)
func active_quests(npc_id: String) -> Array:
	var out := []
	for q in quests_of(npc_id):
		var qid := String(q.get("id", ""))
		if quest_state(npc_id, qid) == QUEST_ACTIVE:
			out.append(q)
	return out

# ══════════════════════════════════════════════
#  상점
# ══════════════════════════════════════════════
func shop_for(npc_id: String) -> Array:
	var out := []
	for it in defs.get(npc_id, {}).get("shop", []):
		if meets(npc_id, it.get("conditions", [])):
			out.append(it)
	return out

func price_of(npc_id: String, item: Dictionary) -> int:
	var base := int(item.get("price", 0))
	return maxi(1, int(round(float(base) * (1.0 - discount(npc_id)))))

func buy(npc_id: String, item_id: String) -> bool:
	for it in shop_for(npc_id):
		if String(it.get("id", "")) != item_id:
			continue
		var p := price_of(npc_id, it)
		if CraftManager.essence < p:
			return false
		CraftManager.add_essence(-p)
		_give(it.get("effect", {}))
		SaveGame.bump("shop_%s_%s" % [npc_id, item_id])
		AchievementManager.bump("npc_shop")
		shop_bought.emit(npc_id, item_id)
		SaveGame.save()
		return true
	return false

# ══════════════════════════════════════════════
#  보상 지급 — 선택지·퀘스트·상점이 공유한다
# ══════════════════════════════════════════════
func _give(fx) -> void:
	if typeof(fx) != TYPE_DICTIONARY or fx.is_empty():
		return
	if int(fx.get("essence", 0)) > 0:
		CraftManager.add_essence(int(fx["essence"]))
	var heal := float(fx.get("heal_pct", 0.0))
	if heal > 0.0:
		var p := Battlefield.live_player()
		if p:
			p.hp = minf(p.max_hp, p.hp + p.max_hp * heal)
			p.hp_changed.emit()
	var rar := String(fx.get("rarity", fx.get("drop_rarity", "")))
	if rar != "":
		var p2 := Battlefield.live_player()
		var at: Vector3 = p2.global_position if p2 else Vector3.ZERO
		LootManager.spawn_drop(at + Vector3(1.4, 0, 0.6), 1.0, _rarity_index(rar))
	var ach := String(fx.get("achievement", ""))
	if ach != "":
		AchievementManager.unlock(ach)

func _rarity_index(name: String) -> int:
	if name == "":
		return -1
	var order := ["F", "E", "D", "C", "B", "A", "S", "SS", "SSS"]
	return order.find(name.to_upper())
