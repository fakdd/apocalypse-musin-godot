## ⚠ AI Asset Factory 가 자동 생성한 파일입니다.
## 캠페인 데이터를 읽는 로더입니다 — 캠페인을 고쳐도 이 파일은 바뀌지 않습니다.
## (데이터는 res://data/campaigns/campaign_<id>.json 에 있습니다)
extends RefCounted
class_name CampaignData
## 캠페인 = 랜드마크를 맵 위에 배치하고 이동 경로로 이은 것.
##
## 사용 예:
##     var camp := CampaignData.load_campaign("main")
##     if camp == null:
##         push_error("캠페인을 불러오지 못했습니다")
##         return
##     for site in camp.nodes:
##         place_landmark(site.id, site.world_pos())
##     for r in camp.routes:
##         draw_route(camp.node_by_id(r.from_id), camp.node_by_id(r.to_id))

const SCHEMA_VERSION := 2
const DATA_DIR := "res://data/campaigns"

# ══════════════════════════════════════════
class Event extends RefCounted:
	var trigger := "on_enter"
	var action := "banner"
	var value := {}
	var once := true
	## 실행 조건 — 전부 만족해야 실행된다 (비면 항상 실행)
	##   [{"kind": "quest_completed", "value": "q_hospital"}]
	var conditions: Array = []

	func value_str(key: String, fallback: String = "") -> String:
		return String(value.get(key, fallback))

	func value_int(key: String, fallback: int = 0) -> int:
		return int(value.get(key, fallback))


class Wave extends RefCounted:
	var index := 1
	var composition := {}
	var delay := 0.0
	var hp_mult := 1.0
	var boss := ""

	func total_count() -> int:
		var n := 0
		for k in composition:
			n += int(composition[k])
		return n


class NPC extends RefCounted:
	var id := ""
	var display_name := ""
	var role := ""
	var dialogue := ""
	var reward := ""
	## idle / quest / completed — 진행에 따라 대사가 달라진다
	var state := "idle"
	var dialogue_quest := ""
	var dialogue_completed := ""

	## 현재 상태에 맞는 대사를 고른다 (없으면 기본 대사)
	func line_for(current_state: String) -> String:
		match current_state:
			"quest":
				return dialogue_quest if dialogue_quest != "" else dialogue
			"completed":
				return dialogue_completed if dialogue_completed != "" else dialogue
		return dialogue


class Quest extends RefCounted:
	var id := ""
	var title := ""
	var objective := "explore"
	var target := 1
	var essence := 0
	var rarity := ""
	var next_id := ""


## 복합 랜드마크 안의 구역 하나 (v2).
## 게임에서는 구역마다 진입 영역이 하나씩 만들어진다 —
## 즉 예전에 노드 세 개로 하던 것을 노드 하나 + 구역 세 개로 표현할 뿐,
## 월드에 생기는 결과물은 같다.
class Stage extends RefCounted:
	var id := ""
	var area_id := ""          ## 게임에서 쓰는 랜드마크 id (세이브 키)
	var display_name := ""
	var subtitle := ""
	var description := ""
	var x := 0.0
	var z := 0.0
	var radius := 7.0
	var zone := 0
	var danger := 1
	var level := 1
	var bgm := ""
	var enter_stinger := ""
	var locked_until := ""
	var boss := ""
	var boss_hp_mult := 1.0
	var item_count := -1        ## -1 = 위험도에서 유도
	var item_luck := -1.0
	var guaranteed := ""
	var ambient := {}
	var story := PackedStringArray()
	var waves: Array = []       ## Wave
	var npcs: Array = []        ## NPC
	var events: Array = []      ## Event
	var quest: Quest = null

	func world_pos() -> Vector3:
		return Vector3(x, 0.0, z)

	func stars() -> String:
		var out := ""
		for i in range(5):
			out += "★" if i < danger else "☆"
		return out

	func events_for(trigger_name: String) -> Array:
		var out: Array = []
		for e in events:
			if e.trigger == trigger_name:
				out.append(e)
		return out

	func total_enemies() -> int:
		var n := 0
		for w in waves:
			n += w.total_count()
		return n


