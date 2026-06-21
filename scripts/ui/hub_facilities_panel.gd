extends Control
## UI-029 Hub Map (시설 progression) — 시설을 골라 다음 Tier 요구(QuestGate + HaulGate)를 보고,
## 충족 시 승급한다. 승급 규칙·소모는 HubProfile(D-029 §5). 데이터는 Slice01Data. ref: F-029.
## 데모 편의: vault 재료 지급 버튼(dev) + 충족 가능 퀘스트 자동완료(_hub.evaluate_quests, B4-lite).

const FACILITY_ORDER := ["barracks", "stash", "scriptorium", "scribe_shop", "armory", "quartermaster", "smithy", "chapel"]
const OK := Color(0.62, 1.0, 0.62)
const BAD := Color(1.0, 0.6, 0.55)
const DIM := Color(0.75, 0.75, 0.78)

var _list: VBoxContainer
var _detail: VBoxContainer
var _vault: Label
var _sel: String = "stash"
var _haul_editor: Control = null   # 재료 편집(테스트) 오버레이 (lazy)
var _haul_rows: VBoxContainer = null
# Runtime path (not the parse-time global) so a stale editor that hasn't re-registered the
# newly-added HubProfile autoload still compiles + runs. (Same pattern as main.gd Stash/RunLoadout.)
@onready var _hub: Node = get_node_or_null("/root/HubProfile")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # block clicks to the hub behind
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var win := PanelContainer.new()
	win.custom_minimum_size = Vector2(780, 540)
	center.add_child(win)
	var margin := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 16)
	win.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var titlebar := HBoxContainer.new()
	root.add_child(titlebar)
	var title := Label.new()
	title.text = "허브 시설 (F-029)"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titlebar.add_child(title)
	var close := Button.new()
	close.text = "닫기 (Esc)"
	close.pressed.connect(close_panel)
	titlebar.add_child(close)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(240, 0)
	body.add_child(_list)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_detail)

	_vault = Label.new()
	_vault.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_vault)

	var devrow := HBoxContainer.new()
	root.add_child(devrow)
	var edit_haul := Button.new()
	edit_haul.text = "재료 편집 (테스트)"
	edit_haul.pressed.connect(_open_haul_editor)
	devrow.add_child(edit_haul)
	var hint := Label.new()
	hint.text = "  (실전: 던전 haul 회수 → 탈출 시 vault 적재)"
	hint.modulate = DIM
	devrow.add_child(hint)

	if _hub.has_signal("facilities_changed"):
		_hub.facilities_changed.connect(_refresh)
		_hub.vault_changed.connect(_refresh)


func open_panel() -> void:
	visible = true
	_refresh()


func close_panel() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


## Rebuild the facility list + detail + vault. Evaluates tractable quests first (B4-lite).
func _refresh() -> void:
	if not visible:
		return
	if _hub.has_method("evaluate_quests"):
		_hub.evaluate_quests()
	for c in _list.get_children():
		c.queue_free()
	for fid in FACILITY_ORDER:
		var def: Dictionary = Slice01Data.get_facility_def(fid)
		if def.is_empty():
			continue
		var tier: int = _hub.facility_tier(fid)
		var chk: Dictionary = _hub.upgrade_check(fid)
		var state := "MAX"
		var col := DIM
		if String(chk.get("reason", "")) != "max":
			state = "승급가능" if bool(chk.get("ok", false)) else "잠김"
			col = OK if bool(chk.get("ok", false)) else BAD
		var btn := Button.new()
		btn.text = "%s   T%d   [%s]" % [String(def.get("display", fid)), tier, state]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_color_override("font_color", col)
		var f: String = fid
		btn.pressed.connect(func() -> void:
			_sel = f
			_refresh_detail())
		_list.add_child(btn)
	_refresh_detail()
	_refresh_vault()
	if _haul_editor != null and _haul_editor.visible:
		_refresh_haul_editor()


func _refresh_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var def: Dictionary = Slice01Data.get_facility_def(_sel)
	if def.is_empty():
		return
	var tier: int = _hub.facility_tier(_sel)
	var cur: Dictionary = Slice01Data.get_facility_tier(_sel, tier)
	_lbl("%s — 현재 T%d" % [String(def.get("display", _sel)), tier], DIM, 18)
	_lbl("  %s" % String(cur.get("effect", "")), DIM)
	var chk: Dictionary = _hub.upgrade_check(_sel)
	if String(chk.get("reason", "")) == "max":
		_lbl("\n최대 단계", DIM)
		return
	var nt: int = int(chk.get("next_tier", tier + 1))
	var nxt: Dictionary = Slice01Data.get_facility_tier(_sel, nt)
	_lbl("\n→ T%d: %s" % [nt, String(nxt.get("effect", ""))], DIM, 16)
	# prereq
	if nxt.has("prereq"):
		for pid in nxt.get("prereq", {}):
			var need_t: int = int(nxt["prereq"][pid])
			var have_t: int = _hub.facility_tier(String(pid))
			_lbl("  선행: %s T%d 이상 (현재 T%d)" % [String(pid), need_t, have_t], OK if have_t >= need_t else BAD)
	# quest gate
	var q := String(nxt.get("quest", ""))
	if q != "":
		var done: bool = _hub.is_quest_done(q)
		var qr: Dictionary = Slice01Data.get_quest(q)
		_lbl("  퀘스트 %s %s — %s" % [q, ("✓" if done else "✗"), String(qr.get("one_liner", ""))], OK if done else BAD)
	# haul gate
	for hid in nxt.get("haul", {}):
		var need: int = int(nxt["haul"][hid])
		var have: int = _hub.vault_count(String(hid))
		var hm: Dictionary = Slice01Data.get_haul_material(String(hid))
		_lbl("  재료 %s  %d / %d" % [String(hm.get("display", hid)), have, need], OK if have >= need else BAD)
	# upgrade button
	var up := Button.new()
	up.text = "승급" if bool(chk.get("ok", false)) else "승급 불가"
	up.disabled = not bool(chk.get("ok", false))
	up.pressed.connect(func() -> void: _hub.attempt_upgrade(_sel))  # → facilities_changed → _refresh
	_detail.add_child(up)


