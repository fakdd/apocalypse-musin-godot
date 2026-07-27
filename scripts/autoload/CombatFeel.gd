extends Node
## 타격감 디렉터 — Engine.time_scale 과 화면 전체 연출의 단일 권한자.
##
## 이전 문제:
##   GameManager.hitstop() 이 `if _hitstop_active: return` 으로 **연타 중 두 번째 히트를 통째로 버렸다.**
##   그래서 콤보를 빠르게 이을 때 정작 가장 강한 3타의 히트스톱이 사라지는 일이 잦았다.
##
## 개선:
##   무게(weight) 기반으로 요청을 받고, 더 강한 요청이 오면 **덮어쓰기(escalate)** 한다.
##   time_scale 복원은 항상 한 곳에서만 하므로 슬로모션과 히트스톱이 서로 꼬이지 않는다.

## 히트스톱 강도 프리셋 — 이름이 있으면 밸런스 조정이 쉽다
const HS_LIGHT := 0.035      ## 평타 명중
const HS_MEDIUM := 0.06      ## 콤보 2타
const HS_HEAVY := 0.095      ## 콤보 3타(피니셔)
const HS_KILL := 0.11        ## 처치
const HS_PARRY := 0.13       ## 반로환동 성공
const HS_ULT := 0.2          ## 만천화우

const HS_TIME_SCALE := 0.035     ## 히트스톱 중 시간 배율 (거의 정지 = 프레임이 "박히는" 느낌)
const SLOWMO_SCALE := 0.28       ## 피니시 블로우 슬로모션 배율

var _stop_weight := 0.0          ## 현재 진행 중인 히트스톱의 강도
var _stop_remain := 0.0          ## 남은 실시간(초)
var _slowmo_remain := 0.0
var _slowmo_scale := 1.0

var _flash_layer: CanvasLayer
var _flash_rect: ColorRect
var _flash_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   ## time_scale 0.03 에서도 복원 타이머가 돌아야 한다
	process_priority = 1000                    ## 다른 노드가 끝난 뒤 시간 복원
	_build_flash_overlay()

func _build_flash_overlay() -> void:
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 90                    ## HUD(10) 보다 위, 하지만 최상단은 아님
	add_child(_flash_layer)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(1, 1, 1, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_layer.add_child(_flash_rect)

## 실시간(time_scale 무관) 기준으로 타이머를 줄여야 하므로 델타를 보정한다
func _process(delta: float) -> void:
	var ts: float = maxf(Engine.time_scale, 0.0001)
	var real_delta: float = delta / ts

	if _stop_remain > 0.0:
		_stop_remain -= real_delta
		if _stop_remain <= 0.0:
			_stop_weight = 0.0
			_apply_time_scale()
	elif _slowmo_remain > 0.0:
		_slowmo_remain -= real_delta
		if _slowmo_remain <= 0.0:
			_slowmo_scale = 1.0
			_apply_time_scale()

## 히트스톱이 슬로모션보다 우선한다 (짧고 강한 것이 먼저)
func _apply_time_scale() -> void:
	if _stop_remain > 0.0:
		Engine.time_scale = HS_TIME_SCALE
	elif _slowmo_remain > 0.0:
		Engine.time_scale = _slowmo_scale
	else:
		Engine.time_scale = 1.0

## 히트스톱 요청. 같은/약한 요청은 무시하고, 강한 요청은 즉시 덮어쓴다.
func hit_stop(weight: float) -> void:
	if weight <= 0.0:
		return
	# 진행 중인 것보다 약하면서 아직 시간이 남아 있으면 새로 걸지 않는다
	if weight <= _stop_weight and _stop_remain > 0.0:
		return
	_stop_weight = weight
	_stop_remain = weight
	_apply_time_scale()

## 피니시 블로우 슬로모션 (보스 처치 / 웨이브 마지막 적)
func slow_motion(duration: float, scale: float = SLOWMO_SCALE) -> void:
	if duration <= _slowmo_remain:
		return
	_slowmo_remain = duration
	_slowmo_scale = clampf(scale, 0.05, 1.0)
	_apply_time_scale()

## 화면 전체 플래시 — 크리티컬(콤보 피니셔·처치·궁극기) 순간의 "번쩍"
##   peak: 최대 알파, hold: 최대 유지 시간, fade: 사라지는 시간
func screen_flash(color: Color, peak: float = 0.22, hold: float = 0.02, fade: float = 0.16) -> void:
	if _flash_rect == null:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_rect.color = Color(color.r, color.g, color.b, peak)
	# 히트스톱 중에도 눈에 보이게 실시간(ignore_time_scale)으로 재생한다
	_flash_tween = create_tween().set_ignore_time_scale(true)
	if hold > 0.0:
		_flash_tween.tween_interval(hold)
	_flash_tween.tween_property(_flash_rect, "color:a", 0.0, fade).set_trans(Tween.TRANS_QUAD)

## 카메라 흔들림을 플레이어 카메라에 전달한다 (방향성 킥 포함)
func shake(mag: float, dur: float, dir: Vector3 = Vector3.ZERO) -> void:
	var p := Battlefield.player
	if p and is_instance_valid(p) and p.has_method("shake_from"):
		p.shake_from(mag, dur, dir)

## 씬 재시작 시 시간 배율이 남아 있지 않게 정리
func reset() -> void:
	_stop_weight = 0.0
	_stop_remain = 0.0
	_slowmo_remain = 0.0
	_slowmo_scale = 1.0
	Engine.time_scale = 1.0
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	if _flash_rect:
		_flash_rect.color = Color(1, 1, 1, 0.0)
