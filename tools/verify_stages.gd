extends SceneTree
## 스키마 v2(구역) 검증 — headless 로 실제 파서를 돌린다.
##   godot --headless --script tools/verify_stages.gd --quit-after 2
##
## 보는 것:
##   1) v2 캠페인이 열리고 노드/구역 수가 맞는가
##   2) 세이브 키가 예전과 같은가 (첫 구역 = 랜드마크 id)
##   3) NPC state · 이벤트 conditions 가 살아 있는가
##   4) **v1 JSON 을 그대로 넣어도 열리는가** (마이그레이션 없이)
##   5) 구역 잠금이 순서대로 이어지는가

const P := "V2| "

func _init() -> void:
	var path := "res://data/campaigns/campaign_main.json"
	var camp = CampaignData.load_from_path(path)
	if camp == null:
		print(P + "✘ 캠페인을 열지 못했다: " + path)
		quit(1)
		return

	print(P + "══ 스키마 v%d ══ '%s' by %s (%s)"
		% [camp.schema_version, camp.display_name, camp.author, camp.modified])

	var areas: Array = camp.all_areas()
	print(P + " 노드 %d개 → 진입 영역 %d개 · 경로 %d개"
		% [camp.nodes.size(), areas.size(), camp.routes.size()])

	_dump_sites(camp)
	_check_save_keys(camp)
	_check_npc_and_events(camp)
	_check_lock_chain(camp)
	_check_v1_still_loads()
	_check_wave_delays(camp)

	print(P + "DONE")
	quit(0)

func _dump_sites(camp) -> void:
	for n in camp.nodes:
		var list: Array = n.areas()
		if list.size() <= 1:
			continue
		var ids := []
		for a in list:
			ids.append(a.area_id)
		print(P + " %-12s 구역%d  %s" % [n.id, list.size(), ", ".join(ids)])

## 예전 세이브 키가 그대로여야 한다 — 첫 구역은 랜드마크 id 를 쓴다.
func _check_save_keys(camp) -> void:
	var want := ["hospital", "hospital_ward", "hospital_morgue",
		"police", "police_armory", "school", "power", "rift_core"]
	var have := {}
	for a in camp.all_areas():
		have[a.area_id] = true
	var missing := []
	for k in want:
		if not have.has(k):
			missing.append(k)
	if missing.is_empty():
		print(P + " ✔ 세이브 키 호환 — 예전 키 %d개 전부 존재" % want.size())
	else:
		print(P + " ✘ 사라진 세이브 키: " + str(missing))

func _check_npc_and_events(camp) -> void:
	var npcs := 0
	var stateful := 0
	var conditional := 0
	for a in camp.all_areas():
		npcs += a.npcs.size()
		for npc in a.npcs:
			if npc.state != "" and npc.state != "idle":
				stateful += 1
		for e in a.events:
			if e.conditions.size() > 0:
				conditional += 1
	print(P + " NPC %d명 (state 지정 %d) · 조건부 이벤트 %d건"
		% [npcs, stateful, conditional])

	# 한 건을 실제로 펼쳐 본다
	var icu = camp.area_by_id("hospital_icu")
	if icu == null:
		print(P + " ✘ hospital_icu 를 찾지 못했다")
		return
	for npc in icu.npcs:
		print(P + "   NPC %s state=%s → \"%s\""
			% [npc.display_name, npc.state, npc.line_for(npc.state)])
	for e in icu.events:
		if e.conditions.size() > 0:
			print(P + "   EV %s → %s  조건=%s"
				% [e.trigger, e.action, str(e.conditions)])

## 구역 잠금이 앞 구역 퀘스트를 가리켜야 한다 (진행이 끊기면 안 된다)
func _check_lock_chain(camp) -> void:
	var quests := {}
	for a in camp.all_areas():
		if a.quest != null:
			quests[a.quest.id] = a.area_id
	var broken := []
	for a in camp.all_areas():
		if a.locked_until != "" and not quests.has(a.locked_until):
			broken.append("%s ← %s" % [a.area_id, a.locked_until])
	if broken.is_empty():
		print(P + " ✔ 잠금 사슬 정상 — 퀘스트 %d개가 모든 잠금을 연다" % quests.size())
	else:
		print(P + " ✘ 열 수 없는 잠금: " + str(broken))

## 대기 0 인 웨이브는 게임이 건너뛴다 — 데이터에 남아 있으면 안 된다.
func _check_wave_delays(camp) -> void:
	var bad := []
	for a in camp.all_areas():
		for i in range(a.waves.size()):
			if i > 0 and float(a.waves[i].delay) <= 0.0:
				bad.append("%s 웨이브%d" % [a.area_id, i + 1])
	if bad.is_empty():
		print(P + " ✔ 웨이브 대기 시간 정상")
	else:
		print(P + " ✘ 건너뛰는 웨이브: " + str(bad))

## v1 JSON(구역 없음)을 그대로 넣어도 열려야 한다 — 마이그레이션 불필요.
func _check_v1_still_loads() -> void:
	var v1 := {
		"schema_version": 1,
		"campaign": {"id": "legacy", "name": "예전 캠페인"},
		"start": "clinic",
		"nodes": [{
			"id": "clinic", "name": "보건소", "x": 30.0, "z": 20.0,
			"radius": 7.0, "danger": 1, "level": 2, "order": 0,
			"locked_until": "", "bgm": "", "story": "",
			"ambient": {"hound": 2},
			"waves": [{"index": 1, "composition": {"hound": 3},
				"delay": 0.0, "hp_mult": 1.0, "boss": "", "boss_hp_mult": 1.0}],
			"npcs": [{"id": "n1", "name": "간호사", "line": "조심해요"}],
			"events": [{"trigger": "on_enter", "action": "banner",
				"value": {"text": "보건소"}, "once": true}],
			"quest": {"id": "q_clinic", "title": "보건소 정리",
				"objective": "clear", "target": 1, "reward_essence": 20,
				"reward_rarity": "C"}
		}],
		"routes": []
	}
	var tmp := "user://_v1_probe.json"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(JSON.stringify(v1))
	f.close()

	var camp = CampaignData.load_from_path(tmp)
	if camp == null:
		print(P + " ✘ v1 JSON 을 열지 못했다 — 하위 호환이 깨졌다")
		return
	var areas: Array = camp.all_areas()
	if areas.size() != 1 or areas[0].area_id != "clinic":
		print(P + " ✘ v1 노드가 단일 구역으로 안 열린다: " + str(areas.size()))
		return
	var a = areas[0]
	print(P + " ✔ v1 JSON 그대로 열림 — 노드 1 → 영역 1 (%s), 웨이브 %d, NPC state=%s"
		% [a.area_id, a.waves.size(), a.npcs[0].state])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))

