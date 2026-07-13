extends Node3D
## Slice-01 demo dungeon — party + run (steps 2–3).

const PartyCohesion := preload("res://scripts/party/party_cohesion.gd")
const EnemyVisibility := preload("res://scripts/world/enemy_visibility.gd")
const DamageIndicator := preload("res://scripts/ui/damage_indicator.gd")
const InventoryUI := preload("res://scripts/ui/inventory/inventory_ui.gd")
const Chest := preload("res://scripts/world/objects/chest.gd")
const ItemFactory := preload("res://scripts/ui/inventory/item_factory.gd")
## S6b acquisition path — ally-only / party-support skillbooks that NO dungeon enemy uses, so they
## never drop from kills (F-009). Stocked in an in-run "ally cache" chest. The new B1 ally-only books
## (usable_by_enemy=false) + the pure party-support subs enemies don't carry. ref: ROADMAP P2-S6b.
const ALLY_CACHE_POOL := [
	"AB-075", "AB-062", "AB-054", "AB-034", "AB-070", "AB-044",
	"AB-064", "AB-065", "AB-067", "AB-068", "AB-069", "AB-057", "AB-061", "AB-046", "AB-047", "AB-028",
	# B2 ally-only(usable_by_enemy=false): 적이 안 씀 → 캐시 전용.
	"AB-030", "AB-033", "AB-048", "AB-055", "AB-056", "AB-058", "AB-059", "AB-060", "AB-066", "AB-073", "AB-074",
	# B2 bespoke(ally-only): taunt/pull/slow/relocate/reveal.
	"AB-035", "AB-051", "AB-050", "AB-045", "AB-032",
]
const InteractionController := preload("res://scripts/run/controllers/interaction_controller.gd")

## 절차적 루트 상자 — 배치 가능 방(EXT 추출·ROUTE 좁은 복도 제외). 면적 비례 개수, 희귀는 소수.
const LOOT_CHEST_ROOMS := [
	"RM-ENTRY-01", "RM-ADV-01", "RM-OBJ-01", "RM-ADV-02", "RM-ADV-03", "RM-ADV-04", "RM-ADV-05",
	"RM-MID-01", "RM-BOSS-01", "RM-DEEP-01", "RM-ADV-06", "RM-ADV-07", "RM-ADV-08", "RM-ADV-09",
]
const CHEST_AREA_PER := 520.0    # m²당 상자 ~1개 기대(+ rng 0~1 가산)
const CHEST_MAX_PER_ROOM := 3
const RARE_CHEST_FRAC := 0.18    # 좋은(희귀) 상자 비율 — 덜 배치
const CHEST_WALL_MARGIN := 4.0   # 벽에서 안쪽으로(클램프 경계)
const CHEST_PERIM_MARGIN := 2.5  # 주변부 배치 시 벽에서 안쪽(벽 근처)
const CHEST_OBSTACLE_FRAC := 0.55  # 장애물 보유 방에서 기둥/장애물 옆 배치 비율
const CHEST_OBSTACLE_GAP := 3.2  # 장애물 중심에서 떨어진 거리(옆에 붙음)
const WallXray := preload("res://scripts/run/controllers/wall_xray.gd")
const VisionFog := preload("res://scripts/run/controllers/vision_fog.gd")
const EnemyVisionOverlay := preload("res://scripts/run/controllers/enemy_vision_overlay.gd")
const Door := preload("res://scripts/world/objects/door.gd")
const ItemDrop := preload("res://scripts/world/objects/item_drop.gd")
const Trap := preload("res://scripts/world/hazards/trap.gd")
const Lever := preload("res://scripts/world/objects/lever.gd")
const Barrel := preload("res://scripts/world/objects/barrel.gd")
const QuestTracker := preload("res://scripts/ui/quest_tracker.gd")
const PipCamera := preload("res://scripts/ui/pip_camera.gd")
const Minimap := preload("res://scripts/ui/minimap.gd")
const EnemyInfo := preload("res://scripts/ui/enemy_info.gd")
const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")
const ConsumableBar := preload("res://scripts/ui/consumable_bar.gd")
const SettlementPanel := preload("res://scripts/ui/settlement_panel.gd")
const AimMarker := preload("res://scripts/ui/aim_marker.gd")
const ControlledIndicator := preload("res://scripts/ui/controlled_indicator.gd")
const ReviveController := preload("res://scripts/run/controllers/revive_controller.gd")
const TorchCarryController := preload("res://scripts/run/controllers/torch_carry_controller.gd")
const Torch := preload("res://scripts/world/objects/torch.gd")
const AimController := preload("res://scripts/run/controllers/aim_controller.gd")
const SelectionController := preload("res://scripts/run/controllers/selection_controller.gd")
const LootService := preload("res://scripts/run/loot_service.gd")
const RunEndController := preload("res://scripts/run/run_end_controller.gd")
const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


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
@onready var _extract_count: Label = $HUD/ExtractCount
@onready var _camera_rig: Node3D = $CameraPivot  # camera_rig.gd: follow/glide/orbit/shake
@onready var _party_sheet: Control = $HUD/PartySheet
@onready var _controlled_sheet: Control = $HUD/ControlledSheet

