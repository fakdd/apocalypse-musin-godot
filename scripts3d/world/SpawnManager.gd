extends WorldSystem
class_name SpawnManager
## 플레이어/적/보스 스폰을 담당한다.

const ENEMY_SCRIPT := preload("res://scripts3d/Enemy3D.gd")
const PLAYER_SCRIPT := preload("res://scripts3d/Player3D.gd")

## 플레이어를 방주 앞에 스폰한다.
func spawn_player() -> void:
	_spawn_player()

## 균열에서 적 1마리를 스폰한다
func spawn_enemy() -> void:
	_spawn_enemy()

## 지정 종류의 적을 지정 위치에 생성한다
func make_enemy(etype: String, pos: Vector3) -> Node:
	return _make_enemy(etype, pos)

func spawn_boss() -> void:
	_spawn_boss()

func spawn_final_boss() -> void:
	_spawn_final_boss()

func _spawn_player() -> void:
	var p := CharacterBody3D.new()
	p.set_script(PLAYER_SCRIPT)
	p.position = world_center() + Vector3(0, 0, 6.0)
	world.add_child(p)
	world.player = p
	world.player.died.connect(func(): GameManager.game_over.emit("world.player"))

func _spawn_enemy() -> void:
	var rifts := get_tree().get_nodes_in_group("rifts")
	var pos := Vector3.ZERO
	if rifts.size() > 0:
		var rift = rifts[randi() % rifts.size()]
		pos = rift.global_position + Vector3(randf_range(-1.6, 1.6), 0, randf_range(-1.6, 1.6))
		if zone_of(pos) == ZONE_SAFE:
			return    # 안전지대에는 절대 스폰하지 않는다
		rift.spawn_burst()
	else:
		var m := 3.0
		pos = Vector3(randf_range(m, ARENA_W - m), 0, m)

	_make_enemy(_roll_enemy_type(pos), pos)

## 스폰 지점이 랜드마크 안이면 그 랜드마크의 스폰 테이블을 우선 적용한다.
## 그래서 지하철역 근처에서는 사냥개가, 제철소 근처에서는 파괴자가 더 나온다.
func _roll_enemy_type(pos: Vector3 = Vector3.ZERO) -> String:
	var lm := LandmarkRegistry.at_position(pos)
	if lm != null and not lm.spawn_table.is_empty():
		var t := lm.roll_spawn_type()
		if t != "":
			return t
	return _roll_global_type()

func _roll_global_type() -> String:
	# 이 챕터의 몬스터가 먼저다 — 숲에 폐허 도시의 사냥개가 나오면 안 된다.
	# 정의되지 않은 종류는 걸러내고, 하나도 없으면 예전 풀로 물러난다.
	var themed: Array = []
	for m in ChapterConfig.monsters_of(GameManager.chapter):
		if EnemyConfig.TYPES.has(String(m)):
			themed.append(String(m))
	if not themed.is_empty():
		# 웨이브가 올라갈수록 뒤쪽(강한) 종류가 더 자주 나온다
		var w: int = GameManager.wave
		var pool: Array = themed.duplicate()
		for i in range(themed.size()):
			if w >= 2 + i * 2:
				pool.append(themed[mini(i + 1, themed.size() - 1)])
		return String(pool[randi() % pool.size()])

	var w2 := GameManager.wave
	var pool2 := ["hound", "hound"]
	if w2 >= 2:
		pool2.append("stalker")
	if w2 >= 3:
		pool2.append_array(["ravager", "destroyer"])
	if w2 >= 4:
		pool2.append_array(["juggernaut", "screecher"])
	if w2 >= 6:
		pool2.append_array(["destroyer", "juggernaut"])
	return pool2[randi() % pool2.size()]

func _make_enemy(etype: String, pos: Vector3) -> Node:
	var e := CharacterBody3D.new()
	e.set_script(ENEMY_SCRIPT)
	world.add_child(e)
	e.position = pos
	e.setup(etype, GameManager.wave)
	return e

func _spawn_boss() -> void:
	# 보스는 균열 구역(외곽)에서 등장한다
	var pos := world_center() + Vector3(0, 0, -ARENA_H * 0.38)
	var rifts := get_tree().get_nodes_in_group("rifts")
	if rifts.size() > 0:
		pos = rifts[randi() % rifts.size()].global_position
	# 이 챕터의 보스를 부른다 (없으면 예전 overlord)
	var btype: String = ChapterConfig.boss_of(GameManager.chapter)
	if not EnemyConfig.TYPES.has(btype):
		btype = "overlord"
	_make_enemy(btype, pos)
	world.hud.show_banner("⚠ %s 강림" % ChapterConfig.name_of(GameManager.chapter))
	SoundManager.play("ultimate")

## 최후의 외계 군주
func _spawn_final_boss() -> void:
	var pos := world_center() + Vector3(0, 0, -26.0)
	var b = _make_enemy("warlord", pos)
	if b:
		b.tree_exited.connect(_on_final_boss_gone)

func _on_final_boss_gone() -> void:
	if GameManager.game_won:
		return
	# 최종 보스가 사라졌다 = 격파
	GameManager.game_won = true
	GameManager.victory.emit()
	world.hud.show_victory()
