extends Node
## Enemy vision cones via GPU 2D lighting (the fog's proven technique). Each enemy is a
## sector-shaped, shadow-casting PointLight2D in a top-down SubViewport; every wall is a
## LightOccluder2D. The GPU computes the lit region per-pixel and clips it EXACTLY at walls,
## continuously as the enemy moves/turns — no discrete raycast fan, so no trembling at wall
## edges. The lit colour (red combat core / yellow alert ring) is the union mask; a single
## ground quad samples it and tints the floor. ref: vision cone union (GPU rebuild).

const PX_PER_M := 8.0
const PADDING_M := 4.0
const GROUND_Y := 0.06          # just above the floor
const OVERLAY_ALPHA := 0.03     # ground tint strength (barely there)
const CULL_DIST_M := 32.0       # only light enemies this close to the player
const MAX_LIGHTS := 16          # cone light pool cap
const TEX_PX := 256             # sector light texture size
const COL_COMBAT := Color(0.95, 0.25, 0.2)   # combat zone (red, inner)
const COL_ALERT := Color(1.0, 0.85, 0.2)     # alert zone (yellow, outer ring)

var _map: Node
var _party: Node = null
var _fog: Node = null   # VisionFog — its CURRENT-LOS texture gates the cones to visible areas
var _viewport: SubViewport
var _root2d: Node2D
var _lights: Array[PointLight2D] = []
var _sector_tex: Texture2D = null
var _tex_scale := 1.0
var _bounds_min := Vector2.ZERO
var _bounds_size := Vector2.ONE


func setup(map: Node, party: Node, fog: Node = null) -> void:
	_map = map
	_party = party
	_fog = fog
	_compute_bounds()
	_build_viewport()
	_build_ground_quad()


func _to_fog(world_xz: Vector2) -> Vector2:
	return (world_xz - _bounds_min) * PX_PER_M


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
	_viewport.transparent_bg = false
	_viewport.disable_3d = true
	_viewport.msaa_2d = Viewport.MSAA_4X
	add_child(_viewport)

	_root2d = Node2D.new()
	_viewport.add_child(_root2d)

	# Black canvas → unlit = black; the cone lights ADD their colour onto the white ground.
	var cmod := CanvasModulate.new()
	cmod.color = Color(0, 0, 0)
	_root2d.add_child(cmod)

	var img := Image.create(1, 1, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)
	var ground := Sprite2D.new()
	ground.texture = ImageTexture.create_from_image(img)
	ground.centered = false
	ground.scale = Vector2(_viewport.size)
	_root2d.add_child(ground)

	_build_occluders()

	for _i in MAX_LIGHTS:
		var pl := PointLight2D.new()
		pl.shadow_enabled = true                 # walls clip the cone (the whole point)
		pl.shadow_filter = Light2D.SHADOW_FILTER_PCF13
		pl.shadow_filter_smooth = 3.0
		pl.blend_mode = Light2D.BLEND_MODE_ADD
		pl.energy = 1.0
		pl.visible = false
		_root2d.add_child(pl)
		_lights.append(pl)


func _build_occluders() -> void:
	for occ in _map.get_occluder_footprints():
		var lo := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		poly.closed = true
		var c: Vector2 = occ["center"]
		if occ.has("radius"):
			var rad: float = occ["radius"]
			var pts := PackedVector2Array()
			for i in 12:
				var a := float(i) * TAU / 12.0
				pts.append(_to_fog(c + Vector2(cos(a), sin(a)) * rad))
			poly.polygon = pts
		else:
			var h: Vector2 = occ["half"]
			poly.polygon = PackedVector2Array([
				_to_fog(c + Vector2(-h.x, -h.y)),
				_to_fog(c + Vector2(h.x, -h.y)),
				_to_fog(c + Vector2(h.x, h.y)),
				_to_fog(c + Vector2(-h.x, h.y)),
			])
		lo.occluder = poly
		_root2d.add_child(lo)


