extends Node3D
class_name PuzzleSet
## 랜드마크 안의 퍼즐 한 벌.
##
## 정의는 **캠페인 JSON** 에서 온다 (stage.puzzle). 이 파일에는 퍼즐 id 도,
## 챕터 이름도 하드코딩돼 있지 않다. 챕터 8~20 을 추가해도 JSON 만 늘리면 된다.
##
##   {"id": "forest_altar", "kind": "plate", "count": 4,
##    "order": [2,0,3,1], "reward": "chest", "rarity": "A",
##    "achievement": "ach_forest_puzzle", "hint": "돌이 넷, 순서가 있다"}
##
## 조작 방식이 밟기(touch)뿐인 이유:
##   E 키는 이미 아이템 획득·NPC 대화·기공파가 나눠 쓰고 있다. 여기에 또 얹으면
##   퍼즐을 풀려다 스킬이 나간다. 밟기는 키를 쓰지 않아 충돌이 없고,
##   "돌 위에 올라선다"는 동작이 퍼즐로 바로 읽힌다.
##
## 저장:
##   푼 퍼즐은 SaveGame.solve_puzzle(id) 로 남는다. 다시 들어와도 풀린 상태다.

## 요소 하나의 감지 반경
const TOUCH_R := 1.6
## 잘못된 순서로 밟았을 때 리셋 대기 (바로 꺼지면 실수인지 모른다)
const FAIL_RESET := 0.6

var puzzle := {}
var area_id := ""

var _elements: Array[Area3D] = []
var _lit: Array[bool] = []
var _seq: Array[int] = []          ## sigil — 밟은 순서
var _solved := false
var _fail_timer := 0.0

func setup(p: Dictionary, p_area_id: String, radius: float) -> void:
	puzzle = p
	area_id = p_area_id
	var pid := _id()
	if pid == "":
		return

	# 이미 푼 퍼즐이면 보상만 열린 채로 둔다
	_solved = SaveGame.is_puzzle_solved(pid)

	var count: int = maxi(2, int(puzzle.get("count", 4)))
	var kind := _kind()
	var ring: float = radius * 0.66

	for i in range(count):
		var a: float = TAU * float(i) / float(count) - PI * 0.5
		var pos := Vector3(cos(a) * ring, 0.0, sin(a) * ring)
		_elements.append(_make_element(i, pos, kind))
		_lit.append(_solved)

	if _solved:
		for e in _elements:
			_set_lit(e, true)
	else:
		set_process(true)
		_hint()

func _id() -> String:
	return String(puzzle.get("id", ""))

func _kind() -> String:
	return String(puzzle.get("kind", "plate"))

func _order() -> Array:
	return puzzle.get("order", [])

## ══════════════════════════════════════════════
##  요소 만들기 — 종류마다 생김새가 다르다
## ══════════════════════════════════════════════
func _make_element(index: int, pos: Vector3, kind: String) -> Area3D:
	var area := Area3D.new()
	area.name = "P%d" % index
	area.monitoring = true
	area.monitorable = false
	area.collision_layer = 0
	area.collision_mask = 2                 ## 플레이어만
	area.position = pos
	add_child(area)

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = TOUCH_R
	cyl.height = 4.0
	shape.shape = cyl
	shape.position.y = 2.0
	area.add_child(shape)

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _mesh_for(kind)
	mi.material_override = _mat(false)
	mi.position.y = _mesh_y(kind)
	area.add_child(mi)

	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = Color(1.0, 0.85, 0.45)
	light.light_energy = 0.0
	light.omni_range = 6.0
	light.position.y = _mesh_y(kind) + 0.6
	area.add_child(light)

	# 순서 퍼즐은 번호를 보여 준다 — 안 그러면 순서를 알 방법이 없다
	if kind == "sigil":
		var lbl := Label3D.new()
		lbl.text = str(index + 1)
		lbl.font_size = 40
		lbl.pixel_size = 0.012
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.modulate = Color(1.0, 0.92, 0.7)
		lbl.outline_size = 10
		lbl.outline_modulate = Color(0, 0, 0, 0.9)
		lbl.position.y = _mesh_y(kind) + 1.4
		area.add_child(lbl)

	area.body_entered.connect(_on_touch.bind(index))
	return area

func _mesh_for(kind: String) -> Mesh:
	match kind:
		"torch":
			var c := CylinderMesh.new()
			c.top_radius = 0.22
			c.bottom_radius = 0.3
			c.height = 2.2
			c.radial_segments = 6
			return c
		"crystal":
			var c2 := CylinderMesh.new()
			c2.top_radius = 0.02
			c2.bottom_radius = 0.55
			c2.height = 2.0
			c2.radial_segments = 5
			return c2
		"lever":
			var b := BoxMesh.new()
			b.size = Vector3(0.35, 1.6, 0.35)
			return b
		"sigil":
			var c3 := CylinderMesh.new()
			c3.top_radius = 1.2
			c3.bottom_radius = 1.2
			c3.height = 0.18
			c3.radial_segments = 8
			return c3
		_:   ## plate
			var b2 := BoxMesh.new()
			b2.size = Vector3(2.0, 0.22, 2.0)
			return b2

func _mesh_y(kind: String) -> float:
	match kind:
		"torch": return 1.1
		"crystal": return 1.0
		"lever": return 0.8
		_: return 0.12

