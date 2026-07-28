extends CharacterBody3D
## EnemyController — 적 1기의 상태(HP/타이머/타입)와 공개 API(take_damage/stun/setup)를 보유하고,
## 실제 행동은 하위 모듈에 위임한다.
##   EnemyBrain     — 목표 선정 · 패턴 발동 판단
##   EnemyMovement  — 물리 이동 (경직/돌진/추적) · 접촉 피해
##   EnemyAttack    — 공격 실행 (근접/기탄/돌진 예고)
##   EnemyAnimation — 모델 · 애니메이션 · HP바 · 피격/사망 연출
## 타입 데이터와 튜닝 상수는 EnemyConfig 로 옮겼다.

# 하위 호환 별칭 — 외부/툴 코드가 Enemy3D 의 상수를 참조해도 깨지지 않게 유지
const GRAVITY := EnemyConfig.GRAVITY
const TYPES := EnemyConfig.TYPES

var enemy_type := "grunt"
var hp := 1.0
var max_hp := 1.0
var speed := 3.0
var contact_damage := 8.0
var _boss_finish_shown := false
var is_elite := false
var hit_radius := 0.6
var is_flying := false
var hover_height := 0.0
var is_siege := false
var pattern := "melee"
var shoot_cd := 0.0
var charge_cd := 0.0
var charge_windup := 0.0
var charge_dash := 0.0
var charge_dir := Vector3.ZERO
var telegraph: MeshInstance3D = null

var hit_cd := 0.0
var stun_timer := 0.0
var attack_anim_timer := 0.0
var landmark_id := ""             ## 랜드마크가 소환한 적이면 그 id (클리어 판정용)
var hurt_anim_timer := 0.0        ## 피격 움찔 잔여 시간
var attack_recover := 0.0         ## 공격 직후 굳어 있는 시간 (플레이어가 파고들 빈틈)
var knock_vel := Vector3.ZERO     ## 넉백 속도 (여러 프레임에 걸쳐 감쇠)
var dead := false

var model: Node3D
var anim: AnimationPlayer
var mesh_instances: Array = []
var flash_mat: StandardMaterial3D
var hurt_mat: StandardMaterial3D    ## 2단계 붉은 잔상
var hp_bar_bg: Sprite3D
var hp_bar_fill: Sprite3D

var anim_idle := "Idle"
var anim_move := "Walk"
var anim_attack := "Punch"
var anim_hit := "HitReact"
var anim_death := "Death"

# 행동 모듈
var brain: EnemyBrain
var movement: EnemyMovement
var attack: EnemyAttack
var animation: EnemyAnimation

## 보스 계열인지 (overlord / warlord)
func is_boss_type(t: String = "") -> bool:
	var check: String = t if t != "" else enemy_type
	# 챕터 보스가 늘어나므로 목록을 본다 (예전에는 overlord/warlord 만 하드코딩)
	return EnemyConfig.BOSS_TYPES.has(check)

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1

	_create_modules()

	# 피격 재질은 모든 적이 공유한다 (적마다 새로 만들면 메모리·드로우 상태가 낭비된다)
	flash_mat = SharedMaterials.enemy_flash()
	hurt_mat = SharedMaterials.enemy_hurt()

func _create_modules() -> void:
	brain = EnemyBrain.new()
	brain.name = "EnemyBrain"
	movement = EnemyMovement.new()
	movement.name = "EnemyMovement"
	attack = EnemyAttack.new()
	attack.name = "EnemyAttack"
	animation = EnemyAnimation.new()
	animation.name = "EnemyAnimation"
	for m in [brain, movement, attack, animation]:
		m.setup(self)
		add_child(m)

