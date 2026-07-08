extends Node3D
## 채널 힐 — 시전자 머리 위에 연속 캐스트바를 띄우고 `dur`초 집중한 뒤, 완료 시 반경 아군을 `heal_pct`만큼 치유한다.
## 치유는 ctx.deal_heal 경유 → 지속치유=도트 전환 / 성역=증폭(자동). **이동/스턴/다운 시 취소** — 취소 시 힐 없음 +
## 쿨·차지 환급(사용 안 됨). 점유(begin_channel)도 해제. sb_beam self-ticking 노드 패턴. P4a 캐스팅 확장에 재활용.

const CastBar := preload("res://scripts/combat/abilities/effects/cast_bar.gd")
const RangeDisc := preload("res://scripts/combat/abilities/effects/range_disc.gd")
const MOVE_CANCEL_M := 0.25   # 이 거리 이상 움직이면 채널 취소

var _caster: CharacterBody3D
var _slot: int
var _heal_pct: float
var _radius: float
var _dur: float
var _ctx
var _t: float = 0.0
var _bar
var _start_pos: Vector3
var _done: bool = false


func setup(caster: CharacterBody3D, slot_index: int, heal_pct: float, radius: float, dur: float, ctx) -> void:
	_caster = caster
	_slot = slot_index
	_heal_pct = heal_pct
	_radius = radius
	_dur = dur
	_ctx = ctx
	_start_pos = caster.global_position
	_bar = CastBar.new()
	add_child(_bar)
	_bar.setup(caster, 2.9, Color(0.45, 0.8, 1.0))
	var disc := RangeDisc.new()   # 채널 중 힐 범위(자기중심 원형)를 지면에 표시
	add_child(disc)
	disc.setup(caster, radius, Color(0.4, 0.9, 0.7))


func _process(delta: float) -> void:
	if _done:
		return
	# 취소: 시전자 소멸/다운/스턴, 또는 이동(시작 지점에서 벗어남).
	if _caster == null or not is_instance_valid(_caster) or not _caster.is_alive() \
			or (_caster.has_method("is_stunned") and _caster.is_stunned()) \
			or _caster.global_position.distance_to(_start_pos) > MOVE_CANCEL_M:
		_cancel()
		return
	_t += delta
	_bar.set_progress(_t / _dur)
	if _t >= _dur:
		_complete()


func _complete() -> void:
	_done = true
	if _caster.has_method("end_channel"):
		_caster.end_channel()
	for a in _ctx.allies_in_radius(_caster.global_position, _radius):
		if a != null and is_instance_valid(a) and a.has_method("heal"):
			_ctx.deal_heal(a, _caster, float(a.max_hp) * _heal_pct)
	queue_free()


## 취소 — 점유 해제 + 쿨/차지 환급(사용 안 됨). 힐 없음.
func _cancel() -> void:
	_done = true
	if is_instance_valid(_caster):
		if _caster.has_method("end_channel"):
			_caster.end_channel()
		var inst = _caster.get_skillbook(_slot)
		if inst != null:
			inst.cooldown_s = 0.0                    # 쿨 안 돌아감
			inst.charges = int(inst.charges) + 1     # 차지 환급(사용 안 됨)
		if _caster.has_method("popup_status"):
			_caster.popup_status("취소", Color(0.82, 0.82, 0.82))
	queue_free()
