extends Control
## Enemy info panel — top-center (12 o'clock). Borrows the party-sheet slot style:
## enemy portrait + name + HP bar (+ buff/debuff pips IF the enemy ever exposes a status
## list — enemies have none yet, so that row stays empty). Shown when an enemy is left-
## clicked; hidden when it dies or selection clears. No skills/cooldowns (per design).
## ref: UI-002 style. Mouse-transparent so it never eats gameplay clicks.

const RadialCooldown := preload("res://scripts/ui/radial_cooldown.gd")
const UiColors := preload("res://scripts/core/ui_colors.gd")

const PANEL_W := 264.0
const PANEL_H := 72.0
const PORTRAIT := 46
const BAR_H := 14
const STATUS_SLOTS := 4
const STATUS_PIP := 15

var _enemy: Node = null
var _portrait: ColorRect
var _name_lbl: Label
var _hp_fill: ColorRect
var _hp_lbl: Label
var _status_pips: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -PANEL_W * 0.5
	offset_right = PANEL_W * 0.5
	offset_top = 12.0
	offset_bottom = 12.0 + PANEL_H
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func set_enemy(e: Node) -> void:
	_enemy = e
	visible = e != null
	if e != null:
		_refresh()


func clear() -> void:
	_enemy = null
	visible = false


func _process(_delta: float) -> void:
	if _enemy == null:
		return
	if not is_instance_valid(_enemy) or _enemy.hp <= 0.0:
		clear()
		return
	_refresh()


func _refresh() -> void:
	if _portrait == null:
		return
	_portrait.color = _enemy.get_body_color() if _enemy.has_method("get_body_color") else Color(0.7, 0.3, 0.3)
	var nm := String(_enemy.display_name) if "display_name" in _enemy else ""
	_name_lbl.text = nm if not nm.is_empty() else "Enemy"
	var ratio: float = clampf(_enemy.hp / maxf(_enemy.max_hp, 1.0), 0.0, 1.0)
	_hp_fill.anchor_right = ratio
	_hp_fill.color = UiColors.hp_color(ratio)
	_hp_lbl.text = "%d / %d" % [int(ceil(_enemy.hp)), int(ceil(_enemy.max_hp))]
	var sl: Array = _enemy.get_status_list() if _enemy.has_method("get_status_list") else []
	for j in _status_pips.size():
		var pip: Control = _status_pips[j]
		if j < sl.size():
			var st: Dictionary = sl[j]
			pip.set_icon_color(st.color)
			pip.set_cd(st.ratio)
			pip.visible = true
		else:
			pip.visible = false


func _build() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.05, 0.06, 0.80)        # reddish tint vs the party panels
	sb.border_color = Color(0.85, 0.35, 0.32, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(6)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	_portrait = ColorRect.new()
	_portrait.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_portrait)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_name_lbl = Label.new()
	_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_lbl.add_theme_font_size_override("font_size", 15)
	top.add_child(_name_lbl)
	_hp_lbl = Label.new()
	_hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_lbl.add_theme_font_size_override("font_size", 12)
	top.add_child(_hp_lbl)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 3)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bottom)
	var hp_bg := ColorRect.new()
	hp_bg.custom_minimum_size = Vector2(0, BAR_H)
	hp_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_bg.color = Color(0.05, 0.05, 0.05, 0.9)
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.3, 0.85, 0.35)
	_hp_fill.anchor_right = 1.0
	_hp_fill.anchor_bottom = 1.0
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bg.add_child(_hp_fill)

	for _i in STATUS_SLOTS:
		var sp := RadialCooldown.new()
		sp.custom_minimum_size = Vector2(STATUS_PIP, STATUS_PIP)
		sp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sp.visible = false
		bottom.add_child(sp)
		_status_pips.append(sp)
