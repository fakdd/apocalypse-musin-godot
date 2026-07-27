extends RefCounted
class_name EnemyConfig
## 적 타입 정의와 튜닝 상수. Enemy3D 와 행동 모듈이 공유한다.

const GRAVITY := 24.0

## 전투 튜닝 상수 (원본 코드의 매직 넘버를 이름 붙여 옮긴 것 — 값은 동일)
const CHARGE_SPEED_MULT := 4.2       ## 돌진 속도 배율
const CHARGE_DASH_TIME := 0.42       ## 돌진 지속 시간
const CHARGE_HIT_MULT := 1.6         ## 돌진 접촉 피해 배율
const ATTACK_HIT_CD := 0.7           ## 일반 공격 쿨다운
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
}
