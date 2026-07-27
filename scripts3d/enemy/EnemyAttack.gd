extends Node
class_name EnemyAttack
## 적의 공격 실행 담당 — 근접 공격 트리거, 기탄 발사, 돌진 예고 표시.
## "언제 공격할지"의 판단은 EnemyBrain 이 한다.

var owner_enemy: CharacterBody3D

func setup(e: CharacterBody3D) -> void:
	owner_enemy = e

## 근접 공격 — 쿨다운을 걸고 공격 모션을 재생한다
func _attack() -> void:
	owner_enemy.hit_cd = EnemyConfig.ATTACK_HIT_CD
	owner_enemy.attack_anim_timer = EnemyConfig.ATTACK_ANIM_TIME
	# 때린 뒤에는 잠깐 굳는다 — 이 빈틈이 있어야 플레이어가 치고 빠질 수 있다
	owner_enemy.attack_recover = EnemyConfig.ATTACK_RECOVER_ELITE \
		if owner_enemy.brain.tier >= 1 else EnemyConfig.ATTACK_RECOVER
	owner_enemy.animation._play(owner_enemy.anim_attack, true)

## 기탄 발사 — 풀에서 꺼내 쓴다 (발사마다 Area3D 를 조립하지 않는다)
func _fire_projectile(dir: Vector3) -> void:
	var proj := VfxPool.take_projectile(owner_enemy.get_parent())
	proj.global_position = owner_enemy.global_position \
		+ Vector3(0, owner_enemy.hover_height + owner_enemy.hit_radius, 0) + dir * 0.8
	proj.launch(dir, EnemyConfig.PROJECTILE_SPEED,
		owner_enemy.contact_damage * EnemyConfig.PROJECTILE_DMG_MULT, EnemyConfig.PROJECTILE_LIFE)

## 돌진 예고 표시 — 플레이어가 회피할 시간을 준다
func _show_telegraph(dir: Vector3) -> void:
	var length: float = owner_enemy.speed * EnemyConfig.CHARGE_SPEED_MULT * EnemyConfig.CHARGE_DASH_TIME + 2.0
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(owner_enemy.hit_radius * 2.2, 0.08, length)
	mesh.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.2, 0.15, 0.4)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(1.0, 0.15, 0.1)
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = m
	owner_enemy.get_parent().add_child(mesh)
	mesh.global_position = owner_enemy.global_position + dir * (length * 0.5) + Vector3(0, 0.1, 0)
	mesh.rotation.y = atan2(dir.x, dir.z)
	owner_enemy.telegraph = mesh
	var tw := owner_enemy.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.75, 0.3)
	tw.tween_property(m, "albedo_color:a", 0.3, 0.3)
