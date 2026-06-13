extends Node
## Skillbook ground-target aim (modal) — start_aim(member, slot, inst) shows the shared marker;
## a left click casts at the ground point, right/cancel ends. Uniform modal interface
## (is_active / cancel / handle_click) so the dungeon_run router treats it like the others.

var _aim: Node3D          # AimMarker — show_at / hide_marker / ground_pos
var _combat: Node3D       # CombatController — cast_skillbook
var _active: bool = false
var _member: CharacterBody3D = null
var _slot: int = -1


func setup(aim_marker: Node3D, combat: Node3D) -> void:
	_aim = aim_marker
	_combat = combat


## Enter aim mode for a targeted skillbook slot (caller checks charges/cooldown/targeted).
func start_aim(member: CharacterBody3D, slot_index: int, inst: Dictionary) -> void:
	_active = true
	_member = member
	_slot = slot_index
	var p: Dictionary = inst.params
	var r: float = float(p.get("radius_m", p.get("aoe_radius_m", 3.0)))
	var cc: Color = member.get_class_color()
	_aim.show_at(r, Color(cc.r, cc.g, cc.b, 0.35))


func is_active() -> bool:
	return _active


func cancel() -> void:
	_active = false
	_member = null
	_slot = -1
	_aim.hide_marker()


## While aiming: LMB casts at the ground point, RMB cancels. Returns true if consumed.
func handle_click(event: InputEvent) -> bool:
	if not _active or not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return false
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_combat.cast_skillbook(_member, _slot, _aim.ground_pos())
		cancel()
		return true
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
		return true
	return false
