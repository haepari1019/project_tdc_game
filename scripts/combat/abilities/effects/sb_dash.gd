extends RefCounted
## AB-013 Backstab Dash (kind=skillbook_dash) — 조준 적에게 **캐스터가 돌진(이동)** + **단일 데미지**.
## 누커가 근접으로 다이브 = 리스크 → `cast_s`로 커밋(짧은 캐스트). Tank의 `skillbook_charge`(전방 콘·다수
## 넉백)와 분리 — 이쪽은 단일 표적 접근+피해. 이동계열 접근+피해 슬롯(AB-006 gap-close=무피해 / AB-013=
## 접근+피해, DRIFT-085). 적 `enemy_dash`와 거동 통일. report_hit_target로 집중 결속이 이 명중을 훅한다.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_dash"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var radius := float(p.get("radius_m", 2.5))   # 조준점 근처 대상 픽업(선택 어시스트)
	var aim: Vector3 = target_pos if target_pos != Vector3.ZERO else m.global_position
	var e: CharacterBody3D = ctx.nearest_enemy_in_range(aim, radius)
	if e == null or not is_instance_valid(e):
		return false   # 대상 없음 = no-op(차지·쿨 미소모)
	# 돌진 — 대상 바로 앞까지 캐스터 이동(gap_m 남겨 겹침 방지)
	var to: Vector3 = Vector3(e.global_position.x - m.global_position.x, 0.0, e.global_position.z - m.global_position.z)
	var gap := float(p.get("gap_m", 1.4))
	var start: Vector3 = m.global_position
	if to.length() > gap:
		m.global_position += to.normalized() * (to.length() - gap)
	SkillVfx.dash_streak(ctx, start, m.global_position, Color(0.7, 0.4, 0.5))   # 돌진 잔상
	# 단일 데미지
	var dmg: float = float(p.get("damage_mult", 1.5)) * m.basic_damage * float(p.get("_coeff", 1.0))
	ctx.deal_damage(e, m, dmg)
	if ctx.has_method("report_hit_target"):
		ctx.report_hit_target(e)   # 집중/기타 결속이 이 명중 대상을 훅(캐스트 완료 후 _apply_binding)
	ctx.sub_shake(p)
	SkillVfx.sub_taunt(ctx, e.global_position, 1.4)   # 대상 위치 타격 플래시
	print("[SB] %s Backstab Dash → %s" % [m.class_id, e.name])
	return true
