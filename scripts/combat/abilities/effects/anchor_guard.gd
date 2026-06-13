extends RefCounted
## AB-020 Anchor Guard (kind=shield_pulse) — self shield + threat pulse when foes in radius.
## Drop-in skill effect (ability_dispatch ctx facade). ref: F-022 §3.10.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")
const TANK_PULSE_FLOOR := 40.0    # F-022 §3.10 Anchor Guard temp threat floor


func kind() -> String:
	return "shield_pulse"


func cast(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3, ctx) -> bool:
	var foes: Array = ctx.enemies_in_radius(m.global_position, float(p.get("radius_m", 5.0)))
	if foes.is_empty():
		return false
	var shield_val: float = minf(
		float(p.get("shield_cap", 160.0)),
		float(p.get("shield_base", 80.0)) + float(p.get("shield_per_enemy", 20.0)) * foes.size()
	)
	m.add_shield(shield_val, float(p.get("shield_duration_s", 4.0)))
	# F-022 §3.10: threat pulse to affected foes — tank holds aggro w/o damage race.
	var pulse: float = float(p.get("threat_pulse", 0.0))
	if pulse > 0.0:
		for e in foes:
			e.add_threat(m, pulse)
			e.set_threat_floor(m, TANK_PULSE_FLOOR)
	SkillVfx.anchor_guard(ctx, m.global_position, float(p.get("radius_m", 5.0)))
	print("[ID] %s Anchor Guard — shield %d (%d foes)" % [m.identity_skill_id, int(shield_val), foes.size()])
	return true
