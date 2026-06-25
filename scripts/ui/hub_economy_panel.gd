extends Control
## F-009 §3.5 / UI-029 — 스킬북 분석·상점 패널. ① 분석: 스태시 보유 책을 의뢰 제출(소멸) → progress
## N=3 → 상점 해금. ② 상점: 해금된 base의 생본(affix 없음)을 ward_scrap로 구매 → 스태시. 게이트:
## scriptorium T1 = 분석, scribe_shop Tier = 구매 tier 상한. 규칙·통화 = HubProfile. ref: F-009 · D-018 §7.1.

const OK := Color(0.62, 1.0, 0.62)
const BAD := Color(1.0, 0.6, 0.55)
const DIM := Color(0.75, 0.75, 0.78)
const SHOP_TIER := "Basic"   # 데모 상점은 Basic 생본 판매(Adv/Master는 loot; per-AB tier 데이터 후속)

var _scrap_lbl: Label
var _analysis_box: VBoxContainer
var _shop_box: VBoxContainer
# Runtime path (parse-time global 회피 — 새 autoload 미등록 에디터에서도 컴파일). main.gd 패턴.
@onready var _hub: Node = get_node_or_null("/root/HubProfile")
@onready var _stash: Node = get_node_or_null("/root/Stash")


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
	win.custom_minimum_size = Vector2(760, 560)
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
	title.text = "필기소 · 상점 (F-009)"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titlebar.add_child(title)
	_scrap_lbl = Label.new()
	_scrap_lbl.add_theme_font_size_override("font_size", 16)
	titlebar.add_child(_scrap_lbl)
	var close := Button.new()
	close.text = "닫기 (Esc)"
	close.pressed.connect(close_panel)
	titlebar.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	_header(col, "── 분석 / 중복 처리 (의뢰 N=3 → 해금 · 분해/매각 → ward_scrap) ──")
	_analysis_box = VBoxContainer.new()
	_analysis_box.add_theme_constant_override("separation", 2)
	col.add_child(_analysis_box)
	_header(col, "\n── 상점 (해금 base 생본 구매) ──")
	_shop_box = VBoxContainer.new()
	_shop_box.add_theme_constant_override("separation", 2)
	col.add_child(_shop_box)

	if _hub != null and _hub.has_signal("economy_changed"):
		_hub.economy_changed.connect(_refresh)


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
	if not visible or _hub == null:
		return
	_scrap_lbl.text = "ward_scrap: %d" % int(_hub.scrap())
	_scrap_lbl.modulate = OK if int(_hub.scrap()) > 0 else DIM
	_refresh_analysis()
	_refresh_shop()


## Owned (stash) skillbooks → 의뢰 버튼. 게이트: scriptorium T1. 해금된 base는 '해금됨' 표시(거부).
func _refresh_analysis() -> void:
	for c in _analysis_box.get_children():
		c.queue_free()
	var can: bool = _hub.has_method("can_analyze") and _hub.can_analyze()
	if not can:
		_lbl(_analysis_box, "  필기소(scriptorium) Tier 1 필요 — 허브 시설에서 승급.", BAD)
		return
	if _stash == null:
		return
	var counts: Dictionary = {}
	for b in _stash.skillbooks:
		var bid := String(b.get("base_ability_id", "")) if typeof(b) == TYPE_DICTIONARY else String(b)
		counts[bid] = int(counts.get(bid, 0)) + 1
	if counts.is_empty():
		_lbl(_analysis_box, "  스태시에 분석할 스킬북 없음 — 던전에서 회수해 스태시에 보관.", DIM)
		return
	for base in counts:
		var m: Dictionary = Slice01Data.get_skillbook_master(String(base))
		var disp: String = String(m.get("display_name", base))
		var row := HBoxContainer.new()
		var b: String = String(base)
		if _hub.is_shop_unlocked(b):
			_lbl(row, "%s — 보유 %d · 해금됨 ✓" % [disp, int(counts[base])], OK)
		else:
			var p: int = _hub.analysis_count(b)
			_lbl(row, "%s — 보유 %d · 분석 %d/%d" % [disp, int(counts[base]), p, int(_hub.ANALYSIS_REQUIRED)], DIM)
			var btn := Button.new()
			btn.text = "분석 의뢰 (책 1권 소멸)"
			btn.pressed.connect(func() -> void: _on_analyze(b))
			row.add_child(btn)
		# D-018 §7.5 중복 sink — 해금됨=분해(+8), 미해금=매각(+4, 분석 재료 대안). 책 1권 소멸 → ward_scrap.
		var sink_val: int = int(_hub.skillbook_sink_value(b))
		var sink := Button.new()
		sink.text = "%s (+%d)" % [("분해" if _hub.is_shop_unlocked(b) else "매각"), sink_val]
		sink.pressed.connect(func() -> void: _on_sink(b))
		row.add_child(sink)
		_analysis_box.add_child(row)


## Unlocked bases → 구매 버튼. 게이트: scribe_shop Tier ≥ 1 (Basic 판매). 구매 = ward_scrap 차감 + 스태시.
func _refresh_shop() -> void:
	for c in _shop_box.get_children():
		c.queue_free()
	if int(_hub.shop_tier_ceiling()) < 1:
		_lbl(_shop_box, "  상점(scribe_shop) Tier 1 필요 — 허브 시설에서 승급.", BAD)
		return
	var unlocked: Dictionary = _hub.shop_listing_unlocked
	var any := false
	for base in unlocked:
		if not bool(unlocked[base]):
			continue
		any = true
		var m: Dictionary = Slice01Data.get_skillbook_master(String(base))
		var disp: String = String(m.get("display_name", base))
		var price: int = int(_hub.shop_price(SHOP_TIER))
		var row := HBoxContainer.new()
		_lbl(row, "%s — %s 생본 · %d scrap" % [disp, SHOP_TIER, price], DIM)
		var btn := Button.new()
		btn.text = "구매"
		btn.disabled = int(_hub.scrap()) < price
		var b: String = String(base)
		btn.pressed.connect(func() -> void: _on_buy(b))
		row.add_child(btn)
		_shop_box.add_child(row)
	if not any:
		_lbl(_shop_box, "  해금된 스킬북 없음 — 위에서 분석 3회로 해금.", DIM)


func _on_analyze(base: String) -> void:
	var r: Dictionary = _hub.submit_analysis(base)
	if bool(r.get("ok", false)) and _stash != null:
		_stash.remove_skillbook(base)   # 의뢰 = 인스턴스 소멸 (F-009 §3.5)
	_refresh()


func _on_buy(base: String) -> void:
	var r: Dictionary = _hub.buy_raw(base, SHOP_TIER)
	if bool(r.get("ok", false)) and _stash != null:
		_stash.add_skillbook(base)      # 생본(affix 없음) → 스태시
	_refresh()


## D-018 §7.5 — 중복 스킬북 분해/매각: 스태시에서 1권 제거 → ward_scrap 획득(해금됨 8 / 미해금 4).
func _on_sink(base: String) -> void:
	if _stash == null:
		return
	var val: int = int(_hub.skillbook_sink_value(base))
	if _stash.remove_skillbook(base):   # 인스턴스 1 소멸 (있을 때만)
		_hub.add_scrap(val)
	_refresh()


func _header(parent: Node, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = Color(0.7, 0.85, 1.0)
	parent.add_child(l)


func _lbl(parent: Node, text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = col
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
