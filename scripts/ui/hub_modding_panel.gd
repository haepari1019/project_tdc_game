extends Control
## **건 모딩 패널** (`UI-005` §3.2) — P4b 경제의 중심 화면. gear를 고르고 그 gear의 Q/E/R에 스킬을 끼운다.
##
## 왜 별도 화면인가: P4b에서 서브는 **멤버가 아니라 gear 인스턴스**에 귀속된다(`D-019` §3
## `equippedSlotAbilities[3]`). 그래서 "누구에게 무엇을 들려줄까"가 아니라 **"이 gear를 어떤 무기로
## 만들까"**가 결정 단위다. 스태시 드래그(`inventory_ui`)는 물건을 옮기는 도구고, 여기는 **빌드를
## 만드는 도구**다 — 둘을 한 그리드에 욱여넣으면 둘 다 나빠진다.
##
## `UI-005` §3.2가 요구하는 6영역:
##   ① 시그니처(읽기 전용) ② Q/E/R 슬롯 ③ 결속 1줄 프리뷰 ④ archetype/Role 필터 회색
##   ⑤ gear 교체 소멸 경고 모달 ⑥ 마석·참 반입 요약
##
## **드래그 대신 클릭 배치.** 작업지시서는 "드래그 장착"이라 썼지만, 스태시 팝업의 중앙 드래그 라우터를
## 건드리지 않는다는 제약(회귀 위험)과 상충한다. 슬롯을 고르고 목록에서 고르는 2클릭은 기능상 동치이며
## 거부 사유를 **그 자리에서 글로** 보여줄 수 있다 — 드래그는 "왜 안 들어가지"를 설명하지 못한다.

const OK := Color(0.62, 1.0, 0.62)
const BAD := Color(1.0, 0.6, 0.55)
const DIM := Color(0.62, 0.62, 0.66)
const ACCENT := Color(1.0, 0.81, 0.42)
const SEL := Color(0.62, 0.86, 1.0)
const SLOT_KEY := ["Q", "E", "R"]
const ROLES := ["Tank", "DPS", "Nuker", "Healer"]

signal closed

var _role: String = "Tank"
var _slot: int = 0                 # 지금 편집 중인 슬롯(목록에서 고른 AB가 여기로 들어간다)
var _left: VBoxContainer           # 시그니처 + 슬롯 + gear
var _right: VBoxContainer          # AB 목록
var _foot: Label
var _role_bar: HBoxContainer
var _modal: Control

@onready var _bp: Node = get_node_or_null("/root/Backpack")
@onready var _stash: Node = get_node_or_null("/root/Stash")
@onready var _hub: Node = get_node_or_null("/root/HubProfile")

## 허브의 라이브 파티(있으면) — 슬롯을 바꾼 뒤 즉시 재적용해 화면·툴팁이 따라오게 한다.
var party: Node = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var win := PanelContainer.new()
	win.custom_minimum_size = Vector2(1080, 660)
	center.add_child(win)
	var margin := MarginContainer.new()
	for sd in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(sd, 16)
	win.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var bar := HBoxContainer.new()
	root.add_child(bar)
	var title := Label.new()
	title.text = "대장간 · 건 모딩 (UI-005 §3.2)"
	title.add_theme_font_size_override("font_size", 20)
	bar.add_child(title)
	_role_bar = HBoxContainer.new()
	_role_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_role_bar.add_theme_constant_override("separation", 4)
	bar.add_child(_role_bar)
	var close := Button.new()
	close.text = "닫기 (Esc)"
	close.pressed.connect(close_panel)
	bar.add_child(close)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	root.add_child(cols)

	var lscroll := ScrollContainer.new()
	lscroll.custom_minimum_size = Vector2(560, 0)
	lscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(lscroll)
	_left = VBoxContainer.new()
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.add_theme_constant_override("separation", 4)
	lscroll.add_child(_left)

	var rscroll := ScrollContainer.new()
	rscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(rscroll)
	_right = VBoxContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.add_theme_constant_override("separation", 2)
	rscroll.add_child(_right)

	_foot = Label.new()
	_foot.add_theme_font_size_override("font_size", 12)
	root.add_child(_foot)

	for r in ROLES:
		var b := Button.new()
		b.text = Slice01Data.get_role_label(r)
		b.pressed.connect(func() -> void:
			_role = r
			_slot = 0
			_refresh())
		_role_bar.add_child(b)


func open_panel() -> void:
	visible = true
	_refresh()


func close_panel() -> void:
	if _modal != null:
		return          # 모달이 떠 있으면 Esc는 모달만 닫는다
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if _modal != null:
		_close_modal()
	else:
		close_panel()
	get_viewport().set_input_as_handled()


# --- 데이터 조회 -------------------------------------------------------------

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


# --- 렌더 --------------------------------------------------------------------

