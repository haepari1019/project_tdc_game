extends Node
## Wall X-ray — fades any wall/obstacle that sits between the camera and the controlled
## character, so the party stays visible when the (low cinematic) camera ends up behind a wall
## or in an adjacent room. Per frame: raycast camera→character on the wall layer, fade the
## hit segments' materials to near-transparent; restore segments no longer occluding.
## Core of the see-through-walls system (outline/blur + camera-room fog = follow-up polish).
## ref: F-012 camera.

const WALL_LAYER := 1            # walls/obstacles collision layer (also used for LOS)
const XRAY_ALPHA := 0.16         # faded wall opacity (see through, still faintly present)
const MAX_OCCLUDERS := 5         # successive walls to fade along the line

var _party: Node = null
var _faded: Dictionary = {}      # MeshInstance3D -> StandardMaterial3D currently faded


func setup(party: Node) -> void:
	_party = party


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _party == null:
		_restore_all()
		return
	var space := cam.get_world_3d().direct_space_state
	var from: Vector3 = cam.global_position
	var occluders: Dictionary = {}   # MeshInstance3D -> material (this frame)
	# Fade walls that hide ANY living party member (not just the controlled one).
	for m in _party.get_members():
		if m == null or not is_instance_valid(m) or not m.is_alive():
			continue
		var to: Vector3 = (m as Node3D).global_position + Vector3(0.0, 1.0, 0.0)  # aim at torso
		var exclude: Array = []
		for _i in MAX_OCCLUDERS:
			var q := PhysicsRayQueryParameters3D.create(from, to, WALL_LAYER)
			q.exclude = exclude
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			exclude.append(hit.collider.get_rid())
			var mi := _mesh_of(hit.collider)
			if mi != null and mi.material_override is StandardMaterial3D:
				occluders[mi] = mi.material_override
	# Fade newly-occluding segments.
	for mi in occluders:
		if not _faded.has(mi):
			_set_fade(occluders[mi], true)
			_faded[mi] = occluders[mi]
	# Restore segments that no longer occlude.
	for mi in _faded.keys():
		if not occluders.has(mi):
			if is_instance_valid(mi):
				_set_fade(_faded[mi], false)
			_faded.erase(mi)


func _mesh_of(collider: Object) -> MeshInstance3D:
	if collider == null or not (collider is Node):
		return null
	for c in (collider as Node).get_children():
		if c is MeshInstance3D:
			return c
	return null


func _set_fade(mat: StandardMaterial3D, on: bool) -> void:
	if on:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = XRAY_ALPHA
	else:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.albedo_color.a = 1.0


func _restore_all() -> void:
	for mi in _faded.keys():
		if is_instance_valid(mi):
			_set_fade(_faded[mi], false)
	_faded.clear()
