extends Node
class_name CampaignEvents
## 캠페인 이벤트 디스패처 — 트리거를 받아 동작을 실행한다.
##
## 캠페인 JSON 의 이벤트는 "언제(trigger) 무엇을(action) 어떤 값으로(value)" 만 담는다.
## **그것을 실제로 실행하는 방법은 게임이 안다.** 이 파일이 그 번역기다.
##
## 이렇게 나눈 이유:
##   JSON 에 GDScript 를 넣을 수는 없다. 그렇다고 이벤트마다 게임 코드를 고치면
##   데이터 주도가 아니게 된다. "동작 이름 → 게임 함수" 표를 여기 한 곳에 두면,
##   기획자는 표에 있는 동작을 조합만 하면 되고 코드는 건드리지 않는다.
##
## 새 동작을 추가하려면 `_run()` 에 분기 하나만 더하면 된다.

## 지원하는 동작 (Campaign Builder 의 EVENT_ACTIONS 와 일치해야 한다)
const ACTIONS := ["bgm", "banner", "stinger", "spawn", "unlock", "reward",
	"dialogue", "seal"]

var world: Node3D = null

## once 이벤트가 이미 실행되었는지 — "<node_id>|<trigger>|<action>" 키
var _fired := {}

func setup(p_world: Node3D) -> void:
	world = p_world

## 트리거 하나를 발생시킨다.
##   node: CampaignData.MapNode
##   trigger: "on_enter" / "on_clear" / …
func fire(node, trigger: String) -> void:
	if node == null:
		return
	for e in node.events_for(trigger):
		var key: String = "%s|%s|%s" % [node.area_id, trigger, e.action]
		if e.once and _fired.has(key):
			continue
		if not _conditions_met(e):
			continue
		_fired[key] = true
		_run(node, e)

## 캠페인 전역 이벤트 (시작/종료 등)
func fire_global(campaign, trigger: String) -> void:
	if campaign == null:
		return
	for e in campaign.global_events:
		if e.trigger != trigger:
			continue
		var key: String = "*|%s|%s" % [trigger, e.action]
		if e.once and _fired.has(key):
			continue
		if not _conditions_met(e):
			continue
		_fired[key] = true
		_run(null, e)

## ══════════════════════════════════════════════
##  조건 평가 — JSON 은 "무엇을" 만 말하고 판정은 게임이 한다
## ══════════════════════════════════════════════
##
## 조건이 비어 있으면 항상 실행된다. 여러 개면 **전부** 만족해야 한다.
## 새 조건을 추가하려면 여기에 분기 하나만 더하면 된다
## (Campaign Builder 의 CONDITION_KINDS 에도 같은 이름을 등록할 것).
func _conditions_met(e) -> bool:
	for c in e.conditions:
		if not _check_condition(c):
			return false
	return true

func _check_condition(c: Dictionary) -> bool:
	var kind := String(c.get("kind", ""))
	var value = c.get("value", "")
	match kind:
		"quest_completed":
			return LandmarkRegistry.is_quest_done(String(value))
		"quest_pending":
			return not LandmarkRegistry.is_quest_done(String(value))
		"stage_cleared":
			var data := LandmarkRegistry.get_data(String(value))
			return data != null and data.cleared
		"item_owned":
			# 장착 중이거나 인벤토리에 같은 스킨이 있으면 만족
			return _has_item(String(value))
		"level":
			# 실제 플레이어 레벨. 랜드마크의 추천 레벨과 같은 축이다.
			return GameManager.player_level >= int(value)
		"time":
			var want := String(value).to_lower()
			var is_night: bool = GameManager.phase == GameManager.Phase.NIGHT
			if want == "night":
				return is_night
			if want == "day":
				return not is_night
			return true
		_:
			push_warning("알 수 없는 이벤트 조건: %s" % kind)
			return true

func _has_item(skin_or_name: String) -> bool:
	for slot in PlayerStats.equipped:
		var it = PlayerStats.equipped[slot]
		if it != null and (it.skin == skin_or_name or it.name == skin_or_name):
			return true
	for it in PlayerStats.inventory:
		if it != null and (it.skin == skin_or_name or it.name == skin_or_name):
			return true
	return false

## ══════════════════════════════════════════════
##  동작 실행 — 새 동작은 여기에 분기를 더한다
## ══════════════════════════════════════════════
func _run(node, e) -> void:
	match e.action:
		"bgm":
			var track: String = e.value_str("track")
			if track != "":
				SoundManager.set_bgm(track)

		"stinger":
			var snd: String = e.value_str("sound")
			if snd != "":
				SoundManager.play(snd, -8.0)

		"banner":
			var text: String = e.value_str("text")
			if text != "" and world and world.hud:
				world.hud.show_banner(text)

		"dialogue":
			var line: String = e.value_str("text")
			if line != "" and world and world.hud:
				world.hud.show_toast(line, Color(0.85, 0.9, 1.0))

		"spawn":
			_do_spawn(node, e)

		"unlock":
			var target: String = e.value_str("target")
			if target != "":
				LandmarkRegistry.unlock(target)
				if world and world.hud:
					var data: LandmarkData = LandmarkRegistry.get_data(target)
					var label: String = data.display_name if data else target
					world.hud.show_toast("%s 해금" % label, Color(0.6, 0.95, 0.75))

		"reward":
			var essence: int = e.value_int("essence", 0)
			if essence > 0:
				CraftManager.add_essence(essence)
			var rarity: String = e.value_str("rarity")
			if rarity != "" and node != null:
				var idx: int = _rarity_index(rarity)
				if idx >= 0:
					LootManager.spawn_drop(node.world_pos() + Vector3(0, 0, 1.5),
						1.0, idx)

		"seal":
			GameManager.add_seal()
			if world and world.hud:
				# 데모 모드는 목표 봉인 수가 다르다 — 상수를 직접 쓰면 "1 / 5" 로 잘못 뜬다
				world.hud.show_banner("차원문 봉인  %d / %d"
					% [GameManager.seals_done, DemoDirector.seals_needed()])

		_:
			push_warning("알 수 없는 캠페인 동작: %s" % e.action)

func _do_spawn(node, e) -> void:
	if node == null or world == null or not world.has_method("_make_enemy"):
		return
	var etype: String = e.value_str("type")
	if etype == "":
		return
	var count: int = maxi(1, e.value_int("count", 1))
	for i in range(count):
		var a := TAU * float(i) / float(count) + randf_range(-0.3, 0.3)
		var r: float = node.radius * randf_range(0.4, 0.9)
		var pos: Vector3 = node.world_pos() + Vector3(cos(a) * r, 0, sin(a) * r)
		var enemy = world._make_enemy(etype, pos)
		if enemy != null:
			enemy.landmark_id = node.area_id

func _rarity_index(name: String) -> int:
	var order := ["F", "E", "D", "C", "B", "A", "S", "SS", "SSS"]
	return order.find(name.to_upper())

## 씬 재시작 시 — 1회 이벤트를 다시 쓸 수 있게 한다
func reset() -> void:
	_fired.clear()
