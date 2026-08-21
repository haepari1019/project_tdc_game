extends HubPanel
## **대장간 — 건 모딩** (`UI-005` §3.2). P4b 경제의 중심 화면: 건을 고르고 그 건의 Q/E/R에 스킬을 새긴다.
##
## 왜 별도 화면인가: P4b에서 슬롯 스킬은 **멤버가 아니라 gear 인스턴스**에 귀속된다(`D-019` §3
## `equippedSlotAbilities[3]`). 결정 단위가 「누구에게 무엇을 들려줄까」가 아니라 **「이 건을 어떤
## 무기로 만들까」**다. 스태시는 물건을 옮기는 도구고, 여기는 **빌드를 만드는 도구**다.
##
## 화면 구성 — **좌: 이 건이 무엇인가 / 우: 무엇을 새길까**.
##   ① 시그니처(읽기 전용·gear 핀) ② Q/E/R **3칸 타일** ③ 결속 1줄 ④ 계열 필터 + 카탈로그
##   ⑤ 건 교체(소멸 경고 모달) ⑥ 슬롯 확장(`Slot` 노드 — M6에서 성소에서 대장간으로 옮겨왔다)
##
## **「고르기 → 결속 미리보기 → 확정」 2단계**다. 행마다 [배치] 버튼을 두면 클릭 한 번에 시술비가
## 빠져나간다 — 되돌릴 수 없는 값을 치르기 전에 **이 조합이 무엇을 얻는지** 읽게 하는 것이 요점이다.
## 결속은 gear × 정체성 × 슬롯의 삼중 매치라, 끼워 보기 전에는 알 수 없던 정보였다.

const SLOT_KEY := ["Q", "E", "R"]
const ROLES := ["Tank", "DPS", "Nuker", "Healer"]
const CAT_COLS := 4   # [이름] [계열·등급·비용] [사유] [행동]
const SkillText := preload("res://scripts/ui/skill_text.gd")
const BindingOverlays := preload("res://scripts/combat/abilities/bindings/binding_overlays.gd")

var party: Node = null      # 허브 라이브 파티 — 바꾼 뒤 즉시 재적용해 화면·툴팁이 따라오게

var _role: String = "Tank"
var _slot: int = 0          # 편집 중인 칸
var _fam: String = ""       # 계열 필터("" = 전체) — 49행을 읽을 수 있는 크기로 줄인다
var _pick: String = ""      # 고른 AB(확정 전) — 결속 미리보기의 대상
var _left: VBoxContainer
var _right: VBoxContainer
var _tabs: HBoxContainer
var _modal: Node                     # 소멸 확인 모달 — 떠 있으면 Esc가 창이 아니라 모달을 닫는다

@onready var _bp: Node = get_node_or_null("/root/Backpack")
@onready var _stash: Node = get_node_or_null("/root/Stash")
@onready var _hub: Node = get_node_or_null("/root/HubProfile")


func _ready() -> void:
	window_size = Vector2(1120, 660)
	panel_title = "대장간 — 건 모딩"
	super()
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", HubTheme.GAP_S)
	titlebar.add_child(_tabs)
	titlebar.move_child(_tabs, 1)
	for r in ROLES:
		var b := Button.new()
		b.text = Slice01Data.get_role_label(r)
		b.pressed.connect(func() -> void:
			_role = r
			_slot = 0
			_pick = ""
			_fam = ""
			refresh())
		_tabs.add_child(b)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", HubTheme.GAP_L)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	_left = VBoxContainer.new()
	_left.custom_minimum_size = Vector2(500, 0)
	_left.add_theme_constant_override("separation", HubTheme.GAP_S)
	cols.add_child(_left)
	cols.add_child(VSeparator.new())
	_right = VBoxContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.add_theme_constant_override("separation", HubTheme.GAP_S)
	cols.add_child(_right)


## `role`을 주면 그 역할로 바로 연다 — 마을 파티 스트립에서 「이 건 손보기」로 들어오는 경로.
func open_panel(role: String = "") -> void:
	if role != "" and ROLES.has(role):
		_role = role
		_slot = 0
	_pick = ""
	_fam = ""
	super()


func close_panel() -> void:
	if _modal != null:
		return          # 모달이 떠 있으면 Esc는 모달만 닫는다
	super()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and _modal != null:
		_close_modal()
		get_viewport().set_input_as_handled()
		return
	super(event)


