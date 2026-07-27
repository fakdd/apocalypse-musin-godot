extends CanvasLayer
## HUDRoot — 메인 HUD (다크 레드 판타지 스타일)의 오케스트레이터.
## 공유 위젯 팩토리(_framed_panel/_bar/_make_model_viewport)와 노드 참조를 보유하고,
## 실제 구축/갱신은 하위 모듈에 위임한다.
##   HealthUI  — 좌상단: 초상화 + 이름/일차 + HP/내공 바 + 자원 라벨
##   MiniMapUI — 우상단: 원형 미니맵
##   QuestUI   — 상단중앙 페이즈/웨이브 상태 + 퀘스트 추적
##   SkillUI   — 우하단: 스킬 버튼 + 쿨다운 + 무기 아이콘
##   DamageUI  — 저체력 비네트
##   PopupUI   — 배너/토스트/튜토리얼/게임오버/승리
## 외부 공개 API(show_banner 등)는 이 파일에 그대로 남아 위임한다.

const RED := Color(0.78, 0.10, 0.13)
const RED_DIM := Color(0.35, 0.06, 0.08)
const GOLD := Color(0.85, 0.70, 0.35)
const PANEL_BG := Color(0.06, 0.05, 0.06, 0.88)

var name_label: Label
var trait_label: Label
var level_label: Label
var hp_bar: ColorRect
var hp_text: Label
var mp_bar: ColorRect
var mp_text: Label
var gear_label: Label
var essence_label: Label
var base_label: Label
var kill_label: Label

var mini_map: Control
var quest_panel: Panel
var quest_lines: Label

var phase_label: Label
var wave_label: Label
var timer_label: Label

var skill_buttons := {}
var banner_label: Label
var toast: Label
var vignette: ColorRect
var tutorial_panel: Control
var game_over_panel: Control
var game_over_label: Label
var victory_panel: Control
var stats_window: CanvasLayer
var inventory_ui: CanvasLayer
var portrait_holder: Control
var weapon_icon_holder: Control
var weapon_icon_mesh: MeshInstance3D
var weapon_icon_rarity := -99
var weapon_icon_tex: TextureRect

# UI 모듈
var health_ui: HealthUI
var skill_ui: SkillUI
var minimap_ui: MiniMapUI
var quest_ui: QuestUI
var damage_ui: DamageUI
var popup_ui: PopupUI
var landmark_ui: LandmarkUI

func _ready() -> void:
	layer = 10
	_create_modules()
	# 구축 순서 = 원본 그대로 (CanvasLayer 자식 순서가 그리기 순서를 정한다)
	damage_ui.build()
	health_ui.build()
	minimap_ui.build()
	quest_ui.build_quest_panel()
	quest_ui.build_center_status()
	skill_ui.build()
	landmark_ui.build()
	popup_ui.build_banner()
	popup_ui.build_toast()
	popup_ui.build_tutorial()
	popup_ui.build_game_over()
	popup_ui.build_victory()

	stats_window = load("res://scripts3d/StatsWindow.gd").new()
	add_child(stats_window)
	inventory_ui = load("res://scripts3d/InventoryUI.gd").new()
	add_child(inventory_ui)

func _create_modules() -> void:
	health_ui = HealthUI.new()
	health_ui.name = "HealthUI"
	skill_ui = SkillUI.new()
	skill_ui.name = "SkillUI"
	minimap_ui = MiniMapUI.new()
	minimap_ui.name = "MiniMapUI"
	quest_ui = QuestUI.new()
	quest_ui.name = "QuestUI"
	damage_ui = DamageUI.new()
	damage_ui.name = "DamageUI"
	popup_ui = PopupUI.new()
	popup_ui.name = "PopupUI"
	landmark_ui = LandmarkUI.new()
	landmark_ui.name = "LandmarkUI"
	for m in [health_ui, skill_ui, minimap_ui, quest_ui, damage_ui, popup_ui, landmark_ui]:
		m.setup(self)
		add_child(m)

## ── 공유 위젯 팩토리 — 여러 모듈이 함께 쓴다 ──

func _framed_panel(pos: Vector2, size: Vector2, border: Color = RED) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(border.r, border.g, border.b, 0.35)
	sb.shadow_size = 5
	p.add_theme_stylebox_override("panel", sb)
	add_child(p)
	return p

