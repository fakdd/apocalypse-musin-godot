extends Node
## VFX 오브젝트 풀 — 데미지 숫자와 기탄을 재사용한다.
##
## 왜 필요했나:
##   · 데미지 숫자(Label3D)를 **피격마다** new/queue_free 했다. 광역기로 10마리를 때리면
##     한 프레임에 Label3D 10개 + Tween 10개가 생기고 0.5초 뒤 전부 해제된다.
##     초당 수십 개의 노드 생성/파괴는 GC 압박과 프레임 스파이크로 이어진다.
##   · 기탄(Area3D + 스크립트 + 메시)도 발사마다 런타임 조립했다.
##     보스 페이즈 3 은 한 번에 7발을 뿌리므로 초당 수 발 × 노드 3개씩 생성됐다.
##
## 어떻게:
##   미리 만들어 두고 숨긴 채 재사용한다. 풀이 비면 새로 만들되(안전), 반납 시 풀에 쌓인다.
##   풀 크기 상한을 둬서 메모리가 무한히 늘지 않게 한다.

const DAMAGE_POOL_MAX := 40        ## 화면에 동시에 뜰 수 있는 데미지 숫자의 현실적 상한
const PROJECTILE_POOL_MAX := 48

var _damage_pool: Array[Label3D] = []
var _projectile_pool: Array[Area3D] = []

## 통계 (성능 보고용)
var damage_created := 0
var damage_reused := 0
var projectile_created := 0
var projectile_reused := 0

func _ready() -> void:
	# 씬을 다시 로드하면 풀에 들어 있던 노드는 무효가 되므로 비운다
	GameManager.phase_changed.connect(func(_p): _prune())

## ── 데미지 숫자 ──

## 풀에서 Label3D 를 꺼낸다. parent 아래에 붙여 반환한다.
## 화면에 한꺼번에 뜨는 데미지 숫자 상한.
## 떼전투에서 숫자가 캐릭터를 완전히 덮어 아무것도 안 보였다.
const ACTIVE_DAMAGE_MAX := 3
var _active_damage := 0

func take_damage_label(parent: Node) -> Label3D:
	if _active_damage >= ACTIVE_DAMAGE_MAX:
		return null
	_active_damage += 1
	var lbl: Label3D = null
	while _damage_pool.size() > 0 and lbl == null:
		var cand: Label3D = _damage_pool.pop_back()
		if is_instance_valid(cand):
			lbl = cand
	if lbl == null:
		lbl = _make_damage_label()
		damage_created += 1
	else:
		damage_reused += 1
		if lbl.get_parent():
			lbl.get_parent().remove_child(lbl)
	parent.add_child(lbl)
	lbl.visible = true
	return lbl

func _make_damage_label() -> Label3D:
	var lbl := Label3D.new()
	lbl.font_size = 64
	lbl.pixel_size = 0.012
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0, 0, 0)
	return lbl

## 사용이 끝난 Label3D 를 반납한다.
func give_damage_label(lbl: Label3D) -> void:
	_active_damage = maxi(0, _active_damage - 1)
	if not is_instance_valid(lbl):
		return
	lbl.visible = false
	if lbl.get_parent():
		lbl.get_parent().remove_child(lbl)
	if _damage_pool.size() < DAMAGE_POOL_MAX:
		_damage_pool.append(lbl)
	else:
		lbl.queue_free()

## ── 기탄 ──

func take_projectile(parent: Node) -> Area3D:
	var proj: Area3D = null
	while _projectile_pool.size() > 0 and proj == null:
		var cand: Area3D = _projectile_pool.pop_back()
		if is_instance_valid(cand):
			proj = cand
	if proj == null:
		proj = Area3D.new()
		proj.set_script(load("res://scripts3d/Projectile3D.gd"))
		projectile_created += 1
	else:
		projectile_reused += 1
		if proj.get_parent():
			proj.get_parent().remove_child(proj)
	# 마스크는 Projectile3D.setup()/retarget() 이 대상에 맞춰 정한다.
	# 여기서 2(플레이어)로 고정하면 플레이어가 쏜 화살이 적을 통과해 버린다.
	proj.collision_layer = 0
	proj.collision_mask = 2   ## LAYER_PLAYER
	parent.add_child(proj)
	proj.visible = true
	proj.set_physics_process(true)
	return proj

func give_projectile(proj: Area3D) -> void:
	if not is_instance_valid(proj):
		return
	proj.visible = false
	proj.set_physics_process(false)
	if proj.get_parent():
		proj.get_parent().remove_child(proj)
	if _projectile_pool.size() < PROJECTILE_POOL_MAX:
		_projectile_pool.append(proj)
	else:
		proj.queue_free()

## 씬 전환으로 무효가 된 항목 제거
func _prune() -> void:
	_active_damage = 0
	_damage_pool = _damage_pool.filter(func(n): return is_instance_valid(n))
	_projectile_pool = _projectile_pool.filter(func(n): return is_instance_valid(n))
	_fx_pool = _fx_pool.filter(func(n): return is_instance_valid(n))

# ══════════════════════════════════════════════
#  임시 메시 (검격 잔상 · 폭발 구 · 장판 · 화살)
# ══════════════════════════════════════════════
## 전투 연출이 프레임마다 MeshInstance3D 를 새로 만들고 버렸다.
## 여기서 돌려 쓰면 GC 부담과 노드 생성 비용이 사라진다.
const FX_POOL_MAX := 48
var _fx_pool: Array[MeshInstance3D] = []
var fx_created := 0
var fx_reused := 0

