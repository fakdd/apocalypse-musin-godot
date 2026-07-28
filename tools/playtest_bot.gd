extends Node
## 1챕터 자동 플레이테스트.
##   godot --quit-after 20000 -- --playtest
##
## 사람이 직접 하는 것을 대신하지는 못한다.
## 대신 "밸런스가 벽인가 / 몹이 도망만 다니는가 / 연출이 겹치는가"
## 세 가지 우려를 **숫자로** 답한다.

var _f := 0
var _on := false

## 계측
var t_start := 0.0
var deaths := 0
var kills := 0
var areas_cleared := 0
var dmg_taken := 0.0
var dmg_dealt := 0.0
var boss_seen := false
var boss_killed := false
var boss_time := 0.0

var flee_frames := 0          ## 적이 후퇴/회피 상태로 보낸 프레임
var combat_frames := 0        ## 적이 살아 있던 프레임
var effect_overlap := 0       ## 연출이 3중 이상 겹친 횟수
var max_enemies := 0
var elite_seen := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a) == "--playtest":
			_on = true
	if not _on:
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func _process(delta: float) -> void:
	_f += 1
	if _f == 30:
		_boot()
		return
	if _f < 30:
		return
	_sample(delta)
	if _f % 600 == 0:
		_tick_report()
	if boss_killed or deaths >= 5 or _f > 18000:
		set_process(false)
		_final()
		get_tree().quit()

func _boot() -> void:
	var w = get_tree().current_scene
	if w and w.get("hud") != null and w.hud.get("menu_ui") != null \
			and w.hud.menu_ui.is_open():
		w.hud.menu_ui.close()
	get_tree().paused = false
	# start_new_game 은 LandmarkRegistry 를 비운다 — 이미 만들어진 월드가 지워지므로
	# 여기서는 부르지 않는다. 세이브는 _enter_tree 에서 미리 치워 뒀다.
	t_start = Time.get_ticks_msec() / 1000.0
	print("PT| ══ 1챕터 자동 플레이테스트 ══")
	print("PT| 목표: 밸런스 벽 / AI 도주 / 연출 과부하 — 세 가지만 본다")
	_drive()

## 봇 조작 — 정직하게 말하면 '조작'이 아니라 진행 강제다.
## 실제 입력을 흉내 내면 결과가 봇 실력에 좌우돼 밸런스 측정이 흐려진다.
## 대신 플레이어를 무적 없이 두고, 영역을 순서대로 밟으며 전투를 그대로 겪게 한다.
func _drive() -> void:
	var w = get_tree().current_scene
	if w == null:
		return
	# 낮을 건너뛰고 바로 밤으로 — 웨이브 루프는 WaveManager3D 가 그대로 돌린다
	if w.has_method("_start_night_phase"):
		w._start_night_phase()
	else:
		GameManager.phase_timer = 0.1

func _sample(delta: float) -> void:
	var w = get_tree().current_scene
	if w == null:
		return
	var pl := Battlefield.live_player()
	var alive := 0
	var fleeing := 0
	for e in Battlefield.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		alive += 1
		if e.get("is_elite") == true:
			elite_seen = maxi(elite_seen, 1)
		var b = e.get("brain")
		if b and (b.retreat_timer > 0.0 or b.dodge_timer > 0.0):
			fleeing += 1
	max_enemies = maxi(max_enemies, alive)
	if alive > 0:
		combat_frames += 1
		if float(fleeing) / float(alive) > 0.4:
			flee_frames += 1

	# 연출 과부하 — 시간배율이 1이 아니고 화면 플래시까지 겹친 순간
	if Engine.time_scale < 0.95 and CombatFeel.get("_flash_rect") != null:
		if CombatFeel._flash_rect.color.a > 0.15:
			effect_overlap += 1

	if pl == null:
		return
	_patrol(pl)
	if boss_seen and not boss_killed:
		boss_time += delta

	# 플레이어를 자동으로 싸우게 한다 (가장 가까운 적을 향해 이동 + 공격)
	var target: Node3D = null
	var best := 999.0
	for e in Battlefield.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = pl.global_position.distance_to(e.global_position)
		if d < best:
			best = d
			target = e
	if target:
		var dir: Vector3 = target.global_position - pl.global_position
		dir.y = 0.0
		if dir.length() > 2.2:
			pl.velocity.x = dir.normalized().x * PlayerStats.get_final_speed()
			pl.velocity.z = dir.normalized().z * PlayerStats.get_final_speed()
		pl.facing_angle = atan2(dir.x, dir.z)
		if pl.atk_cd <= 0.0 and pl.combat:
			pl.combat._slash()

