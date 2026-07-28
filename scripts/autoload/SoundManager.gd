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
	_scan_sfx_folder()
	_scan_bgm_folder()
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

# ══════════════════════════════════════════════
#  폴더 자동 스캔
#  파일을 넣기만 하면 잡힌다 — 코드도 JSON 도 고치지 않는다.
#  우선순위: 폴더 스캔 > data/audio.json > 코드 preload
# ══════════════════════════════════════════════
const SFX_DIR := "res://assets/audio"
## 음원을 어디에 두든 잡히게 두 곳을 본다.
## (기존 플레이스홀더는 assets/audio/bgm, 새로 받은 음원은 assets/music 에 두는 경우가 많다)
const BGM_DIRS := ["res://assets/music", "res://assets/audio/bgm"]
const AUDIO_EXT := ["ogg", "wav", "mp3"]

## BGM 트랙 키 → 파일명에 들어 있으면 그 트랙으로 보는 낱말들.
## 앞쪽에 있을수록 먼저 잡힌다.
## 낱말은 소문자로 비교한다. 앞쪽일수록 먼저 잡힌다.
const BGM_HINTS := {
	"boss":    ["bgm08boss1", "bgm08boss2", "boss", "final", "lord", "epic", "raid"],
	"danger":  ["bgm02evil", "bgm14chase", "danger", "chase", "panic", "horde", "alarm"],
	"tense":   ["bgm12dungeon1", "bgm13dungeon2", "tense", "dungeon", "combat", "fight", "wave"],
	"night":   ["bgm07battle1", "bgm07battle2", "bgm07battle3", "night", "battle", "dark", "moon"],
	"explore": ["bgm06adventure1", "bgm03prairie", "bgm10desert1",
				"explore", "adventure", "prairie", "journey", "field", "travel"],
	"day":     ["bgm04town1", "bgm04town0", "bgm04town2", "bgm01hero",
				"day", "town", "hero", "peace", "calm", "village", "main", "theme"],
}

## 징글/효과음 파일명 → 기존 사운드 키.
## 파일명이 제각각이라 이름만으로는 못 잡히는 것들을 여기서 이어 준다.
## 한 파일이 여러 키를 맡아도 된다.
## Escalona Music 팩은 파일명이 MS/BGM + 번호 + 이름 꼴이다.
## 접미사(NL/L, 1/2)가 붙어도 잡히도록 앞부분만 비교한다 (_alias_key 참고).
const SFX_ALIASES := {
	"ms01triumph":  ["ultimate"],
	"ms02gameover": ["game_over"],
	"ms03discovery":["pickup"],
	"ms04":         ["build"],
	"ms05":         ["rescue"],
	"ms06":         ["day_start"],
	"ms07":         ["night_start"],
	"ms08levelup":  ["level_up"],
	"ms09":         ["error"],
}

## res:// 를 뒤져 오디오 파일 경로를 모은다.
## 내보낸 빌드에서는 원본이 .import 로만 보이므로 그 접미사를 떼고 확인한다.
func _scan_dir(dir_path: String) -> Dictionary:
	var out := {}
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var fn := d.get_next()
	var scan_guard := 0
	while fn != "" and scan_guard < 4000:
		scan_guard += 1
		if not d.current_is_dir():
			var name := fn
			if name.ends_with(".import"):
				name = name.trim_suffix(".import")
			var ext := name.get_extension().to_lower()
			if ext in AUDIO_EXT:
				var full := dir_path.path_join(name)
				if ResourceLoader.exists(full):
					out[name.get_basename()] = full
		fn = d.get_next()
	d.list_dir_end()
	return out

## 효과음 — 파일명(확장자 제외)이 그대로 키가 된다.
func _scan_sfx_folder() -> void:
	var found := _scan_dir(SFX_DIR)
	var added := 0
	for key in found:
		if sounds.has(key):
			continue          ## 이미 등록된 키는 덮어쓰지 않는다 (수동 지정 우선)
		var st = _safe_load(found[key])
		if st != null:
			sounds[key] = st
			added += 1
	# 별칭 — 파일명이 기존 키와 다를 때 이어 준다 (실제 파일이 있을 때만)
	var aliased := 0
	for base in found:
		var lower: String = String(base).to_lower()
		var key := _alias_key(lower)
		if key == "":
			continue
		var st2 = _safe_load(found[base])
		if st2 == null:
			continue
		for key2 in SFX_ALIASES[key]:
			sounds[key2] = st2     ## 별칭은 기존 키를 덮어쓴다 (더 좋은 음원이므로)
			aliased += 1
	if added > 0 or aliased > 0:
		print("[Sound] SFX %d개 자동 등록 · 별칭 %d개 (폴더 %d개)"
			% [added, aliased, found.size()])

