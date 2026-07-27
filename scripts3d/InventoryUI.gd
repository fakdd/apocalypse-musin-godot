extends CanvasLayer
## 인벤토리 & 장비 창 (I 키) — 등급 테두리, 드래그&드롭 장착, 툴팁, 합성/강화

const SLOT_SCRIPT := preload("res://scripts3d/ItemSlotUI.gd")
const COLS := 8
const ROWS := 5

var panel: Control
var grid: GridContainer
var equip_slots := {}
var inv_slots: Array = []
var stat_label: RichTextLabel
var essence_label: Label
var msg_label: Label
var merge_buttons := {}
var enhance_btn: Button
var enhance_info: Label
var enhance_target_slot := "weapon"

func _ready() -> void:
	layer = 16
	_build()
	visible = false
	PlayerStats.stats_changed.connect(_refresh)
	PlayerStats.inventory_changed.connect(_refresh)
	CraftManager.essence_changed.connect(func(_n): _refresh())
	CraftManager.craft_result.connect(_on_craft_result)
	TraitManager.trait_changed.connect(func(_t): _refresh())

func _build() -> void:
	panel = Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.015, 0.03, 0.93)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)

	var title := Label.new()
	title.text = "인벤토리 · 장비"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.96))
	title.position = Vector2(60, 22)
	panel.add_child(title)

	essence_label = Label.new()
	essence_label.add_theme_font_size_override("font_size", 18)
	essence_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	essence_label.position = Vector2(60, 58)
	panel.add_child(essence_label)

	# ── 장비 슬롯 ──
	var eq_head := Label.new()
	eq_head.text = "장착"
	eq_head.add_theme_font_size_override("font_size", 16)
	eq_head.add_theme_color_override("font_color", Color(0.66, 0.74, 0.92))
	eq_head.position = Vector2(60, 100)
	panel.add_child(eq_head)

	var x := 60.0
	for key in ["weapon", "armor", "relic"]:
		var slot: Panel = Panel.new()
		slot.set_script(SLOT_SCRIPT)
		panel.add_child(slot)
		slot.setup(true, key)
		slot.position = Vector2(x, 126)
		slot.request_equip.connect(_on_request_equip)
		slot.request_unequip.connect(_on_request_unequip)
		equip_slots[key] = slot
		x += 72.0

	# ── 최종 스탯 ──
	stat_label = RichTextLabel.new()
	stat_label.bbcode_enabled = true
	stat_label.position = Vector2(300, 100)
	stat_label.size = Vector2(380, 110)
	stat_label.add_theme_font_size_override("normal_font_size", 15)
	panel.add_child(stat_label)

	# ── 인벤토리 그리드 ──
	var inv_head := Label.new()
	inv_head.text = "보관함  (좌클릭/드래그로 장착 · 장비 우클릭으로 해제)"
	inv_head.add_theme_font_size_override("font_size", 15)
	inv_head.add_theme_color_override("font_color", Color(0.66, 0.74, 0.92))
	inv_head.position = Vector2(60, 224)
	panel.add_child(inv_head)

	grid = GridContainer.new()
	grid.columns = COLS
	grid.position = Vector2(60, 250)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	panel.add_child(grid)

	for i in range(COLS * ROWS):
		var cell: Panel = Panel.new()
		cell.set_script(SLOT_SCRIPT)
		grid.add_child(cell)
		cell.setup(false, "")
		cell.request_equip.connect(_on_request_equip)
		cell.request_unequip.connect(_on_request_unequip)
		inv_slots.append(cell)

	_build_craft_panel()

	msg_label = Label.new()
	msg_label.add_theme_font_size_override("font_size", 17)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.position = Vector2(0, 640)
	msg_label.size = Vector2(1280, 26)
	msg_label.modulate.a = 0.0
	panel.add_child(msg_label)

	var hint := Label.new()
	hint.text = "I 또는 ESC 로 닫기"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.58))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 676)
	hint.size = Vector2(1280, 22)
	panel.add_child(hint)

