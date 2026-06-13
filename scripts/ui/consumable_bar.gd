extends Control
## Consumable hotkey bar — 3 slots (Z/X/C) just above the controlled char sheet (6 o'clock).
## Shows the assigned consumable + total held count. Assign/use logic lives in InventoryUI;
## this node is display + a drop hit-target (slot_under). ref: F-010 consumables.

signal slot_grabbed(slot: int)  # left-press on a filled slot → InventoryUI starts a hotkey drag

const SLOT_W := 92
const SLOT_H := 40
const KEYS := ["Z", "X", "C"]

var _slots: Array = []  # {panel, label}
var _last_data: Array = []   # last refresh payload, so clear_carry can restore a slot
var _carry_slot: int = -1    # slot currently overlaid by a carried object (torch); -1 = none


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	var w := 3 * SLOT_W + 2 * 8
	offset_left = -w * 0.5
	offset_right = w * 0.5
	offset_top = -162.0   # lift above the controlled sheet
	offset_bottom = -100.0
	_build()


func _build() -> void:
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hb)
	for i in 3:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(v)
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(SLOT_W, SLOT_H)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE  # set STOP only while inventory open
		slot.gui_input.connect(_on_slot_input.bind(i))
		slot.add_theme_stylebox_override("panel", _slot_style(Color(0.12, 0.14, 0.12), Color(0.4, 0.5, 0.4)))
		var lbl := Label.new()
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.text = "—"
		slot.add_child(lbl)
		v.add_child(slot)
		var key := Label.new()
		key.text = KEYS[i]
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key.add_theme_font_size_override("font_size", 10)
		v.add_child(key)
		_slots.append({"panel": slot, "label": lbl})


func _slot_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(bg.r, bg.g, bg.b, 0.7)
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	return sb


## data: Array of 3 dicts — {} (empty) or {name, count, color}.
func refresh(data: Array) -> void:
	_last_data = data
	for i in mini(_slots.size(), data.size()):
		if i == _carry_slot:
			continue   # a carried object owns this slot's display (set_carry)
		_render_slot(i, data[i])


func _render_slot(i: int, d: Dictionary) -> void:
	var s = _slots[i]
	if d.is_empty():
		s.label.text = "—"
		s.panel.add_theme_stylebox_override("panel", _slot_style(Color(0.12, 0.14, 0.12), Color(0.4, 0.5, 0.4)))
	else:
		s.label.text = "%s\nx%d" % [String(d.get("name", "")), int(d.get("count", 0))]
		var col: Color = d.get("color", Color(0.6, 0.85, 0.6))
		s.panel.add_theme_stylebox_override("panel", _slot_style(col, col.lightened(0.3)))


## Overlay a slot with a carried object (torch) — distinct fiery tint + label (F-021 carry).
func set_carry(slot: int, text: String) -> void:
	if slot < 0 or slot >= _slots.size():
		return
	_carry_slot = slot
	var s = _slots[slot]
	s.label.text = text
	s.panel.add_theme_stylebox_override("panel", _slot_style(Color(1.0, 0.5, 0.15), Color(1.0, 0.72, 0.3)))


## Clear the carry overlay and restore the slot from the last refresh data.
func clear_carry() -> void:
	var slot := _carry_slot
	_carry_slot = -1
	if slot >= 0 and slot < _slots.size():
		var d: Dictionary = _last_data[slot] if slot < _last_data.size() else {}
		_render_slot(slot, d)


func slot_under(mouse: Vector2) -> int:
	for i in _slots.size():
		if (_slots[i].panel as Control).get_global_rect().has_point(mouse):
			return i
	return -1


func _on_slot_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).pressed:
		slot_grabbed.emit(slot)
		accept_event()


## Slots only receive input (draggable) while the inventory is open — so they never eat
## gameplay clicks during normal play.
func set_interactive(on: bool) -> void:
	for s in _slots:
		(s.panel as Control).mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
