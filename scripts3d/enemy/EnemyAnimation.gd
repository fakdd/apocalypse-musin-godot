extends Node
class_name EnemyAnimation
## 적의 시각 요소 담당 — 모델 애니메이션, 눈/오라 연출, HP바, 피격 플래시,
## 데미지 숫자, 사망 폭발. 게임 로직은 넣지 않는다.

var owner_enemy: CharacterBody3D

func setup(e: CharacterBody3D) -> void:
	owner_enemy = e

## ── 애니메이션 이름 해석 · 재생 ──

func _resolve_anim_names() -> void:
	if owner_enemy.anim == null:
		return
	var names: PackedStringArray = owner_enemy.anim.get_animation_list()
	owner_enemy.anim_idle = _pick(names, ["Idle", "Flying_Idle"])
	# Mixamo 베이스 클립이 정지 포즈(0.1초 미만)면 Walk 로 대체
	if owner_enemy.anim_idle != "" and owner_enemy.anim.has_animation(owner_enemy.anim_idle):
		if owner_enemy.anim.get_animation(owner_enemy.anim_idle).length < 0.15:
			owner_enemy.anim_idle = _pick(names, ["Walk", "Fast_Flying", "Idle"])
	owner_enemy.anim_move = _pick(names, ["Walk", "Fast_Flying", "Run", "Flying_Idle"])
	owner_enemy.anim_attack = _pick(names, ["Punch", "Headbutt", "Bite", "JumpAttack", "Punch2"])
	owner_enemy.anim_hit = _pick(names, ["HitReact"])
	owner_enemy.anim_death = _pick(names, ["Death"])

func _pick(names: PackedStringArray, wanted: Array) -> String:
	for w in wanted:
		if names.has(w):
			return w
	return ""

func _play(name: String, force: bool = false) -> void:
	if owner_enemy.anim == null or name == "":
		return
	if not owner_enemy.anim.has_animation(name):
		return
	if not force and owner_enemy.anim.current_animation == name:
		return
	owner_enemy.anim.play(name)

## ── 모델 트리 탐색 ──

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var found := _find_anim_player(c)
		if found:
			return found
	return null

func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		owner_enemy.mesh_instances.append(node)
	for c in node.get_children():
		_collect_meshes(c)

func _apply_tint(tint: Color) -> void:
	for mi in owner_enemy.mesh_instances:
		if not is_instance_valid(mi):
			continue
		var base_mat: Material = mi.get_active_material(0)
		if base_mat is StandardMaterial3D:
			var dup: StandardMaterial3D = base_mat.duplicate()
			dup.albedo_color = tint
			mi.material_override = dup

## ── 연출: 붉은 눈 / 차원 오라 ──

func _add_glowing_eyes() -> void:
	var eye_y: float = owner_enemy.hover_height + owner_enemy.hit_radius * 1.7
	var spread: float = clampf(owner_enemy.hit_radius * 0.32, 0.09, 0.32)
	var r: float = clampf(owner_enemy.hit_radius * 0.13, 0.05, 0.2)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = r
		sph.height = r * 2.0
		eye.mesh = sph
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.15, 0.1)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.1, 0.06)
		m.emission_energy_multiplier = 9.0
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		eye.material_override = m
		eye.position = Vector3(side * spread, eye_y, owner_enemy.hit_radius * 0.62)
		owner_enemy.add_child(eye)

	var glow := OmniLight3D.new()
	glow.position = Vector3(0, eye_y, owner_enemy.hit_radius * 0.5)
	glow.light_color = Color(1.0, 0.2, 0.12)
	glow.light_energy = 1.1
	glow.omni_range = 3.0
	owner_enemy.add_child(glow)

