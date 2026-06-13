extends Panel
## Run settlement screen (F-007 §3.8) — a centered fixed box with a category roll-up and a
## scrollable item list. PURE PRESENTATION: driven by the run_settled(summary) payload that
## the scene composes (survivors/casualties + At-Risk→Safe / Loss Bundle). Add it to the HUD
## and connect run_controller.run_settled → show_settlement. ref: F-007 §3.6/§3.7/§3.8.

var _sb: StyleBoxFlat
var _title: Label
var _sub: Label
var _section: Label
var _body: Label
var _foot: Label


func _ready() -> void:
	visible = false
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -260.0
	offset_right = 260.0
	offset_top = -220.0
	offset_bottom = 220.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sb = StyleBoxFlat.new()
	_sb.bg_color = Color(0.06, 0.07, 0.10, 0.97)
	_sb.set_border_width_all(2)
	_sb.border_color = Color(0.55, 1.0, 0.6)
	_sb.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", _sb)
	_build()


func _build() -> void:
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left", 26)
	mc.add_theme_constant_override("margin_right", 26)
	mc.add_theme_constant_override("margin_top", 20)
	mc.add_theme_constant_override("margin_bottom", 18)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mc)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_child(vb)

	_title = _label(vb, 30, HORIZONTAL_ALIGNMENT_CENTER, Color(0.55, 1.0, 0.6))
	_sub = _label(vb, 16, HORIZONTAL_ALIGNMENT_CENTER, Color(0.86, 0.89, 0.93))
	vb.add_child(HSeparator.new())
	_section = _label(vb, 15, HORIZONTAL_ALIGNMENT_LEFT, Color(0.78, 0.83, 0.90))

	# scrollable detail box — absorbs any overflow so the list never spills the panel.
	var scrollbox := PanelContainer.new()
	scrollbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scrollbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset := StyleBoxFlat.new()
	inset.bg_color = Color(0.0, 0.0, 0.0, 0.28)
	inset.set_corner_radius_all(4)
	inset.set_content_margin_all(7)
	scrollbox.add_theme_stylebox_override("panel", inset)
	vb.add_child(scrollbox)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scrollbox.add_child(scroll)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 14)
	_body.modulate = Color(0.92, 0.94, 0.97)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_body)

	_foot = _label(vb, 13, HORIZONTAL_ALIGNMENT_LEFT, Color(0.62, 0.67, 0.74))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vb.add_child(spacer)
	var hint := _label(vb, 12, HORIZONTAL_ALIGNMENT_CENTER, Color(0.55, 0.60, 0.68))
	hint.text = "(Esc → menu)"


func _label(parent: Node, size: int, align: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = align
	l.modulate = col
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Fill + show. Success/Partial: At-Risk → Safe list. Failure: Loss Bundle (회수 후보).
## 장착 Identity Gear은 항상 Safe.
func show_settlement(summary: Dictionary) -> void:
	var failed := String(summary.get("cause", "")) != ""
	var col := Color(1.0, 0.45, 0.3) if failed else Color(0.55, 1.0, 0.6)
	_sb.border_color = col
	_title.modulate = col
	if failed:
		_title.text = "✖ RUN FAILURE"
		_sub.text = "파티 전멸 · %s" % String(summary.get("cause", ""))
		var lost: Array = summary.get("lost_items", [])
		_section.text = "Loss Bundle · 회수 후보 — %s" % _category_summary(lost)
		_body.text = _item_lines(lost)
		_foot.text = "장착 Identity Gear = Safe (보존)"
	else:
		_title.text = "★ EXTRACTION SUCCESS ★"
		var surv: Array = summary.get("survivors", [])
		var cas: Array = summary.get("casualties", [])
		var s := "생존 %d" % surv.size()
		if not cas.is_empty():
			s = "부분 탈출 · " + s + " · 전사 %d (%s)" % [cas.size(), ", ".join(cas)]
		_sub.text = s
		var safe: Array = summary.get("safe_items", [])
		_section.text = "루트 정산 · At-Risk → Safe — %s" % _category_summary(safe)
		_body.text = _item_lines(safe, " → Safe")
		_foot.text = "장착 Identity Gear = Safe"
	visible = true


## Category roll-up (장비/스킬북/소모품) + total stacks for the summary line.
func _category_summary(items: Array) -> String:
	var g := 0
	var s := 0
	var c := 0
	var o := 0
	for it in items:
		match String(it.get("kind", "")):
			"gear": g += 1
			"skillbook": s += 1
			"consumable": c += 1
			_: o += 1
	var parts: Array = []
	if g > 0:
		parts.append("장비 %d" % g)
	if s > 0:
		parts.append("스킬북 %d" % s)
	if c > 0:
		parts.append("소모품 %d" % c)
	if o > 0:
		parts.append("기타 %d" % o)
	if parts.is_empty():
		return "없음"
	return "%s · 총 %d" % [" · ".join(parts), items.size()]


func _item_lines(items: Array, suffix: String = "") -> String:
	if items.is_empty():
		return "  (없음)"
	var lines: Array = []
	for it in items:
		lines.append("  • %s%s%s" % [String(it.get("label", "?")), _qty(it), suffix])
	return "\n".join(lines)


func _qty(it: Dictionary) -> String:
	var c := int(it.get("count", 1))
	return " ×%d" % c if c > 1 else ""