# --- 조회 -------------------------------------------------------------------

func _entry() -> Dictionary:
	return _bp.member_entry(_role) if _bp != null else {}


func _gear_id() -> String:
	return String(_entry().get("gear", ""))


## 이 역할이 **실제로 쓰는** 정체성 = 인스턴스 굴림(있으면) > gear 아키타입 bundled. `F-008` §3.7.
func _identity_skill_id() -> String:
	var rid := String(_entry().get("rolled_identity", ""))
	if rid != "":
		return rid
	return String(Slice01Data.get_gear_master(_gear_id()).get("bundled_identity_skill_id", ""))


func _identity_ab() -> String:
	return String(Slice01Data.get_identity_row(_identity_skill_id()).get("ability_id", ""))


# --- 렌더 -------------------------------------------------------------------

func refresh() -> void:
	if _left == null or _bp == null:
		return
	for i in _tabs.get_child_count():
		var b: Button = _tabs.get_child(i) as Button
		if b != null:
			b.modulate = HubTheme.SEL if ROLES[i] == _role else Color(0.8, 0.8, 0.84)
	for c in _left.get_children():
		_left.remove_child(c)
		c.queue_free()
	for c2 in _right.get_children():
		_right.remove_child(c2)
		c2.queue_free()
	var scrap: int = int(_hub.scrap()) if _hub != null else 0
	set_status("시술비 ⚙%d" % scrap, HubTheme.ACCENT if scrap > 0 else HubTheme.BAD)
	_render_signature()
	_render_slots()
	_render_slot_expand()
	_render_gear_swap()
	_render_catalog()


## ① 시그니처 — gear에 **핀된** 정체성 + 평타. 여기서 바꿀 수 있는 건 없다(건을 갈아야 바뀐다).
func _render_signature() -> void:
	var gid := _gear_id()
	var gm: Dictionary = Slice01Data.get_gear_master(gid)
	_left.add_child(HubTheme.section("시그니처 — 건에 핀됨"))
	if gm.is_empty():
		_left.add_child(HubTheme.para("건을 착용하지 않았다 — 슬롯이 하나도 열리지 않는다. 아래에서 먼저 신는다.",
			"", HubTheme.BAD, 470))
		return
	var iab := _identity_ab()
	var sig: Dictionary = BindingOverlays.signature_for(gid, iab)
	var g := HubTheme.grid(2)
	_left.add_child(g)
	g.add_child(HubTheme.label("건", "HubMeta"))
	g.add_child(HubTheme.label(String(gm.get("display_name", gid))))
	g.add_child(HubTheme.label("정체성", "HubMeta"))
	g.add_child(HubTheme.label("%s  ·  %s" % [
		String(sig.get("name", Slice01Data.get_identity_display(_identity_skill_id()))), iab], "", HubTheme.ACCENT))
	g.add_child(HubTheme.label("평타", "HubMeta"))
	g.add_child(HubTheme.label("%s  ·  %s" % [String(gm.get("basic_attack_profile_id", "—")),
		String(gm.get("range_band", "—"))], "HubMeta"))
	if sig.has("covenant"):
		_left.add_child(HubTheme.para(String(sig["covenant"]), "", Color(0.80, 0.86, 0.95), 470))
	else:
		_left.add_child(HubTheme.para("이 정체성엔 아직 규약이 저작되지 않았다 — 결속은 기본 델타로만 걸린다.",
			"HubMeta", null, 470))


