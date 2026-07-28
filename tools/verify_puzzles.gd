extends Node
## 퍼즐 검증 — 오토로드/씬이 필요하므로 게임과 함께 돈다.
##   godot --quit-after 300 -- --chapter=1 --puzzletest
##
## 보는 것:
##   1) 캠페인 JSON 의 puzzle 이 로더까지 오는가
##   2) PuzzleSet 이 실제로 만들어지고 요소 개수가 맞는가
##   3) 순서 없는 퍼즐 — 전부 밟으면 풀리는가
##   4) 순서 퍼즐 — 틀린 순서는 리셋되고, 맞는 순서면 풀리는가
##   5) 풀면 SaveGame 에 남는가 (업적 포함)

var _f := 0

func _ready() -> void:
	var want := false
	for a in OS.get_cmdline_user_args():
		if String(a) == "--puzzletest":
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
	print("PZ| ══ 퍼즐 검증 (%d장) ══" % GameManager.chapter)

	# ── 1) 데이터가 로더까지 왔는가 ──
	var world = get_tree().current_scene
	var camp = world.campaign_manager.campaign
	var defined := []
	for a in camp.all_areas():
		if not a.puzzle.is_empty():
			defined.append("%s:%s(%s×%d)" % [a.area_id,
				String(a.puzzle.get("id", "?")), String(a.puzzle.get("kind", "?")),
				int(a.puzzle.get("count", 0))])
	print("PZ|  JSON 정의 %d개 %s" % [defined.size(), str(defined)])
	if defined.is_empty():
		print("PZ|  ✘ 이 챕터에 퍼즐이 하나도 없다")
		return

	# ── 2) 실제 노드가 만들어졌는가 ──
	var sets: Array = []
	for child in world.get_children():
		if child is LandmarkZone:
			for c2 in child.get_children():
				if c2 is PuzzleSet:
					sets.append(c2)
	print("PZ|  PuzzleSet 노드 %d개" % sets.size())
	if sets.size() != defined.size():
		print("PZ|  ✘ 정의 %d개인데 노드 %d개" % [defined.size(), sets.size()])
		bad += 1

	# ── 3~5) 하나씩 실제로 풀어 본다 ──
	for pz in sets:
		bad += _solve_one(pz)

	print("PZ| " + ("✔ 전부 통과" if bad == 0 else "✘ 실패 %d건" % bad))
	print("PZ| DONE")

func _solve_one(pz: PuzzleSet) -> int:
	var pid: String = String(pz.puzzle.get("id", ""))
	var kind: String = String(pz.puzzle.get("kind", ""))
	var order: Array = pz.puzzle.get("order", [])
	var n: int = pz._elements.size()
	var bad := 0

	if n != int(pz.puzzle.get("count", 0)):
		print("PZ|   ✘ %s: 요소 %d개 (정의 %d)" % [pid, n, int(pz.puzzle.get("count", 0))])
		bad += 1

	var player = Battlefield.live_player()
	if player == null:
		print("PZ|   ✘ 플레이어가 없어 밟기를 시험할 수 없다")
		return bad + 1

	if order.is_empty():
		# 전부 밟는다
		for i in range(n):
			pz._on_touch(player, i)
		if not pz._solved:
			print("PZ|   ✘ %s(%s): 전부 밟았는데 안 풀림" % [pid, kind])
			bad += 1
	else:
		# 먼저 **틀린 순서**로 밟아 리셋되는지 본다
		var wrong: int = int(order[1]) if order.size() > 1 else 0
		pz._on_touch(player, wrong)
		if pz._solved:
			print("PZ|   ✘ %s: 틀린 순서인데 풀렸다" % pid)
			bad += 1
		if pz._seq.size() > 0:
			print("PZ|   ✘ %s: 틀렸는데 진행이 남아 있다" % pid)
			bad += 1
		# 리셋 대기를 건너뛰고 정답 순서로
		pz._fail_timer = 0.0
		for step in order:
			pz._on_touch(player, int(step))
		if not pz._solved:
			print("PZ|   ✘ %s(%s): 정답 순서인데 안 풀림" % [pid, kind])
			bad += 1

	# 저장됐는가
	if not SaveGame.is_puzzle_solved(pid):
		print("PZ|   ✘ %s: SaveGame 에 기록되지 않음" % pid)
		bad += 1
	var ach: String = String(pz.puzzle.get("achievement", ""))
	if ach != "" and not SaveGame.has_achievement(ach):
		print("PZ|   ✘ %s: 업적 '%s' 이(가) 안 붙음" % [pid, ach])
		bad += 1

	if bad == 0:
		print("PZ|   ✔ %s (%s×%d%s) — 풀림·저장·업적 확인"
			% [pid, kind, n, " 순서" if not order.is_empty() else ""])
	return bad
