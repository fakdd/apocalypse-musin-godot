extends Node
## 타격감 디렉터 — Engine.time_scale 과 화면 전체 연출의 단일 권한자.
##
## 이전 문제:
##   GameManager.hitstop() 이 `if _hitstop_active: return` 으로 **연타 중 두 번째 히트를 통째로 버렸다.**
##   그래서 콤보를 빠르게 이을 때 정작 가장 강한 3타의 히트스톱이 사라지는 일이 잦았다.
##
## 개선:
##   무게(weight) 기반으로 요청을 받고, 더 강한 요청이 오면 **덮어쓰기(escalate)** 한다.
##   time_scale 복원은 항상 한 곳에서만 하므로 슬로모션과 히트스톱이 서로 꼬이지 않는다.

## 히트스톱 강도 프리셋 — 이름이 있으면 밸런스 조정이 쉽다
const HS_LIGHT := 0.035      ## 평타 명중
const HS_MEDIUM := 0.06      ## 콤보 2타
const HS_HEAVY := 0.095      ## 콤보 3타(피니셔)
const HS_KILL := 0.11        ## 처치
const HS_PARRY := 0.13       ## 반로환동 성공
const HS_ULT := 0.2          ## 만천화우

const HS_TIME_SCALE := 0.035     ## 히트스톱 중 시간 배율 (거의 정지 = 프레임이 "박히는" 느낌)
const SLOWMO_SCALE := 0.28       ## 피니시 블로우 슬로모션 배율

var _stop_weight := 0.0          ## 현재 진행 중인 히트스톱의 강도
var _stop_remain := 0.0          ## 남은 실시간(초)
var _slowmo_remain := 0.0
var _slowmo_scale := 1.0

var _flash_layer: CanvasLayer
var _flash_rect: ColorRect
var _flash_tween: Tween

func _ready() -> void:
	# 메뉴가 트리를 멈춰도 시간배율 복원은 돌아야 한다.
	# 이게 없으면 히트스톱 중에 일시정지 → 해제 시 화면이 언 채로 남는다.
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_mode = Node.PROCESS_MODE_ALWAYS   ## time_scale 0.03 에서도 복원 타이머가 돌아야 한다
	process_priority = 1000                    ## 다른 노드가 끝난 뒤 시간 복원
	_build_flash_overlay()

