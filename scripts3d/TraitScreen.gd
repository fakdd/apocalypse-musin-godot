extends CanvasLayer
## 시작 화면 — 특성을 뽑고, 마음에 들지 않으면 '새로 태어나기'로 리롤한다.

signal started

var panel: Control
var rarity_label: Label
var name_label: Label
var desc_label: Label
var stat_label: Label
var reroll_label: Label
var reborn_btn: Button
var trial_btn: Button
var trial_label: Label
var start_btn: Button
var glow: ColorRect

func _ready() -> void:
	layer = 20
	_build()
	TraitManager.trait_changed.connect(_on_trait_changed)
	if not TraitManager.has_trait():
		TraitManager.roll_random_trait()
	else:
		_on_trait_changed(TraitManager.current_trait)

func _build() -> void:
	panel = Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.02, 0.93)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)

	glow = ColorRect.new()
	glow.color = Color(1, 1, 1, 0.0)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(glow)

	var title := Label.new()
	title.text = "각성 — 당신의 특성"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 90)
	title.size = Vector2(1280, 40)
	panel.add_child(title)

	rarity_label = Label.new()
	rarity_label.add_theme_font_size_override("font_size", 96)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.position = Vector2(0, 155)
	rarity_label.size = Vector2(1280, 120)
	panel.add_child(rarity_label)

	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 46)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(0, 280)
	name_label.size = Vector2(1280, 60)
	panel.add_child(name_label)

	desc_label = Label.new()
	desc_label.add_theme_font_size_override("font_size", 18)
	desc_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.76))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.position = Vector2(240, 350)
	desc_label.size = Vector2(800, 60)
	panel.add_child(desc_label)

	stat_label = Label.new()
	stat_label.add_theme_font_size_override("font_size", 22)
	stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_label.position = Vector2(0, 425)
	stat_label.size = Vector2(1280, 90)
	panel.add_child(stat_label)

	reroll_label = Label.new()
	reroll_label.add_theme_font_size_override("font_size", 15)
	reroll_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	reroll_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reroll_label.position = Vector2(0, 525)
	reroll_label.size = Vector2(1280, 30)
	panel.add_child(reroll_label)

	reborn_btn = Button.new()
	reborn_btn.text = "새로 태어나기 (R)"
	reborn_btn.position = Vector2(300, 570)
	reborn_btn.size = Vector2(180, 48)
	reborn_btn.pressed.connect(_on_reborn)
	panel.add_child(reborn_btn)

	trial_btn = Button.new()
	trial_btn.text = "운명 시험 10만회 (T)"
	trial_btn.position = Vector2(494, 570)
	trial_btn.size = Vector2(210, 48)
	trial_btn.pressed.connect(_on_trial)
	panel.add_child(trial_btn)

	start_btn = Button.new()
	start_btn.text = "이 몸으로 시작 (Enter)"
	start_btn.position = Vector2(708, 570)
	start_btn.size = Vector2(200, 48)
	start_btn.pressed.connect(_on_start)
	panel.add_child(start_btn)

	trial_label = Label.new()
	trial_label.add_theme_font_size_override("font_size", 13)
	trial_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.7))
	trial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trial_label.position = Vector2(0, 672)
	trial_label.size = Vector2(1280, 50)
	panel.add_child(trial_label)

	var hint := Label.new()
	hint.text = "F 58% · E 25% · D 11% · C 4% · B 1.5% · A 0.4% · S 0.09% · SS 0.0099% · SSS 0.0001%
SSS는 100만분의 1 — 운명 시험(10만회)으로도 약 10%, 아이템 합성이 더 현실적입니다"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 628)
	hint.size = Vector2(1280, 40)
	panel.add_child(hint)

func _on_trait_changed(t: Dictionary) -> void:
	if t.is_empty():
		return
	var r: int = int(t.get("rarity", 0))
	var col: Color = RarityEnums.get_rarity_color(r)

	rarity_label.text = RarityEnums.get_rarity_name(r)
	rarity_label.add_theme_color_override("font_color", col)
	name_label.text = String(t.get("name", ""))
	name_label.add_theme_color_override("font_color", col)
	desc_label.text = String(t.get("desc", ""))

	stat_label.text = "공격력 %+.0f%%    이동속도 %+.0f%%    아이템 드랍률 %+.0f%%" % [
		float(t.get("atk_pct", 0.0)), float(t.get("speed_pct", 0.0)), float(t.get("drop_pct", 0.0))
	]
	stat_label.add_theme_color_override("font_color", col.lightened(0.25))

	if TraitManager.reroll_count > 0:
		reroll_label.text = "%d번 다시 태어났다" % TraitManager.reroll_count
	else:
		reroll_label.text = ""

	# 고등급일수록 화면이 번쩍인다
	var flash_strength: float = clampf(float(r) / 8.0, 0.05, 0.55)
	glow.color = Color(col.r, col.g, col.b, flash_strength)
	var tw := create_tween()
	tw.tween_property(glow, "color:a", 0.0, 0.5 + flash_strength)

	rarity_label.scale = Vector2(0.6, 0.6)
	rarity_label.pivot_offset = Vector2(640, 60)
	var tw2 := create_tween()
	tw2.tween_property(rarity_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if r >= RarityEnums.Rarity.S:
		SoundManager.play("ultimate", -16.0)
	else:
		SoundManager.play("build", -20.0)

func _on_reborn() -> void:
	trial_label.text = ""
	TraitManager.reroll_trait()

func _on_trial() -> void:
	TraitManager.roll_best_of(100000)
	var t: Dictionary = TraitManager.last_trial
	if t.is_empty():
		return
	var counts: Dictionary = t.get("counts", {})
	# 등급 순서대로 정렬해 표시
	var parts := []
	for r in range(RarityEnums.Rarity.SSS, RarityEnums.Rarity.F - 1, -1):
		var n := RarityEnums.get_rarity_name(r)
		if counts.has(n):
			parts.append("%s:%d" % [n, counts[n]])
	trial_label.text = "10만회 결과 — 최고 등급 %s (%d회 등장)\n%s" % [
		RarityEnums.get_rarity_name(int(t.get("best_rarity", 0))),
		int(t.get("best_count", 0)),
		"  ".join(parts)
	]

func _on_start() -> void:
	panel.visible = false
	started.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if not visible or panel == null or not panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_on_reborn()
		elif event.keycode == KEY_T:
			_on_trial()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_on_start()