## F2: dynamic box occluder (closed door) for the enemy sight-cone viewport. Returns the node so it
## can be freed on open. Mirrors the static box branch (no inset — cones tolerate the full footprint).
func add_box_occluder(center: Vector2, half: Vector2) -> LightOccluder2D:
	var lo := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.closed = true
	poly.polygon = PackedVector2Array([
		_to_fog(center + Vector2(-half.x, -half.y)),
		_to_fog(center + Vector2(half.x, -half.y)),
		_to_fog(center + Vector2(half.x, half.y)),
		_to_fog(center + Vector2(-half.x, half.y)),
	])
	lo.occluder = poly
	_root2d.add_child(lo)
	return lo


func _build_ground_quad() -> void:
	var quad := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = _bounds_size
	quad.mesh = pm
	quad.position = Vector3(_bounds_min.x + _bounds_size.x * 0.5, GROUND_Y, _bounds_min.y + _bounds_size.y * 0.5)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/enemy_vision_overlay.gdshader")
	mat.set_shader_parameter("threat_tex", _viewport.get_texture())
	mat.set_shader_parameter("bounds_min", _bounds_min)
	mat.set_shader_parameter("bounds_size", _bounds_size)
	mat.set_shader_parameter("overlay_alpha", OVERLAY_ALPHA)
	# Gate cones to the party's CURRENT line of sight (fog cur texture) so they never show in
	# the explored/grey memory — only where the party can see right now.
	if _fog != null and _fog.has_method("get_fog_texture"):
		mat.set_shader_parameter("vis_tex", _fog.get_fog_texture())
		mat.set_shader_parameter("vis_bounds_min", _fog.get_bounds_min())
		mat.set_shader_parameter("vis_bounds_size", _fog.get_bounds_size())
		mat.set_shader_parameter("vis_gate", 1.0)
	quad.material_override = mat
	add_child(quad)


## Sector-shaped light texture: a FOV wedge (pointing +X), red inner core (< combat_frac of the
## radius) → yellow outer ring, with soft angular sides + soft rim. Built once from the shared
## cone params. The PointLight2D projects this colour (occluders then clip it at walls).
func _make_sector_texture(half_fov: float, combat_frac: float) -> Texture2D:
	var n := TEX_PX
	var cen := float(n) * 0.5
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx := (float(x) + 0.5 - cen) / cen
			var dy := (float(y) + 0.5 - cen) / cen
			var r := sqrt(dx * dx + dy * dy)
			var a := 0.0
			var col := COL_COMBAT
			if r <= 1.0:
				var ang := atan2(dy, dx)
				if absf(ang) <= half_fov:
					var af := 1.0 - smoothstep(half_fov * 0.82, half_fov, absf(ang))  # soft sides
					var rf := 1.0 - smoothstep(0.88, 1.0, r)                            # soft rim
					a = af * rf
					col = COL_COMBAT if r < combat_frac else COL_ALERT
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	if _party == null:
		return
	var vp := Vector3.INF
	if _party.has_method("get_controlled"):
		var viewer = _party.get_controlled()
		if viewer != null and is_instance_valid(viewer):
			vp = (viewer as Node3D).global_position
	var li := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if li >= MAX_LIGHTS:
			break
		if not is_instance_valid(e) or not e.has_method("vision_cone_data"):
			continue
		var d: Dictionary = e.vision_cone_data()
		if not d.get("active", false):
			continue
		var ep: Vector3 = (e as Node3D).global_position
		if vp != Vector3.INF and Vector2(ep.x - vp.x, ep.z - vp.z).length() > CULL_DIST_M:
			continue
		if _sector_tex == null:
			_sector_tex = _make_sector_texture(float(d["fov_half"]), float(d["combat_r"]) / maxf(0.01, float(d["range"])))
			_tex_scale = float(d["range"]) * PX_PER_M / (float(TEX_PX) * 0.5)
		var f: Vector3 = e.get("facing")
		var lp := _lights[li]
		lp.texture = _sector_tex
		lp.texture_scale = _tex_scale
		lp.position = _to_fog(Vector2(ep.x, ep.z))
		lp.rotation = atan2(f.z, f.x)   # point the wedge along the enemy's facing (fog 2D)
		lp.visible = true
		li += 1
	for j in range(li, _lights.size()):
		_lights[j].visible = false
