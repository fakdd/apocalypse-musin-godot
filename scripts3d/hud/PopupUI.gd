extends Node
class_name PopupUI
## 전면 팝업 담당 — 배너, 토스트, 튜토리얼, 게임 오버, 승리 화면과 재시작 처리.

var owner_hud: CanvasLayer

## 튜토리얼을 닫을 준비가 됐는가 (한 번이라도 입력을 뗀 적이 있는가).
## HUD 와 함께 씬마다 새로 만들어지므로 재시작 시 자동으로 초기화된다.
var _tutorial_armed := false

func setup(h: CanvasLayer) -> void:
	owner_hud = h

func build_banner() -> void:
	var hud := owner_hud
	hud.banner_label = Label.new()
	hud.banner_label.add_theme_font_size_override("font_size", 32)
	hud.banner_label.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	hud.banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.banner_label.position = Vector2(0, 250)
	hud.banner_label.size = Vector2(1280, 60)
	hud.banner_label.modulate.a = 0.0
	hud.banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud.banner_label)

func build_toast() -> void:
	var hud := owner_hud
	hud.toast = Label.new()
	hud.toast.add_theme_font_size_override("font_size", 19)
	# 화면 정중앙(y=320)에 뜨면 전투 시야를 통째로 가린다 — 우측 상단으로 옮긴다.
	hud.toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.toast.position = Vector2(640, 300)
	hud.toast.size = Vector2(626, 30)
	hud.toast.modulate.a = 0.0
	hud.toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud.toast)

	LootManager.item_collected.connect(func(it): hud.show_toast("%s 획득" % it.get_display_name(), it.get_color()))
	GameManager.level_up.connect(_on_level_up)
	PlayerStats.item_equipped.connect(func(it, _s): hud.show_toast("%s 장착!" % it.get_display_name(), it.get_color()))

func show_banner(text: String) -> void:
	var hud := owner_hud
	hud.banner_label.text = text
	hud.banner_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(hud.banner_label, "modulate:a", 0.0, 0.7)

func show_toast(text: String, col: Color = Color.WHITE) -> void:
	var hud := owner_hud
	hud.toast.text = text
	hud.toast.add_theme_color_override("font_color", col)
	hud.toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(hud.toast, "modulate:a", 0.0, 0.6)

