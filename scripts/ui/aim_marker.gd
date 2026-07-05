extends MeshInstance3D
## Skill aim marker — 두 모드:
##  · ground (AoE 배치: zone/fire/cold …): 마우스 아래 반경만큼의 평평한 원판 — AoE가 떨어지는 자리.
##  · unit (단일타겟: taunt/pull/execute/dash …): 시전자 기준 **사거리 링** + 마우스에 작은 **조준점**.
## show_ground / show_range 로 진입, hide_marker 로 종료. ground_pos()가 확정(클릭) 지점.

var _mat: StandardMaterial3D
var _ring: MeshInstance3D          # 사거리 링(단일타겟) — top_level이라 원판 스케일에 안 딸려감
var _ring_mat: StandardMaterial3D
var _follow: Node3D = null         # 링이 따라갈 시전자


func _ready() -> void:
	# 원판(self) — ground AoE / unit 조준점 겸용
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
	# 사거리 링 — 자식이지만 top_level로 원판의 스케일/위치와 분리(가시성만 부모에 종속).
	_ring = MeshInstance3D.new()
	_ring.top_level = true
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = Color(1, 1, 0.3, 0.5)
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.no_depth_test = true
	_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = _ring_mat
	_ring.visible = false
	add_child(_ring)


func _process(_delta: float) -> void:
	if not visible:
		return
	global_position = ground_pos() + Vector3(0, 0.05, 0)     # 원판/조준점 = 마우스 지면점
	if _ring.visible and _follow != null and is_instance_valid(_follow):
		var c: Vector3 = _follow.global_position
		_ring.global_position = Vector3(c.x, 0.08, c.z)       # 링 = 시전자 발밑


## 지면 AoE 조준: 마우스 아래 반경 `radius` 원판.
func show_ground(radius: float, color: Color) -> void:
	_ring.visible = false
	_follow = null
	scale = Vector3(radius, 1.0, radius)
	_mat.albedo_color = color
	visible = true


## 스킬 조준: 시전자(`caster`) 기준 **사거리 링**(`range_m`) + 마우스에 `disc_radius` 원판.
## 단일타겟 → disc_radius 작게(조준점) · AoE → disc_radius = 효과 반경(떨어지는 자리). 둘 다 링으로 사거리 표기.
func show_aim(caster: Node3D, range_m: float, disc_radius: float, color: Color) -> void:
	_follow = caster
	var t := TorusMesh.new()
	t.inner_radius = maxf(0.05, range_m - 0.05)          # 얇은 링(선폭 ~0.1)
	t.outer_radius = range_m + 0.05
	t.rings = 72
	_ring.mesh = t
	_ring_mat.albedo_color = Color(1, 1, 1, 0.85)         # 하얀 얇은 사거리 링
	_ring.visible = true
	if disc_radius > 0.0:                                 # AoE: 떨어지는 자리 원판(마우스)
		scale = Vector3(disc_radius, 1.0, disc_radius)
		_mat.albedo_color = Color(color.r, color.g, color.b, 0.32)
	else:                                                 # 단일타겟: 원판 없음(커서만 — 지연 없이)
		_mat.albedo_color = Color(color.r, color.g, color.b, 0.0)
	visible = true


func hide_marker() -> void:
	visible = false
	_ring.visible = false
	_follow = null


## 마우스 아래 지면점(y=0 평면). 확정 시점에 사용.
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
