extends Node
## ConsumableController — consumable stacking, the Z/X/C hotkey state, and gameplay use,
## extracted from InventoryUI (ARCHITECTURE DEBT-INV). Owns the hotkey assignments + drives the
## bound on-screen bar widget (consumable_bar.gd via `_bar`); reads/writes the player backpack
## through the coordinator (`_inv.backpack_grid()`) and starts a hotkey drag via the shared
## router (`_inv.start_drag_from_slot`). The coordinator keeps thin public wrappers
## (setup_consumable_bar/add_consumable_to_backpack/use_consumable/…) so external callers
## (dungeon_run, revive/torch controllers) are unaffected. ref: F-010.

const ItemFactory := preload("res://scripts/ui/inventory/item_factory.gd")

## Drop-in consumable effects (consumable_effects/<name>.gd, each: kind()+apply(master, ctx)->bool).
## ADD A CONSUMABLE EFFECT = create the file + add one preload line here. kind()=master.effect.
const _EFFECT_SCRIPTS := [
	preload("res://scripts/ui/inventory/consumable_effects/revive_ally.gd"),
]

var _inv: Control = null            # InventoryUI coordinator (backpack + drag owner)
var _party: Node = null
var _combat: Node = null
var _bar: Node = null               # the on-screen consumable bar widget (Z/X/C)
var _hotkeys: Array = ["", "", ""]  # party-shared; each = consumable_id or ""
var _effects: Dictionary = {}       # effect string -> effect instance (from _EFFECT_SCRIPTS)


func setup(inv: Control) -> void:
	_inv = inv
	for s in _EFFECT_SCRIPTS:
		var e = s.new()
		_effects[String(e.kind())] = e


## The party (consumable effects reach members through this). ref: drop-in effects.
func get_party() -> Node:
	return _party


func bind_party(party: Node, combat: Node) -> void:
	_party = party
	_combat = combat


func setup_bar(bar: Node) -> void:
	_bar = bar
	if bar.has_signal("slot_grabbed") and not bar.slot_grabbed.is_connected(_begin_hotkey_drag):
		bar.slot_grabbed.connect(_begin_hotkey_drag)
	_refresh_ui()


func set_interactive(on: bool) -> void:
	if _bar != null and is_instance_valid(_bar) and _bar.has_method("set_interactive"):
		_bar.set_interactive(on)


# --- backpack stacking ----------------------------------------------------------

## Add `amount` of a consumable, filling existing stacks (≤ max_stack) then new tiles.
func add_to_backpack(consumable_id: String, amount: int) -> int:
	var master := Slice01Data.get_consumable_master(consumable_id)
	if master.is_empty() or amount <= 0:
		return 0
	var backpack = _inv.backpack_grid()
	var max_stack := int(master.get("max_stack", 1))
	var remaining := amount
	for it in backpack.items:
		if remaining <= 0:
			break
		if String(it.get("kind", "")) == "consumable" and String(it.get("consumable_id", "")) == consumable_id:
			var room := max_stack - int(it.get("count", 0))
			if room > 0:
				var add := mini(room, remaining)
				it.count = int(it.count) + add
				remaining -= add
				backpack.refresh_item_label(it)
	while remaining > 0:
		var n := mini(max_stack, remaining)
		if not backpack.add_item_dict(ItemFactory.consumable_item(master, n)):
			break
		remaining -= n
	_refresh_ui()
	return amount - remaining


func count(consumable_id: String) -> int:
	var n := 0
	for it in _inv.backpack_grid().items:
		if String(it.get("kind", "")) == "consumable" and String(it.get("consumable_id", "")) == consumable_id:
			n += int(it.get("count", 0))
	return n


func _find_stack(consumable_id: String):
	for it in _inv.backpack_grid().items:
		if String(it.get("kind", "")) == "consumable" and String(it.get("consumable_id", "")) == consumable_id and int(it.get("count", 0)) > 0:
			return it
	return null


## The consumable item under the cursor (for hover + Z/X/C hotkey assign).
func consumable_under(mouse: Vector2):
	for it in _inv.backpack_grid().items:
		if String(it.get("kind", "")) == "consumable" and it.has("node") and is_instance_valid(it.node):
			if (it.node as Control).get_global_rect().has_point(mouse):
				return it
	return null


