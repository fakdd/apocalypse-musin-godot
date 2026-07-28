extends RefCounted
class_name EnemyConfig
## 적 타입 정의와 튜닝 상수. Enemy3D 와 행동 모듈이 공유한다.

const GRAVITY := 24.0

## 전투 튜닝 상수 (원본 코드의 매직 넘버를 이름 붙여 옮긴 것 — 값은 동일)
## 웨이브(=일차)마다 붙는 HP 증가분의 배율.
## Enemy3D.setup 의 hp_per_wave 는 상한이 없어 날짜가 갈수록 무한히 두꺼워졌다.
## 배율을 낮추고 상한 웨이브를 둔다.
const HP_PER_WAVE_MULT := 0.7
const HP_WAVE_CAP := 12              ## 12일차 이후로는 더 두꺼워지지 않는다

const CHARGE_SPEED_MULT := 4.2       ## 돌진 속도 배율
const CHARGE_DASH_TIME := 0.42       ## 돌진 지속 시간
const CHARGE_HIT_MULT := 1.6         ## 돌진 접촉 피해 배율
const ATTACK_HIT_CD := 0.7           ## 일반 공격 쿨다운

## 방주가 받는 접촉 피해 배율 (1.0 = 플레이어와 동일).
## 시야 밖 적이 방주로 진군하도록 고친 뒤로 방주에 붙는 적이 크게 늘어,
## 파괴자 한 마리만으로도 200 HP 를 8초 만에 깎았다. 여기를 낮추면 쉬워진다.
##   0.45 → 파괴자 단독 약 17초, 여러 마리가 붙어도 대응할 시간이 생긴다.
const BASE_DAMAGE_MULT := 0.45

## 몬스터가 주는 피해 전역 배율.
## 플레이어에게는 피해 경감 수단이 전혀 없다 — Player3D.take_damage 는 amount 를
## 그대로 뺀다. 방어구도 최대 HP 만 올린다. 그래서 TYPES 의 damage(6~10) 가
## 100 HP 기준으로 체감이 매우 컸다. 여기 한 곳만 고치면 전 몬스터·전 챕터에 걸린다.
##   0.65 → 하운드 8 → 5.2, 라비저 10 → 6.5 (약 15회 피격까지 버틴다)
const CONTACT_DAMAGE_MULT := 0.65
const ATTACK_ANIM_TIME := 0.5        ## 공격 모션 유지 시간
const PROJECTILE_SPEED := 13.0
const PROJECTILE_DMG_MULT := 0.7
const PROJECTILE_LIFE := 4.5
const KNOCKBACK_SCALE := 0.05        ## (구) 즉시 위치 이동 배율 — 하위 호환용으로 남김
const BOSS_STUN_MULT := 0.35         ## 보스는 경직 시간이 짧다

## ── 넉백 (속도 기반) ──
## 원본은 위치를 즉시 더해 밀린 것이 보이지 않았다. 이제 속도에 실어 감쇠시킨다.
## KNOCKBACK_IMPULSE / KNOCKBACK_DAMP 조합의 총 이동거리를 구 방식과 비슷하게 맞췄다.
const KNOCKBACK_IMPULSE := 2.6       ## 넉백 벡터 → 초기 속도 배율
const KNOCKBACK_DAMP := 11.0         ## 초당 감쇠율 (클수록 빨리 멈춘다)
const KNOCKBACK_POP := 2.2           ## 큰 피해 시 살짝 뜨는 수직 속도
const KNOCKBACK_BOSS_RESIST := 0.18  ## 보스는 거의 밀리지 않는다

## ── 피격 리액션 ──
const HURT_ANIM_MIN := 0.12          ## 약한 타격의 움찔 길이
const HURT_ANIM_MAX := 0.30          ## 치명타급 타격의 움찔 길이

## ── 피니시 블로우 ──
const FINISH_SLOWMO_BOSS := 0.85     ## 보스 처치 슬로모션 길이
const FINISH_SLOWMO_LAST := 0.34     ## 웨이브 마지막 적 처치 슬로모션 길이

## ══════════════════════════════════════════
##  AI (EnemyBrain State Machine)
## ══════════════════════════════════════════

