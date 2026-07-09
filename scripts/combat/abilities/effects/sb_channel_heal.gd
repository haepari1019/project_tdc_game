extends RefCounted
## skillbook_channel_heal — 집중 채널 힐(Q 짧은 집중 / R 긴 집중). **캐스트 시간(cast_s)은 cast_skillbook이 처리**
## (캐스트바·자기중심 범위 디스크·이동취소·완료 시 발현). 이 effect는 발현 시점에 반경 아군을 heal_pct만큼 치유.
## 최종 힐이 ctx.deal_heal 경유 → 지속치유=도트 전환 / 성역=증폭 자동 연동. ref: 힐러 킷 재설계 · DRIFT-075.


func kind() -> String:
	return "skillbook_channel_heal"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	var radius := float(p.get("radius_m", 6.0))
	var heal_pct := float(p.get("heal_pct", 0.2)) * float(p.get("_coeff", 1.0))
	var n := 0
	for a in ctx.allies_in_radius(m.global_position, radius):
		if a != null and is_instance_valid(a) and a.has_method("heal"):
			ctx.deal_heal(a, m, float(a.max_hp) * heal_pct)
			n += 1
	print("[SB] %s Channel Heal → %d ally (%d%%)" % [m.class_id, n, int(heal_pct * 100.0)])
	return n > 0
