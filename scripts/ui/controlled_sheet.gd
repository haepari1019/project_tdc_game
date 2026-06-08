extends Control
## UI-003 Controlled Character Sheet — bottom center. Portrait + HP bar +
## action bar: Identity(auto) + sub slots Q/E/R with clock cooldown radials.
## (Resource bar omitted — no mana system yet.) Final skin = A4.

const RadialCooldown := preload("res://scripts/ui/radial_cooldown.gd")
const UiColors := preload("res://scripts/core/ui_colors.gd")

const SLOT := 42
const HP_W := 230

var _party: Node
var _portrait: ColorRect
var _name_lbl: Label
var _hp_fill: ColorRect
var _slots: Array = []  # {radial, kind}  kind: "identity" | "sub0" | "empty"


func setup(party: Node) -> void:
	_party = party
	for c in get_children():
		c.queue_free()
	_slots.clear()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 0.62)
	sb.set_content_margin_all(9)
	sb.set_corner_radius_all(5)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	panel.add_child(hb)

	_portrait = ColorRect.new()
	_portrait.custom_minimum_size = Vector2(52, 52)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_portrait)

	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 5)
	hb.add_child(col)
	_name_lbl = Label.new()
	col.add_child(_name_lbl)
	var hp_bg := ColorRect.new()
	hp_bg.custom_minimum_size = Vector2(HP_W, 16)
	hp_bg.color = Color(0.05, 0.05, 0.05, 0.9)
	col.add_child(hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.3, 0.85, 0.35)
	_hp_fill.anchor_right = 1.0
	_hp_fill.anchor_bottom = 1.0
	hp_bg.add_child(_hp_fill)

	# Action bar: Identity(auto) + Q + E + R.
	for d in [["auto", "identity"], ["Q", "sub0"], ["E", "empty"], ["R", "empty"]]:
		var sv := VBoxContainer.new()
		sv.add_theme_constant_override("separation", 2)
		hb.add_child(sv)
		var r := RadialCooldown.new()
		r.custom_minimum_size = Vector2(SLOT, SLOT)
		if String(d[1]) == "empty":
			r.set_empty(true)
		sv.add_child(r)
		var kl := Label.new()
		kl.text = String(d[0])
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sv.add_child(kl)
		_slots.append({"radial": r, "kind": String(d[1])})


func _process(_delta: float) -> void:
	if _party == null:
		return
	var m: CharacterBody3D = _party.get_controlled()
	if m == null or not is_instance_valid(m):
		visible = false
		return
	visible = true
	var alive: bool = m.is_alive()
	var rc: Color = m.get_class_color()
	_portrait.color = rc if alive else Color(0.32, 0.32, 0.34)
	_name_lbl.text = String(m.class_id)
	var hr: float = clampf(m.hp / maxf(m.max_hp, 1.0), 0.0, 1.0) if alive else 0.0
	_hp_fill.anchor_right = hr
	_hp_fill.color = _hp_color(hr)
	for s in _slots:
		match String(s.kind):
			"identity":
				s.radial.set_icon_color(rc)
				var t: float = float(m.identity_params.get("cooldown_s", 0.0))
				s.radial.set_cd(m.identity_cooldown_s / t if t > 0.0 else 0.0)
			"sub0":
				s.radial.set_icon_color(rc.lightened(0.18))
				var t2: float = float(m.sub_params.get("cooldown_s", 0.0))
				s.radial.set_cd(m.sub_cooldown_s / t2 if t2 > 0.0 else 0.0)


func _hp_color(r: float) -> Color:
	return UiColors.hp_color(r)
