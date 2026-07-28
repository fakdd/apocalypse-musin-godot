extends Node3D
## 동행 펫 — 플레이어 주변을 떠다니며 아이템을 자동으로 줍는다.
## 종류마다 수집 반경 / 이동 속도 / 부가 효과가 다르다.

const TYPES := {
	"sprite": {
		"name": "균열의 정령", "radius": 5.5, "speed": 9.0, "orbit": 2.0,
		"color": Color(0.55, 0.85, 1.0), "shape": "orb",
		"essence_bonus": 0, "desc": "가장 흔한 동행. 주변의 유물을 주워온다.",
	},
	"scavenger": {
		"name": "고철 수집기", "radius": 9.0, "speed": 8.0, "orbit": 2.4,
		"color": Color(1.0, 0.8, 0.35), "shape": "cube",
		"essence_bonus": 0, "desc": "수집 반경이 넓다. 넓은 폐허 탐색에 유리.",
	},
	"hound": {
		"name": "길들인 사냥개", "radius": 6.5, "speed": 14.0, "orbit": 2.2,
		"color": Color(1.0, 0.45, 0.35), "shape": "spike",
		"essence_bonus": 0, "desc": "매우 빠르게 달려가 물어온다.",
	},
	"warden": {
		"name": "차원의 감시자", "radius": 12.0, "speed": 10.0, "orbit": 2.8,
		"color": Color(0.8, 0.5, 1.0), "shape": "ring",
		"essence_bonus": 1, "desc": "최상급 동행. 반경이 가장 넓고 마석을 덤으로 얻는다.",
	},
}

var pet_type := "sprite"
var cfg := {}
var body: MeshInstance3D
var orbit_phase := 0.0
var target: Node3D = null
var carrying := false
var label: Label3D

func setup(p_type: String) -> void:
	if not TYPES.has(p_type):
		p_type = "sprite"
	pet_type = p_type
	cfg = TYPES[p_type]
	add_to_group("pets")

	var col: Color = cfg["color"]
	body = MeshInstance3D.new()
	match String(cfg["shape"]):
		"cube":
			var bm := BoxMesh.new()
			bm.size = Vector3(0.42, 0.42, 0.42)
			body.mesh = bm
		"spike":
			var pm := PrismMesh.new()
			pm.size = Vector3(0.38, 0.62, 0.38)
			body.mesh = pm
		"ring":
			var tm := TorusMesh.new()
			tm.inner_radius = 0.2
			tm.outer_radius = 0.36
			body.mesh = tm
		_:
			var sm := SphereMesh.new()
			sm.radius = 0.24
			sm.height = 0.48
			sm.radial_segments = 10
			sm.rings = 6
			body.mesh = sm

	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 4.0
	m.metallic = 0.4
	body.material_override = m
	add_child(body)

	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.8
	light.omni_range = 5.0
	add_child(light)

	label = Label3D.new()
	label.text = String(cfg["name"])
	label.font_size = 34
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = col
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0)
	label.position.y = 0.7
	add_child(label)

func _physics_process(delta: float) -> void:
	var player := Battlefield.player
	if player == null or not is_instance_valid(player):
		return

	orbit_phase += delta * 1.6
	_tick_attack(delta)
	var speed: float = float(cfg.get("speed", 9.0))
	var radius: float = float(cfg.get("radius", 5.5))
	var orbit: float = float(cfg.get("orbit", 2.0))

	# 유효한 목표가 없으면 가까운 드랍을 찾는다
	if target == null or not is_instance_valid(target) or target.collected:
		target = _find_nearest_drop(player.global_position, radius)

	var goal: Vector3
	if target != null and is_instance_valid(target):
		goal = target.global_position + Vector3(0, 0.7, 0)
	else:
		# 플레이어 주변을 선회
		goal = player.global_position + Vector3(
			cos(orbit_phase) * orbit, 1.5 + sin(orbit_phase * 1.4) * 0.25, sin(orbit_phase) * orbit)

	global_position = global_position.lerp(goal, clampf(delta * speed * 0.55, 0.0, 1.0))
	body.rotation.y += delta * 2.4

	# 목표에 닿으면 회수
	if target != null and is_instance_valid(target):
		if global_position.distance_to(target.global_position) < 1.1:
			_collect(target)
			target = null

func _find_nearest_drop(from: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for d in Battlefield.item_drops:
		if not is_instance_valid(d) or d.collected:
			continue
		var dist: float = from.distance_to(d.global_position)
		if dist < best_d:
			best_d = dist
			best = d
	return best

func _collect(drop: Node3D) -> void:
	if drop == null or not is_instance_valid(drop) or drop.collected:
		return
	drop.pet_collect()
	var bonus: int = int(cfg.get("essence_bonus", 0))
	if bonus > 0:
		CraftManager.add_essence(bonus)
	_pulse()

func _pulse() -> void:
	var tw := create_tween()
	tw.tween_property(body, "scale", Vector3(1.6, 1.6, 1.6), 0.1)
	tw.tween_property(body, "scale", Vector3.ONE, 0.16)

# ══════════════════════════════════════════════
#  전투 (data/pets.json)
#  기존 VfxPool 투사체를 그대로 빌려 쓴다 — 새 시스템 없음.
# ══════════════════════════════════════════════
var atk_cd := 0.0

func _tick_attack(delta: float) -> void:
	var conf := PetManager.attack_of(pet_type)
	if conf.is_empty():
		return
	atk_cd = maxf(0.0, atk_cd - delta)
	if atk_cd > 0.0:
		return
	# 밤에만 싸운다 — 낮에는 수집만 (기존 역할 유지)
	if GameManager.phase != GameManager.Phase.NIGHT:
		return

	if not is_inside_tree() or get_parent() == null:
		return
	var reach := float(conf.get("range", 12.0))
	var best: Node3D = null
	var best_d := reach
	for e in Battlefield.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return

	atk_cd = float(conf.get("cd", 2.0))
	var dir: Vector3 = best.global_position - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	var proj := VfxPool.take_projectile(get_parent())
	if proj == null:
		return
	proj.global_position = global_position
	# 펫 피해는 플레이어 검기에 비례한다 — 성장하면 펫도 같이 세진다
	proj.setup(dir.normalized(), float(conf.get("speed", 18.0)),
		PlayerStats.get_slash_damage() * float(conf.get("damage", 0.4)),
		2.0, false, false)
	SoundManager.play_pitched("turret_fire", -16.0, 1.4)
