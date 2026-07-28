extends Node
class_name UpgradeUI
## 업그레이드 제단 화면 — 좌: 카테고리 / 중: 목록 / 우: 상세.
##
## 정의는 UpgradeManager 가 JSON 에서 읽는다. 이 파일에는 강화 id 가 없다.
## 목록도 카테고리도 전부 데이터에서 만들어지므로 JSON 만 늘리면 화면이 늘어난다.

var owner_hud: CanvasLayer

var panel: Control
var cat_box: VBoxContainer
var list_box: VBoxContainer
var detail: RichTextLabel
var essence_label: Label
var buy_btn: Button
var title_label: Label
var gacha_btn: Button
var gacha_info: RichTextLabel

var _cat := ""
var _sel := ""
var _cat_btns := {}
var _list_btns := {}

func setup(h: CanvasLayer) -> void:
	owner_hud = h

func build() -> void:
	var hud := owner_hud
	panel = Control.new()
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(panel)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.015, 0.03, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)

	title_label = Label.new()
	title_label.text = "⌘  마도 제단 — 영구 강화"
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", hud.GOLD)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(0, 28)
	title_label.size = Vector2(1280, 34)
	panel.add_child(title_label)

	essence_label = Label.new()
	essence_label.add_theme_font_size_override("font_size", 17)
	essence_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	essence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	essence_label.position = Vector2(0, 62)
	essence_label.size = Vector2(1280, 24)
	panel.add_child(essence_label)

	# ── 좌: 카테고리 ──
	cat_box = VBoxContainer.new()
	cat_box.position = Vector2(90, 110)
	cat_box.size = Vector2(180, 400)
	cat_box.add_theme_constant_override("separation", 8)
	panel.add_child(cat_box)

	# ── 중: 목록 ──
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(300, 110)
	scroll.size = Vector2(500, 500)
	panel.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.custom_minimum_size = Vector2(480, 0)
	list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(list_box)

	# ── 우: 상세 ──
	var side := Panel.new()
	side.position = Vector2(830, 110)
	side.size = Vector2(360, 440)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.07, 0.92)
	sb.border_color = hud.GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	side.add_theme_stylebox_override("panel", sb)
	panel.add_child(side)

	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.add_theme_font_size_override("normal_font_size", 15)
	detail.position = Vector2(16, 14)
	detail.size = Vector2(328, 350)
	side.add_child(detail)

	buy_btn = Button.new()
	buy_btn.text = "강화 (Enter)"
	buy_btn.position = Vector2(80, 380)
	buy_btn.size = Vector2(200, 44)
	buy_btn.pressed.connect(_on_buy)
	side.add_child(buy_btn)

	# ── 펫 뽑기 ── 제단 화면 아래쪽에 붙인다. 새 창을 만들지 않는다.
	gacha_btn = Button.new()
	gacha_btn.position = Vector2(90, 540)
	gacha_btn.size = Vector2(180, 44)
	gacha_btn.pressed.connect(_on_gacha)
	panel.add_child(gacha_btn)

	gacha_info = RichTextLabel.new()
	gacha_info.bbcode_enabled = true
	gacha_info.add_theme_font_size_override("normal_font_size", 13)
	gacha_info.position = Vector2(300, 620)
	gacha_info.size = Vector2(500, 60)
	panel.add_child(gacha_info)

	PetManager.gacha_result.connect(_on_gacha_result)

	var hint := Label.new()
	hint.text = "[G]/[ESC] 닫기      ↑↓ 카테고리 ←→      Enter 강화"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 640)
	hint.size = Vector2(1280, 20)
	panel.add_child(hint)

	UpgradeManager.changed.connect(_refresh)
	CraftManager.essence_changed.connect(func(_v): _refresh())
	_build_categories()