## ② Q/E/R — **칸처럼 보이는 타일 3개**. 텍스트 행이었을 땐 「여기가 슬롯이다」가 안 읽혔다.
func _render_slots() -> void:
	var gid := _gear_id()
	var cap: int = _bp.gear_slot_count(_role)
	var gmax := int(Slice01Data.get_gear_master(gid).get("gear_skill_slot_count_max", 0))
	_left.add_child(HubTheme.spacer())
	_left.add_child(HubTheme.section("Q / E / R   —   열린 칸 %d / 이 건의 최대 %d" % [cap, gmax]))
	# 규칙을 화면에 적어 둔다 — 비용이 붙는 칸과 안 붙는 칸이 왜 갈리는지가 여기서 답해져야 한다.
	_left.add_child(HubTheme.para("첫 칸은 건에 딸려 오는 기본이라 시술비가 없다. 둘째·셋째 칸이 확장이고 값이 붙는다.",
		"HubMeta", null, 470))
	var slots: Array = _bp.gear_slot_abilities(_role)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", HubTheme.GAP_M)
	_left.add_child(row)
	for j in 3:
		row.add_child(_slot_tile(j, cap, slots[j]))
	# ③ 선택 칸의 결속 1줄 — 타일 밑에 한 줄. 세 칸 것을 다 적으면 지금 관심사가 흐려진다.
	var cur = slots[_slot] if _slot < slots.size() else null
	if typeof(cur) == TYPE_DICTIONARY:
		_left.add_child(HubTheme.para("└ %s" % _binding_line(gid, String(cur.get("base_ability_id", "")), _slot),
			"HubMeta", HubTheme.LINK, 470))
		var rm := Button.new()
		rm.text = "[%s] 칸 비우기" % SLOT_KEY[_slot]
		rm.pressed.connect(func() -> void:
			_bp.set_gear_slot_ability(_role, _slot, "")
			_reapply()
			refresh())
		_left.add_child(rm)


## 슬롯 타일 1개 — 잠김/빈칸/장착을 **면과 테두리**로 구분한다(글자색만으론 어두운 배경에서 안 갈린다).
func _slot_tile(j: int, cap: int, sd) -> Control:
	var locked: bool = j >= cap
	var pc := PanelContainer.new()
	pc.theme_type_variation = "HubCardSel" if (j == _slot and not locked) else "HubCard"
	pc.custom_minimum_size = Vector2(152, 74)
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.modulate = Color(0.5, 0.5, 0.55) if locked else Color(1, 1, 1)
	if not locked:
		pc.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
				_slot = j
				_pick = ""      # 칸을 옮기면 고른 것도 리셋 — 다른 칸의 미리보기가 남으면 오독한다
				refresh())
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	pc.add_child(vb)
	vb.add_child(HubTheme.label("%s%s" % [SLOT_KEY[j], "  ▶" if (j == _slot and not locked) else ""],
		"HubSection", HubTheme.SEL if (j == _slot and not locked) else HubTheme.DIM))
	if locked:
		vb.add_child(HubTheme.label("잠김", "HubMeta"))
	elif typeof(sd) != TYPE_DICTIONARY:
		vb.add_child(HubTheme.label("— 비어 있음 —", "HubMeta"))
	else:
		var abid := String(sd.get("base_ability_id", ""))
		# 타일 폭(152)에서 autowrap을 켜면 글자 단위로 쪼개진다 → **한 줄 + 말줄임**.
		vb.add_child(HubTheme.line(String(Slice01Data.get_skillbook_master(abid).get("display_name", abid))))
		vb.add_child(HubTheme.label("◈%d" % Slice01Data.manastone_cost_for(abid), "HubMeta", HubTheme.ACCENT))
	return pc


## ③ 결속 프리뷰 1줄 — 이 조합이 무엇을 얻는가. `generic`이면 「정체성 기본 델타」임을 밝힌다:
## 저작된 변주와 기본값을 구분 못 하면 「왜 이 건을 골랐지」가 사라진다.
func _binding_line(gid: String, abid: String, slot: int) -> String:
	var ov: Dictionary = BindingOverlays.resolve_effective(gid, _identity_ab(), abid, slot)
	if ov.is_empty():
		return "결속 없음 — 이 정체성엔 이 스킬에 걸릴 규약이 없다."
	var tag: String = "기본 결속" if bool(ov.get("generic", false)) else String(ov.get("id", "BIND"))
	return "%s · %s" % [tag, String(ov.get("desc_ko", ov.get("payoff", "—")))]


