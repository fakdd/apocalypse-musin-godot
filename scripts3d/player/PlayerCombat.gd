extends Node
class_name PlayerCombat
## 검기·만천화우·기공파·반로환동 등 전투 행동과 그 이펙트.
## Player3D(owner)의 상태를 읽고 쓰는 행동 모듈이다.

var owner_player: CharacterBody3D

func setup(p: CharacterBody3D) -> void:
	owner_player = p

func _slash() -> void:
	# 3타 콤보 — 연속으로 이으면 피해와 범위가 커진다
	if owner_player.combo_timer > 0.0:
		owner_player.combo_step = (owner_player.combo_step + 1) % 3
	else:
		owner_player.combo_step = 0
	owner_player.combo_timer = PlayerConfig.COMBO_WINDOW

	var combo_mult: float = [1.0, 1.25, 1.9][owner_player.combo_step]
	var range_mult: float = [1.0, 1.05, 1.35][owner_player.combo_step]

	# 공격 속도 강화 — 배율 계산은 UpgradeManager 가 한다
	# 계열 공격속도 — 도/암기는 빠르고 둔기는 느리다
	owner_player.atk_cd = PlayerConfig.ATTACK_COOLDOWN \
		* UpgradeManager.reduce("attack_speed") / maxf(PlayerStats.wf("rate", 1.0), 0.05)
	owner_player.attack_anim_timer = 0.30
	# 공격 중에는 마우스 방향으로 몸을 즉시 고정
	owner_player.model_yaw = owner_player.facing_angle
	if owner_player.model:
		owner_player.model.rotation.y = owner_player.model_yaw
	if owner_player.anim and owner_player.anim.has_animation("attack-melee-right"):
		owner_player.anim.speed_scale = 1.9   # Mixamo 검격은 느리므로 빠르게 재생
		owner_player.anim.play("attack-melee-right")
	# 베는 순간 살짝 앞으로 파고든다
	owner_player.velocity += owner_player.facing_dir() * 3.5
	_spawn_slash_vfx(range_mult, owner_player.combo_step)
	owner_player.animation.spawn_weapon_trail(owner_player.combo_step)
	var kills := 0
	var hits := 0
	# 치명타 — 한 번의 휘두름에 한 번만 굴린다 (적마다 굴리면 체감이 흐려진다)
	var crit: Array = UpgradeManager.roll_crit()
	var crit_mult: float = crit[0]
	if bool(crit[1]):
		_crit_feedback()
	# 3타 피니시 — 벤 자리에서 검기 파편이 터진다
	if owner_player.combo_step >= 2:
		VfxPool.burst(owner_player.get_parent(),
			owner_player.global_position + owner_player.facing_dir() * 2.2 + Vector3(0, 1.1, 0),
			Color(1.0, 0.72, 0.45), 30, 8.0, 0.5, 0.14, -8.0)
	var is_crit: bool = crit[1]
	var fwd: Vector3 = owner_player.facing_dir()
	# 무기 계열 계수 — 사거리/각도/피해. 무기가 없으면 전부 1.0 이라 기존과 같다.
	var reach := PlayerConfig.ATTACK_RANGE * range_mult * PlayerStats.wf("reach", 1.0)
	var half_angle: float = PlayerConfig.ATTACK_HALF_ANGLE * PlayerStats.wf("arc", 1.0)
	var fam_dmg: float = PlayerStats.wf("damage", 1.0)
	var status: String = String(PlayerStats.weapon_family().get("status", ""))
	# 활 계열 — 근접 부채꼴 대신 화살을 쏜다. 판정은 Projectile3D 가 맡는다.
	if bool(PlayerStats.weapon_family().get("ranged", false)):
		_fire_arrows(fwd, combo_mult * crit_mult * PlayerStats.wf("damage", 1.0))
		return
	var pierce: bool = bool(PlayerStats.weapon_family().get("pierce", false))
	var hit_center := Vector3.ZERO
	# 매 프레임 그룹 검색 대신 Battlefield 캐시를 쓴다.
	# 죽은 몹은 사망 연출 때문에 0.8~1.15초간 시체로 남아 캐시에 계속 잡힌다.
	# 걸러내지 않으면 시체를 벨 때마다 hits 가 올라가 히트스톱·타격음·카메라 킥이
	# 나가고, 정작 진짜 헛스윙 피드백은 사라진다.
	for enemy in Battlefield.enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var to_enemy: Vector3 = enemy.global_position - owner_player.global_position
		to_enemy.y = 0
		if to_enemy.length() > reach + enemy.hit_radius: continue
		if fwd.angle_to(to_enemy.normalized()) > half_angle: continue
		hits += 1
		hit_center += enemy.global_position
		var kb: float = 4.0 * combo_mult \
			* (1.0 + PlayerStats.wf("knockback", 0.0))
		if enemy.take_damage(owner_player.slash_damage * combo_mult * crit_mult * fam_dmg,
				to_enemy.normalized() * kb):
			kills += 1
		elif status != "":
			_apply_status(enemy, status, owner_player.slash_damage * fam_dmg)
		# 관통 무기가 아니면 기존과 동일하게 각도 안 전부를 때린다 (판정 변경 없음)
		if pierce:
			pass

	# ── 명중/헛스윙 피드백 ──
	if hits > 0:
		hit_center /= float(hits)
		_hit_confirm(hits, kills, hit_center)
		if is_crit:
			# 치명타는 화면으로도 읽혀야 한다
			CombatFeel.screen_flash(Color(1.0, 0.95, 0.7), 0.18, 0.0, 0.14)
			SoundManager.play_pitched("hit", 3.0, 1.35, 0.02)
	else:
		_whiff_feedback()

