extends RefCounted
## AB-106 Devour (kind=skillbook_execute) — finisher on the aimed enemy: bonus damage vs low-HP
## prey (×execute_mult under execute_under), and **ON-KILL-FEED**: 처치하면 회복 + **남은 쿨 일부 환급**.
## 스펙(D-016 AB-106)이 060과의 차별점으로 못박은 **킬-보상 루프**인데 환급이 빠져 있었다(DRIFT-132).
## 「다음 먹이로 연쇄」가 이 스킬의 정체성이라 회복만으로는 루프가 닫히지 않는다.
## Looted from EN-3RD-03. Nuker. ref: DEC-20260621-001 / F-009.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_execute"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center := Vector3(target_pos.x, m.global_position.y, target_pos.z)
	var tgt: CharacterBody3D = ctx.resolve_target(p, center, float(p.get("radius_m", 2.0)))
	if tgt == null:
		return false
	var dmg: float = float(p.get("damage_mult", 1.0)) * m.basic_damage * float(p.get("_coeff", 1.0))
	if tgt.hp <= tgt.max_hp * float(p.get("execute_under", 0.3)):
		dmg *= float(p.get("execute_mult", 2.0))
	ctx.deal_damage(tgt, m, dmg)
	# ON-KILL-FEED — 처치하면 회복 + 남은 쿨 환급으로 「다음 먹이」로 이어진다.
	if not tgt.has_method("is_alive") or not tgt.is_alive():
		if m.has_method("heal"):
			m.heal(m.max_hp * float(p.get("on_kill_heal_pct", 0.2)))
		# 쿨은 **절반만** 돌려준다(사용자 판정) — 전액 환급이면 저HP 무리에서 무한 연발이 된다.
		# 여기서 `inst.cooldown_s`를 직접 깎으면 소용없다: `cast_s>0` 경로는 효과 해소 **뒤에**
		# 쿨을 통째로 덮어쓴다. 그래서 프랙션만 보고하고 디스패처가 쿨을 건 직후 접는다. DRIFT-132.
		ctx.report_cd_refund(float(p.get("on_kill_cd_refund", 0.5)))
	ctx.sub_shake(p)
	SkillVfx.telegraph(ctx, tgt.global_position, Color(0.85, 0.05, 0.15))
	print("[SB] %s Devour → enemy" % m.class_id)
	return true
