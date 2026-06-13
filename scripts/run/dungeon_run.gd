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
const Trap := preload("res://scripts/run/trap.gd")
const Lever := preload("res://scripts/run/lever.gd")
const Barrel := preload("res://scripts/run/barrel.gd")
const QuestTracker := preload("res://scripts/ui/quest_tracker.gd")
const PipCamera := preload("res://scripts/ui/pip_camera.gd")
const Minimap := preload("res://scripts/ui/minimap.gd")
const EnemyInfo := preload("res://scripts/ui/enemy_info.gd")
const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")
const ConsumableBar := preload("res://scripts/ui/consumable_bar.gd")
const SkillVfx := preload("res://scripts/combat/skill_vfx.gd")

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
## Gear drops are RARE (per-kill, after the skillbook roll) — ~1-2 per run. (tuning)
const GEAR_DROP_CHANCE := 0.08
## Per-kill skillbook drop (F-009 / DEC-20260611-002): only on enemies that USE a lootable
## AB; that enemy's own AB drops. High so those enemies almost always drop a book. (tuning)
const SKILLBOOK_DROP_CHANCE := 0.85

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
var _aim_slot: int = -1  # which skillbook slot the aim will cast
# Revive consumable — hotkey → target a downed ally (corpse / portrait) → channel + revive.
var _reviving: bool = false
var _revive_cid: String = ""
var _revive_prompt: Label
var _alert_banner: Label   # UI-006 central separation/MIA warning overlay
# F-007 §3.8 run settlement panel (built in _ready, shown by _show_settlement)
var _settle_panel: Panel
var _settle_sb: StyleBoxFlat
var _settle_title: Label
var _settle_sub: Label
var _settle_section: Label
var _settle_body: Label
var _settle_foot: Label
var _alert_token: int = 0
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
var _extract_blocked: bool = false       # F-007 §3.6.2 cohesion gate holding the channel at 0
## F-007 §3.6.2 extractionCohesionRule — Contract flag (spec default false). The demo
## enables it so a survivor MIA/separated blocks ExtractionActivate completion.
const COHESION_RULE := true


func _ready() -> void:
	_map.room_entered.connect(_run.on_player_entered_room)
	_run.run_booted.connect(_on_run_booted)
	_run.run_phase_changed.connect(_on_phase_changed)
	_run.room_changed.connect(_on_room_changed)
	_run.run_ended.connect(_on_run_ended)
	_run.run_settled.connect(_show_settlement)
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
	var consumable_bar := ConsumableBar.new()  # Z/X/C consumable hotkeys above the char sheet
	$HUD.add_child(consumable_bar)
	_inventory_ui.setup_consumable_bar(consumable_bar)
	_inventory_ui.consumable_use_requested.connect(_on_consumable_use_requested)
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
	# Corridor trap (RM-ROUTE-01 chokepoint, 6m wide): the controlled member crossing the
	# plate spawns a fatal zone behind them → followers cut off (split). Far lever clears it.
	var trap := Trap.new()
	trap.position = Vector3(27.0, 0.0, 71.0)    # plate north; zone spawns 7m south (z≈64)
	add_child(trap)
	var lever := Lever.new()
	lever.setup(trap)
	lever.position = Vector3(29.2, 0.0, 74.0)   # front side (north of zone), against the east wall
	add_child(lever)
	# Breakable oil barrels (ENT-BARREL) in the combat court — AoE breaks them → oil pool.
	for bpos in [Vector3(7.0, 0.0, 28.0), Vector3(-8.0, 0.0, 34.0), Vector3(10.0, 0.0, 40.0)]:
		var barrel := Barrel.new()
		barrel.position = bpos
		add_child(barrel)
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
	_revive_prompt = Label.new()  # revive targeting prompt / toast (top-center)
	_revive_prompt.visible = false
	_revive_prompt.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_revive_prompt.offset_top = 92
	_revive_prompt.offset_bottom = 120
	_revive_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_revive_prompt.add_theme_font_size_override("font_size", 18)
	_revive_prompt.modulate = Color(0.6, 1.0, 0.7)
	_revive_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(_revive_prompt)
	_alert_banner = Label.new()  # UI-006 central separation/MIA warning (icon + text, auto-hide)
	_alert_banner.visible = false
	_alert_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_alert_banner.offset_top = 50
	_alert_banner.offset_bottom = 84
	_alert_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_banner.add_theme_font_size_override("font_size", 22)
	_alert_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(_alert_banner)
	_build_settlement_panel()
	_party.party_alert.connect(_on_party_alert)
	var pip := PipCamera.new()  # UI-006 §7 PIP camera (bottom-left, MIA/separation target)
	$HUD.add_child(pip)
	_party.pip_targets.connect(pip.set_targets)
	_camera_rig.set_follow_target(_party.get_controlled())  # glide in from rig origin


