extends Node
## 에디터/디버그 빌드 전용 치트 콘솔.
##
## `OS.is_debug_build()` 가 아니면 스스로 사라진다 — 내보낸 배포판에는 없다.
## 자동 검증(--*test)이 도는 동안에도 켜지지 않는다.
##
## Ctrl + \` 를 누르면 도움말이 화면에 뜬다.
##
## F 키를 쓰지 않는 이유 —
##   에디터에서 F5(실행) · F6(현재 씬 실행) · F8(중지) 이 이미 잡혀 있다.
##   게임 창이 떠 있어도 에디터가 먼저 받아, F8 을 누르면 게임이 그냥 꺼졌다.
##   그래서 게임이 쓰지 않고 에디터와도 겹치지 않는 Ctrl + 숫자로 옮겼다.

const HELP := [
	"Ctrl+`  이 도움말",
	"Ctrl+1  마석 +1000",
	"Ctrl+2  레벨 +5",
	"Ctrl+3  전 등급 아이템 한 벌 (F~SSS)",
	"Ctrl+4  동행 뽑기 10연 (마석 무시)",
	"Ctrl+5  현재 랜드마크 즉시 클리어",
	"Ctrl+6  다음 챕터로 (보스 생략)",
	"Ctrl+7  방주 무적 토글",
	"Ctrl+8  플레이어 무적 토글",
	"Ctrl+9  적 전멸",
	"Ctrl+0  밤/낮 전환",
	"Ctrl+-  그래픽 품질 순환",
]

var god_player := false
var god_base := false
var _label: Label = null

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	for a in OS.get_cmdline_user_args():
		if String(a).ends_with("test") or String(a) == "--playtest":
			queue_free()          ## 자동 검증 중에는 끼어들지 않는다
			return
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	print("[Debug] 치트 콘솔 활성 — Ctrl+` 로 목록 (F키는 에디터가 가져간다)")

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	# Ctrl 을 함께 눌러야 동작한다 — 일반 조작과 절대 겹치지 않게
	if not e.ctrl_pressed:
		return
	get_viewport().set_input_as_handled()
	match e.keycode:
		KEY_QUOTELEFT: _toggle_help()
		KEY_1:
			CraftManager.add_essence(1000)
			_say("마석 +1000 (%d)" % CraftManager.essence)
		KEY_2:
			for i in range(5):
				GameManager.add_exp(GameManager.exp_to_next())
			_say("레벨 %d" % GameManager.player_level)
		KEY_3:
			# acquire_item 은 더 좋으면 곧바로 장착한다 — 9번 연속이면
			# 무기 모델을 9번 갈아 끼우고 토스트도 9번 뜬다. 인벤토리에만 넣는다.
			for r in range(0, 9):
				PlayerStats.inventory.append(LootManager.generate_item(r))
			PlayerStats.inventory_changed.emit()
			_say("아이템 9개 지급 (I 로 확인)")
		KEY_4:
			var keep := CraftManager.essence
			CraftManager.essence = PetManager.gacha_cost() * 10
			for i in range(10):
				PetManager.gacha()
			CraftManager.essence = keep
			_say("10연 뽑기 — 보유 %d종" % PetManager.owned.size())
		KEY_5:
			var d: LandmarkData = _current_landmark()
			if d != null:
				LandmarkRegistry.force_clear(d.id)
				_say("%s 클리어" % d.display_name)
			else:
				_say("가까운 랜드마크가 없다")
		KEY_6:
			GameManager.mark_chapter_boss_defeated()
			_say("보스 처치 처리 — 방주 앞 포탈 확인")
		KEY_7:
			god_base = not god_base
			_say("방주 무적 %s" % ("ON" if god_base else "OFF"))
		KEY_8:
			god_player = not god_player
			var pl := Battlefield.live_player()
			if pl:
				pl.invuln_timer = 99999.0 if god_player else 0.0
			_say("플레이어 무적 %s" % ("ON" if god_player else "OFF"))
		KEY_9:
			var n := 0
			for en in Battlefield.enemies:
				if is_instance_valid(en) and not en.dead:
					en.take_damage(999999)
					n += 1
			_say("적 %d기 제거" % n)
		KEY_0:
			var w = get_tree().current_scene
			if w:
				if GameManager.phase == GameManager.Phase.DAY:
					if w.has_method("_start_night_phase"):
						w._start_night_phase()
				else:
					GameManager.phase_timer = 0.1
			_say("페이즈 전환")
		KEY_MINUS:
			SaveGame.graphics = (SaveGame.graphics + 1) % EnvironmentManager.level_count()
			var w2 = get_tree().current_scene
			if w2 and w2.get("environment_manager") != null:
				w2.environment_manager.apply_quality(SaveGame.graphics)
				_say("그래픽 — %s" % w2.environment_manager.effect_summary())

func _process(_d: float) -> void:
	if god_player:
		var pl := Battlefield.live_player()
		if pl:
			pl.invuln_timer = maxf(pl.invuln_timer, 5.0)
	if god_base:
		GameManager.base_hp = GameManager.base_max_hp

func _current_landmark() -> LandmarkData:
	var pl := Battlefield.live_player()
	if pl == null:
		return null
	var best: LandmarkData = null
	var bd := 18.0
	for d in LandmarkRegistry.landmarks:
		var dist: float = pl.global_position.distance_to(d.center)
		if dist < bd:
			bd = dist
			best = d
	return best

func _say(msg: String) -> void:
	print("[Debug] %s" % msg)
	var w = get_tree().current_scene
	if w and w.get("hud") != null and w.hud.has_method("show_toast"):
		w.hud.show_toast("⚙ %s" % msg, Color(0.6, 1.0, 0.8))

func _toggle_help() -> void:
	var w = get_tree().current_scene
	if w == null or w.get("hud") == null:
		return
	if _label != null and is_instance_valid(_label):
		_label.queue_free()
		_label = null
		return
	_label = Label.new()
	_label.text = "── 디버그 (디버그 빌드 전용) ──\n" + "\n".join(HELP)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
	_label.position = Vector2(24, 120)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.hud.add_child(_label)
