extends Node
## 저장 / 불러오기 — 모든 진행 상태를 JSON 한 파일에 담는다.
##
## 왜 지금 만드나:
##   업그레이드 제단·업적·NPC 호감도·NEW GAME+ 는 전부 "껐다 켜도 남아야" 의미가 있다.
##   저장을 나중에 붙이면 그 시스템들을 만들 때마다 저장 구조를 소급 수정해야 한다.
##   그래서 **먼저 그릇을 만들고**, 앞으로는 여기에 칸만 채운다.
##
## 설계 원칙 (캠페인 스키마에서 배운 것과 같다):
##   1) version 을 박는다. 구조가 바뀌어도 옛 세이브를 읽을 수 있어야 한다.
##   2) **없는 키는 기본값으로 넘어간다.** 새 항목이 생겨도 옛 세이브가 깨지지 않는다.
##   3) 정의(아이템 표·랜드마크 표)는 저장하지 않는다. **진행 상태만** 저장한다.
##      그래야 콘텐츠를 고쳐도 세이브가 살아남는다.
##
## 아직 아무도 안 쓰는 칸(achievements / upgrades / affinity / …)을 미리 둔 이유:
##   나중에 그 시스템을 만들 때 저장 코드를 고치지 않고 값만 넣으면 되게 하기 위해서다.

const PATH := "user://save.json"
const SLOT_COUNT := 3

## 현재 사용 중인 슬롯. 0 은 기존 경로를 그대로 쓴다 — 옛 세이브 호환.
var slot := 0

## 슬롯 파일 경로. 슬롯 0 만 PATH 를 쓰고 나머지는 뒤에 번호가 붙는다.
func slot_path(i: int = -1) -> String:
	var n: int = slot if i < 0 else i
	return PATH if n <= 0 else "user://save_%d.json" % n

## 슬롯 요약 — 메뉴가 그대로 출력한다. 파일이 없으면 empty=true.
func slot_info(i: int) -> Dictionary:
	var path := slot_path(i)
	if not FileAccess.file_exists(path):
		return {"slot": i, "empty": true}
	var j = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(j) != TYPE_DICTIONARY:
		return {"slot": i, "empty": true}
	var pr: Dictionary = j.get("progress", {})
	return {
		"slot": i, "empty": false,
		"chapter": int(pr.get("chapter", 1)),
		"level": int(j.get("player", {}).get("level", 1)),
		"ng_plus": int(j.get("ng_plus", 0)),
		"tier": int(j.get("world_tier", 0)),
		"seconds": float(j.get("run_seconds", 0.0)),
		"saved_at": String(j.get("saved_at", "")),
	}

## 슬롯을 고르고 그 내용을 읽는다. 비어 있으면 새 게임 상태로 둔다.
func use_slot(i: int) -> bool:
	slot = clampi(i, 0, SLOT_COUNT - 1)
	session_started = true
	has_save = false
	if not FileAccess.file_exists(slot_path()):
		return false
	return load_game()
const VERSION := 1

signal saved()
signal loaded()

## 이 세션에서 불러온 적이 있는가 (없으면 새 게임)
var has_save := false

# ══════════════════════════════════════════════
#  앞으로 채워질 칸 — 지금은 그릇만 있다
# ══════════════════════════════════════════════
## 업적 id → true (7순위 히든 업적이 여기 들어온다)
var achievements := {}
## 영구 강화 "atk"/"def"/"hp"/"speed"/"crit"/"skill" → 단계 (업그레이드 제단)
var upgrades := {}
## NPC id → 호감도
var affinity := {}
## 푼 퍼즐 id → true
var puzzles := {}
## 누적 카운터 ("boss"/"puzzle"/"secret"/"chest"…) → 값.
## 업적이 이 값을 보고 달성 여부를 판단한다 (AchievementManager).
var counters := {}
## NEW GAME+ 회차 (0 = 첫 회차)
var ng_plus := 0
## ── 엔드게임 (data/endgame.json) ──
var world_tier := 0
var records: Dictionary = {}      ## challenge_id -> true / 최고 기록값
var run_seconds := 0.0            ## 이번 회차 누적 플레이 시간
var run_deaths := 0
## ── 환경설정 (슬롯과 무관 — 전역) ──
var graphics := 1                 ## 0 Low / 1 Medium / 2 High
var master_db := 0.0
## ── 보스 러시 ──
var rush_index := -1              ## -1 이면 진행 중이 아니다

