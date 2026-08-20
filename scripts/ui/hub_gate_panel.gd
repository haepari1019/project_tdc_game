extends HubPanel
## **성문 — 출정.** 나가기 직전에 정하는 것만 모은다: **포메이션**과 **반입 확인**, 그리고 출정.
##
## `UI-005` §3 「배치」의 자리이며 `F-029` `barracks`가 이 건물이다. 마을의 다른 건물이 **준비**를
## 다룬다면 여기는 **떠남**을 다룬다 — 성문을 지나면 되돌아올 수 없다는 게 요점이라, 되돌릴 수
## 없는 확인(첫 런 게이트·빈 슬롯 경고)이 여기 모여 있다.
##
## **난이도 선택은 없다**(M6). 지역·입장조건이 그 축을 가져가기로 했고, 그때까지는 manifest
## 기본값을 쓴다 — `RunLoadout.get_difficulty()`가 폴백을 이미 갖고 있어 코드는 손대지 않았다.

const FormationEditor := preload("res://scripts/ui/inventory/formation_editor.gd")
const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")
const ROLES := ["Tank", "DPS", "Nuker", "Healer"]
const SLOT_KEY := ["Q", "E", "R"]

signal deploy_requested

var party: Node = null

var _formation: Panel
var _carry: VBoxContainer
var _gate_lbl: Label
var _start: Button
var _warned_empty: bool = false   # 빈 슬롯 경고는 세션당 1회 — 매번 물으면 확인창이 소음이 된다

@onready var _bp: Node = get_node_or_null("/root/Backpack")
@onready var _hub: Node = get_node_or_null("/root/HubProfile")


func _ready() -> void:
	window_size = Vector2(860, 560)
	panel_title = "성문 — 출정"
	super()
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", HubTheme.GAP_L)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)

	var lc := VBoxContainer.new()
	lc.add_theme_constant_override("separation", HubTheme.GAP_S)
	cols.add_child(lc)
	lc.add_child(HubTheme.section("포메이션"))
	_formation = FormationEditor.new()
	_formation.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lc.add_child(_formation)
	lc.add_child(HubTheme.para("토큰 드래그로 배치 · 중앙 = 앵커\n허용 반경 = party_range_m (8.0m)", "HubMeta", null, 230))

	cols.add_child(VSeparator.new())
	var rc := VBoxContainer.new()
	rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rc.add_theme_constant_override("separation", HubTheme.GAP_S)
	cols.add_child(rc)
	rc.add_child(HubTheme.section("반입 확인"))
	_carry = VBoxContainer.new()
	_carry.add_theme_constant_override("separation", 2)
	_carry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rc.add_child(_carry)

	body.add_child(HubTheme.grow())
	_gate_lbl = HubTheme.para("", "", null, 600)
	body.add_child(_gate_lbl)
	_start = Button.new()
	_start.text = "성문을 나선다 (DBP-DEMO-001)"
	_start.custom_minimum_size = Vector2(0, 44)
	_start.pressed.connect(_on_start_pressed)
	body.add_child(_start)


func open_panel() -> void:
	_setup_formation()
	super()


## 포메이션 토큰은 **열 때마다** 파티 슬롯 오프셋에서 다시 세운다 — 마을에서 건을 갈아 구성이
## 바뀌었을 수 있고, 열어서 보이는 것이 곧 나갈 때 쓰이는 값이어야 한다.
func _setup_formation() -> void:
	if party == null or not party.has_method("get_members"):
		return
	var offsets: Dictionary = {}
	var colors: Dictionary = {}
	for m in party.get_members():
		if m == null or not is_instance_valid(m):
			continue
		var cid := String(m.class_id)
		var o3: Vector3 = party.get_slot_offset(cid)
		offsets[cid] = Vector2(o3.x, o3.z)
		colors[cid] = UnitVisuals.role_color(cid)
	_formation.setup(offsets, colors)


