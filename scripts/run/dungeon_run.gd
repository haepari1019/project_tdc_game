extends Node3D
## Slice-01 demo dungeon — party + run (steps 2–3).

const PartyCohesion := preload("res://scripts/party/party_cohesion.gd")

@onready var _run: Node = $RunController
@onready var _map: Node3D = $MapDemoLayout
@onready var _party: Node3D = $PartyController
@onready var _combat: Node3D = $CombatController
@onready var _hud_phase: Label = $HUD/Panel/Margin/VBox/PhaseValue
@onready var _hud_map: Label = $HUD/Panel/Margin/VBox/MapValue
@onready var _hud_room: Label = $HUD/Panel/Margin/VBox/RoomValue
@onready var _hud_controlled: Label = $HUD/Panel/Margin/VBox/ControlledValue
@onready var _hud_cohesion: Label = $HUD/Panel/Margin/VBox/CohesionValue
@onready var _hud_formation: Label = $HUD/Panel/Margin/VBox/FormationValue
@onready var _hud_sub: Label = $HUD/Panel/Margin/VBox/SubValue
@onready var _hud_hint: Label = $HUD/Panel/Margin/VBox/Hint
@onready var _banner: Label = $HUD/ResultBanner
@onready var _party_sheet: Control = $HUD/PartySheet
@onready var _controlled_sheet: Control = $HUD/ControlledSheet

# Ground-targeted sub (DPS/Nuker): press sub key → aim → click to cast at mouse.
var _aiming: bool = false
var _aim_member: CharacterBody3D = null
var _aim_marker: MeshInstance3D
var _aim_mat: StandardMaterial3D

# UI-001: controlled-character world indicator (foot disc + floating arrow).
var _ctrl_indicator: Node3D
var _ctrl_arrow: MeshInstance3D
var _ind_time: float = 0.0


func _ready() -> void:
	_map.room_entered.connect(_run.on_player_entered_room)
	_run.run_booted.connect(_on_run_booted)
	_run.run_phase_changed.connect(_on_phase_changed)
	_run.room_changed.connect(_on_room_changed)
	_run.run_ended.connect(_on_run_ended)
	_party.controlled_changed.connect(_on_controlled_changed)
	_party.cohesion_changed.connect(_on_cohesion_changed)
	_party.formation_priority_changed.connect(_on_formation_priority_changed)
	_party.party_in_combat = _run.party_in_combat
	_combat.setup(_party, _map)
	_run.encounter_triggered.connect(_combat.on_encounter_triggered)
	_combat.combat_started.connect(_on_combat_started)
	_combat.combat_ended.connect(_on_combat_ended)
	_run.start_run("RM-ENTRY-01")
	var spawn: Vector3 = _map.get_spawn_position("RM-ENTRY-01")
	_party.spawn_at(spawn)
	_party_sheet.setup(_party.get_members())
	_controlled_sheet.setup(_party)
	_build_aim_marker()
	_build_controlled_indicator()
	_focus_camera()