func _process(delta: float) -> void:
	# F-007 §3.7.1 — 전원 ExtractCasualty → PartyWipe → Run Failure (탈출 불가).
	if not _run.run_over and _is_party_wiped():
		_settle_failure("PartyWipe")
		return
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
		elif _reviving:
			_cancel_revive_targeting()
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
	# Revive targeting: click a downed ally (world corpse or party portrait) to channel; RMB cancels.
	if _reviving and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var rb := event as InputEventMouseButton
		if rb.button_index == MOUSE_BUTTON_LEFT:
			var tgt := _pick_downed_target()
			if tgt != null:
				_begin_revive_channel(tgt)
		elif rb.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_revive_targeting()
		return
	# Aiming a ground-targeted sub: left click = cast, right click = cancel.
	if _aiming and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_combat.cast_skillbook(_aim_member, _aim_slot, _mouse_ground_pos())
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
		_on_sub_key(0)  # Q → skillbook slot 0
	if event.is_action_pressed("use_sub_e"):
		_on_sub_key(1)  # E → skillbook slot 1
	if event.is_action_pressed("use_sub_r"):
		_on_sub_key(2)  # R → skillbook slot 2
	if event.is_action_pressed("use_consumable_z"):
		_on_consumable_key(0)
	if event.is_action_pressed("use_consumable_x"):
		_on_consumable_key(1)
	if event.is_action_pressed("use_consumable_c"):
		_on_consumable_key(2)
	if event.is_action_pressed("toggle_cohesion"):
		_party.toggle_cohesion_mode()
	if event.is_action_pressed("toggle_formation_priority"):
		_party.toggle_formation_priority()
	if event.is_action_pressed("interact"):
		_interaction.interact_nearest()  # F → nearest interactable to the player (mouse-independent)
	for i in 4:
		if event.is_action_pressed("swap_party_%d" % (i + 1)):
			if _aiming:
				_end_aim()
			_party.try_swap_to(i)  # success → controlled_changed → rig glides to new char


func _on_sub_key(slot_index: int) -> void:
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl == null or not ctrl.is_alive() or ctrl.is_stunned():
		return
	var inst = ctrl.get_skillbook(slot_index)
	if inst == null:
		return
	if int(inst.charges) <= 0 or float(inst.cooldown_s) > 0.0:
		return  # depleted or on cooldown — no aim marker, no cast
	# Targeted subs (DPS lunge / Nuker nova) → aim mode: left-click a ground point to cast.
	# Self-centered subs (taunt/sanctuary/skillbook strike/poison/stun) → instant.
	if bool(inst.params.get("targeted", false)):
		_start_aim(ctrl, slot_index, inst)
	else:
		_combat.cast_skillbook(ctrl, slot_index, ctrl.global_position)


# --- consumables: hotkey use + targeted revive channel --------------------------

