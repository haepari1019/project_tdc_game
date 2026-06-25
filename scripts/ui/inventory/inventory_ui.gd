extends Control
## Inventory coordinator — modal window holding the player's BACKPACK (persistent) and,
## while looting a world container (chest), that container's grid beside it. Cross-
## container drag&drop + rotation (R, 2-state, grab-anchored). Grids own occupancy +
## item visuals; this coordinator owns the active drag and routes drops to whichever
## VISIBLE grid the cursor is over. ref: F-010 Loadout / 백팩 인벤.

const InventoryGrid := preload("res://scripts/ui/inventory/inventory_grid.gd")
const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")
const ItemFactory := preload("res://scripts/ui/inventory/item_factory.gd")
const EquipPanel := preload("res://scripts/ui/inventory/equip_panel.gd")
const ConsumableController := preload("res://scripts/ui/inventory/consumable_controller.gd")

signal consumable_use_requested(consumable_id: String)  # right-click a consumable → use it
signal item_dropped(item: Dictionary)          # Shift+우클릭 백팩 아이템 → 바닥에 드롭(런: 호스트가 ItemDrop 생성)
signal stash_item_discarded(item: Dictionary)  # Shift+우클릭 스태시 아이템 → 소유 영구 제거(허브: 호스트가 Stash 갱신)

const CELL := 48
const GAP := 4
const BAR_H := 30

var _dim: ColorRect
var _window: PanelContainer
var _grids: Array = []           # all grids; drag routes among the VISIBLE ones
var _backpack: InventoryGrid
var _loot: InventoryGrid
var _loot_box: VBoxContainer     # loot column wrapper (shown only while looting)
var _loot_label: Label
var _chest: Node = null          # currently looted chest (null = none)
var _loot_is_stash: bool = false # the loot grid currently shows the persistent Stash (hub), not a chest
# 금고(재료) — 스태시 편집 시 stash 그리드 '아래'에 함께 표시(탭 대신). 읽기 전용 표시(_grids 미등록 →
# 드롭 대상 아님, _on_item_pressed에서 드래그 차단) + '재료 모두 금고로' 버튼이 유일 입금 경로.
var _vault: InventoryGrid = null
var _vault_label: Label = null
var _haul_deposit_btn: Button = null

# Active item drag (across containers).
var _drag: Dictionary = {}
var _from: InventoryGrid = null
var _orig: Dictionary = {}
var _drag_vis: Panel = null
var _grab_off := Vector2.ZERO
var _rotated := false
var _drag_src: Dictionary = {}  # {kind: grid|gear|sub, char, slot} — where the drag began

# Window move (title bar).
var _win_drag := false
var _win_off := Vector2.ZERO

# Party gear equip slots (F-008 §3.2): drop / right-click a gear item to equip it.
var _party: Node = null
var _combat: Node = null
var _content_row: HBoxContainer = null
var _equip: EquipPanel = null    # gear/sub equip slots (extracted, DEBT-INV); drives drag delegates
var _consumables: ConsumableController = null  # consumable stacking + Z/X/C hotkeys (extracted, DEBT-INV)


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 소비 컨트롤러를 _build() 전에 — _build의 _load_backpack_from_autoload가 소비를
	# add_consumable_to_backpack(→ _consumables)로 채운다. null이면 소비만 증발(키 OK).
	_consumables = ConsumableController.new()
	add_child(_consumables)
	_consumables.setup(self)
	_build()
	get_viewport().size_changed.connect(_relayout)
	_window.resized.connect(_center_window)
	_relayout()


# --- open / close modes --------------------------------------------------------

func toggle() -> void:  # `i` — player backpack only
	if visible:
		_close()
	else:
		_loot_box.visible = false
		_open()


## Open the loot view: player backpack + the chest's container (populated from its items).
func open_loot(chest: Node) -> void:
	_chest = chest
	_loot_is_stash = chest != null and chest.has_method("is_stash_source")
	_loot_label.text = chest.title if "title" in chest else "CONTAINER"
	_loot.clear()
	var c: int = int(chest.cols) if "cols" in chest else 5   # container sets its own size
	var r: int = int(chest.rows) if "rows" in chest else 5   # (stash >> backpack; chest defaults 5x5)
	_loot.resize(c, r)
	for it in chest.items:
		_loot.place((it as Dictionary).duplicate(), int(it.col), int(it.row))
	_loot_box.visible = true
	# 금고(재료) 섹션 — 스태시 편집일 때만 stash 아래에 함께 표시. 월드 상자엔 숨김.
	_vault_label.visible = _loot_is_stash
	_vault.visible = _loot_is_stash
	_haul_deposit_btn.visible = _loot_is_stash
	if _loot_is_stash:
		_populate_vault()
	else:
		_vault.clear()
	_open()


func is_open() -> bool:
	return visible


