extends RefCounted
## AB-102 Snare Net (kind=skillbook_root) — **원거리 광역 「뭉치기 + 속박」 셋업기**(DRIFT-109 재정의).
## 조준점 반경의 적을 `gather_m`만큼 **중심으로 끌어모은 뒤** Rooted(이동만 잠금·행동은 가능)를 건다.
## **DPS 주력**(마법사 딜러) — 뒤이을 자기 광역기를 쉽게 맞히는 콤보 셋업이 존재 이유다.
## ⚠️ **`root_s`는 DPS 광역기 캐스트를 덮어야 한다**: 최장 `AB-041`(3.5s) + 투사체 비행(0.4s) →
## 4.0s. 2.0s였던 종전 값으론 캐스트가 끝나기 전에 풀려 콤보가 성립하지 않았다.
## 뭉치기는 폐기된 `sb_pull`의 `apply_knockback(중심−대상)` 기법을 여기로 되살린 것.
## Looted from EN-3RD-02(적도 동형 — 파티를 뭉쳐 자기 광역기를 꽂는다). ref: DEC-20260621-001 / F-009.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_root"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center := Vector3(target_pos.x, m.global_position.y, target_pos.z)
	var radius := float(p.get("radius_m", 2.5))
	var foes: Array = ctx.enemies_in_radius(center, radius)
	if foes.is_empty():
		return false
	var root_s := float(p.get("root_s", 4.0))
	var gather := float(p.get("gather_m", 3.0))
	var dmg: float = float(p.get("damage_mult", 0.2)) * m.basic_damage * float(p.get("_coeff", 1.0))
	for e in foes:
		if dmg > 0.0:
			ctx.deal_damage(e, m, dmg)
		# **뭉치기 먼저, 속박 나중** — 순서가 반대면 Rooted가 이동을 0으로 잠가 끌려오지 않는다.
		if gather > 0.0 and e.has_method("apply_knockback"):
			var to_c: Vector3 = center - e.global_position
			to_c.y = 0.0
			if to_c.length() > 0.1:
				e.apply_knockback(to_c, minf(gather, to_c.length()))   # 중심을 지나치지 않게 캡
		if e.has_method("apply_outcome"):
			e.apply_outcome("Rooted", root_s)
	ctx.sub_shake(p)
	SkillVfx.telegraph(ctx, center, Color(0.6, 0.5, 0.3), radius)  # net brown — 반경 그대로
	print("[SB] %s Snare Net — %d foes gathered(%.1fm)+Rooted(%.1fs)" % [m.class_id, foes.size(), gather, root_s])
	return true
