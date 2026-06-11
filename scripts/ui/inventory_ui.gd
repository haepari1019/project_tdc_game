extends Control
## Inventory coordinator — modal window holding the player's BACKPACK (persistent) and,
## while looting a world container (chest), that container's grid beside it. Cross-
## container drag&drop + rotation (R, 2-state, grab-anchored). Grids own occupancy +
## item visuals; this coordinator owns the active drag and routes drops to whichever
## VISIBLE grid the cursor is over. ref: F-010 Loadout / 백팩 인벤.

const InventoryGrid := preload("res://scripts/ui/inventory_grid.gd")
const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")

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
# Sub skillbook slots (Q/E/R) for the CONTROLLED character (F-009 §3.1).
var _sub_box: VBoxContainer = null
var _sub_slots: Array = []  # entries: {panel, tile, overlay, char, slot} — 4 chars × Q/E/R
# Consumable Z/X/C hotkeys (party-shared; F-010). Each = consumable_id or "".
var _hotkeys: Array = ["", "", ""]
var _consumable_bar: Node = null


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
	if _party != null:  # reflect current equip/charge state + the now-controlled char's subs
		_refresh_equip_slots()
		_refresh_sub_slots()
	if _consumable_bar != null and _consumable_bar.has_method("set_interactive"):
		_consumable_bar.set_interactive(true)  # bar slots become draggable while inventory open
	_relayout()
	call_deferred("_relayout")  # re-fit once the HBox re-sorts after toggling the loot column


func _close() -> void:
	if _chest != null:                          # persist what's left in the chest
		_chest.items = _loot.export_items()
		_loot.clear()
		_loot_box.visible = false
		_chest = null
	if _consumable_bar != null and _consumable_bar.has_method("set_interactive"):
		_consumable_bar.set_interactive(false)
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
	_build_sub_column()
	_refresh_sub_slots()


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


## Add a looted skillbook to the backpack as an At-Risk run-inventory item. Skillbooks
## stay At-Risk even when equipped (F-009 §3.7). Returns false if the backpack is full.
func add_skillbook_to_backpack(base_ability_id: String, at_risk: bool) -> bool:
	var m: Dictionary = Slice01Data.get_skillbook_master(base_ability_id)
	if m.is_empty():
		return false
	return _backpack.add_item_dict(_skillbook_item(m, at_risk))


## Build a backpack item dict from a skillbook master (1x1, role-tinted, full charges).
func _skillbook_item(master: Dictionary, at_risk: bool) -> Dictionary:
	var classes: Array = master.get("equip_classes", [])
	var cid := String(classes[0]) if not classes.is_empty() else "DPS"
	var cmax := int(master.get("charges_max", 0))
	return {
		"id": String(master.get("display_name", master.get("base_ability_id", "Skillbook"))),
		"w": 1, "h": 1,
		"color": UnitVisuals.role_color(cid).lightened(0.15),
		"kind": "skillbook",
		"base_ability_id": String(master.get("base_ability_id", "")),
		"charges": cmax,
		"charges_max": cmax,
		"at_risk": at_risk,
	}


# --- consumables (stacking + Z/X/C hotkeys — F-010) -----------------------------

func _consumable_color(master: Dictionary) -> Color:
	var ca: Array = master.get("color", [0.6, 0.85, 0.6])
	return Color(float(ca[0]), float(ca[1]), float(ca[2])) if ca.size() >= 3 else Color(0.6, 0.85, 0.6)


func _consumable_item(master: Dictionary, count: int) -> Dictionary:
	return {
		"id": String(master.get("display_name", master.get("consumable_id", "Item"))),
		"w": 1, "h": 1,
		"color": _consumable_color(master),
		"kind": "consumable",
		"consumable_id": String(master.get("consumable_id", "")),
		"count": count,
		"max_stack": int(master.get("max_stack", 1)),
	}


