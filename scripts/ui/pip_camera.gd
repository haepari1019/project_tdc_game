extends Control
## UI-006 §7 — small PIP camera. Renders a MIA / separated party member's situation in a
## bottom-left viewport so the player can see why they can't rejoin and decide to intervene.
## Targets are driven by party_controller.pip_targets (empty = close). ref: UI-006 §7.
##
## Auto-open lifecycle (§7.6): emphasized 3 s → low-emphasis expanded → auto-minimize at 8 s.
## While the cause persists the PIP stays minimized (never silently closed); it closes only
## when the cause clears (empty target list). Manual override (§7.7): expanding pauses the
## auto-minimize timer; closing puts that target on a short re-open cooldown.

const PIP_W := 248
const PIP_H := 160
const PIP_MIN_W := 96
const PIP_MIN_H := 62

const EMPHASIS_S := 3.0    # §7.6 highlighted window right after an auto-open
const AUTO_MIN_S := 8.0    # §7.6 total time the PIP stays expanded before auto-minimizing
const REOPEN_CD_S := 5.0   # §7.7 cooldown before a manually-closed target may auto-reopen

var _target: Node3D = null
var _targets: Array = []
var _raw_targets: Array = []          # last list from the controller, pre cooldown-filter
var _index: int = 0
var _cycle_btn: Button
var _subvp: SubViewport
var _cam: Camera3D
var _label: Label
var _border_sb: StyleBoxFlat
var _toggle_btn: Button
var _close_btn: Button
var _minimized: bool = false
var _auto_elapsed: float = 0.0        # seconds since the current auto-open began
var _manual_hold: bool = false        # player manually expanded → pause auto-minimize (§7.7)
var _reopen_cd: float = 0.0           # remaining re-open cooldown for _cd_target
var _cd_target: Node3D = null         # target the player manually closed (suppressed on cd)


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_build()
	_apply_size()


## Set the MIA member list (UI-006 §7.4/§7.8/§7.9). Empty = close; 2+ = count + cycle.
## A manually-closed target stays hidden until its re-open cooldown lapses (§7.7).
func set_targets(members: Array) -> void:
	_raw_targets = members.duplicate()
	var eff: Array = []
	for m in members:
		if _reopen_cd > 0.0 and m == _cd_target:
			continue   # suppressed: player just closed this one (§7.7)
		eff.append(m)

	var was_open := _target != null
	_targets = eff
	if _targets.is_empty():
		_close(true)   # cause cleared (or all suppressed) → close + reset lifecycle
		return
	_index = clampi(_index, 0, _targets.size() - 1)
	_target = _targets[_index] as Node3D
	visible = true
	if not was_open:
		# auto-open → emphasized + expanded, restart the §7.6 lifecycle timers
		_minimized = false
		_manual_hold = false
		_auto_elapsed = 0.0
		_toggle_btn.text = "−"
		_apply_size()
	if _subvp != null:
		_subvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _build() -> void:
	var border := Panel.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border_sb = StyleBoxFlat.new()
	_border_sb.bg_color = Color(0, 0, 0, 0.55)
	_border_sb.border_color = Color(1.0, 0.5, 0.2)
	_border_sb.set_border_width_all(2)
	_border_sb.set_corner_radius_all(4)
	border.add_theme_stylebox_override("panel", _border_sb)
	add_child(border)

	var vc := SubViewportContainer.new()
	vc.set_anchors_preset(Control.PRESET_FULL_RECT)
	vc.offset_left = 3
	vc.offset_top = 3
	vc.offset_right = -3
	vc.offset_bottom = -3
	vc.stretch = true
	vc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vc)
	_subvp = SubViewport.new()
	_subvp.size = Vector2i(PIP_W, PIP_H)
	_subvp.own_world_3d = false
	_subvp.world_3d = get_tree().root.world_3d   # share the main 3D world (same scene/lights)
	_subvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vc.add_child(_subvp)
	_cam = Camera3D.new()
	_cam.fov = 52.0
	_cam.current = true
	_subvp.add_child(_cam)

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_label.offset_top = 2
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	_close_btn = Button.new()  # manual close → re-open cooldown for this target (UI-006 §7.7)
	_close_btn.text = "×"
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_close_btn.offset_left = -21
	_close_btn.offset_top = 1
	_close_btn.offset_right = -2
	_close_btn.offset_bottom = 18
	_close_btn.add_theme_font_size_override("font_size", 12)
	_close_btn.pressed.connect(_on_close)
	add_child(_close_btn)

	_toggle_btn = Button.new()  # minimize / expand (UI-006 §7.6/§7.7 manual override)
	_toggle_btn.text = "−"
	_toggle_btn.focus_mode = Control.FOCUS_NONE
	_toggle_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toggle_btn.offset_left = -44
	_toggle_btn.offset_top = 1
	_toggle_btn.offset_right = -25
	_toggle_btn.offset_bottom = 18
	_toggle_btn.add_theme_font_size_override("font_size", 12)
	_toggle_btn.pressed.connect(_on_toggle)
	add_child(_toggle_btn)

	_cycle_btn = Button.new()  # cycle among MIA members when 2+ (UI-006 §7.8)
	_cycle_btn.text = "▶"
	_cycle_btn.visible = false
	_cycle_btn.focus_mode = Control.FOCUS_NONE
	_cycle_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_cycle_btn.offset_left = 2
	_cycle_btn.offset_top = 1
	_cycle_btn.offset_right = 23
	_cycle_btn.offset_bottom = 18
	_cycle_btn.add_theme_font_size_override("font_size", 11)
	_cycle_btn.pressed.connect(_on_cycle)
	add_child(_cycle_btn)


