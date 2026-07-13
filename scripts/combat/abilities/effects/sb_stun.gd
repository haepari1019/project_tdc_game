extends RefCounted
## AB-011 Toll Stun (kind=skillbook_stun) — TARGETED single-target strike + STUN: freezes ONE aimed
## enemy AND interrupts its channel (EN-AI-000 §2 counterplay — e.g. cancel EN-001's Mockery). 조준점
## 근처 최근접 1체 선택(어시스트). ref: F-009 · aim_controller UNIT_AIM_KINDS.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_stun"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	# 타겟팅형 — 조준점 근처 최근접 적 1체를 기절(선택 어시스트). 대상 없으면 no-op(차지 미소모).
	var radius := float(p.get("radius_m", 2.5))   # 선택 허용 반경(조준점 근처 픽업)
	var aim: Vector3 = target_pos if target_pos != Vector3.ZERO else m.global_position
	var e: CharacterBody3D = ctx.nearest_enemy_in_range(aim, radius)
	if e == null or not is_instance_valid(e):
		return false
	var dmg: float = float(p.get("damage_mult", 0.6)) * m.basic_damage * float(p.get("_coeff", 1.0))
	ctx.deal_damage(e, m, dmg)
	if e.has_method("apply_stun"):
		e.apply_stun(float(p.get("stun_s", 1.4)))    # real stun → freezes + interrupts channels (EN-AI-000 §2)
	else:
		e.apply_slow(0.05, float(p.get("stun_s", 1.4)))
	ctx.sub_shake(p)
	SkillVfx.sub_taunt(ctx, e.global_position, 1.4)   # 대상 위치 타격 플래시
	print("[SB] %s Toll Stun → %s" % [m.class_id, e.name])
	return true