## ── 시야 ──
const SIGHT_RANGE := 30.0            ## 이 거리 밖은 아예 안 보인다
const LOS_INTERVAL := 0.18           ## 시야 레이캐스트 간격 (매 프레임 하면 비싸다)
const MEMORY_TIME := 4.0             ## 시야를 잃은 뒤 마지막 위치를 기억하는 시간
const SIGHT_FOV := 1.92              ## 시야각(라디안, 약 110°). 이 밖은 등 뒤라 못 본다
const SIGHT_NEAR := 3.5              ## 이 거리 안은 각도와 무관하게 알아챈다 (코앞)

## ── 소리 감지 ──
## 등 뒤에서 접근해도 가까우면 "인기척"으로 마지막 위치를 잡는다.
## 시야와 달리 벽을 무시하지 않는다 — 벽 너머 소리는 거리를 절반으로 친다.
const HEAR_RANGE := 12.0             ## 기본 청각 반경
const HEAR_SPRINT_MULT := 1.6        ## 플레이어가 빨리 움직이면 더 멀리 들린다
const HEAR_INTERVAL := 0.3           ## 청각 판정 간격

## ── 공격 후 딜레이 ──
const ATTACK_RECOVER := 0.45         ## 공격 모션 뒤 제자리에 서 있는 시간 (빈틈)
const ATTACK_RECOVER_ELITE := 0.28   ## 엘리트/보스는 빈틈이 짧다

## ── 서로 겹치지 않기 (Separation) ──
const SEPARATION_RADIUS := 1.9       ## 이 거리 안의 동료를 밀어낸다
const SEPARATION_FORCE := 1.15       ## 밀어내는 세기
const SEPARATION_INTERVAL := 0.14    ## 이웃 탐색 간격 (매 프레임 하면 비싸다)
const SEPARATION_MAX_NEIGHBORS := 6  ## 한 번에 볼 이웃 수 상한

## ── 목적지 갱신 ──
const REPATH_INTERVAL := 0.22        ## 목적지를 다시 잡는 간격
const REPATH_SLIP := 2.0             ## 목표가 이만큼 움직이면 간격을 기다리지 않고 즉시 갱신

## ── 접지 / 경사 ──
const FLOOR_SNAP := 0.6              ## 바닥 흡착 거리 (경사·계단에서 뜨지 않게)
const FLOOR_MAX_ANGLE := 0.96        ## 오를 수 있는 최대 경사 (라디안, 약 55°)
const GROUND_STICK := 3.0            ## 접지 중 아래로 눌러 주는 속도 (내리막에서 뜨는 것 방지)

## ── 애니메이션 / 발소리 ──
const ANIM_SPEED_REF := 4.0          ## 이 속도일 때 애니메이션 배속 1.0
const ANIM_SPEED_MIN := 0.55
const ANIM_SPEED_MAX := 1.8
const STEP_STRIDE := 1.7             ## 이만큼 걸을 때마다 발소리 한 번
const STEP_MIN_SPEED := 0.6          ## 이보다 느리면 발소리를 내지 않는다

## ── 거리 유지 ──
const RANGE_KEEP_MELEE := 0.9        ## 근접형: 히트박스 + 이 값
const RANGE_KEEP_CHARGE := 7.5       ## 돌진형: 돌진 준비 거리를 유지
const RANGE_KEEP_RANGED := 11.0      ## 원거리형: 사거리 중간을 유지
const RANGE_KEEP_BOSS := 9.0         ## 보스: 탄막을 쓸 수 있는 거리
const SPACING_INNER := 0.72          ## 선호거리 × 이 값보다 가까우면 물러난다
const SPACING_TARGET := 1.05         ## 물러날 목표 지점 (선호거리 × 이 값)
const SPACING_SPEED := 0.85          ## 후진 속도 배율 (앞으로 갈 때보다 느리다)

## ── 협공 ──
const FLANK_RANGE := 18.0            ## 이 거리 안에서 협공 슬롯을 받는다
const SLOT_REFRESH := 1.2            ## 슬롯 재요청 간격

## ── 재배치 ──
const REPOSITION_TIME := 1.1         ## 재배치 상태 유지 시간
const REPOSITION_ARC := 1.15         ## 옆으로 벌리는 각도(라디안, 약 66°)
const REPOSITION_ARC_RADIUS := 1.5   ## 원호 반지름 = 선호거리 × 이 값
const REPOSITION_SPEED := 1.15       ## 재배치는 조금 빠르게 (지루하지 않게)