## Add an item to the player backpack (from a world pickup). False if there is no room.
func add_to_backpack(id: String, w: int, h: int, color: Color) -> bool:
	return _backpack.add_item(id, w, h, color)


## How many backpack items have this id (drives quest counts, e.g. Cell n/6).
func count_item(id: String) -> int:
	var n := 0
	for it in _backpack.items:
		if String(it.id) == id:
			n += 1
	return n


## Does the player's backpack currently hold a key?
func backpack_has_key() -> bool:
	for it in _backpack.items:
		if String(it.id).to_lower().contains("key"):
			return true
	return false


## Consume ONE key from the backpack — 키는 소모품, 문 열면 사라진다 (사용자 요청). True if removed.
func consume_key() -> bool:
	for it in _backpack.items:
		if String(it.get("id", "")).to_lower().contains("key"):
			_backpack.lift(it)   # 시각/점유 제거 후 즉시 반환(변경된 배열 추가 순회 안 함)
			return true
	return false


func _open() -> void:
	visible = true
	_win_drag = false
	if _equip != null:  # reflect current equip/charge state + the now-controlled char's subs
		_equip.refresh()
	if _consumables != null:
		_consumables.set_interactive(true)  # bar slots become draggable while inventory open
	_relayout()
	call_deferred("_relayout")  # re-fit once the HBox re-sorts after toggling the loot column


func _close() -> void:
	if _chest != null:                          # persist what's left in the chest
		_chest.items = _loot.export_items()
		_loot.clear()
		_loot_box.visible = false
		_chest = null
	if _consumables != null:
		_consumables.set_interactive(false)
	visible = false
	_win_drag = false


# --- party gear equip slots (F-008 §3.2 / DEC-20260611-001) ---------------------

## Wire the party so the inventory can show per-character equip slots and swap gear.
## combat is the CombatController (gate: no swap while engaged — F-008 §4.2).
func setup_party(party: Node, combat: Node) -> void:
	_party = party
	_combat = combat
	if _equip == null:
		_equip = EquipPanel.new()
		add_child(_equip)
	_equip.setup(self, party, combat)
	_equip.build(_content_row)
	_equip.refresh()
	if _consumables != null:
		_consumables.bind_party(party, combat)


# --- equip panel callbacks (the EquipPanel drives the shared drag state through these) ---

## True while an item is being dragged (gates slot drag-out). ref: DEBT-INV.
func is_dragging() -> bool:
	return not _drag.is_empty()


## The player backpack grid (EquipPanel returns displaced gear/skillbooks here).
func backpack_grid() -> InventoryGrid:
	return _backpack


## Transient feedback line (owned by the EquipPanel's gear column). Consumable code uses it too.
func _msg(text: String) -> void:
	if _equip != null:
		_equip.msg(text)


# --- consumables: thin wrappers → ConsumableController (external API preserved; F-010) ---

func setup_consumable_bar(bar: Node) -> void:
	if _consumables != null:
		_consumables.setup_bar(bar)


func add_consumable_to_backpack(consumable_id: String, amount: int) -> int:
	return _consumables.add_to_backpack(consumable_id, amount) if _consumables != null else 0


func consumable_count(consumable_id: String) -> int:
	return _consumables.count(consumable_id) if _consumables != null else 0


func consume_consumable(consumable_id: String) -> bool:
	return _consumables.consume(consumable_id) if _consumables != null else false


func use_consumable(slot: int) -> String:
	return _consumables.use(slot) if _consumables != null else ""


func get_hotkey(slot: int) -> String:
	return _consumables.get_hotkey(slot) if _consumables != null else ""


## Add a looted Identity Gear instance to the backpack as an At-Risk run-inventory
## item (F-008 §3.3). Returns false if the backpack is full.
## inst = 선택적 인스턴스 디스크립터 {rolled_identity_skill_id?, rolls?} — 굴린 정체성/옵션 보존(F-008 §3.7).
func add_gear_to_backpack(base_gear_id: String, at_risk: bool, inst: Dictionary = {}) -> bool:
	var m: Dictionary = Slice01Data.get_gear_master(base_gear_id)
	if m.is_empty():
		return false
	var rid := String(inst.get("rolled_identity_skill_id", ""))
	if rid != "":
		m["rolled_identity_skill_id"] = rid     # gear_item이 캐리
	if inst.has("rolls"):
		m["rolls"] = inst["rolls"]
	return _backpack.add_item_dict(ItemFactory.gear_item(m, at_risk))




