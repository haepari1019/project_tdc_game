extends Control
## EquipPanel — per-character gear equip slots (F-008 §3.2) + sub skillbook Q/E/R slots
## (F-009 §3.1), extracted from InventoryUI (ARCHITECTURE DEBT-INV). Owns the two equip
## columns (build/refresh), equip rules (combat gate + equipClasses same-role), drag-out of a
## slot, and the green/red drop previews. The central DRAG state + router stays on the
## InventoryUI coordinator (`_inv`): this panel calls back start_drag_from_slot()/is_dragging()
## /backpack_grid()/msg(), and the coordinator's _drop/_update_drag/_revert_drag delegate the
## gear/skillbook branches here.

const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")
const ItemFactory := preload("res://scripts/ui/inventory/item_factory.gd")
const RichTooltip := preload("res://scripts/ui/rich_tooltip.gd")   # 색 가능한 BBCode 툴팁(장착 슬롯)
const SkillText := preload("res://scripts/ui/skill_text.gd")

const SLOT_OK := Color(0.30, 0.85, 0.40, 0.32)    # drag-over slot, equippable
const SLOT_BAD := Color(0.95, 0.25, 0.20, 0.42)   # drag-over slot, wrong class / in combat

var _inv: Control = null            # InventoryUI coordinator (drag state + backpack owner)
var _party: Node = null
var _combat: Node = null
var _content_row: HBoxContainer = null

var _equip_box: VBoxContainer = null
var _equip_slots: Array = []        # Panel per character (the slot frame = drop target)
var _equip_tiles: Array = []        # Label inside each slot (equipped gear name)
var _equip_overlays: Array = []     # ColorRect per slot (green/red drag preview)
var _equip_msg: Label = null        # transient feedback (combat/role reject)

var _sub_box: VBoxContainer = null
var _sub_slots: Array = []          # entries: {panel, tile, overlay, char, slot} — 4 chars × Q/E/R


func setup(inv: Control, party: Node, combat: Node) -> void:
	_inv = inv
	_party = party
	_combat = combat
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # logic holder; never catches input itself


func build(content_row: HBoxContainer) -> void:
	_content_row = content_row
	_build_equip_column()
	_build_sub_column()


func refresh() -> void:
	_refresh_equip_slots()
	_refresh_sub_slots()


func msg(text: String) -> void:
	if _equip_msg != null:
		_equip_msg.text = text


func clear_previews() -> void:
	_clear_slot_previews()
	_clear_sub_previews()


# --- party gear equip slots (F-008 §3.2 / DEC-20260611-001) ---------------------

func _build_equip_column() -> void:
	if _content_row == null or _party == null:
		return
	if _equip_box != null and is_instance_valid(_equip_box):
		_equip_box.queue_free()
	_equip_slots.clear()
	_equip_tiles.clear()
	_equip_overlays.clear()
	_equip_box = VBoxContainer.new()
	_equip_box.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "PARTY GEAR (장비 슬롯)"
	title.add_theme_font_size_override("font_size", 14)
	_equip_box.add_child(title)
	_equip_msg = Label.new()
	_equip_msg.add_theme_font_size_override("font_size", 11)
	_equip_msg.modulate = Color(1.0, 0.72, 0.42)
	# Fixed message area — wrap within the column width so a long message can't widen the popup
	# (window auto-sizes to content). 고정 폭 176 · 3줄 높이 예약 · 초과는 클립. (사용자 버그 1)
	_equip_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_equip_msg.custom_minimum_size = Vector2(176, 42)
	_equip_msg.size_flags_horizontal = Control.SIZE_FILL
	_equip_msg.max_lines_visible = 3
	_equip_box.add_child(_equip_msg)
	var members: Array = _party.get_members()
	for i in members.size():
		var cname := String((members[i] as Node).class_id)
		var head := Label.new()  # per-character header (class)
		head.text = cname.to_upper()
		head.add_theme_font_size_override("font_size", 11)
		head.modulate = UnitVisuals.role_color(cname)
		_equip_box.add_child(head)
		var slot := RichTooltip.new()  # slot frame = drop target + drag source (gear) · BBCode 툴팁
		slot.custom_minimum_size = Vector2(176, 50)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_gear_slot_input.bind(i))
		var tile := Label.new()
		tile.set_anchors_preset(Control.PRESET_FULL_RECT)
		tile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_theme_font_size_override("font_size", 11)
		slot.add_child(tile)
		var ov := ColorRect.new()  # green/red drag-preview overlay (on top of the tile)
		ov.set_anchors_preset(Control.PRESET_FULL_RECT)
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ov.visible = false
		slot.add_child(ov)
		_equip_box.add_child(slot)
		_equip_slots.append(slot)
		_equip_tiles.append(tile)
		_equip_overlays.append(ov)
	_content_row.add_child(_equip_box)
	_content_row.move_child(_equip_box, 0)  # leftmost column