## 명중 확정 — 히트스톱 · 카메라 킥 · 사운드 레이어 · 크리티컬 플래시를 한곳에서 처리한다.
##
## 사운드 타이밍 개선:
##   이전에는 명중 수와 콤보 단계에 상관없이 "hit" 하나를 같은 볼륨/피치로 재생했다.
##   3타 피니셔와 평타가 청각적으로 구분되지 않아 타격의 "무게"가 전달되지 않았다.
##   이제 콤보 단계에 따라 피치를 올리고(1타 낮음 → 3타 높음), 다중 명중은 볼륨을 키우고,
##   처치음은 한 프레임 뒤에 재생해 "베었다 → 죽었다"가 두 사건으로 들리게 한다.
func _hit_confirm(hits: int, kills: int, at: Vector3) -> void:
	var step: int = owner_player.combo_step
	var is_finisher := step == 2
	var kick_dir: Vector3 = (at - owner_player.global_position)

	# 타격음 — 콤보가 올라갈수록 피치가 높아지고 두꺼워진다
	var pitch_step: float = [0.92, 1.02, 1.16][step]
	var vol: float = -2.0 + minf(float(hits) * 1.2, 4.0) + (2.0 if is_finisher else 0.0)
	SoundManager.play_pitched("hit", vol, pitch_step, 0.06)

	# 히트스톱 — 콤보 단계와 처치 수에 따라 무게가 다르다
	var weight: float = CombatFeel.HS_LIGHT
	if step == 1:
		weight = CombatFeel.HS_MEDIUM
	if is_finisher:
		weight = CombatFeel.HS_HEAVY
	if kills > 0:
		weight = maxf(weight, CombatFeel.HS_KILL)
	CombatFeel.hit_stop(weight)

	# 카메라 — 명중 방향으로 킥
	var mag: float = 0.08 + 0.05 * float(step) + minf(float(hits) * 0.02, 0.08)
	if kills > 0:
		mag += 0.05
	owner_player.shake_from(mag, 0.16 + 0.06 * float(step), kick_dir)

	# 크리티컬 화면 플래시 — 피니셔/처치 순간에만 (남발하면 눈이 피로해진다)
	if is_finisher:
		CombatFeel.screen_flash(Color(1.0, 0.86, 0.62), 0.16, 0.0, 0.13)
	if kills > 0:
		CombatFeel.screen_flash(Color(1.0, 0.4, 0.28), 0.13, 0.0, 0.18)
		owner_player.ult_gauge = min(owner_player.ult_max, owner_player.ult_gauge + kills * 4)
		owner_player.ult_changed.emit()

