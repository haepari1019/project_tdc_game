extends RefCounted
## skillbook_channel_heal — 집중 채널 힐(Q 짧은 집중 / R 긴 집중). `channel_s`초 집중(점유+이동잠금) 후 완료 시
## 반경 아군을 `heal_pct`만큼 치유. 최종 힐이 ctx.deal_heal 경유 → 지속치유=도트 전환 / 성역=증폭 자동 연동.
## 중단(스턴/다운) 시 힐 없음(커밋형). ref: 힐러 킷 재설계(DoT 서브 → 채널/수호 교체).

const ChannelHeal := preload("res://scripts/combat/abilities/effects/channel_heal.gd")


func kind() -> String:
	return "skillbook_channel_heal"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	if m.has_method("is_channeling") and m.is_channeling():
		return false   # 이미 집중 중 → 중복 시전 차단
	var channel_s := float(p.get("channel_s", 2.0))
	var heal_pct := float(p.get("heal_pct", 0.2)) * float(p.get("_coeff", 1.0))
	var radius := float(p.get("radius_m", 6.0))
	var slot := int(p.get("_slot", -1))
	var node = ChannelHeal.new()
	ctx.add_child(node)
	node.setup(m, slot, heal_pct, radius, channel_s, ctx)
	if m.has_method("begin_channel"):
		m.begin_channel(channel_s)             # 점유 = 다른 서브 시전 차단(이동 잠금은 제거 — 이동 시 취소로 대체)
	print("[SB] %s Channel Heal — %.1fs 집중 → %d%% 힐" % [m.class_id, channel_s, int(heal_pct * 100.0)])
	return true