func _build_categories() -> void:
	for c in UpgradeManager.categories:
		var id := String(c.get("id", ""))
		var b := Button.new()
		b.text = String(c.get("name", id))
		b.custom_minimum_size = Vector2(180, 40)
		b.pressed.connect(func(): _select_cat(id))
		cat_box.add_child(b)
		_cat_btns[id] = b
	if not UpgradeManager.categories.is_empty():
		_cat = String(UpgradeManager.categories[0].get("id", ""))

func is_open() -> bool:
	return panel != null and panel.visible

func toggle() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		# 전체 화면 창은 하나만 (겹치면 입력을 앞선 창이 먹는다)
		owner_hud.close_windows(self)
		_select_cat(_cat)
		owner_hud.pop_in(panel)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP

func _select_cat(id: String) -> void:
	_cat = id
	for k in _cat_btns:
		_cat_btns[k].modulate = Color(1, 0.92, 0.65) if k == id else Color(0.7, 0.7, 0.75)
	_rebuild_list()

func _rebuild_list() -> void:
	for c in list_box.get_children():
		c.queue_free()
	_list_btns.clear()

	var first := ""
	for uid in UpgradeManager.ids():
		var d: Dictionary = UpgradeManager.defs[uid]
		if String(d.get("category", "")) != _cat:
			continue
		if first == "":
			first = uid
		var b := Button.new()
		b.custom_minimum_size = Vector2(470, 46)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): _select(uid))
		list_box.add_child(b)
		_list_btns[uid] = b
	if not _list_btns.has(_sel):
		_sel = first
	_refresh()

func _refresh() -> void:
	if panel == null or not panel.visible:
		return
	essence_label.text = "◇ 보유 마석  %d" % CraftManager.essence
	if gacha_btn:
		gacha_btn.text = "🐾 동행 뽑기  ◇%d" % PetManager.gacha_cost()
		gacha_btn.disabled = not PetManager.can_gacha()

	for uid in _list_btns:
		var b: Button = _list_btns[uid]
		var d: Dictionary = UpgradeManager.defs[uid]
		var lv := UpgradeManager.level(uid)
		var mx := UpgradeManager.max_level(uid)
		var locked := not UpgradeManager.is_unlocked(uid)
		var maxed := UpgradeManager.is_maxed(uid)
		var cost := UpgradeManager.next_cost(uid)

		var tail := ""
		if locked:
			tail = "  🔒 %s" % UpgradeManager.lock_reason(uid)
		elif maxed:
			tail = "  최대"
		else:
			tail = "  ◇%d" % cost
		b.text = "%s %s   %d/%d%s" % [
			String(d.get("icon", "•")), String(d.get("name", uid)), lv, mx, tail]
		b.disabled = locked
		if uid == _sel:
			b.modulate = Color(1.0, 0.92, 0.62)
		elif maxed:
			b.modulate = Color(0.55, 0.7, 0.55)
		elif locked:
			b.modulate = Color(0.5, 0.5, 0.55)
		elif cost > CraftManager.essence:
			b.modulate = Color(0.72, 0.6, 0.6)
		else:
			b.modulate = Color(0.88, 0.88, 0.92)

	_refresh_detail()

func _select(uid: String) -> void:
	_sel = uid
	_refresh()

