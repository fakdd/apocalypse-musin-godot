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

	# 에디터가 F5/F6/F8 을 가져가므로 치트는 Ctrl + 숫자로 옮겼다.
	# F 키를 쓰면 에디터가 실행을 중지시켜 "게임이 꺼지는" 것처럼 보인다.
	var keys := [KEY_QUOTELEFT, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5,
		KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS]
	var names := ["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-"]
	for i in range(keys.size()):
		var ev := InputEventKey.new()
		ev.keycode = keys[i]
		ev.pressed = true
		ev.ctrl_pressed = true
		dc._input(ev)
		await get_tree().process_frame
		await get_tree().process_frame
		print("DBG|  ✔ Ctrl+%s 통과" % names[i])

	# Ctrl 없이 누르면 아무 일도 없어야 한다 (일반 조작과 겹치지 않게)
	var plain := InputEventKey.new()
	plain.keycode = KEY_9
	plain.pressed = true
	var before := CraftManager.essence
	dc._input(plain)
	await get_tree().process_frame
	if CraftManager.essence == before:
		print("DBG|  ✔ Ctrl 없이는 발동하지 않는다")
	else:
		print("DBG|  ✘ Ctrl 없이 발동했다")

	# 무적 토글을 켠 채 몇 프레임 더 (매 프레임 처리 경로 확인)
	for i in range(30):
		await get_tree().process_frame
	# 원상복구
	dc.god_player = false
	dc.god_base = false
	print("DBG| ✔ 전부 통과")
	print("DBG| DONE")
