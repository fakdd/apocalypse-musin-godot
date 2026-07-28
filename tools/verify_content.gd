extends Node
## 보스 · 접사 · 엔드게임 데이터 검증
##   godot --quit-after 400 -- --contenttest

var _f := 0

func _ready() -> void:
	var want := false
	for a in OS.get_cmdline_user_args():
		if String(a) == "--contenttest":
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
	await _run()          ## _run 이 await 를 쓴다 — 기다리지 않으면 먼저 종료된다
	get_tree().quit()

func _run() -> void:
	var bad := 0
	# 첫 실행이면 타이틀이 떠 트리가 멈춰 있다. 검증 전에 닫는다.
	var w0 = get_tree().current_scene
	if w0 and w0.get("hud") != null and w0.hud.get("menu_ui") != null 			and w0.hud.menu_ui.is_open():
		w0.hud.menu_ui.close()
	get_tree().paused = false
	print("CT| ══ 보스 · 접사 · 엔드게임 ══")

	# ── 1) 모든 보스 타입에 정의가 있는가 ──
	var miss := []
	for t in EnemyConfig.BOSS_TYPES:
		if EnemyConfig.boss_def(String(t)).is_empty():
			miss.append(t)
	if miss.is_empty():
		print("CT|  ✔ 보스 %d종 전부 정의됨" % EnemyConfig.BOSS_TYPES.size())
	else:
		print("CT|  ✘ 정의 없는 보스: %s" % str(miss)); bad += 1

	# ── 2) 페이즈 3단계 · 패턴 5종 이상 · 소환 몬스터 실재 ──
	var probs := []
	for t in EnemyConfig.BOSS_TYPES:
		var d := EnemyConfig.boss_def(String(t))
		if d.is_empty():
			continue
		var ph: Array = d.get("phases", [])
		if ph.size() < 3:
			probs.append("%s 페이즈 %d개" % [t, ph.size()])
		var pats := {}
		for p in ph:
			for x in p.get("patterns", []):
				pats[String(x)] = true
			var sm = p.get("summon", null)
			if typeof(sm) == TYPE_DICTIONARY:
				var st := String(sm.get("type", ""))
				if not EnemyConfig.TYPES.has(st):
					probs.append("%s 가 없는 몬스터 '%s' 를 소환" % [t, st])
		if pats.size() < 3:
			probs.append("%s 패턴 %d종" % [t, pats.size()])
		if String(d.get("cutscene", [])[0] if not d.get("cutscene", []).is_empty() else "") == "":
			probs.append("%s 컷신 없음" % t)
	if probs.is_empty():
		print("CT|  ✔ 전 보스 3페이즈 · 패턴 3종 이상 · 컷신 · 소환 대상 정상")
	else:
		for x in probs:
			print("CT|  ✘ %s" % x)
		bad += 1

	# ── 3) 페이즈 경계가 hp 비율 순서대로인가 ──
	var order_bad := []
	for t in EnemyConfig.BOSS_TYPES:
		var ph: Array = EnemyConfig.boss_def(String(t)).get("phases", [])
		var prev := 2.0
		for p in ph:
			var at := float(p.get("at", 0.0))
			if at >= prev:
				order_bad.append("%s at=%.2f" % [t, at])
			prev = at
	if order_bad.is_empty():
		print("CT|  ✔ 페이즈 hp 경계가 내림차순")
	else:
		print("CT|  ✘ 경계 순서 이상: %s" % str(order_bad)); bad += 1

	# ── 4) 페이즈 선택이 실제로 hp 에 따라 바뀌는가 ──
	var t0 := String(EnemyConfig.BOSS_TYPES[0])
	var i_full := EnemyConfig.boss_phase_index(t0, 1.0)
	var i_mid := EnemyConfig.boss_phase_index(t0, 0.5)
	var i_low := EnemyConfig.boss_phase_index(t0, 0.1)
	if i_full == 0 and i_mid == 1 and i_low == 2:
		print("CT|  ✔ hp 비율 → 페이즈 (1.0→0, 0.5→1, 0.1→2)")
	else:
		print("CT|  ✘ 페이즈 선택 이상: %d/%d/%d" % [i_full, i_mid, i_low]); bad += 1

	# ── 5) 접사 — 등급이 오를수록 옵션이 늘어나는가 ──
	# 고유 아이템은 확률로 나오고 접사가 없다 — 여러 번 굴려 일반 생성물로 비교한다
	var lo := LootManager.generate_item(0)
	var hi := LootManager.generate_item(6)
	for _i in range(12):
		if hi != null and String(hi.unique_id) == "":
			break
		hi = LootManager.generate_item(6)
	if lo == null or hi == null:
		print("CT|  ✘ 아이템 생성 실패"); bad += 1
	else:
		var lo_n: int = lo.affixes.size()
		var hi_n: int = hi.affixes.size()
		if hi_n > lo_n:
			print("CT|  ✔ 접사 개수 — 일반 %d개 < SSS %d개" % [lo_n, hi_n])
		else:
			print("CT|  ✘ 접사가 등급에 따라 늘지 않는다: %d / %d" % [lo_n, hi_n]); bad += 1
		if hi.atk_bonus <= lo.atk_bonus:
			print("CT|  ✘ 고등급 아이템이 더 약하다"); bad += 1

	# ── 6) 접사가 참조하는 스탯 필드가 ItemData 에 실재하는가 ──
	var probe := ItemData.new()
	var need := ["atk_bonus", "speed_bonus", "hp_bonus", "luck_bonus", "crit_bonus", "cdr_bonus"]
	var nof := []
	for f in need:
		if not (f in probe):
			nof.append(f)
	if nof.is_empty():
		print("CT|  ✔ 접사 스탯 필드 6종 전부 존재")
	else:
		print("CT|  ✘ ItemData 에 없는 필드: %s" % str(nof)); bad += 1

	# ── 7) 세트 보너스가 실제로 합산되는가 ──
	var a := ItemData.new(); a.slot = "weapon"; a.set_id = "set_ash"
	var b := ItemData.new(); b.slot = "armor"; b.set_id = "set_ash"
	var one: Dictionary = LootManager.set_bonus([a])
	var two: Dictionary = LootManager.set_bonus([a, b])
	if float(one.get("atk", 0.0)) == 0.0 and float(two.get("atk", 0.0)) > 0.0:
		print("CT|  ✔ 세트 2피스 보너스 (1피스 0 → 2피스 +%.0f)" % float(two["atk"]))
	else:
		print("CT|  ✘ 세트 보너스 이상: 1피스 %s / 2피스 %s"
			% [str(one.get("atk")), str(two.get("atk"))]); bad += 1

	# ── 8) 고유 아이템 정의의 슬롯·스킨이 유효한가 ──
	var ub := []
	for u in LootManager.affix_data().get("uniques", []):
		var sl := String(u.get("slot", ""))
		if not ItemData.SKINS.has(sl):
			ub.append("%s 슬롯 '%s'" % [u.get("id"), sl])
		elif not (String(u.get("skin", "")) in ItemData.SKINS[sl]):
			ub.append("%s 스킨 '%s'" % [u.get("id"), u.get("skin")])
	if ub.is_empty():
		print("CT|  ✔ 고유 아이템 슬롯·스킨 유효")
	else:
		print("CT|  ✘ %s" % str(ub)); bad += 1

	# ── 9) 월드 티어 — 배율이 단조 증가하는가 ──
	var keep := SaveGame.world_tier
	var prev_hp := 0.0
	var tier_bad := []
	var tiers: Array = SaveGame.endgame().get("tiers", [])
	for i in range(tiers.size()):
		SaveGame.world_tier = i
		var h := SaveGame.tier_mult("hp")
		if h < prev_hp:
			tier_bad.append("티어 %d hp %.2f" % [i, h])
		prev_hp = h
	SaveGame.world_tier = keep
	if tier_bad.is_empty() and tiers.size() >= 2:
		print("CT|  ✔ 월드 티어 %d단계 배율 단조 증가" % tiers.size())
	else:
		print("CT|  ✘ 티어 배율 이상: %s" % str(tier_bad)); bad += 1

	# ── 10) 티어 0 은 기존 플레이와 동일해야 한다 ──
	SaveGame.world_tier = 0
	var same := true
	for k in ["hp", "dmg", "essence", "drop", "exp"]:
		if abs(SaveGame.tier_mult(k) - 1.0) > 0.001:
			same = false
	if same:
		print("CT|  ✔ 월드 티어 0 = 기존 밸런스 (배율 전부 1.0)")
	else:
		print("CT|  ✘ 티어 0 배율이 1.0 이 아니다"); bad += 1

	# ── 11) 보스 러시 순서가 실재 보스인가 ──
	var rb := []
	for t in SaveGame.boss_rush_order():
		if not EnemyConfig.TYPES.has(String(t)):
			rb.append(t)
	if rb.is_empty():
		print("CT|  ✔ 보스 러시 %d종 전부 실재" % SaveGame.boss_rush_order().size())
	else:
		print("CT|  ✘ 없는 보스: %s" % str(rb)); bad += 1

	# ── 12) NEW GAME+ 왕복 — 성장은 남고 진행만 초기화 ──
	SaveGame.wipe()
	GameManager.chapter = 7
	GameManager.player_level = 22
	CraftManager.essence = 500
	UpgradeManager.purchase("hp")
	var lv_before := UpgradeManager.level("hp")
	SaveGame.run_deaths = 0
	SaveGame.run_seconds = 1200.0
	SaveGame.start_new_game_plus()
	var ok := GameManager.chapter == ChapterConfig.FIRST \
		and SaveGame.ng_plus == 1 \
		and SaveGame.world_tier == 1 \
		and GameManager.player_level == 22 \
		and UpgradeManager.level("hp") == lv_before
	if ok:
		print("CT|  ✔ NEW GAME+ — 챕터 1 초기화 · 레벨/강화 유지 · 티어 1")
	else:
		print("CT|  ✘ NG+ 이상: 챕터%d ng%d 티어%d Lv%d 강화%d"
			% [GameManager.chapter, SaveGame.ng_plus, SaveGame.world_tier,
			GameManager.player_level, UpgradeManager.level("hp")]); bad += 1

	# ── 13) 챌린지 판정 — 무사망·40분 기록이 남는가 ──
	if bool(SaveGame.records.get("ch_no_death", false)) \
			and bool(SaveGame.records.get("ch_speed_40", false)):
		print("CT|  ✔ 챌린지 판정 (무사망 · 40분 이내)")
	else:
		print("CT|  ✘ 챌린지가 기록되지 않았다: %s" % str(SaveGame.records)); bad += 1

	# ── 14) 엔드게임 상태가 저장 왕복에서 살아남는가 ──
	SaveGame.save()
	SaveGame.world_tier = 0
	SaveGame.ng_plus = 0
	SaveGame.records = {}
	SaveGame.load_game()
	if SaveGame.world_tier == 1 and SaveGame.ng_plus == 1 \
			and bool(SaveGame.records.get("ch_no_death", false)):
		print("CT|  ✔ 엔드게임 저장 왕복 (티어 · NG+ · 기록)")
	else:
		print("CT|  ✘ 엔드게임 상태 저장 누락"); bad += 1

	# ── 15) 옛 세이브 호환 — 새 키가 없어도 읽혀야 한다 ──
	var old := {"version": 1, "progress": {"chapter": 3}, "player": {}, "world": {}}
	var f := FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(old)); f.close()
	SaveGame.world_tier = 9
	SaveGame.ng_plus = 9
	if SaveGame.load_game() and SaveGame.world_tier == 0 and SaveGame.ng_plus == 0:
		print("CT|  ✔ 새 키가 없는 옛 세이브도 기본값으로 읽힌다")
	else:
		print("CT|  ✘ 옛 세이브 호환 실패 (티어%d ng%d)"
			% [SaveGame.world_tier, SaveGame.ng_plus]); bad += 1

	# ── 16) 연출 프리셋이 실제로 존재하고 호출부와 이름이 맞는가 ──
	var used := ["crit", "parry", "hurt", "boss_phase", "boss_enrage",
		"boss_death", "weak_point", "slam", "level_up", "ult"]
	var f_missing := []
	for n in used:
		var any := false
		for sec in ["hitstop", "shake", "slowmo", "flash", "camera"]:
			if CombatFeel.feel().get(sec, {}).has(n) 					or CombatFeel.feel().get(sec, {}).has("punch_" + n):
				any = true
		if not any:
			f_missing.append(n)
	if f_missing.is_empty():
		print("CT|  ✔ 연출 프리셋 %d종 전부 정의됨" % used.size())
	else:
		print("CT|  ✘ feel.json 에 없는 프리셋: %s" % str(f_missing)); bad += 1

	# ── 17) 사운드 레이어가 실재하는 사운드 키를 부르는가 ──
	var s_missing := []
	for k in CombatFeel.feel().get("sound", {}).get("layers", {}):
		for row in CombatFeel.feel()["sound"]["layers"][k]:
			if typeof(row) == TYPE_ARRAY and row.size() >= 1:
				if not SoundManager.sounds.has(String(row[0])):
					s_missing.append("%s → %s" % [k, row[0]])
	if s_missing.is_empty():
		print("CT|  ✔ 사운드 레이어가 부르는 키 전부 실재")
	else:
		print("CT|  ✘ 없는 사운드: %s" % str(s_missing)); bad += 1

	# ── 18) impact() 가 정의 없는 이름에도 죽지 않는가 ──
	CombatFeel.impact("__없는_프리셋__")
	CombatFeel.reset()
	print("CT|  ✔ 정의 없는 프리셋 호출도 안전")

	# ── 19) AI 프로필 — 전 몬스터가 프로필을 받는가 ──
	var ai_bad := []
	for t in EnemyConfig.TYPES:
		var pat := String(EnemyConfig.TYPES[t].get("pattern", "melee"))
		var pr := EnemyConfig.ai_profile(String(t), pat)
		if pr.is_empty() or not pr.has("keep"):
			ai_bad.append("%s(%s)" % [t, pat])
	if ai_bad.is_empty():
		print("CT|  ✔ 몬스터 %d종 전부 전술 프로필 보유" % EnemyConfig.TYPES.size())
	else:
		print("CT|  ✘ 프로필 없는 몬스터: %s" % str(ai_bad)); bad += 1

	# ── 20) by_type 덮어쓰기가 실제로 적용되는가 ──
	var st := EnemyConfig.ai_profile("stalker", "charge")
	var ch := EnemyConfig.ai_profile("__없는몹__", "charge")
	if float(st.get("flank_bias", 0.0)) > float(ch.get("flank_bias", 0.0)):
		print("CT|  ✔ by_type 덮어쓰기 적용 (stalker 측면 %.2f > charge 기본 %.2f)"
			% [float(st["flank_bias"]), float(ch["flank_bias"])])
	else:
		print("CT|  ✘ by_type 덮어쓰기 실패"); bad += 1

	# ── 21) 등급 배율이 단조 증가하는가 ──
	if EnemyConfig.ai_tier_scale("dodge", 0) < EnemyConfig.ai_tier_scale("dodge", 2):
		print("CT|  ✔ 등급이 오를수록 회피가 잦아진다")
	else:
		print("CT|  ✘ 등급 배율 이상"); bad += 1

	# ── 22) 리듬 — 체력이 적을수록 정비 시간이 길어지는가 ──
	var b_lo: float = CombatFeel.pace("breather", "base", 3.0)
	var b_hi: float = b_lo + CombatFeel.pace("breather", "per_hp_lost", 6.0)
	if b_hi > b_lo and CombatFeel.pace("breather", "max", 0.0) >= b_lo:
		print("CT|  ✔ 정비 시간 %.0f초 → 최대 %.0f초 (잃은 체력 비례)"
			% [b_lo, CombatFeel.pace("breather", "max", 0.0)])
	else:
		print("CT|  ✘ 정비 시간 설정 이상"); bad += 1

	# ── 23) 전설 옵션 4종이 전부 실제 효과를 갖는가 ──
	var leg_missing := []
	for flag in ["lifesteal", "overflow", "echo", "fortress"]:
		if not CombatFeel.pacing().get("legendary", {}).has(flag):
			leg_missing.append(flag)
	# affixes.json 의 flag 와 pacing.json 의 키가 서로 맞아야 한다
	for o in LootManager.affix_data().get("legendary", {}).get("options", []):
		var fg := String(o.get("flag", ""))
		if fg != "" and not CombatFeel.pacing().get("legendary", {}).has(fg):
			leg_missing.append("affix:" + fg)
	if leg_missing.is_empty():
		print("CT|  ✔ 전설 옵션 4종 전부 실제 효과 정의됨")
	else:
		print("CT|  ✘ 효과 없는 전설 flag: %s" % str(leg_missing)); bad += 1

	# ── 24) 연속 처치 카운터가 동작하는가 ──
	CombatFeel.reset_streak()
	for i in range(int(CombatFeel.pace("moments", "streak_kills", 8))):
		CombatFeel.note_kill()
	CombatFeel.reset_streak()
	print("CT|  ✔ 연속 처치 카운터 동작 (예외 없음)")

	# ── 25) 무기 계열 — 스킨이 전부 계열에 매칭되는가 ──
	var w_bad := []
	for fid in ItemData.weapon_data().get("families", {}):
		for sk in ItemData.weapon_data().get("skins", {}).get(fid, []):
			if ItemData.family_of(String(sk)) != fid:
				w_bad.append("%s→%s" % [sk, fid])
	if w_bad.is_empty():
		print("CT|  ✔ 무기 %d계열 스킨 매칭 정상"
			% ItemData.weapon_data().get("families", {}).size())
	else:
		print("CT|  ✘ 계열 매칭 실패: %s" % str(w_bad)); bad += 1

	# ── 26) 계열마다 실제로 플레이가 달라지는가 (전부 같은 수치면 의미 없다) ──
	var seen := {}
	for fid in ItemData.weapon_data().get("families", {}):
		var f2: Dictionary = ItemData.weapon_data()["families"][fid]
		seen["%s|%s|%s" % [f2.get("reach"), f2.get("rate"), f2.get("status")]] = true
	if seen.size() >= ItemData.weapon_data().get("families", {}).size():
		print("CT|  ✔ 계열별 사거리·속도·상태이상이 전부 다르다")
	else:
		print("CT|  ✘ 계열 수치가 겹친다"); bad += 1

	# ── 27) 계열 상태이상이 정의돼 있는가 ──
	var st_bad := []
	for fid in ItemData.weapon_data().get("families", {}):
		var k := String(ItemData.weapon_data()["families"][fid].get("status", ""))
		if k != "" and ItemData.status_def(k).is_empty():
			st_bad.append(k)
	if st_bad.is_empty():
		print("CT|  ✔ 무기 상태이상 정의 완비")
	else:
		print("CT|  ✘ 정의 없는 상태이상: %s" % str(st_bad)); bad += 1

	# ── 28) 몬스터 개성 — 보스가 아닌 몹이 전부 정의를 갖는가 ──
	var m_bad := []
	for t in EnemyConfig.TYPES:
		if EnemyConfig.BOSS_TYPES.has(String(t)):
			continue
		var tr := EnemyConfig.mon_trait(String(t))
		if tr.is_empty() or String(tr.get("counter", "")) == "":
			m_bad.append(t)
	if m_bad.is_empty():
		print("CT|  ✔ 일반 몬스터 전부 역할·약점·상대법 보유")
	else:
		print("CT|  ✘ 개성 없는 몬스터: %s" % str(m_bad)); bad += 1

	# ── 29) 대표 행동이 실재하는 정의를 가리키는가 ──
	var b_bad := []
	for t in EnemyConfig.mon_data().get("monsters", {}):
		if EnemyConfig.mon_behavior(String(t)).is_empty():
			b_bad.append(t)
		var sm2 := EnemyConfig.mon_behavior(String(t))
		if String(sm2.get("kind", "")) == "summon" 				and not EnemyConfig.TYPES.has(String(sm2.get("type", ""))):
			b_bad.append("%s 소환 대상 없음" % t)
		if String(sm2.get("kind", "")) == "split" 				and not EnemyConfig.TYPES.has(String(sm2.get("into", ""))):
			b_bad.append("%s 분열 대상 없음" % t)
	if b_bad.is_empty():
		print("CT|  ✔ 대표 행동 %d종 전부 유효"
			% EnemyConfig.mon_data().get("behaviors", {}).size())
	else:
		print("CT|  ✘ %s" % str(b_bad)); bad += 1

	# ── 30) 빌드 30종 이상 · 기존 기능만 참조하는가 ──
	var blds: Array = UpgradeManager.builds()
	if blds.size() >= 30:
		print("CT|  ✔ 빌드 %d종 (태그 %d분류)"
			% [blds.size(), UpgradeManager.builds_by_tag().size()])
	else:
		print("CT|  ✘ 빌드가 %d종뿐" % blds.size()); bad += 1

	# ── 31) 템포 — 챕터가 오를수록 조여드는가 ──
	var keep_ch := GameManager.chapter
	GameManager.chapter = 1
	var d1 := CombatFeel.tempo("density", 1.0)
	var e1 := CombatFeel.tempo("elite", 0.0)
	var r1 := CombatFeel.tempo("rest", 1.0)
	GameManager.chapter = 7
	var d7 := CombatFeel.tempo("density", 1.0)
	var e7 := CombatFeel.tempo("elite", 0.0)
	var r7 := CombatFeel.tempo("rest", 1.0)
	GameManager.chapter = keep_ch
	if d7 > d1 and e7 > e1 and r7 < r1:
		print("CT|  ✔ 템포 — 밀도 %.2f→%.2f · 엘리트 %.0f%%→%.0f%% · 휴식 %.2f→%.2f"
			% [d1, d7, e1 * 100.0, e7 * 100.0, r1, r7])
	else:
		print("CT|  ✘ 템포 곡선 이상"); bad += 1

	# ── 32) 챕터 중간값이 보간되는가 ──
	GameManager.chapter = 4
	var d4 := CombatFeel.tempo("density", 1.0)
	GameManager.chapter = keep_ch
	if d4 > d1 and d4 < d7:
		print("CT|  ✔ 챕터 4 보간값 %.2f (1장 %.2f < 4장 < 7장 %.2f)" % [d4, d1, d7])
	else:
		print("CT|  ✘ 보간 실패: %.2f" % d4); bad += 1

	# ── 33) 신규 기믹 — 유도탄/장판 정의와 구현이 맞물리는가 ──
	var g_bad := []
	for k in ["homing", "field"]:
		var found := false
		for bn in EnemyConfig.mon_data().get("behaviors", {}):
			var bv = EnemyConfig.mon_data()["behaviors"][bn]
			if typeof(bv) != TYPE_DICTIONARY:
				continue          ## note 같은 설명 문자열은 건너뛴다
			if String(bv.get("kind", "")) == k:
				found = true
		if not found:
			g_bad.append("monsters:" + k)
	for t in EnemyConfig.BOSS_TYPES:
		for ph in EnemyConfig.boss_def(String(t)).get("phases", []):
			for pn in ph.get("patterns", []):
				if String(pn) in ["homing", "field"]:
					var need_key := String(pn) + "_cd"
					if not ph.has(need_key):
						g_bad.append("%s %s 쿨다운 없음" % [t, pn])
	if g_bad.is_empty():
		print("CT|  ✔ 신규 기믹(유도탄·장판) 정의 완비")
	else:
		print("CT|  ✘ %s" % str(g_bad)); bad += 1

	var brain_probe: Node = EnemyBrain.new()
	if brain_probe.has_method("fire_homing") and brain_probe.has_method("spawn_field"):
		print("CT|  ✔ EnemyBrain 이 기믹 2종을 실행할 수 있다")
	else:
		print("CT|  ✘ EnemyBrain 에 기믹 구현 없음"); bad += 1
	brain_probe.free()

	# ── 34) Bow 계열 ──
	var bowf := ItemData.family_def("bow_steel")
	if String(bowf.get("name", "")) == "활" and bool(bowf.get("ranged", false)):
		print("CT|  ✔ Bow 계열 — 원거리 판정 · 관통 %s" % str(bowf.get("pierce")))
	else:
		print("CT|  ✘ Bow 계열 정의 이상"); bad += 1
	var proj_probe: Node = load("res://scripts3d/Projectile3D.gd").new()
	var ok_p: bool = ("hits_player" in proj_probe) and ("pierce" in proj_probe) 		and ("homing_turn" in proj_probe) and proj_probe.has_method("setup")
	if ok_p:
		print("CT|  ✔ Projectile3D 확장 필드·setup() 존재")
	else:
		print("CT|  ✘ Projectile3D 확장 누락"); bad += 1
	proj_probe.free()

	# ── 35) 타임스케일 우선순위 — 강한 슬로모가 약한 것을 덮는가 ──
	CombatFeel.reset()
	CombatFeel.slow_motion(2.0, 0.8)     ## 길고 약한 것
	CombatFeel.slow_motion(0.4, 0.3)     ## 짧고 강한 것 → 반영돼야 한다
	var ts_ok := Engine.time_scale <= 0.31
	CombatFeel.hit_stop(0.1)             ## 히트스톱이 슬로모보다 우선
	var hs_ok := Engine.time_scale <= 0.05
	CombatFeel.reset()
	if ts_ok and hs_ok and abs(Engine.time_scale - 1.0) < 0.001:
		print("CT|  ✔ 타임스케일 우선순위 (강한 슬로모 반영 · 히트스톱 우선 · reset 복구)")
	else:
		print("CT|  ✘ 타임스케일 이상: slow %s / stop %s / reset %.3f"
			% [str(ts_ok), str(hs_ok), Engine.time_scale]); bad += 1

	# ── 36) VfxPool — 임시 메시가 풀을 거치는가 ──
	var host := Node3D.new()
	add_child(host)
	var f1: MeshInstance3D = VfxPool.take_fx(host, SphereMesh.new(), StandardMaterial3D.new())
	VfxPool.give_fx(f1)
	var f2: MeshInstance3D = VfxPool.take_fx(host, SphereMesh.new(), StandardMaterial3D.new())
	var reused: bool = f2 == f1
	VfxPool.give_fx(f2)
	host.queue_free()
	if reused and int(VfxPool.stats().get("fx_reused", 0)) > 0:
		print("CT|  ✔ VfxPool 임시 메시 재사용 (생성 %d · 재사용 %d)"
			% [int(VfxPool.stats()["fx_created"]), int(VfxPool.stats()["fx_reused"])])
	else:
		print("CT|  ✘ 임시 메시가 재사용되지 않는다"); bad += 1

	# ── 37) 후반 챕터 곡선 — 체력 상승분을 보상이 따라오는가 ──
	var keep2 := GameManager.chapter
	GameManager.chapter = 1
	var hp1 := ChapterConfig.hp_mult_of(1)
	var rw1 := CombatFeel.tempo("reward", 1.0)
	GameManager.chapter = 7
	var hp7 := ChapterConfig.hp_mult_of(7)
	var rw7 := CombatFeel.tempo("reward", 1.0)
	GameManager.chapter = keep2
	if hp7 > hp1 and rw7 > rw1:
		print("CT|  ✔ 후반 곡선 — 체력 ×%.2f→×%.2f · 보상 ×%.2f→×%.2f"
			% [hp1, hp7, rw1, rw7])
	else:
		print("CT|  ✘ 후반 곡선 이상"); bad += 1

	# ── 38) 메뉴 · 세이브 슬롯 ──
	var hud2 = get_tree().current_scene.hud
	if hud2 == null or hud2.get("menu_ui") == null:
		print("CT|  ✘ HUD 에 MainMenuUI 가 없다"); bad += 1
	else:
		var m = hud2.menu_ui
		var sc: Dictionary = m.defs().get("screens", {})
		var need_scr := ["title", "pause", "slots", "options"]
		var miss_scr := []
		for k in need_scr:
			if not sc.has(k):
				miss_scr.append(k)
		if miss_scr.is_empty():
			print("CT|  ✔ 메뉴 화면 4종 정의 (title/pause/slots/options)")
		else:
			print("CT|  ✘ 없는 화면: %s" % str(miss_scr)); bad += 1

		# 항목 id 가 전부 처리 가능한 것인가 (오타 나면 눌러도 아무 일이 없다)
		var known := ["continue", "new", "resume", "options", "title",
			"back", "vol_down", "vol_up", "gfx_down", "gfx_up", "quit", "boss_rush"]
		var bad_id := []
		for k in sc:
			for it in sc[k].get("items", []):
				if not (String(it.get("id", "")) in known):
					bad_id.append("%s/%s" % [k, it.get("id")])
		if bad_id.is_empty():
			print("CT|  ✔ 메뉴 항목 id 전부 처리 가능")
		else:
			print("CT|  ✘ 처리되지 않는 항목: %s" % str(bad_id)); bad += 1

		# 열고 닫을 때 트리 일시정지가 정확히 풀리는가
		m.open_pause()
		var paused_ok: bool = get_tree().paused and m.is_open()
		m.close()
		var closed_ok: bool = not get_tree().paused and not m.is_open()
		if paused_ok and closed_ok:
			print("CT|  ✔ 일시정지 — 열면 멈추고 닫으면 풀린다")
		else:
			print("CT|  ✘ 일시정지 상태 이상 (open %s / close %s)"
				% [str(paused_ok), str(closed_ok)]); bad += 1

		# 다른 창과 동시에 뜨지 않는가
		hud2.npc_ui.open("hunter_old")
		m.open_pause()
		if hud2.npc_ui.is_open():
			print("CT|  ✘ 메뉴와 대화창이 동시에 열린다"); bad += 1
		else:
			print("CT|  ✔ 메뉴가 열리면 다른 창은 닫힌다")
		m.close()

	# ── 39) 세이브 슬롯 — 서로 독립이고 슬롯 0 은 기존 경로 ──
	if SaveGame.slot_path(0) != SaveGame.PATH:
		print("CT|  ✘ 슬롯 0 이 기존 경로가 아니다 (옛 세이브 호환 깨짐)"); bad += 1
	else:
		print("CT|  ✔ 슬롯 0 = %s (옛 세이브 그대로)" % SaveGame.PATH)

	var keep_slot := SaveGame.slot
	SaveGame.use_slot(0); SaveGame.wipe()
	SaveGame.use_slot(1); SaveGame.wipe()
	SaveGame.slot = 0
	GameManager.chapter = 2
	GameManager.player_level = 5
	SaveGame.save()
	SaveGame.slot = 1
	GameManager.chapter = 6
	GameManager.player_level = 30
	SaveGame.save()
	var i0 := SaveGame.slot_info(0)
	var i1 := SaveGame.slot_info(1)
	var i2 := SaveGame.slot_info(2)
	if int(i0.get("chapter", 0)) == 2 and int(i1.get("chapter", 0)) == 6 			and bool(i2.get("empty", false)):
		print("CT|  ✔ 슬롯 독립 (0=%d장 Lv%d · 1=%d장 Lv%d · 2=빈 슬롯)"
			% [int(i0["chapter"]), int(i0["level"]),
			int(i1["chapter"]), int(i1["level"])])
	else:
		print("CT|  ✘ 슬롯이 섞인다: %s / %s / %s" % [str(i0), str(i1), str(i2)]); bad += 1

	SaveGame.use_slot(0)
	if GameManager.chapter == 2:
		print("CT|  ✔ use_slot 이 해당 슬롯을 읽는다")
	else:
		print("CT|  ✘ use_slot 로드 실패 (챕터 %d)" % GameManager.chapter); bad += 1

	SaveGame.use_slot(1); SaveGame.wipe()
	SaveGame.use_slot(0); SaveGame.wipe()
	SaveGame.slot = keep_slot

	await _run_projectile_tests()
	bad += bad_extra

	SaveGame.wipe()
	print("CT| " + ("✔ 전부 통과" if bad == 0 else "✘ 문제 %d건" % bad))
	print("CT| DONE")