func _refresh_equip_slots() -> void:
	if _party == null:
		return
	var members: Array = _party.get_members()
	for i in mini(members.size(), _equip_slots.size()):
		var m: Node = members[i]
		var gear: Dictionary = m.equipped_gear
		var col: Color = UnitVisuals.role_color(String(m.class_id))
		_equip_tiles[i].text = String(gear.get("display_name", gear.get("base_gear_id", "—")))
		# 툴팁은 slot(STOP, 실제 호버 대상)에 — tile은 MOUSE_FILTER_IGNORE라 안 보였음. BBCode 상세(우클릭=가방).
		_equip_slots[i].tooltip_text = _gear_slot_tip(m)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col.r, col.g, col.b, 0.30)
		sb.border_color = col.lightened(0.35)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(5)
		_equip_slots[i].add_theme_stylebox_override("panel", sb)


func gear_slot_under(mouse: Vector2) -> int:
	for i in _equip_slots.size():
		var s: Panel = _equip_slots[i]
		if s.is_visible_in_tree() and s.get_global_rect().has_point(mouse):
			return i
	return -1


## Can `member` equip `master` right now? combat gate (F-008 §4.2) + equipClasses
## same-role (F-008 §3.4). No side effects — used by both the drag preview and equip.
func _can_equip_now(member: Node, master: Dictionary) -> bool:
	if member == null or master.is_empty():
		return false
	if _combat != null and _combat.is_engaged():
		return false
	return member.can_equip_gear(master)


## Index of the first party member whose class matches the gear's equipClasses, else -1.
func _matching_member(master: Dictionary) -> int:
	if _party == null:
		return -1
	var members: Array = _party.get_members()
	for i in members.size():
		if (members[i] as Node).can_equip_gear(master):
			return i
	return -1


## Apply the equip (caller already removed the item from its grid). Displaced gear
## returns to the backpack as an At-Risk instance (F-008 §3.3, decision B).
func _commit_equip(member: Node, master: Dictionary, item: Dictionary = {}) -> void:
	var displaced: Dictionary = member.equipped_gear
	# F-008 §3.7 — 아이템 인스턴스의 rolled(identity/rolls)을 master에 병합해 장착(G2). 없으면 bundled.
	var gm := master.duplicate(true)
	var rid := String(item.get("rolled_identity_skill_id", ""))
	if rid != "":
		gm["rolled_identity_skill_id"] = rid
	if item.has("rolls") and typeof(item["rolls"]) == TYPE_DICTIONARY:
		gm["rolls"] = item["rolls"]
	member.equip_gear(gm)
	if not displaced.is_empty():
		if not _inv.backpack_grid().add_item_dict(ItemFactory.gear_item(displaced, true)):
			push_warning("[TDC] Backpack full — displaced gear had nowhere to go")
	_refresh_equip_slots()
	msg("%s ▸ %s 장착" % [String(member.class_id), String(master.get("display_name", ""))])


## Drag-drop equip onto member `slot_index`. Returns false (no change) if gated; the
## drag item is already lifted, so on success it is consumed (now equipped).
func try_equip_gear(slot_index: int, item: Dictionary) -> bool:
	var member: Node = _party.get_member(slot_index) if _party != null else null
	var master: Dictionary = Slice01Data.get_gear_master(String(item.get("base_gear_id", "")))
	if member == null or master.is_empty():
		return false
	if _combat != null and _combat.is_engaged():
		msg("전투 중에는 장비 교체 불가 (F-008 §4.2)")
		return false
	if not member.can_equip_gear(master):
		msg("역할 불일치 — %s 전용 장비" % String((master.get("equip_classes", ["?"]) as Array)[0]))
		return false
	_commit_equip(member, master, item)
	return true