## ── 그 외 상태 ──
const IDLE_WANDER_SPEED := 0.35      ## Idle 배회 속도 배율
const SEARCH_SPEED := 0.8            ## 마지막 목격 위치로 갈 때의 속도 배율
const SIEGE_INTERRUPT_RANGE := 6.0   ## 공성형이 플레이어에게 반응하는 거리

const ARRIVE_EPSILON := 0.15         ## 목표점까지 이 거리 안이면 도착으로 본다
const TURN_SPEED := 9.0              ## 모델 회전 보간 속도 (즉시 회전은 로봇처럼 보인다)

## ── 벽 회피 ──
const AVOID_PROBE := 2.4             ## 전방 탐지 거리
const AVOID_SIDE_PROBE := 1.8        ## 좌우 탐지 거리
const AVOID_STRENGTH := 1.35         ## 회피 조향 세기
const AVOID_INTERVAL := 0.12         ## 회피 레이캐스트 간격

# 소설 설정 대응:
#  hound/stalker/ravager = 차원의 사냥개 (떼로 덤비는 포식자, 붉은 눈)
#  destroyer/juggernaut  = 차원의 파괴자 (방벽·건물 파괴 우선)
#  overlord              = 차원 환수 보스 (외계 군주, 차원 마력 오라)
const TYPES := {
	"hound": {
		"model": "res://assets3d/monsters/skeletonzombie.tscn",
		"scale": 1.0, "hp": 8.0, "hp_per_wave": 1.4, "speed": 3.8,
		"radius": 0.7, "damage": 8.0, "flying": false,
		"tint": Color(1, 1, 1), "eyes": true, "siege": false, "aura": Color(0, 0, 0, 0),
		"pattern": "melee",
	},
	"stalker": {
		"model": "res://assets3d/monsters/mob_fast.gltf",
		"scale": 0.42, "hp": 5.0, "hp_per_wave": 0.9, "speed": 7.2,
		"radius": 0.6, "damage": 6.0, "flying": true,
		"tint": Color(0.45, 0.12, 0.3), "eyes": true, "siege": false, "aura": Color(0.8, 0.2, 0.9, 1),
		"pattern": "charge",
	},
	"ravager": {
		"model": "res://assets3d/monsters/mutant.tscn",
		"scale": 1.05, "hp": 12.0, "hp_per_wave": 2.0, "speed": 4.6,
		"radius": 0.75, "damage": 10.0, "flying": false,
		"tint": Color(1, 1, 1), "eyes": true, "siege": false, "aura": Color(0, 0, 0, 0),
		"pattern": "melee",
	},
	"screecher": {
		"model": "res://assets3d/monsters/mob_flyer.gltf",
		"scale": 0.5, "hp": 9.0, "hp_per_wave": 1.5, "speed": 4.2,
		"radius": 0.7, "damage": 9.0, "flying": true,
		"tint": Color(0.5, 0.14, 0.34), "eyes": true, "siege": false, "aura": Color(0.9, 0.2, 0.5, 1),
		"pattern": "ranged",
	},
	"destroyer": {
		"model": "res://assets3d/monsters/mutant.tscn",
		"scale": 1.6, "hp": 42.0, "hp_per_wave": 6.0, "speed": 2.2,
		"radius": 1.1, "damage": 18.0, "flying": false,
		"tint": Color(0.75, 0.78, 0.95), "eyes": true, "siege": true, "aura": Color(0, 0, 0, 0),
		"pattern": "melee",
	},
	"juggernaut": {
		"model": "res://assets3d/monsters/pumpkinhulk.tscn",
		"scale": 1.25, "hp": 26.0, "hp_per_wave": 4.0, "speed": 3.0,
		"radius": 0.9, "damage": 14.0, "flying": false,
		"tint": Color(1, 1, 1), "eyes": true, "siege": true, "aura": Color(0, 0, 0, 0),
		"pattern": "charge",
	},
	"overlord": {
		"model": "res://assets3d/monsters/mob_boss.gltf",
		"scale": 1.2, "hp": 320.0, "hp_per_wave": 60.0, "speed": 3.0,
		"radius": 2.0, "damage": 26.0, "flying": true,
		"tint": Color(0.35, 0.08, 0.22), "eyes": true, "siege": false, "aura": Color(0.85, 0.1, 0.35, 1),
		"pattern": "boss",
	},
	"warlord": {
		"model": "res://assets3d/monsters/mob_boss.gltf",
		"scale": 1.9, "hp": 1400.0, "hp_per_wave": 0.0, "speed": 3.4,
		"radius": 3.0, "damage": 42.0, "flying": true,
		"tint": Color(0.9, 0.12, 0.18), "eyes": true, "siege": false, "aura": Color(1.0, 0.1, 0.15, 1),
		"pattern": "boss",
	},

	# ══════════════════════════════════════════════
	#  지역 몬스터 (ChapterConfig.monsters 가 참조한다)
	# ══════════════════════════════════════════════
	# ⚠ 전용 모델이 없어 기존 10개 모델을 색조·크기·스탯으로 나눠 쓴다.
	#   실루엣이 겹치므로, 진짜로 형태가 다른 적이 필요하면
	#   AI Asset Factory 에서 모델을 새로 뽑아 "model" 만 갈아 끼우면 된다.
	#   (스탯·패턴은 그대로 두면 밸런스가 유지된다)

	# ── 1장 · 숲 ──
	"wolf": {
		"model": "res://assets3d/monsters/mob_fast.gltf",
		"scale": 0.44, "hp": 7.0, "hp_per_wave": 1.1, "speed": 6.4,
		"radius": 0.6, "damage": 7.0, "flying": false,
		"tint": Color(0.42, 0.32, 0.24), "eyes": true, "siege": false, "aura": Color(0, 0, 0, 0),
		"pattern": "charge",
	},
	"goblin": {
		"model": "res://assets3d/monsters/mob_grunt.gltf",
		"scale": 0.40, "hp": 6.0, "hp_per_wave": 1.0, "speed": 4.4,
		"radius": 0.55, "damage": 6.0, "flying": false,
		"tint": Color(0.42, 0.62, 0.30), "eyes": true, "siege": false, "aura": Color(0, 0, 0, 0),
		"pattern": "melee",
	},
	"orc": {
		"model": "res://assets3d/monsters/mob_brute.gltf",
		"scale": 0.62, "hp": 16.0, "hp_per_wave": 2.2, "speed": 3.2,
		"radius": 0.85, "damage": 12.0, "flying": false,
		"tint": Color(0.30, 0.46, 0.26), "eyes": true, "siege": false, "aura": Color(0, 0, 0, 0),
		"pattern": "melee",
	},

	# ── 2장 · 사막 ──
	"mummy": {
		"model": "res://assets3d/monsters/skeletonzombie.tscn",
		"scale": 1.0, "hp": 14.0, "hp_per_wave": 1.8, "speed": 2.6,
		"radius": 0.7, "damage": 10.0, "flying": false,
		"tint": Color(0.82, 0.74, 0.56), "eyes": true, "siege": false, "aura": Color(0, 0, 0, 0),
		"pattern": "melee",
	},
	"scorpion": {
		"model": "res://assets3d/monsters/mob_fast.gltf",
		"scale": 0.46, "hp": 9.0, "hp_per_wave": 1.3, "speed": 5.6,
		"radius": 0.62, "damage": 9.0, "flying": false,
		"tint": Color(0.30, 0.22, 0.14), "eyes": true, "siege": false, "aura": Color(0, 0, 0, 0),
		"pattern": "charge",
	},
	"bandit": {
		"model": "res://assets3d/monsters/mob_grunt.gltf",
		"scale": 0.46, "hp": 10.0, "hp_per_wave": 1.4, "speed": 4.0,
		"radius": 0.6, "damage": 8.0, "flying": false,
		"tint": Color(0.58, 0.42, 0.26), "eyes": true, "siege": false, "aura": Color(0, 0, 0, 0),
		"pattern": "ranged",
	},

	# ── 3장 · 설원 ──
	"ice_wisp": {
		"model": "res://assets3d/monsters/mob_flyer.gltf",
		"scale": 0.48, "hp": 12.0, "hp_per_wave": 1.6, "speed": 4.4,
		"radius": 0.65, "damage": 11.0, "flying": true,
		"tint": Color(0.62, 0.86, 1.0), "eyes": true, "siege": false, "aura": Color(0.5, 0.85, 1.0, 1),
		"pattern": "ranged",
	},
	"yeti": {
		"model": "res://assets3d/monsters/pumpkinhulk.tscn",
		"scale": 1.30, "hp": 34.0, "hp_per_wave": 4.4, "speed": 3.0,
		"radius": 0.95, "damage": 16.0, "flying": false,
		"tint": Color(0.90, 0.94, 0.98), "eyes": true, "siege": true, "aura": Color(0, 0, 0, 0),
		"pattern": "charge",
	},

	# ── 4장 · 화산 ──
	"fire_wisp": {
		"model": "res://assets3d/monsters/mob_flyer.gltf",
		"scale": 0.50, "hp": 15.0, "hp_per_wave": 2.0, "speed": 4.6,
		"radius": 0.68, "damage": 13.0, "flying": true,
		"tint": Color(1.0, 0.56, 0.22), "eyes": true, "siege": false, "aura": Color(1.0, 0.45, 0.1, 1),
		"pattern": "ranged",
	},
	"lizardman": {
		"model": "res://assets3d/monsters/mob_brute.gltf",
		"scale": 0.66, "hp": 26.0, "hp_per_wave": 3.4, "speed": 3.6,
		"radius": 0.88, "damage": 15.0, "flying": false,
		"tint": Color(0.72, 0.26, 0.18), "eyes": true, "siege": false, "aura": Color(0, 0, 0, 0),
		"pattern": "melee",
	},

	# ── 5장 · 폐허 도시 ──
	"mutant_m": {
		"model": "res://assets3d/monsters/mutant.tscn",
		"scale": 1.10, "hp": 30.0, "hp_per_wave": 3.8, "speed": 4.2,
		"radius": 0.80, "damage": 15.0, "flying": false,
		"tint": Color(0.72, 0.80, 0.62), "eyes": true, "siege": false, "aura": Color(0, 0, 0, 0),
		"pattern": "melee",
	},
	"soldier": {
		"model": "res://assets3d/monsters/mob_tank.gltf",
		"scale": 0.58, "hp": 28.0, "hp_per_wave": 3.4, "speed": 3.4,
		"radius": 0.82, "damage": 14.0, "flying": false,
		"tint": Color(0.46, 0.50, 0.44), "eyes": true, "siege": true, "aura": Color(0, 0, 0, 0),
		"pattern": "ranged",
	},

	# ── 6장 · 천공 ──
	"angel": {
		"model": "res://assets3d/monsters/mob_flyer.gltf",
		"scale": 0.58, "hp": 30.0, "hp_per_wave": 4.0, "speed": 5.0,
		"radius": 0.72, "damage": 18.0, "flying": true,
		"tint": Color(1.0, 0.98, 0.86), "eyes": true, "siege": false, "aura": Color(1.0, 0.95, 0.7, 1),
		"pattern": "ranged",
	},
	"knight": {
		"model": "res://assets3d/monsters/mob_tank.gltf",
		"scale": 0.70, "hp": 46.0, "hp_per_wave": 5.6, "speed": 3.2,
		"radius": 0.95, "damage": 21.0, "flying": false,
		"tint": Color(0.82, 0.84, 0.90), "eyes": true, "siege": true, "aura": Color(0, 0, 0, 0),
		"pattern": "melee",
	},

	# ── 7장 · 심연 ──
	"demon": {
		"model": "res://assets3d/monsters/mob_alien.gltf",
		"scale": 0.62, "hp": 44.0, "hp_per_wave": 5.4, "speed": 4.8,
		"radius": 0.86, "damage": 22.0, "flying": false,
		"tint": Color(0.58, 0.14, 0.62), "eyes": true, "siege": false, "aura": Color(0.7, 0.1, 0.9, 1),
		"pattern": "charge",
	},
	"fallen_knight": {
		"model": "res://assets3d/monsters/mob_tank.gltf",
		"scale": 0.78, "hp": 62.0, "hp_per_wave": 7.0, "speed": 3.4,
		"radius": 1.0, "damage": 25.0, "flying": false,
		"tint": Color(0.26, 0.20, 0.32), "eyes": true, "siege": true, "aura": Color(0.4, 0.1, 0.6, 1),
		"pattern": "melee",
	},

	# ══════════════════════════════════════════════
	#  지역 보스 — 각 챕터의 마지막을 지킨다
	# ══════════════════════════════════════════════
	# pattern="boss" 는 페이즈별 탄막/돌진을 쓴다 (EnemyBrain._try_boss_pattern).
	# is_boss_type() 은 이름으로 판정하므로, 이 목록은 BOSS_TYPES 에도 넣어야 한다.
	"dire_wolf": {
		"model": "res://assets3d/monsters/mob_brute.gltf",
		"scale": 1.30, "hp": 260.0, "hp_per_wave": 26.0, "speed": 5.2,
		"radius": 1.8, "damage": 22.0, "flying": false,
		"tint": Color(0.34, 0.26, 0.20), "eyes": true, "siege": false, "aura": Color(0.6, 0.4, 0.15, 1),
		"pattern": "boss",
	},
	"sandworm": {
		"model": "res://assets3d/monsters/mutant.tscn",
		"scale": 2.20, "hp": 420.0, "hp_per_wave": 40.0, "speed": 2.8,
		"radius": 2.2, "damage": 28.0, "flying": false,
		"tint": Color(0.78, 0.64, 0.40), "eyes": true, "siege": false, "aura": Color(0.8, 0.6, 0.3, 1),
		"pattern": "boss",
	},
	"ice_golem": {
		"model": "res://assets3d/monsters/pumpkinhulk.tscn",
		"scale": 2.00, "hp": 560.0, "hp_per_wave": 52.0, "speed": 2.6,
		"radius": 2.2, "damage": 32.0, "flying": false,
		"tint": Color(0.72, 0.88, 1.0), "eyes": true, "siege": false, "aura": Color(0.5, 0.8, 1.0, 1),
		"pattern": "boss",
	},
	"fire_dragon": {
		"model": "res://assets3d/monsters/mob_flyer.gltf",
		"scale": 1.60, "hp": 720.0, "hp_per_wave": 64.0, "speed": 4.4,
		"radius": 2.4, "damage": 36.0, "flying": true,
		"tint": Color(1.0, 0.38, 0.14), "eyes": true, "siege": false, "aura": Color(1.0, 0.35, 0.05, 1),
		"pattern": "boss",
	},
	"fallen_lord": {
		"model": "res://assets3d/monsters/mob_boss.gltf",
		"scale": 1.30, "hp": 880.0, "hp_per_wave": 78.0, "speed": 3.2,
		"radius": 2.2, "damage": 38.0, "flying": true,
		"tint": Color(0.40, 0.10, 0.24), "eyes": true, "siege": false, "aura": Color(0.85, 0.1, 0.35, 1),
		"pattern": "boss",
	},
	"seraph": {
		"model": "res://assets3d/monsters/mob_boss.gltf",
		"scale": 1.55, "hp": 1050.0, "hp_per_wave": 92.0, "speed": 4.0,
		"radius": 2.5, "damage": 42.0, "flying": true,
		"tint": Color(1.0, 0.96, 0.80), "eyes": true, "siege": false, "aura": Color(1.0, 0.92, 0.6, 1),
		"pattern": "boss",
	},
	"abyss_lord": {
		"model": "res://assets3d/monsters/mob_boss.gltf",
		"scale": 2.10, "hp": 1600.0, "hp_per_wave": 0.0, "speed": 3.6,
		"radius": 3.0, "damage": 48.0, "flying": true,
		"tint": Color(0.44, 0.10, 0.66), "eyes": true, "siege": false, "aura": Color(0.65, 0.05, 0.95, 1),
		"pattern": "boss",
	},
}

