extends CanvasLayer
## 스탯창 (Tab) — 특성·장비·최종 스탯을 한눈에 보여준다.

var panel: Control
var trait_box: RichTextLabel
var gear_box: RichTextLabel
var total_box: RichTextLabel
var inv_box: RichTextLabel

func _ready() -> void:
	layer = 15
	_build()
	visible = false
	PlayerStats.stats_changed.connect(_refresh)
	PlayerStats.inventory_changed.connect(_refresh)
	TraitManager.trait_changed.connect(func(_t): _refresh())

func _build() -> void:
	panel = Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)

	var title := Label.new()
	title.text = "스탯 정보"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 30)
	title.size = Vector2(1280, 40)
	panel.add_child(title)

	trait_box = _make_box("특성", Vector2(80, 90), Vector2(540, 210))
	total_box = _make_box("최종 스탯", Vector2(660, 90), Vector2(540, 210))
	gear_box = _make_box("장착 장비", Vector2(80, 320), Vector2(540, 250))
	inv_box = _make_box("보관함", Vector2(660, 320), Vector2(540, 250))

	var hint := Label.new()
	hint.text = "Tab 또는 ESC 로 닫기"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 600)
	hint.size = Vector2(1280, 24)
	panel.add_child(hint)

func _make_box(header: String, pos: Vector2, size: Vector2) -> RichTextLabel:
	var frame := ColorRect.new()
	frame.color = Color(0.08, 0.08, 0.12, 0.9)
	frame.position = pos
	frame.size = size
	panel.add_child(frame)

	var lbl := Label.new()
	lbl.text = header
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.9))
	lbl.position = pos + Vector2(14, 8)
	lbl.size = Vector2(size.x - 28, 26)
	panel.add_child(lbl)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.scroll_active = true
	body.position = pos + Vector2(14, 38)
	body.size = Vector2(size.x - 28, size.y - 50)
	body.add_theme_font_size_override("normal_font_size", 15)
	panel.add_child(body)
	return body

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()

func _refresh() -> void:
	if trait_box == null:
		return

	# ── 특성 ──
	if TraitManager.has_trait():
		var r: int = TraitManager.get_trait_rarity()
		var col: Color = RarityEnums.get_rarity_color(r)
		var hexc: String = col.to_html(false)
		trait_box.text = "[color=#%s][b]%s %s[/b][/color]\n[color=#8a8a92]%s[/color]\n\n%s\n%s\n%s" % [
			hexc, RarityEnums.get_rarity_tag(r), TraitManager.get_trait_name(),
			TraitManager.get_trait_desc(),
			_stat_line("공격력 증가율", TraitManager.get_atk_pct(), "%"),
			_stat_line("이동속도 증가율", TraitManager.get_speed_pct(), "%"),
			_stat_line("아이템 드랍률", TraitManager.get_drop_pct(), "%"),
		]
	else:
		trait_box.text = "[color=#8a8a92]특성 없음[/color]"

	# ── 최종 스탯 (계산식 포함) ──
	var base_atk := PlayerStats.BASE_ATK
	var item_atk := PlayerStats.get_item_atk()
	var atk_mult := 1.0 + TraitManager.get_atk_pct() / 100.0
	var base_spd := PlayerStats.BASE_SPEED
	var item_spd := PlayerStats.get_item_speed()
	var spd_mult := 1.0 + TraitManager.get_speed_pct() / 100.0

	total_box.text = "[color=#ffd479][b]공격력  %.1f[/b][/color]\n[color=#7a7a84]  (기본 %.0f + 장비 %.0f) × %.2f[/color]\n\n[color=#8fd4ff][b]이동속도  %.2f[/b][/color]\n[color=#7a7a84]  (기본 %.1f + 장비 %.2f) × %.2f[/color]\n\n[color=#ff9a9a][b]최대 체력  %.0f[/b][/color]\n[color=#7a7a84]  기본 %.0f + 생존자 보너스 %d[/color]\n\n[color=#c8ffc8]검기 1타 데미지  %.1f[/color]" % [
		PlayerStats.get_final_atk(), base_atk, item_atk, atk_mult,
		PlayerStats.get_final_speed(), base_spd, item_spd, spd_mult,
		PlayerStats.get_final_max_hp(), PlayerStats.BASE_HP, GameManager.bonus_max_hp,
		PlayerStats.get_slash_damage(),
	]

	# ── 장착 장비 ──
	var slot_names := {"weapon": "무기", "armor": "방어구", "relic": "유물"}
	var lines := []
	for slot in ["weapon", "armor", "relic"]:
		var it: ItemData = PlayerStats.equipped.get(slot, null)
		if it == null:
			lines.append("[color=#5a5a62]%s — 없음[/color]" % slot_names[slot])
		else:
			var c: String = it.get_color().to_html(false)
			lines.append("[color=#%s]%s  %s[/color]\n[color=#7a7a84]   %s — 공격 +%.0f · 속도 +%.2f[/color]" % [
				c, RarityEnums.get_rarity_tag(it.rarity), it.name,
				slot_names[slot], it.atk_bonus, it.speed_bonus
			])
	gear_box.text = "\n".join(lines)

	# ── 보관함 ──
	if PlayerStats.inventory.is_empty():
		inv_box.text = "[color=#5a5a62]비어 있음[/color]"
	else:
		var inv_lines := []
		var n: int = mini(PlayerStats.inventory.size(), 40)
		for i in range(n):
			var it: ItemData = PlayerStats.inventory[i]
			var c: String = it.get_color().to_html(false)
			inv_lines.append("[color=#%s]%s %s[/color] [color=#6a6a72](공%.0f/속%.2f)[/color]" % [
				c, RarityEnums.get_rarity_tag(it.rarity), it.name, it.atk_bonus, it.speed_bonus
			])
		if PlayerStats.inventory.size() > n:
			inv_lines.append("[color=#6a6a72]... 외 %d개[/color]" % (PlayerStats.inventory.size() - n))
		inv_box.text = "\n".join(inv_lines)

func _stat_line(label: String, value: float, suffix: String) -> String:
	var col := "#8a8a92"
	if value > 0.0:
		col = "#7cd97c"
	elif value < 0.0:
		col = "#e07a7a"
	return "[color=#a8a8b0]%s[/color]  [color=%s]%+.0f%s[/color]" % [label, col, value, suffix]
