extends Node
## 성능 벤치마크 — 고정 시드 · 동일 부하에서 렌더/노드/메모리/실프레임시간을 수집한다.
## BENCH_TAG 환경변수로 태그를, BENCH_BATCH=0 으로 MultiMesh 배칭을 끌 수 있다.

var tag := "AFTER"
var frame_us: Array[int] = []

func _count_mm(n: Node) -> int:
	var c := 0
	if n == null: return 0
	for ch in n.get_children():
		if ch is MultiMeshInstance3D: c += 1
	return c

func _ready() -> void:
	tag = OS.get_environment("BENCH_TAG")
	if tag == "": tag = "AFTER"
	if OS.get_environment("BENCH_BATCH") == "0":
		WorldSystem.BATCH_ENABLED = false
		print("BENCH| MultiMesh 배칭 OFF")
	await get_tree().process_frame

func _start() -> void:
	pass

func _enter_tree() -> void:
	# 월드가 만들어지기 전에 배칭 플래그를 세워야 한다
	if OS.get_environment("BENCH_BATCH") == "0":
		WorldSystem.BATCH_ENABLED = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	var w = get_tree().current_scene
	get_tree().paused = false
	if w and w.trait_screen and is_instance_valid(w.trait_screen): w.trait_screen.queue_free()
	GameManager.phase = GameManager.Phase.NIGHT
	GameManager.night_state = GameManager.NightState.WAVE
	GameManager.phase_timer = 999.0
	if w: w.night_timer = 999.0
	var c = w.world_center() if w else Vector3.ZERO
	for i in range(40):
		var a := TAU * i / 40.0
		var r := 12.0 + (i % 5) * 3.0
		w._make_enemy(["hound","stalker","ravager","screecher","juggernaut"][i % 5],
			c + Vector3(cos(a)*r, 0, sin(a)*r))
	await get_tree().create_timer(2.0).timeout

	# 측정 중에는 히트스톱/슬로모션을 끈다 — time_scale 이 CPU 지표를 왜곡한다
	var acc := {"fps":0.0,"draw":0.0,"prim":0.0,"objs":0.0}
	var n := 120
	var prev := Time.get_ticks_usec()
	for i in range(n):
		await get_tree().process_frame
		CombatFeel.reset()
		var now := Time.get_ticks_usec()
		frame_us.append(now - prev)
		prev = now
		acc["fps"] += Performance.get_monitor(Performance.TIME_FPS)
		acc["draw"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		acc["prim"] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		acc["objs"] += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var fn := float(n)
	frame_us.sort()
	var out := []
	out.append("== %s ==" % tag)
	out.append("fps_avg=%.1f" % (acc["fps"]/fn))
	out.append("frame_ms_median=%.2f" % (frame_us[n/2] / 1000.0))
	out.append("frame_ms_p95=%.2f" % (frame_us[int(n*0.95)] / 1000.0))
	out.append("draw_calls=%.0f" % (acc["draw"]/fn))
	out.append("primitives=%.0f" % (acc["prim"]/fn))
	out.append("render_objects=%.0f" % (acc["objs"]/fn))
	out.append("nodes=%d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	out.append("objects=%d" % Performance.get_monitor(Performance.OBJECT_COUNT))
	out.append("mem_static_mb=%.1f" % (Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0))
	out.append("video_mem_mb=%.1f" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0))
	out.append("enemies=%d" % get_tree().get_nodes_in_group("enemies").size())
	out.append("world_children=%d" % (w.get_child_count() if w else 0))
	out.append("multimesh_nodes=%d" % _count_mm(w))
	out.append("shared_mats=%d" % SharedMaterials.cached_count())
	out.append("pool=%s" % str(VfxPool.stats()))
	var txt := "\n".join(out)
	print(txt)
	var f := FileAccess.open("res://tools/bench_%s.txt" % tag, FileAccess.WRITE)
	f.store_string(txt); f.close()
	print("BENCH_DONE")
	get_tree().quit()
