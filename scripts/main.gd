extends Control
## Deployment hub (UI-005 / F-010) — confirm Identity loadout + edit the run loadout from the
## stash (equip gear/skillbooks onto the 4 members, bring consumables = At-Risk) → deploy to the
## demo dungeon. Reuses InventoryUI (combat=null → equip allowed) as the character-slot UI and
## the player Stash as its container grid. ref: QA-030 §3.1–3.2 / F-010 §3.2.

const DUNGEON_SCENE := "res://scenes/run/dungeon_run.tscn"
const PartyController := preload("res://scripts/party/party_controller.gd")
const InventoryUI := preload("res://scripts/ui/inventory/inventory_ui.gd")
const StashSource := preload("res://scripts/ui/inventory/stash_source.gd")
const FormationEditor := preload("res://scripts/ui/inventory/formation_editor.gd")
const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")
const HubFacilitiesPanel := preload("res://scripts/ui/hub_facilities_panel.gd")  # UI-029 시설 승급

@onready var _status: Label = $Panel/Margin/VBox/Status
@onready var _loadout: VBoxContainer = $Panel/Margin/VBox/LoadoutStub
@onready var _start: Button = $Panel/Margin/VBox/StartButton

var _party: Node
var _inv: InventoryUI
var _stash_src: Node
var _formation: Panel
var _difficulty_opt: OptionButton
# Autoloads via runtime path (not the parse-time global) so a stale editor that hasn't
# re-registered a newly-added autoload still compiles + runs. Loaded fresh on every game run.
@onready var _stash: Node = get_node("/root/Stash")
@onready var _run_loadout: Node = get_node("/root/RunLoadout")


func _ready() -> void:
	if not Slice01Data.is_loaded():
		_status.text = "Slice01 data FAILED — see Output"
		_start.disabled = true
		_loadout.visible = false
		push_error("[TDC] Slice01 data not loaded")
		return
	var pin := GameBootstrap.get_spec_pin_summary()
	_status.text = "%s · %s" % [pin, Slice01Data.get_summary()]
	_loadout.populate_from_data()
	_setup_hub()
	_start.disabled = true
	_loadout.loadout_confirmed.connect(_on_loadout_confirmed)
	_start.pressed.connect(_on_start_pressed)
	print("[TDC] Hub ready — ", pin)


## Embed a (static) party + InventoryUI so the hub reuses the equip/drag system, with the
## player Stash presented as the inventory's container grid.
func _setup_hub() -> void:
	_party = PartyController.new()
	var members_node := Node3D.new()  # PartyController expects a $Members child (tscn node)
	members_node.name = "Members"
	_party.add_child(members_node)
	add_child(_party)
	_party.set_physics_process(false)   # no nav/MIA/formation in the hub — members just hold data
	_party.set_process(false)
	_inv = InventoryUI.new()
	add_child(_inv)
	_inv.setup_party(_party, null)      # combat=null → equip allowed (F-008 §4.2 in-combat gate off)
	_inv.stash_item_discarded.connect(_on_stash_item_discarded)  # Shift+우클릭 스태시 버리기 → 영구 제거
	_stash_src = StashSource.new()
	_stash_src.items = _build_stash_items()
	var edit := Button.new()
	edit.text = "장비·스킬 편집 (스태시 → 캐릭터/백팩)"
	edit.pressed.connect(_open_loadout_editor)
	$Panel/Margin/VBox.add_child(edit)
	$Panel/Margin/VBox.move_child(edit, _loadout.get_index())  # stash editor ABOVE the confirm
	# UI-029 허브 시설 — haul로 시설 승급(F-029). 풀스크린 오버레이로 열림.
	var facilities_panel := HubFacilitiesPanel.new()
	add_child(facilities_panel)
	var facilities_btn := Button.new()
	facilities_btn.text = "허브 시설 (승급)"
	facilities_btn.pressed.connect(facilities_panel.open_panel)
	$Panel/Margin/VBox.add_child(facilities_btn)
	$Panel/Margin/VBox.move_child(facilities_btn, _loadout.get_index())
	_build_formation_editor()
	_build_difficulty_selector()


## Difficulty selector (Normal/Hard) — chosen in the hub BEFORE deploy, written to RunLoadout
## at Deploy and read by run_controller/combat at run start (single source = RunLoadout.get_difficulty).
func _build_difficulty_selector() -> void:
	var dlabel := Label.new()
	dlabel.text = "난이도 (던전 진입 전 선택)"
	$Panel/Margin/VBox.add_child(dlabel)
	$Panel/Margin/VBox.move_child(dlabel, _loadout.get_index())
	_difficulty_opt = OptionButton.new()
	_difficulty_opt.add_item("Normal")
	_difficulty_opt.add_item("Hard")
	_difficulty_opt.selected = 1 if String(_run_loadout.difficulty) == "Hard" else 0
	_difficulty_opt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	$Panel/Margin/VBox.add_child(_difficulty_opt)
	$Panel/Margin/VBox.move_child(_difficulty_opt, _loadout.get_index())


