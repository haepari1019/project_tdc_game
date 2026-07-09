extends Node3D
## Screen-facing HP bar (manual billboard). PH dev visibility — A4 replaces.
## Faces the active camera flat-on each frame so the left-anchored fill reads
## correctly from any camera angle.

const WIDTH := 0.85
const HEIGHT := 0.11
const BORDER := 0.025
const OD_HEIGHT := 0.05           # DPS 「초월」 게이지 바 높이(HP바 아래 얇게)
const UiColors := preload("res://scripts/core/ui_colors.gd")

var _fill: MeshInstance3D
var _fill_mat: StandardMaterial3D
var _projected: MeshInstance3D    # HoT 예측 세그먼트(현재 HP → 회복 완료 도달치, 민트색)
var _proj_ratio: float = 0.0
var _shield: MeshInstance3D       # IDA-020 shield overlay (white, over the fill)
var _shield_ratio: float = 0.0
var _marker: MeshInstance3D
var _marker_mat: StandardMaterial3D
var _marker2: MeshInstance3D  # §5.2 imminent next-target (pulsing)
var _marker2_mat: StandardMaterial3D
var _imm_color: Color = Color.WHITE
var _imm_t: float = 0.0
var _frame: MeshInstance3D  # §5.3 attention (elite/boss) emphasis
var _ratio: float = 1.0
var _od_bar: MeshInstance3D        # DPS 「초월」 게이지(HP바 아래) — 충전=주황 / 발동=밝은 금색
var _od_bar_mat: StandardMaterial3D
var _od_bg: MeshInstance3D
var _cam: Camera3D


func _ready() -> void:
	# §5.3 attention frame (elite/boss) — bright border behind the bar.
	_frame = _make_quad(Color(1.0, 0.82, 0.22, 0.9), WIDTH + BORDER * 5.0, HEIGHT + BORDER * 5.0, -0.005)
	(_frame.material_override as StandardMaterial3D).render_priority = -1
	_frame.visible = false
	var bg := _make_quad(Color(0.04, 0.04, 0.04, 0.85), WIDTH + BORDER * 2.0, HEIGHT + BORDER * 2.0, 0.0)
	(bg.material_override as StandardMaterial3D).render_priority = 0
	_fill = _make_quad(Color(0.30, 0.85, 0.35, 1.0), WIDTH, HEIGHT, 0.01)
	_fill_mat = _fill.material_override
	# Force the fill to always draw in front of the bg — otherwise transparent
	# depth-sorting can flip them frame-to-frame and the bar looks empty (0).
	_fill_mat.render_priority = 1
	# HoT 예측 세그먼트(회복 완료 시 도달할 체력) — 현재 HP 오른쪽에 민트색으로. fill이 자라 채운다.
	_projected = _make_quad(Color(0.55, 1.0, 0.78, 0.5), WIDTH, HEIGHT, 0.015)
	(_projected.material_override as StandardMaterial3D).render_priority = 1
	_projected.visible = false
	# Shield overlay (IDA-020): white bar over the fill, left-anchored, width = shield/maxHP.
	_shield = _make_quad(Color(0.86, 0.92, 1.0, 0.72), WIDTH, HEIGHT, 0.02)
	(_shield.material_override as StandardMaterial3D).render_priority = 2
	_shield.visible = false
	# Current-target marker (F-022 기본어그로): colored square left of the bar.
	var box := HEIGHT + BORDER * 2.0
	_marker = _make_quad(Color(1, 1, 1, 1), box, box, 0.0)
	_marker.position.x = -(WIDTH * 0.5 + BORDER + box * 0.65)
	_marker_mat = _marker.material_override
	_marker_mat.render_priority = 1
	_marker.visible = false
	# §5.2 imminent next-target marker (pulsing) — left of the current marker.
	_marker2 = _make_quad(Color(1, 1, 1, 0.5), box * 0.82, box * 0.82, 0.0)
	_marker2.position.x = _marker.position.x - box * 1.05
	_marker2_mat = _marker2.material_override
	_marker2_mat.render_priority = 1
	_marker2.visible = false
	# DPS 「초월」 게이지 — HP바 아래 얇은 바(충전 진행 + 발동 시 밝은 금색). 비-DPS면 계속 숨김.
	var od_y := -(HEIGHT * 0.5 + BORDER + OD_HEIGHT * 0.5)
	_od_bg = _make_quad(Color(0.04, 0.04, 0.04, 0.8), WIDTH + BORDER * 2.0, OD_HEIGHT + BORDER, 0.0)
	_od_bg.position.y = od_y
	_od_bg.visible = false
	_od_bar = _make_quad(Color(1.0, 0.62, 0.18, 1.0), WIDTH, OD_HEIGHT, 0.01)
	_od_bar.position.y = od_y
	_od_bar_mat = _od_bar.material_override
	_od_bar_mat.render_priority = 1
	_od_bar.visible = false
	_apply()


