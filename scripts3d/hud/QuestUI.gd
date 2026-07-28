extends Node
class_name QuestUI
## 진행 상황 표시 담당 — 상단 중앙 페이즈/웨이브/타이머와 우측 퀘스트 추적 패널.

var owner_hud: CanvasLayer

func setup(h: CanvasLayer) -> void:
	owner_hud = h

func build_quest_panel() -> void:
	var hud := owner_hud
	# 내용이 늘어 칸을 넘쳤다 — 패널을 세로로 키운다
	hud.quest_panel = hud._framed_panel(Vector2(1002, 230), Vector2(264, 250), hud.RED_DIM)
	var head := Label.new()
	head.text = "◈ 퀘스트 추적"
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", hud.GOLD)
	head.position = Vector2(12, 8)
	hud.quest_panel.add_child(head)

	hud.quest_lines = Label.new()
	hud.quest_lines.add_theme_font_size_override("font_size", 13)
	hud.quest_lines.add_theme_color_override("font_color", Color(0.86, 0.86, 0.9))
	hud.quest_lines.position = Vector2(12, 32)
	# 칸을 넘던 문제 — 패널 안쪽 폭에 맞추고 높이는 내용만큼 자란다
	hud.quest_lines.size = Vector2(236, 220)
	hud.quest_lines.clip_text = false
	hud.quest_lines.autowrap_mode = TextServer.AUTOWRAP_WORD
	hud.quest_panel.add_child(hud.quest_lines)

func build_center_status() -> void:
	var hud := owner_hud
	hud.phase_label = Label.new()
	hud.phase_label.add_theme_font_size_override("font_size", 21)
	hud.phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.phase_label.position = Vector2(390, 16)
	hud.phase_label.size = Vector2(500, 28)
	hud.add_child(hud.phase_label)

	hud.wave_label = Label.new()
	hud.wave_label.add_theme_font_size_override("font_size", 15)
	hud.wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.wave_label.add_theme_color_override("font_color", Color(0.87, 0.82, 0.87))
	hud.wave_label.position = Vector2(390, 44)
	hud.wave_label.size = Vector2(500, 22)
	hud.add_child(hud.wave_label)

	hud.timer_label = Label.new()
	hud.timer_label.add_theme_font_size_override("font_size", 14)
	hud.timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.timer_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))
	hud.timer_label.position = Vector2(340, 66)
	hud.timer_label.size = Vector2(600, 20)
	hud.add_child(hud.timer_label)

## 페이즈/웨이브/타이머 라벨 갱신
func update_phase_status() -> void:
	var hud := owner_hud
	if GameManager.phase == GameManager.Phase.DAY:
		hud.phase_label.text = "☀  낮 — 탐험"
		hud.phase_label.add_theme_color_override("font_color", Color(1, 0.75, 0.45))
		var drops := Battlefield.item_drops.size()
		hud.wave_label.text = "필드 아이템 %d" % drops
		hud.timer_label.text = "밤까지 %ds        [J] 바로 밤으로" % int(maxf(0.0, GameManager.phase_timer))
	else:
		hud.phase_label.text = "🌙  밤 — 방어"
		hud.phase_label.add_theme_color_override("font_color", Color(0.78, 0.55, 1.0))
		match GameManager.night_state:
			GameManager.NightState.WAVE:
				hud.wave_label.text = "WAVE %d / %d   (적 %d)" % [
					GameManager.wave_index + 1, GameManager.waves_tonight,
					Battlefield.live_enemy_count()]
				hud.timer_label.text = "웨이브 종료까지 %ds        [K] 밤 넘기기" % int(maxf(0.0, GameManager.phase_timer))
			GameManager.NightState.REST:
				hud.wave_label.text = "정비 시간"
				hud.timer_label.text = "다음 웨이브까지 %ds        [N] 즉시 시작" % int(maxf(0.0, GameManager.phase_timer))
			_:
				hud.wave_label.text = "웨이브 종료"
				hud.timer_label.text = "아침이 온다…"

