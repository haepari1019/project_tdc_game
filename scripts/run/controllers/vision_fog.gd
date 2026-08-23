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

const MeshMaterials := preload("res://scripts/core/mesh_materials.gd")
## 지오메트리 루트를 노드 **이름**이 아니라 그룹으로 찾는다 — authored 씬의 루트 이름은
## 우리가 정하지 않는다(map_source.GEOMETRY_GROUP과 같은 값).
const GEOMETRY_GROUP := "map_geometry"

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
var _explored_viewport: SubViewport  # "ever seen" accumulator (CLEAR_ONCE + ADD blend) → fog memory
var _root2d: Node2D
var _member_lights: Array[PointLight2D] = []
var _bounds_min := Vector2.ZERO   # world (x,z) min corner of the fog field
var _bounds_size := Vector2.ONE   # world (x,z) span

# 3D application (Step 2): a shared next_pass material on world geometry.
var _fog_mat: ShaderMaterial
var _fogged_meshes: Array[MeshInstance3D] = []
## 안개 패스를 실제로 꽂은 머티리얼들. 절차 메시는 material_override 1개, 임포트 메시는
## surface별 인스턴스 오버라이드 — 토글은 **이 목록**을 돈다(메시에서 매번 되찾지 않는다).
var _fogged_materials: Array[BaseMaterial3D] = []
var _world_fog_on := true

# Debug overlay (V toggles): shows the current-LOS + explored fog textures for verification.
var _dbg_layer: CanvasLayer


func setup(party: Node, map: Node) -> void:
	_party = party
	_map = map
	_compute_bounds()
	_build_viewport()
	_build_explored_viewport()
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


## "Ever seen" accumulator: a second viewport that NEVER clears (after the first frame) and
## ADD-blends the current visibility texture into itself each frame → a monotonic union of
## everywhere the party has ever had line of sight. Cheap (one textured blit, no lights). The
## fog shader reads this as the "explored" mask → seen-but-not-now areas stay a faint grayscale
## instead of going fully dark. ref: F-011 Step 3.
func _build_explored_viewport() -> void:
	_explored_viewport = SubViewport.new()
	_explored_viewport.size = _viewport.size
	_explored_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_explored_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE  # clear once, then accumulate
	_explored_viewport.transparent_bg = true   # baseline = 0 (NOT the default gray clear → "explored everywhere")
	_explored_viewport.disable_3d = true
	add_child(_explored_viewport)

	var acc := Sprite2D.new()
	acc.texture = _viewport.get_texture()  # current visibility, thresholded + ADD-blended each frame
	acc.centered = false
	var m := ShaderMaterial.new()           # threshold so only CLEARLY-seen pixels accumulate (no creep)
	m.shader = load("res://assets/shaders/fog_accumulate.gdshader")
	acc.material = m
	_explored_viewport.add_child(acc)


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
		elif occ.has("poly"):
			# 임의 볼록 형상(사선 벽·기울어진 프록시). box/cyl은 편의 표기이고 **이쪽이 일반형**이다 —
			# 안개는 원래 폴리곤을 그리므로 아트가 직교 사각형에 갇힐 이유가 없다.
			poly.polygon = _to_fog_poly(_inset_poly(occ["poly"] as PackedVector2Array))
		elif occ.has("half"):
			# Inset ONLY the thin (thickness) axis so the wall's party-facing face stays out of its
			# own shadow — WITHOUT shortening the length. (Shortening the length opened gaps where
			# wall segments meet at corners → light leaked through as thin streaks that crept into
			# the explored map.) ref: F-011.
			var h0: Vector2 = occ["half"]
			var h := h0
			if h0.x <= h0.y:
				h.x = maxf(0.03, h0.x - OCCLUDER_INSET_M)   # x is the thickness axis
			else:
				h.y = maxf(0.03, h0.y - OCCLUDER_INSET_M)   # y is the thickness axis
			poly.polygon = PackedVector2Array([
				_to_fog(c + Vector2(-h.x, -h.y)),
				_to_fog(c + Vector2(h.x, -h.y)),
				_to_fog(c + Vector2(h.x, h.y)),
				_to_fog(c + Vector2(-h.x, h.y)),
			])
		else:
			continue                      # 모르는 종류는 조용히 건너뛴다(크래시 대신)
		lo.occluder = poly
		_root2d.add_child(lo)


