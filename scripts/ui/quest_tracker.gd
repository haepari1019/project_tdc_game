extends Control
## Quest tracker — top-right HUD, just below the reserved minimap space. Shows the main
## quest (key → door → extract) and a sub quest (loot 6 Cells) with LIVE progress: a (n/6)
## count and a strikethrough on each completed objective. Polls game state each frame
## (cheap). ref: F-006 run state / F-010 loot.

const PANEL_W := 286.0
const PANEL_TOP := 178.0    # reserve minimap room above
const PANEL_H := 156.0
const MARGIN_R := 12.0
const CELL_GOAL := 6

var _inv: Node = null       # InventoryUI
var _run: Node = null       # RunController
var _rt: RichTextLabel = null
var _key_done := false       # latched once the key is obtained


func setup(inv: Node, run: Node) -> void:
	_inv = inv
	_run = run


func _ready() -> void:
	# Anchor a fixed panel to the top-right, offset down past the minimap space.
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -(PANEL_W + MARGIN_R)
	offset_right = -MARGIN_R
	offset_top = PANEL_TOP
	offset_bottom = PANEL_TOP + PANEL_H
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08, 0.74)
	sb.border_color = Color(0.40, 0.43, 0.52, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	_rt = RichTextLabel.new()
	_rt.bbcode_enabled = true
	_rt.fit_content = true
	_rt.scroll_active = false
	_rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rt.add_theme_font_size_override("normal_font_size", 14)
	_rt.add_theme_font_size_override("bold_font_size", 14)
	panel.add_child(_rt)


func _process(_delta: float) -> void:
	if _rt == null:
		return
	if _inv != null and _inv.backpack_has_key():
		_key_done = true
	var door_done: bool = _run != null and _run.objective_complete
	var extract_done: bool = _run != null and _run.run_over
	var cells: int = (_inv.count_item("Cell") if _inv != null else 0)

	var t := "[b]주 임무 — 탈출[/b]\n"
	t += _line(_key_done, "열쇠 획득")
	t += _line(door_done, "봉인문 개방")
	t += _line(extract_done, "탈출 지점에서 탈출")
	t += "\n[b]보조 — 보급 회수[/b]\n"
	t += _line(cells >= CELL_GOAL, "Cell 회수  (%d/%d)" % [mini(cells, CELL_GOAL), CELL_GOAL])
	_rt.text = t


## One objective line: ✔ + strikethrough when done, • + bright when pending.
func _line(done: bool, label: String) -> String:
	if done:
		return "  [color=#77cc88]✔[/color] [s][color=#8b95a0]%s[/color][/s]\n" % label
	return "  [color=#d8c14e]•[/color] [color=#d6dae0]%s[/color]\n" % label
