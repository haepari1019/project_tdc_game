extends Control
## Clockwise radial cooldown overlay (UI-003 style). ratio 0 = ready, 1 = full cd.
## Gray wedge shrinks clockwise from top as the cooldown counts down.

const RichTooltip := preload("res://scripts/ui/rich_tooltip.gd")

var ratio: float = 0.0
var icon_color: Color = Color(0.55, 0.55, 0.62)
var empty: bool = false


## 스킬 슬롯 툴팁을 BBCode(색)로 렌더 — tooltip_text에 색 태그(affix/패널티)를 넣을 수 있게.
func _make_custom_tooltip(for_text: String) -> Object:
	return RichTooltip.make(for_text)


## Mark an unequipped sub slot (dim placeholder, no wedge).
func set_empty(e: bool) -> void:
	empty = e
	if e:
		icon_color = Color(0.16, 0.16, 0.19, 0.5)
	queue_redraw()


func set_cd(r: float) -> void:
	var c := clampf(r, 0.0, 1.0)
	if absf(c - ratio) > 0.002:
		ratio = c
		queue_redraw()


func set_icon_color(col: Color) -> void:
	if col == icon_color:
		return
	icon_color = col
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	draw_circle(center, radius, icon_color)
	draw_arc(center, radius, 0.0, TAU, 24, Color(0, 0, 0, 0.55), 1.5, true)
	if ratio > 0.002:
		var pts := PackedVector2Array()
		pts.append(center)
		var steps := 28
		var start := -PI / 2.0  # top
		for i in range(steps + 1):
			var a := start + TAU * ratio * (float(i) / float(steps))  # clockwise
			pts.append(center + Vector2(cos(a), sin(a)) * radius)
		draw_colored_polygon(pts, Color(0.05, 0.05, 0.06, 0.66))
