extends RefCounted
class_name LandmarkCatalog
## 랜드마크 정의 목록 — CITY_DESIGN.md 의 건물 컨셉을 데이터로 옮긴 것.
##
## 새 랜드마크를 추가하려면 all() 에 항목 하나만 넣으면 된다.
## (LandmarkManager 가 배치하고, 미니맵/HUD/스폰/드랍/BGM 은 자동으로 따라온다)
##
## ⚠ 설정을 Dictionary 로 받는 이유:
##   위치 인자(_mk(a, b, c, d, …))로 만들었더니 값 하나를 빼먹었을 때 뒤의 인자가 전부
##   한 칸씩 밀려, 튜토리얼급 랜드마크가 SSS 아이템을 확정 드랍하는 사고가 났다.
##   키 이름으로 받으면 빠뜨린 값은 기본값이 되고, 밀림 자체가 불가능하다.
##
## 난이도 티어:
##   tier 1 — 안전지대 근처. 첫 탐험용. 잡몹 소수 + 낮은 등급 확정 보상
##   tier 2 — 폐허 도시 중간. 엘리트 포함 + 중간 등급
##   tier 3 — 균열 구역. 다수 + 보스급 + 고등급 확정 보상

## 기본값 — 명시하지 않은 키는 이 값을 쓴다
const DEFAULTS := {
	"radius": 9.0,
	"budget": 3,          ## 최초 진입 시 소환할 수호 몬스터 수
	"items": 2,           ## 최초 진입 시 배치할 아이템 수
	"luck": 0.0,          ## 드랍 운 보정 (%)
	"guaranteed": -1,     ## 확정 드랍 등급 (-1 = 없음)
	"bgm": "explore",
	"color": Color(0.85, 0.75, 0.45),
	"stinger": "",
}

static func _mk(cfg: Dictionary) -> LandmarkData:
	var d := LandmarkData.new()
	d.id = String(cfg["id"])
	d.display_name = String(cfg["name"])
	d.subtitle = String(cfg.get("subtitle", ""))
	d.description = String(cfg.get("desc", ""))
	d.spawn_table = cfg.get("spawn", {})
	d.radius = float(cfg.get("radius", DEFAULTS["radius"]))
	d.spawn_budget = int(cfg.get("budget", DEFAULTS["budget"]))
	d.spawn_radius = d.radius * 0.8
	d.item_count = int(cfg.get("items", DEFAULTS["items"]))
	d.item_luck_bonus = float(cfg.get("luck", DEFAULTS["luck"]))
	d.guaranteed_rarity = int(cfg.get("guaranteed", DEFAULTS["guaranteed"]))
	d.bgm = String(cfg.get("bgm", DEFAULTS["bgm"]))
	d.minimap_color = cfg.get("color", DEFAULTS["color"])
	d.enter_stinger = String(cfg.get("stinger", DEFAULTS["stinger"]))
	return d