## 이번 실행에서 슬롯을 골랐는가.
## 저장하지 않는다 — 게임을 껐다 켜면 다시 타이틀부터다.
## 이게 없으면 "새 게임 → 세이브 삭제 → 씬 재로드 → 세이브 없음 → 타이틀"
## 이 끝없이 반복돼 게임에 들어갈 수 없었다.
var session_started := false

func _ready() -> void:
	# 저장은 게임을 끌 때도 되어야 한다
	get_tree().auto_accept_quit = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
		get_tree().quit()

# ══════════════════════════════════════════════
#  저장
# ══════════════════════════════════════════════
func save() -> bool:
	var d := {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"progress": _progress_out(),
		"player": _player_out(),
		"world": LandmarkRegistry.to_save(),
		# 앞으로 쓸 칸
		"achievements": achievements.keys(),
		"upgrades": upgrades,
		"affinity": affinity,
		"puzzles": puzzles.keys(),
		"counters": counters,
		"ng_plus": ng_plus,
		"world_tier": world_tier,
		"records": records,
		"run_seconds": run_seconds,
		"run_deaths": run_deaths,
		"graphics": graphics,
		"master_db": master_db,
	}
	var f := FileAccess.open(slot_path(), FileAccess.WRITE)
	if f == null:
		push_error("[Save] 저장 실패: %s" % slot_path())
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	saved.emit()
	return true

func _progress_out() -> Dictionary:
	return {
		"chapter": GameManager.chapter,
		"chapter_boss_down": GameManager.chapter_boss_down,
		"day": GameManager.day_count,
		"wave": GameManager.wave,
		"kills": GameManager.kill_count,
		"seals": GameManager.seals_done,
		"final_boss_spawned": GameManager.final_boss_spawned,
		"game_won": GameManager.game_won,
	}

func _player_out() -> Dictionary:
	return {
		"level": GameManager.player_level,
		"exp": GameManager.player_exp,
		"essence": CraftManager.essence,
		"resources": GameManager.resources.duplicate(),
		"survivors": GameManager.survivors_rescued,
		"bonus_max_hp": GameManager.bonus_max_hp,
		"base_hp": GameManager.base_hp,
		"base_max_hp": GameManager.base_max_hp,
		"trait": TraitManager.current_trait.duplicate(),
		"reroll_count": TraitManager.reroll_count,
		"pets_owned": PetManager.owned.duplicate(),
		"pet_active": PetManager.active,
		"pet_levels": PetManager.levels.duplicate(),
		"pet_pity": PetManager.pity,
		"inventory": _items_out(PlayerStats.inventory),
		"equipped": _equipped_out(),
	}

func _items_out(items: Array) -> Array:
	var out := []
	for it in items:
		if it != null:
			out.append(_item_out(it))
	return out

func _item_out(it) -> Dictionary:
	# ItemData 는 @export 필드뿐이라 그대로 옮기면 된다
	return {
		"name": it.name, "rarity": it.rarity,
		"atk": it.atk_bonus, "speed": it.speed_bonus,
		"slot": it.slot, "skin": it.skin, "enhance": it.enhance_level,
	}

func _equipped_out() -> Dictionary:
	var out := {}
	for slot in PlayerStats.equipped:
		var it = PlayerStats.equipped[slot]
		if it != null:
			out[slot] = _item_out(it)
	return out

# ══════════════════════════════════════════════
#  불러오기
# ══════════════════════════════════════════════
func exists() -> bool:
	return FileAccess.file_exists(slot_path())