## Add `amount` of a consumable, filling existing stacks (≤ max_stack) then new tiles.
func add_consumable_to_backpack(consumable_id: String, amount: int) -> int:
	var master := Slice01Data.get_consumable_master(consumable_id)
	if master.is_empty() or amount <= 0:
		return 0
	var max_stack := int(master.get("max_stack", 1))
	var remaining := amount
	for it in _backpack.items:
		if remaining <= 0:
			break
		if String(it.get("kind", "")) == "consumable" and String(it.get("consumable_id", "")) == consumable_id:
			var room := max_stack - int(it.get("count", 0))
			if room > 0:
				var add := mini(room, remaining)
				it.count = int(it.count) + add
				remaining -= add
				_backpack.refresh_item_label(it)
	while remaining > 0:
		var n := mini(max_stack, remaining)
		if not _backpack.add_item_dict(_consumable_item(master, n)):
			break
		remaining -= n
	_refresh_consumable_ui()
	return amount - remaining


func consumable_count(consumable_id: String) -> int:
	var n := 0
	for it in _backpack.items:
		if String(it.get("kind", "")) == "consumable" and String(it.get("consumable_id", "")) == consumable_id:
			n += int(it.get("count", 0))
	return n


func _find_consumable_stack(consumable_id: String):
	for it in _backpack.items:
		if String(it.get("kind", "")) == "consumable" and String(it.get("consumable_id", "")) == consumable_id and int(it.get("count", 0)) > 0:
			return it
	return null


## The consumable item under the cursor (for hover + Z/X/C hotkey assign).
func _consumable_under(mouse: Vector2):
	for it in _backpack.items:
		if String(it.get("kind", "")) == "consumable" and it.has("node") and is_instance_valid(it.node):
			if (it.node as Control).get_global_rect().has_point(mouse):
				return it
	return null


func setup_consumable_bar(bar: Node) -> void:
	_consumable_bar = bar
	if bar.has_signal("slot_grabbed") and not bar.slot_grabbed.is_connected(_begin_hotkey_drag):
		bar.slot_grabbed.connect(_begin_hotkey_drag)
	_refresh_consumable_ui()


## Drag a hotkey assignment OUT of a bar slot — to another slot (move) or away (unassign).
func _begin_hotkey_drag(slot: int) -> void:
	if not _drag.is_empty():
		return
	var cid := get_hotkey(slot)
	if cid.is_empty():
		return
	var master := Slice01Data.get_consumable_master(cid)
	var item := {
		"id": String(master.get("display_name", cid)), "w": 1, "h": 1,
		"color": _consumable_color(master), "kind": "hotkey", "consumable_id": cid, "src_slot": slot,
	}
	_drag = item
	_from = null
	_drag_src = {"kind": "hotkey", "slot": slot}
	_rotated = false
	_orig = {"w": 1, "h": 1, "col": 0, "row": 0}
	_grab_off = Vector2(CELL * 0.5, CELL * 0.5)
	_drag_vis = _make_drag_vis(item)
	add_child(_drag_vis)
	_update_drag()


func get_hotkey(slot: int) -> String:
	return String(_hotkeys[slot]) if slot >= 0 and slot < _hotkeys.size() else ""


func assign_hotkey(slot: int, consumable_id: String) -> void:
	if slot < 0 or slot >= _hotkeys.size():
		return
	for i in _hotkeys.size():  # uniqueness: the same consumable lives in only one slot
		if i != slot and String(_hotkeys[i]) == consumable_id:
			_hotkeys[i] = ""
	_hotkeys[slot] = consumable_id
	_refresh_consumable_ui()
	var nm := String(Slice01Data.get_consumable_master(consumable_id).get("display_name", consumable_id))
	_msg("%s → %s 핫키 등록" % [["Z", "X", "C"][slot], nm])


func _unassign_hotkey(slot: int) -> void:
	if slot < 0 or slot >= _hotkeys.size():
		return
	_hotkeys[slot] = ""
	_refresh_consumable_ui()
	_msg("%s 핫키 해제" % ["Z", "X", "C"][slot])


