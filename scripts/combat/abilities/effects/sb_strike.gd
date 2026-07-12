extends RefCounted
## skillbook_strike — AoE strike. 두 shape: 기본 자기중심 radius(AB-002 Shield Bash) OR
## `shape:"rect"` 전방 직사각형 레인(AB-005 Melee Flurry — 조준/최근접 방향으로 length_m 전방·width_m 폭).
## Drop-in skillbook effect (ability_dispatch ctx facade). ref: F-009.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_strike"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var dmg: float = float(p.get("damage_mult", 2.0)) * m.basic_damage * float(p.get("_coeff", 1.0))
	var kb := float(p.get("knockback_m", 0.0))
	var foes: Array = []
	var broke: bool = false
	if String(p.get("shape", "radius")) == "rect":
		# 전방 직사각형 레인 — 조준점(있으면) 아니면 최근접 적 방향으로, length_m 전방 · width_m 폭.
		var length := float(p.get("length_m", 4.0))
		var width := float(p.get("width_m", 2.0))
		var axis := _forward_axis(m, target_pos, ctx, length)
		SkillVfx.rect_lane(ctx, m.global_position, axis, length, width, Color(0.35, 0.6, 1.0, 0.5))
		foes = ctx.enemies_in_rect(m.global_position, axis, length, width * 0.5)
		if foes.size() == 1:
			dmg *= float(p.get("single_target_mult", 1.0))  # 단일 대상 = 집중타 보너스(+50%)
		for e in foes:
			ctx.deal_damage(e, m, dmg)
			if kb > 0.0:
				e.apply_knockback(axis, kb)                 # 전방(스킬 범위 밖)으로 넉백
	else:
		var radius := float(p.get("radius_m", 4.0))
		SkillVfx.telegraph(ctx, m.global_position, Color(0.35, 0.6, 1.0, 0.55), radius)
		foes = ctx.enemies_in_radius(m.global_position, radius)
		broke = ctx.damage_destructibles(m.global_position, radius, dmg)
		for e in foes:
			ctx.deal_damage(e, m, dmg)
			if kb > 0.0:
				e.apply_knockback(e.global_position - m.global_position, kb)
	if ctx.has_method("report_hit_count"):
		ctx.report_hit_count(foes.size())               # focus_dump(AB-005) 단일/광역 판정용
	if not foes.is_empty() or broke:
		ctx.sub_shake(p)
		SkillVfx.sub_taunt(ctx, m.global_position, float(p.get("radius_m", p.get("width_m", 2.0))))
	print("[SB] %s skillbook_strike — %d foes" % [m.class_id, foes.size()])
	# 헛스윙도 스윙 — 맞은 대상이 없어도 차지 소모+쿨 시작(반응형 CC/커밋 버스트는 휘두름이 비용).
	return true


## 전방 축 — 조준점(target_pos≠0)이 있으면 그 방향, 없으면 최근접 적, 둘 다 없으면 기본 전방(+Z).
func _forward_axis(m: CharacterBody3D, target_pos: Vector3, ctx, reach: float) -> Vector3:
	var axis: Vector3 = (target_pos - m.global_position) if target_pos != Vector3.ZERO else Vector3.ZERO
	axis.y = 0.0
	if axis.length() < 0.1:
		var nearest = ctx.nearest_enemy_in_range(m.global_position, reach)
		if nearest != null and is_instance_valid(nearest):
			axis = nearest.global_position - m.global_position
			axis.y = 0.0
	return axis.normalized() if axis.length() > 0.1 else Vector3(0, 0, 1)