## Add a looted skillbook to the backpack as an At-Risk run-inventory item. Skillbooks
## stay At-Risk even when equipped (F-009 §3.7). Returns false if the backpack is full.
## inst = 선택적 인스턴스 디스크립터 {affix?, charges?} — affix·잔여탄 보존(D-018 §7.3).
func add_skillbook_to_backpack(base_ability_id: String, at_risk: bool, inst: Dictionary = {}) -> bool:
	var m: Dictionary = Slice01Data.get_skillbook_master(base_ability_id)
	if m.is_empty():
		return false
	var item := ItemFactory.skillbook_item(m, at_risk)
	var affix: Dictionary = inst.get("affix", {})
	if not affix.is_empty():
		item["affix"] = affix
		item["charges_max"] = int(item.get("charges_max", 0)) + int(affix.get("charges", 0))   # §7.6 탄 보너스
		item["charges"] = int(item["charges_max"])
	if inst.has("charges"):
		item["charges"] = int(inst["charges"])    # 저장된 잔여 탄
	return _backpack.add_item_dict(item)


## Add a looted haul material to the backpack as At-Risk run inventory (D-029 §4). On Extraction
## Success it transfers to hubHaulVault (Safe); on failure it is lost. Returns false if full.
## 재료는 스택 — 같은 haul_material_id 기존 타일을 채운 뒤(≤max_stack) 새 타일 생성(소비품과 동형).
func add_haul_to_backpack(haul_material_id: String, at_risk: bool, count: int = 1) -> bool:
	var m: Dictionary = Slice01Data.get_haul_material(haul_material_id)
	var display := String(m.get("display", haul_material_id))
	var max_stack := ItemFactory.HAUL_MAX_STACK
	var remaining := count
	for it in _backpack.items:
		if remaining <= 0:
			break
		if String(it.get("kind", "")) == "haul" and String(it.get("haul_material_id", "")) == haul_material_id:
			var room := max_stack - int(it.get("count", 1))
			if room > 0:
				var add := mini(room, remaining)
				it["count"] = int(it.get("count", 1)) + add
				remaining -= add
				_backpack.refresh_item_label(it)
	while remaining > 0:
		var n := mini(max_stack, remaining)
		if not _backpack.add_item_dict(ItemFactory.haul_item(haul_material_id, display, at_risk, n)):
			break
		remaining -= n
	return remaining < count   # true if any added (스택 채움 포함)


## Haul materials currently in the run inventory → {haulMaterialId: count}. Consumed by the run-end
## controller on Extraction Success → HubProfile.add_haul (F-029 §3.2).
func collect_haul() -> Dictionary:
	var out: Dictionary = {}
	for it in _backpack.items:
		if String(it.get("kind", "")) == "haul":
			var hid := String(it.get("haul_material_id", ""))
			if not hid.is_empty():
				out[hid] = int(out.get(hid, 0)) + int(it.get("count", 1))
	return out




# --- run settlement (F-007 §3.6/§3.7 — backpack = At-Risk run inventory) ---------

## The whole backpack is At-Risk run inventory. Returns a settlement list
## [{label, count}] for the Loss Bundle (on failure) / Safe set (on extraction).
func collect_run_inventory() -> Array:
	var out: Array = []
	for it in _backpack.items:
		var kind := String(it.get("kind", ""))
		out.append({
			"label": String(it.get("id", "?")),
			"count": int(it.get("count", 1)) if kind == "consumable" else 1,
			"kind": kind,
		})
	return out


## Raw backpack item dicts (for the deployment hub to serialize the brought loadout).
func get_backpack_items() -> Array:
	var out: Array = []
	for it in _backpack.items:
		out.append((it as Dictionary).duplicate())
	return out


## F-007 §3.6 — Extraction Success: every At-Risk run-inventory stack becomes Safe.
func mark_run_inventory_safe() -> void:
	for it in _backpack.items:
		if it.has("at_risk"):
			it["at_risk"] = false


## B-model — rebuild the loose backpack grid from the persistent Backpack autoload (gear/skillbook/
## generic; consumables excluded in I2b). Called at grid build (hub + run share this path).
func _load_backpack_from_autoload() -> void:
	var bp := get_node_or_null("/root/Backpack")
	if bp == null:
		return
	for d in bp.get_loose():
		match String(d.get("kind", "generic")):
			"gear":
				add_gear_to_backpack(String(d.get("base_gear_id", "")), bool(d.get("at_risk", true)), d)   # rolled 보존(G2)
			"skillbook":
				add_skillbook_to_backpack(String(d.get("base_ability_id", "")), bool(d.get("at_risk", true)), d)   # affix·탄 보존
			"haul":
				add_haul_to_backpack(String(d.get("haul_material_id", "")), bool(d.get("at_risk", true)), int(d.get("count", 1)))
			"consumable":
				add_consumable_to_backpack(String(d.get("consumable_id", "")), int(d.get("count", 1)))
			_:
				add_to_backpack(String(d.get("id", "?")), int(d.get("w", 1)), int(d.get("h", 1)), Color(0.5, 0.5, 0.55))


