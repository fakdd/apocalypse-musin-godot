extends Control
class_name CooldownArc
## 스킬 아이콘 위에 도는 회색 쿨다운 암영.
##
## ColorRect 로 위에서 아래로 채우던 방식은 "얼마나 남았는지"가 잘 안 읽혔다.
## 12시 방향에서 시계 방향으로 도는 부채꼴이 훨씬 직관적이다.
## 새 노드 타입 하나만 늘리고, 나머지 스킬 UI 구조는 그대로 쓴다.

var ratio := 0.0:            ## 1.0 = 완전히 덮임(쿨다운 시작), 0.0 = 준비 완료
	set(v):
		var nv: float = clampf(v, 0.0, 1.0)
		if absf(nv - ratio) < 0.001:
			return
		ratio = nv
		visible = ratio > 0.001
		queue_redraw()

var shade := Color(0, 0, 0, 0.62)
var edge := Color(1.0, 0.95, 0.85, 0.5)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _draw() -> void:
	if ratio <= 0.001:
		return
	var c := size * 0.5
	var r: float = maxf(size.x, size.y) * 0.72      ## 모서리까지 덮도록 넉넉히
	var start := -PI * 0.5                          ## 12시
	var sweep := TAU * ratio

	# 부채꼴을 삼각형 부채로 그린다 (draw_arc 는 선만 그린다)
	var steps: int = maxi(6, int(48.0 * ratio))
	var pts := PackedVector2Array()
	pts.append(c)
	for i in range(steps + 1):
		var a: float = start + sweep * (float(i) / float(steps))
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, shade)

	# 남은 구간의 경계선 — 줄어드는 것이 눈에 잡힌다
	if ratio < 0.999:
		var ea := start + sweep
		draw_line(c, c + Vector2(cos(ea), sin(ea)) * r, edge, 2.0)
