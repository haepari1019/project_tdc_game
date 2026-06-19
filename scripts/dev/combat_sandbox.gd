extends Node3D
## DEBUG combat sandbox — a one-room arena + an ENC dropdown. Spawn ANY encounter to watch its
## combat behavior in isolation (no fog, no run-loop, no traversal). Run this scene directly.
## Reuses the real PartyController / CombatController / CameraRig so behavior matches the game.
## dev tooling only — not referenced by the shipping flow. ref: ROADMAP P2 (F5 debugging).

const SandboxMap := preload("res://scripts/dev/sandbox_map.gd")
const PartyController := preload("res://scripts/party/party_controller.gd")
const CombatController := preload("res://scripts/combat/combat_controller.gd")
const CameraRig := preload("res://scripts/run/controllers/camera_rig.gd")

# Skillbooks auto-equipped so Q/E/R subs (incl. Toll Stun for channel-interrupt testing) work
# without the hub deploy step. slot -> base_ability_id (role gate is bypassed for the sandbox).
const SANDBOX_SUBS := {
	"Tank": ["AB-002", "AB-011", ""],     # Shield Bash, Toll Stun
	"DPS": ["AB-037", "AB-011", ""],      # Ember Lance, Toll Stun
	"Nuker": ["AB-010", "AB-037", ""],    # Venom, Ember Lance
	"Healer": ["AB-010", "AB-002", ""],   # Venom, Shield Bash
}

var _map: Node3D
var _party: Node3D
var _combat: Node3D
var _camera: Node3D
var _enc_dropdown: OptionButton
var _engaged_chk: CheckBox
var _status: Label
var _cam_dragging := false


func _ready() -> void:
	_build_environment()

	_map = Node3D.new()
	_map.set_script(SandboxMap)
	_map.name = "SandboxMap"
	add_child(_map)

	# PartyController needs a "Members" child before its _ready runs.
	_party = Node3D.new()
	_party.set_script(PartyController)
	_party.name = "PartyController"
	var members := Node3D.new()
	members.name = "Members"
	_party.add_child(members)
	add_child(_party)

	_combat = Node3D.new()
	_combat.set_script(CombatController)
	_combat.name = "CombatController"
	add_child(_combat)

	# CameraRig wants a $Camera3D child present when its _ready runs → add the child, set the
	# script, THEN add the pivot to the tree (so _ready sees the camera).
	_camera = Node3D.new()
	_camera.name = "CameraPivot"
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	_camera.add_child(cam)
	_camera.set_script(CameraRig)
	add_child(_camera)

	# Wire the systems exactly like dungeon_run (minus fog/HUD/run-loop).
	_combat.setup(_party, _map)
	_party.bind_combat(_combat)
	if _combat.has_signal("camera_shake"):
		_combat.camera_shake.connect(_camera.add_shake)
	_party.spawn_at(_map.get_spawn_position("SANDBOX"))
	_equip_sandbox_subs()
	_camera.set_follow_target(_party.get_controlled())
	_party.controlled_changed.connect(func(_m: Node) -> void: _camera.set_follow_target(_party.get_controlled()))

	_build_ui()


## Auto-equip a couple of looted-skill stand-ins per member so Q/E/R subs work for testing
## (esp. AB-011 Toll Stun → channel interrupt). Bypasses the role gate via direct slot set.
func _equip_sandbox_subs() -> void:
	for m in _party.get_members():
		var subs: Array = SANDBOX_SUBS.get(String(m.get("class_id")), [])
		for i in mini(subs.size(), 3):
			if String(subs[i]) != "" and m.has_method("equip_skillbook_by_id"):
				m.equip_skillbook_by_id(i, String(subs[i]))


func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(40.0), 0.0)
	sun.light_energy = 1.1
	add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.10, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.62)
	env.ambient_light_energy = 0.7
	we.environment = env
	add_child(we)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(16, 16)
	box.add_theme_constant_override("separation", 6)
	layer.add_child(box)

	var title := Label.new()
	title.text = "COMBAT SANDBOX (dev)"
	box.add_child(title)

	_enc_dropdown = OptionButton.new()
	_enc_dropdown.custom_minimum_size = Vector2(220, 0)
	for eid in Slice01Data.get_encounter_ids():
		_enc_dropdown.add_item(String(eid))
	box.add_child(_enc_dropdown)

	_engaged_chk = CheckBox.new()
	_engaged_chk.text = "spawn engaged (skip perception)"
	_engaged_chk.button_pressed = true
	box.add_child(_engaged_chk)

	var spawn_btn := Button.new()
	spawn_btn.text = "Spawn ENC"
	spawn_btn.pressed.connect(_on_spawn)
	box.add_child(spawn_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear enemies"
	clear_btn.pressed.connect(_on_clear)
	box.add_child(clear_btn)

	var hint := Label.new()
	hint.text = "1-4 swap · WASD move · Q/E/R sub · wheel zoom · RMB-drag orbit · [ ] pitch"
	hint.add_theme_font_size_override("font_size", 12)
	box.add_child(hint)

	_status = Label.new()
	box.add_child(_status)


func _on_spawn() -> void:
	if _enc_dropdown.selected < 0:
		return
	var eid := _enc_dropdown.get_item_text(_enc_dropdown.selected)
	_combat.debug_spawn_only(eid, "SANDBOX", _engaged_chk.button_pressed)
	_status.text = "spawned: %s%s" % [eid, "  (engaged)" if _engaged_chk.button_pressed else "  (dormant)"]


func _on_clear() -> void:
	_combat.debug_spawn_only("", "SANDBOX")
	_status.text = "cleared"


# --- minimal input (swap + camera) — mirrors dungeon_run's forwarding ---
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_camera.zoom(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_camera.zoom(-1)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_cam_dragging = event.pressed
	if event is InputEventMouseMotion and _cam_dragging:
		_camera.orbit_yaw(event.relative.x)
		_camera.pitch_by_drag(event.relative.y)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _party.try_swap_to(0)
			KEY_2: _party.try_swap_to(1)
			KEY_3: _party.try_swap_to(2)
			KEY_4: _party.try_swap_to(3)
			KEY_BRACKETLEFT: _camera.adjust_pitch(-3.0)
			KEY_BRACKETRIGHT: _camera.adjust_pitch(3.0)
			KEY_Q: _cast_sub(0)
			KEY_E: _cast_sub(1)
			KEY_R: _cast_sub(2)


func _cast_sub(slot: int) -> void:
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl == null or not ctrl.is_alive() or ctrl.is_stunned():
		return
	if ctrl.has_method("is_provoked") and ctrl.is_provoked():
		return
	_combat.cast_skillbook(ctrl, slot, ctrl.global_position)