## ⑥ 슬롯 확장 — `Slot` 노드(M6에서 성소 → 대장간). **사는 곳과 조건이 같은 건물**이어야 한다:
## 전에는 성소에서 사는데 대장간 tier가 막아 「왜 여기서 사는데 저기를 올리라 하지」가 됐다.
func _render_slot_expand() -> void:
	if _hub == null:
		return
	var nodes: Array = []
	for row in Slice01Data.tree_nodes_for_class(_role):
		if String((row as Dictionary).get("type", "")) == "Slot":
			nodes.append(row)
	if nodes.is_empty():
		return
	_left.add_child(HubTheme.spacer())
	_left.add_child(HubTheme.section("슬롯 확장"))
	var g := HubTheme.grid(3)
	_left.add_child(g)
	for n in nodes:
		var nid := String(n.get("node_id", ""))
		var bought: bool = bool(_hub.tree_unlocked.get(nid, false))
		var chk: Dictionary = _hub.tree_check(nid)
		var ok: bool = bool(chk.get("ok", false))
		g.add_child(HubTheme.label(String(n.get("display_name", nid)), "",
			HubTheme.TEXT if (bought or ok) else HubTheme.DISABLED))
		g.add_child(HubTheme.label(_cost_text(n.get("cost", {})), "HubMeta",
			HubTheme.OK if ok else HubTheme.DIM))
		if bought:
			g.add_child(HubTheme.label("✔ 확장됨", "HubMeta", HubTheme.OK))
		else:
			var buy := Button.new()
			buy.text = "확장"
			buy.disabled = not ok
			buy.tooltip_text = _reason_text(String(chk.get("reason", "")))
			buy.pressed.connect(func() -> void:
				_hub.tree_buy(nid)
				refresh())
			g.add_child(buy)


## ⑤ 건 교체 — 소멸 경고 모달을 반드시 거친다(`F-008` §3.10 D2).
func _render_gear_swap() -> void:
	_left.add_child(HubTheme.spacer())
	_left.add_child(HubTheme.section("건 교체   —   갈아끼우면 이 건의 슬롯 스킬은 소멸한다"))
	var cur := _gear_id()
	var seen: Dictionary = {}
	var g := HubTheme.grid(3)
	_left.add_child(g)
	var any := false
	for inst in (_stash.gear if _stash != null else []):
		var bgid := String(inst.get("base_gear_id", "")) if typeof(inst) == TYPE_DICTIONARY else String(inst)
		if bgid == "" or bgid == cur or seen.has(bgid):
			continue
		var gm: Dictionary = Slice01Data.get_gear_master(bgid)
		if gm.is_empty() or not (gm.get("equip_classes", []) as Array).has(_role):
			continue
		seen[bgid] = true
		any = true
		g.add_child(HubTheme.label(String(gm.get("display_name", bgid))))
		g.add_child(HubTheme.label("슬롯 최대 %d · %s" % [int(gm.get("gear_skill_slot_count_max", 3)),
			String(gm.get("range_band", "—"))], "HubMeta"))
		var b := Button.new()
		b.text = "착용"
		var snap: Dictionary = inst.duplicate(true) if typeof(inst) == TYPE_DICTIONARY else {"base_gear_id": bgid}
		b.pressed.connect(func() -> void: _confirm_swap(bgid, snap))
		g.add_child(b)
	if not any:
		_left.add_child(HubTheme.label("교체할 건이 창고에 없다 (같은 역할 · 현재 착용분 제외).", "HubMeta"))


## ④ 카탈로그 — **계열 필터 + 고르기**. 49행을 한 번에 늘어놓으면 아무것도 안 읽힌다.
## 못 끼우는 건 **숨기지 않고 회색으로** 둔다: 안 보이면 「왜 없지」가 되고, 회색이면 「왜 안 되지」에
## 답할 수 있다.
func _render_catalog() -> void:
	var gid := _gear_id()
	_right.add_child(HubTheme.section("[%s] 칸에 새길 스킬" % SLOT_KEY[_slot]))

	var fams: Array = Slice01Data.get_gear_master(gid).get("allowed_slot_families", [])
	var fbar := HBoxContainer.new()
	fbar.add_theme_constant_override("separation", 3)
	_right.add_child(fbar)
	for fam_id in ([""] + fams):
		var b := Button.new()
		b.text = "전체" if fam_id == "" else String(fam_id)
		b.modulate = HubTheme.SEL if String(fam_id) == _fam else Color(0.78, 0.78, 0.82)
		b.pressed.connect(func() -> void:
			_fam = String(fam_id)
			refresh())
		fbar.add_child(b)

	var g := HubTheme.grid(CAT_COLS)
	_right.add_child(g)
	var shown := 0
	for row in Slice01Data.get_skillbook_rows():
		var abid := String((row as Dictionary).get("base_ability_id", ""))
		if abid == "":
			continue
		# 다른 역할 전용은 아예 뺀다 — Role Gate는 「이 화면의 주제가 아님」이지 「조건 미충족」이 아니다.
		if not (row.get("equip_classes", []) as Array).has(_role):
			continue
		if _fam != "" and String(row.get("skill_family", "")) != _fam:
			continue
		shown += 1
		_catalog_row(g, row, abid)
	if shown == 0:
		HubTheme.span_row(g, HubTheme.label("이 계열에 이 역할이 쓸 스킬이 없다.", "HubMeta"))
	_render_pick()


