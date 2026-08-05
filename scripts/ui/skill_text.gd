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
	# skillbook_strike 두 형상 — 기본 = **자기중심**(AB-002 발밑 강타) · `shape:"rect"` = 전방 직선 레인
	# (AB-005). 예전엔 둘 다 "대상 지역"이라 조준형처럼 읽혔다 — 조준(AB-011 단일)과 구분이 안 됐다.
	# T1 통폐합(2026-07-28): 남은 Tank 강타 2종의 차이축 = **자기중심 광역 ↔ 조준 단일**이라 문구로 못박는다.
	if kind == "skillbook_strike" and String(params.get("shape", "radius")) == "rect":
		prose = Slice01Data.get_skill_desc("skillbook_strike_rect")
	# skillbook_dr 두 사거리 — 자기(radius≈0.5, AB-046/068) ↔ 주변 아군 전체(radius 4.0, AB-047).
	# T2 판정(2026-07-28): 같은 문장을 공유하던 DR들의 유일한 실차이가 "나만 ↔ 팀도"라 문구로 못박는다.
	if kind == "skillbook_dr":
		if float(params.get("radius_m", 0.0)) > 1.0:
			prose = Slice01Data.get_skill_desc("skillbook_dr_party")
		prose += " 피해가 %d%% 줄어든다." % int(round(float(params.get("damage_reduction", 0.0)) * 100.0))
	# skillbook_reflect 두 변주(DRIFT-104) — 시간형(AB-048a) ↔ 캐스팅 한정 타수형(AB-048b).
	# 반사율·상한·타수를 params로 실어 튜닝이 문장에 바로 드러나게(볼트 조립과 동형).
	if kind == "skillbook_reflect":
		if bool(params.get("reflect_cast_only", false)):
			prose = Slice01Data.get_skill_desc("skillbook_reflect_cast")
			prose += " 다음 %d회의 시전 공격에 대해 %d%%를 되돌리며, 시전 1회당 총 %s까지다." % [
				int(params.get("reflect_hits", 0)),
				int(round(float(params.get("reflect_frac", 0.0)) * 100.0)),
				_n(float(params.get("reflect_cap", 0.0)))]
		else:
			prose += " 되돌리는 양은 받은 피해의 %d%%이며, 시전 1회당 총 %s까지다." % [
				int(round(float(params.get("reflect_frac", 0.0)) * 100.0)), _n(float(params.get("reflect_cap", 0.0)))]
	# skillbook_barrier 두 형상(DRIFT-107) — wall(AB-034 단일 방향·이동차단) ↔ dome(AB-033 전방위·투사체만).
	if kind == "skillbook_barrier":
		if String(params.get("shape", "wall")) == "dome":
			prose = Slice01Data.get_skill_desc("skillbook_barrier_dome")
		prose += " 내구도 %s." % _n(float(params.get("barrier_hp", 0.0)))
	# skillbook_taunt 2종(DRIFT-108) — 둘 다 **단일 대상**이라 차이축은 **사거리 ↔ 위협량**뿐.
	# 문장에 두 수치를 실어 "멀리서 약하게 ↔ 붙어서 강하게"가 툴팁만 읽어도 갈리게 한다.
	if kind == "skillbook_taunt":
		if bool(params.get("taunt_all", false)):
			prose = Slice01Data.get_skill_desc("skillbook_taunt_all")
			prose += " 사거리 %sm · 반경 %sm 안의 **모든** 적에게 위협 +%s(유지 %s)." % [
				_n(float(params.get("range_m", 0.0))), _n(float(params.get("radius_m", 0.0))),
				_n(float(params.get("mark_threat", 0.0))), _n(float(params.get("floor", 0.0)))]
		else:
			prose += " 사거리 %sm에서 **단일** 대상에게 위협 +%s(유지 %s)." % [
				_n(float(params.get("range_m", 0.0))), _n(float(params.get("mark_threat", 0.0))),
				_n(float(params.get("floor", 0.0)))]
	# skillbook_root(AB-102) — 뭉치기 거리·속박 지속을 문장에 실어 **콤보 창**이 몇 초인지 보이게 한다.
	if kind == "skillbook_root":
		prose += " 반경 %sm 안의 적을 %sm 끌어모으고 %s초간 속박한다." % [
			_n(float(params.get("radius_m", 0.0))), _n(float(params.get("gather_m", 0.0))),
			_n(float(params.get("root_s", 0.0)))]
	if kind == "skillbook_bolt":
		if float(params.get("cast_s", 0.0)) > 0.0:
			prose = "에너지를 집중한 뒤 " + prose
		if String(params.get("element", "")) == "lightning":
			prose += " 전격 속성이 더해져 맞은 대상을 감전시킨다."
		# 산탄(AB-055) — 착탄 후 2차 파편. 반경 3종(초탄 > 파편)이 문장에서 갈리게 적는다.
		if int(params.get("scatter_pellets", 0)) > 0:
			prose += " 착탄하면 **파편 %d발이 날아가던 방향으로 %d° 부채꼴로 %sm까지 퍼지며**, 각 파편은 맞은 자리에 반경 %sm의 좁은 피해를 준다." % [
				int(params["scatter_pellets"]), int(round(float(params.get("scatter_cone_deg", 70.0)))),
				_n(float(params.get("scatter_range_m", 0.0))), _n(float(params.get("scatter_radius_m", 0.0)))]
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