func _process(delta: float) -> void:
	if _cam == null or not is_instance_valid(_cam):
		_cam = get_viewport().get_camera_3d()
	if _cam:
		# Keep current (parent-driven) position, orient to face the camera flat.
		global_transform = Transform3D(_cam.global_transform.basis, global_position)
	if _marker2 and _marker2.visible:
		_imm_t += delta
		var a := 0.25 + 0.5 * (0.5 + 0.5 * sin(_imm_t * 6.0))
		_marker2_mat.albedo_color = Color(_imm_color.r, _imm_color.g, _imm_color.b, a)


func set_ratio(r: float) -> void:
	_ratio = clampf(r, 0.0, 1.0)
	_apply()


## HoT 예측치(2안) — 회복 완료 시 도달할 체력 비율. 현재~예측 구간을 민트색 세그먼트로. 0/현재 이하 = 숨김.
func set_projected(proj: float) -> void:
	_proj_ratio = clampf(proj, 0.0, 1.0)
	_apply()


## IDA-020 shield as a fraction of max HP (0 = none) — white overlay over the fill.
func set_shield_ratio(s: float) -> void:
	var sr := clampf(s, 0.0, 1.0)
	if absf(sr - _shield_ratio) < 0.002:
		return
	_shield_ratio = sr
	if _shield == null:
		return
	if _shield_ratio <= 0.0001:
		_shield.visible = false
		return
	_shield.visible = true
	_shield.scale = Vector3(_shield_ratio, 1.0, 1.0)
	_shield.position.x = -WIDTH * 0.5 * (1.0 - _shield_ratio)


## DPS 「초월」 게이지 — frac 0..1(충전), active면 밝은 금색. frac 0 & 비활성이면 숨김(비-DPS 유닛은 계속 숨김).
func set_overdrive(frac: float, active: bool) -> void:
	if _od_bar == null:
		return
	var f := clampf(frac, 0.0, 1.0)
	var show := f > 0.001 or active
	_od_bar.visible = show
	_od_bg.visible = show
	if not show:
		return
	_od_bar.scale = Vector3(maxf(f, 0.0001), 1.0, 1.0)
	_od_bar.position.x = -WIDTH * 0.5 * (1.0 - f)
	_od_bar_mat.albedo_color = Color(1.0, 0.9, 0.42) if active else Color(1.0, 0.62, 0.18)


## Show the current aggro target's slot color next to the bar (F-022 §5.2).
func set_target(color: Color) -> void:
	if _marker == null:
		return
	_marker_mat.albedo_color = color
	_marker.visible = true


func clear_target() -> void:
	if _marker:
		_marker.visible = false


## §5.2 imminent next-target marker (pulsing, next target's color).
func set_imminent(color: Color) -> void:
	if _marker2 == null:
		return
	_imm_color = color
	_marker2.visible = true


func clear_imminent() -> void:
	if _marker2:
		_marker2.visible = false


## §5.3 attention emphasis (elite/boss) — bright frame around the bar.
func set_attention(high: bool) -> void:
	if _frame:
		_frame.visible = high


func _apply() -> void:
	if _fill == null:
		return
	_fill.scale = Vector3(maxf(_ratio, 0.0001), 1.0, 1.0)
	_fill.position.x = -WIDTH * 0.5 * (1.0 - _ratio)
	_fill_mat.albedo_color = UiColors.hp_color(_ratio)
	if _projected:                                  # 현재 HP 오른쪽 ~ 예측 도달치 구간
		if _proj_ratio <= _ratio + 0.003:
			_projected.visible = false
		else:
			_projected.visible = true
			_projected.scale = Vector3(_proj_ratio - _ratio, 1.0, 1.0)
			_projected.position.x = WIDTH * ((_ratio + _proj_ratio) * 0.5 - 0.5)


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
