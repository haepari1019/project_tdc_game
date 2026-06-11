extends Node3D
## Slice-01 demo dungeon — party + run (steps 2–3).

const PartyCohesion := preload("res://scripts/party/party_cohesion.gd")
const EnemyVisibility := preload("res://scripts/run/enemy_visibility.gd")
const DamageIndicator := preload("res://scripts/ui/damage_indicator.gd")
const InventoryUI := preload("res://scripts/ui/inventory_ui.gd")
const Chest := preload("res://scripts/run/chest.gd")
const InteractionController := preload("res://scripts/run/interaction_controller.gd")
const Door := preload("res://scripts/run/door.gd")
const ItemDrop := preload("res://scripts/run/item_drop.gd")
const QuestTracker := preload("res://scripts/ui/quest_tracker.gd")
const Minimap := preload("res://scripts/ui/minimap.gd")
const EnemyInfo := preload("res://scripts/ui/enemy_info.gd")
const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")

## PH loot table — a defeated enemy drops one of these as a world pickup. ref: F-010.
const LOOT_TABLE: Array = [
	{"id": "Ammo", "w": 1, "h": 1, "color": Color(0.80, 0.55, 0.30)},
	{"id": "Medkit", "w": 1, "h": 1, "color": Color(0.85, 0.30, 0.30)},
	{"id": "Scrap", "w": 1, "h": 1, "color": Color(0.55, 0.58, 0.62)},
	{"id": "Cell", "w": 1, "h": 2, "color": Color(0.62, 0.45, 0.82)},
]

## PH gear-loot pool — dungeon-dropped Identity Gear (F-008 §3.3 / DEC-20260611-001;
## looted = At Risk). A same-role set (Tank) the player can equip + a cross-role set
## (Healer) to show the equipClasses gate reject. Masters live in gear.json.
const GEAR_LOOT: Array = ["gear_ward_tank_anchor_set", "gear_ward_healer_mend_set"]
const GEAR_DROP_CHANCE := 0.4

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
@onready var _hud_state: Label = $HUD/Panel/Margin/VBox/StateValue
@onready var _hud_sub: Label = $HUD/Panel/Margin/VBox/SubValue
@onready var _hud_hint: Label = $HUD/Panel/Margin/VBox/Hint
@onready var _banner: Label = $HUD/ResultBanner
@onready var _extract_count: Label = $HUD/ExtractCount
@onready var _camera_rig: Node3D = $CameraPivot  # camera_rig.gd: follow/glide/orbit/shake
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

# Directional damage indicator — screen-edge red glow on the controlled char's hits.
var _damage_indicator: DamageIndicator
# Inventory UI (i) — backpack + loot grids, drag&drop / rotation / cross-container.
var _inventory_ui: InventoryUI
# World interaction (E) — chest/door proximity prompts.
var _interaction: InteractionController
var _interact_prompt: Label
# Enemy inspect (LMB click) — top-center portrait/HP panel.
var _enemy_info: EnemyInfo

# Camera orbit: RMB + horizontal drag yaws the camera rig. Follow/glide/shake live
# in camera_rig.gd ($CameraPivot); dungeon_run only forwards input + swap focus here.
var _cam_dragging: bool = false
var _rmb_move_accum: float = 0.0  # RMB click(=interact) vs drag(=camera orbit) discriminator

# F-007 ExtractionActivate — hold at the extraction point this long to complete.
# Longer while partyInCombat (적이 붙어 있으면 탈출이 더 어렵다). Channel time is
# "후속 UI/전투 SSOT" in F-007 §3.1.2 → tuning (game SPEC_DRIFT).
const EXTRACT_HOLD_S := 5.0          # 비전투
const EXTRACT_HOLD_COMBAT_S := 30.0  # 전투중(partyInCombat)
const EXTRACT_RADIUS_M := 3.0
var _extract_active: bool = false
var _extract_remaining_s: float = 0.0   # hold countdown (s)
var _extract_combat: bool = false        # combat state the current countdown was sized for


