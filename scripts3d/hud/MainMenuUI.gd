extends Node
class_name MainMenuUI
## 타이틀 · 일시정지 · 세이브 슬롯 · 옵션.
##
## 기존 HUD3D CanvasLayer 를 그대로 쓴다 (새 씬·새 오토로드 없음).
## 메뉴 항목·문구는 data/menu.json 에서 읽는다 — 이 파일에 문자열이 없다.

const MENU_PATH := "res://data/menu.json"

var owner_hud: CanvasLayer

var panel: Control
var title_label: Label
var sub_label: Label
var list_box: VBoxContainer
var hint_label: Label

var _defs: Dictionary = {}
var _screen := ""            ## title | pause | slots | options
var _rows: Array = []        ## [{id, label, enabled}]
var _btns: Array = []
var _sel := 0
var _pending := ""           ## slots 화면에서 고른 동작 (continue | new)

func setup(h: CanvasLayer) -> void:
	owner_hud = h

func defs() -> Dictionary:
	if not _defs.is_empty():
		return _defs
	var f := FileAccess.open(MENU_PATH, FileAccess.READ)
	if f == null:
		_defs = {"screens": {}, "text": {}}
		return _defs
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	_defs = j if typeof(j) == TYPE_DICTIONARY else {"screens": {}, "text": {}}
	return _defs

func txt(key: String, fallback: String = "") -> String:
	return String(defs().get("text", {}).get(key, fallback))

# ══════════════════════════════════════════════
#  화면
# ══════════════════════════════════════════════
func build() -> void:
	var hud := owner_hud
	panel = Control.new()
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(panel)

	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.012, 0.02, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 44)
	title_label.add_theme_color_override("font_color", hud.GOLD)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(0, 110)
	title_label.size = Vector2(1280, 56)
	panel.add_child(title_label)

	sub_label = Label.new()
	sub_label.add_theme_font_size_override("font_size", 15)
	sub_label.add_theme_color_override("font_color", Color(0.62, 0.60, 0.66))
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.position = Vector2(0, 168)
	sub_label.size = Vector2(1280, 24)
	panel.add_child(sub_label)

	list_box = VBoxContainer.new()
	list_box.position = Vector2(440, 240)
	list_box.size = Vector2(400, 340)
	list_box.add_theme_constant_override("separation", 10)
	panel.add_child(list_box)

	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.position = Vector2(0, 648)
	hint_label.size = Vector2(1280, 20)
	panel.add_child(hint_label)

func is_open() -> bool:
	return panel != null and panel.visible

## 타이틀은 게임 시작 직후 한 번 뜬다.
func open_title() -> void:
	_show("title")

func open_pause() -> void:
	if _screen == "pause" and is_open():
		close()
		return
	_show("pause")

func close() -> void:
	panel.visible = false
	_screen = ""
	get_tree().paused = false
	SoundManager.set_paused(false)
	owner_hud.sync_mouse_mode()