## B-model — commit the loose backpack grid back to the persistent Backpack autoload (extract = keep,
## hub deploy = persist edits). Consumables INCLUDED — the whole loose carry persists (I3; RunLoadout
## no longer carries inventory).
func commit_loose_to_backpack() -> void:
	var bp := get_node_or_null("/root/Backpack")
	if bp == null:
		return
	bp.set_loose(_backpack.items)   # 소비 포함 — 전체 낱개 캐리가 영속(B I3)


# --- stash item builders (deployment hub) — public wrappers so the hub can fill a stash grid
# with the exact item dicts the equip/sub/backpack drag system expects (F-010). ---
## inst = stash 인스턴스 {base_gear_id, rolled_identity_skill_id?, rolls?} (레거시=문자열). 굴린 정체성/옵션을
## master(deep copy)에 병합 → gear_item이 캐리(F-008 §3.7 스페어 roll 보존).
func make_gear_stash_item(inst) -> Dictionary:
	var base := String(inst.get("base_gear_id", "")) if typeof(inst) == TYPE_DICTIONARY else String(inst)
	var m := Slice01Data.get_gear_master(base)
	if m.is_empty():
		return {}
	if typeof(inst) == TYPE_DICTIONARY:
		var rid := String((inst as Dictionary).get("rolled_identity_skill_id", ""))
		if not rid.is_empty():
			m["rolled_identity_skill_id"] = rid
		if (inst as Dictionary).has("rolls"):
			m["rolls"] = (inst as Dictionary)["rolls"]
	return ItemFactory.gear_item(m, true)


## inst = stash 스킬북 인스턴스 {base_ability_id, affix?, charges?} (레거시=문자열). affix·잔여탄 캐리(D-018 §7.3).
func make_skillbook_stash_item(inst) -> Dictionary:
	var base := String(inst.get("base_ability_id", "")) if typeof(inst) == TYPE_DICTIONARY else String(inst)
	var m := Slice01Data.get_skillbook_master(base)
	if m.is_empty():
		return {}
	var it := ItemFactory.skillbook_item(m, true)
	if typeof(inst) == TYPE_DICTIONARY:
		var affix: Dictionary = (inst as Dictionary).get("affix", {})
		if not affix.is_empty():
			it["affix"] = affix
			it["charges_max"] = int(it.get("charges_max", 0)) + int(affix.get("charges", 0))
			it["charges"] = int(it["charges_max"])
		if (inst as Dictionary).has("charges"):
			it["charges"] = int((inst as Dictionary)["charges"])
	return it


func make_consumable_stash_item(consumable_id: String, count: int) -> Dictionary:
	var m := Slice01Data.get_consumable_master(consumable_id)
	return ItemFactory.consumable_item(m, count) if not m.is_empty() else {}


func make_haul_stash_item(haul_material_id: String, count: int) -> Dictionary:
	var m := Slice01Data.get_haul_material(haul_material_id)
	if m.is_empty():
		return {}
	var it := ItemFactory.haul_item(haul_material_id, String(m.get("display", haul_material_id)), false)
	it["count"] = count       # stash haul stacks (count badge like consumables)
	it["max_stack"] = 99
	return it


## 금고(재료) 표시 갱신 — HubProfile.hub_haul_vault → _vault 그리드(읽기 전용).
func _populate_vault() -> void:
	if _vault == null:
		return
	_vault.clear()
	var hub := get_node_or_null("/root/HubProfile")
	if hub == null:
		return
	var vault: Dictionary = hub.hub_haul_vault if "hub_haul_vault" in hub else {}
	var i := 0
	for hid in vault:
		var it := make_haul_stash_item(String(hid), int(vault[hid]))
		if it.is_empty():
			continue
		@warning_ignore("integer_division")
		_vault.place(it, i % int(_vault.cols), i / int(_vault.cols))
		i += 1


## '재료 모두 금고로' — 백팩의 모든 haul → HubProfile 금고로 일괄 입금. 백팩 그리드에서 제거 + 금고 표시
## 갱신 + 퀘스트 재평가 + 백팩 영속. 런 끝난 뒤 한 번 누르면 재료가 전부 금고로 (사용자 요청).
func _deposit_all_haul() -> void:
	var hub := get_node_or_null("/root/HubProfile")
	if hub == null or _backpack == null:
		return
	var moved := 0
	for it in _backpack.items.duplicate():
		if String(it.get("kind", "")) == "haul" and String(it.get("haul_material_id", "")) != "":
			hub.add_haul(String(it.get("haul_material_id", "")), int(it.get("count", 1)))
			moved += int(it.get("count", 1))
			_backpack.lift(it)
	if moved > 0:
		if hub.has_method("evaluate_quests"):
			hub.evaluate_quests()
		_populate_vault()
		commit_loose_to_backpack()   # 백팩에서 haul 제거 → 즉시 영속(Backpack.loose)
	_msg("재료 %d개 금고로 옮김" % moved if moved > 0 else "백팩에 옮길 재료 없음")






