extends Node
## 챕터별 실전 스모크 테스트.
##   godot --audio-driver Dummy --quit-after 6000 -- --maptest
##
## 각 챕터에서 실제로 쓰이는 몬스터를 전부 소환하고, 대표 행동·보스 패턴을
## 강제로 한 번씩 돌려 본다. 사막에서만 터졌던 `_flash` 류의 결함을
## 나머지 6개 챕터에서도 미리 잡는 것이 목적이다.

var _f := 0
var _on := false
var bad := 0
var _errors: Array = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a) == "--maptest":
			_on = true
	if not _on:
		queue_free()
		return
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
	var w = get_tree().current_scene
	if w and w.get("hud") != null and w.hud.get("menu_ui") != null \
			and w.hud.menu_ui.is_open():
		w.hud.menu_ui.close()
	get_tree().paused = false
	print("MAP| ══ 챕터별 스모크 ══")

	var host := Node3D.new()
	w.add_child(host)

	for ch in range(ChapterConfig.FIRST, ChapterConfig.LAST + 1):
		await _chapter(ch, w, host)

	host.queue_free()
	print("MAP| " + ("✔ 전 챕터 이상 없음" if bad == 0 else "✘ 문제 %d건" % bad))
	for e in _errors:
		print("MAP|   %s" % e)
	print("MAP| DONE")

func _chapter(ch: int, w, host: Node3D) -> void:
	GameManager.chapter = ch
	var name := ChapterConfig.name_of(ch)
	var mons: Array = ChapterConfig.monsters_of(ch)
	var boss := ChapterConfig.boss_of(ch)

	# ── 1) 이 챕터가 쓰는 몬스터가 전부 정의돼 있는가 ──
	var missing := []
	for m in mons:
		if not EnemyConfig.TYPES.has(String(m)):
			missing.append(m)
	if not EnemyConfig.TYPES.has(boss):
		missing.append("boss:" + boss)
	if not missing.is_empty():
		_fail("%d장 %s — 정의 없는 몬스터 %s" % [ch, name, str(missing)])
		return

	# ── 2) 실제로 소환해 대표 행동을 돌려 본다 ──
	var made := []
	for m in mons:
		var e = w._make_enemy(String(m), host.global_position + Vector3(randf() * 6.0, 0, randf() * 6.0))
		if e == null:
			_fail("%d장 %s — %s 소환 실패" % [ch, name, m])
			continue
		made.append(e)

	var b = w._make_enemy(boss, host.global_position + Vector3(0, 0, 8))
	if b != null:
		made.append(b)

	await get_tree().physics_frame
	await get_tree().physics_frame

	# 대표 행동을 강제로 한 번씩 (치유/강화/폭발/분열/부활/장판/유도)
	for e in made:
		if not is_instance_valid(e) or e.brain == null:
			continue
		e.brain.refresh_profile()
		e.brain.sig_cd = 0.0
		e.brain._tick_signature(0.016)
		e.brain.try_dodge(host.global_position)

	# 보스 페이즈 3단계를 전부 밟는다 (연출·소환·장판까지)
	if b != null and is_instance_valid(b):
		for ratio in [0.9, 0.5, 0.1]:
			b.hp = b.max_hp * ratio
			b.brain._update_boss_phase()
			b.brain.nova_cd = 0.0
			b.brain.sweep_cd = 0.0
			b.brain.slam_cd = 0.0
			b.brain.summon_cd = 0.0
			b.brain.homing_cd = 0.0
			b.brain.field_cd = 0.0
			b.brain._try_boss_pattern(6.0, Vector3(0, 0, 1))
			await get_tree().physics_frame

	# ── 3) 죽는 순간 행동 (폭발·분열·부활) ──
	for e in made:
		if is_instance_valid(e) and not e.dead:
			e.take_damage(999999.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# ── 4) 캠페인 데이터가 열리는가 ──
	var camp = CampaignData.load_campaign(ChapterConfig.campaign_of(ch))
	if camp == null:
		_fail("%d장 %s — 캠페인 로드 실패" % [ch, name])
		return
	var areas := camp.all_areas()
	var kinds := {}
	for a in areas:
		kinds[String(a.area_kind)] = int(kinds.get(String(a.area_kind), 0)) + 1

	# ── 5) 바이옴·테마·BGM 이 있는가 ──
	var biome := ChapterConfig.biome_of(ch)
	var bgm := SoundManager.chapter_bgm(ch)
	var probs := []
	if biome.is_empty():
		probs.append("바이옴 없음")
	if bgm == "" or String(SoundManager.audio_defs.get("bgm", {}).get(bgm, "")) == "":
		probs.append("BGM 없음(%s)" % bgm)
	if not probs.is_empty():
		_fail("%d장 %s — %s" % [ch, name, str(probs)])
		return

	print("MAP|  ✔ %d장 %-8s 몹%d 보스%s 영역%d %s" % [
		ch, name, mons.size(), boss, areas.size(), str(kinds)])

func _fail(msg: String) -> void:
	bad += 1
	_errors.append(msg)
	print("MAP|  ✘ %s" % msg)
