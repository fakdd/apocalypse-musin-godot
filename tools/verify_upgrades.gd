extends Node
## 업그레이드 검증 — 오토로드/씬이 필요하므로 게임과 함께 돈다.
##   godot --quit-after 300 -- --upgtest

var _f := 0

func _ready() -> void:
	var want := false
	for a in OS.get_cmdline_user_args():
		if String(a) == "--upgtest":
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
	print("UP| ══ 업그레이드 검증 ══")
	SaveGame.wipe()
	UpgradeManager.reset()

	# ── 1) 정의 ──
	var n := UpgradeManager.ids().size()
	print("UP|  정의 %d개 · 카테고리 %d개" % [n, UpgradeManager.categories.size()])
	if n == 0:
		print("UP|  ✘ 강화 정의를 읽지 못했다")
		return
	for id in UpgradeManager.ids():
		var d: Dictionary = UpgradeManager.defs[id]
		if UpgradeManager.max_level(id) <= 0:
			print("UP|  ✘ %s: max_level 이 0" % id); bad += 1
		if String(d.get("name", "")) == "":
			print("UP|  ✘ %s: 이름 없음" % id); bad += 1
		# 수식이 실제로 평가되는가 (파싱 실패면 0 이 나온다)
		if UpgradeManager.next_cost(id) <= 0:
			print("UP|  ✘ %s: cost_formula 가 0 이하" % id); bad += 1

	# ── 2) 비용 계산이 단계마다 오르는가 ──
	var probe := "attack"
	CraftManager.essence = 999999
	var costs := []
	for i in range(3):
		costs.append(UpgradeManager.next_cost(probe))
		UpgradeManager.purchase(probe)
	if costs[0] < costs[1] and costs[1] < costs[2]:
		print("UP|  ✔ 비용이 단계마다 증가 %s" % str(costs))
	else:
		print("UP|  ✘ 비용이 증가하지 않는다 %s" % str(costs)); bad += 1

	# ── 3) 능력치가 실제로 적용되는가 ──
	SaveGame.upgrades.clear()
	UpgradeManager.reset()
	var atk0 := PlayerStats.get_final_atk()
	var hp0 := PlayerStats.get_final_max_hp()
	var spd0 := PlayerStats.get_final_speed()
	CraftManager.essence = 999999
	UpgradeManager.purchase("attack")
	UpgradeManager.purchase("hp")
	UpgradeManager.purchase("move_speed")
	var atk1 := PlayerStats.get_final_atk()
	var hp1 := PlayerStats.get_final_max_hp()
	var spd1 := PlayerStats.get_final_speed()
	if atk1 > atk0 and hp1 > hp0 and spd1 > spd0:
		print("UP|  ✔ 능력치 반영 — 공격 %.1f→%.1f · HP %.0f→%.0f · 속도 %.2f→%.2f"
			% [atk0, atk1, hp0, hp1, spd0, spd1])
	else:
		print("UP|  ✘ 능력치가 반영되지 않는다 (공격 %.1f→%.1f HP %.0f→%.0f 속도 %.2f→%.2f)"
			% [atk0, atk1, hp0, hp1, spd0, spd1]); bad += 1

	# ── 4) 마석이 실제로 빠지는가 / 부족하면 못 사는가 ──
	CraftManager.essence = 0
	var lv_before := UpgradeManager.level("attack")
	if UpgradeManager.purchase("attack"):
		print("UP|  ✘ 마석 0 인데 구매됐다"); bad += 1
	elif UpgradeManager.level("attack") != lv_before:
		print("UP|  ✘ 실패했는데 단계가 올랐다"); bad += 1
	else:
		print("UP|  ✔ 마석 부족 시 구매 거부")

	var cost := UpgradeManager.next_cost("attack")
	CraftManager.essence = cost
	UpgradeManager.purchase("attack")
	if CraftManager.essence != 0:
		print("UP|  ✘ 마석이 정확히 빠지지 않았다: %d 남음" % CraftManager.essence); bad += 1
	else:
		print("UP|  ✔ 마석 %d 차감 확인" % cost)

	# ── 5) 최대 레벨 ──
	var mx := UpgradeManager.max_level("healing")
	CraftManager.essence = 9999999
	for i in range(mx + 3):
		UpgradeManager.purchase("healing")
	if UpgradeManager.level("healing") != mx:
		print("UP|  ✘ 최대 레벨을 넘었다: %d / %d"
			% [UpgradeManager.level("healing"), mx]); bad += 1
	elif not UpgradeManager.is_maxed("healing"):
		print("UP|  ✘ is_maxed 가 false"); bad += 1
	elif UpgradeManager.next_cost("healing") != -1:
		print("UP|  ✘ 최대인데 비용이 -1 이 아니다"); bad += 1
	else:
		print("UP|  ✔ 최대 레벨 %d 에서 정지 · 추가 구매 거부" % mx)

	# ── 6) 해금 조건 ──
	SaveGame.upgrades.clear()
	UpgradeManager.reset()
	if UpgradeManager.is_unlocked("critical_damage"):
		print("UP|  ✘ 선행 조건이 없는데 해금돼 있다"); bad += 1
	else:
		CraftManager.essence = 999999
		if UpgradeManager.purchase("critical_damage"):
			print("UP|  ✘ 잠긴 강화가 구매됐다"); bad += 1
		UpgradeManager.purchase("critical_rate")
		if UpgradeManager.is_unlocked("critical_damage"):
			print("UP|  ✔ 해금 조건 동작 (치명타 확률 1단계 → 치명타 피해 해금)")
		else:
			print("UP|  ✘ 선행을 채웠는데 해금되지 않았다"); bad += 1

	# ── 7) 저장 왕복 ──
	CraftManager.essence = 999999
	UpgradeManager.purchase("drop_rate")
	UpgradeManager.purchase("drop_rate")
	var snapshot := {}
	for id in UpgradeManager.ids():
		snapshot[id] = UpgradeManager.level(id)
	SaveGame.save()
	SaveGame.upgrades.clear()
	UpgradeManager.reset()
	if not SaveGame.load_game():
		print("UP|  ✘ 불러오기 실패"); bad += 1
	else:
		var diff := []
		for id in snapshot:
			if UpgradeManager.level(id) != int(snapshot[id]):
				diff.append("%s %d≠%d" % [id, UpgradeManager.level(id), int(snapshot[id])])
		if diff.is_empty():
			print("UP|  ✔ 저장 왕복 후 모든 단계 유지 (drop_rate=%d)"
				% UpgradeManager.level("drop_rate"))
		else:
			print("UP|  ✘ 저장 왕복 불일치: %s" % str(diff)); bad += 1

	# ── 8) 챕터를 넘어도 유지되는가 (세이브가 남아 있어야 한다) ──
	var lv_drop := UpgradeManager.level("drop_rate")
	GameManager.advance_chapter()
	SaveGame.save()
	SaveGame.upgrades.clear()
	SaveGame.load_game()
	if UpgradeManager.level("drop_rate") != lv_drop:
		print("UP|  ✘ 챕터를 넘자 강화가 사라졌다"); bad += 1
	else:
		print("UP|  ✔ 챕터 이동 후에도 유지 (%d장, drop_rate=%d)"
			% [GameManager.chapter, lv_drop])

	# ── 9) 치명타 굴림이 확률대로 도는가 ──
	SaveGame.upgrades.clear()
	UpgradeManager.reset()
	var crits := 0
	for i in range(500):
		if UpgradeManager.roll_crit()[1]:
			crits += 1
	if crits != 0:
		print("UP|  ✘ 치명타 0%% 인데 %d회 터졌다" % crits); bad += 1
	else:
		CraftManager.essence = 999999
		for i in range(UpgradeManager.max_level("critical_rate")):
			UpgradeManager.purchase("critical_rate")
		crits = 0
		for i in range(1000):
			if UpgradeManager.roll_crit()[1]:
				crits += 1
		var rate := UpgradeManager.value("critical_rate")
		if crits > 0:
			print("UP|  ✔ 치명타 — 0%% 에서 0회, %.0f%% 에서 %d/1000회"
				% [rate * 100.0, crits])
		else:
			print("UP|  ✘ 치명타가 한 번도 안 터졌다 (기대 %.0f%%)" % (rate * 100.0)); bad += 1

	SaveGame.wipe()
	print("UP| " + ("✔ 전부 통과" if bad == 0 else "✘ 실패 %d건" % bad))
	print("UP| DONE")