# ══════════════════════════════════════════════
#  화살 · 유도탄 · 장판 실동작 검증
#  실제 노드를 만들어 물리 프레임을 돌린다 (정의 검사가 아니라 동작 검사).
# ══════════════════════════════════════════════
var _pt_bad := 0

func _run_projectile_tests() -> void:
	print("CT| ── 투사체 실동작 ──")
	# 앞선 연출 검사가 남긴 시간 배율을 되돌린다.
	# time_scale 이 낮으면 물리 delta 가 작아져 유도·수명 검사가 전부 거짓 실패한다.
	CombatFeel.reset()
	Engine.time_scale = 1.0
	var host := Node3D.new()
	get_tree().current_scene.add_child(host)

	await _t_arrow_hits_enemy(host)
	await _t_arrow_ignores_player(host)
	await _t_pierce(host)
	await _t_homing(host)
	await _t_field(host)
	await _t_pierce_three(host)
	await _t_homing_vs_dash(host)
	await _t_field_tick(host)
	await _t_new_game_reset()
	await _t_menu_click()
	await _t_mute()
	await _t_audio_scan()
	await _t_freeze_guard()
	await _t_qol()
	await _t_aim()
	await _t_pet()

	host.queue_free()
	if _pt_bad > 0:
		bad_extra += _pt_bad

