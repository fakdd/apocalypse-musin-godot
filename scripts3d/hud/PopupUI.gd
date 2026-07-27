extends Node
class_name PopupUI
## 전면 팝업 담당 — 배너, 토스트, 튜토리얼, 게임 오버, 승리 화면과 재시작 처리.

var owner_hud: CanvasLayer

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
	hud.toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.toast.position = Vector2(0, 320)
	hud.toast.size = Vector2(1280, 30)
	hud.toast.modulate.a = 0.0
	hud.toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud.toast)

	LootManager.item_collected.connect(func(it): hud.show_toast("%s 획득" % it.get_display_name(), it.get_color()))
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
	lbl.text = "1일차 — 폐허 탐험\n\n[낮] 폐허에서 빛나는 유물(F~SSS급)을 회수하고 생존자를 구하세요. 가까이 가서 E.\n중앙 안전지대의 마도 제단에서 F 키로 마석 40을 써 특성을 다시 뽑을 수 있습니다.\n\n[밤] 차원의 균열에서 괴수가 쏟아집니다. 밤은 여러 웨이브로 나뉘고 사이에 정비 시간이 있습니다.\n좌클릭 검기(3타 콤보) · Space 점프 · Shift 신법 · Q 만천화우 · E 기공파 · F 반로환동\n\n※ 바닥에 붉은 예고선이 보이면 돌진입니다 — Shift로 피하세요.\n※ 정비 시간: N 다음 웨이브 즉시 시작 / K 밤 넘기기(방주 HP 소모)\n※ Tab 스탯창 · I 인벤토리(합성·강화)
※ [P] 키로 동행 펫 교체 — 펫이 떨어진 아이템을 자동으로 주워옵니다.
   펫은 보스를 잡을 때마다 새 종류가 해금됩니다 (현재 보유한 것들 사이에서 순환).\n\n밤을 버텨낼 때마다 균열이 하나 봉인됩니다. 5개를 모두 봉인하면 최후의 군주가 강림합니다.\n\n[ 이동/공격 아무 키나 눌러 시작 ]"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.position = Vector2(180, 120)
	lbl.size = Vector2(920, 480)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	hud.tutorial_panel.add_child(lbl)

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
	owner_hud.victory_panel.visible = true
	SoundManager.play("ultimate", -10.0)

func show_game_over(reason: String) -> void:
	SoundManager.play("game_over", -8.0)
	owner_hud.game_over_panel.visible = true
	owner_hud.game_over_label.text = "방주 함락" if reason == "base" else "패배"

func restart() -> void:
	GameManager.reset_all()
	TraitManager.reset()
	PlayerStats.reset()
	CraftManager.reset()
	PetManager.reset()
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

## 매 프레임 팝업 입력 처리. 팝업이 입력을 소비했으면 true 를 반환한다.
func handle_popup_input() -> bool:
	var hud := owner_hud
	if hud.tutorial_panel.visible:
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_S) \
			or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_SPACE) \
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			hud.tutorial_panel.visible = false
		return true

	if (hud.game_over_panel.visible or hud.victory_panel.visible) and Input.is_key_pressed(KEY_R):
		restart()
		return true

	return false
