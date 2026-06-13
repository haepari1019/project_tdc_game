extends Control
## Inventory coordinator — modal window holding the player's BACKPACK (persistent) and,
## while looting a world container (chest), that container's grid beside it. Cross-
## container drag&drop + rotation (R, 2-state, grab-anchored). Grids own occupancy +
## item visuals; this coordinator owns the active drag and routes drops to whichever
## VISIBLE grid the cursor is over. ref: F-010 Loadout / 백팩 인벤.

const InventoryGrid := preload("res://scripts/ui/inventory/inventory_grid.gd")
const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")
const ItemFactory := preload("res://scripts/ui/inventory/item_factory.gd")
const EquipPanel := preload("res://scripts/ui/inventory/equip_panel.gd")
const ConsumableController := preload("res://scripts/ui/inventory/consumable_controller.gd")

signal consumable_use_requested(consumable_id: String)  # right-click a consumable → use it

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
var _drag_src: Dictionary = {}  # {kind: grid|gear|sub, char, slot} — where the drag began

# Window move (title bar).
var _win_drag := false
var _win_off := Vector2.ZERO

# Party gear equip slots (F-008 §3.2): drop / right-click a gear item to equip it.
var _party: Node = null
var _combat: Node = null
var _content_row: HBoxContainer = null
var _equip: EquipPanel = null    # gear/sub equip slots (extracted, DEBT-INV); drives drag delegates
var _consumables: ConsumableController = null  # consumable stacking + Z/X/C hotkeys (extracted, DEBT-INV)


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_consumables = ConsumableController.new()
	add_child(_consumables)
	_consumables.setup(self)
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
	if _equip != null:  # reflect current equip/charge state + the now-controlled char's subs
		_equip.refresh()
	if _consumables != null:
		_consumables.set_interactive(true)  # bar slots become draggable while inventory open
	_relayout()
	call_deferred("_relayout")  # re-fit once the HBox re-sorts after toggling the loot column


func _close() -> void:
	if _chest != null:                          # persist what's left in the chest
		_chest.items = _loot.export_items()
		_loot.clear()
		_loot_box.visible = false
		_chest = null
	if _consumables != null:
		_consumables.set_interactive(false)
	visible = false
	_win_drag = false


# --- party gear equip slots (F-008 §3.2 / DEC-20260611-001) ---------------------

## Wire the party so the inventory can show per-character equip slots and swap gear.
## combat is the CombatController (gate: no swap while engaged — F-008 §4.2).
func setup_party(party: Node, combat: Node) -> void:
	_party = party
	_combat = combat
	if _equip == null:
		_equip = EquipPanel.new()
		add_child(_equip)
	_equip.setup(self, party, combat)
	_equip.build(_content_row)
	_equip.refresh()
	if _consumables != null:
		_consumables.bind_party(party, combat)


# --- equip panel callbacks (the EquipPanel drives the shared drag state through these) ---

## True while an item is being dragged (gates slot drag-out). ref: DEBT-INV.
func is_dragging() -> bool:
	return not _drag.is_empty()


## The player backpack grid (EquipPanel returns displaced gear/skillbooks here).
func backpack_grid() -> InventoryGrid:
	return _backpack


## Transient feedback line (owned by the EquipPanel's gear column). Consumable code uses it too.
func _msg(text: String) -> void:
	if _equip != null:
		_equip.msg(text)


# --- consumables: thin wrappers → ConsumableController (external API preserved; F-010) ---

func setup_consumable_bar(bar: Node) -> void:
	if _consumables != null:
		_consumables.setup_bar(bar)


func add_consumable_to_backpack(consumable_id: String, amount: int) -> int:
	return _consumables.add_to_backpack(consumable_id, amount) if _consumables != null else 0


func consumable_count(consumable_id: String) -> int:
	return _consumables.count(consumable_id) if _consumables != null else 0


func consume_consumable(consumable_id: String) -> bool:
	return _consumables.consume(consumable_id) if _consumables != null else false


func use_consumable(slot: int) -> String:
	return _consumables.use(slot) if _consumables != null else ""


func get_hotkey(slot: int) -> String:
	return _consumables.get_hotkey(slot) if _consumables != null else ""


## Add a looted Identity Gear instance to the backpack as an At-Risk run-inventory
## item (F-008 §3.3). Returns false if the backpack is full.
func add_gear_to_backpack(base_gear_id: String, at_risk: bool) -> bool:
	var m: Dictionary = Slice01Data.get_gear_master(base_gear_id)
	if m.is_empty():
		return false
	return _backpack.add_item_dict(ItemFactory.gear_item(m, at_risk))




## Add a looted skillbook to the backpack as an At-Risk run-inventory item. Skillbooks
## stay At-Risk even when equipped (F-009 §3.7). Returns false if the backpack is full.
func add_skillbook_to_backpack(base_ability_id: String, at_risk: bool) -> bool:
	var m: Dictionary = Slice01Data.get_skillbook_master(base_ability_id)
	if m.is_empty():
		return false
	return _backpack.add_item_dict(ItemFactory.skillbook_item(m, at_risk))




