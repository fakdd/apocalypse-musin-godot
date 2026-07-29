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
	_check_models()
	_check_applied()

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

## data/models.json 의 경로가 실제로 열리는가 (파일 존재 + PackedScene 인스턴스화)
func _check_models() -> void:
	var m := VfxPool.models()
	var sections := {"enemies": m.get("enemies", {}), "props": m.get("props", {}),
		"weapons": m.get("weapons", {})}
	var total := 0
	var okc := 0
	var fails := []
	for sec in sections:
		for key in sections[sec]:
			var v = sections[sec][key]
			var path := ""
			if typeof(v) == TYPE_DICTIONARY:
				path = String(v.get("model", ""))
			elif typeof(v) == TYPE_STRING:
				path = String(v)
			if not path.begins_with("res://"):
				continue
			total += 1
			if not ResourceLoader.exists(path):
				fails.append("%s/%s 파일없음" % [sec, key])
				continue
			# .glb/.gltf 는 PackedScene, .obj 는 Mesh 로 들어온다 — 둘 다 받는다
			var node := VfxPool.load_model_node(path)
			if node == null:
				fails.append("%s/%s 로드실패" % [sec, key])
				continue
			node.queue_free()
			okc += 1
	if fails.is_empty():
		print("MAP|  ✔ 모델 매핑 %d개 전부 로드 성공" % okc)
	else:
		bad += 1
		print("MAP|  ✘ 모델 %d/%d 실패" % [fails.size(), total])
		for f in fails.slice(0, 8):
			print("MAP|      %s" % f)

## "다운로드한 것이 실제로 게임에 붙었는가" 를 확인한다.
## 경로가 있는 것과 화면에 나오는 것은 다르다 — 실제 생성 경로를 태워 본다.
func _check_applied() -> void:
	var probs := []

	# 1) 적 — 소환한 개체가 교체 모델을 쓰는가
	var w = get_tree().current_scene
	var host := Node3D.new()
	w.add_child(host)
	var swapped := 0
	var checked := 0
	for t in ["hound", "dire_wolf", "abyss_lord", "knight"]:
		var conf := VfxPool.model_conf("enemy", t)
		if String(conf.get("model", "")) == "":
			continue
		checked += 1
		var n := VfxPool.spawn_model(conf)
		if n != null:
			swapped += 1
			n.queue_free()
	if checked > 0 and swapped == checked:
		print("MAP|  ✔ 적 모델 교체 — 표본 %d종 전부 인스턴스 생성" % swapped)
	else:
		probs.append("적 모델 %d/%d" % [swapped, checked])

	# 2) 소품 — MultiMesh 가 쓸 Mesh 를 꺼낼 수 있는가
	var pm := 0
	var pt := 0
	for k in ["tree", "pine", "rock", "bush", "dead_tree"]:
		var path := String(VfxPool.models().get("props", {}).get(k, ""))
		if path == "":
			continue
		pt += 1
		if VfxPool.mesh_of(path).size() >= 2:
			pm += 1
	if pt > 0 and pm == pt:
		print("MAP|  ✔ 소품 모델 — %d종 전부 Mesh 추출 성공 (MultiMesh 사용 가능)" % pm)
	else:
		probs.append("소품 %d/%d" % [pm, pt])

	# 3) 무기 — 6계열 대표 스킨이 손에 붙을 Mesh 를 갖는가
	var wm := 0
	var wt := 0
	for k in ["blade_steel", "spear_rust", "saber_fang", "mace_steel",
			"dagger_rust", "bow_wooden" if false else "bow_steel"]:
		var path2 := String(VfxPool.models().get("weapons", {}).get(k, ""))
		if path2 == "":
			probs.append("무기 %s 매핑없음" % k)
			continue
		wt += 1
		if VfxPool.mesh_of(path2).size() >= 2:
			wm += 1
	if wt > 0 and wm == wt:
		print("MAP|  ✔ 무기 모델 — 6계열 전부 Mesh 추출 성공")
	else:
		probs.append("무기 %d/%d" % [wm, wt])

	# 4b) T포즈 방지 — 뼈대가 있는데 애니메이션이 없는 모델을 쓰고 있지 않은가
	var tpose := []
	for t in VfxPool.models().get("enemies", {}):
		if String(t) == "_default":
			continue
		var mp3 := String(VfxPool.models()["enemies"][t].get("model", ""))
		if mp3 == "":
			continue
		var n3 := VfxPool.load_model_node(mp3)
		if n3 == null:
			continue
		var has_skel := _has_skeleton(n3, 0)
		var has_anim := VfxPool.find_anim(n3) != null
		n3.queue_free()
		if has_skel and not has_anim:
			tpose.append("%s (%s)" % [t, mp3.get_file()])
	if tpose.is_empty():
		print("MAP|  ✔ T포즈 위험 없음 — 뼈대만 있고 애니 없는 모델 0")
	else:
		probs.append("T포즈 위험: %s" % str(tpose))

	# 4) 애니메이션 이름 매칭 — 접두사가 붙어도 잡아내는가
	var anim_ok := 0
	var anim_t := 0
	for t in ["demon", "fire_dragon", "abyss_lord", "hound"]:
		var conf2 := VfxPool.model_conf("enemy", t)
		var mp := String(conf2.get("model", ""))
		if mp == "":
			continue
		anim_t += 1
		var n2 := VfxPool.load_model_node(mp)
		if n2 == null:
			continue
		var ap := VfxPool.find_anim(n2)
		if ap == null:
			anim_ok += 1          ## 애니메이션이 없는 모델은 통과로 본다
		else:
			var names := ap.get_animation_list()
			var e2 = load("res://scripts3d/Enemy3D.gd").new()
			e2.anim = ap
			e2.animation = load("res://scripts3d/enemy/EnemyAnimation.gd").new()
			e2.animation.owner_enemy = e2
			e2.animation._resolve_anim_names()
			if e2.anim_idle != "" and e2.anim_death != "":
				anim_ok += 1
			else:
				probs.append("%s 애니 매칭 실패 (idle '%s' death '%s' / %s)"
					% [t, e2.anim_idle, e2.anim_death, str(names).substr(0, 50)])
			e2.animation.free()
			e2.free()
		n2.queue_free()
	if anim_t > 0 and anim_ok == anim_t:
		print("MAP|  ✔ 애니메이션 이름 매칭 %d종 (접두사 있는 클립 포함)" % anim_ok)

	host.queue_free()
	if probs.is_empty():
		print("MAP|  ✔ 다운로드 에셋이 실제 생성 경로까지 연결됨")
	else:
		bad += 1
		print("MAP|  ✘ 미연결: %s" % str(probs))

## 뼈대(Skeleton3D)가 들어 있는가.
## 뼈대가 있는데 애니메이션이 없으면 T포즈 그대로 미끄러져 다닌다.
func _has_skeleton(n: Node, depth: int) -> bool:
	if depth > 8 or n == null:
		return false
	if n is Skeleton3D:
		return true
	for c in n.get_children():
		if _has_skeleton(c, depth + 1):
			return true
	return false
