extends RefCounted
## AB-012 Hex Bolt (kind=skillbook_polymorph) — TARGETED single-target POLYMORPH. 조준점 근처 최근접 1체를
## poly_dur_s 동안 **개구리로 변이**: 공격/시전 불가·컨트롤(AI/플레이어 지시) 무력·랜덤 hopping. **어떤 피해든
## 받으면 즉시 해제**(sheep式). 힐러 정화(AB-070)로 아군 개구리 해제. 직접 피해 없음. Shared — 적도 동일 변이를
## 아군에게 건다(enemy_ai enemy_hex → apply_polymorph). 시나리오: 까다로운 엘리트를 잠시 묶고 잡몹 먼저 처리.
## cast_s로 구동(band B ~3s 커밋). ref: F-009 · aim_controller UNIT_AIM_KINDS · DRIFT-098 후속.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_polymorph"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	# 타겟팅형 — 조준점 근처 최근접 적 1체를 변이(선택 어시스트). 대상 없으면 no-op(차지 미소모).
	var radius := float(p.get("radius_m", 1.6))
	var aim: Vector3 = target_pos if target_pos != Vector3.ZERO else m.global_position
	var e: CharacterBody3D = ctx.nearest_enemy_in_range(aim, radius)
	if e == null or not is_instance_valid(e) or not e.has_method("apply_polymorph"):
		return false
	e.apply_polymorph(float(p.get("poly_dur_s", 30.0)))
	SkillVfx.telegraph(ctx, e.global_position, Color(0.55, 0.9, 0.45), 1.4)   # 개구리 변이 마크(초록)
	print("[SB] %s Hex Bolt → %s polymorphed %.0fs" % [m.class_id, e.name, float(p.get("poly_dur_s", 30.0))])
	return true
