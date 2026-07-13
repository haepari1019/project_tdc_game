extends Node3D
## UI-001 — controlled-character world indicator: a foot highlight disc + a floating, bobbing
## downward arrow that follow the controlled party member. setup(party), then it self-updates
## each frame (hidden when there is no controlled member). ref: UI-001.

var _party: Node3D
var _arrow: MeshInstance3D
var _t: float = 0.0


func setup(party: Node3D) -> void:
	_party = party


func _ready() -> void:
	visible = false
	# Foot highlight disc (respects depth — sits on the ground).
	var disc_mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.85
	disc.bottom_radius = 0.85
	disc.height = 0.05
	disc_mi.mesh = disc
	disc_mi.position.y = 0.07
	disc_mi.material_override = _mat(Color(0.25, 0.95, 0.40, 0.35), false)  # 초록 원(조종 표시)
	add_child(disc_mi)
	# Floating downward arrow above the head (always visible).
	_arrow = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.22
	cone.height = 0.42
	_arrow.mesh = cone
	_arrow.rotation_degrees = Vector3(180, 0, 0)  # apex points down
	_arrow.position.y = 2.3
	_arrow.material_override = _mat(Color(0.35, 1.0, 0.55, 0.95), true)  # 초록 화살표
	add_child(_arrow)


func _process(delta: float) -> void:
	if _party == null:
		return
	var ctrl: Node3D = _party.get_controlled()
	if ctrl == null:
		visible = false
		return
	_t += delta
	visible = true
	global_position = ctrl.global_position
	_arrow.position.y = 2.3 + sin(_t * 3.0) * 0.12


func _mat(color: Color, no_depth: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = no_depth
	return m
