extends Node
## 업적 검증 — 오토로드/씬이 필요하므로 게임과 함께 돈다.
##   godot --quit-after 300 -- --achtest
##
## 보는 것:
##   1) JSON 정의가 전부 읽혔는가 (id 중복·빈 필드 없음)
##   2) 캠페인이 참조하는 업적 id 가 정의에 있는가 (없으면 이름 없이 뜬다)
##   3) counter 업적이 target 에서 정확히 달성되는가 (하나 모자라면 안 달성)
##   4) event 업적이 unlock 으로 달성되는가
##   5) 저장 → 초기화 → 불러오기 후에도 유지되는가
##   6) 진행률(earned/total)과 목록이 맞는가

var _f := 0

func _ready() -> void:
	var want := false
	for a in OS.get_cmdline_user_args():
		if String(a) == "--achtest":
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
	_run()
	get_tree().quit()

func _run() -> void:
	var bad := 0
	print("AC| ══ 업적 검증 ══")

	# ── 1) 정의 ──
	var n := AchievementManager.total()
	print("AC|  정의 %d개" % n)
	if n == 0:
		print("AC|  ✘ 업적 정의를 읽지 못했다")
		return

	var seen := {}
	for a in AchievementManager.listing():
		var id: String = a["id"]
		if seen.has(id):
			print("AC|  ✘ id 중복: %s" % id)
			bad += 1
		seen[id] = true
		if String(a["name"]).strip_edges() == "":
			print("AC|  ✘ 이름 없음: %s" % id)
			bad += 1

	# ── 2) 캠페인이 참조하는 업적이 정의에 있는가 ──
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
				missing.append(aid)
	if missing.is_empty():
		print("AC|  ✔ 캠페인이 쓰는 업적 id 가 전부 정의돼 있다")
	else:
		print("AC|  ✘ 정의에 없는 업적 참조: %s" % str(missing))
		bad += 1

	# ── 3) counter 업적 경계 ──
	SaveGame.wipe()
	bad += _counter_boundary("boss", "ach_first_boss", 1)
	bad += _counter_boundary("chest", "ach_chest_25", 25)

	# ── 4) event 업적 ──
	AchievementManager.unlock("ach_level_10")
	if not SaveGame.has_achievement("ach_level_10"):
		print("AC|  ✘ event 업적이 달성되지 않는다")
		bad += 1
	else:
		print("AC|  ✔ event 업적 달성")

	# ── 5) 저장 왕복 ──
	var before := AchievementManager.earned()
	SaveGame.save()
	SaveGame.achievements.clear()
	SaveGame.counters.clear()
	if not SaveGame.load_game():
		print("AC|  ✘ 불러오기 실패")
		bad += 1
	else:
		var after := AchievementManager.earned()
		if before != after:
			print("AC|  ✘ 저장 왕복 후 업적 수가 다르다: %d → %d" % [before, after])
			bad += 1
		elif SaveGame.counter("chest") != 25:
			print("AC|  ✘ 카운터가 유지되지 않았다: chest=%d" % SaveGame.counter("chest"))
			bad += 1
		else:
			print("AC|  ✔ 저장 왕복 후 업적 %d개·카운터 유지" % after)

	# ── 6) 진행률 ──
	var got := AchievementManager.earned()
	var listed := 0
	for a in AchievementManager.listing():
		if a["done"]:
			listed += 1
	if got != listed:
		print("AC|  ✘ 진행률 불일치: earned=%d 목록=%d" % [got, listed])
		bad += 1
	else:
		print("AC|  ✔ 진행률 일치 (%d / %d)" % [got, AchievementManager.total()])

	SaveGame.wipe()
	print("AC| " + ("✔ 전부 통과" if bad == 0 else "✘ 실패 %d건" % bad))
	print("AC| DONE")

## target 바로 아래에서는 안 되고, target 에서 되어야 한다
func _counter_boundary(counter_key: String, ach_id: String, target: int) -> int:
	if not AchievementManager.defs.has(ach_id):
		print("AC|  ✘ 검증 대상 업적이 없다: %s" % ach_id)
		return 1
	SaveGame.counters[counter_key] = 0
	SaveGame.achievements.erase(ach_id)

	if target > 1:
		AchievementManager.bump(counter_key, target - 1)
		if SaveGame.has_achievement(ach_id):
			print("AC|  ✘ %s: %d 에서 미리 달성됐다" % [ach_id, target - 1])
			return 1
	AchievementManager.bump(counter_key, 1)
	if not SaveGame.has_achievement(ach_id):
		print("AC|  ✘ %s: %d 에서 달성되지 않았다" % [ach_id, target])
		return 1
	print("AC|  ✔ %s — %d 에서 정확히 달성 (그 전에는 안 됨)" % [ach_id, target])
	return 0
