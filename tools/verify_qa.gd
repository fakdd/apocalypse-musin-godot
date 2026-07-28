extends Node
## QA 회귀 — 시스템 간 충돌을 검사한다.
##   godot --quit-after 300 -- --qatest
##
## 여기 있는 항목은 전부 **실제로 재현된 결함**을 고정하기 위한 것이다.

var _f := 0

func _ready() -> void:
	var want := false
	for a in OS.get_cmdline_user_args():
		if String(a) == "--qatest":
			want = true
	if not want:
		queue_free()
		return
	# 타이틀 메뉴가 트리를 멈춰도 검증은 돌아야 한다
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func _process(_d: float) -> void:
	_f += 1
	if _f < 40:
		return
	set_process(false)
	await _run()
	get_tree().quit()

func _run() -> void:
	# await 를 쓰므로 코루틴이다
	var bad := 0
	print("QA| ══ 시스템 간 충돌 검사 ══")
	var world = get_tree().current_scene
	if world and world.get("hud") != null and world.hud.get("menu_ui") != null 			and world.hud.menu_ui.is_open():
		world.hud.menu_ui.close()
	get_tree().paused = false

	# ── 1) UI 동시 오픈 — 하나를 열면 나머지는 닫혀야 한다 ──
	var hud = world.hud
	hud.upgrade_ui.toggle()                     ## 제단 열기
	hud.achievement_ui.toggle_list()            ## 업적 열기
	if hud.upgrade_ui.is_open() and hud.achievement_ui.is_list_open():
		print("QA|  ✘ 제단과 업적 목록이 동시에 열린다"); bad += 1
	else:
		print("QA|  ✔ UI 배타 — 제단/업적이 동시에 열리지 않는다")
	if hud.achievement_ui.is_list_open():
		hud.achievement_ui.toggle_list()
	if hud.upgrade_ui.is_open():
		hud.upgrade_ui.toggle()

	hud.npc_ui.open("hunter_old")
	hud.upgrade_ui.toggle()
	if hud.npc_ui.is_open() and hud.upgrade_ui.is_open():
		print("QA|  ✘ 대화창과 제단이 동시에 열린다"); bad += 1
	else:
		print("QA|  ✔ UI 배타 — 대화창/제단이 동시에 열리지 않는다")
	hud.npc_ui.close()
	if hud.upgrade_ui.is_open():
		hud.upgrade_ui.toggle()

	# ── 1b) 제단 화면에 들어가고 나올 길이 있는가 ──
	# 만들어만 두고 아무도 열지 않으면 플레이 중에는 없는 화면이다.
	var altar = null
	for a in get_tree().get_nodes_in_group("altars"):
		altar = a
	if altar == null:
		print("QA|  ✘ 월드에 마도 제단이 없다"); bad += 1
	elif not altar.has_method("_unhandled_input"):
		print("QA|  ✘ 제단에 강화 화면을 여는 입력이 없다"); bad += 1
	else:
		print("QA|  ✔ 제단에 강화 화면 진입 경로가 있다")

	hud.upgrade_ui.toggle()
	if not hud.upgrade_ui.is_open():
		print("QA|  ✘ 제단 화면이 열리지 않는다"); bad += 1
	elif not hud.upgrade_ui.handle_key(KEY_ESCAPE) or hud.upgrade_ui.is_open():
		print("QA|  ✘ 제단 화면을 닫는 키가 없다 (갇힌다)"); bad += 1
	else:
		print("QA|  ✔ 제단 화면 ESC/G 로 닫힌다")
	if hud.upgrade_ui.is_open():
		hud.upgrade_ui.toggle()

	# ── 1c) 창이 열려 있으면 폴링 입력이 막히는가 ──
	# E = 대화·줍기·기공파, F = 제단 재주사·반로환동 이 겹친다.
	if hud.windows_open():
		print("QA|  ✘ 아무 창도 안 열었는데 열려 있다고 한다"); bad += 1
	else:
		hud.npc_ui.open("hunter_old")
		if not hud.windows_open():
			print("QA|  ✘ 대화창이 떴는데 월드 입력이 안 막힌다"); bad += 1
		else:
			print("QA|  ✔ 창이 열리면 스킬·줍기 입력이 막힌다")
		hud.npc_ui.close()

	# ── 1d) 보스를 잡고 포탈에 들어가기 전에 저장·종료하면 ──
	# chapter_boss_down 은 저장되고 보스 랜드마크도 클리어로 저장된다.
	# 다시 켜면 보스가 다시 안 나오므로 mark_chapter_boss_defeated 도 안 불린다.
	# 씬 구성 때 포탈을 다시 열어주지 않으면 그 챕터에서 영영 못 나간다.
	for old_p in get_tree().get_nodes_in_group("chapter_portals"):
		old_p.queue_free()
	await get_tree().process_frame
	GameManager.chapter_boss_down = true
	world.portal_manager.build_rifts()
	await get_tree().process_frame
	if get_tree().get_nodes_in_group("chapter_portals").is_empty():
		print("QA|  ✘ 보스 처치 후 재시작하면 포탈이 안 열린다 (챕터 진행 불가)"); bad += 1
	else:
		print("QA|  ✔ 보스 처치 상태로 재시작해도 포탈이 열린다")
	GameManager.chapter_boss_down = false

	# ── 1e) 창을 연 채로 죽으면 결과 화면이 가려진다 ──
	hud.npc_ui.open("hunter_old")
	hud.popup_ui.show_game_over("base")
	if hud.npc_ui.is_open():
		print("QA|  ✘ 게임오버 화면이 대화창에 가린다"); bad += 1
	else:
		print("QA|  ✔ 게임오버 시 열린 창이 닫힌다")
	hud.game_over_panel.visible = false

	# ── 2) 호감도가 즉시 저장되는가 ──
	SaveGame.wipe()
	NPCManager.add_affinity("hunter_old", 3)
	if not SaveGame.exists():
		print("QA|  ✘ 호감도가 올랐는데 세이브 파일이 없다 (저장 누락)"); bad += 1
	else:
		SaveGame.affinity.clear()
		SaveGame.load_game()
		if NPCManager.affinity("hunter_old") != 3:
			print("QA|  ✘ 호감도가 저장되지 않았다: %d"
				% NPCManager.affinity("hunter_old")); bad += 1
		else:
			print("QA|  ✔ 호감도 즉시 저장")

	# ── 3) 씬 재로드 시 오토로드 시그널 중복 연결 ──
	# HUD/UI 는 씬과 함께 사라지지만, 연결이 남으면 콜백이 두 번 불린다.
	var dup := []
	for pair in [
			[LandmarkRegistry, "landmark_entered"],
			[LandmarkRegistry, "landmark_cleared"],
			[LandmarkRegistry, "explore_reward"],
			[LandmarkRegistry, "landmark_explored"],
			[AchievementManager, "unlocked"],
			[UpgradeManager, "changed"],
			[CraftManager, "essence_changed"],
			[GameManager, "phase_changed"]]:
		var obj = pair[0]
		var sig := String(pair[1])
		var alive := 0
		for c in obj.get_signal_connection_list(sig):
			if is_instance_valid(c["callable"].get_object()):
				alive += 1
			else:
				dup.append("%s.%s → 죽은 객체" % [obj.name, sig])
		# 같은 시그널에 같은 메서드가 두 번 붙었는지
		var seen := {}
		for c in obj.get_signal_connection_list(sig):
			var key := "%s::%s" % [str(c["callable"].get_object()), c["callable"].get_method()]
			if seen.has(key):
				dup.append("%s.%s ← %s 중복" % [obj.name, sig, c["callable"].get_method()])
			seen[key] = true
	if dup.is_empty():
		print("QA|  ✔ 오토로드 시그널 — 죽은 연결·중복 없음")
	else:
		for d in dup:
			print("QA|  ✘ %s" % d)
		bad += 1

	# ── 4) 퍼즐/이벤트/NPC 가 참조하는 업적 id 가 전부 정의돼 있는가 ──
	var missing := []
	for ch in range(ChapterConfig.FIRST, ChapterConfig.LAST + 1):
		var camp = CampaignData.load_campaign(ChapterConfig.campaign_of(ch))
		if camp == null:
			continue
		for area in camp.all_areas():
			if area.puzzle.is_empty():
				continue
			var aid := String(area.puzzle.get("achievement", ""))
			if aid != "" and not AchievementManager.defs.has(aid):
				missing.append("puzzle:" + aid)
	for nid in NPCManager.ids():
		var d: Dictionary = NPCManager.defs[nid]
		for c in d.get("choices", []):
			var a := String(c.get("achievement", ""))
			if a != "" and not AchievementManager.defs.has(a):
				missing.append("npc:" + a)
		for q in d.get("quests", []):
			var a2 := String(q.get("reward", {}).get("achievement", ""))
			if a2 != "" and not AchievementManager.defs.has(a2):
				missing.append("quest:" + a2)
	if missing.is_empty():
		print("QA|  ✔ 참조되는 업적 id 가 전부 정의돼 있다")
	else:
		print("QA|  ✘ 정의에 없는 업적 참조: %s" % str(missing)); bad += 1

	# ── 5) NPC 퀘스트 목표 카운터가 실제로 올라가는 키인가 ──
	var bumped := {}
	for nid in NPCManager.ids():
		for q in NPCManager.quests_of(nid):
			var goal = q.get("goal", {})
			if String(goal.get("kind", "")) != "counter":
				continue
			bumped[String(goal.get("key", ""))] = String(q.get("id", ""))
	var never := []
	for key in bumped:
		# kill_* 은 Enemy3D 가, 나머지는 AchievementManager 가 올린다
		if key.begins_with("kill_"):
			var t: String = key.substr(5)
			if not EnemyConfig.TYPES.has(t):
				never.append("%s (몬스터 '%s' 가 없음 → %s 영구 미완료)"
					% [key, t, bumped[key]])
		elif not SaveGame.counters.has(key) and key not in \
				["boss", "chapter", "chest", "clear", "explore", "puzzle",
				"secret", "event", "npc_talk", "npc_quest", "npc_shop"]:
			never.append("%s (아무도 올리지 않음 → %s 영구 미완료)" % [key, bumped[key]])
	if never.is_empty():
		print("QA|  ✔ NPC 퀘스트 목표 카운터가 전부 실제로 증가하는 키다")
	else:
		for x in never:
			print("QA|  ✘ %s" % x)
		bad += 1

	# ── 6) 씬 전환 후 남는 노드 — 챕터 이동은 씬을 다시 읽는다 ──
	var before := world.get_child_count()
	if before <= 0:
		print("QA|  ✘ 월드에 자식이 없다"); bad += 1
	else:
		print("QA|  ✔ 월드 노드 %d개 (씬 재로드 시 전부 해제된다)" % before)

	# ── 7) 저장 왕복에서 빠지는 상태가 없는가 ──
	SaveGame.wipe()
	CraftManager.essence = 777
	GameManager.chapter = 3
	NPCManager.add_affinity("merchant_sand", 4)
	NPCManager.accept_quest("hunter_old", "q_npc_wolves")
	UpgradeManager.purchase("hp")
	AchievementManager.bump("chest", 7)
	EventManager.emit_event("ev_blessing")
	SaveGame.save()

	var snap := {
		"essence": CraftManager.essence,
		"chapter": GameManager.chapter,
		"affinity": NPCManager.affinity("merchant_sand"),
		"quest": NPCManager.quest_state("hunter_old", "q_npc_wolves"),
		"hp_lv": UpgradeManager.level("hp"),
		"chest": SaveGame.counter("chest"),
		"buff": EventManager.active_buff(),
	}
	SaveGame.achievements.clear()
	SaveGame.upgrades.clear()
	SaveGame.affinity.clear()
	SaveGame.puzzles.clear()
	SaveGame.counters.clear()
	CraftManager.essence = 0
	GameManager.chapter = 1
	SaveGame.load_game()
	var lost := []
	if CraftManager.essence != int(snap["essence"]): lost.append("마석")
	if GameManager.chapter != int(snap["chapter"]): lost.append("챕터")
	if NPCManager.affinity("merchant_sand") != int(snap["affinity"]): lost.append("호감도")
	if NPCManager.quest_state("hunter_old", "q_npc_wolves") != int(snap["quest"]): lost.append("NPC퀘스트")
	if UpgradeManager.level("hp") != int(snap["hp_lv"]): lost.append("영구강화")
	if SaveGame.counter("chest") != int(snap["chest"]): lost.append("카운터")
	if EventManager.active_buff() != String(snap["buff"]): lost.append("버프")
	if lost.is_empty():
		print("QA|  ✔ 통합 저장 왕복 — 7개 시스템 상태 전부 유지")
	else:
		print("QA|  ✘ 저장에서 누락된 상태: %s" % str(lost)); bad += 1

	SaveGame.wipe()
	EventManager.clear_buff()
	# ── 8) 씬 재로드 누수 — 챕터 이동은 씬을 다시 읽는다 ──
	# 오토로드가 죽은 씬 노드를 붙들고 있으면 고아 노드가 계속 쌓인다.
	var orphan0 := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for i in range(2):
		get_tree().reload_current_scene()
		for _f in range(30):
			await get_tree().process_frame
	var orphan1 := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if orphan1 > orphan0 + 8:
		print("QA|  ✘ 씬 2회 재로드 후 고아 노드 %d → %d" % [orphan0, orphan1]); bad += 1
	else:
		print("QA|  ✔ 씬 2회 재로드 — 고아 노드 %d → %d" % [orphan0, orphan1])

	var vs: Dictionary = VfxPool.stats()
	if int(vs["damage_pooled"]) > 200 or int(vs["proj_pooled"]) > 200:
		print("QA|  ✘ VfxPool 이 재로드 후에도 비대: %s" % str(vs)); bad += 1
	else:
		print("QA|  ✔ VfxPool 재로드 후 정상 (%d/%d)"
			% [int(vs["damage_pooled"]), int(vs["proj_pooled"])])

	var dead2 := 0
	for pair2 in [[LandmarkRegistry, "landmark_cleared"], [AchievementManager, "unlocked"],
			[UpgradeManager, "changed"], [GameManager, "phase_changed"]]:
		for c in pair2[0].get_signal_connection_list(String(pair2[1])):
			if not is_instance_valid(c["callable"].get_object()):
				dead2 += 1
	if dead2 > 0:
		print("QA|  ✘ 재로드 후 죽은 시그널 연결 %d개" % dead2); bad += 1
	else:
		print("QA|  ✔ 재로드 후 죽은 시그널 연결 없음")

	print("QA| " + ("✔ 전부 통과" if bad == 0 else "✘ 문제 %d건" % bad))
	print("QA| DONE")