func _on_consumable_key(slot: int) -> void:
	if _inventory_ui.is_open():
		return  # inventory consumes Z/X/C (hotkey assign) when open
	var cid := _inventory_ui.get_hotkey(slot)
	if cid.is_empty():
		return
	var master: Dictionary = Slice01Data.get_consumable_master(cid)
	if master.is_empty():
		return
	if String(master.get("effect", "")) == "revive_ally":
		_start_revive_targeting(cid, master)
	else:
		_inventory_ui.use_consumable(slot)  # instant consumables


## Right-click a consumable in the inventory → close it and use the consumable (revive
## → targeting; needs the inventory closed so the player can click the world target).
func _on_consumable_use_requested(cid: String) -> void:
	if _inventory_ui.is_open():
		_inventory_ui.toggle()
	var master: Dictionary = Slice01Data.get_consumable_master(cid)
	if master.is_empty():
		return
	if String(master.get("effect", "")) == "revive_ally":
		_start_revive_targeting(cid, master)


func _start_revive_targeting(cid: String, master: Dictionary) -> void:
	if _reviving:
		_cancel_revive_targeting()  # re-press → toggle off
		return
	if not bool(master.get("usable_in_combat", true)) and _combat.is_engaged():
		_revive_toast("전투 중 사용 불가")
		return
	if _inventory_ui.consumable_count(cid) <= 0:
		_revive_toast("보유 없음")
		return
	var has_downed := false
	for m in _party.get_members():
		if not (m as Node).is_alive():
			has_downed = true
			break
	if not has_downed:
		_revive_toast("다운된 아군 없음")
		return
	_reviving = true
	_revive_cid = cid
	_revive_prompt.text = "부활: 죽은 아군(시체/초상화) 클릭 · 우클릭 취소"
	_revive_prompt.visible = true


## The downed party member under the cursor — party-sheet portrait first, then world ray.
func _pick_downed_target() -> Node:
	var mouse := get_viewport().get_mouse_position()
	var pm: Node = _party_sheet.portrait_member_under(mouse)
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


func _begin_revive_channel(member: Node) -> void:
	_reviving = false
	_revive_prompt.visible = false
	SkillVfx.revive_pillar(self, (member as Node3D).global_position, 1.5)
	get_tree().create_timer(1.5).timeout.connect(_finish_revive.bind(member, _revive_cid))


func _finish_revive(member: Node, cid: String) -> void:
	if is_instance_valid(member) and not member.is_alive() and _inventory_ui.consume_consumable(cid):
		member.revive(0.5)


func _cancel_revive_targeting() -> void:
	_reviving = false
	_revive_prompt.visible = false


func _revive_toast(msg: String) -> void:
	_revive_prompt.text = msg
	_revive_prompt.visible = true
	get_tree().create_timer(1.2).timeout.connect(_hide_revive_toast)


func _hide_revive_toast() -> void:
	if not _reviving:
		_revive_prompt.visible = false


## UI-006 — central separation/MIA warning overlay (non-blocking, brief, anti-spam).
func _on_party_alert(text: String, level: int) -> void:
	_alert_banner.text = "⚠ " + text
	_alert_banner.modulate = Color(0.98, 0.85, 0.25) if level == 0 else Color(1.0, 0.45, 0.3)
	_alert_banner.visible = true
	_alert_token += 1
	get_tree().create_timer(2.8).timeout.connect(_hide_alert.bind(_alert_token))


func _hide_alert(tok: int) -> void:
	if tok == _alert_token:
		_alert_banner.visible = false


func _start_aim(member: CharacterBody3D, slot_index: int, inst: Dictionary) -> void:
	_aiming = true
	_aim_member = member
	_aim_slot = slot_index
	var p: Dictionary = inst.params
	var r: float = float(p.get("radius_m", p.get("aoe_radius_m", 3.0)))
	_aim_marker.scale = Vector3(r, 1.0, r)
	var cc: Color = member.get_class_color()
	_aim_mat.albedo_color = Color(cc.r, cc.g, cc.b, 0.35)
	_aim_marker.visible = true


