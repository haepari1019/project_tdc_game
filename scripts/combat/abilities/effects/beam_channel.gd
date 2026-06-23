extends Node3D
## AB-054 Rending Beam channel — a self-ticking line beam from a FIXED origin + direction (captured
## at cast). Each tick: damage enemies in the forward cone, emit LightningHit (→ Shock RX on
## Water/Steam), flash the bolt. The caster is move-locked (Rooted) for the channel by sb_beam; this
## node ENDS EARLY if the caster is downed/stunned (channel interrupt, EN-AI-000 §2). Self-frees when
## the ticks are spent. ref: AB-054 · F-009 · STATUS Channeling/Shock · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")

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
	global_position = origin
	_do_tick()  # first tick fires immediately (the beam "connects" on cast)


func _process(delta: float) -> void:
	# Interrupt: caster gone / downed / stunned cancels the remaining channel.
	if _caster == null or not is_instance_valid(_caster) or not _caster.is_alive() \
			or (_caster.has_method("is_stunned") and _caster.is_stunned()):
		queue_free()
		return
	_t += delta
	if _t >= _interval:
		_t -= _interval
		_do_tick()
		if _ticks_left <= 0:
			queue_free()


func _do_tick() -> void:
	_ticks_left -= 1
	var end: Vector3 = _origin + _dir * _range
	for e in _ctx.enemies_in_cone(_origin, _dir, _range, _half):
		if e != null and is_instance_valid(e) and e.has_method("take_damage"):
			_ctx.deal_damage(e, _caster, _dmg)
			_ctx.lightning_hit(e.global_position, 1.2, _caster)  # → Shock RX on conductive media
	SkillVfx.lightning_bolt(_ctx, _origin, end, Color(0.70, 0.85, 1.0))