func _add_aura(color: Color) -> void:
	var aura := MeshInstance3D.new()
	var sph := SphereMesh.new()
	var rad: float = owner_enemy.hit_radius * 1.5
	sph.radius = rad
	sph.height = rad * 2.0
	aura.mesh = sph
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, 0.16)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.2
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	aura.material_override = m
	aura.position.y = owner_enemy.hover_height + owner_enemy.hit_radius * 0.9
	owner_enemy.add_child(aura)

	var light := OmniLight3D.new()
	light.position = aura.position
	light.light_color = color
	light.light_energy = 2.5
	light.omni_range = owner_enemy.hit_radius * 7.0
	owner_enemy.add_child(light)

	var tw := owner_enemy.create_tween().set_loops()
	tw.tween_property(aura, "scale", Vector3(1.14, 1.14, 1.14), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(aura, "scale", Vector3(0.92, 0.92, 0.92), 0.9).set_trans(Tween.TRANS_SINE)

## ── HP 바 ──

func _build_hp_bar() -> void:
	if owner_enemy.max_hp <= 1.0:
		return
	var bar_y: float = owner_enemy.hover_height + owner_enemy.hit_radius * 2.4 + 0.5
	var width: float = 48.0 if not owner_enemy.is_boss_type() else 140.0

	owner_enemy.hp_bar_bg = Sprite3D.new()
	owner_enemy.hp_bar_bg.texture = _make_bar_texture(Color(0, 0, 0, 0.75), int(width))
	owner_enemy.hp_bar_bg.pixel_size = 0.012
	owner_enemy.hp_bar_bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	owner_enemy.hp_bar_bg.no_depth_test = true
	owner_enemy.hp_bar_bg.position = Vector3(0, bar_y, 0)
	owner_enemy.add_child(owner_enemy.hp_bar_bg)

	owner_enemy.hp_bar_fill = Sprite3D.new()
	var fill_col := Color(0.35, 0.95, 0.4) if not owner_enemy.is_boss_type() else Color(1.0, 0.3, 0.25)
	owner_enemy.hp_bar_fill.texture = _make_bar_texture(fill_col, int(width))
	owner_enemy.hp_bar_fill.pixel_size = 0.012
	owner_enemy.hp_bar_fill.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	owner_enemy.hp_bar_fill.no_depth_test = true
	owner_enemy.hp_bar_fill.position = Vector3(0, bar_y, 0.02)
	owner_enemy.add_child(owner_enemy.hp_bar_fill)

func _make_bar_texture(color: Color, width: int) -> ImageTexture:
	var img := Image.create(width, 8, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

## ── 피격 연출 ──

## 피격 플래시 — 2단계로 바뀐다.
##   1단계: 순백 (0.05초) — 타격이 "꽂힌" 순간
##   2단계: 붉은 잔상 (피해 비율만큼 길게) — 아팠다는 여운
## 이전에는 0.09초 흰색 단색이라 큰 타격과 작은 타격이 시각적으로 구분되지 않았다.
## 피격/반응 발광. PlayerAnimation 과 이름을 맞춘다.
##
## 호출부(EnemyBrain 의 치유·강화·광폭화, Enemy3D 의 부활)는 `_flash()` 를 부르는데
## 이 스크립트에는 `_do_flash()` 밖에 없어서 "Nonexistent function '_flash'" 로 튕겼다.
## 색과 길이를 받아 두되, 기존 연출을 그대로 쓰도록 _do_flash 로 넘긴다.
func _flash(color: Color = Color.WHITE, duration: float = 0.1) -> void:
	# 밝은 색일수록 세게 번쩍인다 (기존 damage_ratio 를 밝기로 환산)
	var ratio: float = clampf((color.r + color.g + color.b) / 3.0, 0.1, 1.0)
	_do_flash(ratio * clampf(duration / 0.1, 0.5, 2.0))

func _do_flash(damage_ratio: float = 0.2) -> void:
	var saved := []
	for mi in owner_enemy.mesh_instances:
		if is_instance_valid(mi):
			saved.append([mi, mi.material_override])
			mi.material_override = owner_enemy.flash_mat
	var restore := func():
		for pair in saved:
			if is_instance_valid(pair[0]):
				pair[0].material_override = pair[1]

	var heavy: bool = damage_ratio >= 0.15
	var tw := owner_enemy.create_tween()
	tw.tween_interval(0.05)
	if heavy:
		# 큰 타격 — 흰색 뒤에 붉은 잔상을 얹는다
		tw.tween_callback(func():
			for pair in saved:
				if is_instance_valid(pair[0]):
					pair[0].material_override = owner_enemy.hurt_mat
		)
		tw.tween_interval(lerpf(0.06, 0.18, clampf(damage_ratio, 0.0, 1.0)))
	tw.tween_callback(restore)

## 데미지 숫자 — 풀에서 꺼내 쓰고 반납한다 (피격마다 Label3D 를 새로 만들지 않는다).
## 피해 비율에 따라 글자 크기와 색이 달라져 큰 타격이 눈에 들어온다.
## 직전 타격이 치명타였는가 (Enemy3D.take_damage 가 세운다)
var crit_hit := false

func _spawn_damage_number(amount: float) -> void:
	var lbl := VfxPool.take_damage_label(owner_enemy.get_parent())
	if lbl == null:
		return          ## 동시 표시 상한 — 화면을 덮지 않게 이번 숫자는 건너뛴다
	var ratio: float = clampf(amount / maxf(owner_enemy.max_hp, 1.0), 0.0, 1.0)
	# 큰 피해는 크고 붉게, 작은 피해는 작고 노랗게
	lbl.text = str(int(amount))
	lbl.pixel_size = lerpf(0.010, 0.018, ratio)
	lbl.modulate = Color(1, 1, 0.7).lerp(Color(1.0, 0.55, 0.3), ratio)
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0, 0, 0)
	# 치명타는 확실히 달라 보여야 한다 — 크게 · 주황 발광 · 느낌표
	if crit_hit:
		crit_hit = false
		lbl.text = "%d!" % int(amount)
		lbl.pixel_size *= 1.75
		lbl.modulate = Color(1.0, 0.62, 0.18)
		lbl.outline_size = 20
		lbl.outline_modulate = Color(0.55, 0.16, 0.0)
	lbl.modulate.a = 1.0
	lbl.global_position = owner_enemy.global_position + Vector3(randf_range(-0.3, 0.3), owner_enemy.hover_height + owner_enemy.hit_radius * 2.0, 0)
	var start_y: float = lbl.position.y
	var tw := owner_enemy.create_tween()
	tw.tween_property(lbl, "position:y", start_y + lerpf(1.0, 1.8, ratio), 0.5)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): VfxPool.give_damage_label(lbl))

## ── 사망 폭발 ──

func _spawn_death_burst() -> void:
	var scale_f: float = 1.0 if not owner_enemy.is_boss_type() else 3.0
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6 * scale_f
	sphere.height = 1.2 * scale_f
	mesh.mesh = sphere
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.35, 0.3, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(1.0, 0.3, 0.2)
	m.emission_energy_multiplier = 3.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = m
	mesh.position = owner_enemy.global_position + Vector3(0, owner_enemy.hover_height + 0.7, 0)
	owner_enemy.get_parent().add_child(mesh)
	var tw := owner_enemy.create_tween()
	tw.tween_property(mesh, "scale", Vector3(2.4, 2.4, 2.4), 0.35)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(mesh.queue_free)