## 퀘스트 추적 패널 갱신
## 다음에 할 일 한 줄. 위에서부터 내려가며 처음 걸리는 것을 쓴다.
## 순서는 "막힌 것 → 진행 중 → 다음 목표" 다.
func _next_step() -> String:
	# 1) 결과 화면
	if GameManager.game_won:
		return "포탈에 들어가 다음 회차로"
	# 2) 보스를 잡았다 — 나가는 문이 열려 있다
	if GameManager.chapter_boss_down:
		return "방주 앞 포탈로 들어가 다음 지역으로"

	# 3) 밤이면 지금 벌어지는 일
	if GameManager.phase == GameManager.Phase.NIGHT:
		match GameManager.night_state:
			GameManager.NightState.WAVE:
				return "웨이브 %d/%d 격퇴 — 방주를 지켜라" % [
					GameManager.wave_index + 1, GameManager.waves_tonight]
			GameManager.NightState.REST:
				return "정비 시간 — N 을 눌러 다음 웨이브"
			_:
				return "아침까지 버텨라"

	# 4) 낮 — 아직 안 밟은 랜드마크가 있으면 그리로
	var target: LandmarkData = null
	for d in LandmarkRegistry.landmarks:
		if not d.explored:
			target = d
			break
	if target != null:
		return "%s (미탐험 %d)" % [_short(target.display_name), _unexplored()]

	# 5) 전부 밟았는데 안 깬 곳이 남았다 — 밤에 싸워야 한다
	var uncleared := _uncleared()
	if uncleared != null:
		return "밤에 %s 공략 (J)" % _short(uncleared.display_name)

	# 6) 다 깼다 — 보스전
	return "지역 보스를 찾아 쓰러뜨려라 (J 로 밤 진입)"

## 이름이 길면 칸을 넘는다 — 앞부분만 남긴다
func _short(t: String, n: int = 10) -> String:
	return t if t.length() <= n else t.substr(0, n) + "…"

func _unexplored() -> int:
	var n := 0
	for d in LandmarkRegistry.landmarks:
		if not d.explored:
			n += 1
	return n

func _uncleared() -> LandmarkData:
	for d in LandmarkRegistry.landmarks:
		if not d.cleared:
			return d
	return null

func refresh_quest() -> void:
	var hud := owner_hud
	if hud.quest_lines == null:
		return
	var lines := []
	# ── 지금 할 일 ── 목록이 길어져 "뭘 해야 하는지" 가 묻혔다.
	# 맨 위에 딱 한 줄, 다음 행동만 크게 보여준다.
	lines.append("▶ %s" % _next_step())
	lines.append("")
	# 레벨을 어딘가에는 보여야 한다 — 랜드마크의 "추천 레벨"과 비교할 기준이 없으면
	# 탐험 보상으로 오르는 레벨이 플레이어에게 보이지 않는다
	lines.append("◆ Lv %d   (%d / %d)" % [GameManager.player_level,
		GameManager.player_exp, GameManager.exp_to_next()])
	lines.append("◆ 차원문 봉인  %d / %d" % [GameManager.seals_done, DemoDirector.seals_needed()])
	if GameManager.phase == GameManager.Phase.DAY:
		lines.append("  - 정비 · 장비 정리 (J 로 밤 진입)")
	else:
		match GameManager.night_state:
			GameManager.NightState.WAVE:
				lines.append("  - 웨이브 %d/%d 격퇴" % [GameManager.wave_index + 1, GameManager.waves_tonight])
			GameManager.NightState.REST:
				lines.append("  - 정비 중 (N 즉시 진행)")
			_:
				lines.append("  - 아침을 기다린다")
	# 랜드마크 탐험 진행도 — 낮에 갈 곳을 알려준다
	var lm_total: int = LandmarkRegistry.landmarks.size()
	if lm_total > 0:
		lines.append("◆ 랜드마크 탐험  %d / %d" % [LandmarkRegistry.explored_count(), lm_total])
		var cur: LandmarkData = LandmarkRegistry.current
		if cur != null:
			lines.append("  ▸ %s%s" % [cur.display_name, "  (클리어)" if cur.cleared else ""])
		elif GameManager.phase == GameManager.Phase.DAY:
			var next_lm := _nearest_unexplored()
			if next_lm != null:
				lines.append("  - 미탐험: %s" % next_lm.display_name)
	if GameManager.seals_done >= DemoDirector.seals_needed():
		lines.append("◆ 최후의 군주를 격파하라")
	hud.quest_lines.text = "\n".join(lines)

## 플레이어에게 가장 가까운 미탐험 랜드마크 (다음 목표 안내용)
func _nearest_unexplored() -> LandmarkData:
	var p := Battlefield.player
	if p == null or not is_instance_valid(p):
		return null
	var best: LandmarkData = null
	var best_d := INF
	for lm in LandmarkRegistry.landmarks:
		if lm.explored:
			continue
		# 잠긴 곳은 안내하지 않는다 — 가 봐야 문전박대라 목표로 쓸모가 없다
		if LandmarkRegistry.is_locked(lm.id):
			continue
		var d: float = p.global_position.distance_to(lm.center)
		if d < best_d:
			best_d = d
			best = lm
	return best
