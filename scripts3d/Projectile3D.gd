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

## ── 확장 (data/weapons.json · data/monsters.json 이 켠다) ──
## 기본값은 전부 기존 동작과 동일하다 — 안 켜면 예전 탄 그대로다.
var hits_player := true      ## false 면 적을 맞힌다 (플레이어의 활)
var pierce := false          ## true 면 맞고도 사라지지 않는다
var homing_turn := 0.0       ## >0 이면 목표 쪽으로 초당 이만큼 방향을 튼다
var homing_target: Node3D = null
var _hit: Dictionary = {}    ## 관통 시 같은 대상 중복 타격 방지

## 물리 레이어 (Player3D.collision_layer = 2, Enemy3D.collision_layer = 4)
## VfxPool.take_projectile 이 마스크를 2(플레이어)로 고정해 두기 때문에,
## 플레이어가 쏜 화살은 적과 아예 겹치지 않아 body_entered 가 불리지 않았다.
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4

## VfxPool 에서 꺼낸 탄을 초기화한다. launch 의 별칭 — 호출부 이름을 통일한다.
func setup(p_dir: Vector3, p_speed: float, p_damage: float, p_life: float,
		p_hits_player: bool = true, p_pierce: bool = false) -> void:
	hits_player = p_hits_player
	pierce = p_pierce
	homing_turn = 0.0
	homing_target = null
	_hit.clear()
	retarget()
	launch(p_dir, p_speed, p_damage, p_life)

## 맞힐 대상에 맞춰 충돌 마스크를 다시 잡는다.
## hits_player 를 나중에 바꾸는 호출부를 위해 따로 뺐다.
func retarget() -> void:
	collision_layer = 0
	collision_mask = LAYER_PLAYER if hits_player else LAYER_ENEMY
	monitoring = true

func launch(p_dir: Vector3, p_speed: float, p_damage: float, p_life: float) -> void:
	# setup 을 거치지 않고 직접 부르는 옛 호출부를 위해 여기서도 마스크를 맞춘다
	retarget()
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
	# 유도 — 목표 방향으로 조금씩 튼다. 각속도가 낮아 크게 돌면 피할 수 있다.
	if homing_turn > 0.0 and is_instance_valid(homing_target):
		var want: Vector3 = homing_target.global_position - global_position
		want.y = 0.0
		if want.length_squared() > 0.001:
			dir = dir.slerp(want.normalized(), clampf(delta * homing_turn, 0.0, 1.0))
	life -= delta
	if life <= 0.0:
		_pop()
		return
	global_position += dir * speed * delta

func _on_body_entered(body: Node3D) -> void:
	# 플레이어가 쏜 화살은 적을 맞힌다
	if not hits_player:
		if body == null or not is_instance_valid(body):
			return
		if not body.is_in_group("enemies") or not body.has_method("take_damage"):
			return
		# 이미 죽은 몹은 사망 연출 동안 트리에 남는다 — 화살이 시체에 박히면 안 된다
		if body.get("dead") == true:
			return
		var id := body.get_instance_id()
		if _hit.has(id):
			return
		_hit[id] = true
		var to: Vector3 = body.global_position - global_position
		to.y = 0.0
		if to.length_squared() < 0.0001:
			to = dir
		body.take_damage(damage, to.normalized() * 3.0)
		SoundManager.play_pitched("hit", -8.0, 1.2)
		if not pierce:
			_pop()
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		# 어디서 날아온 탄인지 카메라에 전달한다 (방향성 킥)
		body.take_damage(damage, global_position)
		_pop()

func _pop() -> void:
	monitoring = false          ## 소멸 연출 중에 다시 맞히지 않는다
	set_physics_process(false)
	if _pop_tween and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop_tween = create_tween()
	if mesh:
		_pop_tween.tween_property(mesh, "scale", Vector3(2.2, 2.2, 2.2), 0.12)
		_pop_tween.parallel().tween_property(mesh, "transparency", 1.0, 0.12)
	# queue_free 대신 풀에 반납한다
	_pop_tween.tween_callback(func(): VfxPool.give_projectile(self))