## 헛스윙 — 아무것도 못 맞히면 히트스톱 없이 바람 소리만 (명중과 확실히 구분된다)
func _whiff_feedback() -> void:
	SoundManager.play_pitched("dash", -20.0, 0.7, 0.08)

func _make_arc_mesh(radius: float, half_angle: float, inner: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var steps := 16
	for i in range(steps):
		var a0 := -half_angle + (half_angle * 2.0) * (float(i) / steps)
		var a1 := -half_angle + (half_angle * 2.0) * (float(i + 1) / steps)
		var o0 := Vector3(sin(a0), 0, cos(a0)) * radius
		var o1 := Vector3(sin(a1), 0, cos(a1)) * radius
		var i0 := Vector3(sin(a0), 0, cos(a0)) * inner
		var i1 := Vector3(sin(a1), 0, cos(a1)) * inner
		# 양면으로 두 삼각형씩
		verts.append_array([i0, o0, o1])
		verts.append_array([i0, o1, i1])
		verts.append_array([o1, o0, i0])
		verts.append_array([i1, o1, i0])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am

## 검기 — 칼이 지나간 부채꼴 궤적이 순간적으로 번쩍인다
func _spawn_slash_vfx(range_mult: float = 1.0, step: int = 0) -> void:
	var r := PlayerConfig.ATTACK_RANGE * range_mult
	var m := StandardMaterial3D.new()
	# 3타째는 흰빛에 가깝게 강조
	m.albedo_color = Color(1.0, 0.35, 0.28, 0.85) if step < 2 else Color(1.0, 0.78, 0.5, 0.95)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(1.0, 0.22, 0.15)
	m.emission_energy_multiplier = 6.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := VfxPool.take_fx(owner_player.get_parent(),
		_make_arc_mesh(r, PlayerConfig.ATTACK_HALF_ANGLE, r * 0.35), m)
	mesh.global_position = owner_player.global_position + Vector3(0, 1.0, 0)
	mesh.rotation.y = owner_player.facing_angle

	# 베는 방향으로 궤적이 훑고 지나가는 느낌
	mesh.scale = Vector3(0.5, 1.0, 0.5)
	var tw := create_tween()
	tw.tween_property(mesh, "scale", Vector3(1.15, 1.0, 1.15), 0.09).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(mesh, "rotation:y", owner_player.facing_angle + 0.35, 0.09)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.14)
	tw.parallel().tween_property(m, "emission_energy_multiplier", 0.0, 0.14)
	tw.tween_callback(func(): VfxPool.give_fx(mesh))

	# 칼끝 섬광
	var spark := OmniLight3D.new()
	spark.light_color = Color(1.0, 0.4, 0.3)
	spark.light_energy = 3.5
	spark.omni_range = 6.0
	spark.position = owner_player.global_position + owner_player.facing_dir() * (r * 0.5) + Vector3(0, 1.2, 0)
	owner_player.get_parent().add_child(spark)
	var tw2 := create_tween()
	tw2.tween_property(spark, "light_energy", 0.0, 0.16)
	tw2.tween_callback(spark.queue_free)

func _ultimate() -> void:
	owner_player.ult_gauge = 0
	owner_player.ult_changed.emit()
	Battlefield.telegraph(owner_player.global_position, 16.0)
	SoundManager.play("ultimate")
	# 궁극기는 게임 내 가장 강한 순간 — 히트스톱 + 슬로모션 + 흰 플래시를 모두 쓴다
	CombatFeel.hit_stop(CombatFeel.HS_ULT)
	CombatFeel.slow_motion(0.5, 0.45)
	CombatFeel.screen_flash(Color(0.8, 0.92, 1.0), 0.42, 0.05, 0.4)
	CombatFeel.camera_punch("ult")
	owner_player.shake_from(0.4, 0.5, Vector3.ZERO)
	for enemy in Battlefield.enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var flat: Vector3 = enemy.global_position - owner_player.global_position
		flat.y = 0
		if flat.length() <= PlayerConfig.ULT_RADIUS:
			enemy.take_damage(999, flat.normalized() * 3.0)
	_spawn_ult_vfx()

