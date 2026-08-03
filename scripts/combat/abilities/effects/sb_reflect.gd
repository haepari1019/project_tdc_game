extends RefCounted
## skillbook_reflect — 반격 2변주(DRIFT-104, 사용자 확정):
##  · **AB-048a Counter Stance(시간형)** — `duration_s` 동안 **모든 피격**을 반사.
##  · **AB-048b Riposte(타수형)** — `reflect_hits`타, **`reflect_cast_only`로 적의 캐스팅 스킬만**
##    반사한다(평타 rom_*는 무시 → "큰 거 올 때 받아치는" 타이밍 스킬). `duration_s`는 안전장치.
## ⚠️ **둘 다 내 피해는 그대로 들어간다** — 반사는 경감이 아니라 추가 되돌리기(패링=딜 무효는 후속 특성).
## **DR·이동잠금 없음**(IDA-052 Sentinel = DR+락+반사와 분리).
## `reflect_cap` = **시전 1회당 반사 총량 상한** — 다수에게 둘러싸일수록 무한 증폭되는 걸 막는 밸런싱
## 레버(frac·cap 두 숫자로 튜닝 완결). T2 판정(2026-07-28, 사용자 확정): 이름값(Counter)대로 DR 중복
## 4종에서 빠져나온 재정의. ref: F-009 · DRIFT-102.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")
const AURA_R := 1.0                                  # 자기 대상 스탠스 — 발밑 개인 링
const AURA_COLOR := Color(1.0, 0.50, 0.20)           # 주황 = 반격(DR 금색과 구분되는 색 언어)
const AURA_KEY := "reflect"                          # 반격 상태는 **단일 슬롯**이라 오오라도 키 하나
const AURA_SPIKES := 8                               # 고슴도치 가시 수 — "건드리면 아프다"를 형태로 말한다


func kind() -> String:
	return "skillbook_reflect"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	if not m.has_method("apply_reflect"):
		return false
	var frac := clampf(float(p.get("reflect_frac", 0.4)), 0.0, 1.0)
	var dur := float(p.get("duration_s", 1.5))
	var cap := float(p.get("reflect_cap", 40.0)) * float(p.get("_coeff", 1.0))   # affix/밴드 계수는 상한에 태운다
	var hits := int(p.get("reflect_hits", 0))            # 0 = 시간형(AB-048a) · >0 = 타수형(AB-048b)
	var cast_only := bool(p.get("reflect_cast_only", false))
	var label := String(p.get("reflect_label", "반격"))
	m.apply_reflect(frac, dur, cap, hits, cast_only, label)
	SkillVfx.anchor_guard(ctx, m.global_position, 1.6)   # 시전 순간 큐
	# 지속형 오오라(DRIFT-106) — 태세가 켜져 있는 동안 계속 보인다. 타수형(048b)은 타수가 먼저 소진되면
	# `party_member._end_reflect()`가 `clear_aura`로 즉시 끈다(창 시간이 남아도 꺼진 걸 보여 줘야 한다).
	SkillVfx.aura_field(m, AURA_R, AURA_COLOR, dur, AURA_KEY, AURA_SPIKES)
	print("[SB] %s %s — reflect %d%% %s (cap %.0f%s)" % [m.class_id, label, int(frac * 100.0),
		("× %d타" % hits) if hits > 0 else "/ %.1fs" % dur, cap, " · 캐스팅 한정" if cast_only else ""])
	return true
