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

## 마우스 방향으로 몸을 돌린다.
##
## 예전에는 바닥 평면과 광선을 교차시켰다. 카메라가 -50도로 내려다보고 있어서
## **화면 아래쪽을 가리키면 광선이 카메라 코앞 바닥에 꽂힌다.** 그 지점은
## 플레이어보다 뒤쪽이라 캐릭터가 반대로 돌아버렸고, 그래서 아래로 조준이 안 됐다.
##
## 지금은 화면 좌표에서 바로 방향을 구한다. 플레이어의 화면 위치에서 마우스까지의
## 벡터를 카메라의 좌우/전방 축에 얹으면 화면 어디를 가리켜도 그대로 그 방향이 된다.
func _aim_at_mouse() -> void:
	var vp := get_viewport()
	var cam: Camera3D = owner_player.camera
	if vp == null or cam == null or not is_instance_valid(cam):
		return
	var mouse := vp.get_mouse_position()
	var origin := cam.unproject_position(owner_player.global_position)
	var d := mouse - origin
	if d.length() < 6.0:          ## 캐릭터 위를 가리키면 방향을 바꾸지 않는다
		return

	# 카메라의 좌우축과, 바닥에 눕힌 전방축
	var basis := cam.global_transform.basis
	var right := Vector3(basis.x.x, 0.0, basis.x.z)
	var fwd := Vector3(-basis.z.x, 0.0, -basis.z.z)
	if right.length_squared() < 0.0001 or fwd.length_squared() < 0.0001:
		return
	right = right.normalized()
	fwd = fwd.normalized()

	# 화면 y 는 아래로 증가한다 — 아래로 끌면 전방의 반대(화면 아래쪽)를 향한다
	var world := right * d.x - fwd * d.y
	if world.length_squared() < 0.0001:
		return
	world = world.normalized()
	owner_player.facing_angle = atan2(world.x, world.z)
