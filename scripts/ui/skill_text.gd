extends RefCounted
## 스킬/affix 툴팁 텍스트 빌더 (BBCode). 설명문 = display_names.json `skill_desc[kind]` + 핵심 수치.
## affix·밴드 패널티는 색 구분(긍정 초록 · 부정 빨강 · affix 특별 금색) — RichTooltip(custom tooltip) 사용 컨트롤에서만 색이 보인다.
## 액션바(controlled_sheet)와 인벤 그리드(inventory_grid)가 공유. ref: docs/design/affix_design.md.

const RT := preload("res://scripts/ui/rich_tooltip.gd")
const _BAND_COEFF := {"B0": 1.0, "B1": 0.9, "B2": 0.75, "B3": 0.55}   # D-016 §3.2 / ability_dispatch와 동일


## 스킬 한 줄 설명 — prose(kind별) + 핵심 수치(피해/반경/지속). 색 없음(본문).
static func describe(kind: String, params: Dictionary) -> String:
	var prose := Slice01Data.get_skill_desc(kind)
	# 「광역 투사체」 원형 = skillbook_bolt(AB-008 Slag Spit). 나머지 볼트는 여기서 갈라지는 변형이라
	# 문장을 params로 조립한다 — 원형 문장(kind desc)에 실제로 가진 것만 덧붙어 스킬마다 참이 된다.
	# 집중(cast_s) = 원형이 물려주는 시전 감각 · 전격(lightning) = AB-003 계열이 얹는 속성. DRIFT-085.
	if kind == "skillbook_bolt":
		if float(params.get("cast_s", 0.0)) > 0.0:
			prose = "에너지를 집중한 뒤 " + prose
		if String(params.get("element", "")) == "lightning":
			prose += " 전격 속성이 더해져 맞은 대상을 감전시킨다."
	var stm := float(params.get("single_target_mult", 1.0))
	if stm > 1.0:   # AB-005 — 범위 내 단일 대상이면 피해 증폭(param 있는 스킬만)
		prose += " 범위 내 적이 단일 개체라면 피해를 %d%% 증폭한다." % int(round((stm - 1.0) * 100.0))
	var nums := _key_nums(params)
	if nums.is_empty():
		return prose
	return "%s  [color=#%s](%s)[/color]" % [prose, RT.DIM, nums]


static func _key_nums(p: Dictionary) -> String:
	var parts: Array = []
	if p.has("damage_mult"):
		parts.append("피해 ×%s" % _n(float(p["damage_mult"])))
	for k in p:
		if String(k).ends_with("radius_m"):
			parts.append("반경 %sm" % _n(float(p[k])))
			break
	for k in p:
		var ks := String(k)
		if ks.ends_with("_s") and ks != "cooldown_s" and ks != "telegraph_s" and ks != "cast_s":
			parts.append("지속 %s초" % _n(float(p[k])))
			break
	return "  ·  ".join(parts)


## affix 색구분 라인들(BBCode) — 없으면 []. ▲ 긍정 초록 · ▼ 부정(쿨 트레이드) 빨강.
static func affix_lines(affix) -> Array:
	if typeof(affix) != TYPE_DICTIONARY or (affix as Dictionary).is_empty():
		return []
	var a: Dictionary = affix
	var ids: Array = a.get("ids", [])
	var names: Array = []
	for id in ids:
		names.append(Slice01Data.get_affix_label(String(id)))   # 다종 affix = 모든 라벨 표시
	var nm := " + ".join(names) if not names.is_empty() else "특수 옵션"
	var out: Array = ["[color=#%s]✦ %s · %s[/color]" % [RT.ACCENT, nm, String(a.get("tier", ""))]]
	if float(a.get("coeff", 0.0)) > 0.0:
		out.append("  [color=#%s]▲ 효과 +%d%%[/color]" % [RT.POS, roundi(float(a["coeff"]) * 100.0)])
	if int(a.get("charges", 0)) > 0:
		out.append("  [color=#%s]▲ 탄약 +%d[/color]" % [RT.POS, int(a["charges"])])
	if float(a.get("cd_trade", 0.0)) > 0.0:
		out.append("  [color=#%s]▼ 쿨다운 +%d%%[/color]" % [RT.NEG, roundi(float(a["cd_trade"]) * 100.0)])
	return out


## 비주력(서브 클래스) 적성 패널티 % — main class = 0. sub_bands × BAND_COEFF.
static func band_pct(base_ability_id: String, class_id: String) -> int:
	var bands: Dictionary = Slice01Data.get_skillbook_master(base_ability_id).get("sub_bands", {})
	var coeff := float(_BAND_COEFF.get(String(bands.get(class_id, "B0")), 1.0))
	return int(round((1.0 - coeff) * 100.0))


## 비주력 패널티 색 라인(빨강) — band_pct>0 일 때만 호출.
static func band_line(pct: int) -> String:
	return "[color=#%s]⚠ 비주력 적성 −%d%%[/color]" % [RT.NEG, pct]


## 기어 옵션 roll 색 라인(BBCode) — 피해↑/쿨↓ = 긍정 초록, 쿨↑ = 부정 빨강.
static func gear_roll_line(rolls) -> String:
	if typeof(rolls) != TYPE_DICTIONARY or (rolls as Dictionary).is_empty():
		return ""
	var dm := float((rolls as Dictionary).get("dmg_mult", 1.0))
	var cm := float((rolls as Dictionary).get("cd_mult", 1.0))
	var pm := float((rolls as Dictionary).get("potency_mult", 1.0))
	var parts: Array = []
	parts.append("[color=#%s]피해 ×%.2f[/color]" % [(RT.POS if dm >= 1.0 else RT.NEG), dm])
	parts.append("[color=#%s]쿨 ×%.2f[/color]" % [(RT.POS if cm <= 1.0 else RT.NEG), cm])   # 쿨은 낮을수록 좋음
	parts.append("[color=#%s]정체성 위력 ×%.2f[/color]" % [(RT.POS if pm >= 1.0 else RT.NEG), pm])
	return "옵션: " + "  ·  ".join(parts)


static func _n(v: float) -> String:
	return "%d" % int(v) if is_equal_approx(v, floorf(v)) else "%.1f" % v
