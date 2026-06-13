extends MeshInstance3D
## Ground-target aim marker — a flat disc under the mouse for ground-targeted casts/throws.
## Shared by skillbook aim + torch throw. While visible it self-follows the mouse ground point,
## so callers only show_at(radius, color) / hide_marker(); ground_pos() gives the confirm point.

var _mat: StandardMaterial3D


func _ready() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.06
	mesh = disc
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(1, 1, 0.3, 0.35)
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.no_depth_test = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _mat
	visible = false


func _process(_delta: float) -> void:
	if visible:
		global_position = ground_pos() + Vector3(0, 0.05, 0)


## Show the marker sized to `radius` and tinted `color` (alpha included).
func show_at(radius: float, color: Color) -> void:
	scale = Vector3(radius, 1.0, radius)
	_mat.albedo_color = color
	visible = true


func hide_marker() -> void:
	visible = false


## The ground point under the mouse (y=0 plane). Used at confirm time.
func ground_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var mp := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	if absf(dir.y) < 0.0001:
		return from
	return from + dir * (-from.y / dir.y)