func _refresh() -> void:
	if _left == null or _bp == null:
		return
	for i in _role_bar.get_child_count():
		var b: Button = _role_bar.get_child(i) as Button
		if b != null:
			b.modulate = SEL if ROLES[i] == _role else Color(0.8, 0.8, 0.84)
	for c in _left.get_children():
		c.queue_free()
	for c in _right.get_children():
		c.queue_free()
	_render_signature()
	_render_slots()
	_render_gear_swap()
	_render_catalog()
	_render_footer()


## ① 시그니처 — gear에 **핀된** 정체성 + 평타. 여기서 바꿀 수 있는 건 없다(gear를 갈아야 바뀐다).
func _render_signature() -> void:
	var gid := _gear_id()
	var gm: Dictionary = Slice01Data.get_gear_master(gid)
	_head("① 시그니처 (읽기 전용 — gear 핀)")
	if gm.is_empty():
		_line("gear 미착용 — 슬롯이 하나도 열리지 않는다. 아래에서 gear를 먼저 신어야 한다.", BAD)
		return
	_line("건 %s" % String(gm.get("display_name", gid)), Color(1, 1, 1))
	var iab := _identity_ab()
	var sig: Dictionary = BindingOverlays.signature_for(gid, iab)
	var iname: String = String(sig.get("name", Slice01Data.get_identity_display(_identity_skill_id())))
	_line("정체성 %s  ·  %s" % [iname, iab], ACCENT)
	_line("평타 %s  ·  사거리대 %s" % [String(gm.get("basic_attack_profile_id", "—")), String(gm.get("range_band", "—"))], DIM)
	if sig.has("covenant"):
		var cov := Label.new()
		cov.text = String(sig["covenant"])
		cov.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cov.custom_minimum_size = Vector2(540, 0)
		cov.modulate = Color(0.80, 0.86, 0.95)
		cov.add_theme_font_size_override("font_size", 12)
		_left.add_child(cov)
	else:
		_line("이 정체성엔 아직 규약이 저작되지 않았다 — 결속은 기본 델타로만 걸린다.", DIM)


## ② Q/E/R 슬롯 + ③ 결속 1줄 프리뷰.
func _render_slots() -> void:
	var gid := _gear_id()
	var cap: int = _bp.gear_slot_count(_role)
	var gmax := int(Slice01Data.get_gear_master(gid).get("gear_skill_slot_count_max", 0))
	_head("② Q/E/R 슬롯   (열린 칸 %d / 이 건의 최대 %d)" % [cap, gmax])
	var slots: Array = _bp.gear_slot_abilities(_role)
	for j in 3:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		_left.add_child(hb)
		var key := Label.new()
		key.text = "[%s]" % SLOT_KEY[j]
		key.custom_minimum_size = Vector2(34, 0)
		key.modulate = SEL if j == _slot else DIM
		hb.add_child(key)
		if j >= cap:
			var lk := Label.new()
			lk.text = "잠김 — %s" % ("이 건은 %d칸까지다 (gear 교체 필요)" % gmax if cap >= gmax else "트리 Slot 노드 / 대장간 T2 필요")
			lk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lk.modulate = DIM
			lk.add_theme_font_size_override("font_size", 12)
			hb.add_child(lk)
			continue
		var sd = slots[j]
		var abid := String(sd.get("base_ability_id", "")) if typeof(sd) == TYPE_DICTIONARY else ""
		var pick := Button.new()
		pick.text = "이 칸 편집" if j != _slot else "▶ 편집 중"
		pick.custom_minimum_size = Vector2(90, 0)
		pick.pressed.connect(func() -> void:
			_slot = j
			_refresh())
		hb.add_child(pick)
		var name_l := Label.new()
		if abid == "":
			name_l.text = "— 비어 있음 —"
			name_l.modulate = DIM
		else:
			var m: Dictionary = Slice01Data.get_skillbook_master(abid)
			name_l.text = "%s  ◈%d" % [String(m.get("display_name", abid)), Slice01Data.manastone_cost_for(abid)]
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.add_theme_font_size_override("font_size", 13)
		hb.add_child(name_l)
		if abid != "":
			var rm := Button.new()
			rm.text = "빼기"
			rm.pressed.connect(func() -> void:
				_bp.set_gear_slot_ability(_role, j, "")
				_reapply()
				_refresh())
			hb.add_child(rm)
			_line("    └ %s" % _binding_line(gid, abid, j), Color(0.72, 0.82, 1.0))