# --- run settlement (F-007 §3.6/§3.7 — backpack = At-Risk run inventory) ---------

## The whole backpack is At-Risk run inventory. Returns a settlement list
## [{label, count}] for the Loss Bundle (on failure) / Safe set (on extraction).
func collect_run_inventory() -> Array:
	var out: Array = []
	for it in _backpack.items:
		var kind := String(it.get("kind", ""))
		out.append({
			"label": String(it.get("id", "?")),
			"count": int(it.get("count", 1)) if kind == "consumable" else 1,
			"kind": kind,
		})
	return out


## Raw backpack item dicts (for the deployment hub to serialize the brought loadout).
func get_backpack_items() -> Array:
	var out: Array = []
	for it in _backpack.items:
		out.append((it as Dictionary).duplicate())
	return out


## F-007 §3.6 — Extraction Success: every At-Risk run-inventory stack becomes Safe.
func mark_run_inventory_safe() -> void:
	for it in _backpack.items:
		if it.has("at_risk"):
			it["at_risk"] = false


# --- stash item builders (deployment hub) — public wrappers so the hub can fill a stash grid
# with the exact item dicts the equip/sub/backpack drag system expects (F-010). ---
func make_gear_stash_item(base_gear_id: String) -> Dictionary:
	var m := Slice01Data.get_gear_master(base_gear_id)
	return ItemFactory.gear_item(m, true) if not m.is_empty() else {}


func make_skillbook_stash_item(base_ability_id: String) -> Dictionary:
	var m := Slice01Data.get_skillbook_master(base_ability_id)
	return ItemFactory.skillbook_item(m, true) if not m.is_empty() else {}


func make_consumable_stash_item(consumable_id: String, count: int) -> Dictionary:
	var m := Slice01Data.get_consumable_master(consumable_id)
	return ItemFactory.consumable_item(m, count) if not m.is_empty() else {}






func start_drag_from_slot(item: Dictionary, src: Dictionary) -> void:
	_drag = item
	_from = null
	_drag_src = src
	_rotated = false
	_orig = {"w": int(item.w), "h": int(item.h), "col": 0, "row": 0}
	_grab_off = Vector2(int(item.w) * CELL * 0.5, int(item.h) * CELL * 0.5)
	_drag_vis = _make_drag_vis(item)
	add_child(_drag_vis)
	_update_drag()


## Restore the drag to where it began (grid spot / gear slot / sub slot).
func _revert_drag() -> void:
	match String(_drag_src.get("kind", "grid")):
		"gear":
			_equip.revert_gear(int(_drag_src.char), String(_drag.get("base_gear_id", "")))
		"sub":
			_equip.revert_sub(int(_drag_src.char), int(_drag_src.slot), _drag)
		_:
			if _from != null:
				_drag.w = _orig.w
				_drag.h = _orig.h
				_from.place(_drag, int(_orig.col), int(_orig.row))


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
	add_consumable_to_backpack("con_revive_scroll", 3)  # seed: 3 revive scrolls (1 stack)
	add_skillbook_to_backpack("AB-037", false)          # seed: Ember Lance (fire — ignites oil)

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
		# Ctrl+drag a stackable consumable → split off half into a new floating stack.
		if mb.ctrl_pressed and String(item.get("kind", "")) == "consumable" and int(item.get("count", 1)) > 1:
			_open_split_popup(grid, item)   # Ctrl+click → ask how many to split off
		else:
			_begin_drag(grid, item)
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if grid == _loot:
			_stow_to_backpack(grid, item)  # chest → backpack: auto-stow to free space
		elif String(item.get("kind", "")) == "gear":
			_equip.equip_gear_to_matching(grid, item)  # right-click → auto-equip to matching class
		elif String(item.get("kind", "")) == "skillbook":
			_equip.equip_sub_to_first(grid, item)  # right-click → first matching sub slot
		elif String(item.get("kind", "")) == "consumable":
			consumable_use_requested.emit(String(item.get("consumable_id", "")))  # → use (revive targeting)
		accept_event()


## Right-click in a loot container → move the item to the backpack's first free spot.
func _stow_to_backpack(grid: InventoryGrid, item: Dictionary) -> void:
	if grid == _backpack:
		return
	grid.lift(item)
	if not _backpack.add_item_dict(item):
		grid.place(item, int(item.col), int(item.row))  # no room — leave it in the chest


func _begin_drag(grid: InventoryGrid, item: Dictionary) -> void:
	_drag = item
	_from = grid
	_drag_src = {"kind": "grid"}
	_rotated = false
	_orig = {"w": item.w, "h": item.h, "col": item.col, "row": item.row}
	var node: Control = item.node
	_grab_off = get_viewport().get_mouse_position() - node.global_position
	grid.lift(item)
	_drag_vis = _make_drag_vis(item)
	add_child(_drag_vis)
	_update_drag()