func load_game() -> bool:
	if not exists():
		return false
	var text := FileAccess.get_file_as_string(slot_path())
	var raw = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY:
		push_error("[Save] 세이브를 읽지 못했습니다 (형식 오류)")
		return false
	var d: Dictionary = raw

	# 버전이 달라도 읽는다 — 없는 키는 전부 기본값으로 넘어간다
	_progress_in(d.get("progress", {}))
	_player_in(d.get("player", {}))
	LandmarkRegistry.from_save(d.get("world", {}))

	achievements.clear()
	for a in d.get("achievements", []):
		achievements[String(a)] = true
	upgrades = d.get("upgrades", {})
	affinity = d.get("affinity", {})
	puzzles.clear()
	for p in d.get("puzzles", []):
		puzzles[String(p)] = true
	counters.clear()
	var cs = d.get("counters", {})
	if typeof(cs) == TYPE_DICTIONARY:
		for k in cs:
			counters[String(k)] = int(cs[k])
	ng_plus = int(d.get("ng_plus", 0))
	world_tier = int(d.get("world_tier", 0))
	var rc = d.get("records", {})
	records = rc if typeof(rc) == TYPE_DICTIONARY else {}
	run_seconds = float(d.get("run_seconds", 0.0))
	run_deaths = int(d.get("run_deaths", 0))
	graphics = clampi(int(d.get("graphics", 1)), 0, 2)
	master_db = float(d.get("master_db", 0.0))

	has_save = true
	loaded.emit()
	print("[Save] 불러옴 — v%d · %d장 · Lv%d · %s"
		% [int(d.get("version", 0)), GameManager.chapter,
		GameManager.player_level, String(d.get("saved_at", "?"))])
	return true

func _progress_in(p: Dictionary) -> void:
	GameManager.chapter = clampi(int(p.get("chapter", 1)),
		ChapterConfig.FIRST, ChapterConfig.LAST)
	GameManager.chapter_boss_down = bool(p.get("chapter_boss_down", false))
	GameManager.day_count = int(p.get("day", 1))
	GameManager.wave = int(p.get("wave", 1))
	GameManager.kill_count = int(p.get("kills", 0))
	GameManager.seals_done = int(p.get("seals", 0))
	GameManager.final_boss_spawned = bool(p.get("final_boss_spawned", false))
	GameManager.game_won = bool(p.get("game_won", false))

func _player_in(p: Dictionary) -> void:
	GameManager.player_level = maxi(1, int(p.get("level", 1)))
	GameManager.player_exp = int(p.get("exp", 0))
	CraftManager.essence = int(p.get("essence", 0))
	GameManager.survivors_rescued = int(p.get("survivors", 0))
	GameManager.bonus_max_hp = int(p.get("bonus_max_hp", 0))
	GameManager.base_max_hp = float(p.get("base_max_hp", GameManager.base_max_hp))
	GameManager.base_hp = float(p.get("base_hp", GameManager.base_max_hp))

	var res = p.get("resources", null)
	if typeof(res) == TYPE_DICTIONARY:
		for k in res:
			GameManager.resources[String(k)] = int(res[k])

	var tr = p.get("trait", null)
	if typeof(tr) == TYPE_DICTIONARY and not tr.is_empty():
		TraitManager.current_trait = tr
		TraitManager.reroll_count = int(p.get("reroll_count", 0))
		if TraitManager.has_signal("trait_changed"):
			TraitManager.trait_changed.emit(tr)

	PetManager.owned.clear()
	for pet in p.get("pets_owned", []):
		PetManager.owned.append(String(pet))
	PetManager.active = String(p.get("pet_active", ""))
	var plv = p.get("pet_levels", {})
	PetManager.levels = plv.duplicate() if typeof(plv) == TYPE_DICTIONARY else {}
	PetManager.pity = int(p.get("pet_pity", 0))

	PlayerStats.inventory.clear()
	for raw in p.get("inventory", []):
		var it := _item_in(raw)
		if it != null:
			PlayerStats.inventory.append(it)
	PlayerStats.equipped.clear()
	var eq = p.get("equipped", {})
	if typeof(eq) == TYPE_DICTIONARY:
		for slot in eq:
			var it2 := _item_in(eq[slot])
			if it2 != null:
				PlayerStats.equipped[String(slot)] = it2

	PlayerStats.stats_changed.emit()
	PlayerStats.inventory_changed.emit()
	GameManager.exp_changed.emit(GameManager.player_exp,
		GameManager.exp_to_next(), GameManager.player_level)
	CraftManager.essence_changed.emit(CraftManager.essence)
	GameManager.base_hp_changed.emit()

