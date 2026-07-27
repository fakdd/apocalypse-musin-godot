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
func take_damage_label(parent: Node) -> Label3D:
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
	proj.collision_layer = 0
	proj.collision_mask = 2
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
	_damage_pool = _damage_pool.filter(func(n): return is_instance_valid(n))
	_projectile_pool = _projectile_pool.filter(func(n): return is_instance_valid(n))

## 풀 상태 (성능 보고용)
func stats() -> Dictionary:
	return {
		"damage_pooled": _damage_pool.size(),
		"damage_created": damage_created,
		"damage_reused": damage_reused,
		"proj_pooled": _projectile_pool.size(),
		"proj_created": projectile_created,
		"proj_reused": projectile_reused,
	}
