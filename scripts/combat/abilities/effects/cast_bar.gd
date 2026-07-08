extends Node3D
## 재사용 캐스트/채널 진행바 — 대상 유닛 머리 위에 **연속으로 채워지는** 바(이산 블록 X). set_progress(0..1).
## 카메라를 향해 회전(HealthBar와 동일한 수동 빌보드). 대상을 따라다니고, 대상이 사라지면 자기 소멸.
## P4a 「캐스팅 시간 전체 스킬 확장」에서 재활용 예정 — 채널·정체성 캐스트 등 공용 진행바.

const W := 1.1
const H := 0.16

var _target: Node3D
var _y: float = 2.9
var _fill: MeshInstance3D
var _cam: Camera3D
var _p: float = 0.0


func setup(target: Node3D, y_offset: float = 2.9, color: Color = Color(0.45, 0.8, 1.0)) -> void:
	_target = target
	_y = y_offset
	_make_quad(Color(0.03, 0.03, 0.05, 0.92), W + 0.05, H + 0.05, 0.0)   # 배경+테두리
	_fill = _make_quad(color, W, H, 0.01)                                 # 채워지는 부분(좌측 고정)
	_apply()


func set_progress(p: float) -> void:
	_p = clampf(p, 0.0, 1.0)
	_apply()


func _apply() -> void:
	if _fill == null:
		return
	_fill.scale = Vector3(maxf(_p, 0.0001), 1.0, 1.0)
	_fill.position.x = -W * 0.5 * (1.0 - _p)   # 좌측 고정(HealthBar 방식)


func _process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return
	if _cam == null or not is_instance_valid(_cam):
		_cam = get_viewport().get_camera_3d()
	var pos: Vector3 = _target.global_position + Vector3(0, _y, 0)
	if _cam:
		global_transform = Transform3D(_cam.global_transform.basis, pos)   # 카메라 향해 정면
	else:
		global_position = pos


func _make_quad(color: Color, w: float, h: float, z: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	mi.mesh = q
	mi.position.z = z
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	add_child(mi)
	return mi
