extends RefCounted
## AB-054 Rending Beam (kind=skillbook_beam) — channel a Long line beam toward the aim point: `ticks`
## hits of `tick_mult`×base over the channel, each emitting LightningHit (→ Shock RX on Water/Steam).
## Spawns a self-ticking beam_channel node (origin + direction fixed at cast, so the beam holds its
## line even if the caster shifts). The channel does NOT root or occupy the caster — instead moving,
## casting another skill, or being downed/stunned INTERRUPTS it (beam_channel watches for those).
## ref: F-009 · AB-054 · DRIFT-057.

const BeamChannel := preload("res://scripts/combat/abilities/effects/beam_channel.gd")


func kind() -> String:
	return "skillbook_beam"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var dir: Vector3
	if target_pos != Vector3.ZERO:
		dir = target_pos - m.global_position
	else:
		var tgt = ctx.nearest_enemy_in_range(m.global_position, 20.0)
		dir = (tgt.global_position - m.global_position) if tgt != null else Vector3(0, 0, 1)
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	var range_m := float(p.get("range_m", 14.0))
	var ticks := int(p.get("ticks", 6))
	var interval := float(p.get("tick_interval_s", 0.18))
	var half_deg := float(p.get("half_deg", 7.0))
	var coeff := float(p.get("_coeff", 1.0))
	var dmg := float(m.basic_damage) * float(p.get("tick_mult", 0.25)) * coeff
	var beam = BeamChannel.new()
	ctx.add_child(beam)
	beam.setup(m, m.global_position, dir, range_m, half_deg, dmg, ticks, interval, ctx)
	# The channel is NOT a move-lock/occupy — the caster stays free to move or cast, but doing either
	# INTERRUPTS the beam (beam_channel watches caster drift; a new cast calls interrupt_active_channel).
	# Register the node so a later cast can cancel it. Caster can still be hit; ends on downed/stunned.
	if m.has_method("set_active_channel"):
		m.set_active_channel(beam)
	ctx.sub_shake(p)
	print("[SB] %s Rending Beam — %d tick x%d%% over %.1fs" % [m.class_id, ticks, int(float(p.get("tick_mult", 0.25)) * 100.0), float(ticks) * interval])
	return true