func _bar(parent: Control, pos: Vector2, size: Vector2, col: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.position = pos
	bg.size = size
	bg.color = Color(0.05, 0.04, 0.05, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var fill := ColorRect.new()
	fill.position = pos
	fill.size = size
	fill.color = col
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)
	return fill

## UI 뷰포트 전용 환경 — 메인 씬의 톤매핑/글로우에 영향받지 않게 한다.
func _add_ui_env(vp: SubViewport) -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.5, 0.52)
	e.ambient_light_energy = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.tonemap_exposure = 1.0
	we.environment = e
	vp.add_child(we)

## 3D 모델을 UI 안에 렌더하는 SubViewport 를 만든다.
func _make_model_viewport(parent: Control, vsize: Vector2, scene_path: String,
		cam_pos: Vector3, cam_rot_deg: Vector3, fov: float) -> Control:
	var vc := SubViewportContainer.new()
	vc.stretch = true
	vc.position = Vector2(2, 2)
	vc.size = vsize
	vc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(vc)

	var vp := SubViewport.new()
	vp.size = Vector2i(int(vsize.x), int(vsize.y))
	vp.transparent_bg = true
	vp.own_world_3d = true
	# 초상화는 대기 애니메이션이 돌아야 하므로 매 프레임 갱신이 필요하다.
	# 다만 78×78 픽셀이라 렌더 비용 자체는 작다. 대신 그림자를 끄고
	# 디버그 오브젝트를 배제해 이 작은 뷰포트가 전체 렌더 예산을 먹지 않게 한다.
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.positional_shadow_atlas_size = 0
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_debanding = false
	vc.add_child(vp)
	_add_ui_env(vp)

	var packed: PackedScene = load(scene_path)
	if packed:
		var inst: Node3D = packed.instantiate()
		# 모델 정면이 이미 카메라(+Z) 쪽을 향한다. 살짝만 틀어 3/4 앵글로.
		inst.rotation_degrees = Vector3(0, 18, 0)
		vp.add_child(inst)
		# 대기 애니메이션 재생
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		if ap and ap.has_animation("idle"):
			ap.play("idle")

	var cam := Camera3D.new()
	cam.position = cam_pos
	cam.rotation_degrees = cam_rot_deg
	cam.fov = fov
	vp.add_child(cam)
	cam.make_current()

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-22, 20, 0)
	key.light_energy = 2.6
	key.light_color = Color(1.0, 0.88, 0.82)
	vp.add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(-0.9, 1.5, 1.4)
	rim.light_color = Color(1.0, 0.3, 0.25)
	rim.light_energy = 3.0
	rim.omni_range = 4.0
	vp.add_child(rim)
	return vc

## ── 공개 API — 외부(World/매니저)가 호출한다. 모듈로 위임 ──

func show_banner(text: String) -> void:
	popup_ui.show_banner(text)

func show_toast(text: String, col: Color = Color.WHITE) -> void:
	popup_ui.show_toast(text, col)

func show_tutorial() -> void:
	tutorial_panel.visible = true

func is_tutorial_active() -> bool:
	return tutorial_panel.visible

func show_victory() -> void:
	popup_ui.show_victory()

func show_game_over(reason: String) -> void:
	popup_ui.show_game_over(reason)

## ── 매 프레임 갱신 — 원본 _process 와 동일한 순서 ──

func _process(_delta: float) -> void:
	if popup_ui.handle_popup_input():
		return

	health_ui.update_identity()

	var player := Battlefield.player
	if player and is_instance_valid(player):
		var hr: float = health_ui.update_bars(player)
		damage_ui.update_vignette(hr)
		skill_ui.update_cooldowns(player)

	health_ui.update_resources()
	quest_ui.update_phase_status()

	skill_ui.refresh_weapon_icon()
	skill_ui.spin_weapon_icon(_delta)

	quest_ui.refresh_quest()

## ── 창 토글 입력 (Tab/I/ESC) ──

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			if inventory_ui and inventory_ui.visible:
				inventory_ui.visible = false
			if stats_window:
				stats_window.toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_I:
			if stats_window and stats_window.visible:
				stats_window.visible = false
			if inventory_ui:
				inventory_ui.toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			var closed := false
			if stats_window and stats_window.visible:
				stats_window.visible = false
				closed = true
			if inventory_ui and inventory_ui.visible:
				inventory_ui.visible = false
				closed = true
			if closed:
				get_viewport().set_input_as_handled()
