extends Control
## UI-029 Hub Map (시설 progression) — 시설을 골라 다음 Tier 요구(QuestGate + HaulGate)를 보고,
## 충족 시 승급한다. 승급 규칙·소모는 HubProfile(D-029 §5). 데이터는 Slice01Data. ref: F-029.
## 재료는 읽기 전용 표시(보유/필요) — 무료 ±/채우기 제거(런 회수 → '재료 모두 금고로'로만 적재).
## 충족 가능 퀘스트는 자동완료(B4-lite).

const FACILITY_ORDER := ["barracks", "stash", "scriptorium", "scribe_shop", "armory", "quartermaster", "smithy", "chapel"]
const OK := Color(0.62, 1.0, 0.62)
const BAD := Color(1.0, 0.6, 0.55)
const DIM := Color(0.75, 0.75, 0.78)

var _list: VBoxContainer
var _detail: VBoxContainer
var _vault: Label
var _sel: String = "stash"
# Runtime path (not the parse-time global) so a stale editor that hasn't re-registered the
# newly-added HubProfile autoload still compiles + runs. (Same pattern as main.gd Stash/RunLoadout.)
@onready var _hub: Node = get_node_or_null("/root/HubProfile")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)   # 진하게 — 뒤 허브 UI가 비쳐 겹쳐 보이지 않도록
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var win := PanelContainer.new()
	win.custom_minimum_size = Vector2(820, 560)
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
	var sep := VSeparator.new()
	body.add_child(sep)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 4)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_detail)

	_vault = Label.new()
	_vault.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vault.modulate = DIM
	root.add_child(_vault)

	if _hub != null and _hub.has_signal("facilities_changed"):
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
	if not visible or _hub == null:
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
		if not done:
			_lbl("    조건: %s" % String(qr.get("completion", "?")), DIM)   # 완료 방법 표시(사용자: 퀘스트 내용 불명)
	# haul gate — 선택 시설 요구 재료 vs 보유(금고). 읽기 전용: 재료는 런에서 회수 → '재료 모두 금고로'로
	# 적재해야 채워진다(여기서 무료로 +/채우기 금지 — 사용자 지적). have/need만 표시.
	var haul: Dictionary = nxt.get("haul", {})
	if not haul.is_empty():
		_lbl("  필요 재료 (금고 보유 / 필요):", DIM)
	for hid in haul:
		var id: String = hid
		var need: int = int(haul[id])
		var have: int = _hub.vault_count(id)
		var hm: Dictionary = Slice01Data.get_haul_material(id)
		_lbl("    %s  %d / %d" % [String(hm.get("display", id)), have, need], OK if have >= need else BAD)
	# upgrade
	var up := Button.new()
	up.text = "승급" if bool(chk.get("ok", false)) else "승급 불가"
	up.disabled = not bool(chk.get("ok", false))
	up.pressed.connect(func() -> void: _hub.attempt_upgrade(_sel))  # → facilities_changed → _refresh
	_detail.add_child(up)


func _refresh_vault() -> void:
	var v: Dictionary = _hub.hub_haul_vault
	if v.is_empty():
		_vault.text = "Vault (Safe): (비어있음)   ·   실전은 던전 haul 회수 → 탈출 시 적재"
		return
	var parts: Array = []
	for hid in v:
		parts.append("%s×%d" % [String(Slice01Data.get_haul_material(String(hid)).get("display", hid)), int(v[hid])])
	_vault.text = "Vault (Safe): " + "   ".join(parts)


func _lbl(text: String, col: Color, font_sz: int = 0) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = col
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_sz > 0:
		l.add_theme_font_size_override("font_size", font_sz)
	_detail.add_child(l)
