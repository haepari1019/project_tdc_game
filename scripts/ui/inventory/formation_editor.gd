extends Panel
## Top-down formation editor (F-003 / UI-005) — 4 role tokens draggable in local formation
## space (center = anchor/leader; up = forward, right = +x). Dragging a token sets that class's
## slot offset. setup(class_offsets, colors); get_offsets() → {class_id: Vector2(x, z)}.

const SIZE := 220.0
const SCALE := 28.0     # px per metre
const CLAMP_M := 3.6    # max offset from the anchor
const TOKEN := 26.0

var _offsets: Dictionary = {}     # class_id -> Vector2(x, z=forward)
var _tokens: Dictionary = {}      # class_id -> Panel
var _drag_cid: String = ""
var _drag_off: Vector2


func setup(class_offsets: Dictionary, colors: Dictionary) -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08, 0.92)
	sb.border_color = Color(0.30, 0.34, 0.40)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", sb)
	# Anchor marker (the leader / controlled char) at the center.
	var center := ColorRect.new()
	center.color = Color(0.6, 0.65, 0.7, 0.5)
	center.size = Vector2(8, 8)
	center.position = Vector2(SIZE * 0.5 - 4, SIZE * 0.5 - 4)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	for cid in class_offsets:
		_offsets[cid] = class_offsets[cid]
		_add_token(String(cid), colors.get(cid, Color(0.7, 0.7, 0.7)))
	_layout_tokens()


func get_offsets() -> Dictionary:
	return _offsets


func _add_token(cid: String, color: Color) -> void:
	var t := Panel.new()
	t.custom_minimum_size = Vector2(TOKEN, TOKEN)
	t.size = Vector2(TOKEN, TOKEN)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE   # the editor handles the drag itself
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(TOKEN * 0.5))
	sb.border_color = color.lightened(0.4)
	sb.set_border_width_all(2)
	t.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = cid.substr(0, 1)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(lbl)
	add_child(t)
	_tokens[cid] = t


func _layout_tokens() -> void:
	for cid in _offsets:
		_place_token(String(cid), _offsets[cid])


func _place_token(cid: String, o: Vector2) -> void:
	var c := Vector2(SIZE * 0.5 + o.x * SCALE, SIZE * 0.5 - o.y * SCALE)  # +z = up
	_tokens[cid].position = c - Vector2(TOKEN * 0.5, TOKEN * 0.5)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			for cid in _tokens:
				var t: Panel = _tokens[cid]
				if Rect2(t.position, t.size).has_point(mb.position):
					_drag_cid = String(cid)
					_drag_off = mb.position - t.position
					break
		else:
			_drag_cid = ""
	elif event is InputEventMouseMotion and _drag_cid != "":
		var c := (event as InputEventMouseMotion).position - _drag_off + Vector2(TOKEN * 0.5, TOKEN * 0.5)
		var ox := clampf((c.x - SIZE * 0.5) / SCALE, -CLAMP_M, CLAMP_M)
		var oz := clampf(-(c.y - SIZE * 0.5) / SCALE, -CLAMP_M, CLAMP_M)
		_offsets[_drag_cid] = Vector2(ox, oz)
		_place_token(_drag_cid, _offsets[_drag_cid])