# Modal targeting controllers (aim/revive/torch) + per-kill loot + run-end flow.
var _aim: MeshInstance3D     # AimMarker (shared aim/throw marker)
var _aim_ctrl: Node          # AimController (skillbook ground-target modal)
var _revive: Node3D          # ReviveController (targeted revive)
var _selection: Node3D       # SelectionController (좌클릭 아군 스왑 / 적 인스펙트, 씬 공유)
var _torch: Node             # TorchCarryController (ENT-TORCH carry/throw)
var _loot: Node3D            # LootService (per-kill drops)
var _run_end: Node           # RunEndController (extraction channel + settlement + wipe)
var _alert_banner: Label   # UI-006 central separation/MIA warning overlay
var _alert_token: int = 0


# Directional damage indicator — screen-edge red glow on the controlled char's hits.
var _damage_indicator: DamageIndicator
# Inventory UI (i) — backpack + loot grids, drag&drop / rotation / cross-container.
var _inventory_ui: InventoryUI
# World interaction (E) — chest/door proximity prompts.
var _interaction: InteractionController
var _wall_xray: WallXray
var _vision_fog: VisionFog  # F-011 party-LOS fog texture (step 1: debug-visible, V to toggle)
var _enemy_vision: EnemyVisionOverlay  # enemy sight cones as a unioned ground-tint overlay
var _interact_prompt: Label
# Enemy inspect (LMB click) — top-center portrait/HP panel.
var _enemy_info: EnemyInfo

