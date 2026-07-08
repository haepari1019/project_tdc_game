extends RefCounted
## skillbook_ward_heal — 수호-흡수 힐. 반경 내 가장 다친 아군(없으면 캐스터)에 보호막을 `ward_s`초 걸고, 종료 시
## 그동안 흡수한 피해량만큼 치유(ward_heal 노드 정산 → deal_heal 경유, 도트/성역 연동). 반응형 힐. ref: 힐러 킷 재설계.

const WardHeal := preload("res://scripts/combat/abilities/effects/ward_heal.gd")


func kind() -> String:
	return "skillbook_ward_heal"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	var radius := float(p.get("radius_m", 8.0))
	var amount := (float(p.get("shield", 0.0)) + float(m.max_hp) * float(p.get("shield_pct", 0.15))) * float(p.get("_coeff", 1.0))
	var dur := float(p.get("ward_s", 4.0))
	# 가장 다친 아군(HP 비율 최저)에 우선 — 없으면 캐스터 자신.
	var target: CharacterBody3D = m
	var worst := float(m.hp) / maxf(float(m.max_hp), 1.0)
	for a in ctx.allies_in_radius(m.global_position, radius):
		if a == null or not is_instance_valid(a):
			continue
		var r: float = float(a.hp) / maxf(float(a.max_hp), 1.0)
		if r < worst:
			worst = r
			target = a
	if not target.has_method("apply_ward_shield"):
		return false
	var node = WardHeal.new()
	ctx.add_child(node)
	node.setup(m, target, amount, dur, ctx)
	print("[SB] %s Ward Heal → %s (shield %d, %.1fs)" % [m.class_id, target.class_id, int(amount), dur])
	return true
