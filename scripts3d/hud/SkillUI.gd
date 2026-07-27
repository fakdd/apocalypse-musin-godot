extends Node
class_name SkillUI
## 우하단 스킬 버튼 담당 — 원형 버튼, 쿨다운 오버레이, 장착 무기 아이콘(3D/이미지).

var owner_hud: CanvasLayer

func setup(h: CanvasLayer) -> void:
	owner_hud = h

func _skill_button(pos: Vector2, radius: float, key: String, glyph: String, col: Color) -> Dictionary:
	var hud := owner_hud
	var btn := Panel.new()
	btn.position = pos
	btn.size = Vector2(radius * 2, radius * 2)
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.05, 0.06, 0.94)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(radius))
	sb.shadow_color = Color(col.r, col.g, col.b, 0.4)
	sb.shadow_size = 5
	btn.add_theme_stylebox_override("panel", sb)
	hud.add_child(btn)

	var icon := Label.new()
	icon.text = glyph
	icon.add_theme_font_size_override("font_size", int(radius * 0.8))
	icon.add_theme_color_override("font_color", col)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_child(icon)

	var cd := ColorRect.new()
	cd.color = Color(0, 0, 0, 0.62)
	cd.position = Vector2.ZERO
	cd.size = btn.size
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(cd)

	var cdtext := Label.new()
	cdtext.add_theme_font_size_override("font_size", int(radius * 0.55))
	cdtext.add_theme_color_override("font_color", Color(1, 1, 1))
	cdtext.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cdtext.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cdtext.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_child(cdtext)

	var keyl := Label.new()
	keyl.text = key
	keyl.add_theme_font_size_override("font_size", 11)
	keyl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	keyl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keyl.position = Vector2(-8, radius * 2 - 2)
	keyl.size = Vector2(radius * 2 + 16, 16)
	btn.add_child(keyl)

	return {"panel": btn, "cd": cd, "cdtext": cdtext, "full": btn.size.y}

## 좌클릭 버튼 안에 장착 무기 스킨을 3D로 띄운다.
func _make_weapon_viewport(parent: Control, vsize: Vector2) -> void:
	var hud := owner_hud
	var vc := SubViewportContainer.new()
	vc.stretch = true
	vc.position = Vector2(6, 6)
	vc.size = vsize
	vc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(vc)

	var vp := SubViewport.new()
	vp.size = Vector2i(int(vsize.x), int(vsize.y))
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vc.add_child(vp)
	hud._add_ui_env(vp)

	var pivot := Node3D.new()
	vp.add_child(pivot)
	hud.weapon_icon_mesh = MeshInstance3D.new()
	hud.weapon_icon_mesh.rotation_degrees = Vector3(0, 0, 38)
	pivot.add_child(hud.weapon_icon_mesh)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 2.1)
	cam.fov = 46
	vp.add_child(cam)
	cam.make_current()

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-20, 140, 0)
	key.light_energy = 2.0
	vp.add_child(key)
	hud.weapon_icon_holder = vc

func build() -> void:
	var hud := owner_hud
	hud.skill_buttons["slash"] = _skill_button(Vector2(1150, 556), 46, "좌클릭", "", hud.RED)
	_make_weapon_viewport(hud.skill_buttons["slash"]["panel"], Vector2(80, 80))
	# 아이콘 이미지를 3D 위에 겹쳐 실루엣을 또렷하게
	hud.weapon_icon_tex = TextureRect.new()
	hud.weapon_icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hud.weapon_icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hud.weapon_icon_tex.position = Vector2(16, 16)
	hud.weapon_icon_tex.size = Vector2(60, 60)
	hud.weapon_icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.skill_buttons["slash"]["panel"].add_child(hud.weapon_icon_tex)
	hud.skill_buttons["ult"]   = _skill_button(Vector2(1054, 506), 32, "Q", "天", Color(0.95, 0.55, 0.2))
	hud.skill_buttons["dash"]  = _skill_button(Vector2(1000, 578), 30, "Shift", "步", Color(0.35, 0.7, 1.0))
	hud.skill_buttons["beam"]  = _skill_button(Vector2(1062, 636), 28, "E", "氣", Color(0.5, 0.9, 1.0))
	hud.skill_buttons["parry"] = _skill_button(Vector2(1140, 668), 26, "F", "還", hud.GOLD)

## 장착 무기가 바뀌었으면 아이콘을 갱신한다
func refresh_weapon_icon() -> void:
	var hud := owner_hud
	if hud.weapon_icon_mesh == null:
		return
	var w: ItemData = PlayerStats.equipped.get("weapon", null)
	var r: int = w.rarity if w else -1
	if r == hud.weapon_icon_rarity and w != null:
		return
	hud.weapon_icon_rarity = r
	if w == null:
		hud.weapon_icon_mesh.visible = false
		if hud.weapon_icon_tex:
			hud.weapon_icon_tex.visible = false
		return
	hud.weapon_icon_mesh.visible = true
	hud.weapon_icon_mesh.mesh = ItemSkins.build_mesh(w.skin)
	hud.weapon_icon_mesh.material_override = ItemSkins.build_material(w.rarity)
	if hud.weapon_icon_tex:
		var ip := ItemSkins.icon_path(w.skin)
		if ip != "":
			hud.weapon_icon_tex.texture = load(ip)
			hud.weapon_icon_tex.modulate = w.get_color()
			hud.weapon_icon_tex.visible = true
			# 아이콘이 있으면 3D 는 뒤에서 은은하게만
			hud.weapon_icon_mesh.visible = false
		else:
			hud.weapon_icon_tex.visible = false

## 무기 3D 아이콘을 천천히 회전시킨다
func spin_weapon_icon(delta: float) -> void:
	var hud := owner_hud
	if hud.weapon_icon_mesh and hud.weapon_icon_mesh.visible:
		hud.weapon_icon_mesh.get_parent().rotation.y += delta * 0.9

func update_cooldowns(p) -> void:
	var hud := owner_hud
	_set_cd("slash", p.atk_cd, p.ATTACK_COOLDOWN)
	_set_cd("dash", p.dash_cd, p.DASH_COOLDOWN)
	_set_cd("beam", p.ranged_cd, p.RANGED_COOLDOWN)
	_set_cd("parry", p.parry_cd, p.PARRY_COOLDOWN)
	var ult_ratio: float = 1.0 - clampf(p.ult_gauge / maxf(p.ult_max, 1.0), 0.0, 1.0)
	var d: Dictionary = hud.skill_buttons["ult"]
	d["cd"].size.y = d["full"] * ult_ratio
	d["cdtext"].text = "" if ult_ratio <= 0.001 else "%d%%" % int((1.0 - ult_ratio) * 100)

func _set_cd(key: String, remain: float, total: float) -> void:
	var hud := owner_hud
	if not hud.skill_buttons.has(key):
		return
	var d: Dictionary = hud.skill_buttons[key]
	var ratio: float = clampf(remain / maxf(total, 0.001), 0.0, 1.0)
	d["cd"].size.y = d["full"] * ratio
	d["cdtext"].text = "" if remain <= 0.05 else "%.1f" % remain