func _mat(lit: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if lit:
		m.albedo_color = Color(1.0, 0.86, 0.45)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.78, 0.32)
		m.emission_energy_multiplier = 4.0
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		m.albedo_color = Color(0.30, 0.28, 0.26)
		m.roughness = 0.9
	return m

func _set_lit(area: Area3D, lit: bool) -> void:
	var mi := area.get_node_or_null("Mesh") as MeshInstance3D
	if mi:
		mi.material_override = _mat(lit)
	var gl := area.get_node_or_null("Glow") as OmniLight3D
	if gl:
		gl.light_energy = 2.4 if lit else 0.0

## ══════════════════════════════════════════════
##  풀이
## ══════════════════════════════════════════════
func _on_touch(body: Node3D, index: int) -> void:
	if _solved or _fail_timer > 0.0 or not body.is_in_group("player"):
		return
	if index < 0 or index >= _lit.size():
		return

	var order := _order()
	if order.is_empty():
		# 순서 없음 — 전부 켜면 된다. 이미 켠 것은 다시 눌러도 그대로.
		if _lit[index]:
			return
		_lit[index] = true
		_set_lit(_elements[index], true)
		SoundManager.play_pitched("build", -8.0, 1.0 + 0.06 * float(index), 0.02)
		if not _lit.has(false):
			_solve()
		return

	# 순서 퍼즐 — 정해진 차례대로 밟아야 한다
	var step: int = _seq.size()
	if step >= order.size():
		return
	if int(order[step]) != index:
		_fail()
		return
	_seq.append(index)
	_lit[index] = true
	_set_lit(_elements[index], true)
	SoundManager.play_pitched("build", -6.0, 1.0 + 0.10 * float(step), 0.02)
	if _seq.size() >= order.size():
		_solve()

func _fail() -> void:
	_fail_timer = FAIL_RESET
	_seq.clear()
	for i in range(_lit.size()):
		_lit[i] = false
		_set_lit(_elements[i], false)
	SoundManager.play_pitched("error", -6.0, 0.85, 0.02)
	_toast("순서가 틀렸다", Color(1.0, 0.6, 0.5))

func _process(delta: float) -> void:
	if _fail_timer > 0.0:
		_fail_timer -= delta

func _solve() -> void:
	if _solved:
		return
	_solved = true
	set_process(false)
	for e in _elements:
		_set_lit(e, true)

	SaveGame.solve_puzzle(_id())
	# 업적은 AchievementManager 를 거친다 — 토스트·카운터가 함께 처리된다
	AchievementManager.bump("puzzle")
	var ach := String(puzzle.get("achievement", ""))
	if ach != "":
		AchievementManager.unlock(ach)

	CombatFeel.screen_flash(Color(1.0, 0.9, 0.55), 0.22, 0.0, 0.3)
	SoundManager.play("ultimate", -8.0)
	_banner("◈ 수수께끼가 풀렸다")
	_give_reward()

## 보상 — chest(희귀 상자) / altar(업그레이드 제단) / passage(숨겨진 길)
## altar 는 4순위에서 실제 제단으로 바뀐다. 지금은 상자로 대신 준다.
func _give_reward() -> void:
	var kind := String(puzzle.get("reward", "chest"))
	var rarity := String(puzzle.get("rarity", "B"))
	var idx := _rarity_index(rarity)
	var at := global_position + Vector3(0, 0, 1.5)

	match kind:
		"passage":
			# 숨겨진 길 — 마석과 확정 드랍을 크게 준다
			CraftManager.add_essence(120)
			LootManager.spawn_drop(at, 1.0, idx)
			LootManager.spawn_drop(at + Vector3(1.6, 0, 0), 1.0, maxi(0, idx - 1))
			_toast("숨겨진 길이 열렸다 — 마석 +120", Color(0.7, 0.95, 1.0))
		"altar":
			CraftManager.add_essence(80)
			LootManager.spawn_drop(at, 1.0, idx)
			_toast("제단이 반응한다 — 마석 +80", Color(1.0, 0.9, 0.6))
		_:
			LootManager.spawn_drop(at, 1.0, idx)
			LootManager.spawn_drop(at + Vector3(-1.4, 0, 0.4), 1.0, -1, 80.0)
			_toast("희귀 상자가 열렸다", Color(1.0, 0.88, 0.5))

func _rarity_index(name: String) -> int:
	if name == "":
		return -1
	var order := ["F", "E", "D", "C", "B", "A", "S", "SS", "SSS"]
	return order.find(name.to_upper())

## ══════════════════════════════════════════════
##  안내
## ══════════════════════════════════════════════
func _hint() -> void:
	var h := String(puzzle.get("hint", ""))
	if h == "":
		h = "무언가를 밟아야 할 것 같다" if _order().is_empty() \
			else "순서가 있는 것 같다"
	# 진입했을 때만 알리도록 랜드마크 진입 신호에 건다
	var cb: Callable = func(d: LandmarkData) -> void:
		if d.id == area_id and not _solved:
			_toast(h, Color(0.85, 0.9, 1.0))
	LandmarkRegistry.landmark_entered.connect(cb)

func _toast(text: String, col: Color) -> void:
	var world = get_tree().current_scene
	if world and world.hud:
		world.hud.show_toast(text, col)

func _banner(text: String) -> void:
	var world = get_tree().current_scene
	if world and world.hud:
		world.hud.show_banner(text)