func build_tutorial() -> void:
	var hud := owner_hud
	hud.tutorial_panel = Control.new()
	hud.tutorial_panel.visible = false
	hud.tutorial_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(hud.tutorial_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.02, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.tutorial_panel.add_child(bg)

	var lbl := Label.new()
	lbl.text = _intro_text()
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.position = Vector2(180, 120)
	lbl.size = Vector2(920, 480)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	hud.tutorial_panel.add_child(lbl)

## 챕터 이동용 로딩 화면. 게임오버 패널과 같은 방식으로 만든다.
func build_loading() -> void:
	var hud := owner_hud
	hud.loading_panel = Control.new()
	hud.loading_panel.visible = false
	hud.loading_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.loading_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud.loading_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.02, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.loading_panel.add_child(bg)

	hud.loading_label = Label.new()
	hud.loading_label.add_theme_font_size_override("font_size", 34)
	hud.loading_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	hud.loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.loading_label.position = Vector2(0, 320)
	hud.loading_label.size = Vector2(1280, 50)
	hud.loading_panel.add_child(hud.loading_label)

func show_loading(text: String) -> void:
	owner_hud.loading_panel.visible = true
	owner_hud.loading_label.text = text

func build_game_over() -> void:
	var hud := owner_hud
	hud.game_over_panel = Control.new()
	hud.game_over_panel.visible = false
	hud.game_over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(hud.game_over_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0, 0, 0.84)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.game_over_panel.add_child(bg)

	hud.game_over_label = Label.new()
	hud.game_over_label.add_theme_font_size_override("font_size", 46)
	hud.game_over_label.add_theme_color_override("font_color", Color(1, 0.25, 0.25))
	hud.game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.game_over_label.position = Vector2(0, 250)
	hud.game_over_label.size = Vector2(1280, 60)
	hud.game_over_panel.add_child(hud.game_over_label)

	var btn := Button.new()
	btn.text = "다시 도전 (R)"
	btn.position = Vector2(565, 350)
	btn.size = Vector2(150, 42)
	btn.pressed.connect(restart)
	hud.game_over_panel.add_child(btn)

func build_victory() -> void:
	var hud := owner_hud
	hud.victory_panel = Control.new()
	hud.victory_panel.visible = false
	hud.victory_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(hud.victory_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.victory_panel.add_child(bg)

	var title := Label.new()
	title.text = "TRUE ENDING"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", hud.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 150)
	title.size = Vector2(1280, 70)
	hud.victory_panel.add_child(title)

	var body := Label.new()
	body.text = "최후의 외계 군주가 쓰러졌다.\n차원의 문이 완전히 닫히고, 핏빛 하늘이 걷힌다.\n\n\"이 멸망한 세계 위에… 다시는 무너지지 않을 우리들의 제국을 세운다.\"\n\n강백현은 검을 거두었다. 전설은 여기서 시작된다."
	body.add_theme_font_size_override("font_size", 19)
	body.add_theme_color_override("font_color", Color(0.88, 0.86, 0.88))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.position = Vector2(240, 250)
	body.size = Vector2(800, 210)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	hud.victory_panel.add_child(body)

	var btn := Button.new()
	btn.text = "새로운 삶 (R)"
	btn.position = Vector2(565, 500)
	btn.size = Vector2(150, 44)
	btn.pressed.connect(restart)
	hud.victory_panel.add_child(btn)

func show_victory() -> void:
	# 제단·대화창은 PopupUI 보다 뒤에 add_child 되어 더 위에 그려진다.
	# 열어둔 채 죽거나 이기면 결과 화면이 그 아래에 가려진다.
	owner_hud.close_windows()
	owner_hud.victory_panel.visible = true
	SoundManager.play("ultimate", -10.0)

func show_game_over(reason: String) -> void:
	SoundManager.play("game_over", -8.0)
	owner_hud.close_windows()
	owner_hud.game_over_panel.visible = true
	owner_hud.game_over_label.text = "방주 함락" if reason == "base" else "패배"

func restart() -> void:
	GameManager.reset_all()
	TraitManager.reset()
	PlayerStats.reset()
	CraftManager.reset()
	PetManager.reset()
	# 오토로드는 씬을 다시 읽어도 살아남는다. 아래 둘을 빼먹으면 두 번째 판이 망가진다.
	#   LandmarkRegistry — 완료 퀘스트·탐험/클리어 기록이 남아 캠페인 잠금이 전부 풀린 채
	#                      시작하고, 모든 랜드마크가 이미 "클리어" 상태가 된다.
	#   DemoDirector    — boss_spawned 가 true 로 남아 데모 보스가 다시 나오지 않는다.
	LandmarkRegistry.reset()
	DemoDirector.reset()
	# CombatFeel.reset() 은 "씬 재시작 시" 를 위해 만들어졌는데 불리지 않고 있었다.
	# time_scale 만 1.0 으로 되돌리면 남아 있던 슬로모션 타이머가 다음 프레임에
	# 다시 배율을 덮어써, 새 판이 슬로모션으로 시작한다 (죽는 순간은 대개 슬로모션 중이다).
	# 화면에 깔린 플래시 사각형도 여기서 지운다.
	CombatFeel.reset()
	Battlefield.reset()
	# 세이브도 지운다 — 안 지우면 다음 부팅 때 죽기 직전 상태를 다시 읽는다
	SaveGame.wipe()
	get_tree().reload_current_scene()

## 매 프레임 팝업 입력 처리. 팝업이 입력을 소비했으면 true 를 반환한다.
func handle_popup_input() -> bool:
	var hud := owner_hud
	if hud.tutorial_panel.visible:
		var pressed := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) \
			or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D) \
			or Input.is_key_pressed(KEY_SPACE) \
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		# 키를 한 번 뗀 뒤에야 닫히게 한다.
		# 특성 화면은 Space 로도 시작되는데(TraitScreen._input), 그 Space 가 아직
		# 눌린 채로 같은 프레임에 여기까지 온다. 그대로 두면 튜토리얼이 뜨자마자
		# 닫혀서, 조작법을 알려주는 유일한 화면을 한 번도 못 본다.
		if not pressed:
			_tutorial_armed = true
		elif _tutorial_armed:
			hud.tutorial_panel.visible = false
		return true

	if (hud.game_over_panel.visible or hud.victory_panel.visible) and Input.is_key_pressed(KEY_R):
		restart()
		return true

	return false

## 레벨업 — 지금까지 소리만 났다. 화면 연출을 붙여 보상감을 준다.
func _on_level_up(lv: int) -> void:
	CombatFeel.impact("level_up")
	owner_hud.show_banner("\u2726 레벨 %d" % lv)

## 챕터별 안내 문구 (data/menu.json 의 intro).
##
## 예전에는 "1일차 — 폐허 탐험" 한 덩어리가 하드코딩돼 있어,
## 다음 지역으로 넘어가도 같은 설명이 떴다. 조작은 공통, 제목과 한 줄만 바뀐다.
func _intro_text() -> String:
	var m = owner_hud.get("menu_ui")
	var defs: Dictionary = m.defs() if m != null else {}
	var intro: Dictionary = defs.get("intro", {})
	var ch := str(GameManager.chapter)
	var c: Dictionary = intro.get("chapters", {}).get(ch, {})
	var title := String(c.get("title", ChapterConfig.name_of(GameManager.chapter)))
	var line := String(c.get("line", ""))
	var common := String(intro.get("common", ""))
	if common == "":
		return "%s

%s

[ 아무 키나 눌러 시작 ]" % [title, line]
	return "%s
%s

%s" % [title, line, common]
