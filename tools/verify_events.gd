extends Node
## 랜덤 이벤트 검증.
##   godot --quit-after 300 -- --evtest

var _f := 0

func _ready() -> void:
	var want := false
	for a in OS.get_cmdline_user_args():
		if String(a) == "--evtest":
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
	print("EV| ══ 랜덤 이벤트 검증 ══")
	SaveGame.wipe()

	# ── 1) 정의 ──
	var n := EventManager.defs.size()
	print("EV|  정의 %d개" % n)
	if n == 0:
		print("EV|  ✘ 이벤트 정의를 읽지 못했다")
		return
	var seen := {}
	for id in EventManager.defs:
		var d: Dictionary = EventManager.defs[id]
		if seen.has(id):
			print("EV|  ✘ id 중복: %s" % id); bad += 1
		seen[id] = true
		if float(d.get("weight", 0)) <= 0.0:
			print("EV|  ✘ %s: weight 가 0 이하" % id); bad += 1
		if String(d.get("kind", "")) == "":
			print("EV|  ✘ %s: kind 없음" % id); bad += 1
		if String(d.get("banner", "")) == "":
			print("EV|  ✘ %s: banner 없음" % id); bad += 1

	# ── 2) 챕터 필터 ──
	var per := {}
	for ch in range(ChapterConfig.FIRST, ChapterConfig.LAST + 1):
		GameManager.chapter = ch
		per[ch] = EventManager.candidates().size()
	GameManager.chapter = 1
	print("EV|  챕터별 후보 %s" % str(per))
	for ch in per:
		if int(per[ch]) == 0:
			print("EV|  ✘ %d장에 후보가 하나도 없다" % ch); bad += 1
	# 챕터 전용 이벤트가 다른 챕터에 새지 않는가
	GameManager.chapter = 5
	for d in EventManager.candidates():
		var chs: Array = d.get("chapters", [])
		if not chs.is_empty() and not chs.has(5):
			print("EV|  ✘ 5장에 %s 가 샜다" % String(d.get("id", ""))); bad += 1
	GameManager.chapter = 1

	# ── 3) 추첨이 정의 안에서만 나오는가 ──
	var counts := {}
	for i in range(400):
		var id := EventManager.emit_event(_random_id())
		if id == "":
			continue
		counts[id] = int(counts.get(id, 0)) + 1
	var stray := []
	for id in counts:
		if not EventManager.defs.has(id):
			stray.append(id)
	if stray.is_empty():
		print("EV|  ✔ 발생한 이벤트가 전부 정의 안에 있다 (%d종)" % counts.size())
	else:
		print("EV|  ✘ 정의에 없는 이벤트 발생: %s" % str(stray)); bad += 1

	# ── 4) 가중치대로 분포하는가 ──
	SaveGame.wipe()
	var rolls := {}
	var fired := 0
	for i in range(600):
		var id := EventManager.roll_daily()
		if id != "":
			fired += 1
			rolls[id] = int(rolls.get(id, 0)) + 1
	var rate := float(fired) / 600.0
	if absf(rate - 0.65) > 0.09:
		print("EV|  ✘ 발생률이 설정(0.65)과 다르다: %.2f" % rate); bad += 1
	else:
		print("EV|  ✔ 발생률 %.2f (설정 0.65)" % rate)
	# 가중치가 큰 것이 작은 것보다 많이 나와야 한다
	var hi := int(rolls.get("ev_merchant", 0))     ## weight 14
	var lo := int(rolls.get("ev_curse", 0))        ## weight 6
	if hi > lo:
		print("EV|  ✔ 가중치 반영 — 상인(14) %d회 > 저주(6) %d회" % [hi, lo])
	else:
		print("EV|  ✘ 가중치가 반영되지 않는다 — 상인 %d회, 저주 %d회" % [hi, lo]); bad += 1

	# ── 5) 효과가 실제로 적용되는가 ──
	SaveGame.wipe()
	CraftManager.essence = 0
	EventManager.emit_event("ev_merchant")
	if CraftManager.essence <= 0:
		print("EV|  ✘ 상인 이벤트가 마석을 주지 않았다"); bad += 1
	else:
		print("EV|  ✔ 효과 적용 — 상인 마석 +%d" % CraftManager.essence)

	var sv0 := GameManager.survivors_rescued
	EventManager.emit_event("ev_rescue")
	if GameManager.survivors_rescued <= sv0:
		print("EV|  ✘ 구조 이벤트가 생존자를 늘리지 않았다"); bad += 1
	else:
		print("EV|  ✔ 효과 적용 — 생존자 %d→%d" % [sv0, GameManager.survivors_rescued])

	# ── 6) 버프 — 적용·전투 반영·만료 ──
	SaveGame.wipe()
	GameManager.day_count = 5
	var base_atk := PlayerStats.get_final_atk()
	EventManager.emit_event("ev_blessing")
	if EventManager.active_buff() != "blessing":
		print("EV|  ✘ 축복이 적용되지 않았다"); bad += 1
	elif PlayerStats.get_final_atk() <= base_atk:
		print("EV|  ✘ 축복이 전투에 반영되지 않았다"); bad += 1
	else:
		print("EV|  ✔ 축복 — 공격 %.1f→%.1f" % [base_atk, PlayerStats.get_final_atk()])

	GameManager.day_count = 99          ## 날짜가 지나면 만료
	if EventManager.active_buff() != "":
		print("EV|  ✘ 버프가 만료되지 않았다"); bad += 1
	elif absf(PlayerStats.get_final_atk() - base_atk) > 0.01:
		print("EV|  ✘ 만료 후에도 배율이 남아 있다"); bad += 1
	else:
		print("EV|  ✔ 버프 만료 — 공격이 %.1f 로 복귀" % PlayerStats.get_final_atk())

	GameManager.day_count = 5
	EventManager.emit_event("ev_curse")
	if PlayerStats.get_final_atk() >= base_atk:
		print("EV|  ✘ 저주가 반영되지 않았다"); bad += 1
	else:
		print("EV|  ✔ 저주 — 공격 %.1f (기준 %.1f)"
			% [PlayerStats.get_final_atk(), base_atk])

	# ── 7) 저장 왕복 ──
	var kind := EventManager.active_buff()
	var cnt := SaveGame.counter("event")
	SaveGame.save()
	SaveGame.counters.clear()
	if not SaveGame.load_game():
		print("EV|  ✘ 불러오기 실패"); bad += 1
	elif EventManager.active_buff() != kind:
		print("EV|  ✘ 버프가 저장되지 않았다: %s ≠ %s"
			% [EventManager.active_buff(), kind]); bad += 1
	elif SaveGame.counter("event") != cnt:
		print("EV|  ✘ 이벤트 횟수가 유지되지 않았다"); bad += 1
	else:
		print("EV|  ✔ 저장 왕복 — 버프(%s)·발생 %d회 유지" % [kind, cnt])

	EventManager.clear_buff()
	SaveGame.wipe()
	print("EV| " + ("✔ 전부 통과" if bad == 0 else "✘ 실패 %d건" % bad))
	print("EV| DONE")

func _random_id() -> String:
	var keys: Array = EventManager.defs.keys()
	return String(keys[randi() % keys.size()])
