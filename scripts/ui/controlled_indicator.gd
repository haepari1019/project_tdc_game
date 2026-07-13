extends Node3D
## UI-001 — controlled-character world indicator: a thin green selection ring (스타크래프트식) at the
## feet, following the controlled party member. setup(party), then it self-updates each frame
## (hidden when there is no controlled member). ref: UI-001.

var _party: Node3D


func setup(party: Node3D) -> void:
	_party = party


func _ready() -> void:
	visible = false
	# 발밑 선택 링(스타크래프트식) — 얇은 초록 테두리. TorusMesh는 XZ 평면에 이미 눕혀 있음(회전 불요).
	var ring_mi := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.55
	ring.outer_radius = 0.65
	ring_mi.mesh = ring
	ring_mi.position.y = 0.05
	ring_mi.material_override = _mat(Color(0.30, 1.0, 0.45, 0.9), false)  # 초록 링(조종 표시)
	add_child(ring_mi)


func _process(_delta: float) -> void:
	if _party == null:
		return
	var ctrl: Node3D = _party.get_controlled()
	if ctrl == null:
		visible = false
		return
	visible = true
	global_position = ctrl.global_position


func _mat(color: Color, no_depth: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = no_depth
	return m