func _process(delta: float) -> void:
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl:
		$CameraPivot.global_position = ctrl.global_position
		_hud_sub.text = "Ready" if ctrl.sub_cooldown_s <= 0.0 else "%.1fs" % ctrl.sub_cooldown_s
		# UI-001: controlled indicator follows + bobbing arrow.
		_ind_time += delta
		_ctrl_indicator.visible = true
		_ctrl_indicator.global_position = ctrl.global_position
		_ctrl_arrow.position.y = 2.3 + sin(_ind_time * 3.0) * 0.12
		# Extraction: reach POINT-DEMO-01 with objective done → Run Success.
		if not _run.run_over and _run.objective_complete:
			if ctrl.global_position.distance_to(_map.get_extraction_position()) < 3.0:
				_run.try_extract()
	elif _ctrl_indicator:
		_ctrl_indicator.visible = false
	if _aiming:
		_aim_marker.global_position = _mouse_ground_pos() + Vector3(0, 0.05, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _aiming:
			_end_aim()
		else:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	# Aiming a ground-targeted sub: left click = cast, right click = cancel.
	if _aiming and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_combat.cast_sub(_aim_member, _mouse_ground_pos())
				_end_aim()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_end_aim()
		return
	if event.is_action_pressed("use_sub"):
		_on_sub_key()
	if event.is_action_pressed("debug_advance_phase"):
		_run.advance_phase_debug()
	if event.is_action_pressed("toggle_cohesion"):
		_party.toggle_cohesion_mode()
	if event.is_action_pressed("toggle_formation_priority"):
		_party.toggle_formation_priority()
	for i in 4:
		if event.is_action_pressed("swap_party_%d" % (i + 1)):
			if _aiming:
				_end_aim()
			_party.try_swap_to(i)
			_focus_camera()


func _on_sub_key() -> void:
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl == null or not ctrl.is_alive() or ctrl.is_stunned() or ctrl.sub_cooldown_s > 0.0:
		return
	if bool(ctrl.sub_params.get("targeted", false)):
		_start_aim(ctrl)
	else:
		_combat.cast_sub(ctrl)


func _start_aim(member: CharacterBody3D) -> void:
	_aiming = true
	_aim_member = member
	var r: float = float(member.sub_params.get("radius_m", member.sub_params.get("aoe_radius_m", 3.0)))
	_aim_marker.scale = Vector3(r, 1.0, r)
	var cc: Color = member.get_class_color()
	_aim_mat.albedo_color = Color(cc.r, cc.g, cc.b, 0.35)
	_aim_marker.visible = true


func _end_aim() -> void:
	_aiming = false
	_aim_member = null
	_aim_marker.visible = false


func _mouse_ground_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var mp := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	if absf(dir.y) < 0.0001:
		return from
	return from + dir * (-from.y / dir.y)


func _build_aim_marker() -> void:
	_aim_marker = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.06
	_aim_marker.mesh = disc
	_aim_mat = StandardMaterial3D.new()
	_aim_mat.albedo_color = Color(1, 1, 0.3, 0.35)
	_aim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aim_mat.no_depth_test = true
	_aim_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_aim_marker.material_override = _aim_mat
	_aim_marker.visible = false
	add_child(_aim_marker)


func _build_controlled_indicator() -> void:
	_ctrl_indicator = Node3D.new()
	add_child(_ctrl_indicator)
	# Foot highlight disc (respects depth — sits on the ground).
	var disc_mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.85
	disc.bottom_radius = 0.85
	disc.height = 0.05
	disc_mi.mesh = disc
	disc_mi.position.y = 0.07
	disc_mi.material_override = _ind_mat(Color(0.70, 0.95, 1.0, 0.28), false)
	_ctrl_indicator.add_child(disc_mi)
	# Floating downward arrow above the head (always visible).
	_ctrl_arrow = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.22
	cone.height = 0.42
	_ctrl_arrow.mesh = cone
	_ctrl_arrow.rotation_degrees = Vector3(180, 0, 0)  # apex points down
	_ctrl_arrow.position.y = 2.3
	_ctrl_arrow.material_override = _ind_mat(Color(0.78, 0.97, 1.0, 0.95), true)
	_ctrl_indicator.add_child(_ctrl_arrow)


func _ind_mat(color: Color, no_depth: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = no_depth
	return m


func _focus_camera() -> void:
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl:
		$CameraPivot.global_position = ctrl.global_position


func _on_combat_started(_encounter_id: String) -> void:
	_run.party_in_combat = true
	_party.party_in_combat = true
	print("[TDC] partyInCombat=true")  # state only — swap stays allowed (F-001 §3.3)


func _on_combat_ended(result: String, _encounter_id: String) -> void:
	_run.party_in_combat = false
	_party.party_in_combat = false
	print("[TDC] partyInCombat=false (%s)" % result)


func _on_run_ended(result: String) -> void:
	_banner.text = "★ RUN %s ★\n(Esc → menu)" % result.to_upper()
	_banner.visible = true


func _on_run_booted(state: Dictionary) -> void:
	_refresh_hud(state)


func _on_phase_changed(phase: String) -> void:
	_hud_phase.text = phase


func _on_room_changed(room_ref: String) -> void:
	_hud_room.text = room_ref


func _on_controlled_changed(member: CharacterBody3D) -> void:
	_hud_controlled.text = "%s (%s)" % [member.identity_skill_id, member.class_id]


func _on_cohesion_changed(mode: int) -> void:
	_hud_cohesion.text = (
		"파티비결속" if mode == PartyCohesion.MODE_UNBOUND else "파티결속"
	)


func _on_formation_priority_changed(on: bool) -> void:
	_hud_formation.text = "진형우선" if on else "전투우선"


func _refresh_hud(state: Dictionary) -> void:
	_hud_phase.text = String(state.get("run_phase", "?"))
	_hud_map.text = String(state.get("map_id", "?"))
	_hud_room.text = String(state.get("current_room_ref", "?"))
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl:
		_hud_controlled.text = "%s (%s)" % [ctrl.identity_skill_id, ctrl.class_id]
	_hud_cohesion.text = "파티결속"
	_hud_formation.text = "진형우선" if _party.is_formation_priority() else "전투우선"
	_hud_hint.text = "WASD · 1-4 swap · Q skill · U cohesion · F 진형우선 · Esc menu"
