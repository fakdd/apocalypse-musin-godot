extends Node

enum Phase { DAY, NIGHT }

signal phase_changed(new_phase)
signal night_state_changed(state)
signal seal_progress_changed(sealed: int, needed: int)
signal victory
signal resources_changed
signal survivors_changed
signal base_hp_changed
signal game_over(reason)
signal exp_changed(current: int, need: int, level: int)
signal level_up(level: int)

var phase: int = Phase.DAY
var day_count: int = 1
var wave: int = 1
var kill_count: int = 0
var phase_timer: float = 0.0

var resources := {"scrap": 25, "food": 10, "energy": 5}
var survivors_rescued: int = 0
var bonus_max_hp: int = 0

var base_max_hp: float = 150.0
var base_hp: float = 150.0

## ── 레벨 / 경험치 ──
## 탐험(최초 발견)과 랜드마크 클리어가 주 획득처다.
## 캠페인 이벤트의 `level` 조건과 랜드마크 추천 레벨이 이 값을 본다.
var player_level: int = 1
var player_exp: int = 0

const DAY_DURATION := 60.0

## 다음 레벨까지 필요한 경험치
func exp_to_next(lv: int = -1) -> int:
	var l: int = player_level if lv < 0 else lv
	return 40 + (l - 1) * 25

func add_exp(amount: int) -> void:
	if amount <= 0:
		return
	player_exp += amount
	var leveled := false
	while player_exp >= exp_to_next():
		player_exp -= exp_to_next()
		player_level += 1
		leveled = true
		level_up.emit(player_level)
	exp_changed.emit(player_exp, exp_to_next(), player_level)
	if leveled:
		SoundManager.play("rescue", -4.0)

## ── 밤 페이즈 구조 ──
## 밤은 여러 개의 웨이브로 나뉘고, 웨이브 사이에 정비(휴식) 시간이 있다.
enum NightState { WAVE, REST, DONE }
const WAVE_DURATION := 32.0     ## 한 웨이브 지속
const REST_DURATION := 18.0     ## 웨이브 사이 정비 시간
var night_state: int = NightState.WAVE
var wave_index := 0             ## 이번 밤의 몇 번째 웨이브인지 (0부터)
var waves_tonight := 2

## ── 최종 목표: 차원문 봉인 ──
const SEALS_NEEDED := 5
var seals_done := 0
var final_boss_spawned := false
var game_won := false

func waves_for_day(d: int) -> int:
	return clampi(1 + int(d / 2), 1, 5)

func set_night_state(st: int) -> void:
	night_state = st
	night_state_changed.emit(st)

func add_seal() -> void:
	seals_done += 1
	seal_progress_changed.emit(seals_done, SEALS_NEEDED)

var _hitstop_active := false

func add_resource(res_name: String, amount: int) -> void:
	resources[res_name] = resources.get(res_name, 0) + amount
	resources_changed.emit()

func can_afford(cost: Dictionary) -> bool:
	for key in cost:
		if resources.get(key, 0) < cost[key]:
			return false
	return true

func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for key in cost:
		resources[key] -= cost[key]
	resources_changed.emit()
	return true

func rescue_survivor() -> void:
	survivors_rescued += 1
	bonus_max_hp += 5
	survivors_changed.emit()

func start_night() -> void:
	phase = Phase.NIGHT
	wave = day_count
	wave_index = 0
	# 데모 모드면 DemoDirector 의 페이싱을 따른다 (데모 OFF 시 원래 공식)
	waves_tonight = DemoDirector.waves_tonight()
	set_night_state(NightState.WAVE)
	phase_changed.emit(phase)

func start_day() -> void:
	phase = Phase.DAY
	day_count += 1
	base_hp = min(base_max_hp, base_hp + 20.0)
	base_hp_changed.emit()
	phase_changed.emit(phase)

func reset_all() -> void:
	phase = Phase.DAY
	day_count = 1
	wave = 1
	kill_count = 0
	phase_timer = 0.0
	resources = {"scrap": 25, "food": 10, "energy": 5}
	survivors_rescued = 0
	bonus_max_hp = 0
	base_max_hp = 150.0
	base_hp = base_max_hp
	night_state = NightState.WAVE
	wave_index = 0
	seals_done = 0
	final_boss_spawned = false
	game_won = false
	player_level = 1
	player_exp = 0
	base_hp_changed.emit()
	seal_progress_changed.emit(seals_done, SEALS_NEEDED)
	exp_changed.emit(player_exp, exp_to_next(), player_level)

## 히트스톱 — 실제 처리는 CombatFeel 이 담당한다.
## (이전 구현은 진행 중이면 새 요청을 통째로 버려서 연타 시 3타 히트스톱이 사라졌다)
## 기존 호출부 호환을 위해 시그니처는 그대로 둔다. `slow` 는 CombatFeel 이 관리하므로 무시된다.
func hitstop(duration: float, _slow: float = 0.06) -> void:
	CombatFeel.hit_stop(duration)
