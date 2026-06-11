extends Control
## Inventory coordinator — modal window holding the player's BACKPACK (persistent) and,
## while looting a world container (chest), that container's grid beside it. Cross-
## container drag&drop + rotation (R, 2-state, grab-anchored). Grids own occupancy +
## item visuals; this coordinator owns the active drag and routes drops to whichever
## VISIBLE grid the cursor is over. ref: F-010 Loadout / 백팩 인벤.

const InventoryGrid := preload("res://scripts/ui/inventory_grid.gd")
const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")

const CELL := 48
const GAP := 4
const BAR_H := 30

var _dim: ColorRect
var _window: PanelContainer
var _grids: Array = []           # all grids; drag routes among the VISIBLE ones
var _backpack: InventoryGrid
var _loot: InventoryGrid
var _loot_box: VBoxContainer     # loot column wrapper (shown only while looting)
var _loot_label: Label
var _chest: Node = null          # currently looted chest (null = none)

# Active item drag (across containers).
var _drag: Dictionary = {}
var _from: InventoryGrid = null
var _orig: Dictionary = {}
var _drag_vis: Panel = null
var _grab_off := Vector2.ZERO
var _rotated := false

# Window move (title bar).
var _win_drag := false
var _win_off := Vector2.ZERO

# Party gear equip slots (F-008 §3.2): drop / right-click a gear item to equip it.
const SLOT_OK := Color(0.30, 0.85, 0.40, 0.32)    # drag-over slot, equippable
const SLOT_BAD := Color(0.95, 0.25, 0.20, 0.42)   # drag-over slot, wrong class / in combat
var _party: Node = null
var _combat: Node = null
var _content_row: HBoxContainer = null
var _equip_box: VBoxContainer = null
var _equip_slots: Array = []     # Panel per character (the slot frame = drop target)
var _equip_tiles: Array = []     # Label inside each slot (equipped gear name)
var _equip_overlays: Array = []  # ColorRect per slot (green/red drag preview)
var _equip_msg: Label = null     # transient feedback (combat/role reject)


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	get_viewport().size_changed.connect(_relayout)
	_window.resized.connect(_center_window)
	_relayout()


# --- open / close modes --------------------------------------------------------

func toggle() -> void:  # `i` — player backpack only
	if visible:
		_close()
	else:
		_loot_box.visible = false
		_open()


## Open the loot view: player backpack + the chest's container (populated from its items).
func open_loot(chest: Node) -> void:
	_chest = chest
	_loot_label.text = chest.title if "title" in chest else "CONTAINER"
	_loot.clear()
	for it in chest.items:
		_loot.place((it as Dictionary).duplicate(), int(it.col), int(it.row))
	_loot_box.visible = true
	_open()


func is_open() -> bool:
	return visible


## Add an item to the player backpack (from a world pickup). False if there is no room.
func add_to_backpack(id: String, w: int, h: int, color: Color) -> bool:
	return _backpack.add_item(id, w, h, color)


## How many backpack items have this id (drives quest counts, e.g. Cell n/6).
func count_item(id: String) -> int:
	var n := 0
	for it in _backpack.items:
		if String(it.id) == id:
			n += 1
	return n


## Does the player's backpack currently hold a key?
func backpack_has_key() -> bool:
	for it in _backpack.items:
		if String(it.id).to_lower().contains("key"):
			return true
	return false


func _open() -> void:
	visible = true
	_win_drag = false
	_relayout()
	call_deferred("_relayout")  # re-fit once the HBox re-sorts after toggling the loot column


func _close() -> void:
	if _chest != null:                          # persist what's left in the chest
		_chest.items = _loot.export_items()
		_loot.clear()
		_loot_box.visible = false
		_chest = null
	visible = false
	_win_drag = false


# --- party gear equip slots (F-008 §3.2 / DEC-20260611-001) ---------------------