func take_fx(parent: Node, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = null
	while _fx_pool.size() > 0 and mi == null:
		var cand: MeshInstance3D = _fx_pool.pop_back()
		if is_instance_valid(cand):
			mi = cand
	if mi == null:
		mi = MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx_created += 1
	else:
		fx_reused += 1
		if mi.get_parent():
			mi.get_parent().remove_child(mi)
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D.IDENTITY
	mi.scale = Vector3.ONE
	mi.visible = true
	parent.add_child(mi)
	return mi

func give_fx(mi: MeshInstance3D) -> void:
	if not is_instance_valid(mi):
		return
	if _fx_pool.size() >= FX_POOL_MAX:
		mi.queue_free()
		return
	mi.visible = false
	if mi.get_parent():
		mi.get_parent().remove_child(mi)
	_fx_pool.append(mi)

## 수명이 끝나면 자동으로 풀에 돌려준다. queue_free 대신 이걸 쓴다.
func give_fx_after(mi: MeshInstance3D, seconds: float) -> void:
	if not is_instance_valid(mi):
		return
	await get_tree().create_timer(seconds, true, false, true).timeout
	give_fx(mi)

## 풀 상태 (성능 보고용)
func stats() -> Dictionary:
	return {
		"damage_pooled": _damage_pool.size(),
		"damage_created": damage_created,
		"damage_reused": damage_reused,
		"proj_pooled": _projectile_pool.size(),
		"fx_pooled": _fx_pool.size(),
		"fx_created": fx_created,
		"fx_reused": fx_reused,
		"proj_created": projectile_created,
		"proj_reused": projectile_reused,
	}

# ══════════════════════════════════════════════
#  외부 3D 모델 (data/models.json)
#  파일을 넣고 경로만 적으면 바뀐다. 없으면 기존 모델을 그대로 쓴다.
# ══════════════════════════════════════════════
const MODELS_PATH := "res://data/models.json"
var _models: Dictionary = {}

func models() -> Dictionary:
	if not _models.is_empty():
		return _models
	var f := FileAccess.open(MODELS_PATH, FileAccess.READ)
	if f == null:
		_models = {"player": {}, "enemies": {}, "props": {}}
		return _models
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	_models = j if typeof(j) == TYPE_DICTIONARY else {"player": {}, "enemies": {}, "props": {}}
	return _models

## 적 타입의 교체 설정 (_default 위에 개별 설정을 얹는다)
func model_conf(kind: String, id: String = "") -> Dictionary:
	var m := models()
	if kind == "player":
		return m.get("player", {})
	var e: Dictionary = m.get("enemies", {})
	var base: Dictionary = e.get("_default", {}).duplicate()
	for k in e.get(id, {}):
		base[k] = e[id][k]
	return base

## 설정에 모델이 지정돼 있고 파일이 실제로 있으면 인스턴스를 만들어 준다.
## 없으면 null — 호출부는 기존 모델을 그대로 쓰면 된다.
func spawn_model(conf: Dictionary) -> Node3D:
	var path := String(conf.get("model", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var packed = ResourceLoader.load(path)
	if packed == null or not (packed is PackedScene):
		push_warning("[Model] PackedScene 이 아니다: %s" % path)
		return null
	var inst = packed.instantiate()
	if inst == null or not (inst is Node3D):
		return null
	var n: Node3D = inst
	var sc := float(conf.get("scale", 1.0))
	n.scale = Vector3(sc, sc, sc)
	n.position.y += float(conf.get("y_offset", 0.0))
	n.rotation_degrees.y += float(conf.get("rot_y", 0.0))
	return n

## 모델 안에서 AnimationPlayer 를 찾는다 (.glb 는 보통 한 단계 아래에 있다)
func find_anim(root: Node) -> AnimationPlayer:
	if root == null:
		return null
	for c in root.get_children():
		if c is AnimationPlayer:
			return c
		var deep := find_anim(c)
		if deep != null:
			return deep
	return null

# ══════════════════════════════════════════════
#  파티클 (GPUParticles3D) — 쓰고 자동으로 사라진다
# ══════════════════════════════════════════════
## 한 번 터지고 수명이 끝나면 스스로 정리된다.
## one_shot 이라 emitting 을 켜면 그걸로 끝 — 매 프레임 비용이 없다.
func burst(parent: Node, pos: Vector3, color: Color,
		count: int = 24, speed: float = 6.0, life: float = 0.6,
		size: float = 0.12, gravity: float = -6.0) -> GPUParticles3D:
	if parent == null or not is_instance_valid(parent):
		return null
	var p := GPUParticles3D.new()
	p.amount = maxi(1, count)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.92
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.25
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 70.0
	mat.initial_velocity_min = speed * 0.5
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, gravity, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.0
	mat.color = color
	p.process_material = mat

	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	p.draw_pass_1 = mesh
	var sm := StandardMaterial3D.new()
	sm.albedo_color = color
	sm.emission_enabled = true
	sm.emission = color
	sm.emission_energy_multiplier = 4.0
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.vertex_color_use_as_albedo = true
	p.material_override = sm

	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	# 수명 + 여유를 두고 스스로 사라진다 (queue_free 를 호출부가 신경 쓰지 않아도 된다)
	_free_after(p, life + 0.4)
	return p

func _free_after(n: Node, seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
	if is_instance_valid(n):
		n.queue_free()
