extends Node
## 랜덤 이벤트 — 정의는 data/events.json, 저장은 SaveGame.
##
## 이 파일이 **이벤트의 유일한 관리자**다.
##   굴리기   EventManager.roll_daily()      ← 아침마다 DayNightManager 가 부른다
##   강제 발생 EventManager.emit_event(id)   ← 다른 시스템은 이것만 쓴다
##
## 이 파일에는 이벤트 id 가 하나도 하드코딩돼 있지 않다.
## kind 별 처리만 알고, 무엇이 언제 얼마나 나오는지는 전부 JSON 이 정한다.
##
## 버프(축복/저주)는 날짜 기준으로 만료된다 — SaveGame 에 남아 세이브를 넘어간다.

const PATH := "res://data/events.json"

signal event_fired(id: String, def: Dictionary)

var defs := {}
var _order: Array[String] = []
var _chance := 0.65

func _ready() -> void:
	_load_defs()

func _load_defs() -> void:
	if not FileAccess.file_exists(PATH):
		push_warning("[Ev] 이벤트 정의가 없습니다: %s" % PATH)
		return
	var raw = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(raw) != TYPE_DICTIONARY:
		push_error("[Ev] 이벤트 정의를 읽지 못했습니다 (형식 오류)")
		return
	_chance = float(raw.get("global", {}).get("chance", 0.65))
	for e in raw.get("events", []):
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var id := String(e.get("id", ""))
		if id == "":
			continue
		defs[id] = e
		_order.append(id)

# ══════════════════════════════════════════════
#  후보 / 추첨
# ══════════════════════════════════════════════

## 지금 챕터에서 일어날 수 있는 이벤트들
func candidates() -> Array:
	var out := []
	for id in _order:
		var d: Dictionary = defs[id]
		var chs: Array = d.get("chapters", [])
		if not chs.is_empty() and not chs.has(GameManager.chapter):
			continue
		if bool(d.get("once", false)) and _fired_once(id):
			continue
		out.append(d)
	return out

func _fired_once(id: String) -> bool:
	return SaveGame.counters.has("ev_once_" + id)

## 아침마다 한 번 굴린다. 일어나면 id, 아니면 빈 문자열.
func roll_daily() -> String:
	# 챕터가 올라갈수록 사건이 잦아진다 (tempo.event)
	if randf() > maxf(_chance, CombatFeel.tempo("event", _chance)):
		return ""
	var pool := candidates()
	if pool.is_empty():
		return ""
	var total := 0.0
	for d in pool:
		total += maxf(0.0, float(d.get("weight", 1)))
	if total <= 0.0:
		return ""
	var pick := randf() * total
	for d in pool:
		pick -= maxf(0.0, float(d.get("weight", 1)))
		if pick <= 0.0:
			return emit_event(String(d.get("id", "")))
	return emit_event(String(pool[-1].get("id", "")))

# ══════════════════════════════════════════════
#  발생
# ══════════════════════════════════════════════

## 이벤트를 실제로 일으킨다. 성공하면 id, 실패하면 빈 문자열.
func emit_event(id: String) -> String:
	if not defs.has(id):
		push_warning("[Ev] 정의에 없는 이벤트: %s" % id)
		return ""
	var d: Dictionary = defs[id]

	if bool(d.get("once", false)):
		SaveGame.counters["ev_once_" + id] = 1
	SaveGame.bump("event")

	_apply(d.get("effect", {}))
	_announce(d)
	SaveGame.save()
	event_fired.emit(id, d)
	return id

func _apply(fx: Dictionary) -> void:
	if fx.is_empty():
		return
	var world = get_tree().current_scene
	var center: Vector3 = world.world_center() if world and world.has_method("world_center") \
		else Vector3.ZERO

	if int(fx.get("essence", 0)) > 0:
		CraftManager.add_essence(int(fx["essence"]))

	if int(fx.get("survivor", 0)) > 0:
		for i in range(int(fx["survivor"])):
			GameManager.rescue_survivor()

	var drops := int(fx.get("drops", 0))
	if drops > 0:
		var idx := _rarity_index(String(fx.get("rarity", "")))
		var luck := float(fx.get("luck", 0.0))
		for i in range(drops):
			var a: float = TAU * float(i) / float(drops)
			var at: Vector3 = center + Vector3(cos(a) * 3.0, 0, sin(a) * 3.0 + 6.0)
			LootManager.spawn_drop(at, 1.0, idx if i == 0 else -1, luck)

	var spawn := int(fx.get("spawn", 0))
	if spawn > 0 and world and world.has_method("_make_enemy"):
		var scale := float(fx.get("spawn_scale", 1.0))
		var elite := bool(fx.get("elite", false))
		for i in range(spawn):
			var a2: float = TAU * float(i) / float(spawn) + randf() * 0.4
			var r: float = randf_range(18.0, 26.0)
			var pos: Vector3 = center + Vector3(cos(a2) * r, 0, sin(a2) * r)
			var e = world._make_enemy(_pick_mob(), pos)
			if e == null:
				continue
			if scale != 1.0:
				e.max_hp *= scale
				e.hp = e.max_hp
				if elite:
					e.scale *= 1.35
					e.contact_damage *= 1.4

	var fog := float(fx.get("fog", 0.0))
	if fog > 0.0 and world and world.get("env") != null:
		var env: Environment = world.env.environment
		if env:
			env.fog_density *= fog
			env.volumetric_fog_density *= minf(fog, 2.0)

	var buff := String(fx.get("buff", ""))
	if buff != "":
		_set_buff(buff, int(fx.get("duration_days", 1)))

func _pick_mob() -> String:
	var pool: Array = []
	for m in ChapterConfig.monsters_of(GameManager.chapter):
		if EnemyConfig.TYPES.has(String(m)):
			pool.append(String(m))
	if pool.is_empty():
		return "hound"
	return String(pool[randi() % pool.size()])

func _rarity_index(name: String) -> int:
	if name == "":
		return -1
	var order := ["F", "E", "D", "C", "B", "A", "S", "SS", "SSS"]
	return order.find(name.to_upper())

# ══════════════════════════════════════════════
#  버프 (축복 / 저주) — 날짜로 만료된다
# ══════════════════════════════════════════════
func _set_buff(kind: String, days: int) -> void:
	SaveGame.counters["buff_kind"] = 1 if kind == "blessing" else 2
	SaveGame.counters["buff_until"] = GameManager.day_count + maxi(1, days)

## "blessing" / "curse" / "" — 만료됐으면 빈 문자열
func active_buff() -> String:
	var until := int(SaveGame.counters.get("buff_until", 0))
	if GameManager.day_count > until:
		return ""
	match int(SaveGame.counters.get("buff_kind", 0)):
		1: return "blessing"
		2: return "curse"
	return ""

## 전투 배율 — PlayerStats 가 곱한다 (축복 +15% / 저주 −15%)
func buff_mult() -> float:
	match active_buff():
		"blessing": return 1.15
		"curse": return 0.85
	return 1.0

func clear_buff() -> void:
	SaveGame.counters.erase("buff_kind")
	SaveGame.counters.erase("buff_until")

func _announce(d: Dictionary) -> void:
	var world = get_tree().current_scene
	if world == null or world.get("hud") == null:
		return
	world.hud.show_banner(String(d.get("banner", String(d.get("name", "")))))
	var col := Color(String(d.get("color", "#ffffff")))
	world.hud.show_toast(String(d.get("desc", "")), col)
	SoundManager.play("night_start", -10.0)
