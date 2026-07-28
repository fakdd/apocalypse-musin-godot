extends Node

const POOL_SIZE := 10
## 전체 효과음 볼륨 (dB). 기본값을 낮게 잡아 시작음이 귀를 때리지 않게 한다.
const MASTER_DB := -14.0

var sounds := {}
var pitches := {}
var players: Array = []
var next_player := 0

func _ready() -> void:
	sounds = {
		"hit": preload("res://assets/audio/hit.ogg"),
		"kill": preload("res://assets/audio/kill.ogg"),
		"ultimate": preload("res://assets/audio/ultimate.ogg"),
		"dash": preload("res://assets/audio/dash.ogg"),
		"player_hurt": preload("res://assets/audio/player_hurt.ogg"),
		"wall_break": preload("res://assets/audio/wall_break.ogg"),
		"turret_fire": preload("res://assets/audio/turret_fire.ogg"),
		"pickup": preload("res://assets/audio/pickup.ogg"),
		"rescue": preload("res://assets/audio/rescue.ogg"),
		"build": preload("res://assets/audio/build.ogg"),
		"error": preload("res://assets/audio/error.ogg"),
		"day_start": preload("res://assets/audio/day_start.ogg"),
		"night_start": preload("res://assets/audio/night_start.ogg"),
		"game_over": preload("res://assets/audio/game_over.ogg"),
	}
	pitches = {
		"error": 0.75,
		"night_start": 0.8,
		"game_over": 0.65,
		"dash": 1.35,
	}
	sounds["footstep"] = [
		preload("res://assets/audio/footstep1.ogg"),
		preload("res://assets/audio/footstep2.ogg"),
		preload("res://assets/audio/footstep3.ogg"),
		preload("res://assets/audio/footstep4.ogg"),
		preload("res://assets/audio/footstep5.ogg"),
	]

	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

	_load_audio_json()
	_build_bgm()
	set_master_db(MASTER_DB)
	# 페이즈가 바뀌면 기본 BGM 도 따라간다 (랜드마크 안이면 랜드마크 곡이 우선)
	GameManager.phase_changed.connect(func(_p):
		if LandmarkRegistry.current == null:
			set_bgm(default_bgm_for_phase()))

## ══════════════════════════════════════════════
##  BGM — 랜드마크/페이즈에 따른 배경음 전환 (크로스페이드)
## ══════════════════════════════════════════════
##
## ⚠ 현재 프로젝트에 음악 파일이 없다. 트랙을 등록하지 않으면 이 시스템은
##   **조용히 아무 것도 하지 않는다**(no-op). 아래 BGM_TRACKS 의 경로에 파일을 넣으면
##   코드 수정 없이 바로 동작한다.
##
## 트랙 id 는 LandmarkData.bgm / default_bgm_for_phase() 에서 쓰인다.
const BGM_TRACKS := {
	"day":     "res://assets/music/day.ogg",
	"night":   "res://assets/music/night.ogg",
	"explore": "res://assets/music/explore.ogg",
	"tense":   "res://assets/music/tense.ogg",
	"danger":  "res://assets/music/danger.ogg",
	"boss":    "res://assets/music/boss.ogg",
}
## data/audio.json — 사운드/BGM 목록. 여기 키를 늘리면 코드 수정 없이 늘어난다.
const AUDIO_PATH := "res://data/audio.json"
var audio_defs: Dictionary = {}

func _load_audio_json() -> void:
	var f := FileAccess.open(AUDIO_PATH, FileAccess.READ)
	if f == null:
		return
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(j) != TYPE_DICTIONARY:
		return
	audio_defs = j
	# 없는 파일은 조용히 건너뛴다 — 음원을 나중에 넣어도 된다
	for key in j.get("sfx", {}):
		var path := String(j["sfx"][key])
		if ResourceLoader.exists(path):
			sounds[key] = load(path)
	for key in j.get("pitch", {}):
		pitches[key] = float(j["pitch"][key])

## 챕터에 맞는 배경 트랙 id (없으면 빈 문자열 → 기존 동작 유지)
func chapter_bgm(chapter: int) -> String:
	return String(audio_defs.get("chapter_bgm", {}).get(str(chapter), ""))

const BGM_DB := -18.0
const BGM_FADE := 1.4

var _bgm_a: AudioStreamPlayer
var _bgm_b: AudioStreamPlayer
var _bgm_active: AudioStreamPlayer     ## 지금 소리를 내고 있는 쪽
var _bgm_current := ""
var _bgm_tween: Tween

func _build_bgm() -> void:
	_bgm_a = AudioStreamPlayer.new()
	_bgm_b = AudioStreamPlayer.new()
	for p in [_bgm_a, _bgm_b]:
		p.volume_db = -80.0
		p.bus = "Master"
		add_child(p)
	_bgm_active = _bgm_a

## 현재 페이즈의 기본 BGM id (랜드마크를 벗어날 때 돌아갈 곳)
func default_bgm_for_phase() -> String:
	if GameManager.phase == GameManager.Phase.NIGHT:
		return "night"
	# 낮에는 챕터 테마곡. 정의가 없으면 예전처럼 day.
	var c := chapter_bgm(GameManager.chapter)
	return c if c != "" else "day"

