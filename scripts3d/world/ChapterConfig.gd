extends RefCounted
class_name ChapterConfig
## 챕터(지역) 정의 테이블.
##
## EnemyConfig.TYPES / WorldConfig 와 같은 패턴이다 — 상수 테이블 하나를 두고
## 매니저들이 읽어 간다. 씬을 챕터마다 만들지 않는 이유는, 이 프로젝트의 월드가
## 100% 런타임 절차 생성이기 때문이다(LandmarkManager·PropScatterManager 가
## BoxMesh/MultiMesh 로 만든다). 씬을 나눠도 안에 들어갈 배치 데이터가 없어
## 빈 씬만 늘어난다. 대신 **챕터 = 캠페인 JSON 1개 + 테마 1개** 로 다룬다.
##
## 각 챕터가 바꾸는 것:
##   campaign  — 어떤 캠페인 JSON 을 읽을지 (랜드마크·퀘스트·웨이브의 원천)
##   theme     — 하늘/안개/조명/바닥색 (EnvironmentManager 가 읽는다)
##   monsters  — 이 지역에 나오는 몬스터 종류 (SpawnManager 가 읽는다)
##   boss      — 이 지역의 최종 보스
##   scale     — 챕터가 올라갈수록 강해지는 배율
##
## ⚠ 캠페인 JSON 이 없는 챕터는 CampaignManager 가 "main" 으로 폴백한다.
##   (지금은 chapter05 = 기존 main 캠페인만 실제 콘텐츠가 있다)

const FIRST := 1
const LAST := 7

