extends Control
## 원형 레이더 미니맵 — 플레이어를 중심으로 회전하며 시야 부채꼴을 표시한다.

const SIZE := 200.0
const RADIUS := 100.0
const RANGE := 34.0          ## 레이더가 보여주는 실제 반경 (미터)

var arena_w := 80.0
var arena_h := 80.0

func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

## 월드 좌표 -> 레이더 좌표 (플레이어 기준 상대 + 시야 방향으로 회전)
func _to_radar(world_pos: Vector3, player_pos: Vector3, yaw: float) -> Vector2:
	var rel := world_pos - player_pos
	var rx := rel.x * cos(-yaw) - rel.z * sin(-yaw)
	var rz := rel.x * sin(-yaw) + rel.z * cos(-yaw)
	var scale_f := RADIUS / RANGE
	return Vector2(RADIUS + rx * scale_f, RADIUS + rz * scale_f)

func _dot(world_pos: Vector3, player_pos: Vector3, yaw: float, r: float, col: Color) -> void:
	var v := _to_radar(world_pos, player_pos, yaw)
	if v.distance_to(Vector2(RADIUS, RADIUS)) > RADIUS - r - 2.0:
		return
	draw_circle(v, r, col)

func _draw() -> void:
	var c := Vector2(RADIUS, RADIUS)
	draw_circle(c, RADIUS, Color(0.04, 0.03, 0.04, 0.82))

	var player := Battlefield.player
	if player == null or not is_instance_valid(player):
		return
	var ppos: Vector3 = player.global_position
	var yaw: float = player.facing_angle

	# 시야 부채꼴
	var half := 0.55
	var cone := PackedVector2Array([c])
	var steps := 10
	for i in range(steps + 1):
		var a := -half + (half * 2.0) * (float(i) / steps) - PI * 0.5
		cone.append(c + Vector2(cos(a), sin(a)) * RADIUS)
	draw_colored_polygon(cone, Color(0.55, 0.75, 1.0, 0.10))

	# 거리 링 / 기준선
	for f in [0.33, 0.66]:
		draw_arc(c, RADIUS * f, 0.0, TAU, 32, Color(1, 1, 1, 0.06), 1.0)
	draw_line(c - Vector2(RADIUS * 0.9, 0), c + Vector2(RADIUS * 0.9, 0), Color(1, 1, 1, 0.05), 1.0)
	draw_line(c - Vector2(0, RADIUS * 0.9), c + Vector2(0, RADIUS * 0.9), Color(1, 1, 1, 0.05), 1.0)

	# 맵 경계
	var corners = [
		Vector3(0, 0, 0), Vector3(arena_w, 0, 0),
		Vector3(arena_w, 0, arena_h), Vector3(0, 0, arena_h),
	]
	for i in range(4):
		var a := _to_radar(corners[i], ppos, yaw)
		var b := _to_radar(corners[(i + 1) % 4], ppos, yaw)
		if a.distance_to(c) < RADIUS * 2.0 and b.distance_to(c) < RADIUS * 2.0:
			draw_line(a, b, Color(0.7, 0.25, 0.25, 0.30), 1.5)

	# ── 랜드마크 ──
	# 미탐험은 속이 빈 링(가서 볼 것), 탐험 완료는 채운 점, 클리어는 테두리 강조.
	# 이 시각 구분이 "아직 안 가본 곳"을 한눈에 알려준다.
	for lm in LandmarkRegistry.landmarks:
		if not lm.explored and not lm.show_when_unexplored:
			continue
		var v := _to_radar(lm.center, ppos, yaw)
		if v.distance_to(c) > RADIUS - 8.0:
			continue
		var lcol: Color = lm.minimap_color
		if lm.explored:
			draw_circle(v, lm.minimap_size, lcol)
			if lm.cleared:
				draw_arc(v, lm.minimap_size + 3.0, 0.0, TAU, 14, Color(1, 1, 1, 0.75), 1.5)
		else:
			draw_arc(v, lm.minimap_size, 0.0, TAU, 14, Color(lcol.r, lcol.g, lcol.b, 0.9), 2.0)

	# 방주 / 제단
	var base := Battlefield.base_core
	if base and is_instance_valid(base):
		_dot(base.global_position, ppos, yaw, 5.0, Color(0.45, 0.75, 1.0))
	for al in get_tree().get_nodes_in_group("altars"):
		if is_instance_valid(al):
			_dot(al.global_position, ppos, yaw, 4.0, Color(0.6, 0.9, 1.0))

	# 랜드마크 — 영역 유형별 색 (data/area_kinds.json)
	# 미탐험은 크게·진하게, 탐험한 곳은 작고 흐리게. 클리어한 곳은 그리지 않는다.
	for d in LandmarkRegistry.landmarks:
		if d == null or d.cleared:
			continue
		var kd := LandmarkZone.kind_def(String(d.area_kind))
		var col := Color(0.95, 0.45, 0.40)
		var ca = kd.get("color", null)
		if typeof(ca) == TYPE_ARRAY and ca.size() >= 3:
			col = Color(float(ca[0]), float(ca[1]), float(ca[2]))
		if d.explored:
			col.a = 0.45
			_dot(d.center, ppos, yaw, 3.5, col)
		else:
			_dot(d.center, ppos, yaw, 5.5, col)

	# 다음 장으로 나가는 포탈 — 가장 크고 흰빛
	for pt in get_tree().get_nodes_in_group("chapter_portals"):
		if is_instance_valid(pt):
			_dot(pt.global_position, ppos, yaw, 7.0, Color(1.0, 1.0, 1.0))
			_dot(pt.global_position, ppos, yaw, 3.0, Color(0.6, 0.9, 1.0))

	# 균열 (활성 / 봉인됨)
	for rf in get_tree().get_nodes_in_group("rifts"):
		if is_instance_valid(rf):
			_dot(rf.global_position, ppos, yaw, 4.5, Color(1.0, 0.15, 0.32))
	for rf in get_tree().get_nodes_in_group("sealed_rifts"):
		if is_instance_valid(rf):
			_dot(rf.global_position, ppos, yaw, 4.0, Color(0.35, 0.6, 0.9, 0.7))

	# 아이템 / 생존자 / 펫
	for it in Battlefield.item_drops:
		if is_instance_valid(it) and it.item:
			_dot(it.global_position, ppos, yaw, 3.0, it.item.get_color())
	for sv in get_tree().get_nodes_in_group("survivor_nodes"):
		if is_instance_valid(sv) and not sv.rescued:
			_dot(sv.global_position, ppos, yaw, 3.5, Color(0.5, 1.0, 0.6))
	for pet in get_tree().get_nodes_in_group("pets"):
		if is_instance_valid(pet):
			_dot(pet.global_position, ppos, yaw, 2.5, Color(1.0, 0.9, 0.5))

	# 적 (보스는 크게)
	# 시체는 그리지 않는다 — 사망 연출 동안 캐시에 남아 있어, 다 정리한 구역이
	# 아직 붉은 점으로 보이면 "여기 클리어됐나?" 판단이 흐려진다.
	for e in Battlefield.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		if e.is_in_group("boss"):
			_dot(e.global_position, ppos, yaw, 6.0, Color(1.0, 0.2, 0.15))
		else:
			_dot(e.global_position, ppos, yaw, 3.0, Color(1.0, 0.38, 0.3))

	# 플레이어 (중앙 화살표)
	var arrow := PackedVector2Array([
		c + Vector2(0, -8), c + Vector2(5.5, 6), c + Vector2(0, 3), c + Vector2(-5.5, 6),
	])
	draw_colored_polygon(arrow, Color(1, 1, 1))
