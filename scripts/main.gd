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
const HubEconomyPanel := preload("res://scripts/ui/hub_economy_panel.gd")        # F-009 분석·상점
const HubQuestPanel := preload("res://scripts/ui/hub_quest_panel.gd")            # F-029 §3.3 퀘스트 로그
const HubTreePanel := preload("res://scripts/ui/hub_tree_panel.gd")              # F-020 §3.10 스킬 트리(성소)
const HubModdingPanel := preload("res://scripts/ui/hub_modding_panel.gd")        # UI-005 §3.2 건 모딩(M4)

@onready var _status: Label = $Panel/Margin/VBox/Status
@onready var _loadout: VBoxContainer = $Panel/Margin/VBox/LoadoutStub
@onready var _start: Button = $Panel/Margin/VBox/StartButton

var _party: Node
var _inv: InventoryUI
var _stash_src: Node
var _formation: Panel
var _difficulty_opt: OptionButton
var _economy_lbl: Label   # 마석 반입/보관 요약(F-009 §3.8) — 배치 화면 상시 노출
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
	var bp_hub := get_node_or_null("/root/Backpack")
	if bp_hub != null:
		bp_hub.apply_to_party(_party)   # 영속 장착 기어+서브 복원 → 허브 멤버 (재진입 시 마지막 장착 유지)
	_inv.stash_item_discarded.connect(_on_stash_item_discarded)  # Shift+우클릭 스태시 버리기 → 영구 제거
	_stash_src = StashSource.new()
	_stash_src.items = _build_stash_items()
	var edit := Button.new()
	edit.text = "스태시 / 금고"   # 스태시(창고)+금고(재료)를 위아래로 함께 편집 — '재료 모두 금고로' 버튼 내장
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
	# F-009 필기소·상점 — 스킬북 분석(해금) + 생본 구매(ward_scrap). 풀스크린 오버레이.
	var economy_panel := HubEconomyPanel.new()
	add_child(economy_panel)
	var economy_btn := Button.new()
	economy_btn.text = "필기소 · 상점 (분석/구매)"
	economy_btn.pressed.connect(economy_panel.open_panel)
	# 상점에서 산 기어/스킬북/소비는 Stash에 바로 들어가므로, 패널을 닫으면 에디터 소스를 재빌드해
	# 동기화한다(안 그러면 deploy 시 _sync_stash_from_source가 옛 스냅샷으로 구매를 덮어써 유실).
	economy_panel.closed.connect(func() -> void: _stash_src.items = _build_stash_items())
	$Panel/Margin/VBox.add_child(economy_btn)
	$Panel/Margin/VBox.move_child(economy_btn, _loadout.get_index())
	# F-020 §3.10 성소 스킬 트리 — 해금/발전/슬롯/**doctrine 구매**. 구 분석 의뢰 UI의 후임.
	# doctrine을 살 수 있는 **유일한 경로**라 이게 없으면 F-030이 코드에만 있고 게임엔 없다.
	var tree_panel := HubTreePanel.new()
	add_child(tree_panel)
	var tree_btn := Button.new()
	tree_btn.text = "성소 · 스킬 트리 (해금/운용)"
	tree_btn.pressed.connect(tree_panel.open_panel)
	$Panel/Margin/VBox.add_child(tree_btn)
	$Panel/Margin/VBox.move_child(tree_btn, _loadout.get_index())
	# UI-005 §3.2 건 모딩 — **사용자가 요청한 핵심 UX**. gear의 Q/E/R에 스킬을 끼우고, 결속 1줄을
	# 그 자리에서 보고, gear를 갈 때 소멸을 확인받는다. 슬롯이 gear 귀속으로 옮겨간 뒤로는 여기가
	# 빌드를 만드는 유일한 자리다(equip_panel의 SUB 컬럼은 표시 전용으로 남는다).
	var modding_panel := HubModdingPanel.new()
	modding_panel.party = _party
	add_child(modding_panel)
	var modding_btn := Button.new()
	modding_btn.text = "대장간 · 건 모딩 (Q/E/R)"
	modding_btn.pressed.connect(modding_panel.open_panel)
	# 모딩은 스태시 gear를 꺼내 신고 벗은 걸 돌려놓는다 → 닫을 때 에디터 소스를 재빌드하지 않으면
	# deploy 시 옛 스냅샷이 교체를 덮어써 건이 유실된다(상점 패널과 같은 함정).
	modding_panel.closed.connect(func() -> void: _stash_src.items = _build_stash_items())
	$Panel/Margin/VBox.add_child(modding_btn)
	$Panel/Margin/VBox.move_child(modding_btn, _loadout.get_index())
	# F-029 §3.3 퀘스트 로그 — 승급 의뢰 전체 + 완료 조건 확인. 풀스크린 오버레이.
	var quest_panel := HubQuestPanel.new()
	add_child(quest_panel)
	var quest_btn := Button.new()
	quest_btn.text = "퀘스트 (의뢰 목록)"
	quest_btn.pressed.connect(quest_panel.open_panel)
	$Panel/Margin/VBox.add_child(quest_btn)
	$Panel/Margin/VBox.move_child(quest_btn, _loadout.get_index())
	# 저장 초기화 (테스트/디버그) — 스태시·백팩·허브 메타를 데모 시드로. 확인 다이얼로그로 보호.
	var reset_btn := Button.new()
	reset_btn.text = "저장 초기화 (시드로)"
	reset_btn.modulate = Color(1.0, 0.6, 0.6)   # 파괴적 동작 — 시각 경고
	reset_btn.pressed.connect(_confirm_reset_save)
	$Panel/Margin/VBox.add_child(reset_btn)
	$Panel/Margin/VBox.move_child(reset_btn, _loadout.get_index())
	_build_economy_line()
	_build_formation_editor()
	_build_difficulty_selector()