# Camera orbit: RMB + horizontal drag yaws the camera rig. Follow/glide/shake live
# in camera_rig.gd ($CameraPivot); dungeon_run only forwards input + swap focus here.
var _cam_dragging: bool = false
var _rmb_move_accum: float = 0.0  # RMB click(=interact) vs drag(=camera orbit) discriminator



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
	_combat.setup(_party, _map)
	_party.bind_combat(_combat)
	var enemy_vis := EnemyVisibility.new()
	add_child(enemy_vis)
	enemy_vis.setup(_party)
	_vision_fog = VisionFog.new()  # F-011 step1: 2D party-LOS fog texture (V toggles the debug view)
	add_child(_vision_fog)
	_vision_fog.setup(_party, _map)
	_enemy_vision = EnemyVisionOverlay.new()  # enemy sight cones unioned into one ground tint
	add_child(_enemy_vision)
	_enemy_vision.setup(_map, _party, _vision_fog)  # fog cur-LOS gates cones to visible areas
	_run.start_run("RM-ENTRY-01")
	var spawn: Vector3 = _map.get_spawn_position("RM-ENTRY-01")
	_party.spawn_at(spawn)
	# Pre-spawn all encounters as dormant squads, pushed to each room's far side
	# (away from the party) so the start-adjacent room isn't in range at spawn. Roll the per-run
	# seed first → weighted ENC resolve + spawn scatter vary each run (LDG-SPAWN-DEMO-001 §2).
	RunLoadout.roll_run_seed()
	_combat.prespawn_encounters("RM-ENTRY-01")
	_party_sheet.setup(_party.get_members())
	_controlled_sheet.setup(_party)
	_aim = AimMarker.new()  # shared ground-target marker (skillbook aim + torch throw)
	add_child(_aim)
	var ctrl_ind := ControlledIndicator.new()  # UI-001 foot disc + bob arrow
	add_child(ctrl_ind)
	ctrl_ind.setup(_party)
	_damage_indicator = DamageIndicator.new()
	$HUD.add_child(_damage_indicator)
	_inventory_ui = InventoryUI.new()
	$HUD.add_child(_inventory_ui)
	_inventory_ui.setup_party(_party, _combat)  # party gear equip slots (F-008 §3.2)
	var consumable_bar := ConsumableBar.new()  # Z/X/C consumable hotkeys above the char sheet
	$HUD.add_child(consumable_bar)
	_inventory_ui.setup_consumable_bar(consumable_bar)
	_inventory_ui.consumable_use_requested.connect(_on_consumable_use_requested)
	# B-model: 낱개 인벤(기어/스킬북/소비)은 inventory_ui._ready가 Backpack.loose에서 로드, 장착 기어+서브는
	# Backpack.equipped에서 적용(영속 캐리, 스타터 스폰 위에 덮어씀). RunLoadout는 formation/difficulty만.
	var bp_node: Node = get_node_or_null("/root/Backpack")
	if bp_node != null:
		bp_node.apply_to_party(_party)               # 장착 기어+서브 영속 적용 (런이 실제로 장착 기어 사용)
	var rl: Node = get_node_or_null("/root/RunLoadout")
	if rl != null:
		for f in rl.formation:                       # hub formation editor → slot offsets (F-003)
			var foff: Array = f.get("offset", [0, 0])
			if foff.size() >= 2:
				_party.set_slot_offset(String(f.get("class_id", "")), Vector3(float(foff[0]), 0.0, float(foff[1])))
	_revive = ReviveController.new()  # targeted revive (F-010 / D-020)
	add_child(_revive)
	_revive.setup(_party, _combat, _inventory_ui, _party_sheet, $HUD)
	_torch = TorchCarryController.new()  # ENT-TORCH carry/throw (F-021 §3.1.2)
	add_child(_torch)
	_torch.setup(_party, _aim, consumable_bar, _inventory_ui, $HUD)
	_aim_ctrl = AimController.new()  # skillbook ground-target modal
	add_child(_aim_ctrl)
	_aim_ctrl.setup(_aim, _combat)
	_loot = LootService.new()  # per-kill loot drops (F-009/F-010)
	add_child(_loot)
	_loot.setup(_inventory_ui)
	_combat.enemy_defeated.connect(_loot.on_enemy_defeated)
	_combat.squad_cleared.connect(_loot.on_squad_cleared)  # ENC 클리어 → haul 드롭 (HUB-COR-000)
	_combat.squad_cleared.connect(_on_squad_cleared_quest)  # ENC 클리어 기록 → 허브 퀘스트 (B4)
	_inventory_ui.item_dropped.connect(_on_item_dropped)  # Shift+우클릭 버리기 → 바닥에 드롭
	_run_end = RunEndController.new()  # extraction channel + settlement + party-wipe (F-007)
	add_child(_run_end)
	_run_end.setup(_run, _party, _combat, _inventory_ui, _map, _extract_count)
	_run_end.set_loot_service(_loot)   # 추출 성공 시 run_scrap(At-Risk 킬 재화) 지급
	_run_end.party_alert.connect(_on_party_alert)
	# World loop — chest (holding the extraction key) in the objective room.
	var chest := Chest.new()
	chest.title = "유물함"
	chest.items = [{"id": "Key", "w": 1, "h": 1, "col": 0, "row": 0, "color": Color(0.95, 0.82, 0.22)}]
	chest.setup(_inventory_ui)
	chest.position = _map.get_spawn_position("RM-OBJ-01") + Vector3(3.0, 0.0, 0.0)
	add_child(chest)
	# Ally cache (S6b acquisition) — ally-only / party-support skillbooks can't drop from enemy kills
	# (F-009), so seed an in-run cache the player loots into the backpack (At-Risk like any loot).
	var ally_cache := Chest.new()
	ally_cache.title = "아군 유물함"
	ally_cache.items = _build_ally_cache_items(2)
	ally_cache.setup(_inventory_ui)
	ally_cache.position = _map.get_spawn_position("RM-ADV-01") + Vector3(2.0, 0.0, 2.0)
	add_child(ally_cache)
	# Keyed door blocking the route→extraction opening (RM-ROUTE-01 → RM-EXT-01 @ z=77.25).
	var door := Door.new()
	door.setup(_inventory_ui, _run)
	door.position = Vector3(27.0, 0.0, 77.25)
	add_child(door)
	# F2: the closed door casts a vision shadow (fog + enemy cones); opening frees these occluders.
	var _door_half := Vector2(Door.SIZE.x * 0.5, Door.SIZE.z * 0.5)
	var _door_xz := Vector2(door.position.x, door.position.z)
	door.set_occluders([
		_vision_fog.add_box_occluder(_door_xz, _door_half),
		_enemy_vision.add_box_occluder(_door_xz, _door_half),
	])
	# Corridor trap (RM-ROUTE-01 chokepoint, 6m wide): the controlled member crossing the
	# plate spawns a fatal zone behind them → followers cut off (split). Far lever clears it.
	var trap := Trap.new()
	trap.position = Vector3(27.0, 0.0, 71.0)    # plate north; zone spawns 7m south (z≈64)
	add_child(trap)
	var lever := Lever.new()
	lever.setup(trap)
	lever.position = Vector3(29.2, 0.0, 74.0)   # front side (north of zone), against the east wall
	add_child(lever)
	# These live under dungeon_run (not $Rooms) + spawn AFTER VisionFog.setup, so the initial
	# fog sweep missed them → fog them explicitly (else visible at full brightness in unseen rooms).
	for o in [chest, ally_cache, door, trap, lever]:
		_vision_fog.fog_object(o)
	# Breakable oil barrels (ENT-BARREL) in the combat court — AoE breaks them → oil pool.
	_place_loot_chests()   # 절차적 루트 상자 산포(퀘스트/아군 상자는 위에서 고정)
	for bpos in [Vector3(7.0, 0.0, 28.0), Vector3(-8.0, 0.0, 34.0), Vector3(10.0, 0.0, 40.0)]:
		var barrel := Barrel.new()
		barrel.position = bpos
		add_child(barrel)
		_vision_fog.fog_object(barrel)
	# A few carriable torches (ENT-TORCH) near the oil — the carry/throw + RX-OIL-FIRE gameplay
	# spot. Rooms are lit by fixed lanterns (map), so an enemy can't dark out a room by throwing
	# every light. Wire each torch to combat (ignite_at) + the carry/throw handlers. ref: F-021.
	for tpos in [Vector3(4.0, 0.0, 29.0), Vector3(13.0, 0.0, 38.0), Vector3(-5.0, 0.0, 33.0), Vector3(0.0, 0.0, 43.0)]:
		var torch := Torch.new()
		torch.position = tpos
		add_child(torch)
		_vision_fog.fog_object(torch)
	for t in get_tree().get_nodes_in_group("torch"):
		t.setup(_combat)
		if not t.pickup_requested.is_connected(_torch.on_torch_pickup):
			t.pickup_requested.connect(_torch.on_torch_pickup)
		if not t.dropped.is_connected(_torch.on_torch_dropped):
			t.dropped.connect(_torch.on_torch_dropped)
	# Proximity interaction prompt + controller.
	_interact_prompt = _make_interact_prompt()
	$HUD.add_child(_interact_prompt)
	_interaction = InteractionController.new()
	add_child(_interaction)
	_interaction.setup(_party, _interact_prompt, _inventory_ui)
	_wall_xray = WallXray.new()  # fade walls between camera and the controlled char (see-through)
	add_child(_wall_xray)
	_wall_xray.setup(_party)
	# Walls the xray fades must NOT also be fogged (else see-through looks off) — let xray
	# strip the fog next_pass off its faded walls and restore it on release. ref: F-011.
	_wall_xray.set_fog_material(_vision_fog.get_fog_material())
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
	_selection = SelectionController.new()
	add_child(_selection)
	_selection.setup(_party, _enemy_info, $HUD)
	_alert_banner = Label.new()  # UI-006 central separation/MIA warning (icon + text, auto-hide)
	_alert_banner.visible = false
	_alert_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_alert_banner.offset_top = 50
	_alert_banner.offset_bottom = 84
	_alert_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_banner.add_theme_font_size_override("font_size", 22)
	_alert_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(_alert_banner)
	var settlement := SettlementPanel.new()  # F-007 §3.8 run settlement screen (pure UI)
	$HUD.add_child(settlement)
	_run.run_settled.connect(settlement.show_settlement)
	_party.party_alert.connect(_on_party_alert)
	var pip := PipCamera.new()  # UI-006 §7 PIP camera (bottom-left, MIA/separation target)
	$HUD.add_child(pip)
	_party.pip_targets.connect(pip.set_targets)
	_camera_rig.set_follow_target(_party.get_controlled())  # glide in from rig origin