func setup(type: String, wave: int) -> void:
	if not TYPES.has(type):
		type = "hound"
	enemy_type = type
	var cfg: Dictionary = TYPES[type]
	is_siege = bool(cfg.get("siege", false))
	pattern = String(cfg.get("pattern", "melee"))

	var w: float = minf(float(wave), float(EnemyConfig.HP_WAVE_CAP))
	max_hp = (float(cfg["hp"]) 		+ float(cfg["hp_per_wave"]) * EnemyConfig.HP_PER_WAVE_MULT * maxf(0.0, w - 1.0)) 		* ChapterConfig.hp_mult_of(GameManager.chapter) * SaveGame.tier_mult("hp")
	hp = max_hp
	speed = float(cfg["speed"])
	hit_radius = float(cfg["radius"])
	contact_damage = float(cfg["damage"]) * EnemyConfig.CONTACT_DAMAGE_MULT 		* ChapterConfig.dmg_mult_of(GameManager.chapter) * SaveGame.tier_mult("dmg")
	is_flying = bool(cfg["flying"])

	# 엘리트 — 챕터가 올라갈수록 자주 섞인다. 새 몬스터를 만들지 않고
	# 기존 몹의 체력·피해·보상만 올려 "저건 위험하다"는 인상을 만든다.
	if not is_boss_type(type) and randf() < CombatFeel.tempo("elite", 0.0):
		is_elite = true
		max_hp *= CombatFeel.tempo_num("elite_hp", 1.9)
		hp = max_hp
		contact_damage *= CombatFeel.tempo_num("elite_dmg", 1.25)
		scale *= 1.15
		add_to_group("elite")

	if is_boss_type(type):
		add_to_group("boss")
	if type == "warlord":
		add_to_group("final_boss")

	var shape := CollisionShape3D.new()
	var caps := CapsuleShape3D.new()
	caps.radius = clampf(hit_radius * 0.65, 0.3, 1.3)
	caps.height = maxf(caps.radius * 2.2, hit_radius * 2.2)
	shape.shape = caps
	shape.position.y = caps.height * 0.5
	add_child(shape)

	if is_flying:
		hover_height = 1.5 if not is_boss_type(type) else 2.4
	else:
		# 지상 몹은 바닥에 붙여 놓는다. 흡착 거리가 짧으면 내리막·계단마다 몸이 뜨고,
		# 그 뜬 상태가 "공중을 미끄러지는" 느낌의 정체다.
		up_direction = Vector3.UP
		floor_snap_length = EnemyConfig.FLOOR_SNAP
		floor_max_angle = EnemyConfig.FLOOR_MAX_ANGLE
		floor_stop_on_slope = false        ## 경사에서 멈추지 않고 따라 걷는다
		floor_constant_speed = true        ## 오르막이라고 느려지지 않는다
		floor_block_on_wall = true
		slide_on_ceiling = false

	# data/models.json 에 교체 모델이 지정돼 있으면 그것을 먼저 쓴다.
	# 없거나 파일이 빠졌으면 EnemyConfig 의 기본 모델로 돌아간다 — 일부만 교체해도 된다.
	var mconf := VfxPool.model_conf("enemy", type)
	model = VfxPool.spawn_model(mconf)
	if model != null:
		model.position.y += hover_height
		add_child(model)
		anim = VfxPool.find_anim(model)
		animation._collect_meshes(model)
	var packed: PackedScene = null if model != null else load(cfg["model"])
	if packed:
		model = packed.instantiate()
		var s := float(cfg["scale"])
		model.scale = Vector3(s, s, s)
		model.position.y = hover_height
		add_child(model)
		anim = animation._find_anim_player(model)
		animation._collect_meshes(model)
		var tint: Color = cfg["tint"]
		if tint != Color(1, 1, 1):
			animation._apply_tint(tint)
		if bool(cfg.get("eyes", false)):
			animation._add_glowing_eyes()
		var aura: Color = cfg.get("aura", Color(0, 0, 0, 0))
		if aura.a > 0.0:
			animation._add_aura(aura)

	animation._resolve_anim_names()
	animation._play(anim_move)
	animation._build_hp_bar()
	# 타입이 확정된 뒤에 AI 티어를 계산한다 (_ready 시점에는 아직 "grunt" 였다)
	brain.refresh_tier()

	# 소환 직후에는 플레이어 쪽을 향해 세운다. 시야각이 생긴 뒤로 이게 없으면
	# 등지고 나타난 적이 플레이어를 못 보고 그 자리에서 배회한다.
	var pl := Battlefield.live_player()
	if pl and model:
		var to_pl: Vector3 = pl.global_position - global_position
		to_pl.y = 0
		if to_pl.length_squared() > 0.01:
			model.rotation.y = atan2(to_pl.x, to_pl.z)

func _physics_process(delta: float) -> void:
	if dead:
		return
	movement.physics_step(delta)

## ── 공개 API — 외부(플레이어 공격/스킬)가 호출한다 ──

