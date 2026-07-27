## ⚠ AI Asset Factory 가 자동 생성한 파일입니다.
## 난이도 편집기에서 값을 바꾸고 다시 생성하세요 — 직접 편집하면 다음 생성 때 덮어씁니다.

extends RefCounted
class_name QuestData
## 랜드마크 퀘스트 정의 — 난이도 편집기에서 생성됨.
##
## 목표 유형:
##   explore  진입하면 완료
##   clear    수호 몬스터 전멸
##   collect  아이템 N개 회수
##   boss     보스 처치
##   rescue   생존자 구조
##
## 사용 예:
##     var q := QuestData.for_landmark("police")
##     if q and not q.is_done:
##         hud.show_quest(q.title, q.describe())

class Quest extends RefCounted:
	var id := ""
	var landmark_id := ""
	var title := ""
	var description := ""
	var objective := "explore"
	var target := 1                ## collect/rescue 에서 필요한 개수
	var reward_essence := 0
	var reward_rarity := -1        ## >=0 이면 그 등급 아이템 1개
	var next_quest := ""           ## 이어지는 퀘스트 id ("" = 없음)
	var danger := 1
	var recommended_level := 1
	## 진행 상태 (세이브 대상)
	var progress := 0
	var is_done := false

	func describe() -> String:
		match objective:
			"explore":
				return "%s 에 진입하라" % title
			"clear":
				return "수호 몬스터를 모두 처치하라"
			"collect":
				return "아이템 %d / %d 회수" % [progress, target]
			"boss":
				return "보스를 처치하라"
			"rescue":
				return "생존자 %d / %d 구조" % [progress, target]
		return description

	func advance(amount: int = 1) -> bool:
		## 진행도를 올리고, 이번 호출로 완료되었으면 true 를 반환한다
		if is_done:
			return false
		progress += amount
		if progress >= target:
			progress = target
			is_done = true
			return true
		return false

	func to_save() -> Dictionary:
		return {"progress": progress, "done": is_done}

	func from_save(d: Dictionary) -> void:
		progress = int(d.get("progress", 0))
		is_done = bool(d.get("done", false))

static func _q(cfg: Dictionary) -> Quest:
	## Dictionary 로 받는 이유는 LandmarkCatalog 와 같다 —
	## 위치 인자는 값 하나를 빼먹으면 뒤가 전부 밀려 조용한 사고가 난다.
	var q := Quest.new()
	q.id = String(cfg["id"])
	q.landmark_id = String(cfg.get("landmark", ""))
	q.title = String(cfg.get("title", ""))
	q.description = String(cfg.get("desc", ""))
	q.objective = String(cfg.get("objective", "explore"))
	q.target = int(cfg.get("target", 1))
	q.reward_essence = int(cfg.get("essence", 0))
	q.reward_rarity = int(cfg.get("rarity", -1))
	q.next_quest = String(cfg.get("next", ""))
	q.danger = int(cfg.get("danger", 1))
	q.recommended_level = int(cfg.get("level", 1))
	return q

static func all() -> Array:
	var out: Array = []
	# ★☆☆☆☆  무너진 보건소
	out.append(_q({
		"id": "q_clinic", "landmark": "clinic",
		"title": "첫 구조",
		"desc": "간호사를 찾아 데리고 나와라",
		"objective": "rescue", "target": 2,
		"essence": 30, "rarity": RarityEnums.Rarity.E,
		"next": "q_police",
		"danger": 1, "level": 2,
	}))

	# ★★★☆☆  중앙 경찰서
	out.append(_q({
		"id": "q_police", "landmark": "police",
		"title": "무기고를 열어라",
		"desc": "",
		"objective": "clear", "target": 1,
		"essence": 60, "rarity": RarityEnums.Rarity.C,
		"next": "",
		"danger": 3, "level": 8,
	}))

	# ★★★★★  균열의 심장부
	out.append(_q({
		"id": "q_rift_core", "landmark": "rift_core",
		"title": "심장부 봉인",
		"desc": "",
		"objective": "boss", "target": 1,
		"essence": 300, "rarity": RarityEnums.Rarity.S,
		"next": "",
		"danger": 5, "level": 20,
	}))

	return out

## 랜드마크 id 로 퀘스트를 찾는다 (없으면 null)
static func for_landmark(landmark_id: String) -> Quest:
	for q in all():
		if q.landmark_id == landmark_id:
			return q
	return null

static func by_id(quest_id: String) -> Quest:
	for q in all():
		if q.id == quest_id:
			return q
	return null


# ══════════════════════════════════════════
#  NPC — 랜드마크에 배치되는 생존자/상인
# ══════════════════════════════════════════
class NPC extends RefCounted:
	var id := ""
	var landmark_id := ""
	var display_name := ""
	var role := "생존자"
	var dialogue := ""
	var reward := ""          ## 상호작용 보상 키 (게임이 해석)

static func _npc(cfg: Dictionary) -> NPC:
	var n := NPC.new()
	n.id = String(cfg["id"])
	n.landmark_id = String(cfg.get("landmark", ""))
	n.display_name = String(cfg.get("name", ""))
	n.role = String(cfg.get("role", "생존자"))
	n.dialogue = String(cfg.get("dialogue", ""))
	n.reward = String(cfg.get("reward", ""))
	return n

static func npcs_for(landmark_id: String) -> Array:
	match landmark_id:
		"clinic":
			return [
				_npc({"id": "nurse_yoon", "landmark": "clinic", "name": "간호사 윤", "role": "생존자", "dialogue": "아직 살아있는 사람이 있어요.", "reward": "heal"}),
			]
	return []


# ══════════════════════════════════════════
#  스토리 비트 — 진입/클리어 시 순서대로 표시
# ══════════════════════════════════════════
static func story_for(landmark_id: String) -> PackedStringArray:
	match landmark_id:
		"clinic":
			return PackedStringArray(["침상 옆에 식은 커피가 있다.", "누군가 방금까지 여기 있었다."])
		"rift_core":
			return PackedStringArray(["공간이 이곳에서 찢어졌다."])
	return PackedStringArray()
