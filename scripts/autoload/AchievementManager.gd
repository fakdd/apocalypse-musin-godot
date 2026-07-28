extends Node
## 업적 — 정의는 data/achievements.json, 저장은 SaveGame.
##
## 설계:
##   · **이 파일에는 업적 id 가 하나도 하드코딩돼 있지 않다.** JSON 만 고치면 늘어난다.
##   · 이벤트를 보내는 쪽(CampaignManager · PuzzleSet · Enemy3D · LootManager)은
##     "무슨 일이 있었다" 만 알린다. 어떤 업적이 걸리는지는 여기서만 판단한다.
##   · 가능한 곳은 **기존 시그널에 직접 붙는다** — 소스 코드를 건드리지 않기 위해서다.
##     (보스 처치·레벨업·랜드마크 탐험/클리어)
##
## 업적 종류
##   counter — SaveGame.counters[counter] 가 target 이상이면 달성
##   event   — unlock(id) 을 직접 부르면 달성

const PATH := "res://data/achievements.json"

signal unlocked(id: String, def: Dictionary)

## id → 정의
var defs := {}
## counter 이름 → 그 카운터를 보는 업적 정의 목록
var _by_counter := {}
var _order: Array[String] = []

func _ready() -> void:
	_load_defs()
	_connect_sources()

func _load_defs() -> void:
	if not FileAccess.file_exists(PATH):
		push_warning("[Ach] 업적 정의가 없습니다: %s" % PATH)
		return
	var raw = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(raw) != TYPE_DICTIONARY:
		push_error("[Ach] 업적 정의를 읽지 못했습니다 (형식 오류)")
		return
	for a in raw.get("achievements", []):
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var id := String(a.get("id", ""))
		if id == "":
			continue
		defs[id] = a
		_order.append(id)
		if String(a.get("kind", "event")) == "counter":
			var key := String(a.get("counter", ""))
			if not _by_counter.has(key):
				_by_counter[key] = []
			_by_counter[key].append(a)

## 기존 시그널에 붙는다 — 소스 파일을 고치지 않아도 되는 것들
func _connect_sources() -> void:
	GameManager.chapter_boss_defeated.connect(_on_boss)
	GameManager.chapter_changed.connect(_on_chapter)
	GameManager.level_up.connect(_on_level)
	LandmarkRegistry.landmark_explored.connect(_on_explored)
	LandmarkRegistry.landmark_cleared.connect(_on_cleared)
	CraftManager.essence_changed.connect(_on_essence)

# ══════════════════════════════════════════════
#  공개 API — 이벤트 소스가 부른다
# ══════════════════════════════════════════════

## 업적을 달성한다. 이미 있으면 false.
func unlock(id: String) -> bool:
	if id == "" or SaveGame.has_achievement(id):
		return false
	if not defs.has(id):
		# 정의에 없는 id 도 저장은 한다 (JSON 에 나중에 추가할 수 있게)
		push_warning("[Ach] 정의에 없는 업적: %s" % id)
	SaveGame.unlock_achievement(id)
	var d: Dictionary = defs.get(id, {"id": id, "name": id, "desc": ""})
	unlocked.emit(id, d)
	_toast(d)
	return true

## 카운터를 올리고, 그 카운터를 보는 업적을 검사한다.
func bump(counter_key: String, amount: int = 1) -> void:
	if counter_key == "" or amount == 0:
		return
	var v: int = SaveGame.bump(counter_key, amount)
	_check(counter_key, v)

## 카운터를 절대값으로 맞춘다 (누적이 아니라 현재값이 기준일 때).
func set_counter(counter_key: String, value: int) -> void:
	if int(SaveGame.counters.get(counter_key, 0)) >= value:
		return
	SaveGame.counters[counter_key] = value
	_check(counter_key, value)

func _check(counter_key: String, value: int) -> void:
	for d in _by_counter.get(counter_key, []):
		if value >= int(d.get("target", 1)):
			unlock(String(d.get("id", "")))

# ══════════════════════════════════════════════
#  기존 시그널 → 카운터
# ══════════════════════════════════════════════
func _on_boss(_chapter: int) -> void:
	bump("boss")

func _on_chapter(_chapter: int) -> void:
	bump("chapter")

func _on_level(level: int) -> void:
	# 레벨 업적은 event 라 직접 건다 (JSON 에 id 만 있으면 된다)
	if level >= 10:
		unlock("ach_level_10")
	if level >= 20:
		unlock("ach_level_20")

func _on_explored(_d: LandmarkData) -> void:
	bump("explore")

func _on_cleared(_d: LandmarkData) -> void:
	bump("clear")

func _on_essence(total: int) -> void:
	# 마석은 쓰면 줄어들므로 **최고 기록**으로 센다
	set_counter("essence", total)

# ══════════════════════════════════════════════
#  진행률 (업적 목록 UI 가 쓴다)
# ══════════════════════════════════════════════

## [{id, name, desc, done, hidden, progress, target}] — 정의 순서 그대로
func listing() -> Array:
	var out := []
	for id in _order:
		var d: Dictionary = defs[id]
		var done: bool = SaveGame.has_achievement(id)
		var cur := 0
		var target := 0
		if String(d.get("kind", "event")) == "counter":
			target = int(d.get("target", 1))
			cur = mini(SaveGame.counter(String(d.get("counter", ""))), target)
		out.append({
			"id": id,
			"name": String(d.get("name", id)),
			"desc": String(d.get("desc", "")),
			"done": done,
			"hidden": bool(d.get("hidden", false)),
			"progress": cur,
			"target": target,
		})
	return out

func total() -> int:
	return _order.size()

func earned() -> int:
	var n := 0
	for id in _order:
		if SaveGame.has_achievement(id):
			n += 1
	return n

func _toast(d: Dictionary) -> void:
	var world = get_tree().current_scene
	if world == null or world.get("hud") == null:
		return
	if world.hud.has_method("show_achievement"):
		world.hud.show_achievement(String(d.get("name", "")), String(d.get("desc", "")))
	SoundManager.play("rescue", -8.0)