func _process(delta: float) -> void:
	# §7.7 re-open cooldown: tick down even while closed, then re-evaluate the raw list.
	if _reopen_cd > 0.0:
		_reopen_cd -= delta
		if _reopen_cd <= 0.0:
			_cd_target = null
			if _target == null and not _raw_targets.is_empty():
				set_targets(_raw_targets)

	if _target == null or not is_instance_valid(_target):
		visible = false
		return

	var p: Vector3 = _target.global_position
	_cam.global_position = p + Vector3(0.0, 8.0, 6.5)  # above + behind
	_cam.look_at(p + Vector3(0.0, 0.9, 0.0), Vector3.UP)

	# §7.6 auto-minimize: accumulate while expanded and not manually held open.
	if not _minimized and not _manual_hold:
		_auto_elapsed += delta
		if _auto_elapsed >= AUTO_MIN_S:
			_minimized = true
			_toggle_btn.text = "+"
			_apply_size()

	var nm: String = String(_target.class_id) if "class_id" in _target else "?"
	var n := _targets.size()
	_label.text = "%s · MIA%s" % [nm, (" (%d/%d)" % [_index + 1, n]) if n > 1 else ""]

	# Emphasis is border/label brightness, not extra size (§7.3) — bright for the first 3 s.
	var emph := not _minimized and not _manual_hold and _auto_elapsed < EMPHASIS_S
	var base := Color(1.0, 0.45, 0.3)
	var col: Color = base if emph else base.darkened(0.28)
	_label.modulate = col
	_border_sb.border_color = col
	_border_sb.set_border_width_all(3 if emph else 2)


## Minimize (~2% screen) ↔ expand (~5%) — UI-006 §7.3/§7.6.
func _apply_size() -> void:
	var w: int = PIP_MIN_W if _minimized else PIP_W
	var h: int = PIP_MIN_H if _minimized else PIP_H
	offset_left = 14
	offset_top = -(h + 14)
	offset_right = 14 + w
	offset_bottom = -14
	if _label != null:
		_label.visible = not _minimized
	if _close_btn != null:
		_close_btn.visible = not _minimized        # mini state shows only the expand button
	if _cycle_btn != null:
		_cycle_btn.visible = not _minimized and _targets.size() > 1


func _on_toggle() -> void:
	_minimized = not _minimized
	_toggle_btn.text = "+" if _minimized else "−"
	if not _minimized:
		_manual_hold = true   # manual expand overrides + pauses auto-minimize (§7.7)
		_auto_elapsed = 0.0
	_apply_size()


func _on_close() -> void:
	# §7.7 — player dismissed this PIP: hide and hold off auto-reopen for the same target.
	_reopen_cd = REOPEN_CD_S
	_cd_target = _target
	_target = null
	visible = false
	if _subvp != null:
		_subvp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _on_cycle() -> void:
	if _targets.size() > 1:
		_index = (_index + 1) % _targets.size()
		_target = _targets[_index] as Node3D


## Fully close + reset the auto-open lifecycle (cause cleared). reset_raw clears the cached
## controller list so a stale list can't immediately reopen us.
func _close(reset_raw: bool) -> void:
	_target = null
	_index = 0
	visible = false
	_minimized = false
	_manual_hold = false
	_auto_elapsed = 0.0
	if reset_raw:
		_raw_targets = []
	if _subvp != null:
		_subvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