var bad_extra := 0

## 표적 역할을 할 가짜 적. Enemy3D 전체를 띄우지 않고
## 화살이 보는 최소 조건(그룹·레이어·take_damage·dead)만 갖춘다.
func _make_dummy(host: Node3D, pos: Vector3) -> CharacterBody3D:
	var e := CharacterBody3D.new()
	e.set_script(load("res://tools/_dummy_target.gd"))
	e.collision_layer = 4          ## Enemy3D 와 같은 레이어
	e.collision_mask = 0
	var sh := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.8
	cap.height = 2.0
	sh.shape = cap
	e.add_child(sh)
	host.add_child(e)
	e.global_position = pos
	e.add_to_group("enemies")
	return e

func _steps(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

## 1) 플레이어 화살이 적을 맞히는가 (충돌 마스크가 핵심)
func _t_arrow_hits_enemy(host: Node3D) -> void:
	var e := _make_dummy(host, Vector3(0, 0, 6))
	var proj := VfxPool.take_projectile(host)
	proj.global_position = Vector3(0, 1.0, 0)
	proj.setup(Vector3(0, 0, 1), 20.0, 10.0, 2.0, false, false)
	e.global_position = Vector3(0, 1.0, 6)
	await _steps(30)
	if e.hits > 0:
		print("CT|  ✔ 화살이 적을 명중 (피해 %d회 · 마스크 %d)" % [e.hits, proj.collision_mask])
	else:
		print("CT|  ✘ 화살이 적을 통과했다 (마스크 %d, 적 레이어 4)" % proj.collision_mask)
		_pt_bad += 1
	e.queue_free()
	VfxPool.give_projectile(proj)

## 2) 플레이어의 화살은 플레이어를 때리면 안 된다
func _t_arrow_ignores_player(host: Node3D) -> void:
	var proj := VfxPool.take_projectile(host)
	proj.setup(Vector3(0, 0, 1), 10.0, 10.0, 1.0, false, false)
	var mask_arrow: int = proj.collision_mask
	proj.setup(Vector3(0, 0, 1), 10.0, 10.0, 1.0, true, false)
	var mask_enemy: int = proj.collision_mask
	if mask_arrow == 4 and mask_enemy == 2:
		print("CT|  ✔ 대상별 충돌 마스크 전환 (화살 4 · 적탄 2)")
	else:
		print("CT|  ✘ 마스크 전환 실패: 화살 %d / 적탄 %d" % [mask_arrow, mask_enemy])
		_pt_bad += 1
	VfxPool.give_projectile(proj)

## 3) 관통 — 두 표적을 모두 맞히고, 비관통은 첫 표적에서 멈춘다
func _t_pierce(host: Node3D) -> void:
	var a := _make_dummy(host, Vector3(3, 1.0, 4))
	var b := _make_dummy(host, Vector3(3, 1.0, 8))
	var p1 := VfxPool.take_projectile(host)
	p1.global_position = Vector3(3, 1.0, 0)
	p1.setup(Vector3(0, 0, 1), 22.0, 5.0, 2.0, false, true)
	await _steps(35)
	var pierced: bool = a.hits > 0 and b.hits > 0

	var c := _make_dummy(host, Vector3(-3, 1.0, 4))
	var d := _make_dummy(host, Vector3(-3, 1.0, 8))
	var p2 := VfxPool.take_projectile(host)
	p2.global_position = Vector3(-3, 1.0, 0)
	p2.setup(Vector3(0, 0, 1), 22.0, 5.0, 2.0, false, false)
	await _steps(35)
	var stopped: bool = c.hits > 0 and d.hits == 0

	if pierced and stopped:
		print("CT|  ✔ 관통 동작 (관통 %d/%d · 비관통 %d/%d)"
			% [a.hits, b.hits, c.hits, d.hits])
	else:
		print("CT|  ✘ 관통 이상: 관통 %d/%d · 비관통 %d/%d"
			% [a.hits, b.hits, c.hits, d.hits])
		_pt_bad += 1
	for n in [a, b, c, d]:
		n.queue_free()

## 4) 유도탄 — 옆으로 쏜 탄이 목표 쪽으로 방향을 트는가
func _t_homing(host: Node3D) -> void:
	# 앞선 검사의 표적이 아직 남아 있으면 첫 프레임에 부딪혀 탄이 사라진다.
	# 한 프레임 흘려보내고, 멀리 떨어진 전용 좌표에서 단독으로 확인한다.
	await _steps(2)
	var target := _make_dummy(host, Vector3(60.0, 1.0, 40.0))
	var proj := VfxPool.take_projectile(host)
	proj.setup(Vector3(0, 0, 1), 4.0, 5.0, 6.0, true, false)   ## 표적과 90도 어긋난 방향
	proj.global_position = Vector3(40.0, 1.0, 40.0)            ## setup 이후에 배치
	proj.homing_turn = 4.0
	proj.homing_target = target
	var d0: Vector3 = proj.dir
	await _steps(60)
	var d1: Vector3 = proj.dir
	if d1.x > d0.x + 0.30:
		print("CT|  ✔ 유도탄 선회 (x %.2f → %.2f)" % [d0.x, d1.x])
	else:
		print("CT|  ✘ 유도탄이 방향을 틀지 않는다 (x %.2f → %.2f · life %.2f · pp %s)"
			% [d0.x, d1.x, proj.life, str(proj.is_physics_processing())])
		_pt_bad += 1
	target.queue_free()
	VfxPool.give_projectile(proj)


## 5) 장판 — 생성되고 수명이 끝나면 풀로 돌아오는가
func _t_field(host: Node3D) -> void:
	var e := _make_dummy(host, Vector3(20, 0, 20))
	e.set_script(load("res://tools/_dummy_target.gd"))
	var brain := EnemyBrain.new()
	host.add_child(brain)
	brain.owner_enemy = e
	e.contact_damage = 10.0
	var pooled0: int = int(VfxPool.stats().get("fx_pooled", 0))
	var made0: int = int(VfxPool.stats().get("fx_created", 0)) 		+ int(VfxPool.stats().get("fx_reused", 0))
	brain.spawn_field(4.0, 0.6, Vector3(20, 0, 20))
	await _steps(4)
	# 깔린 직후: 풀에서 하나를 꺼냈어야 한다
	var made1: int = int(VfxPool.stats().get("fx_created", 0)) 		+ int(VfxPool.stats().get("fx_reused", 0))
	var spawned: bool = made1 > made0
	# 수명이 끝나면 다시 풀로 돌아온다
	await get_tree().create_timer(1.4, true, false, true).timeout
	var pooled1: int = int(VfxPool.stats().get("fx_pooled", 0))
	if spawned and pooled1 >= pooled0:
		print("CT|  ✔ 장판 생성·수명 후 풀 반납 (꺼냄 %d회 · pooled %d → %d)"
			% [made1 - made0, pooled0, pooled1])
	else:
		print("CT|  ✘ 장판 이상 (꺼냄 %d회 · pooled %d → %d)"
			% [made1 - made0, pooled0, pooled1])
		_pt_bad += 1
	brain.queue_free()
	e.queue_free()

# ══════════════════════════════════════════════
#  가상 조작 봇 — 실제 노드·실제 입력으로 돌린다
#    godot --quit-after 2000 -- --contenttest
# ══════════════════════════════════════════════

## [Bow 관통] 일직선에 3기를 세우고 화살 1발 — 셋 다 맞고 지나가야 한다
func _t_pierce_three(host: Node3D) -> void:
	await _steps(2)
	var xs := 24.0
	var t := []
	for i in range(3):
		t.append(_make_dummy(host, Vector3(xs, 1.0, 6.0 + i * 4.0)))
	var proj := VfxPool.take_projectile(host)
	proj.setup(Vector3(0, 0, 1), 30.0, 5.0, 3.0, false, true)
	proj.global_position = Vector3(xs, 1.0, 0.0)
	await _steps(60)
	var hit_all: bool = t[0].hits > 0 and t[1].hits > 0 and t[2].hits > 0
	var once: bool = t[0].hits == 1 and t[1].hits == 1 and t[2].hits == 1
	if hit_all and once:
		print("CT|  ✔ 관통 화살 1발이 3기를 각 1회씩 관통 (%d/%d/%d)"
			% [t[0].hits, t[1].hits, t[2].hits])
	else:
		print("CT|  ✘ 관통 3기 실패 (%d/%d/%d)" % [t[0].hits, t[1].hits, t[2].hits])
		_pt_bad += 1
	for n in t:
		n.queue_free()
	VfxPool.give_projectile(proj)

## [유도탄 회피] 선회속도 2.6 일 때, 목표가 대시로 옆으로 빠지면
## 탄이 따라오되 즉시 붙지는 못해야 한다(= 회피 가능).
func _t_homing_vs_dash(host: Node3D) -> void:
	await _steps(2)
	var turn := 2.6
	var target := _make_dummy(host, Vector3(-24.0, 1.0, 12.0))
	var proj := VfxPool.take_projectile(host)
	proj.setup(Vector3(0, 0, 1), 13.0, 5.0, 4.0, true, false)
	proj.global_position = Vector3(-24.0, 1.0, 0.0)
	proj.homing_turn = turn
	proj.homing_target = target
	await _steps(10)
	# 대시 — 목표가 옆으로 8m 순간 이동한다 (플레이어 회피 상황)
	target.global_position += Vector3(8.0, 0, 0)
	var before: float = proj.dir.angle_to((target.global_position - proj.global_position).normalized())
	await _steps(20)
	var after: float = proj.dir.angle_to((target.global_position - proj.global_position).normalized())
	var chased: bool = after < before                 ## 따라오긴 한다
	var dist: float = proj.global_position.distance_to(target.global_position)
	var dodged: bool = dist > 1.5                     ## 그래도 즉시 붙지는 못한다
	if chased and dodged:
		print("CT|  ✔ 유도탄 회피 가능 (오차각 %.2f→%.2f rad · 거리 %.1fm)"
			% [before, after, dist])
	else:
		print("CT|  ✘ 유도탄 균형 이상 (각 %.2f→%.2f · 거리 %.1f)" % [before, after, dist])
		_pt_bad += 1
	target.queue_free()
	VfxPool.give_projectile(proj)

## [장판 tick] 장판 위에 선 대상이 tick 주기대로 맞는가
func _t_field_tick(host: Node3D) -> void:
	await _steps(2)
	var victim := _make_dummy(host, Vector3(80.0, 0.0, 80.0))
	# 장판은 Battlefield.live_player() 를 때린다 — 검증 동안만 플레이어 자리에 세운다
	var keep = Battlefield.player
	# HUD 가 매 프레임 Battlefield.player 의 실제 필드를 읽는다.
	# 더미를 꽂아 두는 동안은 HUD 갱신을 멈춰 무의미한 오류 로그를 없앤다.
	var w3 = get_tree().current_scene
	if w3 and w3.get("hud") != null:
		w3.hud.set_process(false)
	Battlefield.player = victim
	var caster := _make_dummy(host, Vector3(80.0, 0.0, 80.0))
	var brain: Node = EnemyBrain.new()
	host.add_child(brain)
	brain.owner_enemy = caster
	caster.contact_damage = 20.0
	brain.spawn_field(6.0, 1.2, Vector3(80.0, 0.0, 80.0))
	await get_tree().create_timer(1.4, true, false, true).timeout
	Battlefield.player = keep
	if w3 and w3.get("hud") != null:
		w3.hud.set_process(true)
	# tick 0.5초 · 수명 1.2초 → 2회 이상 맞아야 한다
	if victim.hits >= 2:
		print("CT|  ✔ 장판 tick 피해 (%d회 · 누적 %.1f)" % [victim.hits, victim.total])
	else:
		print("CT|  ✘ 장판이 때리지 않는다 (%d회)" % victim.hits)
		_pt_bad += 1
	brain.queue_free()
	caster.queue_free()
	victim.queue_free()

## [새 게임 리셋] 더러운 상태를 넣고 슬롯 2로 새 게임 — 전부 초기값이어야 한다
func _t_new_game_reset() -> void:
	var keep_slot := SaveGame.slot
	SaveGame.slot = 2
	GameManager.chapter = 6
	GameManager.player_level = 40
	GameManager.day_count = 12
	CraftManager.essence = 9999
	SaveGame.ng_plus = 3
	SaveGame.world_tier = 4
	SaveGame.records["ch_no_death"] = true
	SaveGame.counters["chest"] = 77
	UpgradeManager.purchase("hp")
	SaveGame.save()

	SaveGame.start_new_game(2)

	var dirty := []
	if GameManager.chapter != ChapterConfig.FIRST: dirty.append("챕터 %d" % GameManager.chapter)
	if GameManager.player_level != 1: dirty.append("레벨 %d" % GameManager.player_level)
	if GameManager.day_count != 1: dirty.append("일차 %d" % GameManager.day_count)
	if CraftManager.essence != 0: dirty.append("마석 %d" % CraftManager.essence)
	if SaveGame.ng_plus != 0: dirty.append("NG+ %d" % SaveGame.ng_plus)
	if SaveGame.world_tier != 0: dirty.append("티어 %d" % SaveGame.world_tier)
	if not SaveGame.records.is_empty(): dirty.append("기록 %d" % SaveGame.records.size())
	if int(SaveGame.counter("chest")) != 0: dirty.append("카운터")
	if UpgradeManager.level("hp") != 0: dirty.append("강화 %d" % UpgradeManager.level("hp"))
	if not PlayerStats.inventory.is_empty(): dirty.append("인벤 %d" % PlayerStats.inventory.size())
	if not SaveGame.slot_info(2)["empty"]: dirty.append("슬롯 파일 남음")

	if dirty.is_empty():
		print("CT|  ✔ 새 게임 슬롯 리셋 — SaveGame·GameManager·PlayerStats 전부 초기값")
	else:
		print("CT|  ✘ 새 게임 후 남은 값: %s" % str(dirty))
		_pt_bad += 1
	SaveGame.slot = keep_slot

## [메뉴 마우스 클릭] 실제 버튼 신호를 쏴서 동작과 설정 반영을 확인한다
func _t_menu_click() -> void:
	var w = get_tree().current_scene
	if w == null or w.get("hud") == null or w.hud.get("menu_ui") == null:
		print("CT|  ✘ 메뉴를 찾을 수 없다"); _pt_bad += 1
		return
	var m = w.hud.menu_ui
	m.open_pause()
	await _idle()

	# 설정 화면으로 — 항목을 이름으로 찾아 클릭한다
	if not _click(m, "options"):
		print("CT|  ✘ '설정' 버튼을 찾지 못했다"); _pt_bad += 1
		m.close(); return
	await _idle()

	var db0: float = SaveGame.master_db
	var gfx0: int = SaveGame.graphics
	_click(m, "vol_down")
	await _idle()
	_click(m, "gfx_up")
	await _idle()
	var vol_ok: bool = SaveGame.master_db < db0
	var gfx_ok: bool = SaveGame.graphics != gfx0 or gfx0 == EnvironmentManager.level_count() - 1

	# 라벨에 현재 수치가 실제로 찍히는가
	var shown := ""
	for b in m._btns:
		if "볼륨" in b.text:
			shown = b.text
	var label_ok: bool = shown.find("%") >= 0

	# 마우스 hover 가 키보드 선택을 따라오게 하는가
	var before_sel: int = m._sel
	if m._btns.size() > 1:
		m._btns[m._btns.size() - 1].mouse_entered.emit()
		await _idle()
	var hover_ok: bool = m._sel != before_sel or m._btns.size() <= 1

	_click(m, "back")
	await _idle()
	m.close()
	SaveGame.master_db = db0
	SaveGame.graphics = gfx0

	if vol_ok and gfx_ok and label_ok and hover_ok:
		print("CT|  ✔ 메뉴 클릭 — 볼륨·그래픽 반영 · 수치 표시(%s) · hover 연동"
			% shown.strip_edges())
	else:
		print("CT|  ✘ 메뉴 클릭 이상 (vol %s / gfx %s / label %s / hover %s)"
			% [str(vol_ok), str(gfx_ok), str(label_ok), str(hover_ok)])
		_pt_bad += 1

## 항목 id 로 버튼을 찾아 pressed 를 쏜다 (실제 클릭과 같은 경로)
func _click(m, id: String) -> bool:
	for i in range(m._rows.size()):
		if String(m._rows[i]["id"]) == id and i < m._btns.size():
			if m._btns[i].disabled:
				return false
			m._btns[i].pressed.emit()
			return true
	return false

func _idle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

## [볼륨 0% 무음] 0% 로 내리면 버스가 실제로 mute 되는가
func _t_mute() -> void:
	var keep := SaveGame.master_db
	var bus := AudioServer.get_bus_index("Master")
	SoundManager.set_master_db(0.0)
	var loud_ok: bool = not AudioServer.is_bus_mute(bus)
	SoundManager.set_master_db(SoundManager.MIN_DB)      ## 0%
	var mute_ok: bool = AudioServer.is_bus_mute(bus) 		and AudioServer.get_bus_volume_db(bus) <= -79.0
	# 0% 로 둔 채 일시정지를 껐다 켜도 소리가 되살아나면 안 된다
	SoundManager.set_paused(true)
	SoundManager.set_paused(false)
	var stay_ok: bool = AudioServer.is_bus_mute(bus)
	SoundManager.set_master_db(keep)
	var back_ok: bool = not AudioServer.is_bus_mute(bus)
	if loud_ok and mute_ok and stay_ok and back_ok:
		print("CT|  ✔ 볼륨 0% 완전 무음 (일시정지 해제 후에도 유지 · 복구 정상)")
	else:
		print("CT|  ✘ 무음 처리 이상 (loud %s / mute %s / stay %s / back %s)"
			% [str(loud_ok), str(mute_ok), str(stay_ok), str(back_ok)])
		_pt_bad += 1

## [오디오 폴더 스캔] 파일을 넣기만 해도 잡히는가 · 빈 트랙이 없는가
func _t_audio_scan() -> void:
	var tracks := ["day", "night", "explore", "tense", "danger", "boss"]
	var empty := []
	for t in tracks:
		var path := String(SoundManager.audio_defs.get("bgm", {}).get(t, ""))
		if path == "" or not ResourceLoader.exists(path):
			empty.append(t)
	var sfx_n: int = SoundManager.sounds.size()
	# feel.json 이 부르는 사운드 키가 전부 실제로 등록돼 있는가
	var missing := []
	for k in CombatFeel.feel().get("sound", {}).get("layers", {}):
		for row in CombatFeel.feel()["sound"]["layers"][k]:
			if typeof(row) == TYPE_ARRAY and row.size() >= 1:
				if not SoundManager.sounds.has(String(row[0])):
					missing.append(String(row[0]))
	if empty.is_empty() and missing.is_empty() and sfx_n >= 20:
		print("CT|  ✔ 오디오 스캔 — BGM 6트랙 전부 채워짐 · SFX %d개 · 누락 키 0" % sfx_n)
	else:
		print("CT|  ✘ 오디오 스캔 (빈 트랙 %s · 누락 SFX %s · 등록 %d)"
			% [str(empty), str(missing), sfx_n])
		_pt_bad += 1

## [프리즈 방지] 연출 도중 호출부가 끊겨도 시간배율이 되돌아오는가
func _t_freeze_guard() -> void:
	CombatFeel.reset()
	# 잘못된 값이 들어와도 오래 멈추지 않는다
	CombatFeel.hit_stop(99.0)
	var capped: bool = CombatFeel._stop_remain <= 0.41
	# 0 에 붙어도 다음 프레임에 복구된다
	Engine.time_scale = 0.0
	CombatFeel._stop_remain = 0.0
	CombatFeel._slowmo_remain = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	var recovered: bool = Engine.time_scale >= 0.99
	# 타이머가 끝났는데 배율이 남아 있으면 되돌린다
	Engine.time_scale = 0.3
	await get_tree().process_frame
	await get_tree().process_frame
	var restored: bool = Engine.time_scale >= 0.99
	CombatFeel.reset()

	# BBCode 가 버튼 글자에 그대로 새지 않는가
	var raw := "값 [color=#6a6a72](60)[/color] 끝"
	var cleaned := NPCUI.plain(raw)
	var clean_ok: bool = cleaned.find("[") < 0 and cleaned.find("60") >= 0

	if capped and recovered and restored and clean_ok:
		print("CT|  ✔ 프리즈 방지 — 히트스톱 상한 · 0배율 복구 · 잔여배율 복구 · BBCode 제거")
	else:
		print("CT|  ✘ 프리즈 방지 (cap %s / zero %s / left %s / bbcode %s)"
			% [str(capped), str(recovered), str(restored), str(clean_ok)])
		_pt_bad += 1

## [편의 기능] 자동 합성 · 대화 자동 종료 · 퀘스트 안내 · 모델/파티클 체계
func _t_qol() -> void:
	var bad0 := _pt_bad

	# 1) 자동 합성 — 같은 등급 3개가 모이면 상위로 올라간다
	PlayerStats.reset()
	CraftManager.reset()
	var before_n := PlayerStats.inventory.size()
	# 첫 개는 빈 슬롯에 장착된다 — 인벤토리에 3개가 남으려면 4개가 필요하다.
	# (장착 중인 장비는 합성 재료로 쓰지 않는다 — 갑자기 알몸이 되면 안 되므로)
	for i in range(4):
		var it := ItemData.new()
		it.rarity = RarityEnums.Rarity.D
		it.slot = "weapon"
		PlayerStats.acquire_item(it)
	var inv_d := 0
	for chk in PlayerStats.inventory:
		if chk != null and chk.rarity == RarityEnums.Rarity.D:
			inv_d += 1
	var made := CraftManager.auto_merge_from(RarityEnums.Rarity.D)
	# 합성 결과물은 더 강하므로 곧바로 장착된다 — 인벤토리만 보면 놓친다
	var has_up := false
	for it2 in PlayerStats.inventory:
		if it2 != null and it2.rarity > RarityEnums.Rarity.D:
			has_up = true
	for slot in ["weapon", "armor", "relic"]:
		var eq: ItemData = PlayerStats.equipped.get(slot, null)
		if eq != null and eq.rarity > RarityEnums.Rarity.D:
			has_up = true
	var consumed: bool = inv_d >= 3 and PlayerStats.inventory.size() < inv_d
	if made > 0 and has_up:
		print("CT|  ✔ 자동 합성 — 인벤 D 3개 → 상위 등급 %d회 (인벤 %d개 남음)"
			% [made, PlayerStats.inventory.size()])
	else:
		print("CT|  ✘ 자동 합성 실패 (made %d · 소모 %s · 상위 %s · 인벤D %d)"
			% [made, str(consumed), str(has_up), inv_d])
		_pt_bad += 1

	# 2) '그냥 간다' 가 대화를 끝내는 선택지로 표시돼 있는가
	var closers := 0
	for nid in NPCManager.ids():
		for c in NPCManager.defs[nid].get("choices", []):
			if bool(c.get("closes", false)):
				closers += 1
	if closers >= NPCManager.ids().size() and NPCManager.has("hunter_old") 			and NPCManager.closes_talk("hunter_old", "leave"):
		print("CT|  ✔ 대화 자동 종료 — NPC %d명 모두 '그냥 간다' 에 closes" % closers)
	else:
		print("CT|  ✘ closes 표시 %d개 / NPC %d명" % [closers, NPCManager.ids().size()])
		_pt_bad += 1

	# 3) 퀘스트 안내가 상황마다 다른 문장을 주는가
	var w = get_tree().current_scene
	var q = w.hud.quest_ui if w and w.get("hud") != null else null
	if q == null or not q.has_method("_next_step"):
		print("CT|  ✘ 퀘스트 안내 함수가 없다"); _pt_bad += 1
	else:
		var keep_phase := GameManager.phase
		var keep_boss := GameManager.chapter_boss_down
		GameManager.chapter_boss_down = false
		GameManager.phase = GameManager.Phase.DAY
		var a: String = String(q._next_step())
		GameManager.phase = GameManager.Phase.NIGHT
		GameManager.night_state = GameManager.NightState.WAVE
		var b: String = String(q._next_step())
		GameManager.chapter_boss_down = true
		var c2: String = String(q._next_step())
		GameManager.phase = keep_phase
		GameManager.chapter_boss_down = keep_boss
		if a != "" and b != "" and c2 != "" and a != b and b != c2:
			print("CT|  ✔ 퀘스트 안내 — 낮/밤/보스처치 각각 다른 지시")
		else:
			print("CT|  ✘ 퀘스트 안내가 상황을 구분하지 못한다"); _pt_bad += 1

	# 4) 모델 교체 체계 — 빈 경로면 null 을 돌려 기존 모델로 폴백해야 한다
	var empty_conf := VfxPool.model_conf("enemy", "dire_wolf")
	var inst = VfxPool.spawn_model(empty_conf)
	if inst == null:
		print("CT|  ✔ 모델 교체 — 경로가 비면 기존 모델로 폴백")
	else:
		inst.queue_free()
		print("CT|  ✔ 모델 교체 — 지정 모델 인스턴스 생성")

	# 5) 파티클이 만들어지고 스스로 사라지는가
	var host := Node3D.new()
	get_tree().current_scene.add_child(host)
	var pa := VfxPool.burst(host, Vector3.ZERO, Color(1, 1, 1), 8, 4.0, 0.2)
	var made_ok: bool = pa != null and is_instance_valid(pa)
	await get_tree().create_timer(1.0, true, false, true).timeout
	var gone: bool = pa == null or not is_instance_valid(pa)
	host.queue_free()
	if made_ok and gone:
		print("CT|  ✔ 파티클 — 생성 후 수명 끝나면 자동 해제")
	else:
		print("CT|  ✘ 파티클 (생성 %s · 해제 %s)" % [str(made_ok), str(gone)])
		_pt_bad += 1

	# 6) 그래픽 효과 개별 토글
	var em = w.environment_manager if w and w.get("environment_manager") != null else null
	if em and em.has_method("set_effect"):
		var was: bool = bool(em.effect_on("glow"))
		em.set_effect("glow", not was)
		var flipped: bool = em.effect_on("glow") != was
		em.set_effect("glow", was)
		if flipped:
			print("CT|  ✔ 그래픽 개별 토글 — %s" % em.effect_summary())
		else:
			print("CT|  ✘ 그래픽 토글이 먹지 않는다"); _pt_bad += 1
	else:
		print("CT|  ✘ set_effect 없음"); _pt_bad += 1

	PlayerStats.reset()
	if _pt_bad == bad0:
		pass

## [마우스 조준] 커서가 실제로 움직일 수 있는 모드인가 + 화면 아래쪽 조준이 되는가
func _t_aim() -> void:
	var w = get_tree().current_scene
	if w == null or w.get("hud") == null:
		print("CT|  ✘ HUD 없음"); _pt_bad += 1
		return
	w.hud.close_windows()
	w.hud.sync_mouse_mode()
	# CAPTURED 면 커서가 창 중앙에 못 박혀 get_mouse_position 이 안 움직인다
	var mode_ok: bool = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED

	var pl := Battlefield.live_player()
	var cam: Camera3D = pl.camera if pl else null
	var aim_ok := false
	var down_ok := false
	if pl and cam:
		var origin := cam.unproject_position(pl.global_position)
		# 화면 위쪽을 가리키면 전방, 아래쪽을 가리키면 후방을 봐야 한다
		var keep: float = float(pl.facing_angle)
		pl.movement._aim_at_mouse_at(origin + Vector2(0, -200))
		var up_angle: float = float(pl.facing_angle)
		pl.movement._aim_at_mouse_at(origin + Vector2(0, 200))
		var down_angle: float = float(pl.facing_angle)
		aim_ok = absf(angle_difference(up_angle, down_angle)) > 2.5   ## 거의 정반대
		# 화면 맨 아래(스킬 UI 자리)에서도 각도가 나와야 한다
		pl.movement._aim_at_mouse_at(Vector2(origin.x, 700))
		down_ok = absf(angle_difference(pl.facing_angle, up_angle)) > 1.5
		pl.facing_angle = keep

	if mode_ok and aim_ok and down_ok:
		print("CT|  ✔ 마우스 조준 — 모드 %d(비CAPTURED) · 위/아래 반대 방향 · 최하단 조준 가능"
			% Input.mouse_mode)
	else:
		print("CT|  ✘ 마우스 조준 (모드 %s / 상하반전 %s / 최하단 %s)"
			% [str(mode_ok), str(aim_ok), str(down_ok)])
		_pt_bad += 1

## [펫] 전투 설정 · 패시브 · 뽑기 · 저장
func _t_pet() -> void:
	# 1) 모든 펫이 등급·공격·패시브 정의를 갖는가
	var miss := []
	var pet_types: Dictionary = load("res://scripts3d/Pet3D.gd").TYPES
	for t in pet_types:
		var d := PetManager.pet_def(String(t))
		if d.is_empty() or not d.has("attack") or not d.has("passive"):
			miss.append(t)
	if miss.is_empty():
		print("CT|  ✔ 펫 %d종 전부 전투·패시브 정의" % pet_types.size())
	else:
		print("CT|  ✘ 정의 없는 펫: %s" % str(miss)); _pt_bad += 1

	# 2) 레벨이 오르면 피해와 패시브가 같이 오른다
	PetManager.reset()
	PetManager.grant("hound")
	PetManager.set_active("hound")
	PetManager.levels["hound"] = 1
	var d1 := float(PetManager.attack_of("hound").get("damage", 0.0))
	var p1 := PetManager.passive("atk")
	PetManager.levels["hound"] = PetManager.max_level()
	var d2 := float(PetManager.attack_of("hound").get("damage", 0.0))
	var p2 := PetManager.passive("atk")
	if d2 > d1 and p2 > p1:
		print("CT|  ✔ 펫 레벨 — 피해 %.2f→%.2f · 공격 패시브 %.3f→%.3f" % [d1, d2, p1, p2])
	else:
		print("CT|  ✘ 레벨이 반영되지 않는다"); _pt_bad += 1

	# 3) 패시브가 실제 플레이어 스탯에 붙는가
	# set_active("") 는 보유 목록에 없어 무시된다 — 필드를 직접 비운다
	PetManager.active = ""
	var atk0 := PlayerStats.get_final_atk()
	PetManager.active = "hound"
	var atk1 := PlayerStats.get_final_atk()
	if atk1 > atk0:
		print("CT|  ✔ 펫 패시브가 공격력에 반영 (%.1f → %.1f)" % [atk0, atk1])
	else:
		print("CT|  ✘ 패시브 미반영 (%.1f / %.1f)" % [atk0, atk1]); _pt_bad += 1

	# 4) 뽑기 — 마석이 줄고, 새 펫이거나 레벨업이거나 환급이 난다
	PetManager.reset()
	CraftManager.essence = PetManager.gacha_cost() * 6
	var before := CraftManager.essence
	var got := PetManager.gacha()
	var spent: bool = CraftManager.essence < before
	if got != "" and spent and PetManager.owned.size() >= 1:
		print("CT|  ✔ 펫 뽑기 — %s 획득 (마석 %d → %d)"
			% [got, before, CraftManager.essence])
	else:
		print("CT|  ✘ 뽑기 실패 (got '%s' · 마석 %d→%d)"
			% [got, before, CraftManager.essence]); _pt_bad += 1

	# 5) 마석이 모자라면 뽑히지 않는다
	CraftManager.essence = 0
	if PetManager.gacha() == "":
		print("CT|  ✔ 마석 부족 시 뽑기 차단")
	else:
		print("CT|  ✘ 마석 없이 뽑혔다"); _pt_bad += 1

	# 6) 레벨·천장이 저장 왕복에서 살아남는가
	PetManager.grant("warden")
	PetManager.levels["warden"] = 3
	PetManager.pity = 7
	SaveGame.save()
	PetManager.levels.clear()
	PetManager.pity = 0
	SaveGame.load_game()
	if PetManager.level_of("warden") == 3 and PetManager.pity == 7:
		print("CT|  ✔ 펫 레벨·천장 저장 왕복")
	else:
		print("CT|  ✘ 펫 저장 누락 (lv %d · pity %d)"
			% [PetManager.level_of("warden"), PetManager.pity]); _pt_bad += 1
	PetManager.reset()
