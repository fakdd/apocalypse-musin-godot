extends SceneTree
## hero.tscn 에 파생 애니메이션을 추가한다.
##  walk_back : walk 을 역재생 (뒷걸음)
##  hit       : die 앞부분을 잘라낸 피격 흠칫
##  idle_combat: idle 을 빠르게 (전투 대기)
## Mixamo 파일을 더 받지 않고도 동작 종류를 늘리는 방법이다.

func _init() -> void:
	var scn: PackedScene = load("res://assets3d/chars/hero.tscn")
	if scn == null:
		push_error("hero.tscn 없음")
		quit(1); return
	var root: Node3D = scn.instantiate()
	get_root().add_child(root)
	await process_frame

	var ap: AnimationPlayer = root.find_child("AnimationPlayer", true, false)
	if ap == null:
		push_error("AnimationPlayer 없음")
		quit(1); return

	var lib: AnimationLibrary = ap.get_animation_library("")
	if lib == null:
		push_error("라이브러리 없음")
		quit(1); return

	# 1) 뒷걸음 — walk 역재생
	if lib.has_animation("walk") and not lib.has_animation("walk_back"):
		var wb := _reverse(lib.get_animation("walk"))
		wb.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation("walk_back", wb)
		print("baked walk_back  len=%.2f" % wb.length)

	# 2) 피격 흠칫 — die 의 앞 0.55초만
	if lib.has_animation("die") and not lib.has_animation("hit"):
		var h := _slice(lib.get_animation("die"), 0.0, 0.55)
		h.loop_mode = Animation.LOOP_NONE
		lib.add_animation("hit", h)
		print("baked hit  len=%.2f" % h.length)

	# 3) 전투 대기 — idle 을 시간축 압축
	if lib.has_animation("idle") and not lib.has_animation("idle_combat"):
		var ic := _timescale(lib.get_animation("idle"), 0.55)
		ic.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation("idle_combat", ic)
		print("baked idle_combat  len=%.2f" % ic.length)

	_own_all(root, root)
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("pack 실패"); quit(1); return
	var err := ResourceSaver.save(packed, "res://assets3d/chars/hero.tscn")
	print("saved err=", err)
	print("최종 애니메이션:", ap.get_animation_list())
	quit(0)

## 역재생 클립. track_set_key_time 은 키를 자동 재정렬하므로
## 전부 지우고 뒤집힌 시간으로 다시 삽입해야 안전하다.
func _reverse(src: Animation) -> Animation:
	var a: Animation = src.duplicate(true)
	var L := a.length
	for t in range(a.get_track_count()):
		var ttype := a.track_get_type(t)
		var n := a.track_get_key_count(t)
		var times := []
		var vals := []
		for k in range(n):
			times.append(a.track_get_key_time(t, k))
			vals.append(a.track_get_key_value(t, k))
		# 기존 키 전부 제거 (뒤에서부터)
		for k in range(n - 1, -1, -1):
			a.track_remove_key(t, k)
		# 시간을 뒤집어 재삽입
		for k in range(n):
			var new_time: float = L - times[n - 1 - k]
			var v = vals[n - 1 - k]
			match ttype:
				Animation.TYPE_POSITION_3D:
					a.position_track_insert_key(t, new_time, v)
				Animation.TYPE_ROTATION_3D:
					a.rotation_track_insert_key(t, new_time, v)
				Animation.TYPE_SCALE_3D:
					a.scale_track_insert_key(t, new_time, v)
				_:
					a.track_insert_key(t, new_time, v)
	return a

## [from, to] 구간만 남긴 클립.
func _slice(src: Animation, from: float, to: float) -> Animation:
	var a: Animation = src.duplicate(true)
	for t in range(a.get_track_count()):
		# 뒤에서부터 지워야 인덱스가 흔들리지 않는다
		for k in range(a.track_get_key_count(t) - 1, -1, -1):
			var tm := a.track_get_key_time(t, k)
			if tm < from or tm > to:
				a.track_remove_key(t, k)
		for k in range(a.track_get_key_count(t)):
			a.track_set_key_time(t, k, a.track_get_key_time(t, k) - from)
	a.length = maxf(0.1, to - from)
	return a

## 전체 키 시간을 배율로 압축/확장.
func _timescale(src: Animation, factor: float) -> Animation:
	var a: Animation = src.duplicate(true)
	for t in range(a.get_track_count()):
		for k in range(a.track_get_key_count(t)):
			a.track_set_key_time(t, k, a.track_get_key_time(t, k) * factor)
	a.length = a.length * factor
	return a

func _own_all(n: Node, owner_node: Node) -> void:
	for c in n.get_children():
		c.owner = owner_node
		_own_all(c, owner_node)
