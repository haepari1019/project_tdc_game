extends Control
## 퀘스트 로그 (F-029 §3.3) — 허브 승급 퀘스트(Q-HUB-*) 전체를 상태(✓/✗) + 완료 조건과 함께 보여주는
## 풀스크린 오버레이. 시설 패널에 인라인으로만 보이던 퀘스트를 한곳에 모아 "뭘 해야 열리는지" 확인용.
## 데이터 = Slice01Data.get_quests() · 완료 상태 = HubProfile.quest_completed.

const OK := Color(0.62, 1.0, 0.62)
const BAD := Color(1.0, 0.6, 0.55)
const DIM := Color(0.74, 0.74, 0.78)
const HEAD := Color(0.70, 0.85, 1.0)

var _list: VBoxContainer
@onready var _hub: Node = get_node_or_null("/root/HubProfile")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var win := PanelContainer.new()
	win.custom_minimum_size = Vector2(720, 560)
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
	title.text = "퀘스트 (허브 승급 의뢰)"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titlebar.add_child(title)
	var close := Button.new()
	close.text = "닫기 (Esc)"
	close.pressed.connect(close_panel)
	titlebar.add_child(close)

	var hint := Label.new()
	hint.text = "각 시설(필기소/상점/무기고 등)은 아래 퀘스트 + 재료를 채우면 '허브 시설'에서 승급해 열린다."
	hint.modulate = DIM
	hint.add_theme_font_size_override("font_size", 12)
	root.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


func open_panel() -> void:
	visible = true
	_refresh()


func close_panel() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if not visible:
		return
	if _hub != null and _hub.has_method("evaluate_quests"):
		_hub.evaluate_quests()   # 자동평가형(재료/시설Tier 등) 갱신 후 표시
	for c in _list.get_children():
		c.queue_free()
	var quests: Dictionary = Slice01Data.get_quests()
	var pending: Array = []
	var done: Array = []
	for qid in quests:
		if _hub != null and _hub.is_quest_done(String(qid)):
			done.append(String(qid))
		else:
			pending.append(String(qid))
	pending.sort()
	done.sort()

	_header("── 진행 중 (%d) ──" % pending.size())
	if pending.is_empty():
		_lbl("  모든 퀘스트 완료!", DIM)
	for qid in pending:
		_quest_row(qid, quests[qid], false)
	_header("\n── 완료 (%d) ──" % done.size())
	for qid in done:
		_quest_row(qid, quests[qid], true)


func _quest_row(qid: String, q: Dictionary, is_done: bool) -> void:
	var fac := String(q.get("facility", ""))
	var tier := int(q.get("tier", 0))
	var mark := "✓" if is_done else "✗"
	_lbl("%s  %s · %s T%d — %s" % [mark, qid, fac, tier, String(q.get("one_liner", ""))], OK if is_done else BAD)
	if not is_done:
		_lbl("        조건: %s" % String(q.get("completion", "?")), DIM)


func _header(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = HEAD
	_list.add_child(l)


func _lbl(text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = col
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(l)
