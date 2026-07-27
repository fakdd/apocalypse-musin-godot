extends Panel
## 인벤토리/장비 슬롯 한 칸. 등급 테두리 · 드래그&드롭 · 툴팁을 담당한다.

signal request_equip(item: ItemData)
signal request_unequip(slot_key: String)

const CELL := 62.0

var item: ItemData = null
var is_equip_slot := false
var equip_slot_key := ""      ## is_equip_slot 일 때 "weapon"/"armor"/"relic"
var icon: Control
var lvl_label: Label
var placeholder: Label
var icon_tex: TextureRect

func setup(p_is_equip: bool = false, p_slot_key: String = "") -> void:
	is_equip_slot = p_is_equip
	equip_slot_key = p_slot_key
	custom_minimum_size = Vector2(CELL, CELL)
	size = Vector2(CELL, CELL)
	mouse_filter = Control.MOUSE_FILTER_STOP

	icon_tex = TextureRect.new()
	icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_tex.position = Vector2(6, 4)
	icon_tex.size = Vector2(CELL - 12, CELL - 16)
	icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_tex)

	icon = Control.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	icon.draw.connect(_draw_icon)

	lvl_label = Label.new()
	lvl_label.add_theme_font_size_override("font_size", 12)
	lvl_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	lvl_label.position = Vector2(4, CELL - 20)
	lvl_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lvl_label)

	placeholder = Label.new()
	placeholder.add_theme_font_size_override("font_size", 11)
	placeholder.add_theme_color_override("font_color", Color(0.42, 0.42, 0.5))
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(placeholder)

	_apply_style()

func set_item(p_item: ItemData) -> void:
	item = p_item
	_apply_style()
	# 아이콘 이미지가 있으면 그것을 쓰고, 없으면 도형으로 폴백
	var has_tex := false
	if icon_tex:
		if item != null:
			var ip := ItemSkins.icon_path(item.skin)
			if ip != "":
				var tex = load(ip)
				if tex:
					icon_tex.texture = tex
					icon_tex.modulate = item.get_color()
					icon_tex.visible = true
					has_tex = true
		if not has_tex:
			icon_tex.texture = null
			icon_tex.visible = false
	if icon:
		icon.visible = not has_tex
		icon.queue_redraw()
	if lvl_label:
		lvl_label.text = "" if (item == null or item.enhance_level <= 0) else "+%d" % item.enhance_level
	if placeholder:
		if item != null:
			placeholder.text = ""
		elif is_equip_slot:
			placeholder.text = ItemData.SLOT_NAMES.get(equip_slot_key, "")
		else:
			placeholder.text = ""
	_update_tooltip()

func _apply_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.14, 0.95)
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	if item != null:
		# 등급 테두리 — F 회색 … A 보라 … SSS 붉은금색
		var col: Color = item.get_color()
		sb.border_color = col
		sb.bg_color = Color(col.r * 0.16, col.g * 0.16, col.b * 0.16, 0.96)
		if item.rarity >= RarityEnums.Rarity.S:
			sb.set_border_width_all(3)
			sb.shadow_color = Color(col.r, col.g, col.b, 0.55)
			sb.shadow_size = 6
	else:
		sb.border_color = Color(0.26, 0.26, 0.32)
	add_theme_stylebox_override("panel", sb)

func _draw_icon() -> void:
	if item == null:
		return
	var c: Color = item.get_color()
	var mid := Vector2(CELL * 0.5, CELL * 0.5 - 4.0)
	match ItemSkins.icon_shape(item.skin):
		"blade":
			# 칼날
			var pts := PackedVector2Array([
				mid + Vector2(0, -20), mid + Vector2(6, -6),
				mid + Vector2(4, 16), mid + Vector2(-4, 16),
				mid + Vector2(-6, -6),
			])
			icon.draw_colored_polygon(pts, c)
			icon.draw_line(mid + Vector2(-11, 15), mid + Vector2(11, 15), c.darkened(0.35), 3.0)
		"shield":
			var pts2 := PackedVector2Array([
				mid + Vector2(-14, -16), mid + Vector2(14, -16),
				mid + Vector2(14, 4), mid + Vector2(0, 19), mid + Vector2(-14, 4),
			])
			icon.draw_colored_polygon(pts2, c)
			icon.draw_line(mid + Vector2(0, -14), mid + Vector2(0, 16), c.darkened(0.4), 2.0)
		_:
			# 보석
			var pts3 := PackedVector2Array([
				mid + Vector2(0, -18), mid + Vector2(15, -3),
				mid + Vector2(0, 18), mid + Vector2(-15, -3),
			])
			icon.draw_colored_polygon(pts3, c)
			icon.draw_line(mid + Vector2(-15, -3), mid + Vector2(15, -3), c.lightened(0.4), 1.5)

func _update_tooltip() -> void:
	if item == null:
		tooltip_text = "빈 슬롯" if is_equip_slot else ""
		return
	var lines := []
	lines.append("%s" % item.get_display_name())
	lines.append("등급: %s   부위: %s" % [RarityEnums.get_rarity_name(item.rarity), item.slot_label()])
	lines.append("")
	lines.append("공격력  +%.0f" % item.total_atk())
	lines.append("이동속도  +%.2f" % item.total_speed())
	if item.enhance_level > 0:
		lines.append("강화  +%d  (공격 +%d%% / 속도 +%d%%)" % [
			item.enhance_level, int(item.enhance_level * 12), int(item.enhance_level * 6)])
	lines.append("")
	lines.append("종합 점수 %.0f" % item.power_score())
	if is_equip_slot:
		lines.append("우클릭: 장착 해제")
	else:
		lines.append("좌클릭 또는 드래그: 장착")
	tooltip_text = "\n".join(lines)

# ── 드래그 & 드롭 ──
func _get_drag_data(_pos: Vector2) -> Variant:
	if item == null:
		return null
	var preview := Panel.new()
	preview.custom_minimum_size = Vector2(CELL, CELL)
	preview.size = Vector2(CELL, CELL)
	var sb := StyleBoxFlat.new()
	var col: Color = item.get_color()
	sb.bg_color = Color(col.r * 0.3, col.g * 0.3, col.b * 0.3, 0.9)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	preview.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = RarityEnums.get_rarity_name(item.rarity)
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview.add_child(l)
	set_drag_preview(preview)
	return {"item": item, "from_equip": is_equip_slot, "slot_key": equip_slot_key}

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("item"):
		return false
	var d: ItemData = data["item"]
	if d == null:
		return false
	# 장비 슬롯에는 같은 부위만
	if is_equip_slot:
		return d.slot == equip_slot_key
	return true

func _drop_data(_pos: Vector2, data: Variant) -> void:
	var d: ItemData = data["item"]
	if d == null:
		return
	if is_equip_slot:
		request_equip.emit(d)
	else:
		# 인벤토리 칸에 떨어뜨림 = 장착 해제
		if bool(data.get("from_equip", false)):
			request_unequip.emit(String(data.get("slot_key", "")))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not is_equip_slot and item != null:
			request_equip.emit(item)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and is_equip_slot and item != null:
			request_unequip.emit(equip_slot_key)
			accept_event()
