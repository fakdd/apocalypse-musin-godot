extends Node
class_name PlayerSkill
## 스킬 발동 게이트 — "지금 이 스킬을 쓸 수 있는가"의 판단을 한곳에 모은다.
## 실제 효과는 PlayerCombat 이, 입력 버퍼/큐는 PlayerInput 이 담당한다.
## 쿨다운·자원 조건은 원본과 동일하다. 판단 위치만 옮겼다.

var owner_player: CharacterBody3D

func setup(p: CharacterBody3D) -> void:
	owner_player = p

## 공격 모션 중이면 다른 스킬을 바로 못 쓴다 → 인풋 큐로 예약된다
func is_busy() -> bool:
	return owner_player.attack_anim_timer > 0.0 or owner_player.hit_anim_timer > 0.0

## 매 물리 프레임 호출. 버퍼/큐를 거쳐 실제 발동으로 연결한다.
func tick() -> void:
	var p := owner_player
	var inp: PlayerInput = p.input

	# 대화창·제단 화면이 떠 있으면 스킬 키를 무시한다.
	# E 는 대화·줍기·기공파가, F 는 제단 재주사·반로환동이 함께 물려 있고
	# 이 둘은 폴링이라 set_input_as_handled 로는 막히지 않는다.
	if _windows_open():
		inp.clear_queue()
		return

	# ── 검기 (어택 버퍼) ──
	if p.atk_cd <= 0.0 and inp.consume_attack():
		p.combat._slash()

	# ── 만천화우 (Q) — 게이지가 꽉 찼을 때만 ──
	if inp.check_skill("ult", Input.is_key_pressed(KEY_Q),
			p.ult_gauge >= p.ult_max, is_busy()):
		p.combat._ultimate()

	# ── 기공파 (E) — 밤에만 (원본 조건 유지) ──
	if inp.check_skill("beam", Input.is_key_pressed(KEY_E),
			p.ranged_cd <= 0.0 and GameManager.phase == GameManager.Phase.NIGHT, is_busy()):
		p.combat._ranged_wave()

	# ── 반로환동 (F) ──
	if inp.check_skill("parry", Input.is_key_pressed(KEY_F),
			p.parry_cd <= 0.0, is_busy()):
		p.combat._start_parry()

## 전체 화면 창이 떠 있는지 HUD 에 물어본다 (없으면 막지 않는다 — 회귀 방지)
func _windows_open() -> bool:
	var world = owner_player.get_tree().current_scene
	if world == null or world.get("hud") == null:
		return false
	return world.hud.windows_open()