func _end_aim() -> void:
	_aiming = false
	_aim_member = null
	_aim_slot = -1
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
		_extract_blocked = false
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
		# F-007 §3.6.2 extractionCohesionRule — hold the channel at 0 (not complete, not a
		# failure) while a SURVIVING party member is MIA/separated. Run continues.
		if COHESION_RULE and _has_separated_survivor():
			_extract_remaining_s = 0.0
			_extract_count.visible = true
			_extract_count.text = "집합 필요"
			if not _extract_blocked:
				_extract_blocked = true
				_on_party_alert("집합 필요 — 생존 파티원이 이탈/MIA 상태입니다", 1)
			return
		_extract_blocked = false
		_extract_active = false
		_extract_count.visible = false
		_settle_extraction()  # F-007 §3.6 Extraction Success (incl. Partial)
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
func _on_enemy_loot(world_pos: Vector3, ability_refs: Array) -> void:
	var def: Dictionary = _roll_loot_def(ability_refs)
	if def.is_empty():
		return
	var drop := ItemDrop.new()
	drop.setup(_inventory_ui, def)
	drop.position = Vector3(world_pos.x, 0.0, world_pos.z)
	add_child(drop)


## Per-kill loot roll: (1) skillbook — if this enemy USES a lootable AB, roll for that
## AB (F-009/DEC-20260611-002); (2) else gear; (3) else generic item.
func _roll_loot_def(ability_refs: Array) -> Dictionary:
	var lootable: Array = []
	for r in ability_refs:
		if not Slice01Data.get_skillbook_master(String(r)).is_empty():
			lootable.append(String(r))
	if not lootable.is_empty() and randf() < SKILLBOOK_DROP_CHANCE:
		return _make_skillbook_drop_def(String(lootable[randi() % lootable.size()]))
	if randf() < GEAR_DROP_CHANCE and not GEAR_LOOT.is_empty():
		return _make_gear_drop_def(String(GEAR_LOOT[randi() % GEAR_LOOT.size()]))
	return (LOOT_TABLE[randi() % LOOT_TABLE.size()] as Dictionary).duplicate()


## Build an ItemDrop def for a skillbook looted from an enemy's lootable AB.
func _make_skillbook_drop_def(base_ability_id: String) -> Dictionary:
	var m: Dictionary = Slice01Data.get_skillbook_master(base_ability_id)
	var classes: Array = m.get("equip_classes", [])
	var cid := String(classes[0]) if not classes.is_empty() else "DPS"
	return {
		"id": String(m.get("display_name", base_ability_id)),
		"w": 1, "h": 1,
		"color": UnitVisuals.role_color(cid).lightened(0.15),
		"kind": "skillbook",
		"base_ability_id": base_ability_id,
	}


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


## run_ended carries only the result string; run_settled (→ _show_settlement) always
## follows and draws the full settlement panel, so nothing to do here.
func _on_run_ended(_result: String) -> void:
	pass


## F-007 §3.6 — compose + finalize Extraction Success (Partial if any ExtractCasualty).
func _settle_extraction() -> void:
	var survivors: Array = []
	var casualties: Array = []
	for m in _party.get_members():
		if not is_instance_valid(m):
			continue
		if m.has_method("is_alive") and not m.is_alive():
			casualties.append(String(m.class_id))   # ExtractCasualty (§3.0)
		else:
			survivors.append(String(m.class_id))
	var safe_items := _collect_at_risk()             # At-Risk → Safe (전량, §3.6.1)
	_inventory_ui.mark_run_inventory_safe()
	var partial := not casualties.is_empty()
	_run.settle_extraction({
		"result": "Partial Extraction Success" if partial else "Extraction Success",
		"cause": "",
		"survivors": survivors,
		"casualties": casualties,
		"safe_items": safe_items,
		"lost_items": [],
	})


