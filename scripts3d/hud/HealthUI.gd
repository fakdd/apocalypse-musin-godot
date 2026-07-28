extends Node
class_name HealthUI
## 좌상단 상태 표시 담당 — 초상화, 이름/특성/일차, HP/내공 바,
## 장비 요약 · 마석 · 방주 HP · 처치 수 라벨.

const BAR_WIDTH := 210.0

var owner_hud: CanvasLayer

func setup(h: CanvasLayer) -> void:
	owner_hud = h

func build() -> void:
	var hud := owner_hud
	var panel: Panel = hud._framed_panel(Vector2(16, 14), Vector2(340, 96))

	var portrait := Panel.new()
	portrait.position = Vector2(8, 7)
	portrait.size = Vector2(82, 82)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.14, 0.05, 0.06)
	psb.border_color = hud.GOLD
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(41)
	portrait.add_theme_stylebox_override("panel", psb)
	panel.add_child(portrait)

	# 실제 주인공 모델을 SubViewport 로 렌더해 초상화로 쓴다
	hud.portrait_holder = hud._make_model_viewport(portrait, Vector2(78, 78),
		"res://assets3d/chars/hero.tscn", Vector3(0, 1.02, 3.15), Vector3(-2, 0, 0), 34.0)

	hud.name_label = Label.new()
	hud.name_label.text = "강백현"
	hud.name_label.add_theme_font_size_override("font_size", 19)
	hud.name_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.93))
	hud.name_label.position = Vector2(100, 6)
	panel.add_child(hud.name_label)

	hud.level_label = Label.new()
	hud.level_label.add_theme_font_size_override("font_size", 14)
	hud.level_label.add_theme_color_override("font_color", hud.GOLD)
	hud.level_label.position = Vector2(268, 11)
	panel.add_child(hud.level_label)

	hud.hp_bar = hud._bar(panel, Vector2(100, 32), Vector2(BAR_WIDTH, 16), hud.RED)
	hud.hp_text = Label.new()
	hud.hp_text.add_theme_font_size_override("font_size", 11)
	hud.hp_text.add_theme_color_override("font_color", Color(1, 0.92, 0.92))
	hud.hp_text.position = Vector2(104, 32)
	panel.add_child(hud.hp_text)

	hud.mp_bar = hud._bar(panel, Vector2(100, 53), Vector2(BAR_WIDTH, 14), Color(0.22, 0.45, 0.9))
	hud.mp_text = Label.new()
	hud.mp_text.add_theme_font_size_override("font_size", 11)
	hud.mp_text.add_theme_color_override("font_color", Color(0.86, 0.93, 1))
	hud.mp_text.position = Vector2(104, 52)
	panel.add_child(hud.mp_text)

	hud.trait_label = Label.new()
	hud.trait_label.add_theme_font_size_override("font_size", 13)
	hud.trait_label.position = Vector2(100, 72)
	panel.add_child(hud.trait_label)

	hud.gear_label = Label.new()
	hud.gear_label.add_theme_font_size_override("font_size", 12)
	hud.gear_label.add_theme_color_override("font_color", Color(0.74, 0.77, 0.84))
	hud.gear_label.position = Vector2(20, 118)
	hud.add_child(hud.gear_label)

	hud.essence_label = Label.new()
	hud.essence_label.add_theme_font_size_override("font_size", 13)
	hud.essence_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	hud.essence_label.position = Vector2(20, 138)
	hud.add_child(hud.essence_label)

	hud.base_label = Label.new()
	hud.base_label.add_theme_font_size_override("font_size", 14)
	hud.base_label.position = Vector2(20, 160)
	hud.add_child(hud.base_label)

	hud.kill_label = Label.new()
	hud.kill_label.add_theme_font_size_override("font_size", 13)
	hud.kill_label.add_theme_color_override("font_color", Color(0.8, 0.72, 0.72))
	hud.kill_label.position = Vector2(20, 182)
	hud.add_child(hud.kill_label)

## 특성/일차 라벨 갱신
func update_identity() -> void:
	var hud := owner_hud
	if TraitManager.has_trait():
		var r: int = TraitManager.get_trait_rarity()
		hud.trait_label.text = "%s %s" % [RarityEnums.get_rarity_tag(r), TraitManager.get_trait_name()]
		hud.trait_label.add_theme_color_override("font_color", RarityEnums.get_rarity_color(r))
	hud.level_label.text = "Day %d" % GameManager.day_count

## HP/내공 바 갱신. 반환: 체력 비율 (비네트 갱신에 쓴다)
## 게이지가 값에 딱 붙어 움직이면 피해량이 얼마인지 눈에 안 들어온다.
## 목표치로 부드럽게 따라가게 해 "깎이는 것"이 보이게 한다.
var _hp_shown := -1.0
var _ult_shown := -1.0

func update_bars(player) -> float:
	var hud := owner_hud
	var hr: float = clampf(player.hp / maxf(player.max_hp, 1.0), 0.0, 1.0)
	var k: float = clampf(owner_hud.get_process_delta_time()
		* CombatFeel.num("ui", "bar_lerp", 9.0), 0.0, 1.0)
	if _hp_shown < 0.0:
		_hp_shown = hr
	# 늘어날 때는 즉시, 줄어들 때만 천천히 (회복은 바로 보여야 안심이 된다)
	_hp_shown = hr if hr > _hp_shown else lerpf(_hp_shown, hr, k)
	hud.hp_bar.size.x = BAR_WIDTH * _hp_shown
	hud.hp_text.text = "HP  %d / %d" % [int(player.hp), int(player.max_hp)]
	var ur: float = clampf(player.ult_gauge / maxf(player.ult_max, 1.0), 0.0, 1.0)
	if _ult_shown < 0.0:
		_ult_shown = ur
	_ult_shown = lerpf(_ult_shown, ur, k)
	hud.mp_bar.size.x = BAR_WIDTH * _ult_shown
	hud.mp_text.text = "내공  %d%%" % int(ur * 100)
	return hr

## 장비 요약 · 마석 · 펫 · 방주 HP · 처치 수 갱신
func update_resources() -> void:
	var hud := owner_hud
	hud.gear_label.text = "공격 %.0f · 속도 %.1f  |  %s" % [
		PlayerStats.get_final_atk(), PlayerStats.get_final_speed(), PlayerStats.get_equipped_summary()]
	var pet_name := "없음"
	if PetManager.active != "":
		pet_name = String(PetManager.get_info(PetManager.active).get("name", PetManager.active))
	hud.essence_label.text = "◇ 마석 %d      🐾 %s  (P 교체 %d종)" % [
		CraftManager.essence, pet_name, PetManager.owned.size()]
	hud.base_label.text = "방주 HP  %d / %d" % [int(GameManager.base_hp), int(GameManager.base_max_hp)]
	hud.base_label.add_theme_color_override("font_color",
		Color(1, 0.4, 0.4) if GameManager.base_hp < GameManager.base_max_hp * 0.35 else Color(0.6, 0.85, 1.0))
	hud.kill_label.text = "처치 %d" % GameManager.kill_count
