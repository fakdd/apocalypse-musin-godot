extends SceneTree
## 7개 챕터 캠페인을 전부 실제 파서로 열어 본다.
##   godot --headless --script tools/verify_campaigns.gd --quit-after 2
##
## 보는 것:
##   1) 파일이 있고 열리는가
##   2) 노드/영역/보스/NPC/상자 수
##   3) 잠금 사슬이 끊기지 않는가 (끊기면 그 챕터는 진행 불가)
##   4) 챕터 보스가 실제로 배치돼 있는가 (없으면 포탈이 안 열린다)
##   5) 웨이브 대기 0 (게임이 건너뛴다)

const P := "CP| "

func _init() -> void:
	var bad := 0
	for n in range(ChapterConfig.FIRST, ChapterConfig.LAST + 1):
		bad += _check(n)
	print(P + ("✔ 전 챕터 이상 없음" if bad == 0 else "✘ 문제 %d건" % bad))
	print(P + "DONE")
	quit(0 if bad == 0 else 1)

func _check(n: int) -> int:
	var cid: String = ChapterConfig.campaign_of(n)
	var camp = CampaignData.load_campaign(cid)
	if camp == null:
		print(P + "✘ %d장 '%s' 캠페인을 열지 못함" % [n, cid])
		return 1

	var areas: Array = camp.all_areas()
	var npcs := 0
	var items := 0
	var quests := {}
	var bosses := []
	var skip := []

	for a in areas:
		npcs += a.npcs.size()
		items += maxi(0, a.item_count)
		if a.quest != null:
			quests[a.quest.id] = true
		for i in range(a.waves.size()):
			var w = a.waves[i]
			if String(w.boss) != "":
				bosses.append(String(w.boss))
			if i > 0 and float(w.delay) <= 0.0:
				skip.append("%s w%d" % [a.area_id, i + 1])

	var chapter_boss: String = ChapterConfig.boss_of(n)
	var has_boss: bool = bosses.has(chapter_boss)

	print(P + "%d장 %-10s 노드%2d 영역%2d · NPC%2d · 상자%3d · 보스%s"
		% [n, ChapterConfig.name_of(n), camp.nodes.size(), areas.size(),
		npcs, items, str(bosses)])

	var bad := 0
	if not has_boss:
		print(P + "   ✘ 챕터 보스 '%s' 가 배치되지 않았다 — 포탈이 안 열린다" % chapter_boss)
		bad += 1

	# 잠금이 가리키는 퀘스트가 실제로 있는가
	var broken := []
	for a in areas:
		if a.locked_until != "" and not quests.has(a.locked_until):
			broken.append("%s←%s" % [a.area_id, a.locked_until])
	for site in camp.nodes:
		if site.locked_until != "" and not quests.has(site.locked_until):
			broken.append("%s←%s" % [site.id, site.locked_until])
	if not broken.is_empty():
		print(P + "   ✘ 열 수 없는 잠금: " + str(broken))
		bad += 1

	if not skip.is_empty():
		print(P + "   ✘ 건너뛰는 웨이브: " + str(skip))
		bad += 1

	# 시작 지점이 잠겨 있으면 아무것도 못 한다
	var start = camp.start_node()
	if start == null:
		print(P + "   ✘ 시작 노드가 없다")
		bad += 1
	elif start.locked_until != "":
		print(P + "   ✘ 시작 노드 '%s' 가 잠겨 있다" % start.id)
		bad += 1

	return bad