## ③ 결속 프리뷰 1줄 — 이 조합이 지금 무엇을 얻는가. `generic`이면 "정체성 기본 델타"임을 밝힌다
## (저작된 변주와 기본값을 구분 못 하면 "왜 이 gear를 골랐지"가 사라진다).
func _binding_line(gid: String, abid: String, slot: int) -> String:
	var ov: Dictionary = BindingOverlays.resolve_effective(gid, _identity_ab(), abid, slot)
	if ov.is_empty():
		return "결속 없음 — 이 정체성엔 이 스킬에 걸릴 규약이 없다."
	var tag: String = "기본 결속" if bool(ov.get("generic", false)) else String(ov.get("id", "BIND"))
	return "%s · %s" % [tag, String(ov.get("desc_ko", ov.get("payoff", "—")))]


## ⑤ gear 교체 — 소멸 경고 모달을 반드시 거친다.
func _render_gear_swap() -> void:
	_head("⑤ 건 교체   ※ 갈아끼우면 이 건의 슬롯 스킬은 소멸한다")
	var cur := _gear_id()
	var seen: Dictionary = {}
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
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		_left.add_child(hb)
		var l := Label.new()
		l.text = "%s  (슬롯 최대 %d · %s)" % [String(gm.get("display_name", bgid)),
				int(gm.get("gear_skill_slot_count_max", 3)), String(gm.get("range_band", "—"))]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 12)
		hb.add_child(l)
		var b := Button.new()
		b.text = "착용"
		var snap: Dictionary = inst.duplicate(true) if typeof(inst) == TYPE_DICTIONARY else {"base_gear_id": bgid}
		b.pressed.connect(func() -> void: _confirm_swap(bgid, snap))
		hb.add_child(b)
	if not any:
		_line("교체 가능한 건이 스태시에 없다 (같은 역할 · 현재 착용분 제외).", DIM)


## ④ archetype/Role 필터 — 못 끼우는 건 **숨기지 않고 회색으로** 둔다. 안 보이면 "왜 없지"가 되고,
## 회색이면 "왜 안 되지"에 답할 수 있다. 사유는 오른쪽 끝에 글로 붙는다.
func _render_catalog() -> void:
	var gid := _gear_id()
	var h := Label.new()
	h.text = "④ 스킬 카탈로그 → [%s] 칸에 배치 (회색 = 조건 미충족)" % SLOT_KEY[_slot]
	h.add_theme_font_size_override("font_size", 14)
	h.modulate = ACCENT
	_right.add_child(h)
	var rows: Array = Slice01Data.get_skillbook_rows()
	var shown := 0
	for row in rows:
		var abid := String((row as Dictionary).get("base_ability_id", ""))
		if abid == "":
			continue
		# 다른 역할 전용은 아예 뺀다 — Role Gate는 "이 화면의 주제가 아님"이지 "조건 미충족"이 아니다.
		if not (row.get("equip_classes", []) as Array).has(_role):
			continue
		shown += 1
		var chk: Dictionary = _bp.slot_equip_check(_role, _slot, abid)
		var ok: bool = bool(chk.get("ok", false))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		_right.add_child(hb)
		var nm := Label.new()
		nm.text = String(row.get("display_name", abid))
		nm.custom_minimum_size = Vector2(150, 0)
		nm.add_theme_font_size_override("font_size", 12)
		hb.add_child(nm)
		var fam := Label.new()
		fam.text = "%s · %s · ◈%d" % [String(row.get("skill_family", "—")), String(row.get("tier", "—")),
				Slice01Data.manastone_cost_for(abid)]
		fam.custom_minimum_size = Vector2(190, 0)
		fam.add_theme_font_size_override("font_size", 11)
		fam.modulate = DIM
		hb.add_child(fam)
		var why := Label.new()
		why.text = "" if ok else _reason_text(String(chk.get("reason", "")))
		why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		why.add_theme_font_size_override("font_size", 11)
		why.modulate = BAD
		hb.add_child(why)
		var b := Button.new()
		b.text = "배치"
		b.disabled = not ok
		b.pressed.connect(func() -> void:
			_bp.equip_slot_ability(_role, _slot, abid)
			_reapply()
			_refresh())
		hb.add_child(b)
		if not ok:
			nm.modulate = Color(0.55, 0.55, 0.58)
			fam.modulate = Color(0.45, 0.45, 0.48)
	if shown == 0:
		var l := Label.new()
		l.text = "이 역할이 쓸 수 있는 스킬이 카탈로그에 없다."
		l.modulate = DIM
		_right.add_child(l)
	# 결속 미리보기는 슬롯 쪽에만 둔다 — 목록 전 항목에 붙이면 49줄이 전부 시끄러워진다.
	var note := Label.new()
	note.text = "\n건 %s 의 허용 계열: %s" % [gid,
			", ".join(Slice01Data.get_gear_master(gid).get("allowed_slot_families", ["(제한 없음)"]))]
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = DIM
	note.add_theme_font_size_override("font_size", 11)
	_right.add_child(note)


