extends WorldSystem
class_name EnvironmentManager
## 월드 환경 — 하늘/조명/안개/후처리와 낮밤 전환 연출을 담당한다.

## 현재 챕터의 테마 (ChapterConfig.theme_of).
## 키가 없으면 WorldConfig 의 기존 값으로 물러나므로,
## 테마를 지정하지 않은 챕터는 지금과 똑같이 보인다.
var _theme := {}

func _tc(key: String, fallback: Color) -> Color:
	return _theme.get(key, fallback)

func _tf(key: String, fallback: float) -> float:
	return float(_theme.get(key, fallback))

## 하늘·조명·안개·후처리를 구성한다.
func setup_environment() -> void:
	_theme = ChapterConfig.theme_of(GameManager.chapter)
	_setup_environment()

## 낮<->밤 연출 전환 (2초 트윈)
func tween_time_of_day(to_night: bool) -> void:
	_tween_time_of_day(to_night)

func _setup_environment() -> void:
	world.env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = _tc("day_sky_top", DAY_SKY_TOP)
	mat.sky_horizon_color = _tc("day_sky_horizon", DAY_SKY_HORIZON)
	var gnd: Color = _tc("ground", Color(0.20, 0.16, 0.16))
	mat.ground_bottom_color = gnd.darkened(0.55)
	mat.ground_horizon_color = gnd.darkened(0.15)
	mat.sun_angle_max = 24.0
	sky.sky_material = mat
	e.sky = sky

	_apply_tone(e)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# 다크 판타지 — 주변광을 낮춰 그림자를 깊게 남긴다 (data/graphics.json)
	var df: Dictionary = gfx().get("dark_fantasy", {})
	e.ambient_light_energy = float(df.get("ambient_energy", 0.42))
	e.ambient_light_sky_contribution = float(df.get("ambient_sky", 0.75))

	# ── SSAO: 구석에 짙은 그림자를 넣어 입체감을 만든다 (가장 중요) ──
	e.ssao_enabled = false
	e.ssao_radius = 1.6
	e.ssao_intensity = 3.4
	e.ssao_power = 2.0
	e.ssao_detail = 0.6
	e.ssao_light_affect = 0.15

	# ── SSIL: 간접광 (붉은 지면이 벽에 반사되어 분위기가 살아난다) ──
	e.ssil_enabled = true
	e.ssil_radius = 3.0
	e.ssil_intensity = 0.9

	# ── 부피 안개: 스산한 밤 분위기의 핵심 ──
	var fogc: Color = _tc("fog_color", Color(0.36, 0.27, 0.26))
	e.volumetric_fog_enabled = false
	e.volumetric_fog_density = 0.016
	e.volumetric_fog_albedo = fogc
	e.volumetric_fog_emission = fogc.darkened(0.75)
	e.volumetric_fog_emission_energy = 0.5
	e.volumetric_fog_length = 90.0
	e.volumetric_fog_gi_inject = 0.6

	# 거리 안개 (원경을 뭉개 깊이감)
	e.fog_enabled = true
	e.fog_density = _tf("day_fog", DAY_FOG) 		* float(gfx().get("dark_fantasy", {}).get("fog_density_mult", 1.0))
	e.fog_light_color = fogc
	e.fog_sky_affect = 0.4

	# ── 글로우: 균열/스킬/가로등 빛이 번진다 ──
	e.glow_enabled = true
	e.glow_intensity = 1.0
	e.glow_bloom = 0.28
	e.glow_strength = 1.15
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# 임계값을 낮추면 검기·제단·붉은 눈만 골라 번진다 (밝은 면은 그대로)
	e.glow_hdr_threshold = float(gfx().get("dark_fantasy", {}).get("glow_hdr_threshold", 0.92))

	# ── SDFGI: 실시간 전역조명 (가로등/불빛이 벽에 자연스럽게 반사) ──
	e.sdfgi_enabled = false
	e.sdfgi_use_occlusion = true
	e.sdfgi_bounce_feedback = 0.2
	e.sdfgi_cascades = 4
	e.sdfgi_min_cell_size = 0.25
	e.sdfgi_energy = 0.55

	# ── SSR: 젖은 아스팔트/금속 반사 ──
	e.ssr_enabled = false
	e.ssr_max_steps = 32
	e.ssr_fade_in = 0.15
	e.ssr_fade_out = 2.5

	# 톤매핑 — 어둡고 묵직한 대비
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.05
	e.tonemap_white = 6.0

	# 색보정 (채도를 살짝 낮추고 대비를 올려 실사 느낌)
	e.adjustment_enabled = true
	e.adjustment_brightness = 1.02
	e.adjustment_contrast = 1.14
	e.adjustment_saturation = 0.80

	world.env.environment = e
	world.add_child(world.env)

	world.sun = DirectionalLight3D.new()
	world.sun.rotation_degrees = Vector3(-42, -38, 0)
	world.sun.light_color = _tc("sun", Color(1.0, 0.62, 0.45))
	world.sun.light_energy = float(gfx().get("dark_fantasy", {}).get("sun_energy", 1.15))
	world.sun.light_angular_distance = float(gfx().get("dark_fantasy", {}).get("sun_angular", 1.2))
	world.sun.shadow_enabled = true
	# 맵은 80×80m(대각 약 113m)인데 그림자 거리가 260m 였다.
	# 스플릿 4개가 각각 맵 전체를 다시 그려 5장 기준 드로우콜 2869 중 2449 가
	# 그림자 패스였다. 거리를 맵 크기에 맞추고 스플릿을 2개로 줄이면
	# 눈에 보이는 근거리 그림자는 그대로면서 프레임이 11.4ms → 9.5ms 가 된다.
	world.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	world.sun.directional_shadow_max_distance = 90.0
	world.sun.directional_shadow_blend_splits = true
	world.sun.shadow_bias = 0.02
	world.sun.shadow_normal_bias = 1.1
	world.add_child(world.sun)
	apply_quality(SaveGame.graphics)
	SoundManager.set_bgm(SoundManager.default_bgm_for_phase())

