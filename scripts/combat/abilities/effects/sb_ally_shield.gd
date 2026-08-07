extends RefCounted
## 흡수 보호막 (kind=skillbook_shield) — `shield_pct × 대상 maxHP + flat`, × coeff.
## **두 형상**(H3 판정, DRIFT-116) — 힐러 방어 4종을 **대상**으로 갈랐다:
##   · `targeted: true`(AB-067 Aegis Blessing) — **조준점 최근접 아군 1인**. 예전엔 `radius 0.5`
##     자기중심이라 힐러가 자기만 지키는 칸이 AB-068(자기 DR)과 **둘**이었다. "축복"이라는 이름값도
##     남에게 거는 쪽이다.
##   · 미지정(AB-075 Blessed Barrier) — 캐스터 중심 `radius_m` 파티 광역(종전 거동).
## 단일 대상 선택은 **조준점 최근접**이다 — 이 레포엔 아군 클릭 타겟팅이 없어(sb_relocate_ally 주석
## 참조) 적 단일기(sb_stun/sb_taunt)가 쓰는 방식을 그대로 따른다. 반경이 곧 "집는 관용 범위".
## ref: F-009 · IDA-020 Shield Policy · DRIFT-057/116.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_shield"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var radius := float(p.get("radius_m", 0.5))
	var pct := float(p.get("shield_pct", 0.0))
	var flat := float(p.get("shield", 0.0))
	var dur := float(p.get("duration_s", 6.0))
	var coeff := float(p.get("_coeff", 1.0))
	var center: Vector3 = m.global_position
	var single := bool(p.get("targeted", false)) and target_pos != Vector3.ZERO
	if single:
		center = Vector3(target_pos.x, m.global_position.y, target_pos.z)
	var n := 0
	for a in ctx.allies_in_radius(center, radius):
		if a == null or not is_instance_valid(a) or not a.has_method("add_shield"):
			continue
		a.add_shield((float(a.max_hp) * pct + flat) * coeff, dur)
		SkillVfx.sub_taunt(ctx, a.global_position, 1.2)   # 대상 위 파란 보호 돔
		n += 1
		if single:
			break                                          # 지정형 = 최근접 1인만
	if n == 0:
		return false                                       # 아무도 못 감쌌으면 차지 소모 안 함
	if not single:
		SkillVfx.sub_taunt(ctx, center, maxf(radius, 1.2))
	print("[SB] %s 보호막 — %s %d명" % [m.class_id, "지정" if single else "광역", n])
	return true