## 카탈로그 한 줄 = 셀 4개. 클릭하면 **고른 것**이 되고, 확정은 아래 미리보기에서 한다.
func _catalog_row(g: GridContainer, row: Dictionary, abid: String) -> void:
	var chk: Dictionary = _bp.slot_equip_check(_role, _slot, abid)
	var ok: bool = bool(chk.get("ok", false))
	var picked: bool = abid == _pick
	var nm := HubTheme.label(("▶ " if picked else "   ") + String(row.get("display_name", abid)), "",
		HubTheme.SEL if picked else (HubTheme.TEXT if ok else HubTheme.DISABLED))
	nm.mouse_filter = Control.MOUSE_FILTER_STOP
	nm.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_pick = abid
			refresh())
	g.add_child(nm)
	# 시술비 자리에 **기본/확장**을 적는다. 값만 ⚙0으로 두면 「왜 어떤 건 공짜지」가 남는다.
	var price: int = int(_bp.slot_install_price(_role, abid))
	g.add_child(HubTheme.label("%s · %s · ◈%d · %s" % [String(row.get("skill_family", "—")),
		String(row.get("tier", "—")), Slice01Data.manastone_cost_for(abid),
		"기본" if price <= 0 else "⚙%d" % price], "HubMeta"))
	var why := HubTheme.label("" if ok else _reason_text(String(chk.get("reason", ""))), "HubMeta", HubTheme.BAD)
	why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(why)
	var sel := Button.new()
	sel.text = "고르기"
	sel.flat = true
	sel.pressed.connect(func() -> void:
		_pick = abid
		refresh())
	g.add_child(sel)


## **고르기 → 미리보기 → 확정.** 시술비는 되돌릴 수 없으므로 치르기 전에 결속을 읽게 한다.
func _render_pick() -> void:
	_right.add_child(HubTheme.spacer())
	if _pick == "":
		_right.add_child(HubTheme.para("목록에서 스킬을 고르면 여기에 결속 미리보기와 시술비가 뜬다.", "HubMeta"))
		return
	var m: Dictionary = Slice01Data.get_skillbook_master(_pick)
	var chk: Dictionary = _bp.slot_equip_check(_role, _slot, _pick)
	var ok: bool = bool(chk.get("ok", false))
	var pc := PanelContainer.new()
	pc.theme_type_variation = "HubCardSel"
	_right.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	pc.add_child(vb)
	vb.add_child(HubTheme.label("%s   ·   %s · %s" % [String(m.get("display_name", _pick)),
		String(m.get("tier", "—")), String(m.get("skill_family", "—"))], "HubSection", HubTheme.TEXT))
	vb.add_child(HubTheme.para(SkillText.describe(String((m.get("cast", {}) as Dictionary).get("kind", "")),
		m.get("cast", {})), "HubMeta"))
	vb.add_child(HubTheme.para("결속 — %s" % _binding_line(_gear_id(), _pick, _slot), "", HubTheme.LINK))
	var price: int = int(_bp.slot_install_price(_role, _pick))
	var have: int = int(_hub.scrap()) if _hub != null else 0
	if price <= 0:
		vb.add_child(HubTheme.label("기본 장착 — 시술비 없음      시전 ◈%d/회"
			% Slice01Data.manastone_cost_for(_pick), "", HubTheme.OK))
		vb.add_child(HubTheme.para(
			"건 하나에 스킬 하나는 원래 딸려 오는 것이다. 값이 붙는 건 **둘째·셋째 칸으로 확장**할 때다.",
			"HubMeta", null, 420))
	else:
		vb.add_child(HubTheme.label("확장 시술비 ⚙%d  ·  보유 ⚙%d      시전 ◈%d/회" % [
			price, have, Slice01Data.manastone_cost_for(_pick)], "",
			HubTheme.OK if have >= price else HubTheme.BAD))
	var go := Button.new()
	go.text = "[%s] 칸에 새긴다%s" % [SLOT_KEY[_slot], "" if price <= 0 else " (⚙%d)" % price]
	go.disabled = not ok
	go.tooltip_text = "" if ok else _reason_text(String(chk.get("reason", "")))
	go.pressed.connect(func() -> void:
		_bp.equip_slot_ability(_role, _slot, _pick)
		_pick = ""
		_reapply()
		refresh())
	vb.add_child(go)


