extends Node
class_name PlayerMovement
## 이동·대시(신법)·점프·마우스 조준 방향 계산.
## Player3D(owner)의 상태를 읽고 쓰는 행동 모듈이다.

var owner_player: CharacterBody3D

func setup(p: CharacterBody3D) -> void:
	owner_player = p

func _start_dash() -> void:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.z += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1
	if dir.length() == 0:
		dir = owner_player.facing_dir()
	owner_player.dash_dir = dir.normalized()
	owner_player.dash_timer = PlayerConfig.DASH_DURATION
	owner_player.dash_cd = PlayerConfig.DASH_COOLDOWN * UpgradeManager.reduce("cooldown")
	owner_player.invuln_timer = max(owner_player.invuln_timer, 0.22)
	SoundManager.play("dash")
	owner_player.animation._spawn_dash_trail()

func _aim_at_mouse() -> void:
	var vp := get_viewport()
	if vp == null or owner_player.camera == null:
		return
	var mouse := vp.get_mouse_position()
	var from: Vector3 = owner_player.camera.project_ray_origin(mouse)
	var dir: Vector3 = owner_player.camera.project_ray_normal(mouse)
	if absf(dir.y) < 0.0001:
		return
	var t := (owner_player.global_position.y - from.y) / dir.y
	if t <= 0:
		return
	var target := from + dir * t
	var to_target := target - owner_player.global_position
	to_target.y = 0
	if to_target.length() < 0.1:
		return
	owner_player.facing_angle = atan2(to_target.x, to_target.z)