func _process(_delta: float) -> void:
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl:
		_hud_sub.text = "Ready" if ctrl.sub_cooldown_s <= 0.0 else "%.1fs" % ctrl.sub_cooldown_s


## ENC(분대) 클리어 → 허브 프로필에 기록(런 이벤트 퀘스트 판정용, 예: Q-HUB-020 armory).
func _on_squad_cleared_quest(encounter_id: String, _pos: Vector3) -> void:
	var hub: Node = get_node_or_null("/root/HubProfile")
	if hub != null:
		hub.record_enc_cleared(encounter_id, RunLoadout.get_difficulty())   # Hard면 Q-HUB-020 게이트(무기고)


## Shift+우클릭 버리기 (백팩) → 컨트롤 멤버 발치에 재획득 가능한 ItemDrop 생성.
func _on_item_dropped(def: Dictionary) -> void:
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl != null and _loot != null:
		_loot.drop_item(def, ctrl.global_position)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _inventory_ui.is_open():
			_inventory_ui.toggle()  # Esc closes the inventory first
		elif _torch.is_active():
			_torch.cancel()
		elif _revive.is_active():
			_revive.cancel()
		elif _aim_ctrl.is_active():
			_aim_ctrl.cancel()
		else:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	if event.is_action_pressed("toggle_inventory"):
		if _aim_ctrl.is_active():
			_aim_ctrl.cancel()
		_inventory_ui.toggle()
		return
	# Modal targeting click dispatch (priority: revive, skillbook aim, torch throw).
	if _revive.handle_click(event):
		return
	if _aim_ctrl.handle_click(event):
		return
	if _torch.handle_click(event):
		return
	# 좌클릭/드래그 선택 (씬 공유): 클릭=아군 스왑/적 인스펙트, 드래그=박스 안 좌측 아군 스왑
	if _selection.handle_input(event):
		return
	# Scroll wheel = zoom the camera (WoW-style dolly; keeps the look angle).
	if event is InputEventMouseButton:
		var wheel := event as InputEventMouseButton
		if wheel.pressed and wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_rig.zoom(1)   # in
			return
		if wheel.pressed and wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_rig.zoom(-1)  # out
			return
	# Camera pitch tune (dev): [ / ] tilt the angle; console prints pitch/distance to bake in.
	if event is InputEventKey and event.pressed and not event.echo:
		var kc := (event as InputEventKey).physical_keycode
		if kc == KEY_BRACKETLEFT:
			_camera_rig.adjust_pitch(-3.0)   # tilt toward horizontal
			return
		if kc == KEY_BRACKETRIGHT:
			_camera_rig.adjust_pitch(3.0)    # tilt toward top-down
			return
		if kc == KEY_V:
			_vision_fog.toggle_debug()       # F-011: show/hide the 2D fog texture (debug)
			return
		if kc == KEY_B:
			_vision_fog.toggle_world_fog()   # F-011: A/B toggle the 3D world fog
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
		_camera_rig.orbit_yaw(mm.relative.x)     # horizontal drag → yaw
		_camera_rig.pitch_by_drag(mm.relative.y) # vertical drag → pitch (inverted: down = raise angle)
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
			if _aim_ctrl.is_active():
				_aim_ctrl.cancel()
			_party.try_swap_to(i)  # success → controlled_changed → rig glides to new char


