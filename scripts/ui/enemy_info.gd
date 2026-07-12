extends Control
## Enemy info panel — top-center (12 o'clock). Borrows the party-sheet slot style:
## enemy portrait + name + HP bar, with a buff/debuff CHIP row DIRECTLY BELOW the sheet — each
## chip boxes an icon + its status name together (stun/slow/silence + elemental outcomes, via
## enemy_unit.get_status_list()); chips flow and wrap within the sheet width, and the whole row
## hides when the enemy has no active statuses. Shown when an enemy is left-clicked; hidden when
## it dies or selection clears. No skills/cooldowns (per design). Used by both dungeon_run AND the
## combat sandbox. ref: UI-002 style. Mouse-transparent so it never eats gameplay clicks.

const RadialCooldown := preload("res://scripts/ui/radial_cooldown.gd")
const UiColors := preload("res://scripts/core/ui_colors.gd")

const PANEL_W := 264.0
const PANEL_H := 72.0
const PORTRAIT := 46
const BAR_H := 14
const STATUS_SLOTS := 8       # 최대 표시 상태 칩 수(기절/둔화/침묵 + 원소 아웃컴 여러 개)
const STATUS_PIP := 14
const STATUS_RESERVE_H := 96.0   # 시트 아래 상태 칩 영역 확보 높이(여러 줄 wrap 대비; 투명·마우스무시)

var _enemy: Node = null
var _portrait: ColorRect
var _name_lbl: Label
var _hp_fill: ColorRect
var _hp_lbl: Label
var _status_panel: Control   # 시트 바로 아래 칩 스트립 컨테이너(상태 없으면 숨김)
var _status_pips: Array = []    # RadialCooldown ×STATUS_SLOTS
var _status_labels: Array = []  # Label ×STATUS_SLOTS (상태 이름)
var _status_boxes: Array = []   # 칩 상자(PanelContainer) ×STATUS_SLOTS — 아이콘+글씨를 묶음


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -PANEL_W * 0.5
	offset_right = PANEL_W * 0.5
	offset_top = 12.0
	offset_bottom = 12.0 + PANEL_H + STATUS_RESERVE_H   # room for the status-chip strip below the sheet
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func set_enemy(e: Node) -> void:
	_disconnect_died()
	_enemy = e
	visible = e != null
	if e != null:
		if e.has_signal("died") and not e.died.is_connected(_on_enemy_died):
			e.died.connect(_on_enemy_died)
		_refresh()


func clear() -> void:
	_disconnect_died()
	_enemy = null
	visible = false


func _disconnect_died() -> void:
	if _enemy != null and is_instance_valid(_enemy) and _enemy.has_signal("died") \
			and _enemy.died.is_connected(_on_enemy_died):
		_enemy.died.disconnect(_on_enemy_died)


## The inspected enemy died → hide immediately (event-driven; no stale sliver-HP panel).
func _on_enemy_died(_unit: Variant = null) -> void:
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
	if _status_panel != null:
		_status_panel.visible = not sl.is_empty()   # hide the whole strip when nothing is active
	for j in _status_boxes.size():
		if j < sl.size():
			var st: Dictionary = sl[j]
			var col: Color = st.get("color", Color(0.8, 0.8, 0.8))
			_status_pips[j].set_icon_color(col)
			_status_pips[j].set_cd(float(st.get("ratio", 0.0)))
			_status_labels[j].text = String(st.get("name", "?"))
			_status_labels[j].add_theme_color_override("font_color", col.lightened(0.25))  # 아이콘 색과 통일
			_status_boxes[j].visible = true
		else:
			_status_boxes[j].visible = false


func _build() -> void:
	# Column: enemy sheet on top, buff/debuff icon strip directly below.
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.05, 0.06, 0.80)        # reddish tint vs the party panels
	sb.border_color = Color(0.85, 0.35, 0.32, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(6)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", sb)
	vb.add_child(panel)

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

	# --- buff/debuff strip, directly below the sheet: one CHIP per status (icon + name boxed
	# together), flowing left→right and wrapping within the sheet width. Hidden when no status. ---
	_status_panel = PanelContainer.new()
	_status_panel.custom_minimum_size = Vector2(PANEL_W, 0)   # bound the flow width so chips wrap
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())  # only the chips are boxed
	_status_panel.visible = false
	vb.add_child(_status_panel)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_panel.add_child(flow)

	var chip_sb := StyleBoxFlat.new()
	chip_sb.bg_color = Color(0.13, 0.09, 0.10, 0.92)
	chip_sb.border_color = Color(0.70, 0.40, 0.40, 0.55)
	chip_sb.set_border_width_all(1)
	chip_sb.set_corner_radius_all(4)
	chip_sb.content_margin_left = 5.0
	chip_sb.content_margin_right = 6.0
	chip_sb.content_margin_top = 2.0
	chip_sb.content_margin_bottom = 2.0
	for _i in STATUS_SLOTS:
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override("panel", chip_sb)
		chip.visible = false
		flow.add_child(chip)
		var cbox := HBoxContainer.new()
		cbox.add_theme_constant_override("separation", 4)
		cbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(cbox)
		var sp := RadialCooldown.new()
		sp.custom_minimum_size = Vector2(STATUS_PIP, STATUS_PIP)
		sp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cbox.add_child(sp)
		var lbl := Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		cbox.add_child(lbl)
		_status_boxes.append(chip)
		_status_pips.append(sp)
		_status_labels.append(lbl)
