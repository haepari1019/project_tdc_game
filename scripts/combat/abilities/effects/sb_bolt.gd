extends RefCounted
## Targeted ranged damage bolt (kind=skillbook_bolt) — **「광역 투사체」 원형은 AB-008**, 나머지는 그
## 변형(DRIFT-085). Damage = enemies in radius_m (single when small) × coeff; 속성 효과는 AB의
## `element`가 정하고 `ctx.element_hit`이 처리한다(전격=즉시 Shock + 전도 RX / 무속성=없음). Covers the ranged/burst
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
	if String(p.get("element", "")) == "lightning":
		SkillVfx.lightning_bolt(ctx, m.global_position, center, Elements.color_of("lightning"))
	resolve_at(m, center, p, ctx)
	ctx.sub_shake(p)
	return true


## Apply the bolt's hit at `center` — shared by the instant cast AND the projectile impact.
func resolve_at(m: CharacterBody3D, center: Vector3, p: Dictionary, ctx) -> void:
	var radius := float(p.get("radius_m", 1.5))
	var dmg: float = float(p.get("damage_mult", 1.0)) * m.basic_damage * float(p.get("_coeff", 1.0))
	var hits: Array = []
	for e in ctx.enemies_in_radius(center, radius):
		if e == null or not is_instance_valid(e) or not e.has_method("take_damage"):
			continue
		ctx.deal_damage(e, m, dmg)
		hits.append(e)
	# 속성은 AB의 `element`가 정한다 — 즉시 효과(전격=Shock) + RX(전도)를 seam이 처리. 무속성이면 no-op.
	ctx.element_hit(String(p.get("element", "")), center, radius, m, p, hits)
	SkillVfx.mark_ruin(ctx, center)                             # impact burst
