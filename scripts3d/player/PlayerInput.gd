extends Node
class_name PlayerInput
## 입력 수집 · 어택 버퍼 · 인풋 큐.
##
## 이전 문제:
##   `if Input.is_mouse_button_pressed(LEFT) and atk_cd <= 0` 구조라서
##   쿨다운이 0.05초 남은 순간에 누른 클릭은 **그냥 사라졌다.**
##   플레이어는 "눌렀는데 안 나갔다"고 느끼고, 콤보가 자주 끊겼다.
##
## 개선:
##   1) 어택 버퍼 — 쿨다운 중 눌린 입력을 BUFFER_WINDOW 동안 기억해 쿨다운이 끝나는 프레임에 즉시 발동
##   2) 인풋 큐 — 공격 모션 중 눌린 다음 행동(대시/기공파/반로환동)을 1개 예약해 모션이 끝나면 이어서 발동
##   두 장치 모두 "발동 조건"은 원본과 같다. 입력이 유실되지 않게 하는 것뿐이다.

const BUFFER_WINDOW := 0.18      ## 이 시간 안의 입력은 유효하다고 본다
const QUEUE_WINDOW := 0.30       ## 예약된 행동의 유효 시간

var owner_player: CharacterBody3D

## 어택 버퍼 (좌클릭)
var attack_buffer := 0.0
var _mouse_was_down := false

## 인풋 큐 — 하나만 예약한다 (2개 이상 쌓이면 조작이 "밀린" 느낌이 난다)
var queued_action := ""
var queue_timer := 0.0

## 이동 입력 (물리 프레임마다 갱신)
var move_dir := Vector3.ZERO

func setup(p: CharacterBody3D) -> void:
	owner_player = p

## 매 물리 프레임 가장 먼저 호출된다.
func poll(delta: float) -> void:
	if attack_buffer > 0.0:
		attack_buffer -= delta
	if queue_timer > 0.0:
		queue_timer -= delta
		if queue_timer <= 0.0:
			queued_action = ""

	# ── 좌클릭: 눌린 순간(엣지)을 버퍼에 기록 ──
	var mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if mouse_down and not _mouse_was_down:
		attack_buffer = BUFFER_WINDOW
	elif mouse_down:
		# 꾹 누르고 있으면 연속 공격 (원본 동작 유지)
		attack_buffer = maxf(attack_buffer, BUFFER_WINDOW * 0.5)
	_mouse_was_down = mouse_down

	# ── 이동 입력 ──
	move_dir = Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move_dir.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move_dir.z += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move_dir.x += 1
	if move_dir.length() > 0:
		move_dir = move_dir.normalized()

## 공격을 소비한다. 버퍼에 유효 입력이 있으면 true 를 반환하고 버퍼를 비운다.
func consume_attack() -> bool:
	if attack_buffer > 0.0:
		attack_buffer = 0.0
		return true
	return false

## 스킬 입력을 확인한다. 지금 쓸 수 없으면 큐에 예약한다.
##   ready: 지금 발동 가능한가 (쿨다운/자원 조건)
##   busy:  공격 모션 등으로 지금은 막혀 있는가
func check_skill(action: String, pressed: bool, ready: bool, busy: bool) -> bool:
	if pressed and ready:
		if not busy:
			return true
		# 지금은 막혀 있으니 예약해 둔다
		queued_action = action
		queue_timer = QUEUE_WINDOW
		return false
	# 예약된 것이 이제 발동 가능해졌는가
	if queued_action == action and ready and not busy:
		queued_action = ""
		queue_timer = 0.0
		return true
	return false

func clear_queue() -> void:
	queued_action = ""
	queue_timer = 0.0
