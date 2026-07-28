extends Node
## 에디터/디버그 빌드 전용 치트 콘솔.
##
## `OS.is_debug_build()` 가 아니면 스스로 사라진다 — 내보낸 배포판에는 없다.
## 자동 검증(--*test)이 도는 동안에도 켜지지 않는다.
##
## F1 을 누르면 도움말이 화면에 뜬다.

const HELP := [
	"F1  이 도움말",
	"F2  마석 +1000",
	"F3  레벨 +5",
	"F4  전 등급 아이템 한 벌 (F~SSS)",
	"F5  동행 뽑기 10연 (마석 무시)",
	"F6  현재 랜드마크 즉시 클리어",
	"F7  다음 챕터로 (보스 생략)",
	"F8  방주 무적 토글",
	"F9  플레이어 무적 토글",
	"F10 적 전멸",
	"F11 밤/낮 전환",
	"F12 그래픽 품질 순환",
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
	print("[Debug] 치트 콘솔 활성 — F1 로 목록")

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	match e.keycode:
		KEY_F1: _toggle_help()
		KEY_F2:
			CraftManager.add_essence(1000)
			_say("마석 +1000 (%d)" % CraftManager.essence)
		KEY_F3:
			for i in range(5):
				GameManager.add_exp(GameManager.exp_to_next())
			_say("레벨 %d" % GameManager.player_level)
		KEY_F4:
			for r in range(0, 9):
				PlayerStats.acquire_item(LootManager.generate_item(r))
			_say("아이템 9개 지급")
		KEY_F5:
			var keep := CraftManager.essence
			CraftManager.essence = PetManager.gacha_cost() * 10
			for i in range(10):
				PetManager.gacha()
			CraftManager.essence = keep
			_say("10연 뽑기 — 보유 %d종" % PetManager.owned.size())
		KEY_F6:
			var d: LandmarkData = _current_landmark()
			if d != null:
				LandmarkRegistry.force_clear(d.id)
				_say("%s 클리어" % d.display_name)
			else:
				_say("가까운 랜드마크가 없다")
		KEY_F7:
			GameManager.mark_chapter_boss_defeated()
			_say("보스 처치 처리 — 방주 앞 포탈 확인")
		KEY_F8:
			god_base = not god_base
			_say("방주 무적 %s" % ("ON" if god_base else "OFF"))
		KEY_F9:
			god_player = not god_player
			var pl := Battlefield.live_player()
			if pl:
				pl.invuln_timer = 99999.0 if god_player else 0.0
			_say("플레이어 무적 %s" % ("ON" if god_player else "OFF"))
		KEY_F10:
			var n := 0
			for en in Battlefield.enemies:
				if is_instance_valid(en) and not en.dead:
					en.take_damage(999999)
					n += 1
			_say("적 %d기 제거" % n)
		KEY_F11:
			var w = get_tree().current_scene
			if w:
				if GameManager.phase == GameManager.Phase.DAY:
					if w.has_method("_start_night_phase"):
						w._start_night_phase()
				else:
					GameManager.phase_timer = 0.1
			_say("페이즈 전환")
		KEY_F12:
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
