extends Node
class_name NPCUI
## NPC 대화창 · 선택지 · 상점 · 퀘스트 · 호감도 표시.
##
## 정의는 NPCManager 가 JSON 에서 읽는다. 이 파일에는 NPC id 도 대사도 없다.

var owner_hud: CanvasLayer

var panel: Control
var portrait: Label
var name_label: Label
var affinity_label: Label
var body: RichTextLabel
var choice_box: VBoxContainer
var quest_label: RichTextLabel

var _npc := ""
var _mode := "talk"          ## talk | shop
var _btns: Array = []
var _sel := 0

func setup(h: CanvasLayer) -> void:
	owner_hud = h

func build() -> void:
	var hud := owner_hud
	panel = Control.new()
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(panel)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.02, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(dim)

	var box := Panel.new()
	box.position = Vector2(200, 300)
	box.size = Vector2(880, 350)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.06, 0.97)
	sb.border_color = hud.GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(hud.GOLD.r, hud.GOLD.g, hud.GOLD.b, 0.3)
	sb.shadow_size = 8
	box.add_theme_stylebox_override("panel", sb)
	panel.add_child(box)

	portrait = Label.new()
	portrait.add_theme_font_size_override("font_size", 46)
	portrait.position = Vector2(20, 14)
	portrait.size = Vector2(70, 60)
	portrait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(portrait)

	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 21)
	name_label.add_theme_color_override("font_color", hud.GOLD)
	name_label.position = Vector2(96, 16)
	box.add_child(name_label)

	affinity_label = Label.new()
	affinity_label.add_theme_font_size_override("font_size", 13)
	affinity_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	affinity_label.position = Vector2(96, 44)
	box.add_child(affinity_label)

	quest_label = RichTextLabel.new()
	quest_label.bbcode_enabled = true
	quest_label.add_theme_font_size_override("normal_font_size", 12)
	quest_label.position = Vector2(560, 14)
	quest_label.size = Vector2(300, 54)
	box.add_child(quest_label)

	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.add_theme_font_size_override("normal_font_size", 16)
	body.position = Vector2(24, 82)
	body.size = Vector2(830, 76)
	box.add_child(body)

	choice_box = VBoxContainer.new()
	choice_box.position = Vector2(24, 166)
	choice_box.size = Vector2(830, 170)
	choice_box.add_theme_constant_override("separation", 5)
	box.add_child(choice_box)

	var hint := Label.new()
	hint.text = "↑↓ 선택   Enter 결정   ESC 닫기"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.58, 0.58, 0.64))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 660)
	hint.size = Vector2(1280, 18)
	panel.add_child(hint)

func is_open() -> bool:
	return panel != null and panel.visible

func open(npc_id: String) -> void:
	if not NPCManager.has(npc_id):
		return
	_npc = npc_id
	_mode = "talk"
	panel.visible = true
	owner_hud.close_windows(self)
	owner_hud.pop_in(panel)
	# 목표를 채운 퀘스트가 있으면 대화하는 순간 완료된다
	var done := NPCManager.try_complete(npc_id)
	_refresh()
	if not done.is_empty():
		var q := NPCManager.quest_def(npc_id, String(done[0]))
		owner_hud.show_banner("◈ 퀘스트 완료 — %s" % String(q.get("name", "")))

func close() -> void:
	panel.visible = false
	_npc = ""

func _refresh() -> void:
	if _npc == "":
		return
	portrait.text = NPCManager.portrait_of(_npc)
	name_label.text = NPCManager.name_of(_npc)
	var af := NPCManager.affinity(_npc)
	var disc := NPCManager.discount(_npc)
	affinity_label.text = "호감도 %d · %s%s" % [af, NPCManager.tier_name(_npc),
		("   할인 %.0f%%" % (disc * 100.0)) if disc > 0.0 else ""]
	_refresh_quests()
	if _mode == "shop":
		_show_shop()
	else:
		_show_talk()

func _refresh_quests() -> void:
	var lines := []
	for q in NPCManager.active_quests(_npc):
		var qid := String(q.get("id", ""))
		var p := NPCManager.quest_progress(_npc, qid)
		var ready := NPCManager.quest_ready(_npc, qid)
		lines.append("[color=%s]◆ %s (%d/%d)[/color]"
			% ["#8fd8a0" if ready else "#c8b070", String(q.get("name", "")),
			int(p[0]), int(p[1])])
	quest_label.text = "\n".join(lines)

