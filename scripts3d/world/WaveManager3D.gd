extends WorldSystem
class_name WaveManager3D
## 밤 페이즈의 웨이브 진행(전투/정비/종료) 상태 머신.

## DayNightManager 와 상호 참조라 타입을 명시하지 않는다 (GDScript 순환 제약)
var spawner: SpawnManager
var daynight: WorldSystem

## 밤 페이즈 진행 (웨이브 <-> 정비 <-> 종료)
func process_night(delta: float) -> void:
	_process_night(delta)

func _process_night(delta: float) -> void:
	world.night_timer -= delta
	GameManager.phase_timer = world.night_timer

	match GameManager.night_state:
		GameManager.NightState.WAVE:
			world.spawn_timer -= delta
			var interval: float = maxf(0.35, 1.15 - GameManager.wave * 0.06)
			if world.spawn_timer <= 0.0:
				world.spawn_timer = interval
				var count: int = 1 + int(GameManager.wave / 2)
				for i in range(count):
					spawner.spawn_enemy()
			# 웨이브 종료: 시간이 다 되면 정비 시간으로
			if world.night_timer <= 0.0:
				_end_wave()

		GameManager.NightState.REST:
			if world.night_timer <= 0.0:
				begin_wave()

		GameManager.NightState.DONE:
			if world.night_timer <= 0.0:
				daynight.end_night_phase()

## 웨이브 시작
func begin_wave() -> void:
	GameManager.set_night_state(GameManager.NightState.WAVE)
	world.night_timer = DemoDirector.wave_duration()
	GameManager.phase_timer = world.night_timer
	world.spawn_timer = 0.4
	world.hud.show_banner("WAVE %d / %d" % [GameManager.wave_index + 1, GameManager.waves_tonight])
	SoundManager.play("night_start", -6.0)

## 웨이브 종료 -> 정비 시간 또는 밤 종료
func _end_wave() -> void:
	# 남은 적을 정리해 정비 시간을 확보한다
	for e in Battlefield.enemies:
		if is_instance_valid(e) and not e.is_in_group("boss"):
			e.take_damage(99999)

	GameManager.wave_index += 1
	if GameManager.wave_index >= GameManager.waves_tonight:
		GameManager.set_night_state(GameManager.NightState.DONE)
		world.night_timer = 3.0
		world.hud.show_banner("모든 웨이브 격퇴")
		return

	GameManager.set_night_state(GameManager.NightState.REST)
	# 힘들었던 웨이브일수록 숨돌릴 시간을 길게 준다.
	# 매 웨이브 같은 간격이면 계속 밀리는 사람은 계속 밀리고, 여유 있는 사람은 지루하다.
	world.night_timer = maxf(DemoDirector.rest_duration(), _breather())
	GameManager.phase_timer = world.night_timer

	# 체력이 거의 없이 웨이브를 넘긴 순간은 따로 기억시켜 준다
	var pl := Battlefield.live_player()
	if pl and pl.hp / maxf(pl.max_hp, 1.0) <= CombatFeel.pace("moments", "clutch_hp", 0.18):
		CombatFeel.impact("crit")
		world.hud.show_banner(CombatFeel.pace_text("clutch_text", "◈ 아슬아슬했다"))
	else:
		world.hud.show_banner("정비 시간 — N 으로 다음 웨이브 즉시 시작")
	CombatFeel.reset_streak()

## 직전 웨이브에서 잃은 체력에 비례해 정비 시간을 늘린다 (data/pacing.json)
func _breather() -> float:
	var pl := Battlefield.live_player()
	if pl == null:
		return 0.0
	var lost: float = clampf(1.0 - pl.hp / maxf(pl.max_hp, 1.0), 0.0, 1.0)
	# 챕터가 올라갈수록 쉬는 시간이 짧아진다 (tempo.rest)
	return minf((CombatFeel.pace("breather", "base", 3.0)
		+ lost * CombatFeel.pace("breather", "per_hp_lost", 6.0))
		* CombatFeel.tempo("rest", 1.0),
		CombatFeel.pace("breather", "max", 9.0))

## 정비 시간을 건너뛰고 바로 다음 웨이브로 (편의 기능)
func skip_rest() -> void:
	if GameManager.phase == GameManager.Phase.NIGHT and GameManager.night_state == GameManager.NightState.REST:
		world.night_timer = 0.05

## 밤 전체를 건너뛴다 — 방주 HP를 대가로 지불한다 (편의 기능)
func skip_night() -> bool:
	if GameManager.phase != GameManager.Phase.NIGHT:
		return false
	var remaining: int = GameManager.waves_tonight - GameManager.wave_index
	if remaining <= 0:
		return false
	if get_tree().get_nodes_in_group("boss").size() > 0:
		world.hud.show_toast("보스가 남아 있어 밤을 넘길 수 없다", Color(1, 0.6, 0.5))
		return false

	var cost: float = 18.0 * remaining
	if GameManager.base_hp <= cost:
		world.hud.show_toast("방주 HP가 부족하다 (필요 %d)" % int(cost + 1), Color(1, 0.6, 0.5))
		return false

	GameManager.base_hp -= cost
	GameManager.base_hp_changed.emit()
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.take_damage(99999)
	GameManager.wave_index = GameManager.waves_tonight
	GameManager.set_night_state(GameManager.NightState.DONE)
	world.night_timer = 2.0
	world.hud.show_banner("밤을 버텨냈다 — 방주 HP %d 소모" % int(cost))
	return true
