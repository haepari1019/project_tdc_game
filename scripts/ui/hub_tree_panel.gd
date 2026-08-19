extends Control
## F-020 §3.10 스킬 트리 패널 (`chapel` · `UI-029` 건물 패널) — **분석 의뢰 UI의 후임**.
## 구 F-009는 「같은 책 3권 제출 → 해금」이었고(`F-009` §3.9.4에서 폐기), 이제는 **노드 클릭 = 해금**이다.
## 소비는 금고 재료(`hubVault`) — 시설 승급과 **같은 재료를 두고 경쟁**한다(`I-007` §14.6 sink 경쟁).
##
## 노드 4종(`Passive`는 CS-1에서 폐기):
##   `Slot`(gear 슬롯 +1) · `Unlock`(AB 모딩·구매 허용) · `Upgrade`(행동 발전) · `Doctrine`(파티 운용, `F-030`)
##
## **`Doctrine` 노드가 유일한 doctrine 구매 경로다** — 이 패널이 없으면 `DoctrineProfile`이 영원히
## 중립이라 `F-030`이 코드에만 있고 게임엔 없는 상태가 된다(CS-2 잔여였다).

const OK := Color(0.62, 1.0, 0.62)
const BAD := Color(1.0, 0.6, 0.55)
const DIM := Color(0.62, 0.62, 0.66)
const ACCENT := Color(1.0, 0.81, 0.42)

## 노드 유형별 색 — 트리에서 "무엇을 사는 중인가"가 한눈에 갈리게.
const TYPE_COLOR := {
	"Slot": Color(0.62, 0.86, 1.0), "Unlock": Color(0.70, 0.90, 0.70),
	"Upgrade": Color(1.0, 0.85, 0.45), "Doctrine": Color(0.85, 0.70, 1.0),
}
const TYPE_KO := {"Slot": "슬롯", "Unlock": "해금", "Upgrade": "발전", "Doctrine": "운용"}

signal closed

var _body: VBoxContainer
var _header: Label
@onready var _hub: Node = get_node_or_null("/root/HubProfile")
@onready var _doc: Node = get_node_or_null("/root/DoctrineProfile")


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
	win.custom_minimum_size = Vector2(760, 580)
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
	title.text = "성소 · 스킬 트리 (F-020 §3.10)"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 13)
	bar.add_child(_header)
	var close := Button.new()
	close.text = "닫기 (Esc)"
	close.pressed.connect(close_panel)
	bar.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 3)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)

	if _hub != null and _hub.has_signal("economy_changed"):
		_hub.economy_changed.connect(_refresh)


func open_panel() -> void:
	visible = true
	_refresh()


func close_panel() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if _body == null or _hub == null:
		return
	for c in _body.get_children():
		c.queue_free()
	var tier: int = int(_hub.facility_tier("chapel"))
	var uncapped: bool = bool(_hub.PLAYTEST_TREE_ALL_UNLOCKED)
	_header.text = "성소 T%d%s" % [tier, "  ·  (플테: 전 노드 해금)" if uncapped else ""]
	_header.modulate = ACCENT if tier >= 1 else BAD
	if tier < 1:
		_line("성소(chapel)가 아직 안 열렸다 — 트리 잠김. 허브 시설에서 승급하면 열린다.", BAD)
		_line("성소 T0 = doctrine 0 = **중립 성장**. 그 상태로도 클리어는 성립해야 한다(QA-032 §2.1).", DIM)
	for cls in ["Tank", "DPS", "Nuker", "Healer"]:
		var rows: Array = Slice01Data.tree_nodes_for_class(cls)
		if rows.is_empty():
			continue
		_line("\n── %s ──" % Slice01Data.get_role_label(cls), ACCENT)
		for row in rows:
			_node_row(row, cls)


func _node_row(row: Dictionary, cls: String) -> void:
	var nid := String(row.get("node_id", ""))
	var ty := String(row.get("type", ""))
	var bought: bool = bool(_hub.tree_unlocked.get(nid, false))
	var chk: Dictionary = _hub.tree_check(nid)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	_body.add_child(hb)

	var tag := Label.new()
	tag.text = "[%s]" % TYPE_KO.get(ty, ty)
	tag.custom_minimum_size = Vector2(52, 0)
	tag.modulate = TYPE_COLOR.get(ty, DIM)
	tag.add_theme_font_size_override("font_size", 12)
	hb.add_child(tag)

	var name_l := Label.new()
	name_l.text = String(row.get("display_name", nid))
	name_l.custom_minimum_size = Vector2(130, 0)
	name_l.add_theme_font_size_override("font_size", 13)
	hb.add_child(name_l)

	var desc := Label.new()
	desc.text = String(row.get("desc", ""))
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.modulate = DIM
	desc.add_theme_font_size_override("font_size", 12)
	hb.add_child(desc)

	var cost_l := Label.new()
	cost_l.text = _cost_text(row.get("cost", {}))
	cost_l.custom_minimum_size = Vector2(150, 0)
	cost_l.add_theme_font_size_override("font_size", 12)
	cost_l.modulate = OK if bool(chk.get("ok", false)) else DIM
	hb.add_child(cost_l)

	if bought:
		var got := Label.new()
		got.text = "✔ 해금"
		got.custom_minimum_size = Vector2(96, 0)
		got.modulate = OK
		hb.add_child(got)
		# Doctrine 노드는 구매만으로 끝이 아니다 — **활성은 별도**(Identity당 1개, 재배치 자유·환불 없음).
		if ty == "Doctrine" and _doc != null:
			var did := String(row.get("doctrine_id", ""))
			var on: bool = String(_doc.active.get(cls, "")) == did
			var act := Button.new()
			act.text = "활성 해제" if on else "활성"
			act.modulate = ACCENT if on else Color(1, 1, 1)
			act.pressed.connect(func() -> void:
				_doc.set_active(cls, "" if on else did)
				_refresh())
			hb.add_child(act)
	else:
		var buy := Button.new()
		buy.text = "구매"
		buy.custom_minimum_size = Vector2(96, 0)
		buy.disabled = not bool(chk.get("ok", false))
		buy.tooltip_text = _reason_text(String(chk.get("reason", "")))
		buy.pressed.connect(func() -> void:
			_hub.tree_buy(nid)
			_refresh())
		hb.add_child(buy)


func _cost_text(cost: Dictionary) -> String:
	if cost.is_empty():
		return "무료"
	var parts: Array = []
	for m in cost:
		var have: int = int(_hub.vault_count(String(m)))
		var need := int(cost[m])
		parts.append("%s %d/%d" % [Slice01Data.get_haul_material(String(m)).get("display", m), have, need])
	return " · ".join(parts)


## 거부 사유를 **말로** 돌려준다 — 비활성 버튼만 있고 이유가 없으면 "왜 못 사지"가 남는다.
func _reason_text(reason: String) -> String:
	match reason:
		"facility": return "성소(chapel) T1 필요 — 허브 시설에서 승급"
		"prereq":   return "선행 노드를 먼저 해금해야 한다"
		"haul":     return "금고 재료 부족 — 런에서 회수해 입금"
		"already":  return "이미 해금됨 (환불 없음 — F-030 §3.2)"
		_:          return ""


func _line(text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = col
	l.add_theme_font_size_override("font_size", 12)
	_body.add_child(l)