func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO) -> bool:
	if dead:
		return false
	# 보스 약점 창구 — data/bosses.json 의 weakness.mult
	if is_boss_type() and brain and not _boss_finish_shown:
		var fin := CombatFeel.pace("moments", "boss_finish_hp", 0.06)
		if hp / maxf(max_hp, 1.0) <= fin and hp > 0.0:
			_boss_finish_shown = true
			CombatFeel.slow_motion(0.5, 0.4)
			CombatFeel.impact("boss_phase")
			var w2 = get_tree().current_scene
			if w2 and w2.get("hud") != null:
				w2.hud.show_banner(CombatFeel.pace_text("boss_finish_text", "◈ 조금만 더"))
	# 정면 방어(오크) — 앞에서 맞으면 덜 아프다. 옆·뒤로 돌아야 한다.
	var _bh := EnemyConfig.mon_behavior(enemy_type)
	if String(_bh.get("kind", "")) == "front_armor":
		var _pl2 := Battlefield.live_player()
		if _pl2 and is_instance_valid(_pl2):
			var _to: Vector3 = _pl2.global_position - global_position
			_to.y = 0.0
			var _fwd: Vector3 = -global_transform.basis.z
			if _fwd.angle_to(_to.normalized()) < float(_bh.get("arc", 1.2)):
				amount *= 1.0 - float(_bh.get("reduce", 0.45))

	if is_boss_type() and brain:
		var wm := brain.weakness_mult()
		if wm > 1.0:
			amount *= wm
			CombatFeel.impact("weak_point")
	hp -= amount

	# 맞았으면 때린 쪽을 안다 — 시야각이 생긴 뒤로 이게 없으면
	# 등 뒤에서 맞은 적이 가만히 서서 계속 맞는다
	var attacker := Battlefield.live_player()
	if attacker:
		brain.alert_to(attacker.global_position)

	# ── 넉백 개선 ──
	# 이전: global_position += knockback * 0.05 → 순간이동. 밀린 것이 눈에 보이지 않았다.
	# 이제: 속도에 실어 여러 프레임에 걸쳐 밀려나므로 "맞고 밀렸다"가 읽힌다.
	# 총 이동량은 원본과 비슷하게 맞춰 밸런스(거리 유지)를 바꾸지 않는다.
	if knockback.length_squared() > 0.0001:
		var resist: float = EnemyConfig.KNOCKBACK_BOSS_RESIST if is_boss_type() else 1.0
		var flat := Vector3(knockback.x, 0, knockback.z)
		knock_vel = flat * EnemyConfig.KNOCKBACK_IMPULSE * resist
		# 큰 피해는 살짝 위로도 띄운다 (팝 느낌)
		if not is_flying and amount >= max_hp * 0.25:
			knock_vel.y = EnemyConfig.KNOCKBACK_POP

	animation._do_flash(amount / maxf(max_hp, 1.0))
	if hp_bar_fill and is_instance_valid(hp_bar_fill):
		hp_bar_fill.scale.x = clampf(hp / max_hp, 0.0, 1.0)
	if amount < 50.0:
		animation._spawn_damage_number(amount)

	if hp <= 0:
		dead = true
		_die()
		return true

	# ── 피격 리액션 ──
	# 이전에는 stun() 으로만 hit 모션이 나왔다. 평타를 맞아도 몹이 태연히 걸어와서
	# "때리는 느낌"이 없었다. 이제 공격 모션 중이 아니면 짧게 움찔한다.
	_play_hurt_reaction(amount)
	return false

## 피격 움찔 — 피해 비율에 따라 리액션 길이가 달라진다.
## 이동을 멈추지는 않으므로(경직이 아님) 게임플레이 난이도는 그대로다.
func _play_hurt_reaction(amount: float) -> void:
	if attack_anim_timer > 0.0 or charge_dash > 0.0 or charge_windup > 0.0:
		return   ## 공격/돌진 중에는 모션을 끊지 않는다 (예고를 보고 회피하는 규칙 유지)
	var ratio: float = clampf(amount / maxf(max_hp, 1.0), 0.0, 1.0)
	hurt_anim_timer = lerpf(EnemyConfig.HURT_ANIM_MIN, EnemyConfig.HURT_ANIM_MAX, ratio)
	if anim and anim.has_animation(anim_hit):
		anim.speed_scale = 1.5
		anim.play(anim_hit)

## 경직 — 저거너트처럼 immune 로 표시된 몹은 흔들리지 않는다.
func stun(duration: float) -> void:
	var b := EnemyConfig.mon_behavior(enemy_type)
	if String(b.get("kind", "")) == "immune" and bool(b.get("stun", false)):
		return
	if is_boss_type():
		duration *= EnemyConfig.BOSS_STUN_MULT
	stun_timer = maxf(stun_timer, duration)
	animation._play(anim_hit, true)

