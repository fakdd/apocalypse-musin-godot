extends Node
## NPC 검증.
##   godot --quit-after 300 -- --npctest

var _f := 0

func _ready() -> void:
	var want := false
	for a in OS.get_cmdline_user_args():
		if String(a) == "--npctest":
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
	print("NP| ══ NPC 검증 ══")
	SaveGame.wipe()

	# ── 1) 정의 ──
	var n := NPCManager.ids().size()
	print("NP|  정의 %d명" % n)
	if n == 0:
		print("NP|  ✘ NPC 정의를 읽지 못했다")
		return
	for id in NPCManager.ids():
		var d: Dictionary = NPCManager.defs[id]
		if String(d.get("name", "")) == "":
			print("NP|  ✘ %s: 이름 없음" % id); bad += 1
		if d.get("dialog", []).is_empty():
			print("NP|  ✘ %s: 대사 없음" % id); bad += 1
		# 조건 없는 기본 대사가 하나는 있어야 한다 (없으면 빈 대사가 뜬다)
		var has_default := false
		for line in d.get("dialog", []):
			if line.get("conditions", []).is_empty():
				has_default = true
		if not has_default:
			print("NP|  ✘ %s: 조건 없는 기본 대사가 없다" % id); bad += 1
		if NPCManager.dialog_for(id) == "":
			print("NP|  ✘ %s: 지금 상태에서 대사가 비었다" % id); bad += 1

	# ── 2) 대화 분기 (호감도 조건) ──
	var probe := "hunter_old"
	var low := NPCManager.dialog_for(probe)
	SaveGame.affinity[probe] = 9
	var high := NPCManager.dialog_for(probe)
	if low == high:
		print("NP|  ✘ 호감도가 올라도 대사가 그대로다"); bad += 1
	else:
		print("NP|  ✔ 대화 분기 — 호감도 0/9 에서 대사가 다르다")
	SaveGame.affinity.clear()

	# ── 3) 선택지 → 호감도 상승 ──
	var a0 := NPCManager.affinity(probe)
	var reply := NPCManager.choose(probe, "ask")
	if reply == "":
		print("NP|  ✘ 선택지가 동작하지 않는다"); bad += 1
	elif NPCManager.affinity(probe) <= a0:
		print("NP|  ✘ 호감도가 오르지 않았다"); bad += 1
	else:
		print("NP|  ✔ 선택지 — 호감도 %d→%d, 답변 있음"
			% [a0, NPCManager.affinity(probe)])

	# ── 4) 퀘스트 수락 → 진행 → 완료 → 보상 ──
	if not NPCManager.accept_quest(probe, "q_npc_wolves"):
		print("NP|  ✘ 퀘스트를 수락하지 못했다"); bad += 1
	elif NPCManager.quest_state(probe, "q_npc_wolves") != NPCManager.QUEST_ACTIVE:
		print("NP|  ✘ 수락 후 상태가 진행 중이 아니다"); bad += 1
	else:
		if NPCManager.accept_quest(probe, "q_npc_wolves"):
			print("NP|  ✘ 같은 퀘스트를 두 번 수락했다"); bad += 1
		var p := NPCManager.quest_progress(probe, "q_npc_wolves")
		if NPCManager.quest_ready(probe, "q_npc_wolves"):
			print("NP|  ✘ 목표를 안 채웠는데 완료 가능이다"); bad += 1
		# 목표를 채운다
		AchievementManager.bump("kill_wolf", int(p[1]))
		if not NPCManager.quest_ready(probe, "q_npc_wolves"):
			print("NP|  ✘ 목표를 채웠는데 완료 불가다"); bad += 1
		var ess0 := CraftManager.essence
		var done := NPCManager.try_complete(probe)
		if done.is_empty():
			print("NP|  ✘ 완료 처리가 되지 않았다"); bad += 1
		elif NPCManager.quest_state(probe, "q_npc_wolves") != NPCManager.QUEST_DONE:
			print("NP|  ✘ 완료 후 상태가 갱신되지 않았다"); bad += 1
		elif CraftManager.essence <= ess0:
			print("NP|  ✘ 완료 보상이 지급되지 않았다"); bad += 1
		else:
			print("NP|  ✔ 퀘스트 — 수락→진행(%d/%d)→완료, 마석 %d→%d"
				% [int(p[1]), int(p[1]), ess0, CraftManager.essence])
		if not NPCManager.try_complete(probe).is_empty():
			print("NP|  ✘ 완료한 퀘스트가 다시 완료됐다"); bad += 1

	# ── 5) 상점 — 구매·차감·할인·조건 ──
	var shop_npc := "herb_wanderer"
	SaveGame.affinity.clear()
	var items := NPCManager.shop_for(shop_npc)
	var locked_visible := false
	for it in items:
		if String(it.get("id", "")) == "s_relic_a":
			locked_visible = true
	if locked_visible:
		print("NP|  ✘ 호감도 조건 상품이 미리 보인다"); bad += 1
	else:
		print("NP|  ✔ 상점 조건 — 잠긴 상품이 목록에 없다 (%d종 노출)" % items.size())

	CraftManager.essence = 0
	if NPCManager.buy(shop_npc, "s_essence_pack"):
		print("NP|  ✘ 마석 0 인데 구매됐다"); bad += 1
	else:
		print("NP|  ✔ 마석 부족 시 구매 거부")

	# 할인 없이 구매
	var base_price := 0
	for it in NPCManager.shop_for(shop_npc):
		if String(it.get("id", "")) == "s_heal":
			base_price = NPCManager.price_of(shop_npc, it)
	CraftManager.essence = base_price
	var p2 := Battlefield.live_player()
	if p2:
		p2.hp = 1.0
	if not NPCManager.buy(shop_npc, "s_heal"):
		print("NP|  ✘ 구매에 실패했다"); bad += 1
	elif CraftManager.essence != 0:
		print("NP|  ✘ 마석이 정확히 빠지지 않았다: %d" % CraftManager.essence); bad += 1
	elif p2 and p2.hp <= 1.0:
		print("NP|  ✘ 상점 효과(회복)가 적용되지 않았다"); bad += 1
	else:
		print("NP|  ✔ 상점 구매 — ◇%d 차감, 효과 적용(HP %.0f)"
			% [base_price, p2.hp if p2 else 0.0])

	# 할인
	SaveGame.affinity[shop_npc] = 5
	var disc_price := 0
	for it in NPCManager.shop_for(shop_npc):
		if String(it.get("id", "")) == "s_heal":
			disc_price = NPCManager.price_of(shop_npc, it)
	if disc_price >= base_price:
		print("NP|  ✘ 호감도 할인이 적용되지 않는다: %d → %d"
			% [base_price, disc_price]); bad += 1
	else:
		print("NP|  ✔ 호감도 할인 — ◇%d → ◇%d (%.0f%%)"
			% [base_price, disc_price, NPCManager.discount(shop_npc) * 100.0])
	# 호감도 5 면 잠겼던 상품이 열려야 한다
	var now_visible := false
	for it in NPCManager.shop_for(shop_npc):
		if String(it.get("id", "")) == "s_relic_a":
			now_visible = true
	if not now_visible:
		print("NP|  ✘ 호감도를 채웠는데 상품이 열리지 않는다"); bad += 1
	else:
		print("NP|  ✔ 호감도로 상품 해금")

	# ── 6) 비용이 있는 선택지 ──
	CraftManager.essence = 0
	if NPCManager.choose("lost_soul", "give") != "":
		print("NP|  ✘ 마석이 없는데 유료 선택지가 실행됐다"); bad += 1
	else:
		CraftManager.essence = 500
		if NPCManager.choose("lost_soul", "give") == "":
			print("NP|  ✘ 마석이 충분한데 실행되지 않았다"); bad += 1
		elif CraftManager.essence >= 500:
			print("NP|  ✘ 선택지 비용이 빠지지 않았다"); bad += 1
		else:
			print("NP|  ✔ 유료 선택지 — 비용 차감·업적 %s"
				% ("O" if SaveGame.has_achievement("ach_npc_soul") else "X"))

	# ── 7) 저장 왕복 ──
	var af := NPCManager.affinity(probe)
	var qs := NPCManager.quest_state(probe, "q_npc_wolves")
	SaveGame.save()
	SaveGame.affinity.clear()
	SaveGame.counters.clear()
	if not SaveGame.load_game():
		print("NP|  ✘ 불러오기 실패"); bad += 1
	elif NPCManager.affinity(probe) != af:
		print("NP|  ✘ 호감도가 유지되지 않았다: %d ≠ %d"
			% [NPCManager.affinity(probe), af]); bad += 1
	elif NPCManager.quest_state(probe, "q_npc_wolves") != qs:
		print("NP|  ✘ 퀘스트 상태가 유지되지 않았다"); bad += 1
	else:
		print("NP|  ✔ 저장 왕복 — 호감도 %d·퀘스트 상태 %d 유지" % [af, qs])

	SaveGame.wipe()
	print("NP| " + ("✔ 전부 통과" if bad == 0 else "✘ 실패 %d건" % bad))
	print("NP| DONE")