func _on_sub_key(slot_index: int) -> void:
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl == null or not ctrl.is_alive() or ctrl.is_stunned():
		return
	if ctrl.has_method("is_provoked") and ctrl.is_provoked():
		return  # Provoked (AB-099): active skills locked — only forced basic on the caster
	if ctrl.has_method("is_channeling") and ctrl.is_channeling():
		return  # Casting (wind-up, skill_cast): occupied until it resolves. NOTE: AB-054 beam is NOT
		#        this — it's an interruptible channel (a new cast cancels it inside cast_skillbook).
	var inst = ctrl.get_skillbook(slot_index)
	if inst == null:
		return
	if int(inst.charges) <= 0 or float(inst.cooldown_s) > 0.0:
		return  # depleted or on cooldown — no aim marker, no cast
	# Targeted subs (DPS lunge / Nuker nova) → aim mode: left-click a ground point to cast.
	# Self-centered subs (taunt/sanctuary/skillbook strike/poison/stun) → instant.
	if bool(inst.params.get("targeted", false)):
		_aim_ctrl.start_aim(ctrl, slot_index, inst)  # ground-target modal
	else:
		_combat.cast_skillbook(ctrl, slot_index, ctrl.global_position)


# --- consumables: hotkey use + targeted revive channel --------------------------