## Right-click equip: send a backpack gear item to the matching-class member (auto-target).
func equip_gear_to_matching(grid: Node, item: Dictionary) -> void:
	var master: Dictionary = Slice01Data.get_gear_master(String(item.get("base_gear_id", "")))
	if master.is_empty():
		return
	if _combat != null and _combat.is_engaged():
		msg("전투 중에는 장비 교체 불가 (F-008 §4.2)")
		return
	var idx := _matching_member(master)
	if idx < 0:
		msg("착용 가능한 %s 캐릭터 없음" % String((master.get("equip_classes", ["?"]) as Array)[0]))
		return
	grid.lift(item)  # remove from backpack (consumed → equipped)
	_commit_equip(_party.get_member(idx), master, item)


## Re-equip a gear item reverted onto its origin slot (coordinator._revert_drag "gear").
func revert_gear(char_index: int, base_gear_id: String) -> void:
	var m: Node = _party.get_member(char_index) if _party != null else null
	if m != null:
		m.equip_gear(Slice01Data.get_gear_master(base_gear_id))
	_refresh_equip_slots()


func _set_slot_preview(i: int, ok: bool) -> void:
	if i < 0 or i >= _equip_overlays.size():
		return
	var ov: ColorRect = _equip_overlays[i]
	ov.color = SLOT_OK if ok else SLOT_BAD
	ov.visible = true


func _clear_slot_previews() -> void:
	for ov: ColorRect in _equip_overlays:
		ov.visible = false


## During a drag, tint the hovered equip/sub slot green (equippable) / red (wrong class or
## in combat). Non-gear/skillbook drags clear all slot previews. `drag` = coordinator's _drag.
func update_previews(mouse: Vector2, drag: Dictionary) -> void:
	_clear_slot_previews()
	_clear_sub_previews()
	var kind := String(drag.get("kind", ""))
	if kind == "gear":
		var si := gear_slot_under(mouse)
		if si >= 0:
			var master: Dictionary = Slice01Data.get_gear_master(String(drag.get("base_gear_id", "")))
			_set_slot_preview(si, _can_equip_now(_party.get_member(si), master))


# --- sub skillbook slots (per-character Q/E/R — F-009 §3.1) ---------------------

func _build_sub_column() -> void:
	if _content_row == null or _party == null:
		return
	if _sub_box != null and is_instance_valid(_sub_box):
		_sub_box.queue_free()
	_sub_slots.clear()
	_sub_box = VBoxContainer.new()
	_sub_box.add_theme_constant_override("separation", 6)
	var title := Label.new()
	# M4 — 슬롯은 **건(gear) 귀속**이 됐다(`D-019` §3). 여기서 끼우면 다음 `apply_to_party`가
	# 저장분으로 덮어써 **조용히 되돌아간다** — 이 레포가 반복해서 당한 조용한 실패다. 그래서 읽기 전용.
	title.text = "SUB SKILLS (건 귀속 · Q/E/R — 변경은 「대장간 · 건 모딩」)"
	title.add_theme_font_size_override("font_size", 14)
	_sub_box.add_child(title)
	var members: Array = _party.get_members()
	for ci in members.size():
		var cname := String((members[ci] as Node).class_id)
		var crow := HBoxContainer.new()
		crow.add_theme_constant_override("separation", 5)
		var clabel := Label.new()
		clabel.text = cname
		clabel.custom_minimum_size = Vector2(50, 0)
		clabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		clabel.modulate = UnitVisuals.role_color(cname)
		clabel.add_theme_font_size_override("font_size", 11)
		crow.add_child(clabel)
		for si in 3:
			var slot := RichTooltip.new()   # BBCode 툴팁(설명+affix 색구분)
			slot.custom_minimum_size = Vector2(96, 44)
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.gui_input.connect(_on_sub_slot_input.bind(_sub_slots.size()))
			var tile := Label.new()
			tile.set_anchors_preset(Control.PRESET_FULL_RECT)
			tile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tile.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_theme_font_size_override("font_size", 9)
			slot.add_child(tile)
			var ov := ColorRect.new()
			ov.set_anchors_preset(Control.PRESET_FULL_RECT)
			ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ov.visible = false
			slot.add_child(ov)
			crow.add_child(slot)
			_sub_slots.append({"panel": slot, "tile": tile, "overlay": ov, "char": ci, "slot": si})
		_sub_box.add_child(crow)
	_content_row.add_child(_sub_box)
	_content_row.move_child(_sub_box, 1)  # after the gear column


