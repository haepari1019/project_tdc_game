extends Node
## F-011 Vision fog — STEP 1: 2D top-down party line-of-sight texture.
##
## A SubViewport renders a 2D fog-of-war: a black canvas (= unseen) over a white "ground",
## lit by one shadow-casting PointLight2D per alive party member, with a LightOccluder2D
## footprint for every wall/obstacle. The lit region IS the party's union LOS polygon —
## occlusion-shaped (flat-white core + soft far edge so it reads as *occlusion*, not a
## distance gradient). White = visible, black = occluded.
##
## Occluder footprints come from map.get_occluder_footprints() — the SAME geometry as the
## layer-1 colliders enemy_visibility raycasts, so the fog and enemy occlusion never drift.
##
## STEP 2 (later) samples this texture in 3D: world XZ -> fog UV in each object's own shader
## (which already has its world position — so NO depth-texture reconstruction, the part that
## failed twice), greying + darkening unseen geometry independent of 3D lighting ("other
## lights can't reveal what we can't see"). This file's Step-1 job is just to PRODUCE a
## correct, on-screen-verifiable fog texture before any 3D wiring. ref: F-011.

const PX_PER_M := 12.0         # fog texture resolution (px per world metre) — high (crisp mask) on Forward+
const SIGHT_RADIUS_M := 64.0   # party sight reach — large so visibility is occlusion-, not distance-, driven
const PADDING_M := 8.0         # border around the level bounds
const MAX_LIGHTS := 4          # party-size cap (one vision light each — full union LOS)
const LIGHT_TEX_PX := 256      # generated radial light-texture size
const OCCLUDER_INSET_M := 0.15 # shrink occluder footprints so a wall's own faces sample as LIT
                               # (the party-facing side stays bright; only the back goes dark)

var _party: Node = null
var _map: Node = null

var _viewport: SubViewport
var _root2d: Node2D
var _member_lights: Array[PointLight2D] = []
var _bounds_min := Vector2.ZERO   # world (x,z) min corner of the fog field
var _bounds_size := Vector2.ONE   # world (x,z) span

# 3D application (Step 2): a shared next_pass material on world geometry.
var _fog_mat: ShaderMaterial
var _fogged_meshes: Array[MeshInstance3D] = []
var _world_fog_on := true

# Step-1 debug overlay (toggle): shows the fog texture on screen for verification.
var _dbg_layer: CanvasLayer
var _dbg_rect: TextureRect


func setup(party: Node, map: Node) -> void:
	_party = party
	_map = map
	_compute_bounds()
	_build_viewport()
	_build_occluders()
	_build_lights()
	_build_fog_material()
	_apply_fog_to_world()
	_build_debug_overlay()
	print("[FOG] setup: bounds_min=%s size=%s viewport=%s occluders=%d lights=%d fogged_meshes=%d" % [
		_bounds_min, _bounds_size, _viewport.size, _map.get_occluder_footprints().size(),
		_member_lights.size(), _fogged_meshes.size()])


## world (x,z) -> fog-texture pixel space (no Camera2D, so canvas px == texture px).
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
	_viewport.size = Vector2i(
		int(ceil(_bounds_size.x * PX_PER_M)),
		int(ceil(_bounds_size.y * PX_PER_M)))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS  # every frame (Forward+: cheap)
	_viewport.transparent_bg = false
	_viewport.disable_3d = true
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(_viewport)

	_root2d = Node2D.new()
	_viewport.add_child(_root2d)

	# Black canvas ambient = "unseen".
	var cmod := CanvasModulate.new()
	cmod.color = Color(0, 0, 0)
	_root2d.add_child(cmod)

	# White ground the vision lights reveal (1px white sprite stretched to the viewport).
	var img := Image.create(1, 1, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)
	var ground := Sprite2D.new()
	ground.texture = ImageTexture.create_from_image(img)
	ground.centered = false
	ground.scale = Vector2(_viewport.size)
	_root2d.add_child(ground)


func _build_occluders() -> void:
	for occ in _map.get_occluder_footprints():
		var lo := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		poly.closed = true
		var c: Vector2 = occ["center"]
		if occ.has("radius"):
			# Inset so the cylinder's own surface samples as lit (only its far side shadows).
			var rad: float = maxf(0.1, float(occ["radius"]) - OCCLUDER_INSET_M)
			var pts := PackedVector2Array()
			for i in 10:
				var a := float(i) * TAU / 10.0
				pts.append(_to_fog(c + Vector2(cos(a), sin(a)) * rad))
			poly.polygon = pts
		else:
			# Inset both half-extents so the wall's party-facing face stays out of its own shadow.
			var h0: Vector2 = occ["half"]
			var h := Vector2(maxf(0.05, h0.x - OCCLUDER_INSET_M), maxf(0.05, h0.y - OCCLUDER_INSET_M))
			poly.polygon = PackedVector2Array([
				_to_fog(c + Vector2(-h.x, -h.y)),
				_to_fog(c + Vector2(h.x, -h.y)),
				_to_fog(c + Vector2(h.x, h.y)),
				_to_fog(c + Vector2(-h.x, h.y)),
			])
		lo.occluder = poly
		_root2d.add_child(lo)


