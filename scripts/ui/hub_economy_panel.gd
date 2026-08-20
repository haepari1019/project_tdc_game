extends HubPanel
## **구매 패널** (`UI-029`) — 두 건물이 같은 스크립트를 **다른 재고로** 쓴다(M6 건물 재편).
##   · **무기고**(`armory`) = gear 구매 — `armory` tier가 카탈로그를 연다.
##   · **군수**(`quartermaster`) = 소모품 보급 — 게이트 없음, tier는 **런 반입 한도**를 올린다.
##
## 둘을 한 화면에 두면 「지금 뭘 사러 왔는지」가 흐려지고, 마을에 문이 둘인데 화면이 하나면 어느
## 문으로 들어와도 같은 곳이 나온다 — 그러면 마을일 이유가 없다.
##
## ~~분석 의뢰 · 생본 구매~~ — **M5 제거**(`F-009` §3.9.4 · `D-018` §9). 해금은 **필기 상점**이,
## 슬롯에 새기는 **모딩 시술**은 **대장간**이 소유한다. (`F-009` §3.9.3의 마석 티어 판매는 M7.)

const InventoryGrid := preload("res://scripts/ui/inventory/inventory_grid.gd")
const ItemFactory := preload("res://scripts/ui/inventory/item_factory.gd")

## 이 인스턴스가 파는 것 — 건물이 주입한다. "gear"(무기고) | "supply"(군수).
var mode: String = "gear"

var _shop: VBoxContainer
var _stash_cap: Label
var _stash_grid: InventoryGrid   # 표시 전용(드래그 없음) — 산 것이 어디로 가는지 보이게
@onready var _hub: Node = get_node_or_null("/root/HubProfile")
@onready var _stash: Node = get_node_or_null("/root/Stash")


func _ready() -> void:
	window_size = Vector2(940, 600)
	panel_title = "무기고 — 기어" if mode == "gear" else "군수 — 보급"
	super()
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", HubTheme.GAP_L)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	_shop = VBoxContainer.new()
	_shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop.add_theme_constant_override("separation", HubTheme.GAP_S)
	cols.add_child(_shop)
	cols.add_child(VSeparator.new())

	# 오른쪽 — 지금 창고 내용. 산 물건이 **어디로 들어가는지** 보여야 「샀는데 어디 갔지」가 없다.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(260, 0)
	right.add_theme_constant_override("separation", 2)
	cols.add_child(right)
	right.add_child(HubTheme.section("창고 — 현재 보유"))
	_stash_cap = HubTheme.label("", "HubMeta")
	right.add_child(_stash_cap)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	_stash_grid = InventoryGrid.new()
	_stash_grid.setup(self, 6, 18, 36, 2)
	scroll.add_child(_stash_grid)

	if _hub != null and _hub.has_signal("economy_changed"):
		_hub.economy_changed.connect(refresh)


func refresh() -> void:
	if _hub == null or _shop == null:
		return
	set_title("무기고 — 기어" if mode == "gear" else "군수 — 보급")
	var scrap: int = int(_hub.scrap())
	set_status("ward_scrap %d" % scrap, HubTheme.ACCENT if scrap > 0 else HubTheme.BAD)
	for c in _shop.get_children():
		_shop.remove_child(c)
		c.queue_free()
	if mode == "gear":
		_refresh_armory()
	else:
		_refresh_supply()
	_refresh_stash()


## `armory` tier로 열리는 카탈로그 세트. tier가 0이면 **왜 못 사는지**를 적는다 — 빈 목록만 있으면
## 「고장났나」가 된다.
func _refresh_armory() -> void:
	_shop.add_child(HubTheme.section("기어 세트   —   armory tier가 카탈로그를 연다"))
	var atier: int = int(_hub.facility_tier("armory"))
	if atier < 1:
		_shop.add_child(HubTheme.para("무기고가 아직 안 열렸다 — 「시설 승급」에서 세운다.", "", HubTheme.BAD))
		return
	var g := HubTheme.grid(4)   # [이름] [역할] [가격] [행동]
	_shop.add_child(g)
	for t in range(1, atier + 1):
		var cat: Dictionary = Slice01Data.get_facility_tier("armory", t).get("catalog", {})
		var price: int = int(_hub.gear_price(t))
		for role in cat:
			var gid := String(cat[role])
			var m: Dictionary = Slice01Data.get_gear_master(gid)
			if m.is_empty():
				continue
			var afford: bool = int(_hub.scrap()) >= price and not _stash_full()
			g.add_child(HubTheme.label(String(m.get("display_name", gid)), "",
				HubTheme.TEXT if afford else HubTheme.DISABLED))
			g.add_child(HubTheme.label(Slice01Data.get_role_label(String(role)), "HubMeta"))
			var pl := HubTheme.label("⚙%d" % price, "HubMeta", HubTheme.OK if afford else HubTheme.BAD)
			pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(pl)
			var btn := Button.new()
			btn.text = "구매"
			btn.disabled = not afford
			btn.tooltip_text = "" if afford else ("창고가 가득 찼다" if _stash_full() else "ward_scrap 부족")
			var gg: String = gid
			var ct: int = t
			btn.pressed.connect(func() -> void: _on_buy_gear(gg, ct))
			g.add_child(btn)


