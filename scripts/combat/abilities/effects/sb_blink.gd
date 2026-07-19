extends RefCounted
## kind=skillbook_blink — short self-teleport up to blink_m. AB-006 Gap-Close (toward the aim point
## or nearest enemy; absorbed AB-061 Shadowstep's next_hit_bonus, DRIFT-085); AB-007a/b Retreat Hop
## (`away`=true → hop AWAY from **one specific enemy**: 007a = the aimed target(없으면 시전 거부),
## 007b = the engaged attacker(트랩이면 마지막 이동 방향의 반대). ref: F-009 · STATUS-OUTCOME · DRIFT-085.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_blink"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var dist := float(p.get("blink_m", 6.0))
	var away := bool(p.get("away", false))
	var to: Vector3
	var foe = null
	if away:   # AB-007a/b 이탈 — 「특정 적」의 반대로 튄다(막연한 최근접 아님, DRIFT-085)
		if bool(p.get("auto_disengage", false)):
			# 007b(자동) — 지금 싸우고 있는 상대. 존/트랩 피해면 상대가 없으므로(attacker=null)
			# 마지막으로 이동하던 방향의 반대로 물러난다(왔던 길로 되돌아감).
			foe = m.engaged_attacker() if m.has_method("engaged_attacker") else null
			if foe != null and is_instance_valid(foe):
				to = m.global_position - foe.global_position
			else:
				var mv: Vector3 = m.last_move_dir() if m.has_method("last_move_dir") else Vector3.ZERO
				to = -mv
		else:
			# 007a(액티브) — 적을 조준했을 때만 발동. 조준점 근처 최근접 1체 픽업(sb_stun 어시스트와 동일).
			var aim: Vector3 = target_pos if target_pos != Vector3.ZERO else m.global_position
			foe = ctx.nearest_enemy_in_range(aim, float(p.get("radius_m", 2.5)))
			if foe == null or not is_instance_valid(foe):
				return false   # 대상 없음 = no-op(차지·쿨 미소모)
			to = m.global_position - foe.global_position
	elif target_pos != Vector3.ZERO and target_pos.distance_to(m.global_position) > 0.3:
		to = target_pos - m.global_position
	else:
		foe = ctx.nearest_enemy_in_range(m.global_position, 20.0)
		to = (foe.global_position - m.global_position) if foe != null else Vector3(0, 0, 1)
	# AB-007a/b 이탈 — 후퇴 전 '마무리 한 방'. 대상 = **내가 벗어나는 그 적**(007a 조준 / 007b 교전 상대).
	# 트랩 이탈(007b, foe 없음)은 마무리딜 없음 — 벗어날 상대 자체가 없으므로.
	var ps := float(p.get("parting_shot_mult", 0.0))
	if ps > 0.0 and foe != null and is_instance_valid(foe):
		ctx.deal_damage(foe, m, m.basic_damage * ps)
		if ctx.has_method("report_hit_target"):
			ctx.report_hit_target(foe)   # 집중 결속이 마무리 대상에 집중 스택을 얹도록
	to.y = 0.0
	if to.length() < 0.1:
		to = Vector3(0, 0, 1)
	var start: Vector3 = m.global_position
	m.global_position += to.normalized() * (dist if away else minf(dist, to.length()))
	SkillVfx.dash_streak(ctx, start, m.global_position, Color(0.55, 0.38, 0.78))   # shadow blink trail
	# AB-007 이탈 — 어그로 감소(아군: 전 적 위협 −frac / 적 ctx: no-op)
	var ag := float(p.get("aggro_reduce", 0.0))
	if ag > 0.0 and ctx.has_method("reduce_threat"):
		ctx.reduce_threat(m, ag)
	var nhb := float(p.get("next_hit_bonus", 0.0))   # AB-006 Gap-Close — boost the next hit (ex-AB-061)
	if nhb > 0.0 and m.has_method("grant_next_hit_bonus"):
		m.grant_next_hit_bonus(nhb)
	return true