class MapNode extends RefCounted:
	var id := ""
	var display_name := ""
	var order := 0
	var x := 0.0
	var z := 0.0
	var zone := 0
	var danger := 1
	var level := 1
	var radius := 9.0
	var bgm := ""
	var boss := ""
	var boss_hp_mult := 1.0
	var locked_until := ""
	var ambient := {}
	var story := PackedStringArray()
	var waves: Array = []      ## Wave
	var npcs: Array = []       ## NPC
	var events: Array = []     ## Event
	var quest: Quest = null
	var missing_landmark := false
	## 복합 랜드마크의 구역들 (비면 이 노드 자체가 하나의 구역)
	var stages: Array = []      ## Stage

	## 이 노드가 만들어내는 진입 영역들.
	## 구역이 없으면 자기 자신을 감싼 Stage 하나를 만들어 돌려준다 —
	## 그래서 CampaignManager 는 v1/v2 를 구분할 필요가 없다.
	func areas() -> Array:
		if not stages.is_empty():
			return stages
		var st := Stage.new()
		st.id = "main"
		st.area_id = id
		st.display_name = display_name
		st.x = x
		st.z = z
		st.radius = radius
		st.zone = zone
		st.danger = danger
		st.level = level
		st.bgm = bgm
		st.locked_until = locked_until
		st.boss = boss
		st.boss_hp_mult = boss_hp_mult
		st.ambient = ambient
		st.story = story
		st.waves = waves
		st.npcs = npcs
		st.events = events
		st.quest = quest
		return [st]

	func is_complex() -> bool:
		return not stages.is_empty()

	## 게임 월드 좌표 — 그대로 놓으면 된다
	func world_pos() -> Vector3:
		return Vector3(x, 0.0, z)

	func stars() -> String:
		var out := ""
		for i in range(5):
			out += "★" if i < danger else "☆"
		return out

	func events_for(trigger_name: String) -> Array:
		var out: Array = []
		for e in events:
			if e.trigger == trigger_name:
				out.append(e)
		return out

	func total_enemies() -> int:
		var n := 0
		for w in waves:
			n += w.total_count()
		return n


class Route extends RefCounted:
	var from_id := ""
	var to_id := ""
	var kind := "main"
	var locked_until := ""

	func connects(a: String, b: String) -> bool:
		return (from_id == a and to_id == b) or (from_id == b and to_id == a)


# ══════════════════════════════════════════
var id := ""
var display_name := ""
var description := ""
var author := ""
var modified := ""
var schema_version := 1
var arena_w := 80.0
var arena_h := 80.0
var start_id := ""
var nodes: Array = []          ## MapNode (order 순 정렬됨)
var routes: Array = []         ## Route
var global_events: Array = []  ## Event

## ── 조회 ──
func node_by_id(node_id: String) -> MapNode:
	for n in nodes:
		if n.id == node_id:
			return n
	return null

func start_node() -> MapNode:
	return node_by_id(start_id)

