extends Node
class_name MiniMapUI
## 우상단 원형 미니맵 담당 — 붉은 링 프레임과 MiniMap3D(레이더) 배치.

var owner_hud: CanvasLayer

func setup(h: CanvasLayer) -> void:
	owner_hud = h

func build() -> void:
	var hud := owner_hud
	var ring := Panel.new()
	ring.position = Vector2(1062, 12)
	ring.size = Vector2(206, 206)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.04, 0.92)
	sb.border_color = hud.RED
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(103)
	sb.shadow_color = Color(hud.RED.r, hud.RED.g, hud.RED.b, 0.4)
	sb.shadow_size = 8
	ring.add_theme_stylebox_override("panel", sb)
	hud.add_child(ring)

	hud.mini_map = load("res://scripts3d/MiniMap3D.gd").new()
	hud.mini_map.position = Vector2(1065, 15)
	hud.add_child(hud.mini_map)
