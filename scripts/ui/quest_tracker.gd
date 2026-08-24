extends Control
## **런 목표 트래커** (우상단, 미니맵 아래) + **의뢰 목록**(J 토글).
##
## 두 층을 갈랐다(사용자 판정: *「게임내 미니맵하단의 퀘스트 목록이 현재 퀘스트목록과 대응이 안됨.
## 단, 너무 길면 안좋으니, 아예 퀘스트확인키를 따로 두는게 더 나을듯」*).
##   · **상시** = 이 런에서 지금 해야 할 것(열쇠 → 봉인문 → 탈출). 화면을 계속 차지하므로 3줄.
##   · **J** = 마을에서 **맡은 의뢰**와 진행도. 개수가 늘어도 상시 패널을 밀어내지 않는다.
##
## 예전엔 상시 패널에 「Cell 회수 (0/6)」가 붙어 있었다. `Cell`이라는 아이템은 **이 게임에 없다** —
## 데모 시절 문자열이 남은 것이라 그 줄은 영원히 0/6이었고, 그게 「퀘스트 목록이 대응이 안 됨」의
## 절반이었다. 나머지 절반은 마을 의뢰가 여기 전혀 나오지 않던 것.
##
## 진행도는 `HubProfile.quest_progress()`가 판정한다 — **완료 판정과 같은 표**(`QUEST_RULES`)를
## 읽으므로 「목록엔 다 찼는데 완료가 안 된다」가 생길 수 없다.

const PANEL_W := 286.0
const PANEL_TOP := 178.0    # reserve minimap room above
const MARGIN_R := 12.0
const LIST_W := 380.0

var _inv: Node = null       # InventoryUI
var _run: Node = null       # RunController
var _rt: RichTextLabel = null
var _list_box: PanelContainer = null
var _list_rt: RichTextLabel = null
var _key_done := false       # latched once the key is obtained
var _hub: Node = null


## `key_id` = 이번 런의 열쇠(맵 문서 `entry_requirement.ref`). 비면 구 부분 문자열 매칭.
## 표시용이지만 **문과 같은 판정**을 써야 한다 — 안 그러면 「열쇠 획득 ✓인데 문이 안 열리는」 화면이 된다.
var key_id: String = ""


func setup(inv: Node, run: Node) -> void:
	_inv = inv
	_run = run


func _ready() -> void:
	_hub = get_node_or_null("/root/HubProfile")
	# Anchor a fixed panel to the top-right, offset down past the minimap space.
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -(PANEL_W + MARGIN_R)
	offset_right = -MARGIN_R
	offset_top = PANEL_TOP
	offset_bottom = PANEL_TOP + 128.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_TOP_WIDE)
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	var panel := _frame()
	col.add_child(panel)
	_rt = _label()
	panel.add_child(_rt)

	# 의뢰 목록 — 기본 숨김. **상시 패널 아래로** 자라므로 길어져도 목표를 가리지 않는다.
	_list_box = _frame()
	_list_box.visible = false
	_list_box.custom_minimum_size = Vector2(LIST_W, 0)
	col.add_child(_list_box)
	_list_rt = _label()
	_list_box.add_child(_list_rt)


func _frame() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08, 0.74)
	sb.border_color = Color(0.40, 0.43, 0.52, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	return panel


func _label() -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.add_theme_font_size_override("normal_font_size", 14)
	rt.add_theme_font_size_override("bold_font_size", 14)
	return rt


## J — 의뢰 목록 토글. `_unhandled_input`이라 인벤토리·모달이 먼저 먹으면 여기까지 오지 않는다.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_quests"):
		_list_box.visible = not _list_box.visible
		if _list_box.visible:
			_refresh_list()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _rt == null:
		return
	if _inv != null and _inv.backpack_has_key(key_id):
		_key_done = true
	var door_done: bool = _run != null and _run.objective_complete
	var extract_done: bool = _run != null and _run.run_over

	var t := "[b]이번 런 — 탈출[/b]\n"
	t += _line(_key_done, "열쇠 획득")
	t += _line(door_done, "봉인문 개방")
	t += _line(extract_done, "탈출 지점에서 탈출")
	t += "[color=#7b838d]────  [J] 맡은 의뢰 %d[/color]" % _accepted().size()
	_rt.text = t


## 마을에서 **수락했고 아직 안 끝난** 의뢰만. 미수락은 마을 장부의 일이지 런의 일이 아니다.
func _accepted() -> Array:
	var out: Array = []
	if _hub == null:
		return out
	for qid in Slice01Data.get_quests():
		var q := String(qid)
		if _hub.is_quest_accepted(q) and not _hub.is_quest_done(q):
			out.append(q)
	out.sort()
	return out


func _refresh_list() -> void:
	if _list_rt == null:
		return
	var quests: Dictionary = Slice01Data.get_quests()
	var ids: Array = _accepted()
	var t := "[b]맡은 의뢰[/b]   [color=#7b838d](J로 닫기)[/color]\n"
	if ids.is_empty():
		t += "[color=#8b95a0]맡은 의뢰가 없다 — 마을에서 건물을 눌러 받는다.[/color]"
		_list_rt.text = t
		return
	for qid in ids:
		var q: Dictionary = quests.get(qid, {})
		var pr: Dictionary = _hub.quest_progress(String(qid))
		var done: bool = bool(pr.get("done", false))
		var fac := String(q.get("facility", ""))
		t += "  [color=%s]%s[/color] [color=#d6dae0]%s[/color]\n" % [
			"#77cc88" if done else "#d8c14e", "✔" if done else "•", String(q.get("one_liner", qid))]
		# 진행도 줄 — 판정표가 아는 것만 숫자로. 모르면 의뢰 자체의 완료 문구를 그대로 보여준다.
		var detail := String(pr.get("text", ""))
		if detail == "":
			detail = String(q.get("completion", ""))
		t += "      [color=#8b95a0]%s  ·  %s[/color]\n" % [
			String(Slice01Data.get_facility_def(fac).get("display", fac)), detail]
	# 금고는 **탈출해야** 채워진다 — 재료 조건이 런 중에 안 오르는 이유를 여기서 밝힌다.
	t += "[color=#7b838d]재료 조건은 탈출에 성공해야 금고에 반영된다.[/color]"
	_list_rt.text = t


## One objective line: ✔ + strikethrough when done, • + bright when pending.
func _line(done: bool, label: String) -> String:
	if done:
		return "  [color=#77cc88]✔[/color] [s][color=#8b95a0]%s[/color][/s]\n" % label
	return "  [color=#d8c14e]•[/color] [color=#d6dae0]%s[/color]\n" % label