func _item_in(raw) -> ItemData:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var it := ItemData.new()
	it.name = String(raw.get("name", "유물"))
	it.rarity = int(raw.get("rarity", 0))
	it.atk_bonus = float(raw.get("atk", 0.0))
	it.speed_bonus = float(raw.get("speed", 0.0))
	it.slot = String(raw.get("slot", "weapon"))
	it.skin = String(raw.get("skin", "sword"))
	it.enhance_level = int(raw.get("enhance", 0))
	return it

# ══════════════════════════════════════════════
#  편의 API — 앞으로 만들 시스템이 쓴다
# ══════════════════════════════════════════════

## 업적을 얻는다. 이미 있으면 false.
func unlock_achievement(id: String) -> bool:
	if id == "" or achievements.has(id):
		return false
	achievements[id] = true
	save()
	return true

func has_achievement(id: String) -> bool:
	return achievements.has(id)

## 영구 강화 단계를 올린다 (업그레이드 제단).
func add_upgrade(key: String, amount: int = 1) -> int:
	var lv: int = int(upgrades.get(key, 0)) + amount
	upgrades[key] = lv
	save()
	return lv

func upgrade_level(key: String) -> int:
	return int(upgrades.get(key, 0))

## 퍼즐을 풀었다고 기록한다. 이미 풀었으면 false.
func solve_puzzle(id: String) -> bool:
	if id == "" or puzzles.has(id):
		return false
	puzzles[id] = true
	save()
	return true

func is_puzzle_solved(id: String) -> bool:
	return puzzles.has(id)

## 누적 카운터를 올리고 새 값을 돌려준다 (업적 판정용).
func bump(key: String, amount: int = 1) -> int:
	var v: int = int(counters.get(key, 0)) + amount
	counters[key] = v
	return v

func counter(key: String) -> int:
	return int(counters.get(key, 0))

## NPC 호감도.
func add_affinity(npc_id: String, amount: int = 1) -> int:
	var v: int = int(affinity.get(npc_id, 0)) + amount
	affinity[npc_id] = v
	# 업적·강화·퍼즐과 같이 **얻는 즉시** 저장한다.
	# 여기가 빠져 있어서, 대화로 올린 호감도가 다음 저장 지점(아침·챕터 이동)
	# 전에 게임을 끄면 통째로 사라졌다.
	save()
	return v

## 세이브를 지운다 (새 게임).
func wipe() -> void:
	achievements.clear()
	upgrades.clear()
	affinity.clear()
	puzzles.clear()
	counters.clear()
	ng_plus = 0
	world_tier = 0
	records = {}
	run_seconds = 0.0
	run_deaths = 0
	rush_index = -1
	# graphics / master_db 는 환경설정이라 새 게임에도 남긴다
	has_save = false
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path()))

# ══════════════════════════════════════════════
#  엔드게임 — 월드 티어 / NEW GAME+ / 챌린지
# ══════════════════════════════════════════════
const ENDGAME_PATH := "res://data/endgame.json"
var _endgame: Dictionary = {}