## 피니시 블로우 — "마지막 한 방"이 특별하게 느껴지도록.
##   보스 처치        → 긴 슬로모션 + 흰 플래시 + 강한 카메라
##   웨이브 마지막 적 → 짧은 슬로모션 (한숨 돌리는 순간을 만든다)
##   일반 처치        → 처치음만 살짝 늦게 (베는 소리와 겹치지 않게)
func _finish_blow_feedback() -> void:
	if is_boss_type():
		CombatFeel.slow_motion(EnemyConfig.FINISH_SLOWMO_BOSS, 0.2)
		CombatFeel.screen_flash(Color(1.0, 0.95, 0.9), 0.55, 0.07, 0.5)
		CombatFeel.shake(0.45, 0.7, Vector3.ZERO)
		SoundManager.play_pitched("kill", 2.0, 0.62, 0.03)
		SoundManager.play_delayed("ultimate", 0.12, -4.0, 0.8)
		return

	# Battlefield 캐시로 살아있는 적 수를 센다 (그룹 검색 없음)
	var alive := 0
	for e in Battlefield.enemies:
		if is_instance_valid(e) and not e.dead:
			alive += 1
	if alive <= 1 and GameManager.night_state == GameManager.NightState.WAVE:
		# 이 적이 마지막이었다 — 웨이브를 끝내는 한 방
		CombatFeel.slow_motion(EnemyConfig.FINISH_SLOWMO_LAST, 0.3)
		CombatFeel.screen_flash(Color(1.0, 0.85, 0.65), 0.24, 0.03, 0.3)
		SoundManager.play_pitched("kill", 0.0, 0.78, 0.04)
	else:
		# 처치음을 한 박자 뒤에 — "베었다(hit)" 와 "죽었다(kill)" 가 두 사건으로 들린다
		SoundManager.play_delayed("kill", 0.05, -3.0, 1.0, 0.1)

## ── 사망 처리 — 보상 지급과 시체 정리 ──