## 반입 확인 — **던전에 들고 가는 것만**. 창고 보관분은 여기 안 적는다: 나가는 문 앞에서 알아야 할
## 것은 「지금 가방에 뭐가 있나」뿐이고, 보관분을 섞으면 있는 줄 알고 나가게 된다.
func refresh() -> void:
	if _carry == null:
		return
	for c in _carry.get_children():
		_carry.remove_child(c)
		c.queue_free()
	var ms := 0
	var charms: Array = []
	var consum := 0
	if _bp != null:
		for it in _bp.loose:
			if typeof(it) != TYPE_DICTIONARY:
				continue
			match String(it.get("kind", "")):
				"manastone":
					ms += int(it.get("count", 0))
				"charm":
					charms.append(String(Slice01Data.get_charm(String(it.get("charm_id", ""))).get("display", "?")))
				"consumable":
					consum += int(it.get("count", 1))
	var g := HubTheme.grid(2)
	_carry.add_child(g)
	g.add_child(HubTheme.label("마석", "HubMeta"))
	g.add_child(HubTheme.label("◈ %d" % ms, "", HubTheme.ACCENT if ms > 0 else HubTheme.BAD))
	g.add_child(HubTheme.label("참", "HubMeta"))
	g.add_child(HubTheme.label(", ".join(charms) if not charms.is_empty() else "없음", "HubMeta"))
	g.add_child(HubTheme.label("소모품", "HubMeta"))
	g.add_child(HubTheme.label("%d개" % consum, "HubMeta"))
	if ms == 0:
		_carry.add_child(HubTheme.para("마석이 없으면 슬롯 스킬을 한 번도 못 쓴다 — 창고에서 꺼내 오자.",
			"HubMeta", HubTheme.BAD, 380))

	_carry.add_child(HubTheme.spacer())
	var sg := HubTheme.grid(2)
	_carry.add_child(sg)
	for role in ROLES:
		sg.add_child(HubTheme.label(Slice01Data.get_role_label(role), "HubMeta"))
		var sl := HubTheme.label(_slot_summary(role), "HubMeta", HubTheme.TEXT)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sg.add_child(sl)

	var chk := deploy_check()
	var ok: bool = bool(chk.get("ok", false))
	_start.disabled = not ok
	_gate_lbl.text = String(chk.get("msg", ""))
	_gate_lbl.add_theme_color_override("font_color", HubTheme.OK if ok else HubTheme.BAD)
	set_status("첫 런" if (_hub != null and bool(_hub.is_first_run())) else "", HubTheme.ACCENT)


func _slot_summary(role: String) -> String:
	if _bp == null:
		return ""
	var open_n: int = int(_bp.gear_slot_count(role))
	var slots: Array = _bp.gear_slot_abilities(role)
	var parts: Array = []
	for j in 3:
		if j >= open_n:
			continue
		var sd = slots[j]
		if typeof(sd) != TYPE_DICTIONARY:
			parts.append("%s —" % SLOT_KEY[j])
			continue
		var abid := String(sd.get("base_ability_id", ""))
		parts.append("%s %s ◈%d" % [SLOT_KEY[j],
			String(Slice01Data.get_skillbook_master(abid).get("display_name", abid)),
			Slice01Data.manastone_cost_for(abid)])
	return "  ·  ".join(parts) if not parts.is_empty() else "슬롯 없음"


## `F-020` §3.2.0 — **첫 런은 역할당 슬롯 ≥1**이 아니면 못 나간다(빈손으로 나가면 슬롯 스킬이라는
## 축을 한 번도 못 만난 채 첫 인상이 굳는다). 이후 런은 **경고만** — 비워 두는 것도 선택이다.
func deploy_check() -> Dictionary:
	if _bp == null:
		return {"ok": false, "msg": "가방을 찾을 수 없다."}
	var no_gear: Array = []
	var empty: Array = []
	for role in ROLES:
		if String(_bp.member_entry(role).get("gear", "")) == "":
			no_gear.append(Slice01Data.get_role_label(role))
			continue
		var filled := 0
		for sd in _bp.gear_slot_abilities(role):
			if typeof(sd) == TYPE_DICTIONARY:
				filled += 1
		if filled == 0:
			empty.append(Slice01Data.get_role_label(role))
	if not no_gear.is_empty():
		return {"ok": false, "msg": "건 미착용: %s — 건이 곧 정체성이라 없이는 나갈 수 없다." % ", ".join(no_gear)}
	var first: bool = _hub == null or bool(_hub.is_first_run())
	if first and not empty.is_empty():
		return {"ok": false, "msg": "첫 런 — 역할당 슬롯 스킬 ≥1 필요 (F-020 §3.2.0): %s" % ", ".join(empty)}
	if not empty.is_empty():
		return {"ok": true, "msg": "⚠ 빈 슬롯: %s — 그대로 나갈 수 있다(경고)." % ", ".join(empty)}
	return {"ok": true, "msg": "출정 준비 완료."}


func get_formation_offsets() -> Dictionary:
	return _formation.get_offsets() if _formation != null else {}


func _on_start_pressed() -> void:
	var chk := deploy_check()
	if not bool(chk.get("ok", false)):
		return
	# 빈 슬롯 경고는 **비차단**이지만 한 번은 묻는다(`F-020` §3.2.0 「이후 런은 경고」).
	if String(chk.get("msg", "")).begins_with("⚠") and not _warned_empty:
		_warned_empty = true
		var dlg := ConfirmationDialog.new()
		dlg.title = "빈 슬롯"
		dlg.dialog_text = "%s\n\n슬롯 스킬 없이 들어가면 정체성(자동)과 평타만으로 싸운다.\n그대로 나설까?" % String(chk["msg"]).substr(2)
		dlg.ok_button_text = "그대로 나선다"
		dlg.cancel_button_text = "취소"
		add_child(dlg)
		dlg.confirmed.connect(func() -> void: deploy_requested.emit())
		dlg.canceled.connect(dlg.queue_free)
		dlg.popup_centered()
		return
	deploy_requested.emit()