## 배치 화면 경제 요약 — **마석은 슬롯 스킬(Q/E/R)의 시전 자원**인데, 스태시를 열기 전엔 보유량이
## 어디에도 안 보여서 "소모가 어떻게 되는지 모르겠다"가 됐다(DRIFT-145). 반입분(백팩)과 보관분(스태시)을
## 나눠 찍는다 — 둘은 다른 주머니고, 던전에 들고 가는 건 **반입분뿐**이다.
func _build_economy_line() -> void:
	_economy_lbl = Label.new()
	_economy_lbl.add_theme_font_size_override("font_size", 12)
	_economy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_economy_lbl.modulate = Color(0.78, 0.68, 1.0)
	$Panel/Margin/VBox.add_child(_economy_lbl)
	$Panel/Margin/VBox.move_child(_economy_lbl, _loadout.get_index())
	_refresh_economy_line()


func _refresh_economy_line() -> void:
	if _economy_lbl == null:
		return
	var carried := 0
	var bp := get_node_or_null("/root/Backpack")
	if bp != null:
		for it in bp.loose:
			if String(it.get("kind", "")) == "manastone":
				carried += int(it.get("count", 0))
	var stored: int = int(_stash.manastone_count()) if _stash.has_method("manastone_count") else 0
	_economy_lbl.text = "◈ 마석 — 반입 %d · 창고 %d   (슬롯 스킬 Q/E/R 시전 시 소모 · 등급별 1/2/3)" % [carried, stored]


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
		_sync_stash_from_source()                 # 닫기 = 에디터 상태를 Stash에 반영(상점과 단일 SoT)
		_refresh_economy_line()                   # 마석을 옮겼을 수 있다
	else:
		_stash_src.items = _build_stash_items()   # 열기 = 최신 Stash(상점 구매 포함) 반영
		_inv.open_loot(_stash_src)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _inv != null and _inv.is_open():
		_inv.toggle()
		_sync_stash_from_source()   # ESC 닫기도 Stash에 반영(open 시 재빌드와 짝)
		_refresh_economy_line()


