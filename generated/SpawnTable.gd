## ⚠ AI Asset Factory 가 자동 생성한 파일입니다.
## 난이도 편집기에서 값을 바꾸고 다시 생성하세요 — 직접 편집하면 다음 생성 때 덮어씁니다.

extends RefCounted
class_name SpawnTable
## 랜드마크별 웨이브 구성 — 난이도 편집기에서 생성됨.
##
## 사용 예:
##     var waves := SpawnTable.waves_for("police")
##     for w in waves:
##         for etype in w.composition:
##             for i in range(w.composition[etype]):
##                 spawn_enemy(etype, w.hp_mult)
##         if w.boss != "":
##             spawn_boss(w.boss, w.boss_hp_mult)

## 웨이브 1개의 정의
class Wave extends RefCounted:
	var index := 1
	var composition := {}       ## {"hound": 3} — 적 종류별 마릿수
	var delay := 0.0            ## 이전 웨이브 종료 후 대기 시간(초)
	var hp_mult := 1.0          ## 이 웨이브 적의 HP 배율
	var boss := ""              ## 보스 타입 ("" = 없음)
	var boss_hp_mult := 1.0

	func total_count() -> int:
		var n := 0
		for k in composition:
			n += int(composition[k])
		return n

static func _w(idx: int, comp: Dictionary, delay: float, hp: float,
		boss: String = "", boss_hp: float = 1.0) -> Wave:
	var w := Wave.new()
	w.index = idx
	w.composition = comp
	w.delay = delay
	w.hp_mult = hp
	w.boss = boss
	w.boss_hp_mult = boss_hp
	return w

## 랜드마크 id → 웨이브 목록
static func waves_for(landmark_id: String) -> Array:
	match landmark_id:
		"clinic":   # ★☆☆☆☆ Lv2
			return [
				_w(1, {"hound": 3}, 0.0, 1.05, "", 1.0),
			]
		"police":   # ★★★☆☆ Lv8
			return [
				_w(1, {"hound": 2, "ravager": 2, "destroyer": 1}, 0.0, 1.35, "", 1.0),
				_w(2, {"hound": 3, "ravager": 3, "destroyer": 2}, 12.0, 1.55, "", 1.0),
			]
		"rift_core":   # ★★★★★ Lv20
			return [
				_w(1, {"ravager": 3, "juggernaut": 2, "screecher": 2, "destroyer": 1}, 0.0, 1.95, "", 1.0),
				_w(2, {"ravager": 4, "juggernaut": 2, "screecher": 2, "destroyer": 1}, 12.0, 2.24, "", 1.0),
				_w(3, {"ravager": 4, "juggernaut": 3, "screecher": 3, "destroyer": 2}, 12.0, 2.54, "overlord", 2.52),
			]
	return []

## 이 랜드마크에 웨이브 정의가 있는가 (없으면 기존 spawn_budget 방식을 쓴다)
static func has_waves(landmark_id: String) -> bool:
	return not waves_for(landmark_id).is_empty()

## 난이도 표시용 — 위험도(1~5)와 추천 레벨
static func difficulty_of(landmark_id: String) -> Dictionary:
	match landmark_id:
		"clinic":
			return {"danger": 1, "level": 2, "hp_mult": 1.05}
		"police":
			return {"danger": 3, "level": 8, "hp_mult": 1.35}
		"rift_core":
			return {"danger": 5, "level": 20, "hp_mult": 1.95}
	return {"danger": 1, "level": 1, "hp_mult": 1.0}

## ★★★☆☆ 형태의 표시 문자열
static func stars_of(landmark_id: String) -> String:
	var d: int = int(difficulty_of(landmark_id).get("danger", 1))
	var out := ""
	for i in range(5):
		out += "★" if i < d else "☆"
	return out
