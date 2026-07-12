extends RefCounted
## Targeted ranged damage bolt (kind=skillbook_bolt). Damage = enemies in radius_m (single when small)
## × coeff; if `lightning`, emit LightningHit (→ Shock RX) + apply Shock. Covers the ranged/burst
## lootables AB-003/004/008/055/056/058/059/073 (multi-hit/fork/charge folded into one damage_mult).
##
## DELIVERY (DRIFT-059): `instant` (default) resolves at the aim point now; `projectile` spawns a
## traveling Projectile that calls resolve_at() on impact (blocked by walls / absorbed by Rampart).
## resolve_at() is the shared hit, so both paths run identical gameplay. ref: F-009 · D-016 · DRIFT-057/059.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_bolt"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center: Vector3 = Vector3(target_pos.x, m.global_position.y, target_pos.z) if target_pos != Vector3.ZERO else m.global_position
	if String(p.get("delivery", "instant")) == "projectile":
		if bool(p.get("arc_vfx", false)):          # AB-004 「전격 사격」 시그니처 — 지리릿 번개 크래클(발사 순간)
			SkillVfx.lightning_bolt(ctx, m.global_position, center, Color(0.55, 0.8, 1.0))
		ctx.spawn_projectile(self, m, center, p)   # entity travels → resolve_at() on impact
		ctx.sub_shake(p)
		print("[SB] %s bolt → projectile @target (x%.1f)" % [m.class_id, float(p.get("damage_mult", 1.0))])
		return true
	# Instant: no travel entity → draw the bolt streak from the caster, then resolve at the point.
	if bool(p.get("lightning", false)):
		SkillVfx.lightning_bolt(ctx, m.global_position, center, Color(0.62, 0.84, 1.0))
	resolve_at(m, center, p, ctx)
	ctx.sub_shake(p)
	return true


## Apply the bolt's hit at `center` — shared by the instant cast AND the projectile impact.
func resolve_at(m: CharacterBody3D, center: Vector3, p: Dictionary, ctx) -> void:
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
	SkillVfx.mark_ruin(ctx, center)                             # impact burst
