extends Control
## **상점 패널** (`UI-029` · `F-009` §3.9.3 개편) — 무기고(gear) · 보급(소모품) · 창고 열람.
##
## ~~분석 의뢰(N=3) · 생본 구매~~ — **M5 제거**(`F-009` §3.9.4 · `D-018` §9). 해금은 **성소 트리**가,
## 슬롯 스킬을 실제로 새기는 **모딩 시술**은 **대장간 패널**이 소유한다. 스킬북이 물건이 아니게 된
## 뒤로 이 화면이 팔 「책」이 없다 — 남은 건 gear·소모품, 그리고 창고를 보는 일이다.
## (`F-009` §3.9.3의 마석 티어 판매는 Phase 5 = M7.) 규칙·통화 = `HubProfile`.

const OK := Color(0.62, 1.0, 0.62)
const BAD := Color(1.0, 0.6, 0.55)
const DIM := Color(0.75, 0.75, 0.78)
const ACCENT := Color(1.0, 0.81, 0.42)
const InventoryGrid := preload("res://scripts/ui/inventory/inventory_grid.gd")
const ItemFactory := preload("res://scripts/ui/inventory/item_factory.gd")

signal closed   # 패널 닫힘 → 호스트(main.gd)가 stash 에디터 소스를 재빌드(구매 반영·덮어쓰기 방지)

var _scrap_lbl: Label
var _armory_box: VBoxContainer
var _consum_box: VBoxContainer
var _stash_cap_lbl: Label
var _stash_grid: InventoryGrid   # 타르코프식 — 상점 옆 실제 그리드(현재 창고). 표시 전용(드래그 없음).
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
	win.custom_minimum_size = Vector2(940, 560)
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

	# 2단: 왼쪽 = 상점/분석/무기고/보급, 오른쪽 = 현재 창고(타르코프식 — 구매가 들어오는 게 보임).
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	_header(col, "── 무기고 (armory 기어 세트 구매) ──")
	_armory_box = VBoxContainer.new()
	_armory_box.add_theme_constant_override("separation", 2)
	col.add_child(_armory_box)
	_header(col, "\n── 보급 (소모품 구매) ──")
	_consum_box = VBoxContainer.new()
	_consum_box.add_theme_constant_override("separation", 2)
	col.add_child(_consum_box)

	# 오른쪽 — 현재 창고 내용(구매 시 즉시 반영). 실제 격자 편집은 배치/스태시 창에서.
	var stash_scroll := ScrollContainer.new()
	stash_scroll.custom_minimum_size = Vector2(250, 0)
	stash_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(stash_scroll)
	var stash_col := VBoxContainer.new()
	stash_col.add_theme_constant_override("separation", 1)
	stash_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stash_scroll.add_child(stash_col)
	_header(stash_col, "── 창고 (현재 보유) ──")
	_stash_cap_lbl = Label.new()
	_stash_cap_lbl.add_theme_font_size_override("font_size", 12)
	stash_col.add_child(_stash_cap_lbl)
	_stash_grid = InventoryGrid.new()
	_stash_grid.setup(self, 6, 18, 36, 2)   # 표시 전용 그리드(드래그 없음 — _on_item_pressed=no-op). 6×18, cell 36.
	stash_col.add_child(_stash_grid)

	if _hub != null and _hub.has_signal("economy_changed"):
		_hub.economy_changed.connect(_refresh)


func open_panel() -> void:
	visible = true
	_refresh()


func close_panel() -> void:
	visible = false
	closed.emit()   # 호스트가 stash 에디터 소스 재빌드(구매 반영·deploy 덮어쓰기 방지)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if not visible or _hub == null:
		return
	_scrap_lbl.text = "ward_scrap: %d" % int(_hub.scrap())
	_scrap_lbl.modulate = OK if int(_hub.scrap()) > 0 else DIM
	_refresh_armory()
	_refresh_consumables()
	_refresh_stash()


## 현재 창고 내용 — 실제 그리드로 표시(구매 시 즉시 반영). 격자 편집은 배치/스태시 창에서.
func _refresh_stash() -> void:
	if _stash == null or _stash_grid == null:
		return
	_stash_grid.clear()
	# 표시는 **실제 tier 용량**(승급 의미 보존), 게이트만 플테 우회를 쓴다 — hub_profile 참조.
	var cap: int = int(_hub.stash_capacity_tier()) if _hub != null and _hub.has_method("stash_capacity_tier") else 0
	var n: int = int(_stash.item_count())
	var uncapped: bool = _hub != null and int(_hub.stash_capacity()) > cap
	_stash_cap_lbl.text = "용량 %d / %d%s" % [n, cap, "  (플테: 한도 해제)" if uncapped else ""]
	_stash_cap_lbl.modulate = ACCENT if uncapped else (BAD if (cap > 0 and n >= cap) else ACCENT)
	for g in _stash.gear:
		var inst: Dictionary = g if typeof(g) == TYPE_DICTIONARY else {"base_gear_id": String(g)}
		var m: Dictionary = Slice01Data.get_gear_master(String(inst.get("base_gear_id", "")))
		if m.is_empty():
			continue
		var gm := m.duplicate(true)
		if inst.has("rolled_identity_skill_id"):
			gm["rolled_identity_skill_id"] = inst["rolled_identity_skill_id"]   # 툴팁용 인스턴스 정보
		if inst.has("rolls"):
			gm["rolls"] = inst["rolls"]
		_stash_grid.add_item_dict(ItemFactory.gear_item(gm, false))
	for cid in _stash.consumables:
		var cm: Dictionary = Slice01Data.get_consumable_master(String(cid))
		if cm.is_empty():
			continue
		_stash_grid.add_item_dict(ItemFactory.consumable_item(cm, int(_stash.consumables[cid])))


