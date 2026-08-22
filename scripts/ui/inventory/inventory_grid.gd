extends Control
## One backpack container — a fixed CELL lattice with W×H items + an occupancy map.
## Coordinator-driven: this grid owns its occupancy + item visuals and the cell math,
## but DRAG/ROTATE/cross-container routing is handled by the InventoryUI coordinator
## (so items can move BETWEEN containers). ref: F-010 Loadout / 백팩 인벤.
##
## Items: {id, w, h, col, row, color, node}. Occupancy `_occ[row][col]` = item or null.

const C_EMPTY := Color(0.14, 0.15, 0.18)
const C_LINE := Color(0.28, 0.30, 0.36)
const C_OK := Color(0.30, 0.85, 0.40, 0.40)
const C_BAD := Color(0.95, 0.25, 0.20, 0.45)
const RichTooltip := preload("res://scripts/ui/rich_tooltip.gd")   # 색 가능한 BBCode 툴팁(affix 강조)
const SkillText := preload("res://scripts/ui/skill_text.gd")

## Optional flavor blurb per item id, for the hover tooltip (PH). Generic-loot entries removed —
## only real items remain (Key = sealed-door key). Functional items show their own id/name.
const ITEM_DESC := {
	"Key": "봉인문을 여는 열쇠",
}

var cols := 5
var rows := 8
var cell := 48
var gap := 4

var _coord: Node = null
var _occ: Array = []
var items: Array = []          # items currently held by THIS grid

# Drag preview (set by the coordinator while a drag is over this grid).
var _pv_cell := Vector2i.ZERO
var _pv_w := 0
var _pv_h := 0
var _pv_ok := false
var _pv_on := false


func setup(coord: Node, c: int, r: int, cs: int, g: int) -> void:
	_coord = coord
	cols = c
	rows = r
	cell = cs
	gap = g
	custom_minimum_size = _grid_px()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_occ.clear()
	for y in rows:
		var line: Array = []
		for x in cols:
			line.append(null)
		_occ.append(line)


## Resize an (already-cleared) container grid to new dimensions — a container source (chest /
## stash) sets its own size, so the stash can be far larger than the backpack. ref: F-010.
func resize(c: int, r: int) -> void:
	cols = c
	rows = r
	custom_minimum_size = _grid_px()
	_occ.clear()
	for y in rows:
		var line: Array = []
		for x in cols:
			line.append(null)
		_occ.append(line)


func _grid_px() -> Vector2:
	return Vector2(cols * cell + (cols - 1) * gap, rows * cell + (rows - 1) * gap)


func _stride() -> float:
	return float(cell + gap)


func _cell_px(col: int, row: int) -> Vector2:
	return Vector2(col * _stride(), row * _stride())


func item_px(w: int, h: int) -> Vector2:
	return Vector2(w * cell + (w - 1) * gap, h * cell + (h - 1) * gap)


func can_place(w: int, h: int, col: int, row: int, ignore: Variant = null) -> bool:
	if col < 0 or row < 0 or col + w > cols or row + h > rows:
		return false
	for y in range(row, row + h):
		for x in range(col, col + w):
			var o: Variant = _occ[y][x]
			if o != null and o != ignore:
				return false
	return true


func _mark(item: Dictionary, value: Variant) -> void:
	for y in range(int(item.row), int(item.row) + int(item.h)):
		for x in range(int(item.col), int(item.col) + int(item.w)):
			_occ[y][x] = value


## Add an item at the first free spot. Returns false if no room.
func add_item(id: String, w: int, h: int, color: Color) -> bool:
	return add_item_dict({"id": id, "w": w, "h": h, "color": color})


## Add a pre-built item dict (preserving extra fields like gear metadata: kind,
## base_gear_id, at_risk) at the first free spot. Returns false if no room.
func add_item_dict(item: Dictionary) -> bool:
	var w := int(item.get("w", 1))
	var h := int(item.get("h", 1))
	for row in rows:
		for col in cols:
			if can_place(w, h, col, row):
				place(item, col, row)
				return true
	return false


## Put an item into this grid at (col,row): occupy + (re)create its visual here.
func place(item: Dictionary, col: int, row: int) -> void:
	item.col = col
	item.row = row
	_mark(item, item)
	var node := _make_node(item)
	item["node"] = node
	add_child(node)
	node.position = _cell_px(col, row)
	node.gui_input.connect(_coord._on_item_pressed.bind(self, item))
	items.append(item)


## Remove an item from this grid (free cells + destroy its visual). The coordinator
## keeps the item dict and re-places it (here on revert, or in another grid on transfer).
func lift(item: Dictionary) -> void:
	_mark(item, null)
	items.erase(item)
	if item.has("node") and is_instance_valid(item.node):
		item.node.queue_free()
	item["node"] = null


## Remove every item (free visuals + clear occupancy). Used when (re)loading a container.
func clear() -> void:
	for item in items.duplicate():
		if item.has("node") and is_instance_valid(item.node):
			item.node.queue_free()
	items.clear()
	for y in rows:
		for x in cols:
			_occ[y][x] = null