## BGM — 파일명 낱말로 트랙 키를 추정하고, 빈 트랙은 아무 곡으로나 채운다.
func _scan_bgm_folder() -> void:
	var found := {}
	for dir_path in BGM_DIRS:
		var one := _scan_dir(dir_path)
		for k in one:
			if not found.has(k):        ## 앞 폴더가 우선 (assets/music 이 이긴다)
				found[k] = one[k]
	if found.is_empty():
		return
	var mapped := {}
	var used := {}
	for track in BGM_HINTS:
		for hint in BGM_HINTS[track]:
			for base in found:
				if used.has(base):
					continue
				if base.to_lower().find(hint.to_lower()) >= 0:
					mapped[track] = found[base]
					used[base] = true
					break
			if mapped.has(track):
				break

	# 낱말로 못 맞춘 트랙은 남은 곡 → 그래도 없으면 아무 곡이나.
	# 무음보다는 겹쳐 쓰는 편이 낫다.
	var leftovers := []
	for base in found:
		if not used.has(base):
			leftovers.append(found[base])
	var any_track: String = found[found.keys()[0]]
	for track in BGM_HINTS:
		if mapped.has(track):
			continue
		mapped[track] = leftovers.pop_back() if not leftovers.is_empty() else any_track

	# audio.json / BGM_TRACKS 보다 우선한다 — 실제 파일이 있는 쪽이 이긴다
	if not audio_defs.has("bgm"):
		audio_defs["bgm"] = {}
	for track in mapped:
		audio_defs["bgm"][track] = mapped[track]
	print("[Sound] BGM %d곡 스캔 → %s" % [found.size(), str(mapped.keys())])

## 로드 실패해도 게임이 죽지 않게 한다
func _safe_load(path: String):
	if path == "" or not ResourceLoader.exists(path):
		return null
	var r = ResourceLoader.load(path, "AudioStream", ResourceLoader.CACHE_MODE_REUSE)
	if r == null or not (r is AudioStream):
		push_warning("[Sound] 로드 실패: %s" % path)
		return null
	return r

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
		var st = _safe_load(String(j["sfx"][key]))
		if st != null:
			sounds[key] = st
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
	if c != "" and String(audio_defs.get("bgm", {}).get(c, "")) != "":
		return c
	return "day"

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
	var stream = _safe_load(path)
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
	var target_db := BGM_DB + SaveGame.bgm_db
	if SaveGame.bgm_db <= MIN_DB + 0.01:
		target_db = MUTE_DB
	_bgm_tween.tween_property(incoming, "volume_db", target_db, BGM_FADE)
	_bgm_tween.tween_property(outgoing, "volume_db", -80.0, BGM_FADE)
	_bgm_tween.chain().tween_callback(outgoing.stop)
	_bgm_active = incoming

func current_bgm() -> String:
	return _bgm_current

## 파일명이 별칭으로 시작하면 그 별칭을 돌려준다 (접미사 무시).
##   "MS08levelup1NL" → "ms08levelup"
func _alias_key(lower: String) -> String:
	for k in SFX_ALIASES:
		if lower.begins_with(String(k)):
			return String(k)
	return ""

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

## 배경음만 조절한다. 전용 버스가 없어도 BGM 플레이어 두 대에 직접 건다.
func set_bgm_db(db: float) -> void:
	SaveGame.bgm_db = clampf(db, MIN_DB, 6.0)
	_apply_bgm_volume()

func _apply_bgm_volume() -> void:
	var v := BGM_DB + SaveGame.bgm_db
	if SaveGame.bgm_db <= MIN_DB + 0.01:
		v = MUTE_DB
	for pl in [_bgm_a, _bgm_b]:
		if pl != null and is_instance_valid(pl) and pl.playing:
			pl.volume_db = v

## 효과음만 조절한다. play() 계열이 이 값을 더해 쓴다.
func set_sfx_db(db: float) -> void:
	SaveGame.sfx_db = clampf(db, MIN_DB, 6.0)

func sfx_offset() -> float:
	return MUTE_DB if SaveGame.sfx_db <= MIN_DB + 0.01 else SaveGame.sfx_db

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
	volume_db += sfx_offset()      ## 설정의 효과음 볼륨
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