func _refresh_consumable_ui() -> void:
	if _consumable_bar == null or not is_instance_valid(_consumable_bar) or not _consumable_bar.has_method("refresh"):
		return
	var data: Array = []
	for s in 3:
		var cid := String(_hotkeys[s])
		if cid.is_empty():
			data.append({})
		else:
			var m := Slice01Data.get_consumable_master(cid)
			data.append({"name": String(m.get("display_name", cid)), "count": consumable_count(cid), "color": _consumable_color(m)})
	_consumable_bar.refresh(data)


func _consumable_bar_slot_under(mouse: Vector2) -> int:
	if _consumable_bar != null and is_instance_valid(_consumable_bar) and _consumable_bar.has_method("slot_under"):
		return _consumable_bar.slot_under(mouse)
	return -1


## Gameplay use (Z/X/C while playing). Returns a status string for HUD feedback ("" = no-op).
func use_consumable(slot: int) -> String:
	var cid := get_hotkey(slot)
	if cid.is_empty():
		return ""
	var master := Slice01Data.get_consumable_master(cid)
	if master.is_empty():
		return ""
	if not bool(master.get("usable_in_combat", true)) and _combat != null and _combat.is_engaged():
		return "전투 중 사용 불가: %s" % master.get("display_name", cid)
	var stack = _find_consumable_stack(cid)
	if stack == null:
		return "보유 없음: %s" % master.get("display_name", cid)
	if not _apply_consumable(master):
		return "대상 없음: %s" % master.get("display_name", cid)
	stack.count = int(stack.count) - 1
	if int(stack.count) <= 0:
		_backpack.lift(stack)
	else:
		_backpack.refresh_item_label(stack)
	_refresh_consumable_ui()
	return "%s 사용" % master.get("display_name", cid)


func _apply_consumable(master: Dictionary) -> bool:
	match String(master.get("effect", "")):
		"revive_ally":
			if _party == null:
				return false
			for m in _party.get_members():
				if not (m as Node).is_alive():
					return (m as Node).revive(0.5)
			return false
	return false


## Consume 1 of a consumable (external callers, e.g. dungeon_run after a revive channel).
func consume_consumable(consumable_id: String) -> bool:
	var stack = _find_consumable_stack(consumable_id)
	if stack == null:
		return false
	stack.count = int(stack.count) - 1
	if int(stack.count) <= 0:
		_backpack.lift(stack)
	else:
		_backpack.refresh_item_label(stack)
	_refresh_consumable_ui()
	return true


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
		var slot := Panel.new()  # slot frame = drop target + drag source (gear)
		slot.custom_minimum_size = Vector2(176, 50)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_gear_slot_input.bind(i))
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
	_clear_sub_previews()
	var kind := String(_drag.get("kind", ""))
	if kind == "gear":
		var si := _equip_slot_under(mouse)
		if si >= 0:
			var master: Dictionary = Slice01Data.get_gear_master(String(_drag.get("base_gear_id", "")))
			_set_slot_preview(si, _can_equip_now(_party.get_member(si), master))
	elif kind == "skillbook":
		var si := _sub_slot_under(mouse)
		if si >= 0:
			var master: Dictionary = Slice01Data.get_skillbook_master(String(_drag.get("base_ability_id", "")))
			_set_sub_preview(si, _can_equip_sub_now(si, master))


func _msg(text: String) -> void:
	if _equip_msg != null:
		_equip_msg.text = text


# --- sub skillbook slots (per-character Q/E/R — F-009 §3.1) ---------------------