## Wire the party so the inventory can show per-character equip slots and swap gear.
## combat is the CombatController (gate: no swap while engaged — F-008 §4.2).
func setup_party(party: Node, combat: Node) -> void:
	_party = party
	_combat = combat
	_build_equip_column()
	_refresh_equip_slots()


## Add a looted Identity Gear instance to the backpack as an At-Risk run-inventory
## item (F-008 §3.3). Returns false if the backpack is full.
func add_gear_to_backpack(base_gear_id: String, at_risk: bool) -> bool:
	var m: Dictionary = Slice01Data.get_gear_master(base_gear_id)
	if m.is_empty():
		return false
	return _backpack.add_item_dict(_gear_item(m, at_risk))


## Build a backpack item dict from a gear master (id=display name, role color, 2x2).
func _gear_item(master: Dictionary, at_risk: bool) -> Dictionary:
	var classes: Array = master.get("equip_classes", [])
	var cid := String(classes[0]) if not classes.is_empty() else "Tank"
	return {
		"id": String(master.get("display_name", master.get("base_gear_id", "Gear"))),
		"w": 2, "h": 2,
		"color": UnitVisuals.role_color(cid),
		"kind": "gear",
		"base_gear_id": String(master.get("base_gear_id", "")),
		"at_risk": at_risk,
	}


func _build_equip_column() -> void:
	if _content_row == null or _party == null:
		return
	if _equip_box != null and is_instance_valid(_equip_box):
		_equip_box.queue_free()
	_equip_slots.clear()
	_equip_tiles.clear()
	_equip_overlays.clear()
	_equip_box = VBoxContainer.new()
	_equip_box.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "PARTY GEAR (장비 슬롯)"
	title.add_theme_font_size_override("font_size", 14)
	_equip_box.add_child(title)
	_equip_msg = Label.new()
	_equip_msg.add_theme_font_size_override("font_size", 11)
	_equip_msg.modulate = Color(1.0, 0.72, 0.42)
	_equip_msg.custom_minimum_size = Vector2(176, 15)
	_equip_box.add_child(_equip_msg)
	var members: Array = _party.get_members()
	for i in members.size():
		var cname := String((members[i] as Node).class_id)
		var head := Label.new()  # per-character header (class)
		head.text = cname.to_upper()
		head.add_theme_font_size_override("font_size", 11)
		head.modulate = UnitVisuals.role_color(cname)
		_equip_box.add_child(head)
		var slot := Panel.new()  # the slot frame = drop target (gear sits inside)
		slot.custom_minimum_size = Vector2(176, 50)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		var tile := Label.new()
		tile.set_anchors_preset(Control.PRESET_FULL_RECT)
		tile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_theme_font_size_override("font_size", 11)
		slot.add_child(tile)
		var ov := ColorRect.new()  # green/red drag-preview overlay (on top of the tile)
		ov.set_anchors_preset(Control.PRESET_FULL_RECT)
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ov.visible = false
		slot.add_child(ov)
		_equip_box.add_child(slot)
		_equip_slots.append(slot)
		_equip_tiles.append(tile)
		_equip_overlays.append(ov)
	_content_row.add_child(_equip_box)
	_content_row.move_child(_equip_box, 0)  # leftmost column


func _refresh_equip_slots() -> void:
	if _party == null:
		return
	var members: Array = _party.get_members()
	for i in mini(members.size(), _equip_slots.size()):
		var m: Node = members[i]
		var gear: Dictionary = m.equipped_gear
		var col: Color = UnitVisuals.role_color(String(m.class_id))
		_equip_tiles[i].text = String(gear.get("display_name", gear.get("base_gear_id", "—")))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col.r, col.g, col.b, 0.30)
		sb.border_color = col.lightened(0.35)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(5)
		_equip_slots[i].add_theme_stylebox_override("panel", sb)


func _equip_slot_under(mouse: Vector2) -> int:
	for i in _equip_slots.size():
		var s: Panel = _equip_slots[i]
		if s.is_visible_in_tree() and s.get_global_rect().has_point(mouse):
			return i
	return -1


