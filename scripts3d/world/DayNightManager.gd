extends WorldSystem
class_name DayNightManager
## 낮/밤 페이즈 전환과 낮 타이머를 담당한다.

## WaveManager3D 와 상호 참조라 타입을 명시하지 않는다 (GDScript 순환 제약)
var wave: WorldSystem
var spawner: SpawnManager
var environment: EnvironmentManager
var portals: PortalManager

## 낮 진행
func process_day(delta: float) -> void:
	_process_day(delta)

## 밤 시작
func start_night_phase() -> void:
	_start_night_phase()

## 밤 종료 -> 아침
func end_night_phase() -> void:
	_end_night_phase()

func _process_day(delta: float) -> void:
	if world.hud.is_tutorial_active():
		return
	world.day_timer -= delta
	GameManager.phase_timer = world.day_timer
	if world.day_timer <= 0:
		_start_night_phase()
		return
	_handle_interactions()

func _handle_interactions() -> void:
	# 아이템 획득은 ItemDrop 이 자체 처리한다. 낮에 따로 상호작용할 것은 없다.
	pass

## 낮을 즉시 끝내고 밤으로 (편의 기능)
func skip_day() -> bool:
	if GameManager.phase != GameManager.Phase.DAY:
		return false
	if world.hud.is_tutorial_active():
		return false
	world.day_timer = 0.05
	world.hud.show_toast("낮을 건너뛴다 — 밤이 온다", Color(0.8, 0.7, 1.0))
	return true

func _start_night_phase() -> void:
	GameManager.start_night()
	SoundManager.play("night_start", -6.0)
	environment.tween_time_of_day(true)

	# 데모 모드에서는 DemoDirector 가 웨이브 종료 시점에 보스를 부르므로
	# 최종 보스 분기를 타지 않는다 (데모의 클라이맥스가 두 번 오면 안 된다)
	if DemoDirector.DEMO_MODE:
		wave.begin_wave()
		return

	# 최종전 조건: 봉인을 모두 모으면 최후의 군주가 강림한다
	if GameManager.seals_done >= GameManager.SEALS_NEEDED and not GameManager.final_boss_spawned:
		GameManager.final_boss_spawned = true
		GameManager.set_night_state(GameManager.NightState.WAVE)
		world.night_timer = 999.0
		GameManager.phase_timer = world.night_timer
		world.spawn_timer = 1.2
		world.hud.show_banner("최후의 외계 군주가 강림한다")
		spawner.spawn_final_boss()
		return

	if GameManager.wave % 5 == 0:
		world.hud.show_banner("🌙 %d일차 밤 — 차원의 환수 강림" % GameManager.day_count)
		spawner.spawn_boss()
	wave.begin_wave()

func _end_night_phase() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()
	# 밤을 버텨내면 균열 하나를 봉인한다 (최종 목표 진행)
	var needed: int = DemoDirector.seals_needed()
	if not GameManager.game_won and GameManager.seals_done < needed:
		GameManager.add_seal()
		portals.seal_one()
		world.hud.show_banner("차원의 균열 봉인  %d / %d" % [GameManager.seals_done, needed])

	GameManager.start_day()
	# 아침은 자연스러운 세이브 지점이다 (밤을 버텨 낸 결과가 확정된 순간)
	SaveGame.save()
	# 랜덤 이벤트 — 무엇이 얼마나 나오는지는 전부 EventManager 가 정한다
	EventManager.roll_daily()
	world.day_timer = DemoDirector.day_duration()
	GameManager.phase_timer = world.day_timer
	world.hud.show_banner("☀ %d일차 아침이 밝았다" % GameManager.day_count)
	SoundManager.play("day_start")
	environment.tween_time_of_day(false)
	if is_instance_valid(world.player):
		world.player.hp = world.player.max_hp
		world.player.hp_changed.emit()
		world.player.global_position = world_center() + Vector3(0, 0, 6.0)
