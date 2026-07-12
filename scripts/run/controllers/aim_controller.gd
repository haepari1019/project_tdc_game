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
	"skillbook_taunt", "skillbook_pull", "skillbook_execute", "skillbook_charge", "skillbook_blink",
	"skillbook_pin", "skillbook_tether", "skillbook_scent", "skillbook_root", "skillbook_slow",
	"skillbook_vulnerable", "skillbook_purge",
]
## 아군을 대상으로 하는 kind(초록 커서). 그 외 = 적 대상(빨강 커서).
const ALLY_TARGET_KINDS := [
	"skillbook_heal", "skillbook_shield", "skillbook_ally_shield", "skillbook_hot",
	"skillbook_relocate_ally", "skillbook_regen",
]
## 직선형(광선) 조준으로 다룰 kind — 원형 원판/링이 아니라 시전자→마우스 직선 레인으로 표시.
const LINE_AIM_KINDS := ["skillbook_beam"]

var _cursor_ally: ImageTexture     # 초록 십자(아군 대상)
var _cursor_enemy: ImageTexture    # 빨강 십자(적 대상)
var _range: float = 0.0            # 이번 조준 스킬의 시전 사거리(range_m)
var _is_line_aim: bool = false     # 직선 빔 조준 여부(확정 시 사거리까지 안 걷고 그 방향으로 즉시 시전)


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
	_range = float(p.get("range_m", 10.0))
	# Flank Collapse 「잠행」 — 링크된 스킬은 근접 사거리로만 시전(붙어야 함). 원래 range_m를 melee로 대체 → 링도 좁게.
	if String(BindingFixtures.resolve(String(member.base_gear_id), String(member.ability_id), String(inst.get("base_ability_id", "")), slot_index).get("delta", "")) == "flank_strike":
		_range = float(BindingFixtures.FLANK["melee_range_m"])
	# 직선 빔(AB-054 절단 광선) / 전방 직사각형(AB-005 rect) — 원형이 아니라 시전자→마우스 직선 레인으로
	# 조준(적 커서). 확정 시 그 방향으로 즉시 시전(사거리까지 걷지 않음).
	var is_rect := String(p.get("shape", "")) == "rect"
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
	var disc: float = 0.0 if UNIT_AIM_KINDS.has(kind) else float(p.get("radius_m", p.get("aoe_radius_m", 3.0)))
	_aim.show_aim(member, _range, disc, cc)


func is_active() -> bool:
	return _active


func cancel() -> void:
	_active = false
	_member = null
	_slot = -1
	_is_line_aim = false
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)   # 커서 원복(기본 화살표)
	_aim.hide_marker()


## While aiming: LMB casts at the ground point, RMB cancels. Returns true if consumed.
func handle_click(event: InputEvent) -> bool:
	if not _active or not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return false
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_confirm_cast(_aim.ground_pos())
		cancel()
		return true
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
		return true
	return false


## 확정: 사거리 안이면 즉시 시전, 밖이면 navmesh로 사거리까지 걸어가서 도착 시 시전(이동 중 WASD로 취소).
func _confirm_cast(target_pos: Vector3) -> void:
	var m := _member
	var slot := _slot
	var rng := _range
	var cb := _combat
	# 직선 빔 — 방향만 의미(사거리까지 걷지 않음). 마우스 방향으로 그 자리에서 즉시 시전.
	if _is_line_aim:
		cb.cast_skillbook(m, slot, target_pos)
		return
	var d: Vector3 = m.global_position - target_pos
	d.y = 0.0
	if d.length() <= rng:
		cb.cast_skillbook(m, slot, target_pos)
		return
	var pc := m.get_node_or_null("Control")
	if pc != null and pc.has_method("order_move_to"):
		# target_pos까지 걷되 rng만큼 못 미쳐서 멈추고 → 도착 콜백에서 시전(그 지점은 이미 사거리 안).
		pc.order_move_to(target_pos, func() -> void: cb.cast_skillbook(m, slot, target_pos), rng)
	else:
		cb.cast_skillbook(m, slot, target_pos)
