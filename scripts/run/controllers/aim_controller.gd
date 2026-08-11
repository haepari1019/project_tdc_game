extends Node
## Skillbook ground-target aim (modal) — start_aim(member, slot, inst) shows the shared marker;
## a left click casts at the ground point, right/cancel ends. Uniform modal interface
## (is_active / cancel / handle_click) so the dungeon_run router treats it like the others.

var _aim: Node3D          # AimMarker — show_ground / show_range / hide_marker / ground_pos
var _combat: Node3D       # CombatController — cast_skillbook
var _active: bool = false
var _member: CharacterBody3D = null
var _slot: int = -1

## 단일타겟 조준(사거리 링 + 조준 커서)으로 다룰 kind. 그 외 targeted = 지면 AoE(원판). 판단은 여기 한 곳.
const UNIT_AIM_KINDS := [
	"skillbook_taunt", "skillbook_execute", "skillbook_blink",
	"skillbook_pin", "skillbook_tether",   # skillbook_root는 광역(반경 원판) → 제외(DRIFT-109)
	"skillbook_vulnerable", "skillbook_purge", "skillbook_stun", "skillbook_polymorph", "skillbook_dash",
]
## 아군을 대상으로 하는 kind(초록 커서). 그 외 = 적 대상(빨강 커서).
const ALLY_TARGET_KINDS := [
	"skillbook_heal", "skillbook_shield", "skillbook_hot",
	"skillbook_relocate_ally", "skillbook_regen",
	"skillbook_purge",   # AB-070 재정의(DRIFT-116) — 적 강화 제거 → **아군 디버프 정화**라 초록 커서
	# ⚠️ `skillbook_ally_shield` 제거 — 그런 kind는 없다(효과 파일명만 그렇고 선언 kind는 skillbook_shield).
]
## 직선형(광선) 조준으로 다룰 kind — 원형 원판/링이 아니라 시전자→마우스 직선 레인으로 표시.
## 채널링은 kind가 아니라 **`channel_shape`로 갈린다**(line=레인 / cone=부채꼴 / cloud=지면 원판 /
## nova=자기중심이라 조준 자체가 없다). 한 kind가 여러 조준을 갖는 첫 사례라 아래에서 따로 분기한다.
const LINE_AIM_KINDS := []
## 단일 대상 **잠금**(DRIFT-122) — `single_target:true` 스킬은 지면이 아니라 **클릭한 유닛**이 대상이다.
## UNIT_AIM_KINDS(표현: 원판 대신 커서)와는 다른 축이다 — 이쪽은 **해소**를 바꾼다. 적 레이어 4 =
## enemy_unit.collision_layer(selection_controller와 같은 값).
const LAYER_ENEMY := 4
const _SbBolt := preload("res://scripts/combat/abilities/effects/sb_bolt.gd")   # 산탄 데드존 계산 공유(SSOT)

var _cursor_ally: ImageTexture     # 초록 십자(아군 대상)
var _cursor_enemy: ImageTexture    # 빨강 십자(적 대상)
var _range: float = 0.0            # 이번 조준 스킬의 시전 사거리(range_m)
var _is_line_aim: bool = false     # 직선 빔 조준 여부(확정 시 사거리까지 안 걷고 그 방향으로 즉시 시전)
var _single_target: bool = false   # 단일 대상 잠금 — 적 유닛을 찍어야만 시전(빈 지면 = 취소)


func setup(aim_marker: Node3D, combat: Node3D) -> void:
	_aim = aim_marker
	_combat = combat
	_cursor_ally = _make_cursor(Color(0.3, 1.0, 0.4))    # 아군 = 초록
	_cursor_enemy = _make_cursor(Color(1.0, 0.32, 0.3))  # 적 = 빨강


## 십자 조준 커서 텍스처를 색상별로 생성(외곽 검정 + 중앙 갭). 에셋 없이 런타임 드로.
func _make_cursor(color: Color) -> ImageTexture:
	var s := 30
	var c := 15
	var gap := 5
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var edge := Color(0, 0, 0, 0.85)
	for i in range(s):                       # 검정 외곽(3px) — 어떤 배경에서도 보이게
		if absi(i - c) <= gap:
			continue
		for o in [-1, 0, 1]:
			img.set_pixel(i, c + o, edge)
			img.set_pixel(c + o, i, edge)
	for i in range(s):                       # 색 심(1px)
		if absi(i - c) <= gap:
			continue
		img.set_pixel(i, c, color)
		img.set_pixel(c, i, color)
	return ImageTexture.create_from_image(img)