func _build_sub_column() -> void:
	if _content_row == null or _party == null:
		return
	if _sub_box != null and is_instance_valid(_sub_box):
		_sub_box.queue_free()
	_sub_slots.clear()
	_sub_box = VBoxContainer.new()
	_sub_box.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "SUB SKILLS (캐릭터별 Q/E/R)"
	title.add_theme_font_size_override("font_size", 14)
	_sub_box.add_child(title)
	var members: Array = _party.get_members()
	for ci in members.size():
		var cname := String((members[ci] as Node).class_id)
		var crow := HBoxContainer.new()
		crow.add_theme_constant_override("separation", 5)
		var clabel := Label.new()
		clabel.text = cname
		clabel.custom_minimum_size = Vector2(50, 0)
		clabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		clabel.modulate = UnitVisuals.role_color(cname)
		clabel.add_theme_font_size_override("font_size", 11)
		crow.add_child(clabel)
		for si in 3:
			var slot := Panel.new()
			slot.custom_minimum_size = Vector2(96, 44)
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.gui_input.connect(_on_sub_slot_input.bind(_sub_slots.size()))
			var tile := Label.new()
			tile.set_anchors_preset(Control.PRESET_FULL_RECT)
			tile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tile.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_theme_font_size_override("font_size", 9)
			slot.add_child(tile)
			var ov := ColorRect.new()
			ov.set_anchors_preset(Control.PRESET_FULL_RECT)
			ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ov.visible = false
			slot.add_child(ov)
			crow.add_child(slot)
			_sub_slots.append({"panel": slot, "tile": tile, "overlay": ov, "char": ci, "slot": si})
		_sub_box.add_child(crow)
	_content_row.add_child(_sub_box)
	_content_row.move_child(_sub_box, 1)  # after the gear column


func _refresh_sub_slots() -> void:
	if _party == null:
		return
	var members: Array = _party.get_members()
	for e in _sub_slots:
		if int(e.char) >= members.size():
			continue
		var inst = (members[int(e.char)] as Node).get_skillbook(int(e.slot))
		var key: String = ["Q", "E", "R"][int(e.slot)]
		var col: Color
		if inst == null:
			e.tile.text = "%s\n—" % key
			col = Color(0.28, 0.31, 0.38)
		else:
			e.tile.text = "%s %s\n탄%d" % [key, _short(String(inst.display_name)), int(inst.charges)]
			col = Color(0.40, 0.55, 0.85)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col.r, col.g, col.b, 0.30)
		sb.border_color = col.lightened(0.3)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		e.panel.add_theme_stylebox_override("panel", sb)


func _short(s: String) -> String:
	return s if s.length() <= 10 else s.substr(0, 9) + "…"


func _sub_slot_under(mouse: Vector2) -> int:
	for i in _sub_slots.size():
		var p: Panel = _sub_slots[i].panel
		if p.is_visible_in_tree() and p.get_global_rect().has_point(mouse):
			return i
	return -1


## Can the slot's owner char equip this skillbook now? combat gate + equipClasses.
func _can_equip_sub_now(flat_index: int, master: Dictionary) -> bool:
	if master.is_empty() or flat_index < 0 or flat_index >= _sub_slots.size():
		return false
	if _combat != null and _combat.is_engaged():
		return false
	var m: Node = _party.get_member(int(_sub_slots[flat_index].char)) if _party != null else null
	return m != null and m.can_equip_skillbook(master)


## Slot instance from a backpack skillbook item + its master (carries current charges).
func _skillbook_inst(master: Dictionary, item: Dictionary) -> Dictionary:
	var classes: Array = master.get("equip_classes", [])
	var cid := String(classes[0]) if not classes.is_empty() else "DPS"
	return {
		"base_ability_id": String(master.get("base_ability_id", "")),
		"display_name": String(master.get("display_name", "")),
		"params": master.get("cast", {}),
		"charges": int(item.get("charges", master.get("charges_max", 0))),
		"charges_max": int(master.get("charges_max", 0)),
		"cooldown_s": 0.0,
		"equip_classes": classes,
		"color": item.get("color", UnitVisuals.role_color(cid)),
	}


## Backpack item from a displaced slot instance (preserves remaining charges; At-Risk).
func _skillbook_item_from_inst(inst: Dictionary) -> Dictionary:
	return {
		"id": String(inst.display_name),
		"w": 1, "h": 1,
		"color": inst.get("color", Color(0.5, 0.6, 0.85)),
		"kind": "skillbook",
		"base_ability_id": String(inst.base_ability_id),
		"charges": int(inst.charges),
		"charges_max": int(inst.charges_max),
		"at_risk": true,
	}