func _build_lights() -> void:
	var tex := _make_light_texture()
	var tex_scale: float = SIGHT_RADIUS_M * PX_PER_M / float(LIGHT_TEX_PX / 2)
	for _i in MAX_LIGHTS:
		var pl := PointLight2D.new()
		pl.texture = tex
		pl.texture_scale = tex_scale
		pl.energy = 1.0
		pl.blend_mode = Light2D.BLEND_MODE_ADD
		pl.shadow_enabled = true
		pl.shadow_filter = Light2D.SHADOW_FILTER_PCF13  # high-quality soft shadow edge
		pl.shadow_filter_smooth = 4.0
		pl.visible = false
		_root2d.add_child(pl)
		_member_lights.append(pl)


## Radial white texture: flat core to 0.9, soft to the edge. The flat core makes visibility
## occlusion-driven (everything in LOS within reach is fully seen), not a distance falloff.
func _make_light_texture() -> Texture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_offset(1, 1.0)
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.9, Color.WHITE)
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.width = LIGHT_TEX_PX
	gtex.height = LIGHT_TEX_PX
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	return gtex


## Shared fog material — samples the live SubViewport texture by world XZ. One instance,
## referenced as next_pass by every world mesh, so all uniforms update in one place.
func _build_fog_material() -> void:
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = load("res://assets/shaders/vision_fog.gdshader")
	_fog_mat.set_shader_parameter("fog_tex", _viewport.get_texture())
	_fog_mat.set_shader_parameter("bounds_min", _bounds_min)
	_fog_mat.set_shader_parameter("bounds_size", _bounds_size)


## Attach the fog as a next_pass on every world-geometry mesh (floors/walls/obstacles under
## $Rooms). Non-invasive — keeps each StandardMaterial3D; the extra pass greys what's occluded.
## Party/enemies/markers live elsewhere and are untouched (enemies have their own fade).
func _apply_fog_to_world() -> void:
	var rooms := _map.get_node_or_null("Rooms")
	if rooms == null:
		push_warning("[FOG] no $Rooms under map — world fog not applied")
		return
	_collect_and_fog(rooms)


func _collect_and_fog(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if mi.material_override is StandardMaterial3D:
				(mi.material_override as StandardMaterial3D).next_pass = _fog_mat
				_fogged_meshes.append(mi)
		_collect_and_fog(c)


## A/B toggle (B key) — flip the 3D fog on/off to compare against the raw scene.
func toggle_world_fog() -> void:
	_world_fog_on = not _world_fog_on
	for mi in _fogged_meshes:
		if is_instance_valid(mi) and mi.material_override is StandardMaterial3D:
			(mi.material_override as StandardMaterial3D).next_pass = _fog_mat if _world_fog_on else null
	print("[FOG] world fog on=%s" % _world_fog_on)


func _process(_delta: float) -> void:
	if _party == null:
		return
	# Full party union LOS: one vision light per alive member (quality-first; the viewport is
	# UPDATE_ALWAYS). A spot only one member can see around a corner is correctly revealed.
	var li := 0
	for m in _party.get_members():
		if li >= _member_lights.size():
			break
		if is_instance_valid(m) and m.is_alive():
			var mp: Vector3 = (m as Node3D).global_position
			_member_lights[li].position = _to_fog(Vector2(mp.x, mp.z))
			_member_lights[li].visible = true
			li += 1
	for j in range(li, _member_lights.size()):
		_member_lights[j].visible = false


# --- Accessors for Step 2 (3D sampling): texture + world->UV projection ----------

func get_fog_texture() -> Texture2D:
	return _viewport.get_texture() if _viewport != null else null

## The shared fog next_pass material — wall_xray uses it to restore the fog on walls it stops fading.
func get_fog_material() -> ShaderMaterial:
	return _fog_mat

func get_bounds_min() -> Vector2:
	return _bounds_min

func get_bounds_size() -> Vector2:
	return _bounds_size


# --- Step-1 verification: show the fog texture on screen (V toggles) -------------

func _build_debug_overlay() -> void:
	var aspect: float = _bounds_size.y / maxf(0.001, _bounds_size.x)
	var w := 340.0
	var h := 340.0 * aspect
	_dbg_layer = CanvasLayer.new()
	_dbg_layer.layer = 100
	add_child(_dbg_layer)

	# Solid frame behind the texture — visible even if the fog texture is blank/black,
	# so we can tell "panel renders" apart from "texture empty". (Controls placed with
	# explicit position+size, NOT in a Container, so nothing collapses to 0×0.)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.12, 0.85)
	bg.position = Vector2(8, 8)
	bg.size = Vector2(w + 8, h + 40)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dbg_layer.add_child(bg)

	var label := Label.new()
	label.text = "FOG (F-011 step1) — V to toggle"
	label.position = Vector2(14, 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dbg_layer.add_child(label)

	_dbg_rect = TextureRect.new()
	_dbg_rect.texture = _viewport.get_texture()
	_dbg_rect.position = Vector2(12, 36)
	_dbg_rect.size = Vector2(w, h)
	_dbg_rect.custom_minimum_size = Vector2(w, h)
	_dbg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dbg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_dbg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dbg_layer.add_child(_dbg_rect)

	_dbg_layer.visible = false  # hidden by default; V toggles (3D world fog is the main view now)


func toggle_debug() -> void:
	if _dbg_layer != null:
		_dbg_layer.visible = not _dbg_layer.visible
		print("[FOG] debug overlay visible=%s" % _dbg_layer.visible)