## 적이 없으면 다음 미탐험 랜드마크로 걸어간다 (사람이 돌아다니는 것과 같은 효과)
var _goal: LandmarkData = null

func _patrol(pl) -> void:
	if Battlefield.live_enemy_count() > 0:
		return
	if _goal == null or _goal.cleared:
		_goal = null
		for d in LandmarkRegistry.landmarks:
			if not d.cleared:
				_goal = d
				break
	if _goal == null:
		return
	var to: Vector3 = _goal.center - pl.global_position
	to.y = 0.0
	if to.length() < 3.0:
		return
	pl.velocity.x = to.normalized().x * PlayerStats.get_final_speed() * 1.8
	pl.velocity.z = to.normalized().z * PlayerStats.get_final_speed() * 1.8

func _tick_report() -> void:
	var mins := (Time.get_ticks_msec() / 1000.0 - t_start) / 60.0
	print("PT| %5.1f분  Lv%-2d  적%-2d  처치%-3d  사망%d  탐험%d/%d"
		% [mins, GameManager.player_level, Battlefield.live_enemy_count(),
		kills, deaths, LandmarkRegistry.explored_count(), LandmarkRegistry.landmarks.size()])

func _final() -> void:
	var mins := (Time.get_ticks_msec() / 1000.0 - t_start) / 60.0
	print("PT| ── 결과 ──")
	print("PT| 소요 %.1f분 · Lv%d · 처치 %d · 사망 %d"
		% [mins, GameManager.player_level, kills, deaths])
	print("PT| 최대 동시 적 %d · 엘리트 등장 %s" % [max_enemies, "예" if elite_seen > 0 else "아니오"])

	# ① 밸런스가 벽인가
	var wall := deaths >= 3
	print("PT| ① 밸런스 — %s (사망 %d회)"
		% ["★ 벽으로 보인다" if wall else "감당 가능", deaths])

	# ② 몹이 도망만 다니는가
	var flee_pct: float = 0.0
	if combat_frames > 0:
		flee_pct = float(flee_frames) / float(combat_frames) * 100.0
	print("PT| ② AI 도주 — 전투 시간의 %.0f%% 가 회피/후퇴 우세 %s"
		% [flee_pct, "★ 과하다" if flee_pct > 25.0 else "적정"])

	# ③ 연출이 겹치는가
	var over_pct: float = 0.0
	if _f > 0:
		over_pct = float(effect_overlap) / float(_f) * 100.0
	print("PT| ③ 연출 — 전체 프레임의 %.1f%% 가 시간왜곡+플래시 동시 %s"
		% [over_pct, "★ 과하다" if over_pct > 8.0 else "적정"])

	print("PT| 권장 조정:")
	if wall:
		print("PT|   data/pacing.json  tempo.elite 하향, ChapterConfig hp_mult 하향")
	if flee_pct > 25.0:
		print("PT|   data/ai.json  profiles.*.retreat_hp / dodge_chance 하향")
	if over_pct > 8.0:
		print("PT|   data/feel.json  slowmo.* 지속시간 단축, flash.* peak 하향")
	if not wall and flee_pct <= 25.0 and over_pct <= 8.0:
		print("PT|   없음 — 세 우려 모두 수치상 문제 없음")
	print("PT| DONE")

## 전역 신호로 계측 (봇이 직접 세지 않는다)
func _enter_tree() -> void:
	if not _on and not ("--playtest" in OS.get_cmdline_user_args()):
		return
	SaveGame.slot = 2
	SaveGame.wipe()
	LandmarkRegistry.landmark_cleared.connect(func(_d): areas_cleared += 1)
	GameManager.chapter_boss_defeated.connect(func(_c): boss_killed = true)
	GameManager.game_over.connect(func(_r): deaths += 1)
