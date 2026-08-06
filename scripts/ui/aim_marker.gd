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
var _fan_active: bool = false      # 부채꼴 채널(AB-109 화염 분사) — 시전자가 꼭짓점인 sector
## **2단 범위 표시**(AB-055 산탄) — 초탄 원판(self)과 별개로 **마우스를 따라다니는 바깥 링**.
## 색을 살짝 달리해 두 단계가 동시에 읽히고, 그 사이 **빈 공간 = 파편 데드존**이 그대로 보인다.
var _outer: MeshInstance3D
var _outer_mat: StandardMaterial3D
var _outer_active: bool = false
var _outer_cone: bool = false      # true = 부채꼴 띠(캐스터→커서 방향 정렬) · false = 360° 링


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
	# 2단 범위 바깥 링 — 원판(self) 스케일에 딸려가면 안 되므로 top_level.
	_outer = MeshInstance3D.new()
	_outer.top_level = true
	_outer_mat = StandardMaterial3D.new()
	_outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_outer_mat.no_depth_test = true
	_outer_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_outer.material_override = _outer_mat
	_outer.visible = false
	add_child(_outer)
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
	# 부채꼴 모드 — 시전자가 **꼭짓점**인 sector를 캐스터→커서로 정렬(레인처럼 중점 보정을 하지 않는다).
	if _fan_active and _follow != null and is_instance_valid(_follow):
		var of: Vector3 = _follow.global_position
		var gpf := ground_pos()
		var dirf := Vector3(gpf.x - of.x, 0.0, gpf.z - of.z)
		_beam.global_position = Vector3(of.x, 0.08, of.z)
		if dirf.length() > 0.05:
			_beam.rotation = Vector3(0.0, atan2(dirf.x, dirf.z), 0.0)   # 로컬 +Z를 캐스터→커서로
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
	if _outer_active:                                        # 2단 띠 = 초탄 원판과 같은 중심(마우스)
		var gp3 := ground_pos()
		_outer.global_position = Vector3(gp3.x, 0.07, gp3.z)
		# 부채꼴이면 **탄이 날아가던 방향**(캐스터→커서)으로 정렬 — sb_bolt의 확산 기준축과 동일.
		if _outer_cone and _follow != null and is_instance_valid(_follow):
			var oc: Vector3 = _follow.global_position
			var d3 := Vector3(gp3.x - oc.x, 0.0, gp3.z - oc.z)
			if d3.length() > 0.05:
				_outer.rotation = Vector3(0.0, atan2(d3.x, d3.z), 0.0)   # 로컬 +Z → 진행 방향
	if _ring.visible and _follow != null and is_instance_valid(_follow):
		var c: Vector3 = _follow.global_position
		_ring.global_position = Vector3(c.x, 0.08, c.z)       # 링 = 시전자 발밑


## 지면 AoE 조준: 마우스 아래 반경 `radius` 원판.
func show_ground(radius: float, color: Color) -> void:
	_ring.visible = false
	_beam.visible = false
	_beam_active = false
	_rect_active = false
	_fan_active = false
	_follow = null
	scale = Vector3(radius, 1.0, radius)
	_mat.albedo_color = color
	visible = true