func start_drag_from_slot(item: Dictionary, src: Dictionary) -> void:
	_drag = item
	_from = null
	_drag_src = src
	_rotated = false
	_orig = {"w": int(item.w), "h": int(item.h), "col": 0, "row": 0}
	_grab_off = Vector2(int(item.w) * CELL * 0.5, int(item.h) * CELL * 0.5)
	_drag_vis = _make_drag_vis(item)
	add_child(_drag_vis)
	_update_drag()


## Restore the drag to where it began (grid spot / gear slot / sub slot).
func _revert_drag() -> void:
	match String(_drag_src.get("kind", "grid")):
		"gear":
			_equip.revert_gear(int(_drag_src.char), String(_drag.get("base_gear_id", "")))
		"sub":
			_equip.revert_sub(int(_drag_src.char), int(_drag_src.slot), _drag)
		_:
			if _from != null:
				_drag.w = _orig.w
				_drag.h = _orig.h
				_from.place(_drag, int(_orig.col), int(_orig.row))


# --- layout --------------------------------------------------------------------

func _relayout() -> void:
	var vp := get_viewport_rect().size
	size = vp
	position = Vector2.ZERO
	if _dim:
		_dim.size = vp
	if _window:
		_window.reset_size()  # shrink/grow the window to the currently-visible columns
	_center_window()


func _center_window() -> void:
	if _window:
		_window.position = ((get_viewport_rect().size - _window.size) * 0.5).round()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.5)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_window = PanelContainer.new()
	var win_sb := StyleBoxFlat.new()
	win_sb.bg_color = Color(0.08, 0.09, 0.11, 0.98)
	win_sb.border_color = Color(0.35, 0.38, 0.45)
	win_sb.set_border_width_all(2)
	win_sb.set_corner_radius_all(6)
	_window.add_theme_stylebox_override("panel", win_sb)
	add_child(_window)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	_window.add_child(vb)

	# Title bar = drag handle.
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(0, BAR_H)
	var bar_sb := StyleBoxFlat.new()
	bar_sb.bg_color = Color(0.16, 0.17, 0.21)
	bar_sb.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("panel", bar_sb)
	bar.gui_input.connect(_on_bar_input)
	var title := Label.new()
	title.text = "  INVENTORY     (제목바=창이동 · 드래그=이동/컨테이너간 · R=회전 · I/Esc=닫기)"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 12)
	bar.add_child(title)
	vb.add_child(bar)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 14)
	pad.add_theme_constant_override("margin_right", 14)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 14)
	vb.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	pad.add_child(row)
	_content_row = row

	# Player backpack — the persistent carried inventory (Backpack autoload). Loose gear/skillbook/
	# consumable/generic items all load from there (persist run→run, the B-model SoT — I3). ref: meta-save B refactor.
	var bp_box := _make_container(row, "BACKPACK", 5, 8)
	_backpack = bp_box[1]
	_load_backpack_from_autoload()   # 기어/스킬북/소비/generic 전부 Backpack.loose에서 (시드 포함)

	# Loot container (shown only while looting a chest).
	var lt_box := _make_container(row, "CONTAINER", 5, 5)
	_loot_box = lt_box[0]
	_loot_label = lt_box[2]
	_loot = lt_box[1]
	_loot_box.visible = false

	# 금고(재료) — stash 그리드 '아래'에 위아래로 함께(탭 X). 읽기 전용 표시 + 일괄 입금 버튼.
	# (스태시 편집(is_stash_source)일 때만 보임. 월드 상자 looting 시엔 숨김.)
	_vault_label = Label.new()
	_vault_label.text = "금고 (재료 — 시설 승급용)"
	_vault_label.add_theme_font_size_override("font_size", 14)
	_loot_box.add_child(_vault_label)
	_vault = InventoryGrid.new()
	_vault.setup(self, 8, 3, CELL, GAP)   # 8×3 표시용 — _grids에 넣지 않음(드롭 대상/드래그 비활성)
	_loot_box.add_child(_vault)
	_haul_deposit_btn = Button.new()
	_haul_deposit_btn.text = "재료 모두 금고로 옮기기"
	_haul_deposit_btn.pressed.connect(_deposit_all_haul)
	_loot_box.add_child(_haul_deposit_btn)


## Returns [VBox wrapper, InventoryGrid, Label].
func _make_container(parent: Node, title_text: String, cols: int, rows: int) -> Array:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	parent.add_child(col)
	var lbl := Label.new()
	lbl.text = title_text
	lbl.add_theme_font_size_override("font_size", 14)
	col.add_child(lbl)
	var grid := InventoryGrid.new()
	grid.setup(self, cols, rows, CELL, GAP)
	col.add_child(grid)
	_grids.append(grid)
	return [col, grid, lbl]


# --- item drag (begin routed from grids' item visuals) -------------------------