func _on_consumable_key(slot: int) -> void:
	if _torch.handle_consumable_key(slot, _aim_ctrl.is_active() or _revive.is_active()):
		return  # torch carry-pick assign / throw aim
	if _inventory_ui.is_open():
		return  # inventory consumes Z/X/C (hotkey assign) when open
	var cid := _inventory_ui.get_hotkey(slot)
	if cid.is_empty():
		return
	var master: Dictionary = Slice01Data.get_consumable_master(cid)
	if master.is_empty():
		return
	if String(master.get("effect", "")) == "revive_ally":
		_revive.try_start(cid, master)
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
		_revive.try_start(cid, master)


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


## Pick `count` random ally-cache skillbooks → loot-grid item dicts (At-Risk like any loot, F-009 §3.7).
## S6b acquisition path for ally-only / party-support books that never drop from enemy kills.
func _build_ally_cache_items(count: int) -> Array:
	var pool: Array = ALLY_CACHE_POOL.duplicate()
	pool.shuffle()
	var out: Array = []
	for i in mini(count, pool.size()):
		var master: Dictionary = Slice01Data.get_skillbook_master(String(pool[i]))
		if master.is_empty():
			continue
		var it: Dictionary = ItemFactory.skillbook_item(master, true)   # looted = At-Risk
		it["col"] = out.size()
		it["row"] = 0
		out.append(it)
	return out


