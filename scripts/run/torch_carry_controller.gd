extends Node
## Torch carry + throw (ENT-TORCH, F-021 §3.1.2) — the ally holds a torch in a consumable slot
## (auto into the first empty slot, else the player picks Z/X/C), then that slot key aims a
## ground-targeted throw (reuses the shared aim marker). setup() then drive via handle_* /
## on_torch_*. The caller (router) owns mutual exclusion via the `blocked` arg. Owns its prompt.

var _party: Node3D
var _aim: Node3D          # AimMarker — show_at / hide_marker / ground_pos
var _bar: Control         # ConsumableBar — set_carry / clear_carry
var _inv: Node            # InventoryUI — get_hotkey / is_open
var _prompt: Label
var _carried: Node = null
var _slot: int = -1
var _pick: bool = false   # waiting for the player to press Z/X/C to choose a slot
var _pending: Node = null
var _throwing: bool = false


func setup(party: Node3D, aim_marker: Node3D, consumable_bar: Control, inventory_ui: Node, hud: Node) -> void:
	_party = party
	_aim = aim_marker
	_bar = consumable_bar
	_inv = inventory_ui
	_prompt = Label.new()
	_prompt.visible = false
	_prompt.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_prompt.offset_top = 92
	_prompt.offset_bottom = 120
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.modulate = Color(1.0, 0.78, 0.4)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_prompt)


func is_active() -> bool:
	return _pick or _throwing


func cancel() -> void:
	if _pick:
		_pick = false
		_pending = null
		_prompt.visible = false
	elif _throwing:
		_throwing = false
		_aim.hide_marker()
		_prompt.visible = false


## Torch.pickup_requested → choose a slot (auto first-empty, else ask). Connected per torch.
func on_torch_pickup(torch: Node) -> void:
	if _carried != null or _pick or _throwing or _party.get_controlled() == null:
		return
	_pending = torch
	var empty := _first_empty_slot()
	if empty >= 0:
		_assign_slot(empty)
		return
	_pick = true
	_prompt.text = "횃불 슬롯 선택: Z / X / C  · 우클릭/Esc 취소"
	_prompt.visible = true


## Torch.dropped (carrier died) → release the slot binding.
func on_torch_dropped(torch: Node) -> void:
	if _carried == torch:
		if _throwing:
			cancel()
		_clear()


## Z/X/C: choose the slot (carry-pick, always) or aim a throw (carry slot). `blocked` = another
## modal (skillbook aim / revive) is active → suppress the throw-start. Returns true if consumed.
func handle_consumable_key(slot: int, blocked: bool) -> bool:
	if _pick:
		_assign_slot(slot)
		return true
	if _inv.is_open() or blocked:
		return false
	if slot == _slot:
		_begin_throw()
		return true
	return false


## While throwing: LMB throws to the ground point, RMB cancels. Returns true if consumed.
func handle_click(event: InputEvent) -> bool:
	if not _throwing or not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return false
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_do_throw(_aim.ground_pos())
		return true
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
		return true
	return false


func _first_empty_slot() -> int:
	for i in 3:
		if String(_inv.get_hotkey(i)).is_empty():
			return i
	return -1


func _assign_slot(slot: int) -> void:
	var torch := _pending
	_pick = false
	_pending = null
	_prompt.visible = false
	var ctrl: CharacterBody3D = _party.get_controlled()
	if torch == null or not is_instance_valid(torch) or ctrl == null:
		return
	_slot = slot
	_carried = torch
	torch.pick_up(ctrl)
	if _bar.has_method("set_carry"):
		_bar.set_carry(slot, "횃불\n던지기")


func _begin_throw() -> void:
	if _carried == null:
		return
	_throwing = true
	_aim.show_at(2.4, Color(1.0, 0.5, 0.15, 0.35))   # Torch.IGNITE_RADIUS
	_prompt.text = "횃불 투척: 지면 클릭 · 우클릭/Esc 취소"
	_prompt.visible = true


func _do_throw(point: Vector3) -> void:
	if _carried != null and is_instance_valid(_carried):
		_carried.throw_to(point)
	_clear()
	_throwing = false
	_aim.hide_marker()
	_prompt.visible = false


func _clear() -> void:
	if _bar != null and _bar.has_method("clear_carry"):
		_bar.clear_carry()
	_slot = -1
	_carried = null
