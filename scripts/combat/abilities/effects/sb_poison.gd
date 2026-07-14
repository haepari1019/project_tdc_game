extends RefCounted
## AB-010 Venom Spit (kind=skillbook_poison) — 자기중심 AoE 시전. 맞은 적에게 소량 즉발 피해 +
## **스택형 독 DoT 디버프**(apply_poison_stack: 재적용마다 dps 누적 → 두 번 걸면 틱 배증). 스택은 cap 상한.
## Drop-in skillbook effect. ref: F-009 · outcome_status Poison.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_poison"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var radius := float(p.get("radius_m", 5.0))
	var center: Vector3 = target_pos if target_pos != Vector3.ZERO else m.global_position   # 논타겟 지면 조준 착탄점(AI/조준없음 = 자기중심)
	var foes: Array = ctx.enemies_in_radius(center, radius)
	if foes.is_empty():
		return false
	var coeff := float(p.get("_coeff", 1.0))
	var direct: float = float(p.get("damage_mult", 0.3)) * m.basic_damage * coeff    # 소량 즉발
	var unit_dps: float = float(p.get("poison_dps", 8.0))                            # 스택 1개의 기본 DoT dps
	var add_dps: float = unit_dps * coeff                                            # 이번 시전이 얹는 dps(=1스택)
	var dur := float(p.get("poison_dur_s", 8.0))
	var cap: float = unit_dps * float(p.get("poison_stack_cap", 5))                  # 최대 누적(스택 cap 기준)
	for e in foes:
		if direct > 0.0:
			ctx.deal_damage(e, m, direct)
		if e.has_method("apply_poison_stack"):
			e.apply_poison_stack(dur, add_dps, cap, unit_dps)   # 스택 독 디버프(1스택) — unit 기준 표시
	ctx.sub_shake(p)
	SkillVfx.sub_nova(ctx, center, radius)
	print("[SB] %s Venom Spit — %d foes poisoned" % [m.class_id, foes.size()])
	return true
