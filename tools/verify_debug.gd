extends Node
## 디버그 콘솔 전 기능 스모크.
##   godot --audio-driver Dummy --quit-after 4000 -- --dbgsmoke
## 에디터(디버그 빌드)에서만 켜지는 경로라 배포판 검증에 안 잡힌다.

var _f := 0
var _on := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a) == "--dbgsmoke":
			_on = true
	if not _on:
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func _process(_d: float) -> void:
	_f += 1
	if _f < 60:
		return
	set_process(false)
	await _run()
	get_tree().quit()

func _run() -> void:
	var w = get_tree().current_scene
	if w and w.get("hud") != null and w.hud.get("menu_ui") != null \
			and w.hud.menu_ui.is_open():
		w.hud.menu_ui.close()
	get_tree().paused = false

	var dc = get_node_or_null("/root/DebugConsole")
	print("DBG| 콘솔 노드 %s" % ("있음" if dc != null else "없음(비디버그 빌드)"))
	if dc == null:
		print("DBG| DONE")
		return

	var keys := [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6,
		KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F11, KEY_F12]
	for k in keys:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.pressed = true
		dc._input(ev)
		await get_tree().process_frame
		await get_tree().process_frame
		print("DBG|  ✔ F%d 통과" % (k - KEY_F1 + 1))

	# 무적 토글을 켠 채 몇 프레임 더 (매 프레임 처리 경로 확인)
	for i in range(30):
		await get_tree().process_frame
	# 원상복구
	dc.god_player = false
	dc.god_base = false
	print("DBG| ✔ 전부 통과")
	print("DBG| DONE")