func _ready() -> void:
	_map.room_entered.connect(_run.on_player_entered_room)
	_run.run_booted.connect(_on_run_booted)
	_run.run_phase_changed.connect(_on_phase_changed)
	_run.room_changed.connect(_on_room_changed)
	_run.run_ended.connect(_on_run_ended)
	_party.controlled_changed.connect(_on_controlled_changed)
	_party.cohesion_changed.connect(_on_cohesion_changed)
	_party.formation_priority_changed.connect(_on_formation_priority_changed)
	_combat.engagement_changed.connect(_on_engagement_changed)
	_combat.camera_shake.connect(_camera_rig.add_shake)
	_combat.party_hit.connect(_on_party_hit)
	_combat.enemy_defeated.connect(_on_enemy_loot)
	_combat.setup(_party, _map)
	_party.bind_combat(_combat)
	var enemy_vis := EnemyVisibility.new()
	add_child(enemy_vis)
	enemy_vis.setup(_party)
	_run.start_run("RM-ENTRY-01")
	var spawn: Vector3 = _map.get_spawn_position("RM-ENTRY-01")
	_party.spawn_at(spawn)
	# Pre-spawn all encounters as dormant squads, pushed to each room's far side
	# (away from the party) so the start-adjacent room isn't in range at spawn.
	_combat.prespawn_encounters("RM-ENTRY-01")
	_party_sheet.setup(_party.get_members())
	_controlled_sheet.setup(_party)
	_build_aim_marker()
	_build_controlled_indicator()
	_damage_indicator = DamageIndicator.new()
	$HUD.add_child(_damage_indicator)
	_inventory_ui = InventoryUI.new()
	$HUD.add_child(_inventory_ui)
	_inventory_ui.setup_party(_party, _combat)  # party gear equip slots (F-008 §3.2)
	# World loop — chest (holding the extraction key) in the objective room.
	var chest := Chest.new()
	chest.title = "유물함"
	chest.items = [{"id": "Key", "w": 1, "h": 1, "col": 0, "row": 0, "color": Color(0.95, 0.82, 0.22)}]
	chest.setup(_inventory_ui)
	chest.position = _map.get_spawn_position("RM-OBJ-01") + Vector3(3.0, 0.0, 0.0)
	add_child(chest)
	# Keyed door blocking the route→extraction opening (RM-ROUTE-01 → RM-EXT-01 @ z=77.25).
	var door := Door.new()
	door.setup(_inventory_ui, _run)
	door.position = Vector3(27.0, 0.0, 77.25)
	add_child(door)
	# Proximity interaction prompt + controller.
	_interact_prompt = _make_interact_prompt()
	$HUD.add_child(_interact_prompt)
	_interaction = InteractionController.new()
	add_child(_interaction)
	_interaction.setup(_party, _interact_prompt, _inventory_ui)
	# Quest tracker (top-right, below the reserved minimap space).
	var quest := QuestTracker.new()
	$HUD.add_child(quest)
	quest.setup(_inventory_ui, _run)
	# Minimap (top-right, above the quest tracker).
	var minimap := Minimap.new()
	$HUD.add_child(minimap)
	minimap.setup(_map, _party)
	# Enemy inspect panel (top-center), shown on left-click of an enemy.
	_enemy_info = EnemyInfo.new()
	$HUD.add_child(_enemy_info)
	_camera_rig.set_follow_target(_party.get_controlled())  # glide in from rig origin