## Build the stash container items (gear 2×2, skillbooks 1×1, consumables 1×1) with grid
## placement, from the Stash autoload. Reuses InventoryUI's item builders for the exact format.
## 스태시 전체를 10×12 그리드에 배치(기어 2×2 → 스킬북 1×1 → 소비 1×1, 행 흐름). 모든 항목을 표시해야
## deploy 시 _sync_stash_from_source(에디터 = 스태시 최종 상태)가 표시 안 된 항목을 잃지 않는다.
## (구 버그: 기어 4·스킬북 4개만 표시 → deploy 동기화가 나머지를 스태시에서 삭제. 사용자 버그.)
func _build_stash_items() -> Array:
	_stash.ensure_seeded()   # 오토로드 순서로 시드가 밀렸으면 여기서 확정(카탈로그 파생, DRIFT-139)
	var items: Array = []
	var cols: int = int(_stash_src.cols) if _stash_src != null and "cols" in _stash_src else 10
	var gear_per_row: int = maxi(1, cols / 2)   # 기어 2×2 — 위쪽 블록에 고정 배치
	var g := 0
	for i in _stash.gear.size():
		var it: Dictionary = _inv.make_gear_stash_item(_stash.gear[i])   # 인스턴스 dict(rolled/rolls 포함)
		if it.is_empty():
			continue
		it["col"] = (g % gear_per_row) * 2
		it["row"] = floori(float(g) / float(gear_per_row)) * 2
		items.append(it)
		g += 1
	# 스킬북·소비는 **좌표를 주지 않는다** — open_loot의 자동 배치(first-fit)에 맡겨 기어 블록이
	# 남긴 빈칸까지 채운다. 예전엔 여기서 행을 직접 계산했는데, 카탈로그가 커지자(서브 49종)
	# 계산상 행이 그리드 밖으로 넘어가 배치가 통째로 실패했다. 자동 배치는 셀이 남아 있는 한 성공한다.
	for i in _stash.skillbooks.size():
		var it: Dictionary = _inv.make_skillbook_stash_item(_stash.skillbooks[i])   # 인스턴스(affix/탄 포함)
		if not it.is_empty():
			items.append(it)
	for cid in _stash.consumables:
		var it: Dictionary = _inv.make_consumable_stash_item(String(cid), int(_stash.consumables[cid]))
		if not it.is_empty():
			items.append(it)
	# F-009 §3.8 마석 — 허브 보관분을 타일로. 이게 없으면 스태시에 마석이 **보이지도 않고**,
	# 드래그로 옮겨도 아래 sync가 kind를 몰라 지워 버린다(M1 누락, DRIFT-145).
	for mid in _stash.manastones:
		var it: Dictionary = _inv.make_manastone_stash_item(String(mid), int(_stash.manastones[mid]))
		if not it.is_empty():
			items.append(it)
	# F-010 §3.11 참 — 비스택이라 개수만큼 타일을 만든다(칸을 먹는 게 곧 대가).
	for cid2 in _stash.charms:
		var it: Dictionary = _inv.make_charm_stash_item(String(cid2))
		if not it.is_empty():
			items.append(it)
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
	if _inv.is_open():
		_inv.toggle()                 # 닫기 → 남은 스태시 아이템을 _stash_src로 export (open_loot §persist)
	_sync_stash_from_source()         # 에디터에서 캐릭터/백팩으로 옮긴 스킬북·소비 = 스태시에서 제거 (중복 방지)
	_inv.commit_loose_to_backpack()   # 허브 백팩 편집 → 영속 Backpack(loose, 소비 포함). RunLoadout는 인벤 운반 안 함(B).
	var bp := get_node_or_null("/root/Backpack")
	if bp != null:
		bp.capture_from_party(_party)   # 허브 장착 기어+서브 → Backpack.equipped (member_subs 브리지 폐기)
	var form: Array = []
	if _formation != null:
		var offsets: Dictionary = _formation.get_offsets()
		for cid in offsets:
			var o: Vector2 = offsets[cid]
			form.append({"class_id": String(cid), "offset": [o.x, o.y]})  # o.y holds z (forward)
	_run_loadout.formation = form
	if _difficulty_opt != null:
		_run_loadout.difficulty = _difficulty_opt.get_item_text(_difficulty_opt.selected)