func _refresh_sub_slots() -> void:
	if _party == null:
		return
	var members: Array = _party.get_members()
	for e in _sub_slots:
		if int(e.char) >= members.size():
			continue
		var inst = (members[int(e.char)] as Node).get_skillbook(int(e.slot))
		var key: String = ["Q", "E", "R"][int(e.slot)]
		var col: Color
		if inst == null:
			e.tile.text = "%s\n—" % key
			e.panel.tooltip_text = "[color=#9aa4b2]보조 %s\n(빈 슬롯 — 스킬북 장착)[/color]" % key
			col = Color(0.28, 0.31, 0.38)
		else:
			# 탄(charges)은 **더 이상 표시하지 않는다** — 실제 소모는 마석이라 탄수는 거짓 정보였다.
			# 필드 자체는 살아 있다(M5에서 폐기; 그때까지 마석을 되돌릴 여지). ref: DRIFT-145.
			var mc: int = Slice01Data.manastone_cost_for(String(inst.get("base_ability_id", "")))
			e.tile.text = "%s %s%s" % [key, _short(String(inst.display_name)), ("\n◈%d" % mc) if mc > 0 else ""]
			e.panel.tooltip_text = _sub_slot_tip(members[int(e.char)], inst, key)   # BBCode 상세(우클릭=가방)
			col = Color(0.40, 0.55, 0.85)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col.r, col.g, col.b, 0.30)
		sb.border_color = col.lightened(0.3)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		e.panel.add_theme_stylebox_override("panel", sb)


func _short(s: String) -> String:
	return s if s.length() <= 10 else s.substr(0, 9) + "…"


## 장착 기어 슬롯 툴팁(BBCode) — 표시명 + 정체성 + 실제 스탯(roll 반영) + 옵션(색) + 회수 안내.
func _gear_slot_tip(m: Node) -> String:
	var role := Slice01Data.get_role_label(String(m.class_id))
	var gear: Dictionary = m.equipped_gear
	if gear.is_empty():
		return "[color=#9aa4b2]%s · 미장착[/color]" % role
	var lines: Array = [
		"[b]%s[/b]  [color=#9aa4b2]· %s[/color]" % [String(gear.get("display_name", gear.get("base_gear_id", ""))), role],
		"[color=#9aa4b2]정체성: %s[/color]" % Slice01Data.get_identity_display(String(m.identity_skill_id)),
		"[color=#9aa4b2]HP %d · 평타 %d / %.1fs / %.1fm[/color]" % [int(m.max_hp), int(m.basic_damage), float(m.basic_interval_s), float(m.basic_range_m)],
	]
	var roll := SkillText.gear_roll_line(m.gear_rolls)
	if not roll.is_empty():
		lines.append(roll)
	lines.append("[color=#9aa4b2]── 우클릭 → 가방[/color]")
	return "\n".join(lines)


## 장착 서브 스킬 슬롯 툴팁(BBCode) — 표시명 + 설명문 + 마석/쿨 + 비주력 패널티(색). 표시 전용(M5).
func _sub_slot_tip(m: Node, inst: Dictionary, key: String) -> String:
	var kind := String(inst.params.get("kind", ""))
	var lines: Array = [
		"[b]%s[/b]  [color=#9aa4b2]· 보조 %s[/color]" % [String(inst.display_name), key],
		SkillText.describe(kind, inst.params),
		"[color=#9aa4b2]◈ 마석 %d · 쿨 %ss[/color]" % [Slice01Data.manastone_cost_for(String(inst.get("base_ability_id", ""))), str(inst.params.get("cooldown_s", "?"))],
	]
	var bp := SkillText.band_pct(String(inst.get("base_ability_id", "")), String(m.class_id))
	if bp > 0:
		lines.append(SkillText.band_line(bp))
	lines.append("[color=#9aa4b2]── 우클릭 → 가방[/color]")
	return "\n".join(lines)


