extends RefCounted
class_name PlayerConfig
## 플레이어 튜닝 상수. Player3D 와 행동 모듈이 공유한다.
## (Player3D 에도 같은 이름의 const 별칭이 남아 있어 HUD 등 외부 코드 호환을 유지한다)

const DASH_SPEED := 26.0
const DASH_DURATION := 0.16
const DASH_COOLDOWN := 0.9
const ATTACK_COOLDOWN := 0.34
const ATTACK_RANGE := 4.2
const ATTACK_HALF_ANGLE := 1.0
const RANGED_COOLDOWN := 2.6
const RANGED_RANGE := 16.0
const PARRY_COOLDOWN := 4.0
const PARRY_WINDOW := 0.25
const ULT_RADIUS := 10.0
const GRAVITY := 24.0
const JUMP_SPEED := 9.0

const STEP_INTERVAL := 0.34
const TURN_SPEED := 12.0      ## 모델 회전 보간 속도
const ACCEL := 22.0           ## 가감속 (즉시 정지/출발 방지)
const COMBO_WINDOW := 0.85

## 3타 콤보 배율
const COMBO_DAMAGE := [1.0, 1.25, 1.9]
const COMBO_RANGE := [1.0, 1.05, 1.35]
