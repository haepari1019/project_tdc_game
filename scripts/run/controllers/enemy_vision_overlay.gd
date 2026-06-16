extends Node
## Enemy vision cones rendered as a UNION. Every enemy's sight sector is rasterised into one
## top-down 2D mask (overlaps merge naturally in the raster), then a SINGLE ground quad samples
## that mask and tints the floor — combat=red, alert=yellow. Because the on-screen graphic is
## ONE quad sampling a pre-merged mask, overlapping cones can't z-fight or alpha-stack (the bug
## the per-enemy cone meshes had). ref: vision cone union.

const Painter := preload("res://scripts/run/controllers/enemy_vision_painter.gd")

const PX_PER_M := 16.0          # high (crisp cone edges) — Forward+, quality-first
const PADDING_M := 4.0
const GROUND_Y := 0.06          # just above the floor (the old cones floated at 0.3)
const OVERLAY_ALPHA := 0.16     # ground tint strength (faint)

var _map: Node
var _viewport: SubViewport
var _bounds_min := Vector2.ZERO
var _bounds_size := Vector2.ONE


func setup(map: Node) -> void:
	_map = map
	_compute_bounds()
	_build_viewport()
	_build_ground_quad()


func _compute_bounds() -> void:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for r in _map.get_room_rects():
		var c: Vector3 = r["center"]
		var s: Vector3 = r["size"]
		mn.x = minf(mn.x, c.x - s.x * 0.5)
		mn.y = minf(mn.y, c.z - s.z * 0.5)
		mx.x = maxf(mx.x, c.x + s.x * 0.5)
		mx.y = maxf(mx.y, c.z + s.z * 0.5)
	mn -= Vector2(PADDING_M, PADDING_M)
	mx += Vector2(PADDING_M, PADDING_M)
	_bounds_min = mn
	_bounds_size = mx - mn


func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(ceil(_bounds_size.x * PX_PER_M)), int(ceil(_bounds_size.y * PX_PER_M)))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = true   # uncovered = transparent → mask alpha = cone coverage
	_viewport.disable_3d = true
	_viewport.msaa_2d = Viewport.MSAA_4X  # anti-alias the sector edges (smooth cone outline)
	add_child(_viewport)
	var painter := Painter.new()
	painter.bounds_min = _bounds_min
	painter.px_per_m = PX_PER_M
	_viewport.add_child(painter)


func _build_ground_quad() -> void:
	var quad := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = _bounds_size       # XZ extents
	quad.mesh = pm
	quad.position = Vector3(_bounds_min.x + _bounds_size.x * 0.5, GROUND_Y, _bounds_min.y + _bounds_size.y * 0.5)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/enemy_vision_overlay.gdshader")
	mat.set_shader_parameter("threat_tex", _viewport.get_texture())
	mat.set_shader_parameter("bounds_min", _bounds_min)
	mat.set_shader_parameter("bounds_size", _bounds_size)
	mat.set_shader_parameter("overlay_alpha", OVERLAY_ALPHA)
	quad.material_override = mat
	add_child(quad)
