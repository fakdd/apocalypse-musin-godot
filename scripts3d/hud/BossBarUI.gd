extends Node
class_name BossBarUI
## 보스 전용 체력바 — 화면 중앙 상단.
##
## 기존 HUD3D CanvasLayer 를 그대로 쓴다 (새 씬·새 오토로드 없음).
## 보스가 나타나면 내려오고, 죽으면 천천히 사라진다.
## 수치·문구는 data/bosses.json 과 data/feel.json 에서 온다.

const W := 720.0
const H := 26.0

var owner_hud: CanvasLayer

var root: Control
var name_label: Label
var sub_label: Label
var back: ColorRect
var fill: ColorRect
var lag: ColorRect          ## 늦게 따라오는 흰 잔여 바 (깎인 양이 보이게)
var phase_marks: Array = []

var _boss: Node3D = null
var _shown := 0.0           ## 화면에 표시 중인 비율
var _lag := 0.0
var _tween: Tween

func setup(h: CanvasLayer) -> void:
	owner_hud = h

func build() -> void:
	var hud := owner_hud
	root = Control.new()
	root.visible = false
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = Vector2((1280.0 - W) * 0.5, 40.0)
	root.size = Vector2(W, 78.0)
	hud.add_child(root)

	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.72))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(W, 30)
	root.add_child(name_label)

	sub_label = Label.new()
	sub_label.add_theme_font_size_override("font_size", 13)
	sub_label.add_theme_color_override("font_color", Color(0.72, 0.62, 0.58))
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.position = Vector2(0, 30)
	sub_label.size = Vector2(W, 18)
	root.add_child(sub_label)

	back = ColorRect.new()
	back.color = Color(0.10, 0.05, 0.06, 0.92)
	back.position = Vector2(0, 52)
	back.size = Vector2(W, H)
	root.add_child(back)

	lag = ColorRect.new()
	lag.color = Color(0.95, 0.88, 0.85, 0.55)
	lag.position = Vector2(2, 54)
	lag.size = Vector2(W - 4.0, H - 4.0)
	root.add_child(lag)

	fill = ColorRect.new()
	fill.color = Color(0.86, 0.14, 0.16)
	fill.position = Vector2(2, 54)
	fill.size = Vector2(W - 4.0, H - 4.0)
	root.add_child(fill)

	# 페이즈 경계선 — 어디서 단계가 바뀌는지 눈으로 보인다
	for at in [0.66, 0.33]:
		var m := ColorRect.new()
		m.color = Color(0, 0, 0, 0.7)
		m.position = Vector2(2.0 + (W - 4.0) * at, 54)
		m.size = Vector2(2, H - 4.0)
		root.add_child(m)
		phase_marks.append(m)

	GameManager.chapter_boss_defeated.connect(func(_c): hide_bar())

## 보스가 나타났다. LandmarkZone / World3D 가 부른다.
func show_for(boss: Node3D) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	_boss = boss
	var d := EnemyConfig.boss_def(String(boss.enemy_type))
	name_label.text = String(d.get("name", boss.enemy_type))
	sub_label.text = String(d.get("title", ""))
	_shown = 1.0
	_lag = 1.0
	fill.color = Color(0.86, 0.14, 0.16)
	root.visible = true

	# 위에서 내려오며 나타난다
	root.modulate.a = 0.0
	root.position.y = 10.0
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = owner_hud.create_tween().set_parallel(true)
	_tween.tween_property(root, "modulate:a", 1.0, 0.35)
	_tween.tween_property(root, "position:y", 40.0, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_bar() -> void:
	if root == null or not root.visible:
		return
	_boss = null
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = owner_hud.create_tween().set_parallel(true)
	_tween.tween_property(root, "modulate:a", 0.0, 0.8)
	_tween.tween_property(root, "position:y", 18.0, 0.8)
	_tween.chain().tween_callback(func(): root.visible = false)

func is_open() -> bool:
	return root != null and root.visible

## HUD3D._process 가 부른다.
func update_bar(delta: float) -> void:
	if root == null or not root.visible:
		return
	if _boss == null or not is_instance_valid(_boss) or _boss.dead:
		hide_bar()
		return

	var r: float = clampf(_boss.hp / maxf(_boss.max_hp, 1.0), 0.0, 1.0)
	var k: float = clampf(delta * CombatFeel.num("ui", "bar_lerp", 9.0), 0.0, 1.0)
	_shown = r if r > _shown else lerpf(_shown, r, k)
	# 잔여 바는 더 느리게 따라와 "방금 깎인 양"이 흰 띠로 남는다
	_lag = lerpf(_lag, _shown, k * 0.35)

	fill.size.x = (W - 4.0) * _shown
	lag.size.x = (W - 4.0) * maxf(_lag, _shown)

	# 광폭화 구간은 바 색이 바뀐다
	var enraged: bool = _boss.brain != null and _boss.brain.enraged
	fill.color = Color(1.0, 0.35, 0.15) if enraged else Color(0.86, 0.14, 0.16)
	var stage := 1
	if _boss.brain != null:
		stage = _boss.brain.boss_phase + 1
	sub_label.text = "%d단계   %d / %d%s" % [stage, int(_boss.hp), int(_boss.max_hp),
		"   ⚠ 광폭화" if enraged else ""]
