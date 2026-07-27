extends RefCounted
class_name WorldConfig
## 월드 격자/구역 상수. 모든 매니저가 이 값을 공유한다.
## (World3D 에도 같은 이름의 const 가 남아 있어 외부 코드/프로브 호환을 유지한다)

const TILE := 2.0
const COLS := 40
const ROWS := 40
const ARENA_W := COLS * TILE
const ARENA_H := ROWS * TILE

const DAY_SKY_TOP := Color(0.32, 0.09, 0.09)
const DAY_SKY_HORIZON := Color(0.58, 0.30, 0.22)
const NIGHT_SKY_TOP := Color(0.05, 0.01, 0.04)
const NIGHT_SKY_HORIZON := Color(0.30, 0.04, 0.13)
const DAY_FOG := 0.022
const NIGHT_FOG := 0.038

## 3구역: 0 안전지대 · 1 폐허 도시 · 2 차원의 균열
const ZONE_SAFE := 0
const ZONE_CITY := 1
const ZONE_RIFT := 2
const SAFE_RADIUS := 15.0
const RIFT_BAND := 11.0

## 구역별 아이템 드랍 운(luck) 보정
const LUCK_RIFT := 260.0
const LUCK_CITY := 40.0
const LUCK_SAFE := 0.0

## 격자 판정 ──────────────────────────────────────────────
static func is_horizontal_road(z: int) -> bool:
	if z == int(ROWS / 2):
		return true
	return z >= 3 and z <= ROWS - 4 and (z - 3) % 7 == 0

static func is_vertical_road(x: int) -> bool:
	if x == int(COLS / 2):
		return true
	return x >= 3 and x <= COLS - 4 and (x - 3) % 7 == 0

static func is_road(x: int, z: int) -> bool:
	return is_horizontal_road(z) or is_vertical_road(x)

static func in_base_zone(x: int, z: int) -> bool:
	var cx := int(COLS / 2)
	var cz := int(ROWS / 2)
	return absi(x - cx) <= 4 and absi(z - cz) <= 4

## 중앙 대로변인지 (보도블록을 까는 기준)
static func adjacent_to_main_road(x: int, z: int) -> bool:
	var cx := int(COLS / 2)
	var cz := int(ROWS / 2)
	return absi(x - cx) == 1 or absi(z - cz) == 1

## 플레이 영역에는 고층을 세우지 않는다 (시야 차단 방지)
static func is_skyline_cell(_x: int, _z: int) -> bool:
	return false

static func world_center() -> Vector3:
	return Vector3(ARENA_W * 0.5, 0, ARENA_H * 0.5)

static func zone_of(pos: Vector3) -> int:
	if pos.distance_to(world_center()) <= SAFE_RADIUS:
		return ZONE_SAFE
	var edge_dist: float = minf(minf(pos.x, ARENA_W - pos.x), minf(pos.z, ARENA_H - pos.z))
	if edge_dist <= RIFT_BAND:
		return ZONE_RIFT
	return ZONE_CITY

static func zone_luck(pos: Vector3) -> float:
	match zone_of(pos):
		ZONE_RIFT:
			return LUCK_RIFT
		ZONE_CITY:
			return LUCK_CITY
		_:
			return LUCK_SAFE