func _die() -> void:
	set_physics_process(false)
	var col := get_node_or_null("CollisionShape3D")
	if col:
		col.queue_free()
	if hp_bar_bg: hp_bar_bg.visible = false
	if hp_bar_fill: hp_bar_fill.visible = false
	# 대표 행동 — 죽는 순간에 일어나는 것들 (폭발/분열/부활)
	if _signature_on_death():
		return
	# 돌진 예고 중에 죽으면 빨간 띠가 바닥에 영원히 남는다.
	# EnemyMovement 는 '돌진이 시작될 때'만 지우므로 여기서도 지워야 한다.
	if telegraph and is_instance_valid(telegraph):
		telegraph.queue_free()
	telegraph = null
	charge_windup = 0.0
	charge_dash = 0.0

	GameManager.kill_count += 1
	CombatFeel.note_kill()
	var _pl := Battlefield.live_player()
	if _pl:
		# 전설 '흡혈'
		if PlayerStats.has_legendary("lifesteal"):
			var pct := float(CombatFeel.pacing().get("legendary", {})
				.get("lifesteal", {}).get("heal_pct", 0.0))
			if pct > 0.0:
				_pl.hp = minf(_pl.max_hp, _pl.hp + _pl.max_hp * pct)
				_pl.hp_changed.emit()
		# 죽기 직전에 낸 마지막 한 방은 크게 기억된다
		if _pl.hp / maxf(_pl.max_hp, 1.0) <= CombatFeel.pace("moments", "last_hit_hp", 0.25):
			CombatFeel.impact("crit")
	# 처치 경험치 — 지금까지 add_exp 는 랜드마크 발견/클리어에서만 불렸다.
	# 밤 웨이브를 아무리 잘 치러도 레벨이 오르지 않아 전투와 성장이 분리돼 있었다.
	# 체력에 비례시켜 별도 데이터 없이 잡몹 2~4, 보스 78~480 이 되게 한다.
	GameManager.add_exp(maxi(1, int(round(max_hp * 0.30))))
	# 랜드마크 수호 몬스터였다면 클리어 판정에 반영한다
	if landmark_id != "":
		LandmarkRegistry.notify_kill(landmark_id)
	# 종류별 처치 수 — NPC 퀘스트 목표가 이 값을 본다
	AchievementManager.bump("kill_" + enemy_type)
	# 지역 보스였다면 다음 챕터로 나가는 포탈이 열린다 (PortalManager 가 받는다)
	if is_in_group("boss"):
		_boss_death_sequence()
		GameManager.mark_chapter_boss_defeated()
	# 이동 속도에 맞춰 올려 둔 배속을 되돌린다 (안 하면 죽는 모션이 빨리 감긴다)
	if anim:
		anim.speed_scale = 1.0
	animation._play(anim_death, true)
	animation._spawn_death_burst()
	_finish_blow_feedback()

	# 마석(정수) — 강화 재화
	var tier_bonus := 0
	if is_boss_type():
		tier_bonus = 25
	elif is_siege:
		tier_bonus = 3
	CraftManager.add_essence(CraftManager.roll_essence_drop(
		tier_bonus + (int(CombatFeel.tempo_num("elite_essence", 3)) if is_elite else 0)))

	# 파밍: 보스는 확정 고등급, 일반 몹은 확률 드랍
	# 구역 보정 — 균열 구역에서 죽인 몹이 훨씬 좋은 것을 떨어뜨린다
	var zone_bonus := 0.0
	var w = get_tree().current_scene
	if w and w.has_method("zone_luck"):
		zone_bonus = w.zone_luck(global_position)
	# 랜드마크 안에서 죽은 몹은 그 랜드마크의 운 보정을 추가로 받는다
	var lm := LandmarkRegistry.at_position(global_position)
	if lm != null:
		zone_bonus += lm.item_luck_bonus

	if is_boss_type():
		# 보스는 확정 드랍 + 매우 높은 운
		LootManager.spawn_drop(global_position, 1.0,
			RarityEnums.roll_rarity(TraitManager.get_drop_pct() + zone_bonus + 700.0))
	elif is_siege:
		LootManager.spawn_drop(global_position, 0.75, -1, zone_bonus)
	else:
		LootManager.spawn_drop(global_position, 0.42, -1, zone_bonus)

	var tw := create_tween()
	var linger := 0.9 if is_boss_type() else 0.55
	tw.tween_interval(linger)
	if model:
		tw.tween_property(model, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	tw.tween_callback(queue_free)

## 보스 처치 연출 — 수치는 data/bosses.json 의 death 에서 온다.
func _boss_death_sequence() -> void:
	var d = EnemyConfig.boss_field(enemy_type, "death")
	if typeof(d) != TYPE_DICTIONARY:
		return
	CombatFeel.impact("boss_death")
	CombatFeel.slow_motion(float(d.get("slowmo", 0.9)), 0.22)
	var fc = d.get("flash", null)
	if typeof(fc) == TYPE_ARRAY and fc.size() >= 3:
		CombatFeel.screen_flash(Color(float(fc[0]), float(fc[1]), float(fc[2])),
			0.5, 0.1, float(d.get("hold", 1.4)))
	var world = get_tree().current_scene
	if world and world.get("hud") != null:
		var nm := String(EnemyConfig.boss_def(enemy_type).get("name", enemy_type))
		world.hud.show_banner("\u2620 %s 격파" % nm)

## 죽는 순간의 대표 행동. true 를 돌려주면 이번 죽음은 취소된다(부활).
## 전부 기존 take_damage / _make_enemy / stun 만 쓴다.
func _signature_on_death() -> bool:
	var b := EnemyConfig.mon_behavior(enemy_type)
	if b.is_empty():
		return false
	match String(b.get("kind", "")):
		"death_blast":
			# 폭발체 — 죽으면서 주변을 태운다. 가까이서 마무리하면 아프다.
			var r := float(b.get("radius", 5.0))
			CombatFeel.impact("slam")
			var pl := Battlefield.live_player()
			if pl and global_position.distance_to(pl.global_position) <= r:
				pl.take_damage(contact_damage * float(b.get("damage", 1.6)), global_position)
		"split":
			# 분열체 — 죽으면 작은 것 둘로 갈라진다
			var world = get_tree().current_scene
			if world and world.has_method("_make_enemy"):
				var n := int(b.get("count", 2))
				for i in range(n):
					var a := TAU * float(i) / float(maxi(1, n))
					var kid = world._make_enemy(String(b.get("into", "goblin")),
						global_position + Vector3(cos(a) * 1.6, 0, sin(a) * 1.6))
					if kid != null:
						kid.max_hp *= float(b.get("hp_pct", 0.3))
						kid.hp = kid.max_hp
						kid.landmark_id = landmark_id
		"revive":
			# 완충재 — 한 번은 다시 일어난다. 확인 사살이 필요하다.
			if brain and not brain.revived:
				brain.revived = true
				hp = max_hp * float(b.get("hp_pct", 0.35))
				dead = false
				animation._flash()
				stun(float(b.get("delay", 1.2)))
				return true
	return false