## 보스로 취급할 타입 (그룹 "boss" 에 들어가고, 챕터 포탈을 연다).
## Enemy3D.is_boss_type() 이 이 목록을 본다.
const BOSS_TYPES := [
	"overlord", "warlord",
	"dire_wolf", "sandworm", "ice_golem", "fire_dragon",
	"fallen_lord", "seraph", "abyss_lord",
]

# ══════════════════════════════════════════════
#  보스 연출·페이즈 데이터 (data/bosses.json)
# ══════════════════════════════════════════════
const BOSS_PATH := "res://data/bosses.json"
static var _boss_cache: Dictionary = {}

static func boss_data() -> Dictionary:
	if not _boss_cache.is_empty():
		return _boss_cache
	var f := FileAccess.open(BOSS_PATH, FileAccess.READ)
	if f == null:
		_boss_cache = {"bosses": {}, "defaults": {}}
		return _boss_cache
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	_boss_cache = j if typeof(j) == TYPE_DICTIONARY else {"bosses": {}, "defaults": {}}
	return _boss_cache

static func boss_def(type: String) -> Dictionary:
	return boss_data().get("bosses", {}).get(type, {})

## 보스 설정을 defaults 로 채워 돌려준다. 없는 보스는 빈 딕셔너리.
static func boss_field(type: String, key: String) -> Variant:
	var d := boss_def(type)
	if d.has(key):
		return d[key]
	return boss_data().get("defaults", {}).get(key, null)