func _tween_time_of_day(to_night: bool) -> void:
	var e: Environment = world.env.environment
	var sky_mat: ProceduralSkyMaterial = e.sky.sky_material
	# 트윈도 같은 테마를 봐야 한다. 상수로 되돌리면 밤이 오는 순간
	# 챕터 색이 사라지고 원래 붉은 폐허 색으로 튄다.
	var fogc: Color = _tc("fog_color", Color(0.36, 0.27, 0.26))
	var sunc: Color = _tc("sun", Color(1.0, 0.72, 0.55))
	var tw := create_tween()
	tw.set_parallel(true)
	if to_night:
		tw.tween_property(world.sun, "light_energy", 0.1, 2.0)
		tw.tween_property(world.sun, "light_color", sunc.darkened(0.35), 2.0)
		tw.tween_property(sky_mat, "sky_top_color", _tc("night_sky_top", NIGHT_SKY_TOP), 2.0)
		tw.tween_property(sky_mat, "sky_horizon_color", _tc("night_sky_horizon", NIGHT_SKY_HORIZON), 2.0)
		tw.tween_property(e, "fog_light_color", fogc.darkened(0.6), 2.0)
		tw.tween_property(e, "fog_density", _tf("night_fog", NIGHT_FOG), 2.0)
		tw.tween_property(e, "ambient_light_energy", 0.16, 2.0)
		tw.tween_property(e, "volumetric_fog_density", 0.034, 2.0)
		tw.tween_property(e, "volumetric_fog_albedo", fogc.darkened(0.45), 2.0)
		tw.tween_property(e, "volumetric_fog_emission", fogc.darkened(0.85), 2.0)
	else:
		tw.tween_property(world.sun, "light_energy", 1.0, 2.0)
		tw.tween_property(world.sun, "light_color", sunc, 2.0)
		tw.tween_property(sky_mat, "sky_top_color", _tc("day_sky_top", DAY_SKY_TOP), 2.0)
		tw.tween_property(sky_mat, "sky_horizon_color", _tc("day_sky_horizon", DAY_SKY_HORIZON), 2.0)
		tw.tween_property(e, "fog_light_color", fogc, 2.0)
		tw.tween_property(e, "fog_density", _tf("day_fog", DAY_FOG), 2.0)
		tw.tween_property(e, "ambient_light_energy", 0.42, 2.0)
		tw.tween_property(e, "volumetric_fog_density", 0.016, 2.0)
		tw.tween_property(e, "volumetric_fog_albedo", fogc, 2.0)
		tw.tween_property(e, "volumetric_fog_emission", fogc.darkened(0.75), 2.0)

	for light in get_tree().get_nodes_in_group("street_lights"):
		if is_instance_valid(light):
			tw.tween_property(light, "light_energy", 3.5 if to_night else 0.0, 2.0)

	for rift in get_tree().get_nodes_in_group("rifts"):
		if is_instance_valid(rift):
			rift.set_active(to_night)

# ══════════════════════════════════════════════
#  그래픽 품질 (data/graphics.json)
# ══════════════════════════════════════════════
const GFX_PATH := "res://data/graphics.json"
static var _gfx: Dictionary = {}

static func gfx() -> Dictionary:
	if not _gfx.is_empty():
		return _gfx
	var f := FileAccess.open(GFX_PATH, FileAccess.READ)
	if f == null:
		_gfx = {"levels": [], "tone": {}}
		return _gfx
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	_gfx = j if typeof(j) == TYPE_DICTIONARY else {"levels": [], "tone": {}}
	return _gfx

static func level_def(i: int) -> Dictionary:
	var lv: Array = gfx().get("levels", [])
	if lv.is_empty():
		return {}
	return lv[clampi(i, 0, lv.size() - 1)]

static func level_name(i: int) -> String:
	return String(level_def(i).get("name", "?"))

static func level_count() -> int:
	return maxi(1, gfx().get("levels", []).size())