func _process(delta: float) -> void:
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl:
		_hud_sub.text = "Ready" if ctrl.sub_cooldown_s <= 0.0 else "%.1fs" % ctrl.sub_cooldown_s
		# UI-001: controlled indicator follows + bobbing arrow.
		_ind_time += delta
		_ctrl_indicator.visible = true
		_ctrl_indicator.global_position = ctrl.global_position
		_ctrl_arrow.position.y = 2.3 + sin(_ind_time * 3.0) * 0.12
		# Extraction (F-007 ExtractionActivate): hold at POINT-DEMO-01 for
		# EXTRACT_HOLD_S with the objective done → Run Success. Leaving the zone
		# cancels (no failure — F-007: 미완료=런 지속). Big countdown UI ticks down.
		var in_extract: bool = not _run.run_over and _run.objective_complete \
				and ctrl.global_position.distance_to(_map.get_extraction_position()) < EXTRACT_RADIUS_M
		_update_extraction(in_extract, delta)
	elif _ctrl_indicator:
		_ctrl_indicator.visible = false
	if _aiming:
		_aim_marker.global_position = _mouse_ground_pos() + Vector3(0, 0.05, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _inventory_ui.is_open():
			_inventory_ui.toggle()  # Esc closes the inventory first
		elif _aiming:
			_end_aim()
		else:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	if event.is_action_pressed("toggle_inventory"):
		if _aiming:
			_end_aim()
		_inventory_ui.toggle()
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
	# Left-click (not aiming) inspects an enemy in the top-center panel; empty space clears.
	if event is InputEventMouseButton:
		var lb := event as InputEventMouseButton
		if lb.button_index == MOUSE_BUTTON_LEFT and lb.pressed:
			_select_enemy_under_mouse()
			return
	# RMB: drag = camera orbit; a click (negligible drag) = interact the nearest object.
	# (E is reserved for a future sub-skill, so world interaction uses the right mouse.)
	if event is InputEventMouseButton:
		var cam_btn := event as InputEventMouseButton
		if cam_btn.button_index == MOUSE_BUTTON_RIGHT:
			if cam_btn.pressed:
				_cam_dragging = true
				_rmb_move_accum = 0.0
			else:
				_cam_dragging = false
				if _rmb_move_accum < 8.0:
					_interaction.try_interact()  # RMB click (not a drag) → interact
			return
	if event is InputEventMouseMotion and _cam_dragging:
		var mm := event as InputEventMouseMotion
		_rmb_move_accum += absf(mm.relative.x) + absf(mm.relative.y)
		_camera_rig.orbit_yaw(mm.relative.x)
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
			_party.try_swap_to(i)  # success → controlled_changed → rig glides to new char


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


## ExtractionActivate hold-channel: a countdown that ticks down while in the zone and
## completes at 0. Combat sizes it to 30s; clearing combat SHORTENS the remaining to the
## 5s safe hold (capped, so it doesn't instant-complete); starting combat re-extends to
## 30s. Leaving the zone cancels (reset). Big countdown ticks high→low.
func _update_extraction(in_zone: bool, delta: float) -> void:
	if not in_zone:
		if _extract_active:
			_extract_active = false
			_extract_count.visible = false
		return
	var combat: bool = _combat.is_engaged()
	if not _extract_active:
		_extract_active = true
		_extract_combat = combat
		_extract_remaining_s = EXTRACT_HOLD_COMBAT_S if combat else EXTRACT_HOLD_S
	elif combat != _extract_combat:
		# Combat starting re-extends to the long hold; combat clearing shortens the
		# remaining to (at most) the safe hold instead of instantly completing.
		_extract_remaining_s = EXTRACT_HOLD_COMBAT_S if combat else minf(_extract_remaining_s, EXTRACT_HOLD_S)
		_extract_combat = combat
	_extract_remaining_s -= delta
	if _extract_remaining_s <= 0.0:
		_extract_active = false
		_extract_count.visible = false
		_run.try_extract()  # → run_ended("Success") (F-007 §3.1.2 정산)
		return
	_extract_count.visible = true
	_extract_count.text = "%d" % int(ceil(_extract_remaining_s))  # 30…/5… → 1


## Left-click → ray-pick an enemy (collision layer 4) for the inspect panel; else clear.
func _select_enemy_under_mouse() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var to := from + cam.project_ray_normal(mouse) * 1000.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 4)  # LAYER_ENEMY
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		_enemy_info.clear()
		return
	var n: Node = hit.collider
	if n != null and n.has_method("get_body_color"):
		_enemy_info.set_enemy(n)
	else:
		_enemy_info.clear()


