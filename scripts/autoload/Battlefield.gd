extends Node
## 전장 상태 캐시 + 협공 슬롯 배분소.
##
## 목적 1 — Group Search 제거:
##   기존에는 적 1기가 매 물리 프레임 `get_first_node_in_group()` 을 3회(플레이어/방주/방벽) 호출했다.
##   적 50기면 프레임당 150회 트리 검색. 여기서 프레임당 1회만 갱신해 모두가 공유한다.
##
## 목적 2 — 협공(flanking) 조율:
##   적들이 플레이어 정면에 뭉치지 않도록, 플레이어 주위를 N등분한 슬롯을 적에게 배분한다.
##   슬롯을 가진 적은 그 방향에서 접근하므로 자연스럽게 포위 형태가 된다.

signal enemies_changed(count: int)

## ── 캐시 (프레임당 1회 갱신) ──
var player: Node3D = null
var base_core: Node3D = null
var enemies: Array = []
var defenses: Array = []
## 미니맵·퀘스트HUD·펫이 각자 매 프레임 그룹 검색을 하고 있었다 (프레임당 3회 배열 할당).
## 여기 한 번만 담아 공유한다.
var item_drops: Array = []

var _frame := -1
var _enemy_count_last := -1

## ── 협공 슬롯 ──
const SLOT_COUNT := 8               ## 플레이어 주위를 8방향으로 나눈다
const SLOT_CLAIM_RANGE := 22.0      ## 이 거리 안의 적만 슬롯을 받는다
var _slots := {}                    ## slot_index(int) -> enemy(Node)
var _slot_of := {}                  ## enemy 인스턴스 id -> slot_index

func _ready() -> void:
	# 물리 프레임보다 먼저 돌아 캐시가 항상 최신이 되게 한다
	process_priority = -100
	process_physics_priority = -100

func _physics_process(_delta: float) -> void:
	refresh()

## 캐시를 갱신한다. 같은 프레임에 여러 번 불려도 1회만 수행한다.
func refresh() -> void:
	var f := Engine.get_physics_frames()
	if f == _frame:
		return
	_frame = f

	var tree := get_tree()
	if tree == null:
		return

	# 플레이어/방주는 유효성이 깨졌을 때만 다시 찾는다 (대부분 프레임은 검색 0회)
	if player == null or not is_instance_valid(player):
		player = tree.get_first_node_in_group("player") as Node3D
	if base_core == null or not is_instance_valid(base_core):
		base_core = tree.get_first_node_in_group("base_core") as Node3D

	enemies = tree.get_nodes_in_group("enemies")
	defenses = tree.get_nodes_in_group("defenses")
	item_drops = tree.get_nodes_in_group("item_drops")

	if enemies.size() != _enemy_count_last:
		_enemy_count_last = enemies.size()
		enemies_changed.emit(_enemy_count_last)

	_prune_slots()

## 플레이어가 살아 있으면 반환, 아니면 null
func live_player() -> Node3D:
	refresh()
	if player and is_instance_valid(player) and player.hp > 0:
		return player
	return null

func live_base() -> Node3D:
	refresh()
	if base_core and is_instance_valid(base_core):
		return base_core
	return null

## 아직 싸울 수 있는 적의 수.
## enemies.size() 는 시체까지 센다 — 죽은 몹이 사망 연출 동안 트리에 남기 때문이다.
## 화면에 "적 N" 으로 보여줄 때는 이 값을 써야 실제와 맞는다.
func live_enemy_count() -> int:
	refresh()
	var n := 0
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			n += 1
	return n

## 가장 가까운 방벽/포탑 (없으면 null)
func nearest_defense(from: Vector3) -> Node3D:
	refresh()
	var best: Node3D = null
	var best_d := INF
	for d in defenses:
		if not is_instance_valid(d):
			continue
		var dist: float = from.distance_to(d.global_position)
		if dist < best_d:
			best_d = dist
			best = d
	return best

## ── 협공 슬롯 ──

## 적에게 플레이어 주위 접근 슬롯을 배분한다.
## 반환: 슬롯의 방향 각도(라디안). 슬롯을 못 받으면 NAN.
func claim_slot(enemy: Node3D) -> float:
	var p := live_player()
	if p == null or not is_instance_valid(enemy):
		return NAN
	var id := enemy.get_instance_id()

	# 이미 가진 슬롯이 있으면 유지 (매 프레임 흔들리면 움직임이 떨린다)
	if _slot_of.has(id):
		return _slot_angle(_slot_of[id])

	if enemy.global_position.distance_to(p.global_position) > SLOT_CLAIM_RANGE:
		return NAN

	# 자기 현재 방향에 가장 가까운 빈 슬롯부터 시도 — 불필요한 우회를 줄인다
	var to_me: Vector3 = enemy.global_position - p.global_position
	var my_angle := atan2(to_me.x, to_me.z)
	var start := int(round(my_angle / TAU * SLOT_COUNT)) % SLOT_COUNT
	for step in range(SLOT_COUNT):
		# 0, +1, -1, +2, -2 … 순서로 탐색
		var off: int = int(ceil(step * 0.5)) * (1 if step % 2 == 1 else -1)
		var idx: int = posmod(start + off, SLOT_COUNT)
		if not _slots.has(idx):
			_slots[idx] = enemy
			_slot_of[id] = idx
			return _slot_angle(idx)
	return NAN

func release_slot(enemy: Node3D) -> void:
	if not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	if _slot_of.has(id):
		_slots.erase(_slot_of[id])
		_slot_of.erase(id)

func _slot_angle(idx: int) -> float:
	return TAU * float(idx) / float(SLOT_COUNT)

## 죽거나 멀어진 적의 슬롯을 회수한다
func _prune_slots() -> void:
	var p: Node3D = player
	var drop := []
	for id in _slot_of.keys():
		var e = instance_from_id(id)
		if e == null or not is_instance_valid(e):
			drop.append(id)
			continue
		if p and is_instance_valid(p):
			if e.global_position.distance_to(p.global_position) > SLOT_CLAIM_RANGE * 1.4:
				drop.append(id)
	for id in drop:
		if _slot_of.has(id):
			_slots.erase(_slot_of[id])
			_slot_of.erase(id)

## 씬 재시작 시 호출
func reset() -> void:
	player = null
	base_core = null
	enemies.clear()
	defenses.clear()
	_slots.clear()
	_slot_of.clear()
	_frame = -1
	_enemy_count_last = -1

## 플레이어가 큰 기술을 쓰기 직전에 부른다.
## 반경 안의 적이 각자 확률에 따라 옆으로 빠진다 (data/ai.json 의 dodge_chance).
func telegraph(from: Vector3, radius: float = 12.0) -> void:
	refresh()
	for e in enemies:
		if not is_instance_valid(e) or e.dead or e.brain == null:
			continue
		if e.global_position.distance_to(from) > radius:
			continue
		e.brain.try_dodge(from)