## 이 노드에서 갈 수 있는 노드 id 목록
func neighbors(node_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for r in routes:
		if r.from_id == node_id:
			out.append(r.to_id)
		elif r.to_id == node_id:
			out.append(r.from_id)
	return out

## 잠긴 경로를 제외한 이웃 (done_quests: 완료한 퀘스트 id 목록)
func open_neighbors(node_id: String, done_quests: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for r in routes:
		var other := ""
		if r.from_id == node_id:
			other = r.to_id
		elif r.to_id == node_id:
			other = r.from_id
		else:
			continue
		if r.locked_until != "" and not done_quests.has(r.locked_until):
			continue
		var target: MapNode = node_by_id(other)
		if target and target.locked_until != "" and not done_quests.has(target.locked_until):
			continue
		out.append(other)
	return out

## 모든 노드의 모든 구역을 펼쳐서 돌려준다 (CampaignManager 가 쓴다)
func all_areas() -> Array:
	var out: Array = []
	for n in nodes:
		for st in n.areas():
			out.append(st)
	return out

## area_id 로 구역을 찾는다
func area_by_id(area_id: String) -> Stage:
	for n in nodes:
		for st in n.areas():
			if st.area_id == area_id:
				return st
	return null

func nodes_in_zone(zone_index: int) -> Array:
	var out: Array = []
	for n in nodes:
		if n.zone == zone_index:
			out.append(n)
	return out

## 가장 가까운 노드 (플레이어 위치로 "지금 어느 랜드마크 근처인가" 판정)
func nearest_node(pos: Vector3) -> MapNode:
	var best: MapNode = null
	var best_d := INF
	for n in nodes:
		var d: float = pos.distance_to(n.world_pos())
		if d < best_d:
			best_d = d
			best = n
	return best

## 플레이어가 지금 안에 들어와 있는 노드 (반경 판정). 없으면 null
func node_at(pos: Vector3) -> MapNode:
	for n in nodes:
		if pos.distance_to(n.world_pos()) <= n.radius:
			return n
	return null


# ══════════════════════════════════════════
#  불러오기
# ══════════════════════════════════════════
static func load_campaign(campaign_id: String) -> CampaignData:
	return load_from_path("%s/campaign_%s.json" % [DATA_DIR, campaign_id])

static func load_from_path(path: String) -> CampaignData:
	if not FileAccess.file_exists(path):
		push_error("캠페인 파일이 없습니다: " + path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("캠페인 JSON 을 해석할 수 없습니다: " + path)
		return null
	return from_dict(parsed)

## 사용 가능한 캠페인 id 목록
static func list_campaigns() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.begins_with("campaign_") and f.ends_with(".json"):
			out.append(f.substr(9, f.length() - 14))
	return out

static func from_dict(d: Dictionary) -> CampaignData:
	var c := CampaignData.new()
	var schema := int(d.get("version", d.get("schema", 0)))
	if schema > SCHEMA_VERSION:
		push_warning("캠페인 스키마 버전이 더 높습니다 (%d > %d) — 일부 항목이 무시될 수 있습니다"
			% [schema, SCHEMA_VERSION])
	c.schema_version = schema
	c.id = String(d.get("id", ""))
	c.display_name = String(d.get("name", ""))
	c.description = String(d.get("description", ""))
	c.author = String(d.get("author", ""))
	c.modified = String(d.get("modified", ""))
	var arena: Dictionary = d.get("arena", {})
	c.arena_w = float(arena.get("w", 80.0))
	c.arena_h = float(arena.get("h", 80.0))
	c.start_id = String(d.get("start", ""))

	for raw in d.get("nodes", []):
		c.nodes.append(_parse_node(raw))
	for raw in d.get("routes", []):
		var r := Route.new()
		r.from_id = String(raw.get("from", ""))
		r.to_id = String(raw.get("to", ""))
		r.kind = String(raw.get("kind", "main"))
		r.locked_until = String(raw.get("locked_until", ""))
		c.routes.append(r)
	for raw in d.get("events", []):
		c.global_events.append(_parse_event(raw))
	return c

static func _parse_node(raw: Dictionary) -> MapNode:
	var n := MapNode.new()
	n.id = String(raw.get("id", ""))
	n.display_name = String(raw.get("name", n.id))
	n.order = int(raw.get("order", 0))
	var pos: Dictionary = raw.get("pos", {})
	n.x = float(pos.get("x", 0.0))
	n.z = float(pos.get("z", 0.0))
	n.zone = int(raw.get("zone", 0))
	n.danger = int(raw.get("danger", 1))
	n.level = int(raw.get("level", 1))
	n.radius = float(raw.get("radius", 9.0))
	n.bgm = String(raw.get("bgm", ""))
	n.boss = String(raw.get("boss", ""))
	n.boss_hp_mult = float(raw.get("boss_hp_mult", 1.0))
	n.locked_until = String(raw.get("locked_until", ""))
	n.ambient = _int_counts(raw.get("ambient", {}))
	n.missing_landmark = bool(raw.get("missing_landmark", false))

	for s in raw.get("story", []):
		n.story.append(String(s))

	for rw in raw.get("waves", []):
		n.waves.append(_parse_wave(rw))

	for rp in raw.get("npcs", []):
		n.npcs.append(_parse_npc(rp))

	for re in raw.get("events", []):
		n.events.append(_parse_event(re))

	for rs in raw.get("stages", []):
		n.stages.append(_parse_stage(rs))

	if raw.has("quest"):
		n.quest = _parse_quest(raw.get("quest", {}))
	return n

## Godot 의 JSON 파서는 모든 수를 float 로 만든다.
## 마릿수는 정수여야 하므로 여기서 되돌린다 —
## 그러지 않으면 소비 코드가 {"hound": 3.0} 을 받아 비교/표시에서 놀라게 된다.
static func _int_counts(raw) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for k in raw:
		out[String(k)] = int(raw[k])
	return out

static func _parse_stage(raw: Dictionary) -> Stage:
	var st := Stage.new()
	st.id = String(raw.get("id", ""))
	st.area_id = String(raw.get("area_id", st.id))
	st.display_name = String(raw.get("name", st.id))
	st.subtitle = String(raw.get("subtitle", ""))
	st.description = String(raw.get("desc", ""))
	var pos: Dictionary = raw.get("pos", {})
	st.x = float(pos.get("x", 0.0))
	st.z = float(pos.get("z", 0.0))
	st.radius = float(raw.get("radius", 7.0))
	st.zone = int(raw.get("zone", 0))
	st.danger = int(raw.get("danger", 1))
	st.level = int(raw.get("level", 1))
	st.bgm = String(raw.get("bgm", ""))
	st.enter_stinger = String(raw.get("stinger", ""))
	st.locked_until = String(raw.get("locked_until", ""))
	st.boss = String(raw.get("boss", ""))
	st.boss_hp_mult = float(raw.get("boss_hp_mult", 1.0))
	st.item_count = int(raw.get("items", -1))
	st.item_luck = float(raw.get("luck", -1.0))
	st.guaranteed = String(raw.get("guaranteed", ""))
	st.ambient = _int_counts(raw.get("ambient", {}))
	for sline in raw.get("story", []):
		st.story.append(String(sline))
	for rw in raw.get("waves", []):
		st.waves.append(_parse_wave(rw))
	for rp in raw.get("npcs", []):
		st.npcs.append(_parse_npc(rp))
	for re in raw.get("events", []):
		st.events.append(_parse_event(re))
	if raw.has("quest"):
		st.quest = _parse_quest(raw.get("quest", {}))
	return st

static func _parse_wave(rw: Dictionary) -> Wave:
	var w := Wave.new()
	w.index = int(rw.get("index", 1))
	w.composition = _int_counts(rw.get("composition", {}))
	w.delay = float(rw.get("delay", 0.0))
	w.hp_mult = float(rw.get("hp_mult", 1.0))
	w.boss = String(rw.get("boss", ""))
	return w

static func _parse_npc(rp: Dictionary) -> NPC:
	var p := NPC.new()
	p.id = String(rp.get("id", ""))
	p.display_name = String(rp.get("name", ""))
	p.role = String(rp.get("role", ""))
	p.dialogue = String(rp.get("dialogue", ""))
	p.reward = String(rp.get("reward", ""))
	p.state = String(rp.get("state", "idle"))
	p.dialogue_quest = String(rp.get("dialogue_quest", ""))
	p.dialogue_completed = String(rp.get("dialogue_completed", ""))
	return p

static func _parse_quest(rq: Dictionary) -> Quest:
	var q := Quest.new()
	q.id = String(rq.get("id", ""))
	q.title = String(rq.get("title", ""))
	q.objective = String(rq.get("objective", "explore"))
	q.target = int(rq.get("target", 1))
	q.essence = int(rq.get("essence", 0))
	q.rarity = String(rq.get("rarity", ""))
	q.next_id = String(rq.get("next", ""))
	return q

static func _parse_event(raw: Dictionary) -> Event:
	var e := Event.new()
	e.trigger = String(raw.get("trigger", "on_enter"))
	e.action = String(raw.get("action", "banner"))
	e.value = raw.get("value", {})
	e.once = bool(raw.get("once", true))
	e.conditions = raw.get("conditions", [])
	return e
