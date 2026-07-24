extends MeshInstance3D
## Skill aim marker — 세 모드:
##  · ground (AoE 배치: zone/fire/cold …): 마우스 아래 반경만큼의 평평한 원판 — AoE가 떨어지는 자리.
##  · unit (단일타겟: taunt/pull/execute/dash …): 시전자 기준 **사거리 링** + 마우스에 작은 **조준점**.
##  · beam (직선형: AB-054 절단 광선): 시전자→마우스 방향으로 뻗는 **직선 레인**(길이=사거리, 너비=빔폭).
## show_ground / show_aim / show_beam 으로 진입, hide_marker 로 종료. ground_pos()가 확정(클릭) 지점.

var _mat: StandardMaterial3D
var _ring: MeshInstance3D          # 사거리 링(단일타겟) — top_level이라 원판 스케일에 안 딸려감
var _ring_mat: StandardMaterial3D
var _follow: Node3D = null         # 링/빔이 따라갈 시전자
var _beam: MeshInstance3D          # 직선 빔 레인(top_level) — 시전자→마우스 방향
var _beam_mat: StandardMaterial3D
var _beam_len: float = 0.0         # 레인 길이(=빔 사거리)
var _beam_active: bool = false
var _rect_active: bool = false     # 지면배치 rect 존(AB-042 Wind 복도) — 커서 '중앙' 정렬 + 사거리 링(빔은 캐스터에서 뻗음)


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
	# 직선 빔 레인 — top_level(원판 스케일과 분리). 시전자에서 마우스 방향으로 뻗는 납작한 상자.
	_beam = MeshInstance3D.new()
	_beam.top_level = true
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.no_depth_test = true
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam.material_override = _beam_mat
	_beam.visible = false
	add_child(_beam)


func _process(_delta: float) -> void:
	if not visible:
		return
	# rect 존 모드 — 커서를 **중앙**으로 캐스터→커서 축의 레인 + 사거리 링(빔과 달리 커서 중앙 정렬 → 실제 스폰과 일치).
	if _rect_active and _follow != null and is_instance_valid(_follow):
		var o2: Vector3 = _follow.global_position
		var gp2 := ground_pos()
		var dir2 := Vector3(gp2.x - o2.x, 0.0, gp2.z - o2.z)
		_beam.global_position = Vector3(gp2.x, 0.08, gp2.z)     # 커서 = 복도 중앙
		if dir2.length() > 0.05:
			_beam.rotation = Vector3(0.0, atan2(dir2.x, dir2.z), 0.0)   # 로컬 +Z를 캐스터→커서로
		if _ring.visible:
			_ring.global_position = Vector3(o2.x, 0.08, o2.z)   # 사거리 링 = 시전자 발밑
		return
	# 빔 모드 — 원판/링 대신 시전자→마우스 방향의 직선 레인을 매 프레임 정렬.
	if _beam_active and _follow != null and is_instance_valid(_follow):
		var o: Vector3 = _follow.global_position
		var gp := ground_pos()
		var dir := Vector3(gp.x - o.x, 0.0, gp.z - o.z)
		if dir.length() > 0.05:
			dir = dir.normalized()
			_beam.global_position = Vector3(o.x, 0.08, o.z) + dir * (_beam_len * 0.5)  # 한쪽 끝=시전자
			_beam.rotation = Vector3(0.0, atan2(dir.x, dir.z), 0.0)                    # 로컬 +Z를 dir로
		return
	global_position = ground_pos() + Vector3(0, 0.05, 0)     # 원판/조준점 = 마우스 지면점
	if _ring.visible and _follow != null and is_instance_valid(_follow):
		var c: Vector3 = _follow.global_position
		_ring.global_position = Vector3(c.x, 0.08, c.z)       # 링 = 시전자 발밑


## 지면 AoE 조준: 마우스 아래 반경 `radius` 원판.
func show_ground(radius: float, color: Color) -> void:
	_ring.visible = false
	_beam.visible = false
	_beam_active = false
	_rect_active = false
	_follow = null
	scale = Vector3(radius, 1.0, radius)
	_mat.albedo_color = color
	visible = true


## 스킬 조준: 시전자(`caster`) 기준 **사거리 링**(`range_m`) + 마우스에 `disc_radius` 원판.
## 단일타겟 → disc_radius 작게(조준점) · AoE → disc_radius = 효과 반경(떨어지는 자리). 둘 다 링으로 사거리 표기.
func show_aim(caster: Node3D, range_m: float, disc_radius: float, color: Color) -> void:
	_follow = caster
	_beam.visible = false
	_beam_active = false
	_rect_active = false
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


## 직선 빔 조준(AB-054): 시전자에서 마우스 방향으로 뻗는 길이 `range_m` · 너비 `width_m` 레인.
## 원형이 아니라 직선이라 광선 스킬임이 한눈에 보인다. 원판/링은 끄고 레인만 표시.
func show_beam(caster: Node3D, range_m: float, width_m: float, color: Color) -> void:
	_follow = caster
	_beam_active = true
	_rect_active = false
	_beam_len = range_m
	var b := BoxMesh.new()
	b.size = Vector3(maxf(width_m, 0.2), 0.05, range_m)   # 너비 × 얇은 높이 × 길이(로컬 +Z)
	_beam.mesh = b
	_beam_mat.albedo_color = Color(color.r, color.g, color.b, 0.30)
	_beam.visible = true
	_ring.visible = false
	_mat.albedo_color = Color(color.r, color.g, color.b, 0.0)   # 원판 숨김(투명)
	visible = true


## 지면배치 rect 존 조준(AB-042 Wind 복도): 커서 P를 **중앙**으로 캐스터→P 축의 length×width 직사각 프리뷰 +
## 시전자 기준 사거리 링. 빔(show_beam=캐스터에서 뻗음)과 달리 커서 중앙 정렬이라 실제 스폰(P 중앙)과 일치한다.
func show_zone_rect(caster: Node3D, range_m: float, length_m: float, width_m: float, color: Color) -> void:
	_follow = caster
	_rect_active = true
	_beam_active = false
	_beam_len = length_m
	var b := BoxMesh.new()
	b.size = Vector3(maxf(width_m, 0.2), 0.05, maxf(length_m, 0.2))   # 너비 × 얇은 높이 × 길이(로컬 +Z)
	_beam.mesh = b
	_beam_mat.albedo_color = Color(color.r, color.g, color.b, 0.30)
	_beam.visible = true
	var t := TorusMesh.new()                                # 사거리 링(show_aim과 동일 규격)
	t.inner_radius = maxf(0.05, range_m - 0.05)
	t.outer_radius = range_m + 0.05
	t.rings = 72
	_ring.mesh = t
	_ring_mat.albedo_color = Color(1, 1, 1, 0.85)
	_ring.visible = true
	_mat.albedo_color = Color(color.r, color.g, color.b, 0.0)   # 마우스 원판 숨김(레인으로 대체)
	visible = true


func hide_marker() -> void:
	visible = false
	_ring.visible = false
	_beam.visible = false
	_beam_active = false
	_rect_active = false
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