## F-007 §3.7 — compose + finalize Run Failure. Run-inventory At-Risk → Loss Bundle.
func _settle_failure(cause: String) -> void:
	var casualties: Array = []
	for m in _party.get_members():
		if is_instance_valid(m):
			casualties.append(String(m.class_id))
	_run.settle_failure(cause, {
		"result": "Run Failure",
		"cause": cause,
		"survivors": [],
		"casualties": casualties,
		"safe_items": [],
		"lost_items": _collect_at_risk(),
	})


## At-Risk run inventory = backpack (전체) + 장착 스킬북(F-009 §3.7). 장착 Identity Gear
## 모듈은 Safe(허브 메타)라 제외한다.
func _collect_at_risk() -> Array:
	var out: Array = _inventory_ui.collect_run_inventory()
	for m in _party.get_members():
		if not is_instance_valid(m) or not m.has_method("get_skillbook"):
			continue
		for i in 3:
			var sb = m.get_skillbook(i)
			if sb != null:
				out.append({
					"label": "%s (장착)" % String(sb.get("display_name", "Skillbook")),
					"count": 1,
					"kind": "skillbook",
				})
	return out


## F-007 §3.6.2 — any SURVIVING party member MIA or beyond the unbound anchor leash.
func _has_separated_survivor() -> bool:
	for m in _party.get_members():
		if not is_instance_valid(m):
			continue
		if m.has_method("is_alive") and not m.is_alive():
			continue  # casualties don't gate (§3.6.2: 생존 파티원 중)
		if m.has_method("is_mia") and m.is_mia():
			return true
		if m.has_method("is_warn") and m.is_warn():
			return true  # anchorDistance > unbound_anchor_max_m (pre-MIA 경고 구간)
	return false


## F-007 §3.7.1 — every party member is an ExtractCasualty (Dead/RunIncapacitated).
func _is_party_wiped() -> bool:
	var members: Array = _party.get_members()
	if members.is_empty():
		return false
	for m in members:
		if is_instance_valid(m) and (not m.has_method("is_alive") or m.is_alive()):
			return false
	return true


## F-007 §3.8 — centered settlement panel (fixed box, small left-aligned list). Built once.
func _build_settlement_panel() -> void:
	_settle_panel = Panel.new()
	_settle_panel.visible = false
	_settle_panel.anchor_left = 0.5
	_settle_panel.anchor_top = 0.5
	_settle_panel.anchor_right = 0.5
	_settle_panel.anchor_bottom = 0.5
	_settle_panel.offset_left = -260.0
	_settle_panel.offset_right = 260.0
	_settle_panel.offset_top = -220.0
	_settle_panel.offset_bottom = 220.0
	_settle_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_settle_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_settle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settle_sb = StyleBoxFlat.new()
	_settle_sb.bg_color = Color(0.06, 0.07, 0.10, 0.97)
	_settle_sb.set_border_width_all(2)
	_settle_sb.border_color = Color(0.55, 1.0, 0.6)
	_settle_sb.set_corner_radius_all(8)
	_settle_panel.add_theme_stylebox_override("panel", _settle_sb)
	$HUD.add_child(_settle_panel)

	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left", 26)
	mc.add_theme_constant_override("margin_right", 26)
	mc.add_theme_constant_override("margin_top", 20)
	mc.add_theme_constant_override("margin_bottom", 18)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settle_panel.add_child(mc)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_child(vb)

	_settle_title = _settle_label(vb, 30, HORIZONTAL_ALIGNMENT_CENTER, Color(0.55, 1.0, 0.6))
	_settle_sub = _settle_label(vb, 16, HORIZONTAL_ALIGNMENT_CENTER, Color(0.86, 0.89, 0.93))
	vb.add_child(HSeparator.new())
	_settle_section = _settle_label(vb, 15, HORIZONTAL_ALIGNMENT_LEFT, Color(0.78, 0.83, 0.90))

	# scrollable detail box — absorbs any overflow so the list never spills the panel.
	var scrollbox := PanelContainer.new()
	scrollbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scrollbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset := StyleBoxFlat.new()
	inset.bg_color = Color(0.0, 0.0, 0.0, 0.28)
	inset.set_corner_radius_all(4)
	inset.set_content_margin_all(7)
	scrollbox.add_theme_stylebox_override("panel", inset)
	vb.add_child(scrollbox)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scrollbox.add_child(scroll)
	_settle_body = Label.new()
	_settle_body.add_theme_font_size_override("font_size", 14)
	_settle_body.modulate = Color(0.92, 0.94, 0.97)
	_settle_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_settle_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settle_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_settle_body)

	_settle_foot = _settle_label(vb, 13, HORIZONTAL_ALIGNMENT_LEFT, Color(0.62, 0.67, 0.74))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vb.add_child(spacer)
	var hint := _settle_label(vb, 12, HORIZONTAL_ALIGNMENT_CENTER, Color(0.55, 0.60, 0.68))
	hint.text = "(Esc → menu)"