func _spawn_ult_vfx() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = PlayerConfig.ULT_RADIUS
	sphere.height = PlayerConfig.ULT_RADIUS * 2.0
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.85, 1.0, 0.4)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.5, 0.8, 1.0)
	m.emission_energy_multiplier = 4.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := VfxPool.take_fx(owner_player.get_parent(), sphere, m)
	mesh.position = owner_player.global_position + Vector3(0, 1.0, 0)
	mesh.scale = Vector3(0.15, 0.15, 0.15)

	var flash := OmniLight3D.new()
	flash.position = owner_player.global_position + Vector3(0, 1.5, 0)
	flash.light_color = Color(0.6, 0.85, 1.0)
	flash.light_energy = 8.0
	flash.omni_range = PlayerConfig.ULT_RADIUS * 2.0
	owner_player.get_parent().add_child(flash)

	var tw := create_tween()
	tw.tween_property(mesh, "scale", Vector3(1.1, 0.5, 1.1), 0.45)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.parallel().tween_property(flash, "light_energy", 0.0, 0.45)
	tw.tween_callback(func(): VfxPool.give_fx(mesh))
	tw.tween_callback(flash.queue_free)

func _ranged_wave() -> void:
	owner_player.ranged_cd = PlayerConfig.RANGED_COOLDOWN * UpgradeManager.reduce("cooldown")
	owner_player.attack_anim_timer = 0.34
	owner_player.model_yaw = owner_player.facing_angle
	if owner_player.model:
		owner_player.model.rotation.y = owner_player.model_yaw
	if owner_player.anim and owner_player.anim.has_animation("attack-melee-left"):
		owner_player.anim.speed_scale = 1.6
		owner_player.anim.play("attack-melee-left")
	var half_width := 1.4
	var dir: Vector3 = owner_player.facing_dir()
	var kills := 0
	var hits := 0
	for enemy in Battlefield.enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var rel: Vector3 = enemy.global_position - owner_player.global_position
		rel.y = 0
		var proj := rel.dot(dir)
		if proj < 0 or proj > PlayerConfig.RANGED_RANGE: continue
		var perp := (rel - dir * proj).length()
		if perp > half_width + enemy.hit_radius: continue
		hits += 1
		if enemy.take_damage(owner_player.slash_damage * 2.0, dir * 3.0):
			kills += 1
	if hits > 0:
		SoundManager.play("hit", 0.0, 0.12)
	if kills > 0:
		owner_player.ult_gauge = min(owner_player.ult_max, owner_player.ult_gauge + kills * 4)
		owner_player.ult_changed.emit()
	_spawn_beam_vfx(dir)

func _spawn_beam_vfx(dir: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(2.4, 1.2, PlayerConfig.RANGED_RANGE)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.9, 1.0, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.45, 0.85, 1.0)
	m.emission_energy_multiplier = 4.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := VfxPool.take_fx(owner_player.get_parent(), box, m)
	mesh.position = owner_player.global_position + dir * (PlayerConfig.RANGED_RANGE * 0.5) + Vector3(0, 1.0, 0)
	mesh.rotation.y = owner_player.facing_angle
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(func(): VfxPool.give_fx(mesh))

func _start_parry() -> void:
	owner_player.parry_cd = PlayerConfig.PARRY_COOLDOWN * UpgradeManager.reduce("cooldown")
	owner_player.parry_timer = PlayerConfig.PARRY_WINDOW
	_spawn_parry_vfx()