## 톤매핑 — 품질과 무관하게 항상 적용된다 (GPU 비용이 사실상 없다).
func _apply_tone(e: Environment) -> void:
	var t: Dictionary = gfx().get("tone", {})
	match String(t.get("mode", "aces")):
		"aces": e.tonemap_mode = Environment.TONE_MAPPER_ACES
		"filmic": e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		_: e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.tonemap_exposure = float(t.get("exposure", 1.0))
	e.tonemap_white = float(t.get("white", 6.0))
	e.adjustment_enabled = true
	e.adjustment_contrast = float(t.get("contrast", 1.0))
	e.adjustment_saturation = float(t.get("saturation", 1.0))
	e.adjustment_brightness = float(t.get("brightness", 1.0))

## 품질 프리셋 적용. 메뉴에서 바꾸면 즉시 반영된다.
func apply_quality(level: int) -> void:
	var d := level_def(level)
	if d.is_empty() or world == null or world.env == null:
		return
	var e: Environment = world.env.environment
	if e == null:
		return

	e.ssao_enabled = bool(d.get("ssao", false))
	if e.ssao_enabled:
		var a: Dictionary = gfx().get("ssao", {})
		e.ssao_radius = float(a.get("radius", 1.6))
		e.ssao_intensity = float(a.get("intensity", 3.4))
		e.ssao_power = float(a.get("power", 2.0))
		e.ssao_detail = float(a.get("detail", 0.6))
		e.ssao_light_affect = float(a.get("light_affect", 0.15))

	e.sdfgi_enabled = bool(d.get("sdfgi", false))
	if e.sdfgi_enabled:
		var g: Dictionary = gfx().get("sdfgi", {})
		e.sdfgi_cascades = int(g.get("cascades", 4))
		e.sdfgi_min_cell_size = float(g.get("min_cell_size", 0.25))
		e.sdfgi_energy = float(g.get("energy", 0.55))
		e.sdfgi_bounce_feedback = float(g.get("bounce_feedback", 0.2))
		e.sdfgi_use_occlusion = true

	e.ssr_enabled = bool(d.get("ssr", false))

	e.volumetric_fog_enabled = bool(d.get("volumetric", false))
	if e.volumetric_fog_enabled:
		var v: Dictionary = gfx().get("volumetric", {})
		e.volumetric_fog_density = float(v.get("density", 0.014))
		e.volumetric_fog_length = float(v.get("length", 90.0))
		e.volumetric_fog_gi_inject = float(v.get("gi_inject", 0.5))
		e.volumetric_fog_emission_energy = float(v.get("emission_energy", 0.5))

	e.glow_enabled = bool(d.get("glow", true))
	e.glow_intensity = float(d.get("glow_intensity", 1.0))
	e.glow_bloom = float(d.get("glow_bloom", 0.28))
	e.glow_strength = float(d.get("glow_strength", 1.15))

	if world.sun:
		world.sun.directional_shadow_max_distance = float(d.get("shadow_distance", 90.0))
		world.sun.directional_shadow_mode = (
			DirectionalLight3D.SHADOW_ORTHOGONAL if int(d.get("shadow_splits", 2)) <= 1
			else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)

	var vp := world.get_viewport()
	if vp:
		vp.positional_shadow_atlas_size = int(d.get("shadow_size", 4096))
		vp.msaa_3d = clampi(int(d.get("msaa", 1)), 0, 3) as Viewport.MSAA
	RenderingServer.directional_soft_shadow_filter_set_quality(
		clampi(int(d.get("soft_shadow", 1)), 0, 4) as RenderingServer.ShadowQuality)

## 개별 효과를 코드에서 바로 껐다 켠다 (그래픽 옵션·디버그용).
##   set_effect("glow", false) / set_effect("ssao", true) …
## 이름: glow / fog / volumetric / ssao / sdfgi / ssr / tonemap
func set_effect(name: String, on: bool) -> void:
	if world == null or world.env == null:
		return
	var e: Environment = world.env.environment
	if e == null:
		return
	match name:
		"glow": e.glow_enabled = on
		"fog": e.fog_enabled = on
		"volumetric": e.volumetric_fog_enabled = on
		"ssao": e.ssao_enabled = on
		"sdfgi": e.sdfgi_enabled = on
		"ssr": e.ssr_enabled = on
		"tonemap":
			if on:
				_apply_tone(e)
			else:
				e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
				e.adjustment_enabled = false

func effect_on(name: String) -> bool:
	if world == null or world.env == null:
		return false
	var e: Environment = world.env.environment
	if e == null:
		return false
	match name:
		"glow": return e.glow_enabled
		"fog": return e.fog_enabled
		"volumetric": return e.volumetric_fog_enabled
		"ssao": return e.ssao_enabled
		"sdfgi": return e.sdfgi_enabled
		"ssr": return e.ssr_enabled
		"tonemap": return e.tonemap_mode != Environment.TONE_MAPPER_LINEAR
	return false

## 현재 화면 상태 한 줄 (디버그 출력용)
func effect_summary() -> String:
	var on := []
	for k in ["tonemap", "glow", "fog", "volumetric", "ssao", "sdfgi", "ssr"]:
		if effect_on(k):
			on.append(k)
	return "%s [%s]" % [level_name(SaveGame.graphics), ", ".join(on)]
