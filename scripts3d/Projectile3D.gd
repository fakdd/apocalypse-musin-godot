extends Area3D
## 몬스터가 쏘는 기탄. 플레이어에 닿으면 피해를 주고 사라진다.
##
## 오브젝트 풀 대응:
##   이전에는 launch() 가 매번 CollisionShape3D/MeshInstance3D/OmniLight3D 를 새로 만들고
##   끝나면 queue_free 했다. 보스 탄막(한 번에 5~7발)에서 초당 수십 개의 노드가 생겼다.
##   이제 자식 노드는 **최초 1회만** 만들고(_build_parts), 재사용 시 상태만 초기화한다.

var dir := Vector3.ZERO
var speed := 12.0
var damage := 6.0
var life := 4.0
var mesh: MeshInstance3D
var _built := false
var _pop_tween: Tween

func launch(p_dir: Vector3, p_speed: float, p_damage: float, p_life: float) -> void:
	dir = p_dir.normalized()
	speed = p_speed
	damage = p_damage
	life = p_life
	if not is_in_group("projectiles"):
		add_to_group("projectiles")

	if not _built:
		_build_parts()
		_built = true

	# 재사용 시 이전 소멸 연출의 잔여 상태를 되돌린다
	if _pop_tween and _pop_tween.is_valid():
		_pop_tween.kill()
	if mesh:
		mesh.scale = Vector3.ONE
		mesh.transparency = 0.0
	set_physics_process(true)

func _build_parts() -> void:
	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.42
	shape.shape = sph
	add_child(shape)

	mesh = MeshInstance3D.new()
	var m3 := SphereMesh.new()
	m3.radius = 0.3
	m3.height = 0.6
	m3.radial_segments = 8
	m3.rings = 4
	mesh.mesh = m3
	# 모든 기탄이 같은 재질을 공유한다 (개별 알파 애니메이션은 transparency 속성으로 처리)
	mesh.material_override = SharedMaterials.projectile()
	add_child(mesh)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.3, 0.2)
	light.light_energy = 2.0
	light.omni_range = 4.0
	add_child(light)

	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_pop()
		return
	global_position += dir * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		# 어디서 날아온 탄인지 카메라에 전달한다 (방향성 킥)
		body.take_damage(damage, global_position)
		_pop()

func _pop() -> void:
	set_physics_process(false)
	if _pop_tween and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop_tween = create_tween()
	if mesh:
		_pop_tween.tween_property(mesh, "scale", Vector3(2.2, 2.2, 2.2), 0.12)
		_pop_tween.parallel().tween_property(mesh, "transparency", 1.0, 0.12)
	# queue_free 대신 풀에 반납한다
	_pop_tween.tween_callback(func(): VfxPool.give_projectile(self))