## CombatController.enemy_defeated → spawn a PH loot drop at the death position.
func _on_enemy_loot(world_pos: Vector3) -> void:
	var def: Dictionary
	if randf() < GEAR_DROP_CHANCE and not GEAR_LOOT.is_empty():
		def = _make_gear_drop_def(String(GEAR_LOOT[randi() % GEAR_LOOT.size()]))
	else:
		def = (LOOT_TABLE[randi() % LOOT_TABLE.size()] as Dictionary).duplicate()
	var drop := ItemDrop.new()
	drop.setup(_inventory_ui, def)
	drop.position = Vector3(world_pos.x, 0.0, world_pos.z)
	add_child(drop)


## Build an ItemDrop def for an Identity Gear master (gear.json), colored by its role.
func _make_gear_drop_def(base_gear_id: String) -> Dictionary:
	var m: Dictionary = Slice01Data.get_gear_master(base_gear_id)
	var classes: Array = m.get("equip_classes", [])
	var cid := String(classes[0]) if not classes.is_empty() else "Tank"
	return {
		"id": String(m.get("display_name", base_gear_id)),
		"w": 2, "h": 2,
		"color": UnitVisuals.role_color(cid),
		"kind": "gear",
		"base_gear_id": base_gear_id,
	}


## Floating interaction label (name + key) positioned ABOVE the hovered object by
## InteractionController (which sets text/position/visibility each frame).
func _make_interact_prompt() -> Label:
	var l := Label.new()
	l.visible = false
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 17)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.07, 0.80)
	sb.border_color = Color(0.62, 0.64, 0.74, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 9.0
	sb.content_margin_right = 9.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	l.add_theme_stylebox_override("normal", sb)
	return l


## CombatController.party_hit → screen-edge damage glow for the CONTROLLED char only.
## Projects a point toward the attacker to screen space (exact under any camera yaw/
## pitch), so the glow points at the source regardless of orbit. ref: F-011 info-war HUD.
func _on_party_hit(from_dir_world: Vector3, severity: float, is_controlled: bool) -> void:
	if not is_controlled:
		return
	var ctrl: CharacterBody3D = _party.get_controlled()
	var cam := get_viewport().get_camera_3d()
	if ctrl == null or cam == null:
		return
	var toward := from_dir_world
	toward.y = 0.0
	if toward.length() < 0.01:
		return
	var src_world: Vector3 = ctrl.global_position + toward.normalized() * 4.0
	var screen_dir: Vector2 = cam.unproject_position(src_world) - cam.unproject_position(ctrl.global_position)
	_damage_indicator.flash(screen_dir, severity)


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
	_camera_rig.set_follow_target(member)  # glide to the new char (covers auto-swap too)


func _on_cohesion_changed(mode: int) -> void:
	_hud_cohesion.text = (
		"파티비결속" if mode == PartyCohesion.MODE_UNBOUND else "파티결속"
	)


func _on_formation_priority_changed(on: bool) -> void:
	_hud_formation.text = "진형우선" if on else "전투우선"


func _on_engagement_changed(engaged: bool) -> void:
	_hud_state.text = "전투중" if engaged else "휴식중"


func _refresh_hud(state: Dictionary) -> void:
	_hud_phase.text = String(state.get("run_phase", "?"))
	_hud_map.text = String(state.get("map_id", "?"))
	_hud_room.text = String(state.get("current_room_ref", "?"))
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl:
		_hud_controlled.text = "%s (%s)" % [ctrl.identity_skill_id, ctrl.class_id]
	_hud_cohesion.text = "파티결속"
	_hud_formation.text = "진형우선" if _party.is_formation_priority() else "전투우선"
	_hud_state.text = "전투중" if _combat.is_engaged() else "휴식중"
	_hud_hint.text = "WASD · 1-4 swap · Q skill · U cohesion · F 진형우선 · I 인벤 · Esc menu"