func _refresh_detail() -> void:
	if _sel == "" or not UpgradeManager.has(_sel):
		detail.text = "[color=#70707a]강화를 고르세요.[/color]"
		buy_btn.disabled = true
		return
	var d: Dictionary = UpgradeManager.defs[_sel]
	var lv := UpgradeManager.level(_sel)
	var mx := UpgradeManager.max_level(_sel)
	var maxed := UpgradeManager.is_maxed(_sel)
	var locked := not UpgradeManager.is_unlocked(_sel)
	var cost := UpgradeManager.next_cost(_sel)
	var unit := String(d.get("unit", "pct"))

	var lines := []
	lines.append("[b][color=#e8c26a]%s %s[/color][/b]"
		% [String(d.get("icon", "•")), String(d.get("name", _sel))])
	lines.append("[color=#8a8a92]%s[/color]\n" % String(d.get("desc", "")))
	lines.append("현재 단계   [b]%d / %d[/b]" % [lv, mx])
	lines.append("현재 효과   [color=#8fd8a0]%s[/color]"
		% _fmt(UpgradeManager.value(_sel), unit))

	if locked:
		lines.append("\n[color=#c07070]🔒 %s[/color]" % UpgradeManager.lock_reason(_sel))
		buy_btn.disabled = true
		buy_btn.text = "잠김"
	elif maxed:
		lines.append("\n[color=#8fd8a0]최대 단계입니다.[/color]")
		buy_btn.disabled = true
		buy_btn.text = "최대 단계"
	else:
		lines.append("다음 효과   [color=#a8e0ff]%s[/color]"
			% _fmt(UpgradeManager.next_value(_sel), unit))
		var can := CraftManager.essence >= cost
		lines.append("\n필요 마석   [color=%s]◇ %d[/color]"
			% ["#8fd8a0" if can else "#c07070", cost])
		buy_btn.disabled = not can
		buy_btn.text = "강화 (Enter)" if can else "마석 부족"
	detail.text = "\n".join(lines)

func _fmt(v: float, unit: String) -> String:
	if unit == "pct":
		return "+%.0f%%" % (v * 100.0)
	return "+%.0f" % v

func _on_buy() -> void:
	if _sel == "":
		return
	if UpgradeManager.purchase(_sel):
		SoundManager.play("build", -6.0)
		CombatFeel.screen_flash(Color(1.0, 0.9, 0.6), 0.16, 0.0, 0.16)
	else:
		SoundManager.play("error", -12.0)
	_refresh()

## HUD 가 키 입력을 넘겨준다
func handle_key(keycode: int) -> bool:
	if not is_open():
		return false
	match keycode:
		KEY_G, KEY_ESCAPE:
			panel.visible = false
			return true
		KEY_ENTER, KEY_KP_ENTER:
			_on_buy()
			return true
		KEY_DOWN, KEY_UP:
			var keys: Array = _list_btns.keys()
			if keys.is_empty():
				return true
			var i: int = keys.find(_sel)
			i = wrapi(i + (1 if keycode == KEY_DOWN else -1), 0, keys.size())
			_select(String(keys[i]))
			return true
		KEY_LEFT, KEY_RIGHT:
			var cats: Array = UpgradeManager.categories
			if cats.is_empty():
				return true
			var ids: Array = []
			for c in cats:
				ids.append(String(c.get("id", "")))
			var j: int = ids.find(_cat)
			j = wrapi(j + (1 if keycode == KEY_RIGHT else -1), 0, ids.size())
			_select_cat(String(ids[j]))
			return true
	return false

# ══════════════════════════════════════════════
#  펫 뽑기
# ══════════════════════════════════════════════
func _on_gacha() -> void:
	PetManager.gacha()
	_refresh()

func _on_gacha_result(pet_type: String, is_new: bool, leveled: bool, refund: int) -> void:
	var info := PetManager.get_info(pet_type)
	var nm := String(info.get("name", pet_type))
	var gr := PetManager.grade_of(pet_type)
	var msg := ""
	if is_new:
		msg = "[color=#e8c26a]★ 새 동행 — %s [%s][/color]" % [nm, gr]
		CombatFeel.impact("crit")
		SoundManager.play("loot_legend", -4.0)
	elif leveled:
		msg = "[color=#8fd8a0]%s [%s] 레벨 %d[/color]" % [nm, gr, PetManager.level_of(pet_type)]
		SoundManager.play("loot_epic", -6.0)
	else:
		msg = "[color=#8a8a92]%s [%s] 최대 레벨 — 마석 %d 환급[/color]" % [nm, gr, refund]
		SoundManager.play("loot_rare", -8.0)
	if gacha_info:
		gacha_info.text = "%s
[color=#70707a]보유 %d종 · 천장까지 %d회[/color]" % [
			msg, PetManager.owned.size(),
			maxi(0, int(PetManager.defs().get("gacha", {}).get("pity", {}).get("count", 0))
				- PetManager.pity)]
