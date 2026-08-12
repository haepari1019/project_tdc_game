extends RefCounted
## kind=skillbook_silence — 대상을 `Silenced`(silence_s, ccTenacity 적용)로 봉인한다. 침묵 중엔
## **액티브 스킬 시전만** 막히고 이동·평타는 남는다(enemy_ai가 캐스트를 게이트).
## **진행 중인 시전도 끊는다**(DRIFT-133) — 단 이건 *반응해서 끊는 도구*라는 뜻이 아니다.
## AB-030은 자기 `cast_s`가 1.5s라 적 텔레그래프(0.2~1.0s)에 맞춰 대응할 수 없다.
## **타이밍이 얻어걸렸을 때만 캐스트가 무산되는 보너스**이고, 본 목적은 3초간의 「제압」이다.
##
## **2변주(DRIFT-133):**
##  · `AB-044` Hush Ward (Healer) — **광역·무피해**. 여럿을 한 번에 봉인.
##  · `AB-030` 전격 제압 (Nuker) — **단일 잠금 + 타격**(`damage_mult`). 저격수가 한 명을 찍어 묶는다.
## 차이축은 **대상 수와 피해 유무**뿐이라 한 파일에서 받는다(sb_dr·sb_shield 변주와 같은 방식).
## 대상 선정은 `resolve_targets`가 `single_target` 잠금을 존중한다. ref: F-009 · DRIFT-057/122/133.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_silence"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center: Vector3 = target_pos if target_pos != Vector3.ZERO else m.global_position
	var radius := float(p.get("radius_m", 2.0))
	var dur := float(p.get("silence_s", 3.0))
	# 잠금 스킬이면 조준한 그 유닛만, 아니면 반경 전체(광역 변주).
	var dmg: float = float(p.get("damage_mult", 0.0)) * m.basic_damage * float(p.get("_coeff", 1.0))
	var n := 0
	for e in ctx.resolve_targets(p, center, radius):
		if e == null or not is_instance_valid(e) or not e.has_method("apply_silence"):
			continue
		if dmg > 0.0:
			ctx.deal_damage(e, m, dmg)   # 타격 변주(AB-030) — 봉인이 「맞히는 것」과 함께 온다
		e.apply_silence(dur)
		SkillVfx.telegraph(ctx, e.global_position, Color(0.62, 0.42, 0.95), 1.4)   # seal rune
		n += 1
	if n == 0:
		return false   # no enemy in range → don't spend a charge
	if dmg <= 0.0:
		SkillVfx.telegraph(ctx, center, Color(0.62, 0.42, 0.95), maxf(radius, 1.5))   # 광역 변주만 반경 표기
	ctx.sub_shake(p)
	print("[SB] %s silence — %d sealed (%.1fs)" % [m.class_id, n, dur])
	return true