## Deploy 시 스태시 오토로드를 에디터의 최종 상태(_stash_src, 닫을 때 export됨)로 맞춘다. 에디터에서
## 캐릭터(장착)나 백팩(인출)으로 옮긴 스킬북·소비는 스태시에서 빠진다 — 장착=Backpack.equipped,
## 인출=Backpack.loose로 영속되므로 스태시에 남기면 중복(라이브러리 복제)이 된다. 기어는 장착 영속
## (I4) 전까지 라이브러리 모델 유지 → _stash.gear는 그대로 보존(동기화 시 손실 방지).
func _sync_stash_from_source() -> void:
	var gear: Array = []
	var skillbooks: Array = []
	var consumables: Dictionary = {}
	var manastones: Dictionary = {}
	var charms: Array = []
	# 그리드에 자리가 없어 표시되지 못한 소유분을 **먼저 되돌려 넣는다.** 이 sync는 Stash를 통째로
	# 재작성하므로, 안 보인 아이템 = 영구 삭제였다(과거 실사고). 이제 그리드 크기와 소유가 분리된다.
	var src: Array = (_stash_src.items as Array).duplicate()
	src.append_array(_inv.loot_overflow())
	for it in src:
		match String(it.get("kind", "")):
			"gear":
				# 보관분만(장착=Backpack.equipped로 빠짐). F-008 §3.7 인스턴스 — 스페어도 굴린 정체성·옵션 보존.
				var gi := {"base_gear_id": String(it.get("base_gear_id", ""))}
				var rid := String(it.get("rolled_identity_skill_id", ""))
				if not rid.is_empty():
					gi["rolled_identity_skill_id"] = rid
				if it.has("rolls"):
					gi["rolls"] = it["rolls"]
				gear.append(gi)
			"skillbook":
				# D-018 §7.3 인스턴스 — 스태시도 affix·잔여 탄 보존.
				var si := {"base_ability_id": String(it.get("base_ability_id", ""))}
				var af = it.get("affix", {})
				if typeof(af) == TYPE_DICTIONARY and not (af as Dictionary).is_empty():
					si["affix"] = af
				if it.has("charges"):
					si["charges"] = int(it["charges"])
				skillbooks.append(si)
			"consumable":
				var cid := String(it.get("consumable_id", ""))
				consumables[cid] = int(consumables.get(cid, 0)) + int(it.get("count", 1))
			"manastone":
				var mid := String(it.get("manastone_id", ""))
				manastones[mid] = int(manastones.get(mid, 0)) + int(it.get("count", 1))
			"charm":
				charms.append(String(it.get("charm_id", "")))   # 비스택 — 항목 수 = 칸 수
			_:
				# ⚠️ **모르는 kind = 조용한 삭제**였다. 이 sync는 Stash를 통째로 재작성하므로 분기가
				# 없는 종류는 그대로 증발한다 — 마석이 정확히 이랬다(M1이 런 쪽만 배선, DRIFT-145).
				# **새 아이템 종류를 추가하면 여기 + `_build_stash_items` 둘 다 봐야 한다.**
				push_warning("[TDC] 스태시 sync — 미처리 kind '%s' (소유 유실 위험)" % String(it.get("kind", "")))
	_stash.apply_dict({"gear": gear, "skillbooks": skillbooks, "consumables": consumables, "manastones": manastones, "charms": charms})
	_stash.save_stash()


## 저장 초기화 — 파괴적이라 확인 후 진행. (테스트/디버그)
func _confirm_reset_save() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "저장 초기화"
	dlg.dialog_text = "저장 데이터를 전부 초기화합니다.\n스태시·백팩·허브 메타(시설/창고/퀘스트) → 데모 시드.\n되돌릴 수 없습니다. 진행할까요?"
	dlg.ok_button_text = "초기화"
	dlg.cancel_button_text = "취소"
	add_child(dlg)
	dlg.confirmed.connect(_reset_save)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered()


## SaveProfile 파일 비우기 + 각 도메인 오토로드 시드 리셋 + 허브 씬 리로드(UI 재구성).
func _reset_save() -> void:
	var sp := get_node_or_null("/root/SaveProfile")
	if sp != null and sp.has_method("wipe"):
		sp.wipe()
	for path in ["/root/Stash", "/root/Backpack", "/root/HubProfile"]:
		var n := get_node_or_null(path)
		if n != null and n.has_method("reset_to_seed"):
			n.reset_to_seed()
	get_tree().reload_current_scene()   # 허브 재구성 — 리셋된 오토로드에서 새로 빌드
