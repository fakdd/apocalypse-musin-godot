extends Node
## 챕터 스크린샷 — 지형과 색이 실제로 다른지 눈으로 확인하기 위한 것.
##   godot --quit-after 260 -- --chapter=3 --shot
##
## 월드가 다 만들어진 뒤 카메라를 높이 띄워 한 장 찍고 저장한다.
## 저장 위치: user://shot_chapter<N>.png (실제 경로는 콘솔에 찍는다)

var _frames := 0

func _ready() -> void:
	var want := false
	for a in OS.get_cmdline_user_args():
		if String(a) == "--shot":
			want = true
	if not want:
		queue_free()
		return
	set_process(true)

func _process(_d: float) -> void:
	_frames += 1
	# 특성 화면(layer 20)과 HUD 가 화면을 덮으므로 먼저 걷어낸다
	if _frames == 20:
		var w := get_tree().current_scene
		if w:
			if w.get("trait_screen") != null and is_instance_valid(w.trait_screen):
				w.trait_screen.queue_free()
				w.trait_screen = null
			if w.get("hud") != null and is_instance_valid(w.hud):
				w.hud.visible = false
	# 월드 생성·조명 안정화·SDFGI 수렴을 기다린다
	if _frames < 150:
		return
	set_process(false)
	_shoot()

func _shoot() -> void:
	var world := get_tree().current_scene
	if world == null:
		return

	# 실제 게임 카메라와 같은 높이·각도로 본다 (Player3D: y 8.5, z 7.0, fov 62).
	# 조감도로 찍으면 거리 안개가 과장돼 실제 플레이와 다른 판단을 하게 된다.
	var cam := Camera3D.new()
	cam.fov = 62.0
	world.add_child(cam)
	var c: Vector3 = WorldConfig.world_center()
	# 방주에서 바깥(랜드마크 쪽)을 바라본다
	var eye: Vector3 = c + Vector3(0, 8.5, 24.0)
	cam.global_position = eye
	cam.rotation_degrees = Vector3(-22, 0, 0)
	cam.make_current()

	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := get_viewport().get_texture().get_image()
	var path := "user://shot_chapter%d.png" % GameManager.chapter
	img.save_png(path)
	print("SHOT| 챕터 %d (%s) → %s"
		% [GameManager.chapter, ChapterConfig.name_of(GameManager.chapter),
		ProjectSettings.globalize_path(path)])
	get_tree().quit()