## BGM 을 전환한다. 같은 트랙이면 아무것도 하지 않는다.
## 트랙 파일이 없으면 조용히 무시한다 (음악 에셋이 없어도 게임이 정상 동작해야 한다).
func set_bgm(track_id: String) -> void:
	if track_id == _bgm_current:
		return
	var path: String = String(audio_defs.get("bgm", {}).get(track_id, ""))
	if path == "":
		path = BGM_TRACKS.get(track_id, "")
	if path == "" or not ResourceLoader.exists(path):
		_bgm_current = track_id    ## 요청은 기억해 둔다 (파일이 추가되면 다음 전환부터 동작)
		return

	_bgm_current = track_id
	var stream = load(path)
	if stream == null:
		return

	# 쉬고 있는 쪽에 새 트랙을 올려 페이드 인하고, 기존 쪽은 페이드 아웃한다
	var incoming: AudioStreamPlayer = _bgm_b if _bgm_active == _bgm_a else _bgm_a
	var outgoing: AudioStreamPlayer = _bgm_active
	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()

	if _bgm_tween and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween().set_parallel(true).set_ignore_time_scale(true)
	_bgm_tween.tween_property(incoming, "volume_db", BGM_DB, BGM_FADE)
	_bgm_tween.tween_property(outgoing, "volume_db", -80.0, BGM_FADE)
	_bgm_tween.chain().tween_callback(outgoing.stop)
	_bgm_active = incoming

func current_bgm() -> String:
	return _bgm_current

## 마스터 버스 상태는 두 가지 이유로 죽는다 — 일시정지, 볼륨 0%.
## 둘을 따로 기억하고 한 곳에서만 버스에 반영한다.
## (예전엔 set_paused 가 mute 를 직접 껐다 켜서, 볼륨 0% 로 둔 채 일시정지를
##  풀면 소리가 되살아났다.)
const MIN_DB := -30.0        ## 메뉴의 0% 지점. 이 아래는 무음으로 본다.
const MUTE_DB := -80.0

var _paused := false
var _volume_db := 0.0

func set_paused(on: bool) -> void:
	if on == _paused:
		return
	_paused = on
	_apply_bus()

## 마스터 버스 볼륨 조절 (설정 메뉴에서 재사용 가능)
## 0%(MIN_DB 이하)면 완전 무음 — -30dB 는 작게 들릴 뿐 무음이 아니다.
func set_master_db(db: float) -> void:
	_volume_db = clampf(db, MIN_DB, 6.0)
	_apply_bus()

func is_muted() -> bool:
	return _paused or _volume_db <= MIN_DB + 0.01

func _apply_bus() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	var mute := is_muted()
	AudioServer.set_bus_mute(bus, mute)
	AudioServer.set_bus_volume_db(bus, MUTE_DB if mute else _volume_db)

## 같은 효과음이 한 프레임에 여러 번 겹치면 진폭이 합쳐져 찢어지는 소리가 난다.
## 프레임당 같은 이름의 재생을 1회로 제한한다 (타격음이 가장 큰 수혜자).
const SAME_SOUND_GAP := 0.04
var _last_played := {}

func play(name: String, volume_db: float = 0.0, pitch_variance: float = 0.05) -> void:
	play_pitched(name, volume_db, 1.0, pitch_variance)

## 피치 배율을 지정해 재생한다. 타격음의 콤보 단계별 음높이 변화에 쓴다.
##   pitch_mult: 사운드 고유 피치에 곱해지는 배율 (1.0 = 원본)
func play_pitched(name: String, volume_db: float = 0.0, pitch_mult: float = 1.0,
		pitch_variance: float = 0.05) -> void:
	if not sounds.has(name):
		return
	# 중복 재생 차단 — 같은 소리가 너무 촘촘히 겹치는 것을 막는다
	var now := Time.get_ticks_msec() / 1000.0
	if _last_played.get(name, -99.0) > now - SAME_SOUND_GAP:
		return
	_last_played[name] = now

	var stream = sounds[name]
	if stream is Array:
		stream = stream[randi() % stream.size()]
	var p: AudioStreamPlayer = players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.05,
		pitches.get(name, 1.0) * pitch_mult + randf_range(-pitch_variance, pitch_variance))
	p.play()

## 지연 재생 — "베었다 → 죽었다" 처럼 두 사건으로 들려야 하는 소리에 쓴다.
## 히트스톱(time_scale 0.03) 중에도 실시간으로 흘러야 하므로 ignore_time_scale 타이머를 쓴다.
func play_delayed(name: String, delay: float, volume_db: float = 0.0,
		pitch_mult: float = 1.0, pitch_variance: float = 0.05) -> void:
	if not sounds.has(name):
		return
	await get_tree().create_timer(delay, true, false, true).timeout
	play_pitched(name, volume_db, pitch_mult, pitch_variance)