## Enter aim mode for a targeted skillbook slot (caller checks charges/cooldown/targeted).
func start_aim(member: CharacterBody3D, slot_index: int, inst: Dictionary) -> void:
	_active = true
	_member = member
	_slot = slot_index
	var p: Dictionary = inst.params
	var cc: Color = member.get_class_color()
	var kind := String(p.get("kind", ""))
	_single_target = bool(p.get("single_target", false))
	_range = float(p.get("range_m", 10.0))
	# Flank Collapse 「잠행」 — 링크된 스킬은 근접 사거리로만 시전(붙어야 함). 원래 range_m를 melee로 대체 → 링도 좁게.
	if String(BindingOverlays.resolve_effective(String(member.base_gear_id), String(member.ability_id), String(inst.get("base_ability_id", "")), slot_index).get("delta", "")) == "flank_strike":
		_range = float(BindingOverlays.FLANK["melee_range_m"])
	var is_rect := String(p.get("shape", "")) == "rect"
	# AB-042 등 rect **존**(지면배치) — 커서 P가 복도 중앙·캐스터→P 축. 사거리 링 + 커서 중앙 프리뷰라 실제 스폰과 일치.
	# 배치형이라 line-aim 아님(사거리 안=즉시 시전 / 밖=navmesh로 걸어가서 시전 — _confirm_cast 일반 경로).
	if is_rect and kind == "skillbook_zone":
		_is_line_aim = false
		Input.set_custom_mouse_cursor(_cursor_enemy, Input.CURSOR_ARROW, Vector2(15, 15))
		_aim.show_zone_rect(member, _range, float(p.get("length_m", 6.0)), float(p.get("width_m", 2.5)), cc)
		return
	# 직선 빔(AB-054 절단 광선) / 캐스터에서 뻗는 직사각형(AB-005 근접 rect) — 원형이 아니라 시전자→마우스 직선
	# 레인으로 조준(적 커서). 확정 시 그 방향으로 즉시 시전(사거리까지 걷지 않음).
	# 채널링 — `channel_shape`가 조준 형태를 정한다. cone은 실제 판정이 원뿔이라 **부채꼴 프리뷰**로
	# 그린다(직선 레인으로 그리면 산탄 때와 같은 "마커와 실제가 다르다" 문제가 난다).
	if kind == "skillbook_channeling":
		var cshape := String(p.get("channel_shape", "line"))
		if cshape == "cone" or cshape == "line":
			_is_line_aim = true   # 방향 조준 = 확정 시 사거리까지 걷지 않고 그 방향으로 즉시 시전
			Input.set_custom_mouse_cursor(_cursor_enemy, Input.CURSOR_ARROW, Vector2(15, 15))
			if cshape == "cone":
				_aim.show_fan(member, _range, 2.0 * float(p.get("half_deg", 30.0)), cc)
			else:
				_aim.show_beam(member, _range, 2.0 * float(p.get("radius_m", 1.0)), cc)
			return
		# cloud = 지면 배치 → 아래 일반 경로(사거리 링 + 반경 원판). nova는 targeted가 아니라 여기 안 온다.
	if LINE_AIM_KINDS.has(kind) or is_rect:
		_is_line_aim = true
		Input.set_custom_mouse_cursor(_cursor_enemy, Input.CURSOR_ARROW, Vector2(15, 15))
		var lane_len: float = float(p.get("length_m", 5.0)) if is_rect else _range
		var lane_w: float = float(p.get("width_m", 2.0)) if is_rect else 2.0 * float(p.get("radius_m", 1.0))
		_aim.show_beam(member, lane_len, lane_w, cc)
		return
	_is_line_aim = false
	# 커서 색으로 대상 진영 구분 — 아군=초록 / 적=빨강(조준 중임도 십자로 표시).
	Input.set_custom_mouse_cursor(_cursor_ally if ALLY_TARGET_KINDS.has(kind) else _cursor_enemy, Input.CURSOR_ARROW, Vector2(15, 15))
	# 단일타겟 → 원판 없음(커서만) / AoE → 효과 반경 원판. 둘 다 시전 사거리를 하얀 링으로 표시.
	# 같은 kind라도 **광역 변주는 원판을 보여준다** — AB-035 광역 도발이 단일 커서로 뜨면 반경을 못 읽는다.
	# (skillbook_taunt: AB-051=단일 → 커서만 / AB-035 `taunt_all` → 반경 원판. DRIFT-108)
	# 잠금 스킬은 kind와 무관하게 커서 표현이다 — 반경 1.2m짜리 원판을 그려 두고 "지면을 찍어라"라고
	# 말하면 조준 방식이 화면과 어긋난다(볼트 4종이 그랬다). 표현과 해소를 같은 플래그로 묶는다.
	var unit_aim: bool = (UNIT_AIM_KINDS.has(kind) or _single_target) and not bool(p.get("taunt_all", false))
	var disc: float = 0.0 if unit_aim else float(p.get("radius_m", p.get("aoe_radius_m", 3.0)))
	# **2단 범위**(AB-055 산탄) — 초탄 원판 + 파편 확산 링. 둘 사이 빈 공간이 곧 파편 데드존이라,
	# 화면에 보이는 간격이 실제 무장 거리(`arm_after_m`)와 같은 값이다. ref: IMPL-DEC-20260728-002.
	var band_in: float = 0.0
	var band_out: float = 0.0
	var band_cone: float = 360.0
	if int(p.get("scatter_pellets", 0)) > 0:
		# 안쪽 = 파편 무장 거리(초탄 반경 + 데드존) · 바깥 = 파편 도달 한계. **sb_bolt와 같은 식**을
		# 써야 화면과 실제가 어긋나지 않는다(무장 거리 계산은 `deadzone_of` 한 곳이 SSOT).
		band_in = _SbBolt.deadzone_of(p)
		band_out = float(p.get("scatter_range_m", 0.0))
		band_cone = float(p.get("scatter_cone_deg", 360.0))   # 실제 확산과 같은 각도로 그린다
	_aim.show_aim(member, _range, disc, cc, band_in, band_out, band_cone)


