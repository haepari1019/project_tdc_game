extends RefCounted
## Targeted ranged damage bolt (kind=skillbook_bolt) — **「광역 투사체」 원형은 AB-008**, 나머지는 그
## 변형(DRIFT-085). Damage = enemies in radius_m (single when small) × coeff; 속성 효과는 AB의
## `element`가 정하고 `ctx.element_hit`이 처리한다(전격=즉시 Shock + 전도 RX / 무속성=없음). Covers the ranged/burst
## lootables AB-003/004/008/055/056/058/059/073 (multi-hit/fork/charge folded into one damage_mult).
##
## DELIVERY (DRIFT-059): `instant` (default) resolves at the aim point now; `projectile` spawns a
## traveling Projectile that calls resolve_at() on impact (blocked by walls / absorbed by Rampart).
## resolve_at() is the shared hit, so both paths run identical gameplay. ref: F-009 · D-016 · DRIFT-057/059.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")
const ARC_FIELD_S := 0.8   # 착탄 후 전기장 잔향 길이(초) — 잔향이지 지속 장판이 아니다


func kind() -> String:
	return "skillbook_bolt"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center: Vector3 = Vector3(target_pos.x, m.global_position.y, target_pos.z) if target_pos != Vector3.ZERO else m.global_position
	if String(p.get("delivery", "instant")) == "projectile":
		if bool(p.get("arc_vfx", false)):          # AB-004 「전격 사격」 시그니처 — 지리릿 번개 크래클(발사 순간)
			SkillVfx.lightning_bolt(ctx, m.global_position, center, Color(0.55, 0.8, 1.0))
		ctx.spawn_projectile(self, m, center, p)   # entity travels → resolve_at() on impact
		ctx.sub_shake(p)
		print("[SB] %s bolt → projectile @target (x%.1f)" % [m.class_id, float(p.get("damage_mult", 1.0))])
		return true
	# Instant: no travel entity → draw the bolt streak from the caster, then resolve at the point.
	if String(p.get("element", "")) == "lightning":
		SkillVfx.lightning_bolt(ctx, m.global_position, center, Elements.color_of("lightning"))
	resolve_at(m, center, p, ctx)
	ctx.sub_shake(p)
	return true


## Apply the bolt's hit at `center` — shared by the instant cast AND the projectile impact.
func resolve_at(m: CharacterBody3D, center: Vector3, p: Dictionary, ctx) -> void:
	var radius := float(p.get("radius_m", 1.5))
	var dmg: float = float(p.get("damage_mult", 1.0)) * m.basic_damage * float(p.get("_coeff", 1.0))
	var hits: Array = []
	for e in ctx.enemies_in_radius(center, radius):
		if e == null or not is_instance_valid(e) or not e.has_method("take_damage"):
			continue
		ctx.deal_damage(e, m, dmg)
		hits.append(e)
	# 속성은 AB의 `element`가 정한다 — 즉시 효과(전격=Shock) + RX(전도)를 seam이 처리. 무속성이면 no-op.
	ctx.element_hit(String(p.get("element", "")), center, radius, m, p, hits)
	SkillVfx.mark_ruin(ctx, center)                             # impact burst
	# 전격 볼트 — 착탄 **후 범위 안에 전기가 흐르는** 잔향(사용자 요청, AB-003 계기).
	# `element`로 갈리고 크기는 `radius_m` 그대로라 **볼트마다 자기 반경이 그려진다**
	# (AB-003 r4.0이 가장 크게, AB-004/073 r1.2~1.4는 작게). 원형-변형 체계와 같은 조립 방식.
	if String(p.get("element", "")) == "lightning":
		SkillVfx.arc_field(ctx, center, radius, Elements.color_of("lightning"), ARC_FIELD_S)
	_scatter(m, center, p, ctx)


## **산탄**(AB-055) — 착탄점에서 2차 투사체 `scatter_pellets`개를 **방사형으로** 뿌린다. 각 탄은
## 자기 좁은 반경으로 다시 `resolve_at`을 돌려 충돌 지점에 소범위 피해를 준다(같은 이펙트 재귀 사용).
## ⚠️ **재귀 가드 `_pellet`** — 산탄이 또 산탄을 낳으면 무한 증식한다. 파편 params에 플래그를 박고
## 여기서 먼저 걸러낸다. 파편은 캐스터가 아니라 **착탄점**에서 출발하므로 `spawn_projectile(origin)` 사용.
## 파편 무장 거리 = 초탄 반경 + `scatter_deadzone_m`. 조준 마커(초탄 원판 ↔ 산탄 링)의 빈 공간과 동일.
static func deadzone_of(p: Dictionary) -> float:
	return float(p.get("radius_m", 1.5)) + float(p.get("scatter_deadzone_m", 1.2))


func _deadzone(p: Dictionary) -> float:
	return deadzone_of(p)


func _scatter(m: CharacterBody3D, center: Vector3, p: Dictionary, ctx) -> void:
	var pellets := int(p.get("scatter_pellets", 0))
	if pellets <= 0 or bool(p.get("_pellet", false)):
		return
	var pr: Dictionary = p.duplicate()
	pr["_pellet"] = true                       # 재귀 차단
	pr["delivery"] = "projectile"
	pr["radius_m"] = float(p.get("scatter_radius_m", 0.6))
	pr["damage_mult"] = float(p.get("scatter_damage_mult", 0.35))
	pr["speed_mps"] = float(p.get("scatter_speed_mps", 24.0))
	# **데드존** — 초탄 반경 + 여유만큼 날아가기 전에는 파편이 터지지 않는다. 없으면 착탄점에 적이
	# 서 있을 때 6발이 그 자리에서 동시에 터져 피해가 몰린다(사용자 제보). 조준 마커의 "빈 공간"과
	# 같은 값이라 화면에 보이는 그대로 동작한다.
	pr["arm_after_m"] = _deadzone(p)
	# 파편은 조준 대상이 없어 **레이가 적을 스치고 지나가기 쉽다** → 근접 히트 반경을 준다.
	pr["hit_radius_m"] = float(p.get("scatter_hit_radius_m", 0.55))
	pr.erase("arc_vfx")                        # 파편마다 발사 크래클을 그리진 않는다
	var spread := float(p.get("scatter_range_m", 7.0))
	# **부채꼴 확산**(산탄총) — 360° 방사가 아니라 **탄이 날아가던 방향**으로 원뿔이 열린다.
	# 기준축 = 캐스터→착탄점(탄도 연장). 캐스터가 착탄점 위에 겹치면 방향이 0이라 정면으로 폴백.
	var fwd: Vector3 = center - m.global_position
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3(0.0, 0.0, 1.0)
	var base: float = atan2(fwd.z, fwd.x)
	var half: float = deg_to_rad(float(p.get("scatter_cone_deg", 70.0)) * 0.5)
	var jitter: float = half / float(maxi(pellets, 2)) * 0.6   # 등간격이 기계적이라 살짝 흩는다
	for i in pellets:
		# 부채꼴 안에서 균등 배치(양 끝단 포함) — 1발이면 정중앙.
		var t: float = (float(i) / float(pellets - 1)) if pellets > 1 else 0.5
		var a: float = base + lerpf(-half, half, t) + randf_range(-jitter, jitter)
		var dest: Vector3 = center + Vector3(cos(a), 0.0, sin(a)) * spread
		ctx.spawn_projectile(self, m, dest, pr, center)
	print("[SB] %s 산탄 — 파편 %d발 부채꼴 %.0f° 확산(사거리 %.1fm)" % [
		m.class_id, pellets, rad_to_deg(half * 2.0), spread])