func _on_item_pressed(event: InputEvent, grid: InventoryGrid, item: Dictionary) -> void:
	if not (event is InputEventMouseButton):
		return
	if grid == _vault:
		return  # 금고(재료)는 읽기 전용 표시 — 드래그/우클릭 비활성(입금은 '재료 모두 금고로' 버튼)
	var mb := event as InputEventMouseButton
	if not mb.pressed or not _drag.is_empty():
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		# Ctrl+drag a stackable consumable → split off half into a new floating stack.
		if mb.ctrl_pressed and String(item.get("kind", "")) == "consumable" and int(item.get("count", 1)) > 1:
			_open_split_popup(grid, item)   # Ctrl+click → ask how many to split off
		else:
			_begin_drag(grid, item)
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if mb.shift_pressed:
			_request_discard(grid, item)  # Shift+우클릭 = 버리기(확인창) — 백팩→드롭 / 스태시→소유 제거
			accept_event()
			return
		if grid == _loot:
			_stow_to_backpack(grid, item)  # chest → backpack: auto-stow to free space
		elif String(item.get("kind", "")) == "gear":
			_equip.equip_gear_to_matching(grid, item)  # right-click → auto-equip to matching class
		elif String(item.get("kind", "")) == "skillbook":
			_equip.equip_sub_to_first(grid, item)  # right-click → first matching sub slot
		elif String(item.get("kind", "")) == "consumable":
			consumable_use_requested.emit(String(item.get("consumable_id", "")))  # → use (revive targeting)
		accept_event()


## 버리기 요청 — 확인창을 띄우고, 확인 시에만 _do_discard. 버릴 수 있는 건 백팩(런)·스태시(허브)뿐
## (월드 상자 아이템은 stow만). Shift+우클릭과 인벤 밖 드래그가 공통으로 여기로 들어온다.
func _request_discard(grid: InventoryGrid, item: Dictionary) -> void:
	if grid == null or item.is_empty():
		return
	if not (grid == _backpack or (grid == _loot and _loot_is_stash)):
		return
	var to_world: bool = grid == _backpack
	var dlg := ConfirmationDialog.new()
	dlg.title = "버리기"
	dlg.dialog_text = "'%s' 을(를) 버릴까요?\n%s" % [
		String(item.get("id", "아이템")),
		"바닥에 떨어집니다 (재획득 가능)" if to_world else "스태시에서 영구 제거됩니다",
	]
	dlg.ok_button_text = "버리기"
	dlg.cancel_button_text = "취소"
	add_child(dlg)
	dlg.confirmed.connect(func() -> void: _do_discard(grid, item))
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.close_requested.connect(dlg.queue_free)
	dlg.popup_centered()


## Execute the discard (after confirm). 백팩 → 바닥에 드롭(재획득 가능, 호스트가 ItemDrop 생성).
## 스태시(허브 소유) → 영구 제거(호스트가 Stash 갱신).
func _do_discard(grid: InventoryGrid, item: Dictionary) -> void:
	if grid == _backpack:
		var def := _drop_def(item)
		grid.lift(item)
		item_dropped.emit(def)
	elif grid == _loot and _loot_is_stash:
		var def := _drop_def(item)
		grid.lift(item)
		stash_item_discarded.emit(def)


