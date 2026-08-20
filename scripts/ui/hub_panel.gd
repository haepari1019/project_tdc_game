extends Control
class_name HubPanel
## **허브 창 공용 뼈대** — 어둡게 깔기 / 가운데 창 / 제목줄(제목 · 상태 · 닫기) / 본문 / Esc.
##
## 이 여섯 줄이 화면 6개에 **복사돼 있었다**. 복사본은 조금씩 달라지고(창 크기·여백·닫기 문구),
## 그 차이가 곧 「건물마다 다른 게임 같다」는 인상이 된다. 여기로 모으면 새 건물을 만들 때
## 크롬을 다시 짤 일이 없고, 고치면 **전부** 고쳐진다.
##
## 쓰는 법: `extends HubPanel` → `_ready()`에서 `super()` 먼저 호출 → `body`(VBoxContainer)에 채운다.
## 제목은 `panel_title`, 우측 상태 문구는 `set_status()`.

signal closed

## 창 최소 크기 — 화면마다 다를 수 있으니 서브클래스가 `_ready` 전에 바꾼다.
var window_size := Vector2(880, 600)
var panel_title: String = ""

var body: VBoxContainer         # 서브클래스가 채우는 영역
var titlebar: HBoxContainer     # 제목 오른쪽에 버튼을 더 붙이고 싶을 때
var _status: Label
var _title_lbl: Label


func _ready() -> void:
	# ⚠️ **`set_anchors_preset`이 아니라 `set_anchors_and_offsets_preset`**이다. 전자는 앵커만 바꾸고
	# 오프셋은 「현재 사각형을 유지하도록」 재계산하는데, 갓 만든 컨트롤은 크기가 0이라 결과가
	# **전체 화면에 앵커된 0×0**이 된다. 그러면 안쪽 `CenterContainer`가 0폭 안에서 가운데를 잡아
	# 창이 통째로 **좌상단에 붙는다**(실제로 그랬다). 후자는 오프셋까지 0으로 놓아 부모를 채운다.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	theme = HubTheme.get_theme()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # 뒤쪽 마을 클릭 차단
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var win := PanelContainer.new()
	win.theme_type_variation = "HubWindow"
	win.custom_minimum_size = window_size
	center.add_child(win)

	var margin := MarginContainer.new()
	for sd in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(sd, HubTheme.PAD)
	win.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", HubTheme.GAP_M)
	margin.add_child(root)

	titlebar = HBoxContainer.new()
	titlebar.add_theme_constant_override("separation", HubTheme.GAP_M)
	root.add_child(titlebar)
	_title_lbl = HubTheme.label(panel_title, "HubTitle")
	titlebar.add_child(_title_lbl)
	_status = HubTheme.label("", "HubMeta")
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	titlebar.add_child(_status)
	var close := Button.new()
	close.text = "닫기 (Esc)"
	close.pressed.connect(close_panel)
	titlebar.add_child(close)

	var sep := HSeparator.new()
	root.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", HubTheme.GAP_S)
	scroll.add_child(body)


func set_title(text: String) -> void:
	panel_title = text
	if _title_lbl != null:
		_title_lbl.text = text


## 제목 오른쪽 한 줄 — 「이 건물의 지금 상태」(tier·재화 등). 창마다 자리가 다르면 눈이 헤맨다.
func set_status(text: String, col = null) -> void:
	if _status == null:
		return
	_status.text = text
	_status.add_theme_color_override("font_color", col if col != null else HubTheme.DIM)


func open_panel() -> void:
	visible = true
	refresh()


func close_panel() -> void:
	visible = false
	closed.emit()


## 서브클래스가 덮어쓴다 — 열릴 때와 상태가 바뀔 때 본문을 다시 그린다.
func refresh() -> void:
	pass


func clear_body() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()
