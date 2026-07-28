extends Resource
class_name LandmarkData
## 랜드마크 1개의 정의. 건물마다 이 데이터가 하나씩 붙는다.
##
## Resource 로 만든 이유:
##   나중에 .tres 파일로 저장해 인스펙터에서 편집하거나, 새 랜드마크를 코드 수정 없이
##   추가할 수 있게 하기 위해서다.
##   지금은 CampaignManager 가 캠페인 JSON 을 읽어 만들어 넣는다.

## ── 식별 / 표시 ──
@export var id := ""                       ## 고유 키 (세이브에 쓰인다 — 절대 바꾸지 말 것)
@export var display_name := "무명 건물"
@export var description := ""
@export var subtitle := ""                 ## 진입 배너 아래 한 줄 (분위기용)

## ── 공간 ──
@export var center := Vector3.ZERO          ## 월드 좌표 (LandmarkManager 가 배치 시 채운다)
@export var radius := 9.0                   ## 진입 판정 반경

## ── 미니맵 ──
@export var minimap_color := Color(0.85, 0.75, 0.45)
@export var minimap_size := 5.0
@export var show_when_unexplored := true    ## 미탐험 상태에서도 아이콘을 보여줄지

## ── 진입 이벤트 ──
@export var bgm := ""                       ## SoundManager.set_bgm() 에 넘길 트랙 id ("" = 변경 없음)
@export var enter_stinger := ""             ## 진입 순간의 짧은 효과음 이름

## ── 몬스터 스폰 테이블 ──
## { "hound": 3, "ravager": 1 } 처럼 가중치를 넣는다. 비어 있으면 전역 기본 테이블을 쓴다.
@export var spawn_table := {}
@export var spawn_budget := 0               ## 최초 진입 시 소환할 마리 수 (0 = 소환 없음)
## 영역 유형 (data/area_kinds.json). CampaignManager 가 Stage 에서 넣어 준다.
@export var area_kind := "combat"
@export var spawn_radius := 7.0

## ── 아이템 테이블 ──
@export var item_count := 0                 ## 최초 진입 시 배치할 아이템 개수
@export var item_luck_bonus := 0.0          ## 이 랜드마크의 드랍 운 보정 (구역 보정에 더해진다)
@export var guaranteed_rarity := -1         ## >=0 이면 그 등급 1개를 확정 드랍 (첫 클리어 보상)

## ── 진행 상태 (세이브 대상) ──
@export var explored := false               ## 한 번이라도 진입했는가
@export var cleared := false                ## 소환된 적을 모두 처치했는가
var visited_count := 0

func is_inside(pos: Vector3) -> bool:
	var flat := Vector2(pos.x - center.x, pos.z - center.z)
	return flat.length() <= radius

## 가중치 테이블에서 적 종류를 하나 뽑는다. 테이블이 비면 "" 를 반환한다.
func roll_spawn_type() -> String:
	if spawn_table.is_empty():
		return ""
	var total := 0
	for k in spawn_table:
		total += int(spawn_table[k])
	if total <= 0:
		return ""
	var r := randi() % total
	for k in spawn_table:
		r -= int(spawn_table[k])
		if r < 0:
			return String(k)
	return String(spawn_table.keys()[0])

## 세이브용 — 진행 상태만 직렬화한다 (정의는 코드에 있으므로 저장하지 않는다)
func to_save() -> Dictionary:
	return {"explored": explored, "cleared": cleared, "visited": visited_count}

func from_save(d: Dictionary) -> void:
	explored = bool(d.get("explored", false))
	cleared = bool(d.get("cleared", false))
	visited_count = int(d.get("visited", 0))