## A clean item def for a world drop / discard signal — keeps the pickup-routing fields, drops
## grid-internal state (col/row/node) that must not leak into a new world ItemDrop.
func _drop_def(item: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in ["id", "w", "h", "color", "kind", "base_gear_id", "base_ability_id",
			"haul_material_id", "consumable_id", "count", "charges", "charges_max"]:
		if item.has(k):
			out[k] = item[k]
	return out


## Right-click in a loot container → move the item to the backpack's first free spot.
func _stow_to_backpack(grid: InventoryGrid, item: Dictionary) -> void:
	if grid == _backpack:
		return
	grid.lift(item)
	if not _backpack.add_item_dict(item):
		grid.place(item, int(item.col), int(item.row))  # no room — leave it in the chest


func _begin_drag(grid: InventoryGrid, item: Dictionary) -> void:
	_drag = item
	_from = grid
	_drag_src = {"kind": "grid"}
	_rotated = false
	_orig = {"w": item.w, "h": item.h, "col": item.col, "row": item.row}
	var node: Control = item.node
	_grab_off = get_viewport().get_mouse_position() - node.global_position
	grid.lift(item)
	_drag_vis = _make_drag_vis(item)
	add_child(_drag_vis)
	_update_drag()


## Ctrl+click a consumable stack → popup asking how many to split off into a NEW stack (placed
## in the first free cell). Drag a stack onto a same-id stack to merge them back. ref: F-010.
func _open_split_popup(grid: InventoryGrid, item: Dictionary) -> void:
	var total := int(item.count)
	if total <= 1:
		return
	var pop := PopupPanel.new()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pop.add_child(vb)
	var lbl := Label.new()
	lbl.text = "%s — 분해 수량 (1~%d)" % [String(item.get("id", "")), total - 1]
	vb.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = total - 1
	@warning_ignore("integer_division")  # 절반 분할 기본값 — 아이템 개수라 정수 의도
	spin.value = total / 2
	vb.add_child(spin)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_END
	var cancel := Button.new()
	cancel.text = "취소"
	cancel.pressed.connect(pop.queue_free)
	hb.add_child(cancel)
	var ok := Button.new()
	ok.text = "분해"
	ok.pressed.connect(func() -> void:
		_do_split(grid, item, int(spin.value))
		pop.queue_free()
	)
	hb.add_child(ok)
	vb.add_child(hb)
	add_child(pop)
	pop.popup(Rect2i(get_viewport().get_mouse_position(), Vector2i(230, 116)))


## Split `n` units off `item` into a new stack placed in the grid's first free cell.
func _do_split(grid: InventoryGrid, item: Dictionary, n: int) -> void:
	n = clampi(n, 1, int(item.count) - 1)
	if n <= 0:
		return
	item.count = int(item.count) - n
	grid.refresh_item_label(item)
	var part: Dictionary = item.duplicate()
	part.erase("node")
	part.count = n
	if not grid.add_item_dict(part):
		item.count = int(item.count) + n   # no free cell → undo the split
		grid.refresh_item_label(item)


func _make_drag_vis(item: Dictionary) -> Panel:
	var p := Panel.new()
	p.size = _backpack.item_px(int(item.w), int(item.h))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c: Color = item.color
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(c.r, c.g, c.b, 0.6)
	sb.border_color = c.lightened(0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _grid_under(mouse: Vector2) -> InventoryGrid:
	for g: InventoryGrid in _grids:
		if g.is_visible_in_tree() and g.contains_global(mouse):
			return g
	return null


func _update_drag() -> void:
	if _drag_vis == null:
		return
	var mouse := get_viewport().get_mouse_position()
	_drag_vis.position = mouse - _grab_off
	var topleft := _drag_vis.global_position
	var target := _grid_under(mouse)
	for g: InventoryGrid in _grids:
		if g == target:
			var c := g.cell_from_global_topleft(topleft)
			g.set_preview(c, int(_drag.w), int(_drag.h), g.can_place(int(_drag.w), int(_drag.h), c.x, c.y))
		else:
			g.clear_preview()
	if _equip != null:
		_equip.update_previews(mouse, _drag)


func _rotate_drag() -> void:
	if int(_drag.w) == int(_drag.h):
		return  # square — rotation changes nothing; don't nudge its placement
	# Rectangular items have only 2 orientations, so R is a 2-state toggle (W×H ↔ H×W):
	# rotate about the GRABBED point, alternating CW then CCW so a second R returns to the
	# exact original (no 4-step 360° cycle). The held part stays under the cursor.
	var old_size := _drag_vis.size
	var fx := _grab_off.x / maxf(old_size.x, 1.0)
	var fy := _grab_off.y / maxf(old_size.y, 1.0)
	var w: int = _drag.w
	_drag.w = _drag.h
	_drag.h = w
	var new_size: Vector2 = _backpack.item_px(int(_drag.w), int(_drag.h))
	_drag_vis.size = new_size
	if not _rotated:
		_grab_off = Vector2((1.0 - fy) * new_size.x, fx * new_size.y)         # 90° CW
	else:
		_grab_off = Vector2(fy * new_size.x, (1.0 - fx) * new_size.y)         # 90° CCW (inverse)
	_rotated = not _rotated
	_update_drag()


func _drop() -> void:
	var topleft := _drag_vis.global_position
	var mouse := get_viewport().get_mouse_position()
	var placed := false
	# Identity Gear → drop onto a party equip slot (F-008 §3.2 mid-run swap). On success
	# the item is consumed from the backpack (now equipped); on reject it reverts.
	if String(_drag.get("kind", "")) == "gear":
		var si := _equip.gear_slot_under(mouse)
		if si >= 0:
			if not _equip.try_equip_gear(si, _drag):
				_revert_drag()
			placed = true
	elif String(_drag.get("kind", "")) == "skillbook":
		var ssi := _equip.sub_slot_under(mouse)
		if ssi >= 0:
			if not _equip.try_equip_sub(ssi, _drag):
				_revert_drag()
			placed = true
	elif String(_drag.get("kind", "")) == "consumable":
		var bi := _consumables.bar_slot_under(mouse)
		if bi >= 0:
			_consumables.assign_hotkey(bi, String(_drag.get("consumable_id", "")))
			_revert_drag()  # assigning doesn't consume — return the stack to the backpack
			placed = true
	elif String(_drag.get("kind", "")) == "hotkey":
		var hbi := _consumables.bar_slot_under(mouse)
		var src := int(_drag.get("src_slot", -1))
		if hbi == src:
			pass  # dropped back on its own slot → keep
		elif hbi >= 0:
			_consumables.assign_hotkey(hbi, String(_drag.get("consumable_id", "")))  # move (uniqueness clears src)
		else:
			_consumables.unassign_hotkey(src)  # dropped away → unassign
		placed = true
	if not placed:
		var target := _grid_under(mouse)
		if target != null:
			var c := target.cell_from_global_topleft(topleft)
			# 스태시(창고) 입금 가드 — 기어·스킬북·소비만(deploy 동기화 3종). 재료(haul)는 일반 스태시가
			# 아니라 HubProfile 금고로 일원화 → '재료 모두 금고로' 버튼/금고 탭 사용. 스태시 내부 재배치는 예외.
			var rearrange_in_stash: bool = _from == _loot and String(_drag_src.get("kind", "grid")) == "grid"
			if target == _loot and _loot_is_stash and not rearrange_in_stash \
					and not (String(_drag.get("kind", "")) in ["gear", "skillbook", "consumable"]):
				_msg("창고엔 기어·스킬북·소비만 — 재료(haul)는 금고/버튼으로")
				_revert_drag()
				placed = true   # 원위치 복귀 후 아래 공통 정리로 폴백 — 조기 return을 하면 드래그 상태/비주얼이
				# 남아 다음 클릭에 한 번 더 놓여 '복제'되던 버그. placed=true는 재배치만 건너뜀.
			# consumable merge: dropping onto a same-id stack combines (≤ max_stack).
			if String(_drag.get("kind", "")) == "consumable":
				var dest: Dictionary = target.item_at(int(c.x), int(c.y))
				if not dest.is_empty() and dest != _drag \
						and String(dest.get("consumable_id", "")) == String(_drag.get("consumable_id", "")):
					var room := int(_drag.get("max_stack", 1)) - int(dest.get("count", 0))
					var move := mini(room, int(_drag.get("count", 0)))
					if move > 0:
						dest.count = int(dest.count) + move
						target.refresh_item_label(dest)
						_drag.count = int(_drag.count) - move
						if int(_drag.count) <= 0:
							placed = true  # fully merged into the stack
			if not placed and target.can_place(int(_drag.w), int(_drag.h), c.x, c.y):
				target.place(_drag, c.x, c.y)
				placed = true
		if not placed:  # leftover / no target → revert to source (or merge the split back)
			# 인벤 창 밖으로 드래그 = 버리기(확인창). 일단 원위치로 되돌린 뒤(드래그 정리 안전) 확인 요청 —
			# 확인하면 _do_discard, 취소면 그대로 둠. 창 안의 빈칸 드롭은 그냥 revert.
			var out_of_window: bool = _window != null and not _window.get_global_rect().has_point(mouse)
			var src_grid: InventoryGrid = _from
			var dragged: Dictionary = _drag
			_revert_drag()
			if out_of_window and (src_grid == _backpack or (src_grid == _loot and _loot_is_stash)):
				call_deferred("_request_discard", src_grid, dragged)
	for g: InventoryGrid in _grids:
		g.clear_preview()
	if _equip != null:
		_equip.clear_previews()
	_drag_vis.queue_free()
	_drag_vis = null
	_drag = {}
	_from = null
	_drag_src = {}


func _input(event: InputEvent) -> void:
	# Z/X/C while the inventory is open → assign the hovered consumable to that hotkey.
	if visible and _drag.is_empty():
		var hk := -1
		if event.is_action_pressed("use_consumable_z"): hk = 0
		elif event.is_action_pressed("use_consumable_x"): hk = 1
		elif event.is_action_pressed("use_consumable_c"): hk = 2
		if hk >= 0:
			var it = _consumables.consumable_under(get_viewport().get_mouse_position())
			if it != null:
				var cid := String(it.consumable_id)
				if _consumables.get_hotkey(hk) == cid:
					_consumables.unassign_hotkey(hk)  # hover the item on its own slot's key → toggle off
				else:
					_consumables.assign_hotkey(hk, cid)
			get_viewport().set_input_as_handled()
			return
	if not _drag.is_empty():
		if event is InputEventMouseMotion:
			_update_drag()
		elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (event as InputEventMouseButton).pressed:
			_drop()
		elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_R:
			_rotate_drag()
		return
	if _win_drag:
		if event is InputEventMouseMotion:
			var vp := get_viewport_rect().size
			var maxp := vp - _window.size
			maxp.x = maxf(maxp.x, 0.0)
			maxp.y = maxf(maxp.y, 0.0)
			_window.position = (get_viewport().get_mouse_position() + _win_off).clamp(Vector2.ZERO, maxp)
		elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (event as InputEventMouseButton).pressed:
			_win_drag = false


func _on_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_win_drag = true
			_win_off = _window.position - get_viewport().get_mouse_position()
			accept_event()