func _cost_text(cost: Dictionary) -> String:
	if cost.is_empty():
		return "무료"
	var parts: Array = []
	for k in cost:
		parts.append("%s %d/%d" % [Slice01Data.get_haul_material(String(k)).get("display", k),
			int(_hub.vault_count(String(k))), int(cost[k])])
	return " · ".join(parts)


func _reason_text(reason: String) -> String:
	match reason:
		"no_gear": return "건 미착용"
		"slot": return "이 칸이 아직 안 열렸다"
		"family": return "이 건이 받지 않는 계열"
		"locked": return "미해금 — 필기 상점에서 해금"
		"dup": return "이미 다른 칸에 있음"
		"scrap": return "확장 시술비 부족"
		"tier_ceiling": return "필기 상점 등급 부족"
		"facility_req": return "대장간 승급 필요"
		"haul": return "금고 재료 부족"
		"facility": return "건물 미건립"
		_: return "불가"


# --- ⑤ 소멸 확인 모달 --------------------------------------------------------

## 되돌릴 수 없는 유일한 행동이라 **무엇을 잃는지 이름으로** 보여준다. 「정말?」만 묻는 모달은
## 아무것도 막지 못한다.
func _confirm_swap(new_gid: String, inst: Dictionary = {}) -> void:
	var lost: Array = []
	for sd in _bp.gear_slot_abilities(_role):
		if typeof(sd) == TYPE_DICTIONARY:
			var abid := String(sd.get("base_ability_id", ""))
			lost.append(String(Slice01Data.get_skillbook_master(abid).get("display_name", abid)))
	if lost.is_empty():
		_do_swap(new_gid, inst)     # 잃을 게 없으면 굳이 묻지 않는다
		return
	var dlg := ConfirmationDialog.new()
	dlg.title = "건을 갈아끼우면 슬롯 스킬이 사라진다"
	dlg.dialog_text = "소멸: %s\n\n같은 스킬은 필기 상점 해금이 남아 있으므로 시술비만 다시 내면 새 건에 새길 수 있다(F-009 §3.9.3).\n마석·참은 영향 없다." % ", ".join(lost)
	dlg.ok_button_text = "소멸 감수하고 착용"
	dlg.cancel_button_text = "취소"
	add_child(dlg)
	_modal = dlg
	dlg.confirmed.connect(func() -> void:
		_modal = null
		_do_swap(new_gid, inst))
	dlg.canceled.connect(func() -> void:
		_modal = null
		dlg.queue_free())
	dlg.popup_centered()


func _close_modal() -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null


## 건은 **하나뿐인 물건**이다 — 창고에서 꺼내 신고, 벗은 건 창고로 돌려놓는다(굴림째로).
## 이 교환을 빼먹으면 착용할 때마다 건이 복제되고 소멸 경고가 무의미해진다.
func _do_swap(new_gid: String, inst: Dictionary = {}) -> void:
	var old_gid := _gear_id()
	var old_e: Dictionary = _entry()
	var lost: Array = _bp.set_member_gear(_role, new_gid, inst)   # 소멸은 여기서(반환 = 잃은 목록)
	if _stash != null:
		_stash.remove_gear(new_gid)
		if old_gid != "":
			_stash.add_gear(old_gid, String(old_e.get("rolled_identity", "")),
				old_e.get("rolls", {}) if typeof(old_e.get("rolls", {})) == TYPE_DICTIONARY else {})
	if not lost.is_empty():
		print("[TDC] 건 교체 — %s 슬롯 AB 소멸: %s" % [_role, ", ".join(lost)])
	_reapply()
	refresh()


## 저장분을 라이브 파티에 되먹인다 — 모딩 결과가 파티 시트/툴팁에 바로 보여야 「바꿨다」가 체감된다.
func _reapply() -> void:
	if party != null and _bp != null:
		_bp.apply_to_party(party)