## 소모품 보급 — 게이트 없음. `quartermaster` tier는 **런 반입 한도**라 여기 상태줄에 함께 적는다:
## 살 수는 있는데 못 들고 나가는 상황을 미리 알 수 있어야 한다.
func _refresh_supply() -> void:
	var cap: int = int(_hub.run_inventory_capacity()) if _hub.has_method("run_inventory_capacity") else 0
	_shop.add_child(HubTheme.section("보급품   —   런 반입 한도 %d칸 (군수 T%d)" % [
		cap, int(_hub.facility_tier("quartermaster"))]))
	var g := HubTheme.grid(4)   # [이름] [보유] [가격] [행동]
	_shop.add_child(g)
	for row in Slice01Data.get_consumable_rows():
		var cid := String((row as Dictionary).get("consumable_id", ""))
		if cid.is_empty():
			continue
		var price: int = int((row as Dictionary).get("price", 25))
		var have: int = int(_stash.consumables.get(cid, 0)) if _stash != null else 0
		var afford: bool = int(_hub.scrap()) >= price
		g.add_child(HubTheme.label(String((row as Dictionary).get("display_name", cid)), "",
			HubTheme.TEXT if afford else HubTheme.DISABLED))
		g.add_child(HubTheme.label("보유 %d" % have, "HubMeta"))
		var pl := HubTheme.label("⚙%d" % price, "HubMeta", HubTheme.OK if afford else HubTheme.BAD)
		pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(pl)
		var btn := Button.new()
		btn.text = "구매"
		btn.disabled = not afford
		var c: String = cid
		btn.pressed.connect(func() -> void: _on_buy_consumable(c))
		g.add_child(btn)


## 창고 표시 — **실제 tier 용량**을 적는다(플테 우회로 9999가 보이면 승급이 의미 없어 보인다).
## 게이트만 우회하고 표시는 진실을.
func _refresh_stash() -> void:
	if _stash == null or _stash_grid == null:
		return
	_stash_grid.clear()
	var cap: int = int(_hub.stash_capacity_tier()) if _hub.has_method("stash_capacity_tier") else 0
	var n: int = int(_stash.item_count())
	var uncapped: bool = int(_hub.stash_capacity()) > cap
	_stash_cap.text = "용량 %d / %d%s" % [n, cap, "  ·  플테: 한도 해제" if uncapped else ""]
	_stash_cap.add_theme_color_override("font_color",
		HubTheme.BAD if (not uncapped and cap > 0 and n >= cap) else HubTheme.DIM)
	for gi in _stash.gear:
		var inst: Dictionary = gi if typeof(gi) == TYPE_DICTIONARY else {"base_gear_id": String(gi)}
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


## 표시 전용 그리드의 클릭 핸들러(`InventoryGrid.place`가 `gui_input`을 여기로 연결한다).
## 구매 화면의 창고는 드래그/이동이 없다 → no-op(마우스오버 툴팁은 노드 자체가 처리).
func _on_item_pressed(_event: InputEvent, _grid: Node, _item: Dictionary) -> void:
	pass


## 창고 한도 — 산 기어가 창고로 들어가므로 초과면 구매를 막는다(scrap을 태우고 물건이 사라지면 안 된다).
func _stash_full() -> bool:
	return _hub != null and _stash != null and int(_stash.item_count()) >= int(_hub.stash_capacity())


func _on_buy_gear(base_gear_id: String, catalog_tier: int) -> void:
	if _stash_full():
		return
	var r: Dictionary = _hub.buy_gear(base_gear_id, catalog_tier)
	if bool(r.get("ok", false)) and _stash != null:
		_stash.add_gear(base_gear_id)   # 확정 세트(굴림 없음) → 창고
	refresh()


func _on_buy_consumable(consumable_id: String) -> void:
	var r: Dictionary = _hub.buy_consumable(consumable_id)
	if bool(r.get("ok", false)) and _stash != null:
		_stash.return_consumable(consumable_id, 1)
	refresh()