## hp 비율에 해당하는 페이즈 정의와 번호를 돌려준다.
static func boss_phase_def(type: String, ratio: float) -> Dictionary:
	var ph: Array = boss_def(type).get("phases", [])
	for i in range(ph.size()):
		if ratio >= float(ph[i].get("at", 0.0)):
			return ph[i]
	if ph.is_empty():
		return {}
	return ph[ph.size() - 1]

static func boss_phase_index(type: String, ratio: float) -> int:
	var ph: Array = boss_def(type).get("phases", [])
	for i in range(ph.size()):
		if ratio >= float(ph[i].get("at", 0.0)):
			return i
	return maxi(0, ph.size() - 1)

# ══════════════════════════════════════════════
#  전술 프로필 (data/ai.json)
# ══════════════════════════════════════════════
const AI_PATH := "res://data/ai.json"
static var _ai_cache: Dictionary = {}

static func ai_data() -> Dictionary:
	if not _ai_cache.is_empty():
		return _ai_cache
	var f := FileAccess.open(AI_PATH, FileAccess.READ)
	if f == null:
		_ai_cache = {"profiles": {}, "by_type": {}}
		return _ai_cache
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	_ai_cache = j if typeof(j) == TYPE_DICTIONARY else {"profiles": {}, "by_type": {}}
	return _ai_cache