func _parry_success() -> void:
	owner_player.parry_timer = 0
	# 반로환동 성공 — 가장 만족스러워야 하는 순간이므로 강한 히트스톱 + 금색 플래시
	CombatFeel.impact("parry")
	# 검 계열은 패링 반격이 강하다 (on_parry)
	owner_player.shake_from(0.24, 0.26, Vector3.ZERO)
	for enemy in Battlefield.enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var flat: Vector3 = enemy.global_position - owner_player.global_position
		flat.y = 0
		if flat.length() <= 6.0:
			enemy.stun(1.2)
			enemy.take_damage(owner_player.slash_damage, flat.normalized() * 7.0)

func _spawn_parry_vfx() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.9, 0.4, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(1.0, 0.85, 0.3)
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := VfxPool.take_fx(self, torus, m)
	mesh.position = Vector3(0, 1.0, 0)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, PlayerConfig.PARRY_WINDOW + 0.15)
	tw.tween_callback(func(): VfxPool.give_fx(mesh))

## 치명타 전용 연출 — 일반 타격과 확실히 구분되게 한다.
## 화면 플래시(금색) + 히트스톱 + 짧은 슬로모션 + 사운드 레이어 2겹.
func _crit_feedback() -> void:
	CombatFeel.impact("crit")

## 무기 계열 상태이상 — 기존 take_damage / stun 만 재사용한다.
## 새 상태 시스템·새 노드를 만들지 않고 타이머로 몇 번 더 때리는 방식이다.
func _apply_status(enemy, kind: String, base_damage: float) -> void:
	var d := ItemData.status_def(kind)
	if d.is_empty() or not is_instance_valid(enemy):
		return
	match kind:
		"stun":
			if randf() <= float(d.get("chance", 0.35)):
				enemy.stun(float(d.get("duration", 0.55)))
		"bleed", "poison":
			_dot(enemy, int(d.get("ticks", 4)), float(d.get("interval", 0.5)),
				base_damage * float(d.get("damage_pct", 0.2)), float(d.get("slow", 1.0)))

## 지속 피해 — 정해진 횟수만큼 나눠 때린다.
func _dot(enemy, ticks: int, interval: float, dmg: float, slow: float) -> void:
	var tree := owner_player.get_tree()
	if slow < 1.0 and is_instance_valid(enemy):
		enemy.speed *= slow
	for i in range(ticks):
		await tree.create_timer(interval, true, false, true).timeout
		if not is_instance_valid(enemy) or enemy.dead:
			return
		enemy.take_damage(dmg)

## 활 — VfxPool 의 투사체를 그대로 빌려 쓴다 (새 노드·새 시스템 없음).
## Projectile3D 가 이미 적 판정·수명·풀 반납을 하므로 여기서는 발사만 한다.
func _fire_arrows(dir: Vector3, damage_mult: float) -> void:
	var fam := PlayerStats.weapon_family()
	var n: int = maxi(1, int(fam.get("arrow_count", 1)))
	var spd: float = float(fam.get("arrow_speed", 26.0))
	var life: float = float(fam.get("arrow_life", 1.6))
	var dmg: float = owner_player.slash_damage * damage_mult
	var origin: Vector3 = owner_player.global_position + Vector3(0, 1.1, 0) + dir * 0.8

	for i in range(n):
		var a := (float(i) - (n - 1) * 0.5) * 0.10
		var d := dir.rotated(Vector3.UP, a)
		var proj := VfxPool.take_projectile(owner_player.get_parent())
		if proj == null:
			continue
		proj.global_position = origin
		# 플레이어가 쏜 화살은 적을 맞힌다 — setup 이 충돌 마스크까지 잡아 준다
		proj.setup(d, spd, dmg, life, false, bool(fam.get("pierce", false)))

	# 발사 지점에서 빛가루가 튄다
	VfxPool.burst(owner_player.get_parent(), origin, Color(0.65, 0.95, 1.0),
		14, 5.0, 0.35, 0.09, -2.0)
	CombatFeel.impact("hit_light")
	SoundManager.play_pitched("dash", -10.0, 1.35)
