extends Node3D
## Targeted revive (F-010 / D-020 con_revive_scroll) — a hotkey/RMB starts targeting; clicking
## a downed ally (world corpse or party-sheet portrait) channels a 1.5s light pillar, then
## revives at 50% HP. Out-of-combat only. setup() then drive via try_start / handle_click /
## cancel / is_active. Owns its own prompt label. ref: F-010 §3.4 / D-020.

const SkillVfx := preload("res://scripts/combat/skill_vfx.gd")

var _party: Node3D
var _combat: Node3D
var _inv: Node            # InventoryUI — consumable_count / consume_consumable
var _sheet: Control       # PartySheet — portrait_member_under
var _prompt: Label
var _active: bool = false
var _cid: String = ""


func setup(party: Node3D, combat: Node3D, inventory_ui: Node, party_sheet: Control, hud: Node) -> void:
	_party = party
	_combat = combat
	_inv = inventory_ui
	_sheet = party_sheet
	_prompt = _make_prompt(Color(0.6, 1.0, 0.7))
	hud.add_child(_prompt)


func is_active() -> bool:
	return _active


func cancel() -> void:
	_active = false
	_prompt.visible = false


## Begin targeting for consumable `cid` (master from consumables.json). Re-press toggles off.
func try_start(cid: String, master: Dictionary) -> void:
	if _active:
		cancel()
		return
	if not bool(master.get("usable_in_combat", true)) and _combat.is_engaged():
		_toast("전투 중 사용 불가")
		return
	if _inv.consumable_count(cid) <= 0:
		_toast("보유 없음")
		return
	var has_downed := false
	for m in _party.get_members():
		if not (m as Node).is_alive():
			has_downed = true
			break
	if not has_downed:
		_toast("다운된 아군 없음")
		return
	_active = true
	_cid = cid
	_prompt.text = "부활: 죽은 아군(시체/초상화) 클릭 · 우클릭 취소"
	_prompt.visible = true


## While targeting: LMB on a downed ally channels the revive; RMB cancels. Returns true if
## the event was consumed.
func handle_click(event: InputEvent) -> bool:
	if not _active or not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return false
	var rb := event as InputEventMouseButton
	if rb.button_index == MOUSE_BUTTON_LEFT:
		var tgt := _pick_downed_target()
		if tgt != null:
			_begin_channel(tgt)
		return true
	if rb.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
		return true
	return false


## The downed party member under the cursor — party-sheet portrait first, then world ray.
func _pick_downed_target() -> Node:
	var mouse := get_viewport().get_mouse_position()
	var pm: Node = _sheet.portrait_member_under(mouse)
	if pm != null and not pm.is_alive():
		return pm
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var from := cam.project_ray_origin(mouse)
	var to := from + cam.project_ray_normal(mouse) * 1000.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 << 1)  # LAYER_PARTY
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var n: Node = hit.collider
		if n != null and n.has_method("is_alive") and not n.is_alive():
			return n
	return null


func _begin_channel(member: Node) -> void:
	_active = false
	_prompt.visible = false
	SkillVfx.revive_pillar(self, (member as Node3D).global_position, 1.5)
	get_tree().create_timer(1.5).timeout.connect(_finish.bind(member, _cid))


func _finish(member: Node, cid: String) -> void:
	if is_instance_valid(member) and not member.is_alive() and _inv.consume_consumable(cid):
		member.revive(0.5)


func _toast(msg: String) -> void:
	_prompt.text = msg
	_prompt.visible = true
	get_tree().create_timer(1.2).timeout.connect(_hide_toast)


func _hide_toast() -> void:
	if not _active:
		_prompt.visible = false


func _make_prompt(col: Color) -> Label:
	var l := Label.new()
	l.visible = false
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = 92
	l.offset_bottom = 120
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 18)
	l.modulate = col
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