func _build_craft_panel() -> void:
	var px := 640.0
	var head := Label.new()
	head.text = "합성 — 같은 등급 3개 → 상위 등급 1개"
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", Color(0.66, 0.74, 0.92))
	head.position = Vector2(px, 224)
	panel.add_child(head)

	var y := 252.0
	for r in range(RarityEnums.Rarity.F, RarityEnums.Rarity.SSS):
		var btn := Button.new()
		btn.position = Vector2(px, y)
		btn.size = Vector2(300, 30)
		btn.add_theme_font_size_override("font_size", 14)
		var captured_r := r
		btn.pressed.connect(func(): CraftManager.merge(captured_r))
		panel.add_child(btn)
		merge_buttons[r] = btn
		y += 34.0

	var ehead := Label.new()
	ehead.text = "강화 — 마석을 소비해 장비를 +N 강화"
	ehead.add_theme_font_size_override("font_size", 15)
	ehead.add_theme_color_override("font_color", Color(0.66, 0.74, 0.92))
	ehead.position = Vector2(px, y + 10)
	panel.add_child(ehead)

	var bx := px
	for key in ["weapon", "armor", "relic"]:
		var sel := Button.new()
		sel.text = ItemData.SLOT_NAMES[key]
		sel.position = Vector2(bx, y + 38)
		sel.size = Vector2(94, 28)
		sel.add_theme_font_size_override("font_size", 13)
		var ck: String = key
		sel.pressed.connect(func():
			enhance_target_slot = ck
			_refresh()
		)
		panel.add_child(sel)
		bx += 100.0

	enhance_btn = Button.new()
	enhance_btn.position = Vector2(px, y + 72)
	enhance_btn.size = Vector2(294, 34)
	enhance_btn.add_theme_font_size_override("font_size", 15)
	enhance_btn.pressed.connect(func():
		var it: ItemData = PlayerStats.equipped.get(enhance_target_slot, null)
		CraftManager.enhance(it)
	)
	panel.add_child(enhance_btn)

	enhance_info = Label.new()
	enhance_info.add_theme_font_size_override("font_size", 13)
	enhance_info.add_theme_color_override("font_color", Color(0.68, 0.68, 0.76))
	enhance_info.position = Vector2(px, y + 112)
	enhance_info.size = Vector2(340, 40)
	enhance_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.add_child(enhance_info)

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()

func _on_request_equip(item: ItemData) -> void:
	PlayerStats.equip_item(item)
	SoundManager.play("build", -16.0)

func _on_request_unequip(slot_key: String) -> void:
	PlayerStats.unequip_slot(slot_key)
	SoundManager.play("pickup", -16.0)

func _on_craft_result(_success: bool, message: String, _item) -> void:
	if msg_label == null:
		return
	msg_label.text = message
	msg_label.add_theme_color_override("font_color",
		Color(0.6, 1.0, 0.7) if _success else Color(1.0, 0.6, 0.6))
	msg_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(msg_label, "modulate:a", 0.0, 0.7)

func _refresh() -> void:
	if grid == null:
		return

	essence_label.text = "마석 %d" % CraftManager.essence

	for key in equip_slots.keys():
		equip_slots[key].set_item(PlayerStats.equipped.get(key, null))

	for i in range(inv_slots.size()):
		var it = PlayerStats.inventory[i] if i < PlayerStats.inventory.size() else null
		inv_slots[i].set_item(it)

	var overflow: int = maxi(0, PlayerStats.inventory.size() - inv_slots.size())
	stat_label.text = "[color=#ffd479][b]공격력  %.1f[/b][/color]\n[color=#8fd4ff][b]이동속도  %.2f[/b][/color]\n[color=#ff9a9a]최대 체력  %.0f[/color]\n[color=#7a7a84]검기 1타 %.1f%s[/color]" % [
		PlayerStats.get_final_atk(), PlayerStats.get_final_speed(),
		PlayerStats.get_final_max_hp(), PlayerStats.get_slash_damage(),
		("   (보관함 초과 %d개)" % overflow) if overflow > 0 else ""
	]

	var counts := CraftManager.inventory_counts()
	for r in merge_buttons.keys():
		var have: int = counts.get(r, 0)
		var btn: Button = merge_buttons[r]
		var chance: float = CraftManager.MERGE_CHANCE.get(r, 0.1)
		btn.text = "%s → %s   보유 %d/3   성공 %d%%" % [
			RarityEnums.get_rarity_name(r), RarityEnums.get_rarity_name(r + 1),
			have, int(chance * 100)
		]
		btn.disabled = have < CraftManager.MERGE_COST
		btn.add_theme_color_override("font_color", RarityEnums.get_rarity_color(r))

	var target: ItemData = PlayerStats.equipped.get(enhance_target_slot, null)
	if target == null:
		enhance_btn.text = "%s 슬롯이 비어 있음" % ItemData.SLOT_NAMES[enhance_target_slot]
		enhance_btn.disabled = true
		enhance_info.text = ""
	elif target.enhance_level >= CraftManager.MAX_ENHANCE:
		enhance_btn.text = "%s 최대 강화 (+%d)" % [target.name, CraftManager.MAX_ENHANCE]
		enhance_btn.disabled = true
		enhance_info.text = ""
	else:
		var cost := CraftManager.enhance_cost(target)
		enhance_btn.text = "%s +%d → +%d   (마석 %d)" % [
			target.name, target.enhance_level, target.enhance_level + 1, cost]
		enhance_btn.disabled = CraftManager.essence < cost
		enhance_info.text = "성공률 %d%%  ·  성공 시 공격 +12%%p, 속도 +6%%p  ·  실패 시 마석만 소모 (단계 유지)" % int(CraftManager.enhance_chance(target) * 100)
