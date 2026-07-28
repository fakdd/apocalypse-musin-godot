extends Node
class_name AchievementUI
## 업적 표시 — 우측 상단 토스트 + 목록 창(J 로 열고 닫는다).
##
## 기존 HUD 위에 얹는다. 새 HUD 를 만들지 않고 CanvasLayer 하나를 공유한다.

const TOAST_W := 320.0
const TOAST_H := 64.0
const TOAST_HOLD := 3.2

var owner_hud: CanvasLayer

var toast_panel: Panel
var toast_title: Label
var toast_desc: Label
var list_panel: Control
var list_text: RichTextLabel
var list_header: Label

var _tween: Tween
## 동시에 여러 개가 달성되면 줄을 세운다 (겹쳐 뜨면 못 읽는다)
var _queue: Array = []
var _showing := false

func setup(h: CanvasLayer) -> void:
	owner_hud = h

func build() -> void:
	_build_toast()
	_build_list()
	AchievementManager.unlocked.connect(_on_unlocked)

func _build_toast() -> void:
	var hud := owner_hud
	# 미니맵(1062,12 크기 206) 아래에 둔다 — 겹치지 않는 자리
	toast_panel = Panel.new()
	toast_panel.position = Vector2(1280 - TOAST_W - 14, 228)
	toast_panel.size = Vector2(TOAST_W, TOAST_H)
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.modulate.a = 0.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.03, 0.94)
	sb.border_color = hud.GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(hud.GOLD.r, hud.GOLD.g, hud.GOLD.b, 0.35)
	sb.shadow_size = 7
	toast_panel.add_theme_stylebox_override("panel", sb)
	hud.add_child(toast_panel)

	var badge := Label.new()
	badge.text = "◈ 업적 달성"
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", Color(0.75, 0.68, 0.45))
	badge.position = Vector2(12, 6)
	toast_panel.add_child(badge)

	toast_title = Label.new()
	toast_title.add_theme_font_size_override("font_size", 17)
	toast_title.add_theme_color_override("font_color", hud.GOLD)
	toast_title.position = Vector2(12, 20)
	toast_title.size = Vector2(TOAST_W - 24, 22)
	toast_panel.add_child(toast_title)

	toast_desc = Label.new()
	toast_desc.add_theme_font_size_override("font_size", 12)
	toast_desc.add_theme_color_override("font_color", Color(0.78, 0.76, 0.74))
	toast_desc.position = Vector2(12, 42)
	toast_desc.size = Vector2(TOAST_W - 24, 18)
	toast_panel.add_child(toast_desc)

func _build_list() -> void:
	var hud := owner_hud
	list_panel = Control.new()
	list_panel.visible = false
	list_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(list_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.02, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	list_panel.add_child(bg)

	list_header = Label.new()
	list_header.add_theme_font_size_override("font_size", 26)
	list_header.add_theme_color_override("font_color", hud.GOLD)
	list_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list_header.position = Vector2(0, 40)
	list_header.size = Vector2(1280, 34)
	list_panel.add_child(list_header)

	list_text = RichTextLabel.new()
	list_text.bbcode_enabled = true
	list_text.scroll_active = true
	list_text.add_theme_font_size_override("normal_font_size", 14)
	list_text.position = Vector2(200, 92)
	list_text.size = Vector2(880, 540)
	list_panel.add_child(list_text)

	var hint := Label.new()
	hint.text = "[U] 닫기"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 646)
	hint.size = Vector2(1280, 20)
	list_panel.add_child(hint)

# ══════════════════════════════════════════════
#  토스트
# ══════════════════════════════════════════════
func _on_unlocked(_id: String, d: Dictionary) -> void:
	show_achievement(String(d.get("name", "")), String(d.get("desc", "")))

func show_achievement(title: String, desc: String) -> void:
	_queue.append([title, desc])
	if not _showing:
		_next()

func _next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var row: Array = _queue.pop_front()
	toast_title.text = String(row[0])
	toast_desc.text = String(row[1])

	if _tween and _tween.is_valid():
		_tween.kill()
	toast_panel.modulate.a = 0.0
	toast_panel.position.x = 1280 - TOAST_W + 20     ## 오른쪽에서 밀려 들어온다
	_tween = owner_hud.create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.25)
	_tween.tween_property(toast_panel, "position:x", 1280 - TOAST_W - 14, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(false)
	_tween.tween_interval(TOAST_HOLD)
	_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.5)
	_tween.tween_callback(_next)

# ══════════════════════════════════════════════
#  목록
# ══════════════════════════════════════════════
func toggle_list() -> void:
	list_panel.visible = not list_panel.visible
	if list_panel.visible:
		owner_hud.close_windows(self)
		_refresh_list()
		owner_hud.pop_in(list_panel)

func is_list_open() -> bool:
	return list_panel != null and list_panel.visible

func _refresh_list() -> void:
	var got := AchievementManager.earned()
	var all := AchievementManager.total()
	var pct: float = (float(got) / float(maxi(all, 1))) * 100.0
	var tail := ""
	if SaveGame.ng_plus > 0:
		tail = "      NEW GAME+ %d · 월드 티어 %s" % [SaveGame.ng_plus, SaveGame.tier_name()]
	list_header.text = "◈ 업적    %d / %d   (%.0f%%)%s" % [got, all, pct, tail]

	var lines := []
	for a in AchievementManager.listing():
		var done: bool = a["done"]
		var hidden: bool = a["hidden"] and not done
		var name: String = "???" if hidden else String(a["name"])
		var desc: String = "숨겨진 업적" if hidden else String(a["desc"])
		var mark := "[color=#e8c26a]✔[/color]" if done else "[color=#4a4a52]○[/color]"
		var col := "#e8c26a" if done else "#8a8a92"
		var prog := ""
		if not done and int(a["target"]) > 1:
			prog = "  [color=#6a8fbf](%d/%d)[/color]" % [int(a["progress"]), int(a["target"])]
		lines.append("%s  [color=%s][b]%s[/b][/color]%s\n      [color=#70707a]%s[/color]"
			% [mark, col, name, prog, desc])
	list_text.text = "\n".join(lines)
