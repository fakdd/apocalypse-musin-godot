extends WorldSystem
class_name EnvironmentManager
## 월드 환경 — 하늘/조명/안개/후처리와 낮밤 전환 연출을 담당한다.

## 하늘·조명·안개·후처리를 구성한다.
func setup_environment() -> void:
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
	mat.sky_top_color = DAY_SKY_TOP
	mat.sky_horizon_color = DAY_SKY_HORIZON
	mat.ground_bottom_color = Color(0.08, 0.04, 0.04)
	mat.ground_horizon_color = Color(0.22, 0.16, 0.15)
	mat.sun_angle_max = 24.0
	sky.sky_material = mat
	e.sky = sky

	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.42
	e.ambient_light_sky_contribution = 0.75

	# ── SSAO: 구석에 짙은 그림자를 넣어 입체감을 만든다 (가장 중요) ──
	e.ssao_enabled = true
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
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.016
	e.volumetric_fog_albedo = Color(0.38, 0.30, 0.30)
	e.volumetric_fog_emission = Color(0.09, 0.05, 0.05)
	e.volumetric_fog_emission_energy = 0.5
	e.volumetric_fog_length = 90.0
	e.volumetric_fog_gi_inject = 0.6

	# 거리 안개 (원경을 뭉개 깊이감)
	e.fog_enabled = true
	e.fog_density = DAY_FOG
	e.fog_light_color = Color(0.36, 0.27, 0.26)
	e.fog_sky_affect = 0.4

	# ── 글로우: 균열/스킬/가로등 빛이 번진다 ──
	e.glow_enabled = true
	e.glow_intensity = 1.0
	e.glow_bloom = 0.28
	e.glow_strength = 1.15
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.glow_hdr_threshold = 0.92

	# ── SDFGI: 실시간 전역조명 (가로등/불빛이 벽에 자연스럽게 반사) ──
	e.sdfgi_enabled = true
	e.sdfgi_use_occlusion = true
	e.sdfgi_bounce_feedback = 0.2
	e.sdfgi_cascades = 4
	e.sdfgi_min_cell_size = 0.25
	e.sdfgi_energy = 0.55

	# ── SSR: 젖은 아스팔트/금속 반사 ──
	e.ssr_enabled = true
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
	world.sun.light_color = Color(1.0, 0.62, 0.45)
	world.sun.light_energy = 1.15
	world.sun.light_angular_distance = 1.2
	world.sun.shadow_enabled = true
	world.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	world.sun.directional_shadow_max_distance = 260.0
	world.sun.directional_shadow_blend_splits = true
	world.sun.shadow_bias = 0.02
	world.sun.shadow_normal_bias = 1.1
	world.add_child(world.sun)

func _tween_time_of_day(to_night: bool) -> void:
	var e: Environment = world.env.environment
	var sky_mat: ProceduralSkyMaterial = e.sky.sky_material
	var tw := create_tween()
	tw.set_parallel(true)
	if to_night:
		tw.tween_property(world.sun, "light_energy", 0.1, 2.0)
		tw.tween_property(world.sun, "light_color", Color(0.85, 0.3, 0.45), 2.0)
		tw.tween_property(sky_mat, "sky_top_color", NIGHT_SKY_TOP, 2.0)
		tw.tween_property(sky_mat, "sky_horizon_color", NIGHT_SKY_HORIZON, 2.0)
		tw.tween_property(e, "fog_light_color", Color(0.13, 0.11, 0.17), 2.0)
		tw.tween_property(e, "fog_density", NIGHT_FOG, 2.0)
		tw.tween_property(e, "ambient_light_energy", 0.16, 2.0)
		tw.tween_property(e, "volumetric_fog_density", 0.034, 2.0)
		tw.tween_property(e, "volumetric_fog_albedo", Color(0.22, 0.18, 0.24), 2.0)
		tw.tween_property(e, "volumetric_fog_emission", Color(0.10, 0.01, 0.05), 2.0)
	else:
		tw.tween_property(world.sun, "light_energy", 1.0, 2.0)
		tw.tween_property(world.sun, "light_color", Color(1.0, 0.72, 0.55), 2.0)
		tw.tween_property(sky_mat, "sky_top_color", DAY_SKY_TOP, 2.0)
		tw.tween_property(sky_mat, "sky_horizon_color", DAY_SKY_HORIZON, 2.0)
		tw.tween_property(e, "fog_light_color", Color(0.36, 0.27, 0.26), 2.0)
		tw.tween_property(e, "fog_density", DAY_FOG, 2.0)
		tw.tween_property(e, "ambient_light_energy", 0.42, 2.0)
		tw.tween_property(e, "volumetric_fog_density", 0.016, 2.0)
		tw.tween_property(e, "volumetric_fog_albedo", Color(0.38, 0.30, 0.30), 2.0)
		tw.tween_property(e, "volumetric_fog_emission", Color(0.16, 0.03, 0.03), 2.0)

	for light in get_tree().get_nodes_in_group("street_lights"):
		if is_instance_valid(light):
			tw.tween_property(light, "light_energy", 3.5 if to_night else 0.0, 2.0)

	for rift in get_tree().get_nodes_in_group("rifts"):
		if is_instance_valid(rift):
			rift.set_active(to_night)