func _show(screen: String) -> void:
	_screen = screen
	_sel = 0
	panel.visible = true
	owner_hud.close_windows(self)
	# 메뉴가 떠 있는 동안 월드는 멈춘다. HUD 는 PROCESS_MODE_ALWAYS 라 계속 돈다.
	get_tree().paused = true
	SoundManager.set_paused(true)      ## 효과음·BGM 버스를 함께 멈춘다
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	owner_hud.pop_in(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	SoundManager.play("ui_open", -10.0)
	_refresh()

func _refresh() -> void:
	var sc: Dictionary = defs().get("screens", {}).get(_screen, {})
	title_label.text = String(sc.get("title", ""))
	sub_label.text = _subtitle(sc)
	hint_label.text = String(sc.get("hint", ""))
	_rows = _build_rows(sc)
	_rebuild_buttons()

func _subtitle(sc: Dictionary) -> String:
	var base := String(sc.get("subtitle", ""))
	if _screen == "pause":
		return "%s   ·   %s   Lv%d   %s" % [base,
			ChapterConfig.name_of(GameManager.chapter),
			GameManager.player_level, SaveGame.tier_name()]
	return base

## 화면별 항목. slots 는 세이브 파일을 읽어 동적으로 만든다.
func _build_rows(sc: Dictionary) -> Array:
	if _screen == "slots":
		var out := []
		for i in range(SaveGame.SLOT_COUNT):
			var info := SaveGame.slot_info(i)
			out.append({
				"id": "slot_%d" % i,
				"label": _slot_label(info),
				"enabled": _pending == "new" or not bool(info["empty"]),
			})
		out.append({"id": "back", "label": txt("back", "← 돌아가기"), "enabled": true})
		return out

	var out2 := []
	for it in sc.get("items", []):
		var id := String(it.get("id", ""))
		out2.append({
			"id": id,
			"label": _decorate(id, String(it.get("label", id))),
			"enabled": _item_enabled(id),
		})
	return out2

## 옵션 항목 옆에 현재 값을 붙인다 ("마스터 볼륨: 80%").
func _decorate(id: String, label: String) -> String:
	match id:
		"vol_down", "vol_up":
			return "%s      %s" % [label, txt("vol_fmt", "마스터 볼륨: %d%%") % _volume_pct()]
		"gfx_down", "gfx_up":
			return "%s      %s" % [label,
				txt("gfx_fmt", "그래픽 품질: %s") % EnvironmentManager.level_name(SaveGame.graphics)]
		"boss_rush":
			if not SaveGame.boss_rush_unlocked():
				return txt("rush_locked", "보스 러시 — 엔딩 후 해금")
	return label

## -30dB ~ +6dB 를 0~100% 로 보여준다 (사람이 읽는 값).
func _volume_pct() -> int:
	return int(round(clampf((SaveGame.master_db + 30.0) / 36.0, 0.0, 1.0) * 100.0))

func _slot_label(info: Dictionary) -> String:
	var n: int = int(info["slot"]) + 1
	if bool(info["empty"]):
		return txt("slot_empty", "슬롯 %d — 비어 있음") % n
	var mm := int(float(info["seconds"]) / 60.0)
	var ng := ""
	if int(info["ng_plus"]) > 0:
		ng = "  NG+%d" % int(info["ng_plus"])
	return txt("slot_used", "슬롯 %d — %d장 · Lv%d · %d분%s") \
		% [n, int(info["chapter"]), int(info["level"]), mm, ng]

func _item_enabled(id: String) -> bool:
	match id:
		"continue":
			for i in range(SaveGame.SLOT_COUNT):
				if not bool(SaveGame.slot_info(i)["empty"]):
					return true
			return false
		"boss_rush":
			return SaveGame.boss_rush_unlocked()
	return true

func _rebuild_buttons() -> void:
	for c in list_box.get_children():
		c.queue_free()
	_btns.clear()
	for r in _rows:
		var b := Button.new()
		b.text = NPCUI.plain(String(r["label"]))
		b.custom_minimum_size = Vector2(400, 46)
		b.disabled = not bool(r["enabled"])
		var rid := String(r["id"])
		var idx := _btns.size()
		b.focus_mode = Control.FOCUS_NONE          ## 하이라이트는 우리가 직접 칠한다
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.pressed.connect(func(): _activate(rid))
		# 마우스를 올리면 키보드 선택도 따라 움직인다 (두 입력이 어긋나지 않게)
		b.mouse_entered.connect(func(): _hover(idx))
		list_box.add_child(b)
		_btns.append(b)
	_sel = clampi(_sel, 0, maxi(0, _btns.size() - 1))
	_highlight()

func _hover(i: int) -> void:
	if i == _sel or i < 0 or i >= _btns.size():
		return
	_sel = i
	_highlight()
	SoundManager.play("ui_move", -16.0)

func _highlight() -> void:
	for i in range(_btns.size()):
		_btns[i].modulate = Color(1.0, 0.92, 0.62) if i == _sel else Color(0.85, 0.85, 0.9)

# ══════════════════════════════════════════════
#  동작
# ══════════════════════════════════════════════
func _activate(id: String) -> void:
	SoundManager.play("ui_select", -10.0)
	if id.begins_with("slot_"):
		_pick_slot(int(id.substr(5)))
		return
	match id:
		"continue":
			_pending = "continue"
			_show("slots")
		"new":
			_pending = "new"
			_show("slots")
		"resume":
			close()
		"options":
			_show("options")
		"title":
			_show("title")
		"back":
			_show("pause" if get_tree().paused and _screen != "title" \
				and _pending == "" else "title")
		"vol_down":
			_nudge_volume(-4.0)
		"vol_up":
			_nudge_volume(4.0)
		"gfx_down":
			_nudge_graphics(-1)
		"gfx_up":
			_nudge_graphics(1)
		"boss_rush":
			_start_boss_rush()
		"quit":
			get_tree().quit()
		_:
			pass

func _pick_slot(i: int) -> void:
	var info := SaveGame.slot_info(i)
	if _pending == "new":
		# 세이브 파일뿐 아니라 오토로드에 남은 진행 상태까지 전부 초기값으로
		SaveGame.start_new_game(i)
		_start(false)
	else:
		if bool(info["empty"]):
			SoundManager.play("error", -12.0)
			return
		SaveGame.use_slot(i)
		_start(true)

## 슬롯을 정한 뒤 월드를 새로 만든다. 챕터·테마가 세이브에 따라 달라지므로
## 씬을 다시 읽는 것이 가장 안전하다 (챕터 이동과 같은 경로).
func _start(_loaded: bool) -> void:
	_pending = ""
	get_tree().paused = false
	SoundManager.set_paused(false)
	panel.visible = false
	owner_hud.show_loading(txt("loading", "불러오는 중…"))
	get_tree().create_timer(0.4, true, false, true).timeout.connect(
		func(): get_tree().reload_current_scene())

func _nudge_volume(db: float) -> void:
	SaveGame.master_db = clampf(SaveGame.master_db + db, -30.0, 6.0)
	SoundManager.set_master_db(SaveGame.master_db)
	SaveGame.save()
	_refresh()

func _nudge_graphics(step: int) -> void:
	SaveGame.graphics = clampi(SaveGame.graphics + step, 0,
		EnvironmentManager.level_count() - 1)
	var w = get_tree().current_scene
	if w and w.get("environment_manager") != null:
		w.environment_manager.apply_quality(SaveGame.graphics)
	SaveGame.save()
	_refresh()

## 보스 러시 — 엔딩 후에만 열린다. 진행은 World3D 가 맡는다.
func _start_boss_rush() -> void:
	if not SaveGame.boss_rush_unlocked():
		SoundManager.play("ui_deny", -8.0)
		return
	SaveGame.rush_index = 0
	SaveGame.save()
	_pending = ""
	get_tree().paused = false
	SoundManager.set_paused(false)
	panel.visible = false
	owner_hud.show_loading(txt("rush_start", "보스 러시 시작"))
	get_tree().create_timer(0.4, true, false, true).timeout.connect(
		func(): get_tree().reload_current_scene())

## HUD 가 키를 넘겨준다
func handle_key(keycode: int) -> bool:
	if not is_open():
		return false
	match keycode:
		KEY_ESCAPE:
			if _screen == "title":
				return true          ## 타이틀에서는 ESC 로 못 빠져나간다
			if _screen == "slots" or _screen == "options":
				_show("pause" if _pending == "" else "title")
			else:
				close()
			return true
		KEY_UP, KEY_DOWN:
			if _btns.is_empty():
				return true
			_sel = wrapi(_sel + (1 if keycode == KEY_DOWN else -1), 0, _btns.size())
			_highlight()
			return true
		KEY_LEFT, KEY_RIGHT:
			if _screen != "options" or _btns.is_empty():
				return true
			var rid := String(_rows[_sel]["id"])
			if rid.begins_with("vol_"):
				_nudge_volume(4.0 if keycode == KEY_RIGHT else -4.0)
			elif rid.begins_with("gfx_"):
				_nudge_graphics(1 if keycode == KEY_RIGHT else -1)
			return true
		KEY_ENTER, KEY_KP_ENTER:
			if _sel >= 0 and _sel < _btns.size() and not _btns[_sel].disabled:
				_btns[_sel].pressed.emit()
			return true
	return false