func _commit_sub_equip(m: Node, slot_index: int, item: Dictionary, master: Dictionary) -> void:
	var inst := _skillbook_inst(master, item)
	var displaced = m.set_skillbook(slot_index, inst)
	if displaced != null:
		if not _backpack.add_item_dict(_skillbook_item_from_inst(displaced)):
			push_warning("[TDC] Backpack full — displaced skillbook had nowhere to go")
	_refresh_sub_slots()
	_msg("%s %s → %s 장착" % [String(m.class_id), ["Q", "E", "R"][slot_index], String(master.get("display_name", ""))])


## Drag-drop equip a skillbook onto the sub slot at `flat_index` (item already lifted).
func _try_equip_sub(flat_index: int, item: Dictionary) -> bool:
	if flat_index < 0 or flat_index >= _sub_slots.size():
		return false
	var e = _sub_slots[flat_index]
	var m: Node = _party.get_member(int(e.char)) if _party != null else null
	var master: Dictionary = Slice01Data.get_skillbook_master(String(item.get("base_ability_id", "")))
	if m == null or master.is_empty():
		return false
	if _combat != null and _combat.is_engaged():
		_msg("전투 중에는 스킬북 교체 불가 (F-009 §3.4)")
		return false
	if not m.can_equip_skillbook(master):
		_msg("역할 불일치 — %s 전용 스킬북" % String((master.get("equip_classes", ["?"]) as Array)[0]))
		return false
	_commit_sub_equip(m, int(e.slot), item, master)
	return true


## Right-click equip: first matching-class char with an empty slot (else that char's Q).
func _equip_sub_to_first(grid: Node, item: Dictionary) -> void:
	var master: Dictionary = Slice01Data.get_skillbook_master(String(item.get("base_ability_id", "")))
	if master.is_empty():
		return
	if _combat != null and _combat.is_engaged():
		_msg("전투 중에는 스킬북 교체 불가 (F-009 §3.4)")
		return
	var members: Array = _party.get_members() if _party != null else []
	var fb_char := -1
	for ci in members.size():
		var m: Node = members[ci]
		if not m.can_equip_skillbook(master):
			continue
		if fb_char < 0:
			fb_char = ci
		for si in 3:
			if m.get_skillbook(si) == null:
				grid.lift(item)
				_commit_sub_equip(m, si, item, master)
				return
	if fb_char < 0:
		_msg("착용 가능한 %s 캐릭터 없음" % String((master.get("equip_classes", ["?"]) as Array)[0]))
		return
	grid.lift(item)
	_commit_sub_equip(members[fb_char], 0, item, master)


func _set_sub_preview(i: int, ok: bool) -> void:
	if i < 0 or i >= _sub_slots.size():
		return
	_sub_slots[i].overlay.color = SLOT_OK if ok else SLOT_BAD
	_sub_slots[i].overlay.visible = true


func _clear_sub_previews() -> void:
	for e in _sub_slots:
		e.overlay.visible = false


# --- drag OUT of an equip / sub slot (unequip to inventory, or move slot↔slot) --