## Top-down draggable formation editor (4 role tokens), placed above the confirm.
func _build_formation_editor() -> void:
	var offsets: Dictionary = {}
	var colors: Dictionary = {}
	for m in _party.get_members():
		if m == null or not is_instance_valid(m):
			continue
		var cid := String(m.class_id)
		var o3: Vector3 = _party.get_slot_offset(cid)
		offsets[cid] = Vector2(o3.x, o3.z)
		colors[cid] = UnitVisuals.role_color(cid)
	var flabel := Label.new()
	flabel.text = "포메이션 (토큰 드래그로 배치 · 중앙 = 리더)"
	$Panel/Margin/VBox.add_child(flabel)
	$Panel/Margin/VBox.move_child(flabel, _loadout.get_index())
	_formation = FormationEditor.new()
	# Lock to its 220×220 min size (else the VBox stretches it wide and the token coordinate
	# space — anchored at SIZE/2 — no longer matches the visible panel).
	_formation.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	$Panel/Margin/VBox.add_child(_formation)
	_formation.setup(offsets, colors)
	$Panel/Margin/VBox.move_child(_formation, _loadout.get_index())


func _open_loadout_editor() -> void:
	if _inv.is_open():
		_inv.toggle()
	else:
		_inv.open_loot(_stash_src)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _inv != null and _inv.is_open():
		_inv.toggle()


## Build the stash container items (gear 2×2, skillbooks 1×1, consumables 1×1) with grid
## placement, from the Stash autoload. Reuses InventoryUI's item builders for the exact format.
func _build_stash_items() -> Array:
	var items: Array = []
	var gear_pos := [[0, 0], [2, 0], [0, 2], [2, 2]]   # 2×2 each, fills cols 0–3 / rows 0–3
	for i in _stash.gear.size():
		var it: Dictionary = _inv.make_gear_stash_item(String(_stash.gear[i]))
		if it.is_empty() or i >= gear_pos.size():
			continue
		it["col"] = gear_pos[i][0]
		it["row"] = gear_pos[i][1]
		items.append(it)
	for i in _stash.skillbooks.size():
		var it: Dictionary = _inv.make_skillbook_stash_item(String(_stash.skillbooks[i]))
		if it.is_empty() or i >= 4:
			continue
		it["col"] = 4
		it["row"] = i
		items.append(it)
	var c := 0
	for cid in _stash.consumables:
		var it: Dictionary = _inv.make_consumable_stash_item(String(cid), int(_stash.consumables[cid]))
		if it.is_empty():
			continue
		it["col"] = c
		it["row"] = 4
		items.append(it)
		c += 1
	return items


## Shift+우클릭 스태시 버리기 → 소유 목록(Stash autoload)에서 영구 제거. 그리드는 InventoryUI가
## 이미 lift함 → Stash만 갱신하면 다음 빌드/재진입에 반영된다.
func _on_stash_item_discarded(item: Dictionary) -> void:
	match String(item.get("kind", "")):
		"gear": _stash.remove_gear(String(item.get("base_gear_id", "")))
		"skillbook": _stash.remove_skillbook(String(item.get("base_ability_id", "")))
		"consumable": _stash.take_consumable(String(item.get("consumable_id", "")), int(item.get("count", 1)))


func _on_loadout_confirmed() -> void:
	_start.disabled = false


func _on_start_pressed() -> void:
	if not _loadout.is_confirmed():
		return
	_serialize_loadout()
	get_tree().change_scene_to_file(DUNGEON_SCENE)


## Persist the edited loadout (hub backpack + each member's equipped subs) into RunLoadout so
## the dungeon scene can re-apply it after it spawns its own party. ref: F-010.
func _serialize_loadout() -> void:
	_inv.commit_loose_to_backpack()   # 허브 백팩 편집 → 영속 Backpack(loose). RunLoadout는 인벤 운반 안 함(B).
	var subs: Array = []
	for m in _party.get_members():
		var row := ["", "", ""]
		if m != null and is_instance_valid(m):
			for j in 3:
				var sb = m.get_skillbook(j)
				if sb != null:
					row[j] = String(sb.get("base_ability_id", ""))
		subs.append(row)
	_run_loadout.member_subs = subs
	var form: Array = []
	if _formation != null:
		var offsets: Dictionary = _formation.get_offsets()
		for cid in offsets:
			var o: Vector2 = offsets[cid]
			form.append({"class_id": String(cid), "offset": [o.x, o.y]})  # o.y holds z (forward)
	_run_loadout.formation = form
	if _difficulty_opt != null:
		_run_loadout.difficulty = _difficulty_opt.get_item_text(_difficulty_opt.selected)
