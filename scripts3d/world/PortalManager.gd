extends WorldSystem
class_name PortalManager
## 차원의 균열(포털) 생성과 봉인을 담당한다.

## 균열을 무작위 위치에 생성한다.
func build_rifts() -> void:
	_build_rifts()

## 균열 하나를 봉인한다 (밤을 버텨낼 때마다 호출)
func seal_one() -> bool:
	var rifts := get_tree().get_nodes_in_group("rifts")
	if rifts.is_empty():
		return false
	var r = rifts[randi() % rifts.size()]
	if is_instance_valid(r):
		r.seal()
		return true
	return false

## 낮/밤에 따라 균열 활성 상태를 바꾼다
func set_all_active(active: bool) -> void:
	for rift in get_tree().get_nodes_in_group("rifts"):
		if is_instance_valid(rift):
			rift.set_active(active)

## 차원의 균열 — 개수와 위치가 매번 무작위로 결정된다.
func _build_rifts() -> void:
	var center := world_center()
	var count := 4 + randi() % 4          # 4~7개
	var placed := 0
	var attempts := 0
	var made: Array[Vector3] = []

	while placed < count and attempts < 400:
		attempts += 1
		var pos := Vector3(
			randf_range(4.0, ARENA_W - 4.0), 0,
			randf_range(4.0, ARENA_H - 4.0)
		)
		# 균열 구역(맵 외곽 밴드) 안에만 생성한다
		if zone_of(pos) != ZONE_RIFT:
			continue
		var too_close := false
		for other in made:
			if pos.distance_to(other) < 16.0:
				too_close = true
				break
		if too_close:
			continue
		var rift = load("res://scripts3d/Rift3D.gd").new()
		rift.position = pos
		world.add_child(rift)
		made.append(pos)
		placed += 1
