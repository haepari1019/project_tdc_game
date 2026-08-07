extends RefCounted
## AB-070 Purge Light (kind=skillbook_purge) — **아군 디버프 정화**(H7 재정의, DRIFT-116).
##
## 종전엔 **적 강화 제거**가 본체였다. 그런데 전수 실측(23 ENC / 97 스폰)에서 적 강화를 가진 적은
## `Bloodlust` 하나뿐이고 **1/97 = 1%**, 아군 개구리를 거는 EN-007도 **2/97**이었다 — 슬롯 하나를
## 쓰는데 **표적이 사실상 없는** 스킬이었다(T4b에서 이동 CC를 9%로 폐기한 것과 같은 진단).
##
## 파티가 실제로 매 판 겪는 건 **디버프**다(Chilled·Ignited·Poison·Rooted·Frozen…). 특히
## **매질을 소모품으로 옮기면서(DRIFT-112) 아군도 장판을 밟게 됐다** — 정화 수요는 그때 구조적으로
## 생겼다. 그래서 축을 "적에게서 빼앗는다" → **"아군에게서 걷어낸다"** 로 옮겼다.
##
## 우선순위: **아군 개구리(폴리모프) → 아군 debuff 1건 → (없으면) 적 강화 1건**. 적 강화 제거는
## 버리지 않고 **폴백**으로 남긴다(Bloodlust Reaver를 만났을 때의 답은 계속 이 스킬이다).
## 지울 게 하나도 없으면 **차지를 소모하지 않는다**(종전 규약 유지). ref: F-009 · AB-070 · DRIFT-058/116.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")
const ALLY_COLOR := Color(0.55, 0.95, 0.60)    # 아군 정화 = 초록
const FOE_COLOR := Color(1.0, 0.92, 0.55)      # 적 강화 제거 = 금색(종전 색)


func kind() -> String:
	return "skillbook_purge"


func cast(m: CharacterBody3D, p: Dictionary, target_pos: Vector3, ctx) -> bool:
	var center: Vector3 = target_pos if target_pos != Vector3.ZERO else m.global_position
	var radius := float(p.get("radius_m", 3.0))
	# 1) 아군 정화 — 반경 안 전원을 훑어 **각자 1건씩** 지운다(광역 정화). 개구리가 최우선.
	var cleaned := 0
	var first := ""
	for a in ctx.allies_in_radius(center, radius):
		if a == null or not is_instance_valid(a) or not a.has_method("cleanse_debuff"):
			continue
		var got := String(a.cleanse_debuff())
		if got == "":
			continue
		if first == "":
			first = got
		cleaned += 1
		SkillVfx.telegraph(ctx, a.global_position, ALLY_COLOR, 1.4)
	if cleaned > 0:
		SkillVfx.telegraph(ctx, center, ALLY_COLOR, maxf(radius, 1.5))
		print("[SB] %s Purge Light — 아군 %d명 정화(%s…)" % [m.class_id, cleaned, first])
		return true
	# 2) 폴백 — 걷어낼 아군 디버프가 없으면 적 강화를 1건 빼앗는다(종전 거동).
	for e in ctx.enemies_in_radius(center, radius):
		if e == null or not is_instance_valid(e) or not e.has_method("purge_one_buff"):
			continue
		var removed := String(e.purge_one_buff())
		if removed != "":
			SkillVfx.telegraph(ctx, e.global_position, FOE_COLOR, 1.6)
			SkillVfx.telegraph(ctx, center, FOE_COLOR, maxf(radius, 1.5))
			print("[SB] %s Purge Light — 적 강화 제거(%s)" % [m.class_id, removed])
			return true
	return false   # 지울 게 없음 → 차지 소모 안 함
