extends Node3D
## 자기중심 원형 스킬의 지면 범위 표시 — 옅게 채운 디스크 + 얇은 링 경계로 `radius` 안에 들어오는 대상을 보이게.
## 대상 유닛을 따라다닌다(자기중심). setup(target, radius, color). 재사용: 채널 힐 힐범위, P4a 캐스팅 범위 등.

var _target: Node3D
var _y_pos: float = 0.06


func setup(target: Node3D, radius: float, color: Color = Color(0.4, 0.9, 0.7)) -> void:
	_target = target
	# 옅은 채움 디스크(범위 안 가시화) — 납작한 실린더가 XZ 평면에 눕는다(hazard_zone과 동일).
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	cyl.radial_segments = 48
	disc.mesh = cyl
	disc.material_override = _mat(Color(color.r, color.g, color.b, 0.1), 0)
	add_child(disc)
	# 얇은 링 경계(TorusMesh는 XZ에 이미 눕혀 있음 — 회전 불요).
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.12
	torus.outer_radius = radius
	torus.rings = 96
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = _mat(Color(color.r, color.g, color.b, 0.65), 1)
	add_child(ring)


func _process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return
	global_position = Vector3(_target.global_position.x, _target.global_position.y + _y_pos, _target.global_position.z)


func _mat(color: Color, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = 1.2
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = priority
	return m