func _on_gear_slot_input(event: InputEvent, char_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and _drag.is_empty():
		_begin_gear_slot_drag(char_index)
		accept_event()


func _on_sub_slot_input(event: InputEvent, flat_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and _drag.is_empty():
		_begin_sub_slot_drag(flat_index)
		accept_event()


func _begin_gear_slot_drag(char_index: int) -> void:
	var m: Node = _party.get_member(char_index) if _party != null else null
	if m == null or (m.equipped_gear as Dictionary).is_empty():
		return
	if _combat != null and _combat.is_engaged():
		_msg("전투 중에는 장비 해제 불가 (F-008 §4.2)")
		return
	if float(m.identity_cooldown_s) > 0.0:
		_msg("Identity 스킬 쿨다운 중 — 장비 해제 불가")
		return
	var item := _gear_item(m.equipped_gear, true)  # unequipped → At-Risk in inventory
	m.unequip_gear()
	_refresh_equip_slots()
	_start_drag_from_slot(item, {"kind": "gear", "char": char_index})


func _begin_sub_slot_drag(flat_index: int) -> void:
	if flat_index < 0 or flat_index >= _sub_slots.size():
		return
	var e = _sub_slots[flat_index]
	var m: Node = _party.get_member(int(e.char)) if _party != null else null
	if m == null:
		return
	var inst = m.get_skillbook(int(e.slot))
	if inst == null:
		return
	if _combat != null and _combat.is_engaged():
		_msg("전투 중에는 스킬북 해제 불가 (F-009 §3.4)")
		return
	if float(inst.cooldown_s) > 0.0:
		_msg("스킬북 쿨다운 중 — 해제 불가")
		return
	var item := _skillbook_item_from_inst(inst)
	m.set_skillbook(int(e.slot), null)
	_refresh_sub_slots()
	_start_drag_from_slot(item, {"kind": "sub", "char": int(e.char), "slot": int(e.slot)})


func _start_drag_from_slot(item: Dictionary, src: Dictionary) -> void:
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
			var m: Node = _party.get_member(int(_drag_src.char))
			if m != null:
				m.equip_gear(Slice01Data.get_gear_master(String(_drag.get("base_gear_id", ""))))
			_refresh_equip_slots()
		"sub":
			var m: Node = _party.get_member(int(_drag_src.char))
			if m != null:
				var master := Slice01Data.get_skillbook_master(String(_drag.get("base_ability_id", "")))
				m.set_skillbook(int(_drag_src.slot), _skillbook_inst(master, _drag))
			_refresh_sub_slots()
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
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if grid == _loot:
			_stow_to_backpack(grid, item)  # chest → backpack: auto-stow to free space
		elif String(item.get("kind", "")) == "gear":
			_equip_to_matching(grid, item)  # right-click → auto-equip to matching class
		elif String(item.get("kind", "")) == "skillbook":
			_equip_sub_to_first(grid, item)  # right-click → first matching sub slot
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
				_revert_drag()
			placed = true
	elif String(_drag.get("kind", "")) == "skillbook":
		var ssi := _sub_slot_under(mouse)
		if ssi >= 0:
			if not _try_equip_sub(ssi, _drag):
				_revert_drag()
			placed = true
	elif String(_drag.get("kind", "")) == "consumable":
		var bi := _consumable_bar_slot_under(mouse)
		if bi >= 0:
			assign_hotkey(bi, String(_drag.get("consumable_id", "")))
			_revert_drag()  # assigning doesn't consume — return the stack to the backpack
			placed = true
	elif String(_drag.get("kind", "")) == "hotkey":
		var hbi := _consumable_bar_slot_under(mouse)
		var src := int(_drag.get("src_slot", -1))
		if hbi == src:
			pass  # dropped back on its own slot → keep
		elif hbi >= 0:
			assign_hotkey(hbi, String(_drag.get("consumable_id", "")))  # move (uniqueness clears src)
		else:
			_unassign_hotkey(src)  # dropped away → unassign
		placed = true
	if not placed:
		var target := _grid_under(mouse)
		if target != null:
			var c := target.cell_from_global_topleft(topleft)
			if target.can_place(int(_drag.w), int(_drag.h), c.x, c.y):
				target.place(_drag, c.x, c.y)
				placed = true
		if not placed:  # revert to where it began (grid spot / gear slot / sub slot)
			_revert_drag()
	for g: InventoryGrid in _grids:
		g.clear_preview()
	_clear_slot_previews()
	_clear_sub_previews()
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
			var it = _consumable_under(get_viewport().get_mouse_position())
			if it != null:
				var cid := String(it.consumable_id)
				if String(_hotkeys[hk]) == cid:
					_unassign_hotkey(hk)  # hover the item on its own slot's key → toggle off
				else:
					assign_hotkey(hk, cid)
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