const CHAPTERS := {
	1: {
		"name": "잊혀진 숲",
		"subtitle": "나무가 사람을 삼킨 자리",
		"campaign": "chapter01_forest",
		"bgm": "explore",
		"monsters": ["wolf", "goblin", "orc"],
		"boss": "dire_wolf",
		"hp_mult": 1.0, "dmg_mult": 1.0,
		"theme": {
			"day_sky_top": Color(0.16, 0.28, 0.20),
			"day_sky_horizon": Color(0.52, 0.58, 0.34),
			"night_sky_top": Color(0.03, 0.06, 0.05),
			"night_sky_horizon": Color(0.10, 0.20, 0.16),
			"day_fog": 0.020, "night_fog": 0.034,
			"fog_color": Color(0.38, 0.48, 0.36),
			"ground": Color(0.18, 0.24, 0.15),
			"sun": Color(1.0, 0.96, 0.82),
		},
	},
	2: {
		"name": "메마른 사막",
		"subtitle": "모래 밑에서 무언가 움직인다",
		"campaign": "chapter02_desert",
		"bgm": "explore",
		"monsters": ["mummy", "scorpion", "bandit"],
		"boss": "sandworm",
		"hp_mult": 1.25, "dmg_mult": 1.1,
		"theme": {
			"day_sky_top": Color(0.42, 0.34, 0.16),
			"day_sky_horizon": Color(0.86, 0.70, 0.40),
			"night_sky_top": Color(0.06, 0.05, 0.09),
			"night_sky_horizon": Color(0.28, 0.20, 0.16),
			"day_fog": 0.014, "night_fog": 0.026,
			"fog_color": Color(0.74, 0.62, 0.40),
			"ground": Color(0.62, 0.50, 0.30),
			"sun": Color(1.0, 0.90, 0.68),
		},
	},
	3: {
		"name": "얼어붙은 설원",
		"subtitle": "숨소리가 얼어 떨어진다",
		"campaign": "chapter03_snow",
		"bgm": "explore",
		"monsters": ["ice_wisp", "yeti"],
		"boss": "ice_golem",
		"hp_mult": 1.55, "dmg_mult": 1.22,
		"theme": {
			"day_sky_top": Color(0.42, 0.52, 0.64),
			"day_sky_horizon": Color(0.80, 0.86, 0.92),
			"night_sky_top": Color(0.04, 0.06, 0.12),
			"night_sky_horizon": Color(0.16, 0.24, 0.38),
			"day_fog": 0.032, "night_fog": 0.048,
			"fog_color": Color(0.76, 0.84, 0.92),
			"ground": Color(0.78, 0.83, 0.88),
			"sun": Color(0.86, 0.92, 1.0),
		},
	},
	4: {
		"name": "불타는 화산",
		"subtitle": "발밑이 붉게 갈라져 있다",
		"campaign": "chapter04_volcano",
		"bgm": "battle",
		"monsters": ["fire_wisp", "lizardman"],
		"boss": "fire_dragon",
		"hp_mult": 1.95, "dmg_mult": 1.36,
		"theme": {
			"day_sky_top": Color(0.24, 0.06, 0.04),
			"day_sky_horizon": Color(0.72, 0.24, 0.08),
			"night_sky_top": Color(0.08, 0.02, 0.01),
			"night_sky_horizon": Color(0.44, 0.10, 0.03),
			"day_fog": 0.030, "night_fog": 0.044,
			"fog_color": Color(0.52, 0.20, 0.10),
			"ground": Color(0.22, 0.12, 0.10),
			"sun": Color(1.0, 0.64, 0.40),
		},
	},
	5: {
		"name": "폐허 도시",
		"subtitle": "차원의 균열이 처음 열린 곳",
		# 리메이크판. 공원·지하철·병원·백화점·경찰청·학교·방송국·고가·발전소 9곳.
		# 예전 'main' 캠페인 파일은 지우지 않고 남겨 두었다 (폴백 겸 참고용).
		"campaign": "chapter05_city",
		"bgm": "explore",
		"monsters": ["mutant_m", "soldier", "hound", "ravager"],
		"boss": "fallen_lord",
		"hp_mult": 2.15, "dmg_mult": 1.46,
		"theme": {
			# WorldConfig 의 기존 값 — 지금 눈에 보이는 그 색이다
			"day_sky_top": Color(0.32, 0.09, 0.09),
			"day_sky_horizon": Color(0.58, 0.30, 0.22),
			"night_sky_top": Color(0.05, 0.01, 0.04),
			"night_sky_horizon": Color(0.30, 0.04, 0.13),
			"day_fog": 0.022, "night_fog": 0.038,
			"fog_color": Color(0.38, 0.16, 0.14),
			"ground": Color(0.20, 0.16, 0.16),
			"sun": Color(1.0, 0.78, 0.62),
		},
	},
	6: {
		"name": "천공의 성채",
		"subtitle": "구름 위에 무언가 앉아 있다",
		"campaign": "chapter06_sky",
		"bgm": "battle",
		"monsters": ["angel", "knight"],
		"boss": "seraph",
		"hp_mult": 3.25, "dmg_mult": 1.60,
		"theme": {
			"day_sky_top": Color(0.30, 0.44, 0.70),
			"day_sky_horizon": Color(0.92, 0.88, 0.72),
			"night_sky_top": Color(0.06, 0.08, 0.18),
			"night_sky_horizon": Color(0.34, 0.32, 0.52),
			# 흰 안개 + 흰 지형 + 밝은 태양이 겹치면 형태가 전부 날아간다.
			# 안개를 옅게 하고 지면을 낮춰 실루엣이 남게 한다.
			"day_fog": 0.012, "night_fog": 0.022,
			"fog_color": Color(0.66, 0.72, 0.86),
			"ground": Color(0.48, 0.52, 0.62),
			"sun": Color(1.0, 0.96, 0.86),
		},
	},
	7: {
		"name": "심연",
		"subtitle": "여기서 끝난다",
		"campaign": "chapter07_abyss",
		"bgm": "boss",
		"monsters": ["demon", "fallen_knight"],
		"boss": "abyss_lord",
		"hp_mult": 4.10, "dmg_mult": 1.74,
		"theme": {
			"day_sky_top": Color(0.06, 0.02, 0.10),
			"day_sky_horizon": Color(0.24, 0.06, 0.30),
			"night_sky_top": Color(0.02, 0.00, 0.04),
			"night_sky_horizon": Color(0.16, 0.02, 0.22),
			"day_fog": 0.042, "night_fog": 0.056,
			"fog_color": Color(0.22, 0.08, 0.30),
			"ground": Color(0.10, 0.06, 0.14),
			"sun": Color(0.72, 0.52, 1.0),
		},
	},
}

