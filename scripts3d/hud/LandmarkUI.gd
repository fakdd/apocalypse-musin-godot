extends Node
class_name LandmarkUI
## 랜드마크 진입 연출 — 화면 하단에 이름/부제/설명 카드를 띄운다.
##
## 왜 배너(show_banner)를 쓰지 않았나:
##   배너는 1.5초 뒤 사라지는 한 줄짜리라서 3~4줄 설명을 읽을 시간이 없다.
##   랜드마크는 "환경 스토리텔링"이 핵심이므로 읽을 시간을 주는 별도 카드가 필요하다.

const CARD_W := 560.0
const SHOW_TIME := 4.2        ## 카드가 머무는 시간 (설명을 읽을 수 있을 만큼)
const FADE_TIME := 0.7

var owner_hud: CanvasLayer

var card: Panel
var title_label: Label
var subtitle_label: Label
var desc_label: Label
var status_label: Label
var reward_label: Label
var _pending_reward := ""
var _tween: Tween

func setup(h: CanvasLayer) -> void:
	owner_hud = h

func build() -> void:
	var hud := owner_hud
	card = Panel.new()
	card.position = Vector2(360, 430)
	card.size = Vector2(CARD_W, 150)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.05, 0.90)
	sb.border_color = hud.GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(hud.GOLD.r, hud.GOLD.g, hud.GOLD.b, 0.3)
	sb.shadow_size = 6
	card.add_theme_stylebox_override("panel", sb)
	hud.add_child(card)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", hud.GOLD)
	title_label.position = Vector2(18, 10)
	card.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override("font_color", Color(0.72, 0.68, 0.66))
	subtitle_label.position = Vector2(20, 40)
	card.add_child(subtitle_label)

	desc_label = Label.new()
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.85, 0.84, 0.86))
	desc_label.position = Vector2(18, 62)
	desc_label.size = Vector2(CARD_W - 36, 72)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	card.add_child(desc_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.position = Vector2(CARD_W - 200, 12)
	status_label.size = Vector2(182, 18)
	card.add_child(status_label)

	reward_label = Label.new()
	reward_label.add_theme_font_size_override("font_size", 13)
	reward_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward_label.position = Vector2(CARD_W - 200, 30)
	reward_label.size = Vector2(182, 18)
	card.add_child(reward_label)

	LandmarkRegistry.landmark_entered.connect(_on_entered)
	LandmarkRegistry.landmark_cleared.connect(_on_cleared)
	LandmarkRegistry.explore_reward.connect(_on_explore_reward)

## 보상은 진입 신호보다 먼저 온다 (LandmarkRegistry.notify_enter 순서).
## 그래서 여기서는 문구만 챙겨 두고, 카드를 띄우는 _on_entered 가 소비한다.
func _on_explore_reward(_data: LandmarkData, exp_gain: int, essence: int) -> void:
	_pending_reward = "+%d EXP   +%d 마석" % [exp_gain, essence]

func _on_entered(data: LandmarkData) -> void:
	title_label.text = data.display_name
	subtitle_label.text = data.subtitle
	desc_label.text = data.description
	reward_label.text = _pending_reward
	_pending_reward = ""
	if data.cleared:
		status_label.text = "탐험 완료 ✔"
		status_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))
	elif data.visited_count > 1:
		status_label.text = "재방문 (%d회)" % data.visited_count
		status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	else:
		status_label.text = "◈ 최초 발견"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_show()

func _on_cleared(data: LandmarkData) -> void:
	if owner_hud.has_method("show_banner"):
		owner_hud.show_banner("◈ %s 탐험 완료" % data.display_name)
	SoundManager.play("rescue", -6.0)

func _show() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	card.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(card, "modulate:a", 1.0, 0.3)
	_tween.tween_interval(SHOW_TIME)
	_tween.tween_property(card, "modulate:a", 0.0, FADE_TIME)
