extends Node3D
## 범용 캐스트 노드 — `dur`초 캐스트바 진행 후 `on_complete.call()` 실행. 이동(MOVE_CANCEL_M 이탈)/스턴/다운 시 **취소**:
## 취소면 on_complete 미실행 + 쿨/차지 환급(사용 안 됨) + 점유 해제. `radius>0`면 자기중심 범위 디스크 표시.
## P4a 「전체 스킬 캐스팅 시간 확장」의 범용 래퍼 — 힐·볼트·정체성 캐스트 등 공용. cast_bar/range_disc 재사용.
## ref: DRIFT-075(캐스터 캐스트 중심) · channel_heal 일반화.

const CastBar := preload("res://scripts/combat/abilities/effects/cast_bar.gd")
const RangeDisc := preload("res://scripts/combat/abilities/effects/range_disc.gd")
const MOVE_CANCEL_M := 0.25   # 시작 지점에서 이 거리 이상 움직이면 취소

var _caster: CharacterBody3D
var _slot: int
var _dur: float
var _ctx
var _on_complete: Callable
var _t: float = 0.0
var _bar
var _start_pos: Vector3
var _done: bool = false


func setup(caster: CharacterBody3D, slot_index: int, dur: float, ctx, on_complete: Callable,
		radius: float = 0.0, bar_color: Color = Color(0.45, 0.8, 1.0)) -> void:
	_caster = caster
	_slot = slot_index
	_dur = dur
	_ctx = ctx
	_on_complete = on_complete
	_start_pos = caster.global_position
	_bar = CastBar.new()
	add_child(_bar)
	_bar.setup(caster, 2.9, bar_color)
	if radius > 0.0:                                # 자기중심 범위(힐 등) 지면 표시
		var disc := RangeDisc.new()
		add_child(disc)
		disc.setup(caster, radius, Color(bar_color.r, bar_color.g, bar_color.b))
	if caster.has_method("begin_channel"):
		caster.begin_channel(dur)                  # 점유 = 캐스트 중 다른 서브 차단


func _process(delta: float) -> void:
	if _done:
		return
	# 취소: 시전자 소멸/다운/스턴, 또는 이동(시작 지점 이탈).
	if _caster == null or not is_instance_valid(_caster) or not _caster.is_alive() \
			or (_caster.has_method("is_stunned") and _caster.is_stunned()) \
			or _caster.global_position.distance_to(_start_pos) > MOVE_CANCEL_M:
		_cancel()
		return
	_t += delta
	_bar.set_progress(_t / _dur)
	if _t >= _dur:                                  # 완료 → 결과 실행
		_done = true
		if _caster.has_method("end_channel"):
			_caster.end_channel()
		if _on_complete.is_valid():
			_on_complete.call()
		queue_free()


## 취소 — 점유 해제 + 쿨/차지 환급(사용 안 됨). on_complete 미실행.
func _cancel() -> void:
	_done = true
	if is_instance_valid(_caster):
		if _caster.has_method("end_channel"):
			_caster.end_channel()
		var inst = _caster.get_skillbook(_slot)
		if inst != null:
			inst.cooldown_s = 0.0
			inst.charges = int(inst.charges) + 1
		if _caster.has_method("popup_status"):
			_caster.popup_status("취소", Color(0.82, 0.82, 0.82))
	queue_free()