## ══════════════════════════════════════════════
##  지형(biome) — BiomeBuilder 가 읽는다
## ══════════════════════════════════════════════
## kind      "city" 면 기존 폐허 도시 생성을 그대로 쓴다 (도로·건물·스카이라인).
##           그 외에는 도시 생성을 건너뛰고 아래 자연물을 뿌린다.
## props     [종류, 개수, 최소크기, 최대크기, 색] 목록.
##           종류: tree / pine / dead_tree / rock / boulder / grass / bush /
##                 cactus / palm / pillar / spike / crystal / bone / shard
## water     호수/강 — [반경, 색] (0 이면 없음)
## hero      멀리서 보이는 거대 구조물 — [종류, 높이, 색]
##           종류: worldtree / pyramid / spire / volcano / tower / gate
## cliffs    맵 가장자리를 두르는 절벽 개수 (0 이면 없음)
const BIOMES := {
	1: {  ## 숲
		"kind": "forest",
		"props": [
			["tree", 900, 1.6, 3.4, Color(0.20, 0.42, 0.20)],
			["dead_tree", 120, 1.8, 3.0, Color(0.32, 0.27, 0.20)],
			["bush", 500, 0.7, 1.4, Color(0.24, 0.46, 0.24)],
			["grass", 1600, 0.5, 1.1, Color(0.34, 0.54, 0.26)],
			["rock", 220, 0.6, 1.5, Color(0.38, 0.40, 0.36)],
		],
		"water": [11.0, Color(0.24, 0.52, 0.56, 0.62)],
		"hero": ["worldtree", 34.0, Color(0.30, 0.44, 0.24)],
		"cliffs": 18,
	},
	2: {  ## 사막
		"kind": "desert",
		"props": [
			["cactus", 260, 1.2, 2.6, Color(0.32, 0.48, 0.28)],
			["palm", 90, 2.0, 3.4, Color(0.42, 0.50, 0.26)],
			["rock", 420, 0.6, 1.8, Color(0.72, 0.60, 0.40)],
			["boulder", 120, 1.8, 3.6, Color(0.66, 0.54, 0.36)],
			["bone", 140, 0.7, 1.6, Color(0.86, 0.82, 0.70)],
			["grass", 300, 0.4, 0.8, Color(0.62, 0.58, 0.34)],
		],
		"water": [8.0, Color(0.26, 0.60, 0.58, 0.66)],
		"hero": ["pyramid", 26.0, Color(0.74, 0.62, 0.40)],
		"cliffs": 22,
	},
	3: {  ## 설원
		"kind": "snow",
		"props": [
			["pine", 620, 1.8, 3.6, Color(0.16, 0.30, 0.26)],
			["spike", 340, 1.0, 2.8, Color(0.72, 0.88, 0.98)],
			["rock", 300, 0.6, 1.6, Color(0.74, 0.78, 0.84)],
			["boulder", 90, 1.8, 3.2, Color(0.80, 0.85, 0.90)],
			["bush", 260, 0.6, 1.1, Color(0.80, 0.86, 0.92)],
		],
		"water": [12.0, Color(0.62, 0.82, 0.92, 0.55)],
		"hero": ["spire", 30.0, Color(0.80, 0.90, 1.0)],
		"cliffs": 20,
	},
	4: {  ## 화산
		"kind": "volcano",
		"props": [
			["pillar", 380, 1.2, 3.2, Color(0.16, 0.13, 0.13)],
			["rock", 460, 0.6, 1.8, Color(0.22, 0.17, 0.16)],
			["boulder", 130, 1.8, 3.4, Color(0.18, 0.14, 0.13)],
			["dead_tree", 90, 1.6, 2.8, Color(0.20, 0.14, 0.12)],
			["bone", 110, 0.8, 1.8, Color(0.52, 0.44, 0.38)],
		],
		"water": [13.0, Color(0.90, 0.32, 0.08, 0.92)],   ## 용암
		"hero": ["volcano", 32.0, Color(0.24, 0.16, 0.14)],
		"cliffs": 24,
	},
	5: {  ## 폐허 도시 — 기존 생성 유지
		"kind": "city",
		"props": [],
		"water": [0.0, Color(0, 0, 0, 0)],
		"hero": ["", 0.0, Color(0, 0, 0, 0)],
		"cliffs": 0,
	},
	6: {  ## 천공
		"kind": "sky",
		"props": [
			["pillar", 260, 1.4, 3.4, Color(0.72, 0.74, 0.84)],
			["crystal", 220, 1.0, 2.4, Color(0.92, 0.80, 0.42)],
			["bush", 320, 0.6, 1.2, Color(0.48, 0.64, 0.44)],
			["grass", 700, 0.4, 0.9, Color(0.54, 0.68, 0.42)],
			["rock", 180, 0.6, 1.4, Color(0.62, 0.64, 0.74)],
		],
		"water": [10.0, Color(0.72, 0.86, 1.0, 0.50)],
		"hero": ["tower", 36.0, Color(0.92, 0.92, 0.98)],
		"cliffs": 14,
	},
	7: {  ## 심연
		"kind": "abyss",
		"props": [
			["shard", 420, 1.2, 3.6, Color(0.34, 0.12, 0.44)],
			["pillar", 240, 1.6, 3.8, Color(0.14, 0.09, 0.18)],
			["bone", 220, 0.8, 2.0, Color(0.46, 0.40, 0.50)],
			["rock", 260, 0.6, 1.6, Color(0.13, 0.09, 0.16)],
			["crystal", 160, 1.0, 2.6, Color(0.62, 0.20, 0.86)],
		],
		"water": [15.0, Color(0.06, 0.02, 0.12, 0.88)],   ## 검은 바다
		"hero": ["gate", 38.0, Color(0.40, 0.10, 0.56)],
		"cliffs": 26,
	},
}