## 절차적 루트 상자 산포 — 런 시드로 시드(런마다 위치 변동·재현 가능). 퀘스트(Key)·아군 상자는 고정(별도).
## 방 면적 비례 개수, 희귀(좋은) 상자는 소수(RARE_CHEST_FRAC). 스폰/벽 피해 방 안쪽에 배치 + fog.
func _place_loot_chests() -> void:
	if _loot == null or _map == null:
		return
	var rng := RandomNumberGenerator.new()
	var seed_v := 0
	var rl := get_node_or_null("/root/RunLoadout")
	if rl != null and "run_seed" in rl:
		seed_v = int(rl.run_seed)
	rng.seed = hash("loot_chests:%d" % seed_v)
	var placed := 0
	for room_ref in LOOT_CHEST_ROOMS:
		var center: Vector3 = _map.get_spawn_position(room_ref)
		var size: Vector3 = _map.get_room_size(room_ref) if _map.has_method("get_room_size") else Vector3(16, 0, 16)
		var obstacles: Array = _map.get_obstacle_positions(room_ref) if _map.has_method("get_obstacle_positions") else []
		var n: int = clampi(int(floor(size.x * size.z / CHEST_AREA_PER + rng.randf())), 0, CHEST_MAX_PER_ROOM)
		var hx: float = maxf(1.0, size.x * 0.5 - CHEST_WALL_MARGIN)        # 클램프 경계(벽)
		var hz: float = maxf(1.0, size.z * 0.5 - CHEST_WALL_MARGIN)
		var px: float = maxf(1.0, size.x * 0.5 - CHEST_PERIM_MARGIN)       # 주변부(벽 근처)
		var pz: float = maxf(1.0, size.z * 0.5 - CHEST_PERIM_MARGIN)
		for _i in n:
			var rare := rng.randf() < RARE_CHEST_FRAC
			var c := Chest.new()
			c.tier = "rare" if rare else "common"
			c.title = "봉인된 유물함" if rare else "유물 상자"
			c.items = _loot.build_chest_items(c.tier)
			c.setup(_inventory_ui)
			var pos: Vector3
			if not obstacles.is_empty() and rng.randf() < CHEST_OBSTACLE_FRAC:
				# 장애물/기둥 옆에 붙임
				var o: Vector3 = obstacles[rng.randi() % obstacles.size()]
				var ang := rng.randf() * TAU
				pos = o + Vector3(cos(ang), 0.0, sin(ang)) * CHEST_OBSTACLE_GAP
			else:
				# 주변부(모서리) — 벽/모서리에 붙음(중앙 회피; 모서리 편향으로 개구부도 회피)
				var sx: float = 1.0 if rng.randf() < 0.5 else -1.0
				var sz: float = 1.0 if rng.randf() < 0.5 else -1.0
				pos = center + Vector3(sx * (px - rng.randf_range(0.0, 2.0)), 0.0, sz * (pz - rng.randf_range(0.0, 2.0)))
			pos.x = clampf(pos.x, center.x - hx, center.x + hx)   # 방 안으로 클램프
			pos.z = clampf(pos.z, center.z - hz, center.z + hz)
			c.position = pos
			add_child(c)
			_vision_fog.fog_object(c)
			placed += 1
	print("[LOOT] 절차적 상자 %d개 배치 (seed %d)" % [placed, seed_v])


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


## CombatController.party_hit → screen-edge damage glow: red toward the attacker (controlled), dim amber toward an off-screen ally (C3).
## Projects a point toward the attacker to screen space (exact under any camera yaw/
## pitch), so the glow points at the source regardless of orbit. ref: F-011 info-war HUD.
func _on_party_hit(from_dir_world: Vector3, severity: float, is_controlled: bool, member: Node) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if is_controlled:
		var ctrl: CharacterBody3D = _party.get_controlled()
		if ctrl == null:
			return
		var toward := from_dir_world
		toward.y = 0.0
		if toward.length() < 0.01:
			return
		var src_world: Vector3 = ctrl.global_position + toward.normalized() * 4.0
		var screen_dir: Vector2 = cam.unproject_position(src_world) - cam.unproject_position(ctrl.global_position)
		_damage_indicator.flash(screen_dir, severity)
		return
	# C3: a non-controlled ally is under fire OFF-SCREEN → dim amber glow toward them (awareness,
	# F-003 §3.9). On-screen ally hits show on their own HP bar, so no edge glow is needed there.
	if member == null or not is_instance_valid(member):
		return
	var mp: Vector3 = (member as Node3D).global_position
	var behind: bool = cam.is_position_behind(mp)
	var sp: Vector2 = cam.unproject_position(mp)
	var sz: Vector2 = get_viewport().get_visible_rect().size
	if not behind and sp.x >= 0.0 and sp.x <= sz.x and sp.y >= 0.0 and sp.y <= sz.y:
		return  # ally is on-screen
	var dir: Vector2 = sp - sz * 0.5
	if behind:
		dir = -dir   # behind the camera → unproject mirrors; flip to point the right way
	_damage_indicator.flash(dir, severity * 0.5, Color(1.0, 0.62, 0.1))   # dim amber = ally, not you


## run_ended is just the result string; run_settled → SettlementPanel.show_settlement
## draws the full end screen, so nothing to do here.
func _on_run_ended(_result: String) -> void:
	pass


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