## 스킬 조준: 시전자(`caster`) 기준 **사거리 링**(`range_m`) + 마우스에 `disc_radius` 원판.
## 단일타겟 → disc_radius 작게(조준점) · AoE → disc_radius = 효과 반경(떨어지는 자리). 둘 다 링으로 사거리 표기.
## **2단 범위**(AB-055 산탄) — 안쪽 원판(초탄 `disc_radius`) + 바깥 **띠**(`band_inner`~`band_outer`).
## 띠의 안쪽 경계가 **파편 데드존**이라, 원판과 띠 사이의 빈 공간이 곧 "여긴 파편이 안 터진다"이다.
## 색은 같은 계열에서 **밝기만 이동** — 다른 색을 쓰면 별개 스킬처럼 읽힌다.
## `band_cone_deg` < 360 이면 **부채꼴 띠**를 그리고 매 프레임 캐스터→커서 축으로 정렬한다.
## 360° 링으로 그리면 **실제 확산(부채꼴)과 조준선이 다른 모양**이 되어 거짓말이 된다.
func show_aim(caster: Node3D, range_m: float, disc_radius: float, color: Color,
		band_inner: float = 0.0, band_outer: float = 0.0, band_cone_deg: float = 360.0) -> void:
	_follow = caster
	_beam.visible = false
	_beam_active = false
	_rect_active = false
	_fan_active = false
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
	_outer_active = band_outer > band_inner and band_inner > 0.0
	_outer_cone = _outer_active and band_cone_deg < 359.0
	if _outer_active:
		if _outer_cone:
			_outer.mesh = _annular_sector(band_inner, band_outer, deg_to_rad(band_cone_deg * 0.5))
			_outer.rotation = Vector3.ZERO   # _process가 매 프레임 캐스터→커서로 정렬
		else:
			var ot := TorusMesh.new()
			ot.inner_radius = band_inner        # = 파편 무장 거리(데드존 바깥 경계)
			ot.outer_radius = band_outer        # = 파편 도달 한계
			ot.rings = 64
			_outer.mesh = ot
		_outer_mat.albedo_color = Color(
			minf(color.r * 0.55 + 0.45, 1.0), minf(color.g * 0.55 + 0.45, 1.0),
			minf(color.b * 0.55 + 0.45, 1.0), 0.20)   # 띠는 넓으니 옅게(원판보다 흐리게)
	_outer.visible = _outer_active
	visible = true


## 부채꼴 채널 조준(AB-109 화염 분사): **시전자가 꼭짓점**인 반경 `radius_m` · `cone_deg` sector.
## 직선 레인(show_beam)으로 그리면 실제 판정(원뿔)과 모양이 달라 거짓말이 된다 — 산탄 조준에서
## 같은 문제를 겪고 세운 규칙이다(IMPL-DEC-20260728-002). ⚠️ 표시 반경 = **최대 사거리**이고,
## 실제로는 틱마다 거기까지 뻗어나간다(첫 틱은 발밑) — 도달 순서는 채널을 봐야 읽힌다.
func show_fan(caster: Node3D, radius_m: float, cone_deg: float, color: Color) -> void:
	_follow = caster
	_fan_active = true
	_beam_active = false
	_rect_active = false
	_beam.mesh = _annular_sector(0.05, radius_m, deg_to_rad(cone_deg * 0.5))
	_beam_mat.albedo_color = Color(color.r, color.g, color.b, 0.28)
	_beam.visible = true
	_ring.visible = false
	_mat.albedo_color = Color(color.r, color.g, color.b, 0.0)   # 마우스 원판 숨김
	visible = true


## 직선 빔 조준(AB-054): 시전자에서 마우스 방향으로 뻗는 길이 `range_m` · 너비 `width_m` 레인.
## 원형이 아니라 직선이라 광선 스킬임이 한눈에 보인다. 원판/링은 끄고 레인만 표시.
func show_beam(caster: Node3D, range_m: float, width_m: float, color: Color) -> void:
	_follow = caster
	_beam_active = true
	_rect_active = false
	_fan_active = false
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
	_fan_active = false
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


## 고리형 부채꼴(annular sector) 메시 — 로컬 **+Z를 중심**으로 ±`half_rad` 벌어진 띠.
## `inner`~`outer` 사이만 채운다(안쪽 빈 공간 = 파편 데드존). CULL_DISABLED라 winding 무관.
func _annular_sector(inner: float, outer: float, half_rad: float, segs: int = 28) -> ArrayMesh:
	var v := PackedVector3Array()
	for i in segs:
		var a0: float = lerpf(-half_rad, half_rad, float(i) / float(segs))
		var a1: float = lerpf(-half_rad, half_rad, float(i + 1) / float(segs))
		var d0 := Vector3(sin(a0), 0.0, cos(a0))
		var d1 := Vector3(sin(a1), 0.0, cos(a1))
		var p00 := d0 * inner
		var p01 := d0 * outer
		var p10 := d1 * inner
		var p11 := d1 * outer
		v.append(p00); v.append(p01); v.append(p11)
		v.append(p00); v.append(p11); v.append(p10)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func hide_marker() -> void:
	_outer_active = false
	_outer_cone = false
	if _outer != null:
		_outer.visible = false
	visible = false
	_ring.visible = false
	_beam.visible = false
	_beam_active = false
	_rect_active = false
	_fan_active = false
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