static func biome_of(n: int) -> Dictionary:
	return BIOMES.get(clampi(n, FIRST, LAST), BIOMES[LAST])

## 이 챕터가 기존 폐허 도시 생성(도로·건물·스카이라인)을 쓰는가.
static func is_city(n: int) -> bool:
	return String(biome_of(n).get("kind", "")) == "city"

## 챕터 정의를 돌려준다. 범위를 벗어나면 마지막 챕터로 물린다.
static func get_chapter(n: int) -> Dictionary:
	var i: int = clampi(n, FIRST, LAST)
	return CHAPTERS.get(i, CHAPTERS[LAST])

static func theme_of(n: int) -> Dictionary:
	return get_chapter(n).get("theme", {})

static func name_of(n: int) -> String:
	return String(get_chapter(n).get("name", "?"))

static func campaign_of(n: int) -> String:
	return String(get_chapter(n).get("campaign", "main"))

static func boss_of(n: int) -> String:
	return String(get_chapter(n).get("boss", "overlord"))

## 이 챕터에 나오는 몬스터 종류. EnemyConfig.TYPES 에 없는 이름은
## SpawnManager 가 걸러내므로, 아직 만들지 않은 종류를 적어 둬도 안전하다.
static func monsters_of(n: int) -> Array:
	return get_chapter(n).get("monsters", [])

## 챕터 난이도 배율 — 정의만 있고 읽는 곳이 없어 챕터가 올라가도 잡몹이 그대로였다.
static func hp_mult_of(n: int) -> float:
	return float(get_chapter(n).get("hp_mult", 1.0))

static func dmg_mult_of(n: int) -> float:
	return float(get_chapter(n).get("dmg_mult", 1.0))

static func is_last(n: int) -> bool:
	return n >= LAST