func is_active() -> bool:
	return _active


func cancel() -> void:
	_active = false
	_member = null
	_slot = -1
	_is_line_aim = false
	_single_target = false
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)   # 커서 원복(기본 화살표)
	_aim.hide_marker()


## While aiming: LMB casts at the ground point, RMB cancels. Returns true if consumed.
func handle_click(event: InputEvent) -> bool:
	if not _active or not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return false
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT:
		# 잠금 스킬 — **적 유닛을 찍었을 때만** 시전한다. 빈 지면이면 그냥 취소(차지·쿨 불변): 시전은
		# `cast_skillbook`에 들어가야 비용이 나가므로, 여기서 안 부르는 것만으로 무비용 취소가 된다.
		var unit = _pick_enemy_under_mouse() if _single_target else null
		if _single_target and unit == null:
			cancel()
			return true
		_confirm_cast(_aim.ground_pos(), unit)
		cancel()
		return true
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
		return true
	return false


## 마우스 아래의 적(레이픽) — 없으면 null. selection_controller._pick과 같은 방식(레이어 4 = 적).
func _pick_enemy_under_mouse() -> CharacterBody3D:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mp := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var to := from + cam.project_ray_normal(mp) * 1000.0
	var q := PhysicsRayQueryParameters3D.create(from, to, LAYER_ENEMY)
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var c = hit.get("collider")
	return c as CharacterBody3D if c != null and c.is_in_group("enemy") else null


## 확정: 사거리 안이면 즉시 시전, 밖이면 navmesh로 사거리까지 걸어가서 도착 시 시전(이동 중 WASD로 취소).
## `unit`(단일 대상 잠금)은 걸어가는 경로에서도 클로저에 실려 유지된다 — 그 사이 대상이 움직여도
## 시전 시점의 위치를 `cast_skillbook`이 다시 읽으므로 조준이 따라간다.
func _confirm_cast(target_pos: Vector3, unit = null) -> void:
	var m := _member
	var slot := _slot
	var rng := _range
	var cb := _combat
	# 직선 빔 — 방향만 의미(사거리까지 걷지 않음). 마우스 방향으로 그 자리에서 즉시 시전.
	if _is_line_aim:
		cb.cast_skillbook(m, slot, target_pos, unit)
		return
	var d: Vector3 = m.global_position - target_pos
	d.y = 0.0
	if d.length() <= rng:
		cb.cast_skillbook(m, slot, target_pos, unit)
		return
	var pc := m.get_node_or_null("Control")
	if pc != null and pc.has_method("order_move_to"):
		# target_pos까지 걷되 rng만큼 못 미쳐서 멈추고 → 도착 콜백에서 시전(그 지점은 이미 사거리 안).
		pc.order_move_to(target_pos, func() -> void: cb.cast_skillbook(m, slot, target_pos, unit), rng)
	else:
		cb.cast_skillbook(m, slot, target_pos, unit)