## pattern 기본값 위에 몬스터별 덮어쓰기를 얹은 최종 프로필.
static func ai_profile(type: String, pattern: String) -> Dictionary:
	var d := ai_data()
	var base: Dictionary = d.get("profiles", {}).get(pattern, {}).duplicate()
	var over: Dictionary = d.get("by_type", {}).get(type, {})
	for k in over:
		base[k] = over[k]
	return base

## 등급별 전술 배율 (dodge / flank / retreat)
static func ai_tier_scale(key: String, tier: int) -> float:
	var arr: Array = ai_data().get("tier_scale", {}).get(key, [])
	if arr.is_empty():
		return 1.0
	return float(arr[clampi(tier, 0, arr.size() - 1)])

static func ai_num(section: String, key: String, fallback: float) -> float:
	return float(ai_data().get(section, {}).get(key, fallback))

# ══════════════════════════════════════════════
#  몬스터 개성 (data/monsters.json)
# ══════════════════════════════════════════════
const MON_PATH := "res://data/monsters.json"
static var _mon_cache: Dictionary = {}

static func mon_data() -> Dictionary:
	if not _mon_cache.is_empty():
		return _mon_cache
	var f := FileAccess.open(MON_PATH, FileAccess.READ)
	if f == null:
		_mon_cache = {"monsters": {}, "behaviors": {}}
		return _mon_cache
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	_mon_cache = j if typeof(j) == TYPE_DICTIONARY else {"monsters": {}, "behaviors": {}}
	return _mon_cache

static func mon_trait(type: String) -> Dictionary:
	return mon_data().get("monsters", {}).get(type, {})

## 이 몬스터의 대표 행동 정의 (없으면 빈 딕셔너리)
static func mon_behavior(type: String) -> Dictionary:
	var sig := String(mon_trait(type).get("signature", ""))
	if sig == "":
		return {}
	return mon_data().get("behaviors", {}).get(sig, {})

static func mon_danger(type: String) -> int:
	return int(mon_trait(type).get("danger", 0))

static func mon_color(type: String) -> Color:
	var c = mon_data().get("danger_colors", {}).get(str(mon_danger(type)), null)
	if typeof(c) == TYPE_ARRAY and c.size() >= 3:
		return Color(float(c[0]), float(c[1]), float(c[2]))
	return Color(1, 1, 1)

## 초반 챕터 장판/충격파 완화 배율 (data/monsters.json 의 chapter_scale)
static func mon_chapter_scale(key: String) -> float:
	var cs: Dictionary = mon_data().get("chapter_scale", {})
	var c := str(clampi(GameManager.chapter, 1, 99))
	while int(c) > 1 and not cs.has(c):
		c = str(int(c) - 1)
	return float(cs.get(c, {}).get(key, 1.0))