## 폴리곤을 안쪽으로 인셋 — 박스의 「두꺼운 축만 줄이기」에 대응하는 일반형.
## 인셋으로 도형이 사라지면(얇은 프록시) 원본을 쓴다.
func _inset_poly(world_poly: PackedVector2Array) -> PackedVector2Array:
	var rings := Geometry2D.offset_polygon(world_poly, -OCCLUDER_INSET_M)
	var best := world_poly
	var best_n := 0
	for r in rings:
		if (r as PackedVector2Array).size() > best_n:
			best_n = (r as PackedVector2Array).size()
			best = r
	return best


func _to_fog_poly(world_poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in world_poly:
		out.append(_to_fog(v))
	return out


## F2: register a dynamic box occluder (e.g. a closed door) at runtime. Returns the LightOccluder2D
## so the caller frees it when the barrier opens (fog updates next frame — the viewport is
## UPDATE_ALWAYS). center/half are world XZ. Mirrors the static box branch (thin-axis inset).
func add_box_occluder(center: Vector2, half: Vector2) -> LightOccluder2D:
	var lo := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.closed = true
	var h := half
	if half.x <= half.y:
		h.x = maxf(0.03, half.x - OCCLUDER_INSET_M)
	else:
		h.y = maxf(0.03, half.y - OCCLUDER_INSET_M)
	poly.polygon = PackedVector2Array([
		_to_fog(center + Vector2(-h.x, -h.y)),
		_to_fog(center + Vector2(h.x, -h.y)),
		_to_fog(center + Vector2(h.x, h.y)),
		_to_fog(center + Vector2(-h.x, h.y)),
	])
	lo.occluder = poly
	_root2d.add_child(lo)
	return lo


func _build_lights() -> void:
	var tex := _make_light_texture()
	var tex_scale: float = SIGHT_RADIUS_M * PX_PER_M / (float(LIGHT_TEX_PX) / 2.0)
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
	_fog_mat.set_shader_parameter("cur_tex", _viewport.get_texture())
	_fog_mat.set_shader_parameter("exp_tex", _explored_viewport.get_texture())
	_fog_mat.set_shader_parameter("bounds_min", _bounds_min)
	_fog_mat.set_shader_parameter("bounds_size", _bounds_size)


## Attach the fog as a next_pass on every world-geometry mesh (floors/walls/obstacles under
## $Rooms). Non-invasive — keeps each StandardMaterial3D; the extra pass greys what's occluded.
## Party/enemies/markers live elsewhere and are untouched (enemies have their own fade).
func _apply_fog_to_world() -> void:
	var rooms: Node = _geometry_root()
	if rooms == null:
		push_warning("[FOG] 지오메트리 루트를 못 찾음(그룹 %s / $Rooms) — 월드 안개 미적용" % GEOMETRY_GROUP)
		return
	_collect_and_fog(rooms)


## 그룹 `map_geometry` 우선, 없으면 예전 이름 `Rooms`, 그것도 없으면 맵 노드 전체.
## 이름 하드코딩이 임포트 씬에서 월드 안개를 통째로 날리던 자리다(경고 한 줄로 끝났다).
func _geometry_root() -> Node:
	if _map == null:
		return null
	for n in (_map as Node).get_tree().get_nodes_in_group(GEOMETRY_GROUP):
		if n == _map or (_map as Node).is_ancestor_of(n):
			return n
	var named: Node = (_map as Node).get_node_or_null("Rooms")
	return named if named != null else _map


## Fog a world object spawned AFTER setup. door/trap/chest/barrel/torch live under dungeon_run
## (not $Rooms) and spawn after _apply_fog_to_world ran, so they'd never receive the fog pass and
## would show at full brightness in unexplored rooms. Same rule as the initial sweep.
func fog_object(n: Node) -> void:
	if _fog_mat == null or n == null:
		return
	_collect_and_fog(n)


## 넘겨받은 노드 **자신**부터 본다. 예전엔 자식만 돌았는데, 절차 경로에선 루트가 항상
## 평범한 Node3D(`Rooms`·상자·배럴)라 티가 안 났다. 임포트 계층은 **루트가 곧 MeshInstance3D**
## (`-col` 힌트가 그 아래에 StaticBody3D를 단다)라, 자식만 돌면 그 메시가 통째로 안개를 안 받는다.
func _collect_and_fog(n: Node) -> void:
	if n is MeshInstance3D:
		_fog_mesh(n as MeshInstance3D)
	for c in n.get_children():
		_collect_and_fog(c)


func _fog_mesh(mi: MeshInstance3D) -> void:
	# 절차 메시(material_override)와 임포트 메시(surface 머티리얼) 양쪽 — 임포트 쪽은
	# 인스턴스 전용으로 복제된 뒤 돌아온다. 예전엔 override만 봐서 **임포트 메시를
	# 통째로 건너뛰었다**(경고도 없이). ref: MeshMaterials.
	var mats: Array = MeshMaterials.editable_materials(mi)
	if mats.is_empty():
		return
	for m in mats:
		(m as BaseMaterial3D).next_pass = _fog_mat
		_fogged_materials.append(m as BaseMaterial3D)
	_fogged_meshes.append(mi)


## A/B toggle (B key) — flip the 3D fog on/off to compare against the raw scene.
func toggle_world_fog() -> void:
	_world_fog_on = not _world_fog_on
	for m in _fogged_materials:
		if is_instance_valid(m):
			m.next_pass = _fog_mat if _world_fog_on else null
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
	var w := 150.0
	var h := 150.0 * aspect
	var vw: float = get_viewport().get_visible_rect().size.x
	if vw < 200.0:
		vw = 1920.0  # fallback if the window size isn't resolved yet at build time
	_dbg_layer = CanvasLayer.new()
	_dbg_layer.layer = 100
	add_child(_dbg_layer)

	# Two SMALL, SEPARATE thumbnails in opposite top corners (no overlap): CURRENT line-of-sight
	# (top-left) and the accumulated EXPLORED map (top-right). Watching EXPLORED grow + persist
	# as the party moves confirms the memory accumulation works.
	_add_dbg_panel("CURRENT LOS (V)", _viewport.get_texture(), Vector2(12, 12), w, h)
	_add_dbg_panel("EXPLORED", _explored_viewport.get_texture(), Vector2(vw - w - 12, 12), w, h)

	_dbg_layer.visible = false  # hidden by default; V toggles (3D world fog is the main view)


func _add_dbg_panel(title: String, tex: Texture2D, pos: Vector2, w: float, h: float) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.10, 0.9)
	bg.position = pos - Vector2(4, 4)
	bg.size = Vector2(w + 8, h + 26)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dbg_layer.add_child(bg)
	var label := Label.new()
	label.text = title
	label.position = pos
	label.add_theme_font_size_override("font_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dbg_layer.add_child(label)
	# TextureRect renders a ViewportTexture at its NATIVE size (1164×1398) and ignores .size /
	# custom_minimum_size for a free Control — so we draw it native and hard-SCALE it down to the
	# target px. scale pivots at top-left, so it shrinks toward `pos`. Guaranteed small.
	var src := Vector2(_viewport.size)
	var r := TextureRect.new()
	r.texture = tex
	r.position = pos + Vector2(0, 16)
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.scale = Vector2(w / src.x, h / src.y)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dbg_layer.add_child(r)


func toggle_debug() -> void:
	if _dbg_layer != null:
		_dbg_layer.visible = not _dbg_layer.visible
		print("[FOG] debug overlay visible=%s" % _dbg_layer.visible)
