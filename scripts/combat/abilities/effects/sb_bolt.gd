extends RefCounted
## Targeted ranged damage bolt (kind=skillbook_bolt) — fly to the aim point, damage enemies in
## radius_m (single when small) × coeff. If `lightning`, emit LightningHit (→ Shock RX on Water/Steam)
## and apply the Shock outcome (shock_s) to those hit; else a plain physical/arcane hit. Covers the
## remaining ranged/burst lootables that map to "throw a damaging bolt": AB-003 Arc Bolt Volley·
## AB-004 Charged Voltaic·AB-008 Slag Spit·AB-055 Scatter Shot·AB-056 Longshot·AB-058 Arc Detonation·
## AB-059 Void Lance·AB-073 Overcharge. Multi-hit/fork/charge spec shapes folded into one damage_mult
## (demo 근사). ref: F-009 · D-016 · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_bolt"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center: Vector3 = Vector3(target_pos.x, m.global_position.y, target_pos.z) if target_pos != Vector3.ZERO else m.global_position
	var radius := float(p.get("radius_m", 1.5))
	var dmg: float = float(p.get("damage_mult", 1.0)) * m.basic_damage * float(p.get("_coeff", 1.0))
	var lightning := bool(p.get("lightning", false))
	var shock := float(p.get("shock_s", 0.0))
	for e in ctx.enemies_in_radius(center, radius):
		if e == null or not is_instance_valid(e) or not e.has_method("take_damage"):
			continue
		ctx.deal_damage(e, m, dmg)
		if lightning:
			ctx.lightning_hit(e.global_position, 1.2, m)        # → Shock RX on Water/Steam
			if shock > 0.0 and e.has_method("apply_outcome"):
				e.apply_outcome("Shock", shock)                 # direct Shock (APPLY-SHOCK-2S)
	if lightning:
		SkillVfx.lightning_bolt(ctx, m.global_position, center, Color(0.62, 0.84, 1.0))
	else:
		SkillVfx.mark_ruin(ctx, center)                         # generic bolt impact (beam + burst)
	ctx.sub_shake(p)
	print("[SB] %s bolt @target (x%.1f%s)" % [m.class_id, float(p.get("damage_mult", 1.0)), " ⚡" if lightning else ""])
	return true
