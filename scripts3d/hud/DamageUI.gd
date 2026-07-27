extends Node
class_name DamageUI
## 피해 피드백 담당 — 저체력 비네트(화면 가장자리 붉은 맥동).
## (적 머리 위 데미지 숫자는 EnemyAnimation 이 3D 공간에 직접 그린다)

const LOW_HP_RATIO := 0.3     ## 이 비율 미만이면 비네트가 맥동한다

var owner_hud: CanvasLayer

func setup(h: CanvasLayer) -> void:
	owner_hud = h

func build() -> void:
	owner_hud.vignette = ColorRect.new()
	owner_hud.vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner_hud.vignette.color = Color(0.7, 0.05, 0.05, 0.0)
	owner_hud.vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner_hud.add_child(owner_hud.vignette)

## 체력 비율에 따라 비네트 강도를 갱신한다
func update_vignette(hp_ratio: float) -> void:
	owner_hud.vignette.color.a = \
		(0.12 + 0.12 * sin(Time.get_ticks_msec() / 180.0)) if hp_ratio < LOW_HP_RATIO else 0.0
