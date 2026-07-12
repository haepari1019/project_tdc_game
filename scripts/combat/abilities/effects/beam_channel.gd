extends Node3D
## AB-054 Rending Beam channel — a self-ticking line beam from a FIXED origin + direction (captured
## at cast). Each tick: damage enemies in the forward cone, emit LightningHit (→ Shock RX on
## Water/Steam), flash the bolt. A DEPLETING channel bar (drains right→left, distinct teal color vs
## the filling blue cast bar) sits over the caster. The channel is NOT a move-lock: it ENDS EARLY if
## the caster MOVES from the cast spot, is downed/stunned, or starts another cast (cancel_channel).
## Self-frees when the ticks are spent. ref: AB-054 · F-009 · STATUS Channeling/Shock · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")
const CastBar := preload("res://scripts/combat/abilities/effects/cast_bar.gd")
const MOVE_CANCEL_M := 0.3            # 시전 지점에서 이 거리 이상 움직이면 채널 취소(이동=중단)
const CHANNEL_BAR_COLOR := Color(0.35, 0.9, 0.85)  # 캐스팅(파랑)과 구분되는 채널 전용 색(청록)

var _caster: CharacterBody3D
var _origin: Vector3
var _dir: Vector3
var _range: float
var _half: float            # cone half-angle (rad)
var _dmg: float             # per-tick damage
var _interval: float
var _ticks_left: int
var _ctx
var _t: float = 0.0
var _bar                    # CastBar (depleting) over the caster
var _elapsed: float = 0.0
var _total_dur: float = 0.0
var _finished: bool = false


func setup(caster: CharacterBody3D, origin: Vector3, dir: Vector3, range_m: float, half_deg: float,
		dmg_per_tick: float, ticks: int, interval: float, ctx) -> void:
	_caster = caster
	_origin = origin
	_dir = dir
	_range = range_m
	_half = deg_to_rad(half_deg)
	_dmg = dmg_per_tick
	_ticks_left = ticks
	_interval = interval
	_ctx = ctx
	# 첫 틱은 즉발(t=0), 마지막 틱은 (ticks-1)*interval에 발사 → 그 시점에 채널 종료.
	# 바가 정확히 그때 0에 닿도록 총 지속을 (ticks-1)*interval로 잡는다.
	_total_dur = maxf(float(ticks - 1) * interval, 0.001)
	global_position = origin
	# Depleting channel bar (starts full, drains) — reuses CastBar fed the REMAINING fraction, so the
	# fill recedes leftward (opposite of a cast bar filling rightward). Teal to differentiate.
	_bar = CastBar.new()
	add_child(_bar)
	_bar.setup(caster, 2.9, CHANNEL_BAR_COLOR)
	_bar.set_progress(1.0)
	_do_tick()  # first tick fires immediately (the beam "connects" on cast)


func _process(delta: float) -> void:
	if _finished:
		return
	# Interrupt: caster gone / downed / stunned, OR the caster moved off the cast spot (moving cancels).
	if _caster == null or not is_instance_valid(_caster) or not _caster.is_alive() \
			or (_caster.has_method("is_stunned") and _caster.is_stunned()) \
			or _caster.global_position.distance_to(_origin) > MOVE_CANCEL_M:
		_finish()
		return
	_elapsed += delta
	if _bar != null and is_instance_valid(_bar):
		_bar.set_progress(clampf(1.0 - _elapsed / maxf(_total_dur, 0.001), 0.0, 1.0))  # drain
	_t += delta
	if _t >= _interval:
		_t -= _interval
		_do_tick()
		if _ticks_left <= 0:
			_finish()


## Public interrupt — a new cast (interrupt_active_channel) cancels the remaining channel.
func cancel_channel() -> void:
	_finish()


## End (natural completion OR interrupt): drop the bar, release the caster's channel ref, self-free.
func _finish() -> void:
	if _finished:
		return
	_finished = true
	if _caster != null and is_instance_valid(_caster) and _caster.has_method("clear_active_channel"):
		_caster.clear_active_channel(self)
	queue_free()


func _do_tick() -> void:
	_ticks_left -= 1
	var end: Vector3 = _origin + _dir * _range
	for e in _ctx.enemies_in_cone(_origin, _dir, _range, _half):
		if e != null and is_instance_valid(e) and e.has_method("take_damage"):
			_ctx.deal_damage(e, _caster, _dmg)
			_ctx.lightning_hit(e.global_position, 1.2, _caster)  # → Shock RX on conductive media
	SkillVfx.lightning_bolt(_ctx, _origin, end, Color(0.70, 0.85, 1.0))