## 표시 전용 그리드의 클릭 핸들러(InventoryGrid.place가 gui_input을 _coord._on_item_pressed로 연결).
## 경제 패널 창고 그리드는 드래그/이동 없음 → no-op(마우스오버 툴팁은 노드 자체가 처리).
func _on_item_pressed(_event: InputEvent, _grid: Node, _item: Dictionary) -> void:
	pass


## ~~`_refresh_analysis` · `_refresh_shop` · `_on_analyze` · `_on_buy`~~ — **M5 제거**.
## 분석 의뢰와 생본 구매는 성소 트리(해금) + 대장간 모딩(시술)로 갈라졌다.


## 창고(stash) 한도 — 구매한 기어가 스태시로 들어가므로 초과면 구매 차단(scrap 미소진).
func _stash_full() -> bool:
	var hub := get_node_or_null("/root/HubProfile")
	return hub != null and _stash != null and int(_stash.item_count()) >= int(hub.stash_capacity())


## D-018 §7.5 — 중복 스킬북 분해/매각: 스태시에서 1권 제거 → ward_scrap 획득(해금됨 8 / 미해금 4).
## armory Tier로 구매 가능한 카탈로그 기어 세트(facilities_tiers armory.catalog) → 구매 버튼. ward_scrap → 스태시.
func _refresh_armory() -> void:
	for c in _armory_box.get_children():
		c.queue_free()
	var atier: int = int(_hub.facility_tier("armory"))
	if atier < 1:
		_lbl(_armory_box, "  무기고(armory) Tier 1 필요 — 허브 시설에서 승급.", BAD)
		return
	for t in range(1, atier + 1):
		var cat: Dictionary = Slice01Data.get_facility_tier("armory", t).get("catalog", {})
		var price: int = int(_hub.gear_price(t))
		for role in cat:
			var gid := String(cat[role])
			var m: Dictionary = Slice01Data.get_gear_master(gid)
			if m.is_empty():
				continue
			var row := HBoxContainer.new()
			_lbl(row, "%s (%s) · %d scrap" % [String(m.get("display_name", gid)), Slice01Data.get_role_label(String(role)), price], DIM)
			var btn := Button.new()
			btn.text = "구매"
			btn.disabled = int(_hub.scrap()) < price or _stash_full()
			var g: String = gid
			var ct: int = t
			btn.pressed.connect(func() -> void: _on_buy_gear(g, ct))
			row.add_child(btn)
			_armory_box.add_child(row)


func _on_buy_gear(base_gear_id: String, catalog_tier: int) -> void:
	if _stash_full():
		return
	var r: Dictionary = _hub.buy_gear(base_gear_id, catalog_tier)
	if bool(r.get("ok", false)) and _stash != null:
		_stash.add_gear(base_gear_id)   # 확정 세트(굴림 없음) → 스태시
	_refresh()


## 소모품 상점(기본 보급, 게이트 없음) — 카탈로그 전체를 가격과 함께 구매 버튼. 구매 → 스태시 소모품 +1.
func _refresh_consumables() -> void:
	for c in _consum_box.get_children():
		c.queue_free()
	for row in Slice01Data.get_consumable_rows():
		var cid := String((row as Dictionary).get("consumable_id", ""))
		if cid.is_empty():
			continue
		var price: int = int((row as Dictionary).get("price", 25))
		var have: int = int(_stash.consumables.get(cid, 0)) if _stash != null else 0
		var r := HBoxContainer.new()
		_lbl(r, "%s — %d scrap (보유 %d)" % [String((row as Dictionary).get("display_name", cid)), price, have], DIM)
		var btn := Button.new()
		btn.text = "구매"
		btn.disabled = int(_hub.scrap()) < price
		var c: String = cid
		btn.pressed.connect(func() -> void: _on_buy_consumable(c))
		r.add_child(btn)
		_consum_box.add_child(r)


func _on_buy_consumable(consumable_id: String) -> void:
	var r: Dictionary = _hub.buy_consumable(consumable_id)
	if bool(r.get("ok", false)) and _stash != null:
		_stash.return_consumable(consumable_id, 1)   # 스태시 소모품 +1(보급)
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
