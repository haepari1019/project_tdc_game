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
func export_items() -> Array:
	var out: Array = []
	for item in items:
		out.append({
			"id": item.id, "w": int(item.w), "h": int(item.h),
			"col": int(item.col), "row": int(item.row), "color": item.color,
		})
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


## Item tile caption: 스택류(consumable·haul)=보유 수, 스킬북=남은 탄수, 그 외(기어 등)=이름만.
## (구: 차지 칸수 w×h — 불필요해 제거. 사용자 요청.)
func _node_label(item: Dictionary) -> String:
	var kind := String(item.get("kind", ""))
	if kind == "consumable" or kind == "haul":
		return "%s\nx%d" % [String(item.id), int(item.get("count", 1))]
	if kind == "skillbook":
		var c := int(item.get("charges", -1))
		if c < 0:   # 루팅/디스크립터엔 charges 없음 → master 만탄 + affix 보너스로 표시
			var m: Dictionary = Slice01Data.get_skillbook_master(String(item.get("base_ability_id", "")))
			c = int(m.get("charges_max", 0)) + int((item.get("affix", {}) as Dictionary).get("charges", 0))
		return "%s\n탄 %d" % [String(item.id), c]
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
		"skillbook": lines.append_array(_skillbook_tip(item))
		"consumable": lines.append("소모품 · 보유 x%d · 호버+Z/X/C 또는 드래그로 핫키 등록" % int(item.get("count", 1)))
		"haul": lines.append("재료 (haul) · 금고/'재료 모두 금고로'로 입금")
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


## Skillbook detail — 표시명(상단) + 풀 설명문(SkillText) + 쿨/장착 + affix(색구분). 액션바 툴팁과 동일 수준. F-009/D-018.
func _skillbook_tip(item: Dictionary) -> Array:
	var out: Array = []
	out.append("[color=#9aa4b2]스킬북 (서브) · 탄 %d/%d · At Risk[/color]" % [int(item.get("charges", 0)), int(item.get("charges_max", 0))])
	var m: Dictionary = Slice01Data.get_skillbook_master(String(item.get("base_ability_id", "")))
	if not m.is_empty():
		var cast: Dictionary = m.get("cast", {})
		out.append(SkillText.describe(String(cast.get("kind", "")), cast))   # 풀 설명문 + 핵심 수치
		var eq: Array = []
		for c in m.get("equip_classes", []):
			eq.append(Slice01Data.get_role_label(String(c)))
		out.append("[color=#9aa4b2]쿨 %ss · 장착: %s[/color]" % [str(cast.get("cooldown_s", "?")), ", ".join(eq)])
	# D-018 §7.3 affix — 루팅 인스턴스 굴림. 색구분(긍정 초록/부정 빨강) 라인. {} = 무affix(스태시 base).
	out.append_array(SkillText.affix_lines(item.get("affix", {})))
	return out


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