func _build_flash_overlay() -> void:
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 90                    ## HUD(10) 보다 위, 하지만 최상단은 아님
	add_child(_flash_layer)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(1, 1, 1, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_layer.add_child(_flash_rect)

## 실시간(time_scale 무관) 기준으로 타이머를 줄여야 하므로 델타를 보정한다
func _process(delta: float) -> void:
	var ts: float = maxf(Engine.time_scale, 0.0001)
	var real_delta: float = delta / ts

	# 두 타이머를 항상 함께 흘린다.
	# elif 로 두면 히트스톱이 도는 동안 슬로모션 타이머가 멈춰,
	# 콤보 피니시(히트스톱) 직후 보스 페이즈(슬로모션)가 통째로 씹히거나
	# 반대로 슬로모션이 예상보다 길게 남는 일이 생겼다.
	var was_stop := _stop_remain > 0.0
	var was_slow := _slowmo_remain > 0.0
	if _stop_remain > 0.0:
		_stop_remain -= real_delta
		if _stop_remain <= 0.0:
			_stop_remain = 0.0
			_stop_weight = 0.0
	if _slowmo_remain > 0.0:
		_slowmo_remain -= real_delta
		if _slowmo_remain <= 0.0:
			_slowmo_remain = 0.0
			_slowmo_scale = 1.0
	if was_stop != (_stop_remain > 0.0) or was_slow != (_slowmo_remain > 0.0):
		_apply_time_scale()

	# ── 안전장치 ──
	# 어떤 이유로든 타이머가 다 끝났는데 배율이 남아 있으면 되돌린다.
	# (연출 중에 호출부가 예외로 중단되면 배율만 남아 게임이 언 것처럼 보인다)
	if _stop_remain <= 0.0 and _slowmo_remain <= 0.0 and Engine.time_scale != 1.0:
		Engine.time_scale = 1.0
	# 0 이하로 떨어지면 물리·타이머가 전부 멈춰 영구 프리즈가 된다
	if Engine.time_scale <= 0.001:
		push_warning("[Feel] time_scale 이 0 에 붙어 복구했다")
		_stop_remain = 0.0
		_slowmo_remain = 0.0
		_slowmo_scale = 1.0
		Engine.time_scale = 1.0

## 히트스톱이 슬로모션보다 우선한다 (짧고 강한 것이 먼저)
func _apply_time_scale() -> void:
	if _stop_remain > 0.0:
		Engine.time_scale = HS_TIME_SCALE
	elif _slowmo_remain > 0.0:
		Engine.time_scale = _slowmo_scale
	else:
		Engine.time_scale = 1.0

## 히트스톱 요청. 같은/약한 요청은 무시하고, 강한 요청은 즉시 덮어쓴다.
func hit_stop(weight: float) -> void:
	if weight <= 0.0:
		return
	weight = minf(weight, 0.4)      ## 상한 — 잘못된 값이 들어와도 오래 멈추지 않는다
	# 진행 중인 것보다 약하면서 아직 시간이 남아 있으면 새로 걸지 않는다
	if weight <= _stop_weight and _stop_remain > 0.0:
		return
	_stop_weight = weight
	_stop_remain = weight
	_apply_time_scale()

## 피니시 블로우 슬로모션 (보스 처치 / 웨이브 마지막 적)
## 피니시 블로우 슬로모션 (보스 처치 / 웨이브 마지막 적 / 페이즈 전환)
## 남은 시간이 더 길어도 **더 강한(느린) 요청은 받는다**.
## 이전에는 duration 만 비교해서, 긴 약한 슬로모션이 도는 동안
## 짧고 강한 보스 페이즈 연출이 통째로 버려졌다.
func slow_motion(duration: float, scale: float = SLOWMO_SCALE) -> void:
	if duration <= 0.0:
		return
	var s2 := clampf(scale, 0.05, 1.0)
	var stronger := s2 < _slowmo_scale - 0.001
	if duration <= _slowmo_remain and not stronger:
		return
	_slowmo_remain = maxf(_slowmo_remain, duration)
	if stronger or _slowmo_scale >= 1.0:
		_slowmo_scale = s2
	_apply_time_scale()

## 화면 전체 플래시 — 크리티컬(콤보 피니셔·처치·궁극기) 순간의 "번쩍"
##   peak: 최대 알파, hold: 최대 유지 시간, fade: 사라지는 시간
func screen_flash(color: Color, peak: float = 0.22, hold: float = 0.02, fade: float = 0.16) -> void:
	if _flash_rect == null:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_rect.color = Color(color.r, color.g, color.b, peak)
	# 히트스톱 중에도 눈에 보이게 실시간(ignore_time_scale)으로 재생한다
	_flash_tween = create_tween().set_ignore_time_scale(true)
	if hold > 0.0:
		_flash_tween.tween_interval(hold)
	_flash_tween.tween_property(_flash_rect, "color:a", 0.0, fade).set_trans(Tween.TRANS_QUAD)

## 카메라 흔들림을 플레이어 카메라에 전달한다 (방향성 킥 포함)
func shake(mag: float, dur: float, dir: Vector3 = Vector3.ZERO) -> void:
	var p := Battlefield.player
	if p and is_instance_valid(p) and p.has_method("shake_from"):
		p.shake_from(mag, dur, dir)

## 씬 재시작 시 시간 배율이 남아 있지 않게 정리
# ══════════════════════════════════════════════
#  프리셋 (data/feel.json)
# ══════════════════════════════════════════════
## 코드에 흩어져 있던 수치를 이름으로 부른다. JSON 만 고치면 전 전투에 걸린다.
## 정의가 없는 이름은 아무것도 하지 않는다 (호출부가 죽지 않게).
const FEEL_PATH := "res://data/feel.json"
var _feel: Dictionary = {}

func feel() -> Dictionary:
	if not _feel.is_empty():
		return _feel
	var f := FileAccess.open(FEEL_PATH, FileAccess.READ)
	if f == null:
		_feel = {"hitstop": {}, "shake": {}, "camera": {}, "slowmo": {}, "flash": {}, "sound": {}, "ui": {}}
		return _feel
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	_feel = j if typeof(j) == TYPE_DICTIONARY else {}
	return _feel

func num(section: String, key: String, fallback: float) -> float:
	var sec: Dictionary = feel().get(section, {})
	return float(sec.get(key, fallback)) if sec.has(key) else fallback

## 한 번에 히트스톱 + 흔들림 + 슬로모 + 플래시 + 사운드 레이어를 건다.
## 이름 하나로 연출 한 벌이 나오므로 호출부가 짧아지고 톤이 일정해진다.
func impact(name: String, dir: Vector3 = Vector3.ZERO) -> void:
	var hs: Dictionary = feel().get("hitstop", {})
	if hs.has(name):
		hit_stop(float(hs[name]))

	var sk: Dictionary = feel().get("shake", {})
	if sk.has(name):
		var v: Array = sk[name]
		if v.size() >= 2:
			shake(float(v[0]), float(v[1]), dir)

	var sm: Dictionary = feel().get("slowmo", {})
	if sm.has(name):
		var v2: Array = sm[name]
		if v2.size() >= 2:
			slow_motion(float(v2[0]), float(v2[1]))

	var fl: Dictionary = feel().get("flash", {})
	if fl.has(name):
		var v3: Array = fl[name]
		if v3.size() >= 6:
			screen_flash(Color(float(v3[0]), float(v3[1]), float(v3[2])),
				float(v3[3]), float(v3[4]), float(v3[5]))

	play_layers(name)
	camera_punch(name)

## 사운드 겹치기 — 한 타격에 2~3겹을 쌓아 두께를 만든다.
func play_layers(name: String) -> void:
	var layers: Dictionary = feel().get("sound", {}).get("layers", {})
	if not layers.has(name):
		return
	for row in layers[name]:
		if typeof(row) != TYPE_ARRAY or row.size() < 4:
			continue
		var key := String(row[0])
		var vol := float(row[1])
		var pit := float(row[2])
		var delay := float(row[3])
		if delay <= 0.0:
			SoundManager.play_pitched(key, vol, pit)
		else:
			SoundManager.play_delayed(key, delay, vol)

## 타격 순간 카메라가 살짝 파고든다 (FOV 를 순간적으로 좁힌다).
func camera_punch(name: String) -> void:
	var key := "punch_" + name
	var cam: Dictionary = feel().get("camera", {})
	if not cam.has(key):
		return
	var p := Battlefield.player
	if p and is_instance_valid(p) and p.has_method("fov_punch"):
		p.fov_punch(float(cam[key]))

# ══════════════════════════════════════════════
#  리듬 · 순간 (data/pacing.json)
# ══════════════════════════════════════════════
const PACING_PATH := "res://data/pacing.json"
var _pacing: Dictionary = {}

func pacing() -> Dictionary:
	if not _pacing.is_empty():
		return _pacing
	var f := FileAccess.open(PACING_PATH, FileAccess.READ)
	if f == null:
		_pacing = {"breather": {}, "moments": {}, "drop_tease": {}, "legendary": {}}
		return _pacing
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	_pacing = j if typeof(j) == TYPE_DICTIONARY else {}
	return _pacing

func pace(section: String, key: String, fallback: float) -> float:
	return float(pacing().get(section, {}).get(key, fallback))

func pace_text(key: String, fallback: String) -> String:
	return String(pacing().get("moments", {}).get(key, fallback))

## 임의의 [r,g,b,peak,hold,fade] 배열을 플래시로 재생한다.
func flash_array(section: String, key: String) -> void:
	var v = pacing().get(section, {}).get(key, null)
	if typeof(v) != TYPE_ARRAY or v.size() < 6:
		return
	screen_flash(Color(float(v[0]), float(v[1]), float(v[2])),
		float(v[3]), float(v[4]), float(v[5]))

## 챕터 진행도에 따라 보간된 템포 값.
## pacing.json 의 tempo 는 {"1":a,"4":b,"7":c} 형태의 구간점이다.
func tempo(key: String, fallback: float) -> float:
	var t = pacing().get("tempo", {}).get(key, null)
	if typeof(t) != TYPE_DICTIONARY:
		return fallback
	var ch := float(GameManager.chapter)
	var keys := []
	for k in t:
		keys.append(float(k))
	keys.sort()
	if keys.is_empty():
		return fallback
	if ch <= keys[0]:
		return float(t[str(int(keys[0]))])
	for i in range(keys.size() - 1):
		var a: float = keys[i]
		var b: float = keys[i + 1]
		if ch <= b:
			var u: float = (ch - a) / maxf(b - a, 0.001)
			return lerpf(float(t[str(int(a))]), float(t[str(int(b))]), u)
	return float(t[str(int(keys[keys.size() - 1]))])

func tempo_num(key: String, fallback: float) -> float:
	return float(pacing().get("tempo", {}).get(key, fallback))

# ── 연속 처치 ──
var _streak := 0
var _streak_time := 0.0

func note_kill() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var win := pace("moments", "streak_window", 6.0)
	_streak = (_streak + 1) if (now - _streak_time) <= win else 1
	_streak_time = now
	var need := int(pace("moments", "streak_kills", 8))
	if need > 0 and _streak > 0 and _streak % need == 0:
		impact("crit")
		var p := Battlefield.player
		var world = p.get_tree().current_scene if p and is_instance_valid(p) else null
		if world and world.get("hud") != null:
			world.hud.show_banner(pace_text("streak_text", "◈ %d 연속 처치") % _streak)

func reset_streak() -> void:
	_streak = 0

func reset() -> void:
	_stop_weight = 0.0
	_stop_remain = 0.0
	_slowmo_remain = 0.0
	_slowmo_scale = 1.0
	Engine.time_scale = 1.0
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	if _flash_rect:
		_flash_rect.color = Color(1, 1, 1, 0.0)
