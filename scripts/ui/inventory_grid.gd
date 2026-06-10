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

## Optional flavor blurb per item id, for the hover tooltip (PH).
const ITEM_DESC := {
	"Key": "봉인문을 여는 열쇠",
	"Medkit": "치료 키트",
	"Ammo": "탄약",
	"Cell": "에너지 셀 — 보조 임무 수집품",
	"Scrap": "잡동사니 부품",
	"Pistol": "권총",
	"Armor": "방어구",
	"Rifle": "소총",
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
	for row in rows:
		for col in cols:
			if can_place(w, h, col, row):
				place({"id": id, "w": w, "h": h, "col": col, "row": row, "color": color}, col, row)
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
	var p := Panel.new()
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
	lbl.text = "%s\n%d×%d" % [item.id, int(item.w), int(item.h)]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 10)
	p.add_child(lbl)
	return p


## Hover tooltip for an item: name + optional blurb + footprint size.
func _item_tip(item: Dictionary) -> String:
	var id := String(item.id)
	var lines: Array = [id]
	var desc := String(ITEM_DESC.get(id, ""))
	if not desc.is_empty():
		lines.append(desc)
	lines.append("크기 %d×%d" % [int(item.w), int(item.h)])
	return "\n".join(lines)


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