func _settle_label(parent: Node, size: int, align: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = align
	l.modulate = col
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## F-007 §3.8 — fill + show the settlement panel. Success/Partial: At-Risk → Safe list.
## Failure: Loss Bundle (회수 후보). 장착 Identity Gear은 항상 Safe.
func _show_settlement(summary: Dictionary) -> void:
	var failed := String(summary.get("cause", "")) != ""
	var col := Color(1.0, 0.45, 0.3) if failed else Color(0.55, 1.0, 0.6)
	_settle_sb.border_color = col
	_settle_title.modulate = col
	if failed:
		_settle_title.text = "✖ RUN FAILURE"
		_settle_sub.text = "파티 전멸 · %s" % String(summary.get("cause", ""))
		var lost: Array = summary.get("lost_items", [])
		_settle_section.text = "Loss Bundle · 회수 후보 — %s" % _category_summary(lost)
		_settle_body.text = _item_lines(lost)
		_settle_foot.text = "장착 Identity Gear = Safe (보존)"
	else:
		_settle_title.text = "★ EXTRACTION SUCCESS ★"
		var surv: Array = summary.get("survivors", [])
		var cas: Array = summary.get("casualties", [])
		var s := "생존 %d" % surv.size()
		if not cas.is_empty():
			s = "부분 탈출 · " + s + " · 전사 %d (%s)" % [cas.size(), ", ".join(cas)]
		_settle_sub.text = s
		var safe: Array = summary.get("safe_items", [])
		_settle_section.text = "루트 정산 · At-Risk → Safe — %s" % _category_summary(safe)
		_settle_body.text = _item_lines(safe, " → Safe")
		_settle_foot.text = "장착 Identity Gear = Safe"
	_settle_panel.visible = true


## F-007 §3.8 — category roll-up (장비/스킬북/소모품) + total stacks for the summary line.
func _category_summary(items: Array) -> String:
	var g := 0
	var s := 0
	var c := 0
	var o := 0
	for it in items:
		match String(it.get("kind", "")):
			"gear": g += 1
			"skillbook": s += 1
			"consumable": c += 1
			_: o += 1
	var parts: Array = []
	if g > 0:
		parts.append("장비 %d" % g)
	if s > 0:
		parts.append("스킬북 %d" % s)
	if c > 0:
		parts.append("소모품 %d" % c)
	if o > 0:
		parts.append("기타 %d" % o)
	if parts.is_empty():
		return "없음"
	return "%s · 총 %d" % [" · ".join(parts), items.size()]


func _item_lines(items: Array, suffix: String = "") -> String:
	if items.is_empty():
		return "  (없음)"
	var lines: Array = []
	for it in items:
		lines.append("  • %s%s%s" % [String(it.get("label", "?")), _qty(it), suffix])
	return "\n".join(lines)


func _qty(it: Dictionary) -> String:
	var c := int(it.get("count", 1))
	return " ×%d" % c if c > 1 else ""


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
	_hud_hint.text = "WASD 이동 · 1-4 스왑 · RMB·F 상호작용 · I 인벤토리 · Esc 메뉴"