## Can `member` equip `master` right now? combat gate (F-008 §4.2) + equipClasses
## same-role (F-008 §3.4). No side effects — used by both the drag preview and equip.
func _can_equip_now(member: Node, master: Dictionary) -> bool:
	if member == null or master.is_empty():
		return false
	if _combat != null and _combat.is_engaged():
		return false
	return member.can_equip_gear(master)


## Index of the first party member whose class matches the gear's equipClasses, else -1.
func _matching_member(master: Dictionary) -> int:
	if _party == null:
		return -1
	var members: Array = _party.get_members()
	for i in members.size():
		if (members[i] as Node).can_equip_gear(master):
			return i
	return -1


## Apply the equip (caller already removed the item from its grid). Displaced gear
## returns to the backpack as an At-Risk instance (F-008 §3.3, decision B).
func _commit_equip(member: Node, master: Dictionary) -> void:
	var displaced: Dictionary = member.equipped_gear
	member.equip_gear(master)
	if not displaced.is_empty():
		if not _backpack.add_item_dict(_gear_item(displaced, true)):
			push_warning("[TDC] Backpack full — displaced gear had nowhere to go")
	_refresh_equip_slots()
	_msg("%s ▸ %s 장착" % [String(member.class_id), String(master.get("display_name", ""))])


## Drag-drop equip onto member `slot_index`. Returns false (no change) if gated; the
## drag item is already lifted, so on success it is consumed (now equipped).
func _try_equip(slot_index: int, item: Dictionary) -> bool:
	var member: Node = _party.get_member(slot_index) if _party != null else null
	var master: Dictionary = Slice01Data.get_gear_master(String(item.get("base_gear_id", "")))
	if member == null or master.is_empty():
		return false
	if _combat != null and _combat.is_engaged():
		_msg("전투 중에는 장비 교체 불가 (F-008 §4.2)")
		return false
	if not member.can_equip_gear(master):
		_msg("역할 불일치 — %s 전용 장비" % String((master.get("equip_classes", ["?"]) as Array)[0]))
		return false
	_commit_equip(member, master)
	return true


## Right-click equip: send a backpack gear item to the matching-class member (auto-target).
func _equip_to_matching(grid: Node, item: Dictionary) -> void:
	var master: Dictionary = Slice01Data.get_gear_master(String(item.get("base_gear_id", "")))
	if master.is_empty():
		return
	if _combat != null and _combat.is_engaged():
		_msg("전투 중에는 장비 교체 불가 (F-008 §4.2)")
		return
	var idx := _matching_member(master)
	if idx < 0:
		_msg("착용 가능한 %s 캐릭터 없음" % String((master.get("equip_classes", ["?"]) as Array)[0]))
		return
	grid.lift(item)  # remove from backpack (consumed → equipped)
	_commit_equip(_party.get_member(idx), master)


func _set_slot_preview(i: int, ok: bool) -> void:
	if i < 0 or i >= _equip_overlays.size():
		return
	var ov: ColorRect = _equip_overlays[i]
	ov.color = SLOT_OK if ok else SLOT_BAD
	ov.visible = true


func _clear_slot_previews() -> void:
	for ov: ColorRect in _equip_overlays:
		ov.visible = false


## During a gear drag, tint the hovered equip slot green (equippable) / red (wrong
## class or in combat). Non-gear drags clear all slot previews.
func _update_slot_previews(mouse: Vector2) -> void:
	_clear_slot_previews()
	if String(_drag.get("kind", "")) != "gear":
		return
	var si := _equip_slot_under(mouse)
	if si < 0:
		return
	var master: Dictionary = Slice01Data.get_gear_master(String(_drag.get("base_gear_id", "")))
	_set_slot_preview(si, _can_equip_now(_party.get_member(si), master))


func _msg(text: String) -> void:
	if _equip_msg != null:
		_equip_msg.text = text


