extends RefCounted
## skillbook_taunt — 도발 2변주(DRIFT-108):
##  · **AB-035 도전 선포**(`taunt_all: true`) — 반경 안의 적 **전체**. 광역의 대가로 `cast_s 2.5` 커밋.
##  · **AB-051 Shield Throw**(기본) — **단일** 대상, 대신 사거리 16m(원거리 풀링). 즉발.
## 표식 대상의 위협을 +mark_threat 만큼 올리고 threat floor를 세워 Tank에게 돌린다. 피해 없음.
## The +threat spike decays over a few seconds (≈ time-limited taunt); the floor keeps the Tank
## relevant after. ref: F-009 · F-022 · AB-035 · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_taunt"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center: Vector3 = target_pos if target_pos != Vector3.ZERO else m.global_position
	var radius := float(p.get("radius_m", 2.0))
	var spike := float(p.get("mark_threat", 120.0))
	var flr := float(p.get("floor", 50.0))
	var all := bool(p.get("taunt_all", false))   # AB-035 = 광역 · AB-051 = 단일
	var hit: CharacterBody3D = null
	var n := 0
	for e in ctx.enemies_in_radius(center, radius):
		if e == null or not is_instance_valid(e) or not e.has_method("add_threat"):
			continue
		e.add_threat(m, spike)
		if e.has_method("set_threat_floor"):
			e.set_threat_floor(m, flr)
		if e.has_method("apply_taunted"):
			e.apply_taunted(m, float(p.get("taunt_s", 6.0)))   # Taunted 마커(doctrine 조건·연장 대상)
		_force_engage(e, m)
		if hit == null:
			hit = e
		n += 1
		if not all:
			break   # 단일 도발(AB-051)
	if hit == null:
		return false
	SkillVfx.sub_taunt(ctx, center if all else hit.global_position, maxf(radius, 1.8))
	print("[SB] %s taunt — +%d threat on %d%s" % [m.class_id, int(spike), n, " (AoE)" if all else ""])
	return true


## ⚠️ 위협만 올리면 **비전투(dormant) 적은 안 온다**(DRIFT-108, 사용자 제보): `add_threat`는 수치만 쓰고
## `engaged`를 안 건드리는데, 도발은 피해가 0이라 `perceive_attacker`(피격 경로)도 안 탄다. → 도발은
## **정의상 교전을 강제하는 스킬**이므로 여기서 직접 끌어낸다. 귀환(leash) 중이었어도 취소.
## 분대 전파는 **일부러 안 한다**(`combat_controller._engage_enemy`의 squad 경로 미사용) — 도발이
## "자는 무리에서 원하는 놈만 떼어오는" 풀링 도구가 된다. 광역(AB-035)은 반경 안만 깨운다.
func _force_engage(e: CharacterBody3D, m: CharacterBody3D) -> void:
	if e.has_method("perceive_attacker"):
		e.perceive_attacker(m)   # engaged=true + grace(6s) + search_pos=시전자 → LOS 없어도 걸어온다
	e.returning = false