func _refresh_vault() -> void:
	var v: Dictionary = _hub.hub_haul_vault
	if v.is_empty():
		_vault.text = "Vault (Safe): (비어있음)"
		return
	var parts: Array = []
	for hid in v:
		parts.append("%s×%d" % [String(Slice01Data.get_haul_material(String(hid)).get("display", hid)), int(v[hid])])
	_vault.text = "Vault (Safe): " + "   ".join(parts)


## 재료 편집(테스트) 오버레이 — 각 재료를 넣다/빼기. 스태시 편집처럼 별도 창으로 열린다.
func _open_haul_editor() -> void:
	if _haul_editor == null:
		_build_haul_editor()
	_haul_editor.visible = true
	_refresh_haul_editor()


func _build_haul_editor() -> void:
	_haul_editor = Control.new()
	_haul_editor.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_haul_editor)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_haul_editor.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_haul_editor.add_child(cc)
	var win := PanelContainer.new()
	win.custom_minimum_size = Vector2(560, 500)
	cc.add_child(win)
	var mg := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		mg.add_theme_constant_override(s, 16)
	win.add_child(mg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	mg.add_child(v)
	var tb := HBoxContainer.new()
	v.add_child(tb)
	var t := Label.new()
	t.text = "재료 편집 (테스트)"
	t.add_theme_font_size_override("font_size", 18)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb.add_child(t)
	var fill := Button.new()
	fill.text = "필요량까지 채움"
	fill.pressed.connect(_haul_fill_all)
	tb.add_child(fill)
	var cl := Button.new()
	cl.text = "닫기"
	cl.pressed.connect(func() -> void: _haul_editor.visible = false)
	tb.add_child(cl)
	var note := Label.new()
	note.text = "넣다/빼기 — 각 재료는 '필요량'(최대 단일 요구)까지만 채워집니다. 실전 vault는 던전 회수로 채움."
	note.modulate = DIM
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	_haul_rows = VBoxContainer.new()
	_haul_rows.add_theme_constant_override("separation", 4)
	v.add_child(_haul_rows)


func _refresh_haul_editor() -> void:
	if _haul_rows == null:
		return
	for c in _haul_rows.get_children():
		c.queue_free()
	for hid in Slice01Data.get_haul_material_ids():
		var id: String = hid
		var cap: int = _max_needed(id)
		var have: int = _hub.vault_count(id)
		var row := HBoxContainer.new()
		var nm := Label.new()
		nm.text = String(Slice01Data.get_haul_material(id).get("display", id))
		nm.custom_minimum_size = Vector2(130, 0)
		row.add_child(nm)
		var minus := Button.new()
		minus.text = "−"
		minus.custom_minimum_size = Vector2(36, 0)
		minus.disabled = have <= 0
		minus.pressed.connect(_hub.remove_haul.bind(id, 1))
		row.add_child(minus)
		var cnt := Label.new()
		cnt.text = "%d / %d" % [have, cap]
		cnt.custom_minimum_size = Vector2(80, 0)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.modulate = OK if have >= cap else DIM
		row.add_child(cnt)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(36, 0)
		plus.disabled = have >= cap   # 필요량 이상으로는 안 들어감
		plus.pressed.connect(_haul_inc.bind(id, cap))
		row.add_child(plus)
		_haul_rows.add_child(row)


## +1, but never above the material's max single requirement (cap).
func _haul_inc(id: String, cap: int) -> void:
	if _hub.vault_count(id) < cap:
		_hub.add_haul(id, 1)


## Top every material up to its cap (idempotent — repeated presses don't overfill).
func _haul_fill_all() -> void:
	for hid in Slice01Data.get_haul_material_ids():
		var id: String = hid
		var deficit: int = _max_needed(id) - _hub.vault_count(id)
		if deficit > 0:
			_hub.add_haul(id, deficit)


## A material's '필요량' = the largest single haul requirement across all facility tiers (so you can
## afford the most demanding single upgrade, but the test grant never piles past it).
func _max_needed(id: String) -> int:
	var m := 0
	for fid in FACILITY_ORDER:
		for t in Slice01Data.get_facility_def(fid).get("tiers", []):
			var need: int = int((t as Dictionary).get("haul", {}).get(id, 0))
			if need > m:
				m = need
	return maxi(m, 1)


func _lbl(text: String, col: Color, size: int = 0) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = col
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	_detail.add_child(l)
