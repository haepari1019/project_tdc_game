extends RefCounted
## AB-002 Shield Bash (kind=skillbook_strike) — AoE strike + knockback on nearby foes.
## Drop-in skillbook effect (ability_dispatch ctx facade). ref: F-009.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_strike"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	var radius := float(p.get("radius_m", 4.0))
	# 즉발 자기중심 AoE라 사전 조준이 없음 — 대신 발동 프레임에 반경 링을 띄워 "어디까지 맞는지"를
	# 보여주는 가이드. 명중 여부와 무관하게(헛스윙 포함) 항상 표시.
	SkillVfx.telegraph(ctx, m.global_position, Color(0.35, 0.6, 1.0, 0.55), radius)
	var dmg: float = float(p.get("damage_mult", 2.0)) * m.basic_damage * float(p.get("_coeff", 1.0))
	var foes: Array = ctx.enemies_in_radius(m.global_position, radius)
	var broke: bool = ctx.damage_destructibles(m.global_position, radius, dmg)
	var kb := float(p.get("knockback_m", 0.0))
	for e in foes:
		ctx.deal_damage(e, m, dmg)
		if kb > 0.0:
			e.apply_knockback(e.global_position - m.global_position, kb)
	if not foes.is_empty() or broke:
		ctx.sub_shake(p)
		SkillVfx.sub_taunt(ctx, m.global_position, float(p.get("radius_m", 4.0)))
	print("[SB] %s Shield Bash — %d foes" % [m.class_id, foes.size()])
	# 헛스윙도 스윙 — 맞은 대상이 없어도 차지 소모+쿨 시작(반응형 CC는 판정 성공이 아니라 휘두름이 비용).
	return true