## Clean snapshot of held items (no live node refs) — for persisting a container.
## 그리드 → 직렬화 items. 모든 영속 필드 보존(runtime grid node만 제외). 구버그: id/w/h/col/row/color만
## 내보내 kind·base_gear_id·base_ability_id·affix·count 등이 증발 → 스태시 deploy 동기화 시 kind="" 매칭
## 실패로 전체 삭제. (사용자: 에디터 열고 닫으면 스태시 증발.)
func export_items() -> Array:
	var out: Array = []
	for item in items:
		var d: Dictionary = {}
		for k in item:
			if k == "node":
				continue   # 살아있는 그리드 Panel — 직렬화 불가
			d[k] = item[k]
		out.append(d)
	return out


func _make_node(item: Dictionary) -> Panel:
	var p := RichTooltip.new()   # BBCode 툴팁(색구분 affix/옵션) — 일반 Panel처럼 동작
	p.size = item_px(int(item.w), int(item.h))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.tooltip_text = _item_tip(item)
	var c: Color = item.color
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(c.r, c.g, c.b, 0.85)
	sb.border_color = c.lightened(0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = _node_label(item)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # 긴 이름은 칸 안에서 줄바꿈
	lbl.clip_text = true                                  # 그래도 넘치면 칸 밖으로 안 나오게 클립(전체명=툴팁)
	lbl.add_theme_font_size_override("font_size", 9)
	p.add_child(lbl)
	return p


## Item tile caption: 스택류(consumable·haul·manastone)=보유 수, 그 외(기어 등)=이름만.
## (구: 차지 칸수 w×h — 불필요해 제거. 사용자 요청.)
func _node_label(item: Dictionary) -> String:
	var kind := String(item.get("kind", ""))
	if kind == "consumable" or kind == "haul" or kind == "manastone":
		return "%s\nx%d" % [String(item.id), int(item.get("count", 1))]
	return String(item.id)   # 기어 등 — 이름만


## The item whose footprint covers cell (col,row), or {} if the cell is empty.
func item_at(col: int, row: int) -> Dictionary:
	for it in items:
		if col >= int(it.col) and col < int(it.col) + int(it.w) and row >= int(it.row) and row < int(it.row) + int(it.h):
			return it
	return {}


## Refresh a placed item's caption in-place (e.g. after a consumable stack changes).
func refresh_item_label(item: Dictionary) -> void:
	if not (item.has("node") and is_instance_valid(item.node)):
		return
	for c in item.node.get_children():
		if c is Label:
			c.text = _node_label(item)
			return


## Hover tooltip for an item: name + 상세 스펙(기어 = 굴린 identity·스탯·옵션 / 스킬북 = 효과·쿨·밴드)
## + footprint. F-008 §3.7 / F-009 검증용 — 마우스오버로 인스턴스 롤·스킬 효과 확인. ref: gear_roll_table.md.
func _item_tip(item: Dictionary) -> String:
	var id := String(item.id)
	var lines: Array = ["[b]%s[/b]" % id]   # 이름 = 헤더(굵게). 나머지 라인은 종류별 상세.
	match String(item.get("kind", "")):
		"gear": lines.append_array(_gear_tip(item))
		"consumable": lines.append("소모품 · 보유 x%d · 호버+Z/X/C 또는 드래그로 핫키 등록" % int(item.get("count", 1)))
		"haul": lines.append_array(_haul_tip(item))
		"charm": lines.append_array(_charm_tip(item))
	var desc := String(ITEM_DESC.get(id, ""))
	if not desc.is_empty():
		lines.append(desc)
	lines.append("[color=#9aa4b2]크기 %d×%d[/color]" % [int(item.w), int(item.h)])
	return "\n".join(lines)


## Gear detail — 아키타입 + 굴린 identity(rolled>bundled) + 그 정체성 스탯 + 옵션 roll(mult). F-008 §3.7.
func _gear_tip(item: Dictionary) -> Array:
	var out: Array = []
	var g: Dictionary = Slice01Data.get_gear_master(String(item.get("base_gear_id", "")))
	out.append("장비 (Identity Gear) · %s · %s" % [String(g.get("range_band", "?")), "At Risk" if bool(item.get("at_risk", false)) else "Safe"])
	var rid := String(item.get("rolled_identity_skill_id", g.get("bundled_identity_skill_id", "")))
	var idr: Dictionary = Slice01Data.get_identity_row(rid)
	if not idr.is_empty():
		var combat: Dictionary = idr.get("combat", {})
		out.append("정체성: %s  (%s)" % [Slice01Data.get_identity_display(rid), Slice01Data.get_role_label(String(idr.get("class_id", "")))])
		out.append("  HP %d · 평타 %d / %.1fs / %.1fm" % [
			int(combat.get("hp", 0)),
			int(g.get("basic_damage", combat.get("basic_damage", 0))),
			float(g.get("basic_interval_s", combat.get("basic_interval_s", 1.0))),
			float(g.get("basic_range_m", combat.get("basic_range_m", 2.0)))])
	var roll_line := SkillText.gear_roll_line(item.get("rolls", {}))   # 색구분(피해↑/쿨↓ 초록)
	if not roll_line.is_empty():
		out.append(roll_line)
	return out


## 참 상세 — **무엇을 해 주는가**. 예전엔 이름과 크기만 나와서, 참이 실제로 효과가 있는지조차
## 화면에서 알 수 없었다(효과가 꺼져 있던 기간과 구분이 안 됐다 — 그게 이 툴팁이 필요한 이유다).
## 「들고 있을 때만 적용 = 칸 vs 파워」가 이 물건의 전부이므로, 그 대가도 같이 적는다.
func _charm_tip(item: Dictionary) -> Array:
	var cid := String(item.get("charm_id", ""))
	var row: Dictionary = Slice01Data.get_charm(cid)
	if row.is_empty():
		return ["[color=#c98b7b]알 수 없는 참 '%s'[/color]" % cid]
	var out: Array = ["참 (charm) · 시전 없음 — **들고 있는 동안** 적용"]
	out.append("[color=#9ad1a5]%s[/color]" % String(row.get("desc", "?")))
	var scope: Array = row.get("applies_to", [])
	if not scope.is_empty():
		var names: Array = []
		for c in scope:
			names.append(Slice01Data.get_role_label(String(c)))
		out.append("[color=#d8c14e]%s에게만 걸린다[/color]" % " · ".join(names))
	if row.has("condition"):
		out.append("[color=#d8c14e]조건부 — %s[/color]" % String(row.get("desc", "")))
	out.append("[color=#9aa4b2]같은 참을 여러 개 들면 곱연산으로 겹친다(칸을 더 쓴 만큼).[/color]")
	return out


## 재료 상세 — **무엇에 쓰는가**를 말한다. 예전엔 「재료 (haul) · 금고로 입금」 한 줄이라, 11종이
## 전부 같은 문장을 달고 있었다: 이름만 다른 잡템 더미로 보일 수밖에 없었다(사용자 보고
## 「너무 퀘템이 많이 나오는데 구분이 안되고 딱히 의미도 없으니」).
## 소비처는 `facilities_tiers.json`에서 파생한다 — 툴팁이 비용표를 복제하면 둘이 어긋난다.
func _haul_tip(item: Dictionary) -> Array:
	var hid := String(item.get("haul_material_id", ""))
	var m: Dictionary = Slice01Data.get_haul_material(hid)
	var out: Array = ["재료 · 출처 %s · 보유 x%d" % [String(m.get("source", "?")), int(item.get("count", 1))]]
	var users: Array = Slice01Data.haul_consumers(hid)
	if users.is_empty():
		out.append("[color=#c98b7b]지금 이 재료를 쓰는 건물이 없다.[/color]")
	else:
		out.append("[color=#9ad1a5]쓰는 곳: %s[/color]" % " · ".join(users))
	var hub := get_node_or_null("/root/HubProfile")
	if hub != null and hub.has_method("vault_count"):
		out.append("[color=#9aa4b2]금고 보유 %d — 탈출해야 금고로 넘어간다[/color]" % int(hub.vault_count(hid)))
	return out


## ~~`_skillbook_tip`~~ — **M5 제거**. 스킬북 타일이 존재하지 않으므로 띄울 툴팁도 없다.
## 슬롯 스킬의 상세는 액션바(`controlled_sheet`)와 모딩 패널이 보여준다.


## Grid cell for an item whose top-left is at `global_topleft` (screen). Used by the
## coordinator to map a dragged item onto whichever grid the cursor is over.
func cell_from_global_topleft(global_topleft: Vector2) -> Vector2i:
	var local := global_topleft - global_position
	return Vector2i(roundi(local.x / _stride()), roundi(local.y / _stride()))


func contains_global(p: Vector2) -> bool:
	return get_global_rect().has_point(p)


func set_preview(cell_v: Vector2i, w: int, h: int, ok: bool) -> void:
	_pv_cell = cell_v
	_pv_w = w
	_pv_h = h
	_pv_ok = ok
	_pv_on = true
	queue_redraw()


func clear_preview() -> void:
	if _pv_on:
		_pv_on = false
		queue_redraw()


func _draw() -> void:
	for y in rows:
		for x in cols:
			var r := Rect2(_cell_px(x, y), Vector2(cell, cell))
			draw_rect(r, C_EMPTY, true)
			draw_rect(r, C_LINE, false, 1.0)
	if _pv_on:
		var col: Color = C_OK if _pv_ok else C_BAD
		for dy in _pv_h:
			for dx in _pv_w:
				var cx: int = _pv_cell.x + dx
				var cy: int = _pv_cell.y + dy
				if cx < 0 or cy < 0 or cx >= cols or cy >= rows:
					continue
				draw_rect(Rect2(_cell_px(cx, cy), Vector2(cell, cell)), col, true)
