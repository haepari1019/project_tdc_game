extends RefCounted
## AB-046 Shield Wall (**자기만**, radius~0.5) / AB-047 Aegis Pulse (**주변 아군 전체**, radius 4) /
## AB-068 Warding Sigil (Healer 자기) — kind=skillbook_dr. 반경이 곧 대상 범위이자 두 스킬의 유일한
## 차이축이라 툴팁도 여기서 갈린다(skill_text `skillbook_dr_party`). T2 판정 2026-07-28 · DRIFT-102.
## Temporary damage reduction to allies in radius (caster included). Reuses member.damage_taken_mult
## (no move-lock, unlike Sentinel Form). Drop-in skillbook effect. ref: F-009 · STATUS Fortified/Warded.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")
const AURA_R := 0.9                                  # 개인 오오라 링 반경(대상 발밑) — 반경 params와 무관
const AURA_COLOR := Color(0.97, 0.86, 0.35)          # 시전 펄스(sub_sanctuary)와 같은 금색 = 같은 효과로 읽히게


func kind() -> String:
	return "skillbook_dr"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	var radius := float(p.get("radius_m", 0.5))
	var dr := clampf(float(p.get("damage_reduction", 0.3)), 0.0, 1.0)
	# 지속(초) 기반 — 타수형은 되돌렸다(DRIFT-104). `dr_label` = 버프 칩 이름(스택 분리 키).
	var dur := float(p.get("duration_s", 3.0))
	var label := String(p.get("dr_label", "피해 감소"))
	var n := 0
	for a in ctx.allies_in_radius(m.global_position, radius):
		if a != null and is_instance_valid(a) and a.has_method("apply_damage_reduction"):
			a.apply_damage_reduction(dr, dur, label, Color(0.6, 0.8, 1.0))
			# **지속형 오오라**(DRIFT-106) — 버프를 받은 **각 유닛**에 붙어 지속 동안 따라다닌다.
			# ⚠️ 캐스터의 radius에 거는 게 아니다: DR은 시전 순간 반경 안에 있던 대상에게 1회 부여될
			# 뿐 "안에 서 있어야 유지"되는 필드가 아니라서, 캐스터에 큰 링을 깔면 규칙을 오독하게 된다.
			SkillVfx.aura_field(a, AURA_R, AURA_COLOR, dur, "dr_" + label)
			n += 1
	SkillVfx.sub_sanctuary(ctx, m.global_position, maxf(radius, 1.2))   # 시전 순간 큐(금색 돔/펄스)
	print("[SB] %s %s DR %d%% / %.1fs → %d ally" % [m.class_id, label, int(dr * 100), dur, n])
	return n > 0