# --- Z/X/C hotkeys --------------------------------------------------------------

## Drag a hotkey assignment OUT of a bar slot — to another slot (move) or away (unassign).
## Routed through the coordinator's shared drag so _drop handles the "hotkey" kind.
func _begin_hotkey_drag(slot: int) -> void:
	if _inv.is_dragging():
		return
	var cid := get_hotkey(slot)
	if cid.is_empty():
		return
	var master := Slice01Data.get_consumable_master(cid)
	var item := {
		"id": String(master.get("display_name", cid)), "w": 1, "h": 1,
		"color": ItemFactory.consumable_color(master), "kind": "hotkey", "consumable_id": cid, "src_slot": slot,
	}
	_inv.start_drag_from_slot(item, {"kind": "hotkey", "slot": slot})


func get_hotkey(slot: int) -> String:
	return String(_hotkeys[slot]) if slot >= 0 and slot < _hotkeys.size() else ""


func assign_hotkey(slot: int, consumable_id: String) -> void:
	if slot < 0 or slot >= _hotkeys.size():
		return
	for i in _hotkeys.size():  # uniqueness: the same consumable lives in only one slot
		if i != slot and String(_hotkeys[i]) == consumable_id:
			_hotkeys[i] = ""
	_hotkeys[slot] = consumable_id
	_refresh_ui()
	var nm := String(Slice01Data.get_consumable_master(consumable_id).get("display_name", consumable_id))
	_inv._msg("%s → %s 핫키 등록" % [["Z", "X", "C"][slot], nm])


func unassign_hotkey(slot: int) -> void:
	if slot < 0 or slot >= _hotkeys.size():
		return
	_hotkeys[slot] = ""
	_refresh_ui()
	_inv._msg("%s 핫키 해제" % ["Z", "X", "C"][slot])


func _refresh_ui() -> void:
	if _bar == null or not is_instance_valid(_bar) or not _bar.has_method("refresh"):
		return
	var data: Array = []
	for s in 3:
		var cid := String(_hotkeys[s])
		if cid.is_empty():
			data.append({})
		else:
			var m := Slice01Data.get_consumable_master(cid)
			data.append({"name": String(m.get("display_name", cid)), "count": count(cid), "color": ItemFactory.consumable_color(m)})
	_bar.refresh(data)


func bar_slot_under(mouse: Vector2) -> int:
	if _bar != null and is_instance_valid(_bar) and _bar.has_method("slot_under"):
		return _bar.slot_under(mouse)
	return -1


# --- gameplay use ---------------------------------------------------------------

## Gameplay use (Z/X/C while playing). Returns a status string for HUD feedback ("" = no-op).
func use(slot: int) -> String:
	var cid := get_hotkey(slot)
	if cid.is_empty():
		return ""
	var master := Slice01Data.get_consumable_master(cid)
	if master.is_empty():
		return ""
	if not bool(master.get("usable_in_combat", true)) and _combat != null and _combat.is_engaged():
		return "전투 중 사용 불가: %s" % master.get("display_name", cid)
	var stack = _find_stack(cid)
	if stack == null:
		return "보유 없음: %s" % master.get("display_name", cid)
	if not _apply(master):
		return "대상 없음: %s" % master.get("display_name", cid)
	_decrement(stack)
	return "%s 사용" % master.get("display_name", cid)


func _apply(master: Dictionary) -> bool:
	var effect = _effects.get(String(master.get("effect", "")))
	return effect.apply(master, self) if effect != null else false


## Consume 1 of a consumable (external callers, e.g. dungeon_run after a revive channel).
func consume(consumable_id: String) -> bool:
	var stack = _find_stack(consumable_id)
	if stack == null:
		return false
	_decrement(stack)
	return true


func _decrement(stack) -> void:
	var backpack = _inv.backpack_grid()
	stack.count = int(stack.count) - 1
	if int(stack.count) <= 0:
		backpack.lift(stack)
	else:
		backpack.refresh_item_label(stack)
	_refresh_ui()