static func all() -> Array[LandmarkData]:
	var out: Array[LandmarkData] = []

	# ══ Tier 1 — 첫 탐험 (안전지대 인접) ══
	out.append(_mk({
		"id": "clinic", "name": "무너진 보건소",
		"subtitle": "약품 냄새가 아직 남아 있다",
		"desc": "응급 침상이 복도까지 밀려나 있다. 누군가 여기서 마지막까지 사람을 살리려 했다.\n의약품 상자에 쓸 만한 것이 남아 있을지도 모른다.",
		"color": Color(0.55, 0.9, 0.75), "bgm": "explore",
		"spawn": {"hound": 3}, "budget": 2,
		"items": 2, "luck": 10.0, "guaranteed": RarityEnums.Rarity.E, "radius": 8.0,
	}))

	out.append(_mk({
		"id": "convenience", "name": "24시 편의점",
		"subtitle": "간판만 아직 깜빡인다",
		"desc": "유리창이 전부 깨졌지만 진열대 안쪽은 손대지 않은 채다.\n사람들은 이곳을 지날 여유조차 없었던 모양이다.",
		"color": Color(0.9, 0.85, 0.5), "bgm": "explore",
		"spawn": {"hound": 2}, "budget": 2,
		"items": 2, "luck": 8.0, "radius": 7.5,
	}))

	out.append(_mk({
		"id": "school", "name": "제3고등학교",
		"subtitle": "칠판에 날짜가 멈춰 있다",
		"desc": "운동장에 헬기 착륙 표시가 급하게 그려져 있다. 그 헬기는 오지 않았다.\n교실 사물함에 학생들이 남긴 것들이 그대로 있다.",
		"color": Color(0.7, 0.8, 0.95), "bgm": "explore",
		"spawn": {"hound": 3, "stalker": 1}, "budget": 4,
		"items": 3, "luck": 12.0, "guaranteed": RarityEnums.Rarity.D, "radius": 10.0,
	}))

	# ══ Tier 2 — 폐허 도시 (엘리트 등장) ══
	out.append(_mk({
		"id": "police", "name": "중앙 경찰서",
		"subtitle": "무기고 문이 안쪽에서 잠겼다",
		"desc": "바리케이드가 건물 안쪽을 향해 세워져 있다. 막으려던 것이 밖이 아니었다.\n무기고에는 아직 쓸 수 있는 장비가 남아 있다.",
		"color": Color(0.5, 0.65, 1.0), "bgm": "tense", "stinger": "night_start",
		"spawn": {"hound": 2, "ravager": 2, "destroyer": 1}, "budget": 5,
		"items": 3, "luck": 25.0, "guaranteed": RarityEnums.Rarity.C, "radius": 11.0,
	}))

	out.append(_mk({
		"id": "mall", "name": "폐쇄된 백화점",
		"subtitle": "에스컬레이터가 거꾸로 멈췄다",
		"desc": "3층 높이 아트리움에 균열의 잔재가 고여 있다. 마네킹들이 모두 같은 방향을 보고 있다.\n명품관 진열장은 아무도 손대지 않았다.",
		"color": Color(0.85, 0.6, 0.9), "bgm": "tense",
		"spawn": {"stalker": 2, "ravager": 2, "juggernaut": 1}, "budget": 5,
		"items": 4, "luck": 30.0, "guaranteed": RarityEnums.Rarity.C, "radius": 12.0,
	}))

	out.append(_mk({
		"id": "subway", "name": "지하철 환승역",
		"subtitle": "아래에서 바람이 올라온다",
		"desc": "개찰구가 전부 열려 있다. 사람들은 지하로 내려갔고, 올라온 것은 다른 것이었다.\n선로 쪽에서 긁는 소리가 들린다.",
		"color": Color(0.6, 0.55, 0.7), "bgm": "tense",
		"spawn": {"hound": 4, "stalker": 2, "destroyer": 1}, "budget": 7,
		"items": 4, "luck": 28.0, "radius": 11.0,
	}))

	out.append(_mk({
		"id": "factory", "name": "폐기된 제철소",
		"subtitle": "용광로가 아직 뜨겁다",
		"desc": "누군가 최근까지 이곳에서 무기를 벼렸다. 모루 위에 미완성 검이 남아 있다.\n마석을 다루던 흔적이 곳곳에 있다.",
		"color": Color(1.0, 0.6, 0.35), "bgm": "tense",
		"spawn": {"ravager": 3, "juggernaut": 2}, "budget": 6,
		"items": 4, "luck": 35.0, "guaranteed": RarityEnums.Rarity.B, "radius": 12.0,
	}))

	# ══ Tier 3 — 차원의 균열 구역 (보스급) ══
	out.append(_mk({
		"id": "broadcast", "name": "방송국 송신탑",
		"subtitle": "마지막 방송이 반복 재생된다",
		"desc": "\"…대피하십시오. 반복합니다…\" 스튜디오 조명이 여전히 켜져 있다.\n송신탑 아래에 균열이 직접 뚫려 있다.",
		"color": Color(1.0, 0.4, 0.45), "bgm": "danger", "stinger": "night_start",
		"spawn": {"screecher": 3, "ravager": 2, "juggernaut": 2}, "budget": 7,
		"items": 5, "luck": 45.0, "guaranteed": RarityEnums.Rarity.B, "radius": 13.0,
	}))

	out.append(_mk({
		"id": "cathedral", "name": "성모 대성당",
		"subtitle": "기도가 끝나지 않았다",
		"desc": "신도석이 제단을 향해 가지런하다. 아무도 도망가지 않았다는 뜻이다.\n스테인드글라스 너머로 붉은 하늘이 비친다.",
		"color": Color(1.0, 0.85, 0.55), "bgm": "danger",
		"spawn": {"screecher": 2, "destroyer": 2, "juggernaut": 2}, "budget": 6,
		"items": 5, "luck": 55.0, "guaranteed": RarityEnums.Rarity.A, "radius": 13.0,
	}))

	out.append(_mk({
		"id": "rift_core", "name": "균열의 심장부",
		"subtitle": "공간이 이곳에서 찢어졌다",
		"desc": "차원의 문이 처음 열린 지점. 중력이 어긋나 잔해가 공중에 떠 있다.\n환수 하나가 이 자리를 지키고 있다.",
		"color": Color(1.0, 0.15, 0.3), "bgm": "boss", "stinger": "ultimate",
		"spawn": {"ravager": 3, "juggernaut": 2, "overlord": 1}, "budget": 6,
		"items": 6, "luck": 90.0, "guaranteed": RarityEnums.Rarity.S, "radius": 15.0,
	}))

	return out