# --- layout --------------------------------------------------------------------

func _relayout() -> void:
	var vp := get_viewport_rect().size
	size = vp
	position = Vector2.ZERO
	if _dim:
		_dim.size = vp
	if _window:
		_window.reset_size()  # shrink/grow the window to the currently-visible columns
	_center_window()


func _center_window() -> void:
	if _window:
		_window.position = ((get_viewport_rect().size - _window.size) * 0.5).round()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.5)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_window = PanelContainer.new()
	var win_sb := StyleBoxFlat.new()
	win_sb.bg_color = Color(0.08, 0.09, 0.11, 0.98)
	win_sb.border_color = Color(0.35, 0.38, 0.45)
	win_sb.set_border_width_all(2)
	win_sb.set_corner_radius_all(6)
	_window.add_theme_stylebox_override("panel", win_sb)
	add_child(_window)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	_window.add_child(vb)

	# Title bar = drag handle.
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(0, BAR_H)
	var bar_sb := StyleBoxFlat.new()
	bar_sb.bg_color = Color(0.16, 0.17, 0.21)
	bar_sb.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("panel", bar_sb)
	bar.gui_input.connect(_on_bar_input)
	var title := Label.new()
	title.text = "  INVENTORY     (제목바=창이동 · 드래그=이동/컨테이너간 · R=회전 · I/Esc=닫기)"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 12)
	bar.add_child(title)
	vb.add_child(bar)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 14)
	pad.add_theme_constant_override("margin_right", 14)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 14)
	vb.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	pad.add_child(row)
	_content_row = row

	# Player backpack (persistent) + a couple seed items (room left for a looted key).
	var bp_box := _make_container(row, "BACKPACK", 5, 8)
	_backpack = bp_box[1]
	_backpack.add_item("Pistol", 2, 1, Color(0.45, 0.55, 0.85))
	_backpack.add_item("Armor", 2, 2, Color(0.82, 0.70, 0.35))

	# Loot container (shown only while looting a chest).
	var lt_box := _make_container(row, "CONTAINER", 5, 5)
	_loot_box = lt_box[0]
	_loot_label = lt_box[2]
	_loot = lt_box[1]
	_loot_box.visible = false


## Returns [VBox wrapper, InventoryGrid, Label].
func _make_container(parent: Node, title_text: String, cols: int, rows: int) -> Array:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	parent.add_child(col)
	var lbl := Label.new()
	lbl.text = title_text
	lbl.add_theme_font_size_override("font_size", 14)
	col.add_child(lbl)
	var grid := InventoryGrid.new()
	grid.setup(self, cols, rows, CELL, GAP)
	col.add_child(grid)
	_grids.append(grid)
	return [col, grid, lbl]


# --- item drag (begin routed from grids' item visuals) -------------------------

func _on_item_pressed(event: InputEvent, grid: InventoryGrid, item: Dictionary) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or not _drag.is_empty():
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_begin_drag(grid, item)
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and String(item.get("kind", "")) == "gear":
		_equip_to_matching(grid, item)  # right-click → auto-equip to matching class
		accept_event()


func _begin_drag(grid: InventoryGrid, item: Dictionary) -> void:
	_drag = item
	_from = grid
	_rotated = false
	_orig = {"w": item.w, "h": item.h, "col": item.col, "row": item.row}
	var node: Control = item.node
	_grab_off = get_viewport().get_mouse_position() - node.global_position
	grid.lift(item)
	_drag_vis = _make_drag_vis(item)
	add_child(_drag_vis)
	_update_drag()