## Ctrl+click a consumable stack → popup asking how many to split off into a NEW stack (placed
## in the first free cell). Drag a stack onto a same-id stack to merge them back. ref: F-010.
func _open_split_popup(grid: InventoryGrid, item: Dictionary) -> void:
	var total := int(item.count)
	if total <= 1:
		return
	var pop := PopupPanel.new()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pop.add_child(vb)
	var lbl := Label.new()
	lbl.text = "%s — 분해 수량 (1~%d)" % [String(item.get("id", "")), total - 1]
	vb.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = total - 1
	spin.value = total / 2
	vb.add_child(spin)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_END
	var cancel := Button.new()
	cancel.text = "취소"
	cancel.pressed.connect(pop.queue_free)
	hb.add_child(cancel)
	var ok := Button.new()
	ok.text = "분해"
	ok.pressed.connect(func() -> void:
		_do_split(grid, item, int(spin.value))
		pop.queue_free()
	)
	hb.add_child(ok)
	vb.add_child(hb)
	add_child(pop)
	pop.popup(Rect2i(get_viewport().get_mouse_position(), Vector2i(230, 116)))


## Split `n` units off `item` into a new stack placed in the grid's first free cell.
func _do_split(grid: InventoryGrid, item: Dictionary, n: int) -> void:
	n = clampi(n, 1, int(item.count) - 1)
	if n <= 0:
		return
	item.count = int(item.count) - n
	grid.refresh_item_label(item)
	var part: Dictionary = item.duplicate()
	part.erase("node")
	part.count = n
	if not grid.add_item_dict(part):
		item.count = int(item.count) + n   # no free cell → undo the split
		grid.refresh_item_label(item)


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
	if _equip != null:
		_equip.update_previews(mouse, _drag)


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
		var si := _equip.gear_slot_under(mouse)
		if si >= 0:
			if not _equip.try_equip_gear(si, _drag):
				_revert_drag()
			placed = true
	elif String(_drag.get("kind", "")) == "skillbook":
		var ssi := _equip.sub_slot_under(mouse)
		if ssi >= 0:
			if not _equip.try_equip_sub(ssi, _drag):
				_revert_drag()
			placed = true
	elif String(_drag.get("kind", "")) == "consumable":
		var bi := _consumables.bar_slot_under(mouse)
		if bi >= 0:
			_consumables.assign_hotkey(bi, String(_drag.get("consumable_id", "")))
			_revert_drag()  # assigning doesn't consume — return the stack to the backpack
			placed = true
	elif String(_drag.get("kind", "")) == "hotkey":
		var hbi := _consumables.bar_slot_under(mouse)
		var src := int(_drag.get("src_slot", -1))
		if hbi == src:
			pass  # dropped back on its own slot → keep
		elif hbi >= 0:
			_consumables.assign_hotkey(hbi, String(_drag.get("consumable_id", "")))  # move (uniqueness clears src)
		else:
			_consumables.unassign_hotkey(src)  # dropped away → unassign
		placed = true
	if not placed:
		var target := _grid_under(mouse)
		if target != null:
			var c := target.cell_from_global_topleft(topleft)
			# consumable merge: dropping onto a same-id stack combines (≤ max_stack).
			if String(_drag.get("kind", "")) == "consumable":
				var dest: Dictionary = target.item_at(int(c.x), int(c.y))
				if not dest.is_empty() and dest != _drag \
						and String(dest.get("consumable_id", "")) == String(_drag.get("consumable_id", "")):
					var room := int(_drag.get("max_stack", 1)) - int(dest.get("count", 0))
					var move := mini(room, int(_drag.get("count", 0)))
					if move > 0:
						dest.count = int(dest.count) + move
						target.refresh_item_label(dest)
						_drag.count = int(_drag.count) - move
						if int(_drag.count) <= 0:
							placed = true  # fully merged into the stack
			if not placed and target.can_place(int(_drag.w), int(_drag.h), c.x, c.y):
				target.place(_drag, c.x, c.y)
				placed = true
		if not placed:  # leftover / no target → revert to source (or merge the split back)
			_revert_drag()
	for g: InventoryGrid in _grids:
		g.clear_preview()
	if _equip != null:
		_equip.clear_previews()
	_drag_vis.queue_free()
	_drag_vis = null
	_drag = {}
	_from = null
	_drag_src = {}


func _input(event: InputEvent) -> void:
	# Z/X/C while the inventory is open → assign the hovered consumable to that hotkey.
	if visible and _drag.is_empty():
		var hk := -1
		if event.is_action_pressed("use_consumable_z"): hk = 0
		elif event.is_action_pressed("use_consumable_x"): hk = 1
		elif event.is_action_pressed("use_consumable_c"): hk = 2
		if hk >= 0:
			var it = _consumables.consumable_under(get_viewport().get_mouse_position())
			if it != null:
				var cid := String(it.consumable_id)
				if _consumables.get_hotkey(hk) == cid:
					_consumables.unassign_hotkey(hk)  # hover the item on its own slot's key → toggle off
				else:
					_consumables.assign_hotkey(hk, cid)
			get_viewport().set_input_as_handled()
			return
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
