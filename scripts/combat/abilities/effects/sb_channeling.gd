extends RefCounted
## **채널링 단일 kind**(kind=`skillbook_channeling`) — 제자리에 서서 여러 틱에 걸쳐 효과를 굴리는
## 스킬 전부가 여기로 모인다. 형상은 `channel_shape`가 가르고, 속성은 `element`가 정한다(DRIFT-088).
## 예전 kind 이름은 `skillbook_beam`이었다 — 클러스터가 「빔」에서 **「채널링」**으로 재정의되면서
## 빔은 4형상 중 하나(`line`)가 됐다(사용자 판정, DRIFT-115). 원형-변형 체계는 볼트(DRIFT-085/111)와
## 같은 방식이다: **한 kind + params 분기**, 새 형상은 데이터로 늘린다.
##
##   AB-054 절단 광선   `line`  · lightning — 직선 관통(원형)
##   AB-109 화염 분사   `cone`  · fire      — 틱마다 앞으로 뻗는 부채꼴
##   AB-110 독무 살포   `cloud` · poison    — 조준점 구름, 틱마다 독 스택
##   AB-111 냉기 폭풍   `nova`  · cold      — 자기중심 원형, 완주 시 빙결
##
## 채널은 **이동하면 끊긴다**(ChannelField.MOVE_CANCEL_M) — 형상과 무관한 공통 계약이다.
## ref: F-009 · D-016 · DRIFT-057/115.

const ChannelField := preload("res://scripts/combat/abilities/effects/channel_field.gd")


func kind() -> String:
	return "skillbook_channeling"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var shape := String(p.get("channel_shape", "line"))
	var range_m := float(p.get("range_m", 14.0))
	var dir: Vector3
	if target_pos != Vector3.ZERO:
		dir = target_pos - m.global_position
	else:
		var tgt = ctx.nearest_enemy_in_range(m.global_position, 20.0)
		dir = (tgt.global_position - m.global_position) if tgt != null else Vector3(0, 0, 1)
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	# 기하 원점 — `cloud`만 **조준점**에 선다(사거리 밖이면 잘라서 최대 사거리 지점에 건다).
	# 나머지 형상은 캐스터 자신이 원점이다(line·cone은 앞으로, nova는 사방으로).
	var origin: Vector3 = m.global_position
	if shape == "cloud" and target_pos != Vector3.ZERO:
		var to: Vector3 = target_pos - m.global_position
		to.y = 0.0
		if to.length() > range_m:
			to = to.normalized() * range_m
		origin = m.global_position + to
	var ticks := int(p.get("ticks", 6))
	var interval := float(p.get("tick_interval_s", 0.18))
	var half_deg := float(p.get("half_deg", 7.0))
	var coeff := float(p.get("_coeff", 1.0))
	var dmg := float(m.basic_damage) * float(p.get("tick_mult", 0.25)) * coeff
	var ch = ChannelField.new()
	ctx.add_child(ch)
	ch.setup(m, origin, dir, range_m, half_deg, dmg, ticks, interval, ctx, p)
	# The channel is NOT a move-lock/occupy — the caster stays free to move or cast, but doing either
	# INTERRUPTS it (channel_field watches caster drift; a new cast calls interrupt_active_channel).
	# Register the node so a later cast can cancel it. Caster can still be hit; ends on downed/stunned.
	if m.has_method("set_active_channel"):
		m.set_active_channel(ch)
	ctx.sub_shake(p)
	print("[SB] %s 채널 %s — %d tick x%d%% over %.1fs" % [m.class_id, shape, ticks,
		int(float(p.get("tick_mult", 0.25)) * 100.0), float(ticks) * interval])
	return true