func endgame() -> Dictionary:
	if not _endgame.is_empty():
		return _endgame
	var f := FileAccess.open(ENDGAME_PATH, FileAccess.READ)
	if f == null:
		_endgame = {"tiers": [], "challenges": [], "boss_rush": {}}
		return _endgame
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	_endgame = j if typeof(j) == TYPE_DICTIONARY else {}
	return _endgame

## 현재 월드 티어의 배율 묶음. 티어 0 은 전부 1.0 이라 기존 플레이와 같다.
func tier_def() -> Dictionary:
	var t: Array = endgame().get("tiers", [])
	if t.is_empty():
		return {}
	return t[clampi(world_tier, 0, t.size() - 1)]

func tier_mult(key: String) -> float:
	return float(tier_def().get(key, 1.0))

func tier_name() -> String:
	return String(tier_def().get("name", "표준"))

## 엔딩 직후 다음 회차를 연다. 성장(레벨/강화/업적)은 남고 진행만 초기화된다.
func start_new_game_plus() -> void:
	_check_challenges()
	ng_plus += 1
	var t: Array = endgame().get("tiers", [])
	world_tier = clampi(world_tier + 1, 0, maxi(0, t.size() - 1))
	run_seconds = 0.0
	run_deaths = 0
	GameManager.chapter = ChapterConfig.FIRST
	GameManager.chapter_boss_down = false
	GameManager.game_won = false
	GameManager.day_count = 1
	GameManager.wave = 1
	GameManager.seals_done = 0
	GameManager.final_boss_spawned = false
	LandmarkRegistry.reset()
	save()

## 회차를 끝냈을 때 챌린지 달성 여부를 기록한다.
func _check_challenges() -> void:
	for c in endgame().get("challenges", []):
		var id := String(c.get("id", ""))
		if id == "" or bool(records.get(id, false)):
			continue
		var ok := false
		match String(c.get("kind", "")):
			"no_death":
				ok = run_deaths == 0
			"time":
				ok = run_seconds > 0.0 and run_seconds <= float(c.get("value", 0.0))
			"tier":
				ok = world_tier >= int(c.get("value", 99))
			"boss_rush":
				ok = int(counter("boss_rush")) >= int(c.get("value", 99))
		if ok:
			records[id] = true

func challenge_listing() -> Array:
	var out := []
	for c in endgame().get("challenges", []):
		out.append({
			"id": String(c.get("id", "")),
			"name": String(c.get("name", "")),
			"desc": String(c.get("desc", "")),
			"done": bool(records.get(String(c.get("id", "")), false)),
		})
	return out

func boss_rush_order() -> Array:
	return endgame().get("boss_rush", {}).get("order", [])

## 엔딩을 본 적이 있으면 보스 러시가 열린다.
func boss_rush_unlocked() -> bool:
	return ng_plus > 0

## 새 게임 — 슬롯 파일과 런타임 상태를 모두 초기값으로 되돌린다.
## wipe() 는 세이브 데이터만 지우므로, 오토로드에 남은 진행 상태까지 함께 비운다.
func start_new_game(i: int) -> void:
	slot = clampi(i, 0, SLOT_COUNT - 1)
	session_started = true
	wipe()
	GameManager.reset_all()
	TraitManager.reset()
	PlayerStats.reset()
	CraftManager.reset()
	PetManager.reset()
	LandmarkRegistry.reset()
	DemoDirector.reset()
	CombatFeel.reset()
	Battlefield.reset()
	UpgradeManager.reset()
	rush_index = -1
	# 새 게임을 시작한 그 순간 슬롯 파일을 만든다.
	# 파일이 있어야 슬롯 목록에 뜨고, 부팅 시 타이틀로 되돌아가지 않는다.
	save()

## 보스 러시 기록 갱신 (최고 기록만 남긴다)
func note_boss_rush(cleared: int) -> void:
	var best := int(records.get("boss_rush", 0))
	if cleared > best:
		records["boss_rush"] = cleared
	counters["boss_rush"] = maxi(cleared, int(counter("boss_rush")))
	save()
