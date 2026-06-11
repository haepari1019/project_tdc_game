extends Control
## UI-002 Party Sheet (4) — top-left. Portrait(PH role color) + HP bar +
## controlled emphasis (border + opacity). Dead=gray. Sub-skill cooldown radials
## (3 slots, Q·E·R; clock style). Final skin = A4. ref: docs/ui/UI-002.

const RadialCooldown := preload("res://scripts/ui/radial_cooldown.gd")
const UiColors := preload("res://scripts/core/ui_colors.gd")

const SLOT_W := 204
const PORTRAIT := 40
const BAR_H := 12
const RADIAL := 22
const SUB_SLOTS := 3
const STATUS_SLOTS := 4   # UI-002 §3: ~2 buff + 2 debuff
const STATUS_PIP := 15

var _members: Array = []
var _slots: Array = []  # {panel, sb, portrait, hp_fill, radials[3]}


func setup(members: Array) -> void:
	_members = members
	for c in get_children():
		c.queue_free()
	_slots.clear()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)
	for m in members:
		_slots.append(_build_slot(vb, m))


func _build_slot(parent: Node, m) -> Dictionary:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.55)
	sb.border_color = Color(1, 1, 1)
	sb.set_content_margin_all(5)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_W, 0)
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)

	var port := ColorRect.new()
	port.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	port.color = m.get_class_color()
	port.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(port)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)

	# Top row: class name (left) + 3 sub-skill cooldown radials (right).
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	col.add_child(top)
	var name_lbl := Label.new()
	name_lbl.text = String(m.class_id)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(name_lbl)
	var cc: Color = m.get_class_color()
	var radials: Array = []
	for slot in SUB_SLOTS:
		var r := RadialCooldown.new()
		r.custom_minimum_size = Vector2(RADIAL, RADIAL)
		if slot == 0:
			r.set_icon_color(cc.lightened(0.18))
		else:
			r.set_empty(true)  # unequipped sub slot 2/3 (placeholder)
		top.add_child(r)
		radials.append(r)

	# Bottom row: HP bar (expand) + buff/debuff status pips (UI-002 §3).
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 3)
	col.add_child(bottom)
	var hp_bg := ColorRect.new()
	hp_bg.custom_minimum_size = Vector2(0, BAR_H)
	hp_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_bg.color = Color(0.05, 0.05, 0.05, 0.9)
	bottom.add_child(hp_bg)
	var hp_fill := ColorRect.new()
	hp_fill.color = Color(0.3, 0.85, 0.35)
	hp_fill.anchor_left = 0.0
	hp_fill.anchor_top = 0.0
	hp_fill.anchor_right = 1.0
	hp_fill.anchor_bottom = 1.0
	hp_bg.add_child(hp_fill)

	var status_pips: Array = []
	for _i in STATUS_SLOTS:
		var sp := RadialCooldown.new()
		sp.custom_minimum_size = Vector2(STATUS_PIP, STATUS_PIP)
		sp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sp.visible = false
		bottom.add_child(sp)
		status_pips.append(sp)

	return {
		"panel": panel, "sb": sb, "portrait": port, "hp_fill": hp_fill,
		"radials": radials, "status_pips": status_pips,
	}


func _process(_delta: float) -> void:
	for i in _slots.size():
		if i >= _members.size():
			continue
		var m = _members[i]
		if not is_instance_valid(m):
			continue
		var s: Dictionary = _slots[i]
		var alive: bool = m.is_alive()
		var ratio: float = clampf(m.hp / maxf(m.max_hp, 1.0), 0.0, 1.0) if alive else 0.0
		s.hp_fill.anchor_right = ratio
		s.hp_fill.color = _hp_color(ratio)
		var controlled: bool = m.is_controlled()
		s.sb.set_border_width_all(3 if controlled else 0)
		s.panel.modulate.a = 1.0 if controlled else 0.6
		if alive:
			s.portrait.color = m.get_class_color()
		else:
			s.portrait.color = Color(0.32, 0.32, 0.34)
		# Sub slot 0 = equipped sub cooldown (remaining / total). Slots 1·2 empty.
		var total: float = float(m.sub_params.get("cooldown_s", 0.0))
		s.radials[0].set_cd(m.sub_cooldown_s / total if total > 0.0 else 0.0)
		# Buff/debuff overlay — colored arc = remaining time (UI-002 §3).
		var sl: Array = m.get_status_list()
		var pips: Array = s.status_pips
		for j in pips.size():
			if j < sl.size():
				var st: Dictionary = sl[j]
				pips[j].set_icon_color(st.color)
				pips[j].set_cd(st.ratio)
				pips[j].visible = true
			else:
				pips[j].visible = false


func _hp_color(r: float) -> Color:
	return UiColors.hp_color(r)


## The party member whose portrait is under the cursor (for revive-target clicks). null if none.
func portrait_member_under(mouse: Vector2) -> Node:
	for i in mini(_slots.size(), _members.size()):
		var port: Control = _slots[i].portrait
		if is_instance_valid(port) and port.get_global_rect().has_point(mouse):
			return _members[i]
	return null