func _reason_text(reason: String) -> String:
	match reason:
		"no_gear": return "건 미착용"
		"slot":    return "이 칸이 아직 안 열렸다"
		"family":  return "이 건이 받지 않는 계열"
		"locked":  return "미해금 — 성소 트리에서 해금"
		"dup":     return "이미 다른 칸에 있음"
		_:         return "불가"


## ⑥ 마석·참 반입 요약 — 슬롯 스킬은 **마석이 없으면 한 발도 못 쏜다**. 빌드를 짜는 화면에서
## 연료 잔량이 안 보이면 "왜 시전이 안 되지"가 던전에서 터진다.
func _render_footer() -> void:
	var carry := 0
	var charms: Array = []
	if _bp != null:
		for it in _bp.loose:
			if typeof(it) != TYPE_DICTIONARY:
				continue
			match String(it.get("kind", "")):
				"manastone": carry += int(it.get("count", 0))
				"charm": charms.append(String(Slice01Data.get_charm(String(it.get("charm_id", ""))).get("display", "?")))
	var stash_ms: int = int(_stash.manastone_count()) if _stash != null else 0
	_foot.text = "⑥ 반입 마석 ◈%d  ·  보관 ◈%d  ·  반입 참: %s" % [carry, stash_ms,
			", ".join(charms) if not charms.is_empty() else "없음"]
	_foot.modulate = ACCENT if carry > 0 else BAD


# --- ⑤ 소멸 확인 모달 --------------------------------------------------------

## 되돌릴 수 없는 유일한 행동이라 **무엇을 잃는지 이름으로** 보여준다. "정말?"만 묻는 모달은
## 아무것도 막지 못한다.
func _confirm_swap(new_gid: String, inst: Dictionary = {}) -> void:
	var lost: Array = []
	for sd in _bp.gear_slot_abilities(_role):
		if typeof(sd) == TYPE_DICTIONARY:
			var abid := String(sd.get("base_ability_id", ""))
			lost.append(String(Slice01Data.get_skillbook_master(abid).get("display_name", abid)))
	if lost.is_empty():
		_do_swap(new_gid, inst)   # 잃을 게 없으면 굳이 묻지 않는다
		return
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(520, 0)
	cc.add_child(pc)
	var mg := MarginContainer.new()
	for sd2 in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		mg.add_theme_constant_override(sd2, 14)
	pc.add_child(mg)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	mg.add_child(vb)
	var t := Label.new()
	t.text = "건을 갈아끼우면 이 슬롯 스킬은 사라진다"
	t.add_theme_font_size_override("font_size", 16)
	t.modulate = BAD
	vb.add_child(t)
	var body := Label.new()
	body.text = "소멸: %s\n\n같은 스킬은 성소 트리 해금과 상점 재구매로 다시 얻을 수 있다(F-009 §3.9.3). 마석·참은 영향 없다." % ", ".join(lost)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 12)
	vb.add_child(body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var no := Button.new()
	no.text = "취소"
	no.pressed.connect(_close_modal)
	row.add_child(no)
	var yes := Button.new()
	yes.text = "소멸 감수하고 착용"
	yes.modulate = BAD
	yes.pressed.connect(func() -> void:
		_close_modal()
		_do_swap(new_gid, inst))
	row.add_child(yes)


func _close_modal() -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null


## 건은 **하나뿐인 물건**이다 — 스태시에서 꺼내 신고, 벗은 건 스태시로 돌려놓는다(굴림째로).
## 이 교환을 빼먹으면 착용할 때마다 건이 복제되고 소멸 경고가 무의미해진다.
func _do_swap(new_gid: String, inst: Dictionary = {}) -> void:
	var old_gid := _gear_id()
	var old_e: Dictionary = _entry()
	var lost: Array = _bp.set_member_gear(_role, new_gid, inst)   # 소멸은 여기서 일어난다(반환 = 잃은 목록)
	if _stash != null:
		_stash.remove_gear(new_gid)
		if old_gid != "":
			_stash.add_gear(old_gid, String(old_e.get("rolled_identity", "")),
					old_e.get("rolls", {}) if typeof(old_e.get("rolls", {})) == TYPE_DICTIONARY else {})
	if not lost.is_empty():
		print("[TDC] 건 교체 — %s 슬롯 AB 소멸: %s" % [_role, ", ".join(lost)])
	_reapply()
	_refresh()


## 저장분을 라이브 파티에 되먹인다 — 모딩 결과가 파티 시트/툴팁에 바로 보여야 "바꿨다"가 체감된다.
func _reapply() -> void:
	if party != null and _bp != null:
		_bp.apply_to_party(party)


func _head(text: String) -> void:
	var l := Label.new()
	l.text = "\n%s" % text
	l.add_theme_font_size_override("font_size", 14)
	l.modulate = ACCENT
	_left.add_child(l)


func _line(text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = col
	l.add_theme_font_size_override("font_size", 12)
	_left.add_child(l)
