extends RefCounted
## IDA-021 Iron Beacon (kind=beacon_threat) — narrow, threat-heavy guard: a small shield + a strong
## single-target threat floor on nearby foes. Trades Anchor Guard's fodder pulse for elite hold (F-022).
## Drop-in identity effect (ability_dispatch ctx facade). ref: GEAR-012/013 · DEC(gear catalog).

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "beacon_threat"


func cast(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3, ctx) -> bool:
	var foes: Array = ctx.enemies_in_radius(m.global_position, float(p.get("radius_m", 3.5)))
	if foes.is_empty():
		return false
	var shield_val: float = minf(float(p.get("shield_cap", 90.0)),
		float(p.get("shield_base", 40.0)) + float(p.get("shield_per_enemy", 10.0)) * foes.size())
	m.add_shield(shield_val, float(p.get("shield_duration_s", 4.0)))
	var pulse: float = float(p.get("threat_pulse", 90.0))
	var floor_v: float = float(p.get("threat_floor", 80.0))
	for e in foes:
		e.add_threat(m, pulse)
		e.set_threat_floor(m, floor_v)
	SkillVfx.anchor_guard(ctx, m.global_position, float(p.get("radius_m", 3.5)))
	print("[ID] %s Iron Beacon — shield %d, threat hold %d" % [m.identity_skill_id, int(shield_val), foes.size()])
	return true