func sub_slot_under(mouse: Vector2) -> int:
	for i in _sub_slots.size():
		var p: Panel = _sub_slots[i].panel
		if p.is_visible_in_tree() and p.get_global_rect().has_point(mouse):
			return i
	return -1


## ~~서브 장착·회수·드래그 경로 일체~~ — **M5에서 제거**(`D-018` §9 스킬북 인스턴스 Frozen).
## `_skillbook_inst` · `_skillbook_item_from_inst` · `_commit_sub_equip` · `try_equip_sub` ·
## `equip_sub_to_first` · `revert_sub` · `_can_equip_sub_now` — 전부 **스킬북이 물건이던 시절**의
## 배관이다. 슬롯 AB는 이제 gear에 새겨진 등록이라 집을 수도, 가방에 넣을 수도 없다.
## SUB 컬럼은 `_refresh_sub_slots`가 그리는 **표시 전용**으로만 남는다(변경 = `hub_modding_panel`).




func _set_sub_preview(i: int, ok: bool) -> void:
	if i < 0 or i >= _sub_slots.size():
		return
	_sub_slots[i].overlay.color = SLOT_OK if ok else SLOT_BAD
	_sub_slots[i].overlay.visible = true


func _clear_sub_previews() -> void:
	for e in _sub_slots:
		e.overlay.visible = false


# --- drag OUT of an equip / sub slot (unequip to inventory, or move slot↔slot) --

func _on_gear_slot_input(event: InputEvent, char_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT and not _inv.is_dragging():
		_begin_gear_slot_drag(char_index)
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and not _inv.is_dragging():
		_unequip_gear_to_backpack(char_index)   # 우클릭 = 가방으로 회수
		accept_event()


## SUB 슬롯은 **표시 전용**이다(M5). 좌·우클릭 모두 안내만 한다 — 조용히 무시하면 "고장났나"가
## 되므로 어디로 가야 하는지 말해 준다.
func _on_sub_slot_input(event: InputEvent, _flat_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or _inv.is_dragging():
		return
	if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		msg("슬롯 스킬은 건(gear)에 귀속된다 — 「대장간 · 건 모딩」에서 변경 (F-009 §3.9.2)")
		accept_event()


## 우클릭 회수 — 장착 기어를 가방(backpack)으로. 인스턴스(굴린 identity/rolls) 보존. 가방 가득 시 유지.
func _unequip_gear_to_backpack(char_index: int) -> void:
	var m: Node = _party.get_member(char_index) if _party != null else null
	if m == null or (m.equipped_gear as Dictionary).is_empty():
		return
	if _combat != null and _combat.is_engaged():
		msg("전투 중에는 장비 해제 불가 (F-008 §4.2)")
		return
	if float(m.identity_cooldown_s) > 0.0:
		msg("Identity 스킬 쿨다운 중 — 장비 해제 불가")
		return
	var item := ItemFactory.gear_item(m.equipped_gear, true)   # rolled identity/rolls 캐리(G2) → At-Risk
	if not _inv.backpack_grid().add_item_dict(item):
		msg("가방이 가득 참 — 회수 불가")
		return
	m.unequip_gear()
	_refresh_equip_slots()
	msg("%s 장비 → 가방" % String(m.class_id))


func _begin_gear_slot_drag(char_index: int) -> void:
	var m: Node = _party.get_member(char_index) if _party != null else null
	if m == null or (m.equipped_gear as Dictionary).is_empty():
		return
	if _combat != null and _combat.is_engaged():
		msg("전투 중에는 장비 해제 불가 (F-008 §4.2)")
		return
	if float(m.identity_cooldown_s) > 0.0:
		msg("Identity 스킬 쿨다운 중 — 장비 해제 불가")
		return
	var item := ItemFactory.gear_item(m.equipped_gear, true)  # unequipped → At-Risk in inventory
	m.unequip_gear()
	_refresh_equip_slots()
	_inv.start_drag_from_slot(item, {"kind": "gear", "char": char_index})