func _make_drag_vis(item: Dictionary) -> Panel:
	var p := Panel.new()
	p.size = _backpack.item_px(int(item.w), int(item.h))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c: Color = item.color
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(c.r, c.g, c.b, 0.6)
	sb.border_color = c.lightened(0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _grid_under(mouse: Vector2) -> InventoryGrid:
	for g: InventoryGrid in _grids:
		if g.is_visible_in_tree() and g.contains_global(mouse):
			return g
	return null


func _update_drag() -> void:
	if _drag_vis == null:
		return
	var mouse := get_viewport().get_mouse_position()
	_drag_vis.position = mouse - _grab_off
	var topleft := _drag_vis.global_position
	var target := _grid_under(mouse)
	for g: InventoryGrid in _grids:
		if g == target:
			var c := g.cell_from_global_topleft(topleft)
			g.set_preview(c, int(_drag.w), int(_drag.h), g.can_place(int(_drag.w), int(_drag.h), c.x, c.y))
		else:
			g.clear_preview()
	_update_slot_previews(mouse)


func _rotate_drag() -> void:
	if int(_drag.w) == int(_drag.h):
		return  # square — rotation changes nothing; don't nudge its placement
	# Rectangular items have only 2 orientations, so R is a 2-state toggle (W×H ↔ H×W):
	# rotate about the GRABBED point, alternating CW then CCW so a second R returns to the
	# exact original (no 4-step 360° cycle). The held part stays under the cursor.
	var old_size := _drag_vis.size
	var fx := _grab_off.x / maxf(old_size.x, 1.0)
	var fy := _grab_off.y / maxf(old_size.y, 1.0)
	var w: int = _drag.w
	_drag.w = _drag.h
	_drag.h = w
	var new_size: Vector2 = _backpack.item_px(int(_drag.w), int(_drag.h))
	_drag_vis.size = new_size
	if not _rotated:
		_grab_off = Vector2((1.0 - fy) * new_size.x, fx * new_size.y)         # 90° CW
	else:
		_grab_off = Vector2(fy * new_size.x, (1.0 - fx) * new_size.y)         # 90° CCW (inverse)
	_rotated = not _rotated
	_update_drag()


func _drop() -> void:
	var topleft := _drag_vis.global_position
	var mouse := get_viewport().get_mouse_position()
	var placed := false
	# Identity Gear → drop onto a party equip slot (F-008 §3.2 mid-run swap). On success
	# the item is consumed from the backpack (now equipped); on reject it reverts.
	if String(_drag.get("kind", "")) == "gear":
		var si := _equip_slot_under(mouse)
		if si >= 0:
			if not _try_equip(si, _drag):
				_drag.w = _orig.w
				_drag.h = _orig.h
				_from.place(_drag, int(_orig.col), int(_orig.row))
			placed = true
	if not placed:
		var target := _grid_under(mouse)
		if target != null:
			var c := target.cell_from_global_topleft(topleft)
			if target.can_place(int(_drag.w), int(_drag.h), c.x, c.y):
				target.place(_drag, c.x, c.y)
				placed = true
		if not placed:  # revert: restore original orientation + spot in the source grid
			_drag.w = _orig.w
			_drag.h = _orig.h
			_from.place(_drag, int(_orig.col), int(_orig.row))
	for g: InventoryGrid in _grids:
		g.clear_preview()
	_clear_slot_previews()
	_drag_vis.queue_free()
	_drag_vis = null
	_drag = {}
	_from = null


func _input(event: InputEvent) -> void:
	if not _drag.is_empty():
		if event is InputEventMouseMotion:
			_update_drag()
		elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (event as InputEventMouseButton).pressed:
			_drop()
		elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_R:
			_rotate_drag()
		return
	if _win_drag:
		if event is InputEventMouseMotion:
			var vp := get_viewport_rect().size
			var maxp := vp - _window.size
			maxp.x = maxf(maxp.x, 0.0)
			maxp.y = maxf(maxp.y, 0.0)
			_window.position = (get_viewport().get_mouse_position() + _win_off).clamp(Vector2.ZERO, maxp)
		elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (event as InputEventMouseButton).pressed:
			_win_drag = false


func _on_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_win_drag = true
			_win_off = _window.position - get_viewport().get_mouse_position()
			accept_event()