func _show_talk() -> void:
	body.text = "[color=#e0dcd8]%s[/color]" % NPCManager.dialog_for(_npc)
	var rows := []
	for c in NPCManager.choices_for(_npc):
		var label := String(c.get("text", ""))
		var cost = c.get("cost", null)
		if typeof(cost) == TYPE_DICTIONARY and int(cost.get("essence", 0)) > 0:
			label += "   (◇%d)" % int(cost["essence"])
		var q := String(c.get("start_quest", ""))
		if q != "":
			label += "   [퀘스트]"
		if bool(c.get("open_shop", false)):
			label += "   [상점]"
		rows.append([label, String(c.get("id", "")),
			NPCManager.can_afford(c), "choice"])
	_build_rows(rows)

func _show_shop() -> void:
	body.text = "[color=#a8c0d8]무엇을 사겠소?[/color]   보유 마석 ◇%d" % CraftManager.essence
	var rows := []
	for it in NPCManager.shop_for(_npc):
		var p := NPCManager.price_of(_npc, it)
		var base := int(it.get("price", 0))
		var tag := "◇%d" % p
		if p < base:
			tag = "◇%d [color=#6a6a72](%d)[/color]" % [p, base]
		rows.append(["%s   %s\n     %s" % [String(it.get("name", "")), tag,
			String(it.get("desc", ""))],
			String(it.get("id", "")), CraftManager.essence >= p, "shop"])
	rows.append(["← 돌아가기", "__back", true, "back"])
	_build_rows(rows)

func _build_rows(rows: Array) -> void:
	for c in choice_box.get_children():
		c.queue_free()
	_btns.clear()
	for i in range(rows.size()):
		var r: Array = rows[i]
		var b := Button.new()
		b.text = String(r[0])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(820, 30)
		b.disabled = not bool(r[2])
		var rid := String(r[1])
		var kind := String(r[3])
		b.pressed.connect(func(): _activate(rid, kind))
		choice_box.add_child(b)
		_btns.append(b)
	_sel = clampi(_sel, 0, maxi(0, _btns.size() - 1))
	_highlight()

func _highlight() -> void:
	for i in range(_btns.size()):
		_btns[i].modulate = Color(1.0, 0.92, 0.62) if i == _sel \
			else Color(0.85, 0.85, 0.9)

func _activate(rid: String, kind: String) -> void:
	match kind:
		"back":
			_mode = "talk"
			_sel = 0
			_refresh()
		"shop":
			if NPCManager.buy(_npc, rid):
				SoundManager.play("build", -8.0)
			else:
				SoundManager.play("error", -12.0)
			_refresh()
		_:
			var reply := NPCManager.choose(_npc, rid)
			if reply == "":
				SoundManager.play("error", -12.0)
				return
			if NPCManager.opens_shop(_npc, rid):
				_mode = "shop"
				_sel = 0
				_refresh()
				return
			body.text = "[color=#e0dcd8]%s[/color]" % reply
			_refresh_quests()
			affinity_label.text = "호감도 %d · %s" % [
				NPCManager.affinity(_npc), NPCManager.tier_name(_npc)]
			SoundManager.play("pickup", -14.0)
			# 답변을 읽을 시간을 주고 선택지를 다시 만든다
			await owner_hud.get_tree().create_timer(1.1, true, false, true).timeout
			if is_open():
				_show_talk()

## HUD 가 키를 넘겨준다
func handle_key(keycode: int) -> bool:
	if not is_open():
		return false
	match keycode:
		KEY_ESCAPE:
			close()
			return true
		KEY_UP, KEY_DOWN:
			if _btns.is_empty():
				return true
			_sel = wrapi(_sel + (1 if keycode == KEY_DOWN else -1), 0, _btns.size())
			_highlight()
			return true
		KEY_ENTER, KEY_KP_ENTER:
			if _sel >= 0 and _sel < _btns.size() and not _btns[_sel].disabled:
				_btns[_sel].pressed.emit()
			return true
	return false
