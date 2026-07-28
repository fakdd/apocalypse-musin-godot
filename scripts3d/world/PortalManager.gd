extends WorldSystem
class_name PortalManager
## 차원의 균열(포털) 생성과 봉인을 담당한다.

## 균열을 무작위 위치에 생성한다.
func build_rifts() -> void:
	_build_rifts()
	# 챕터 보스가 쓰러지면 다음 지역으로 나가는 포탈을 연다
	if not GameManager.chapter_boss_defeated.is_connected(_on_chapter_boss_defeated):
		GameManager.chapter_boss_defeated.connect(_on_chapter_boss_defeated)

	# 이미 보스를 잡은 채로 씬이 만들어지는 경우 — 세이브를 불러온 직후가 그렇다.
	# 보스 랜드마크도 클리어로 저장되므로 보스가 다시 나오지 않고,
	# 따라서 chapter_boss_defeated 도 다시 발신되지 않는다.
	# 여기서 열어주지 않으면 그 챕터에서 나갈 방법이 사라진다.
	if GameManager.chapter_boss_down:
		spawn_chapter_portal()

## ══════════════════════════════════════════════
##  챕터 이동 포탈 (기존 균열과 별개)
## ══════════════════════════════════════════════

func _on_chapter_boss_defeated(_chapter: int) -> void:
	spawn_chapter_portal()

## 방주 앞에 포탈을 연다. 플레이어가 반드시 아는 자리라 헤매지 않는다.
func spawn_chapter_portal() -> void:
	if not get_tree().get_nodes_in_group("chapter_portals").is_empty():
		return
	var pos: Vector3 = world_center() + Vector3(0, 0, -9.0)
	var portal := ChapterPortal.new()
	portal.name = "ChapterPortal"
	world.add_child(portal)
	portal.global_position = pos
	portal.setup(_next_chapter_name())

	if world.hud:
		world.hud.show_banner("◈ 포탈이 열렸다 — %s" % _next_chapter_name())
	SoundManager.play("ultimate", -6.0)

func _next_chapter_name() -> String:
	if ChapterConfig.is_last(GameManager.chapter):
		return "귀환"
	return ChapterConfig.name_of(GameManager.chapter + 1)

## 포탈에 들어갔을 때 — 다음 챕터로 넘어간다.
##
## 씬을 다시 읽어 월드를 새 챕터로 재생성한다. 재시작(PopupUI.restart)과 다른 점:
##   유지 — 레벨/경험치/마석/아이템/특성 (지역을 넘어도 성장은 남는다)
##   초기화 — 랜드마크·퀘스트(새 지역이므로), 보스 재등장 플래그, 방주 HP
func advance_to_next_chapter() -> void:
	if ChapterConfig.is_last(GameManager.chapter):
		# 엔딩 — 다음 회차를 연다. 레벨·강화·업적은 남고 월드 티어가 한 단계 오른다.
		AchievementManager.unlock("ach_ending")
		AchievementManager.bump("chapter")
		SaveGame.start_new_game_plus()
		if world.hud and world.hud.has_method("show_victory"):
			world.hud.show_victory()
		if world.hud:
			world.hud.show_banner("◈ NEW GAME+ %d — 월드 티어 %s"
				% [SaveGame.ng_plus, SaveGame.tier_name()])
		get_tree().create_timer(3.2, true, false, true).timeout.connect(
			func(): get_tree().reload_current_scene())
		return

	if world.hud:
		world.hud.show_loading("%s 로 이동 중…" % _next_chapter_name())

	GameManager.advance_chapter()
	GameManager.base_hp = GameManager.base_max_hp
	GameManager.chapter_boss_down = false

	LandmarkRegistry.reset()      ## 새 지역 = 새 랜드마크·새 퀘스트
	DemoDirector.reset()          ## 지역 보스가 다시 나올 수 있게
	CombatFeel.reset()
	Battlefield.reset()

	# 챕터를 넘는 순간은 반드시 저장한다 —
	# 여기서 껐다 켜면 다시 그 챕터부터 시작할 수 있어야 한다
	SaveGame.save()

	# 로딩 문구가 한 프레임이라도 보이게 한 뒤 씬을 바꾼다
	get_tree().create_timer(0.6, true, false, true).timeout.connect(
		func(): get_tree().reload_current_scene())

## 균열 하나를 봉인한다 (밤을 버텨낼 때마다 호출)
func seal_one() -> bool:
	var rifts := get_tree().get_nodes_in_group("rifts")
	if rifts.is_empty():
		return false
	var r = rifts[randi() % rifts.size()]
	if is_instance_valid(r):
		r.seal()
		return true
	return false

## 낮/밤에 따라 균열 활성 상태를 바꾼다
func set_all_active(active: bool) -> void:
	for rift in get_tree().get_nodes_in_group("rifts"):
		if is_instance_valid(rift):
			rift.set_active(active)

## 차원의 균열 — 개수와 위치가 매번 무작위로 결정된다.
func _build_rifts() -> void:
	var center := world_center()
	var count := 4 + randi() % 4          # 4~7개
	var placed := 0
	var attempts := 0
	var made: Array[Vector3] = []

	while placed < count and attempts < 400:
		attempts += 1
		var pos := Vector3(
			randf_range(4.0, ARENA_W - 4.0), 0,
			randf_range(4.0, ARENA_H - 4.0)
		)
		# 균열 구역(맵 외곽 밴드) 안에만 생성한다
		if zone_of(pos) != ZONE_RIFT:
			continue
		var too_close := false
		for other in made:
			if pos.distance_to(other) < 16.0:
				too_close = true
				break
		if too_close:
			continue
		var rift = load("res://scripts3d/Rift3D.gd").new()
		rift.position = pos
		world.add_child(rift)
		made.append(pos)
		placed += 1
