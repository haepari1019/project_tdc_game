extends RefCounted
## 스킬 툴팁 텍스트 빌더 (BBCode). 설명문 = display_names.json `skill_desc[kind]` + 핵심 수치.
## 밴드 패널티·gear 굴림은 색 구분(긍정 초록 · 부정 빨강) — RichTooltip 사용 컨트롤에서만 색이 보인다.
## 액션바(controlled_sheet)와 인벤 그리드(inventory_grid)가 공유. (~~affix~~ 폐기 = M5 · `D-018` §9)

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
	# skillbook_stealth(AB-062, DRIFT-121) — 은신이 **평타를 멈춘다**는 걸 안 적으면 플레이어는 "은신했더니
	# 공격이 안 나감"을 버그로 읽는다. 대가(평타 정지)와 보상(첫 타격 증폭)을 한 문장에 같이 실어야 은신
	# 지속이 도망 시간이 아니라 **무엇에 실을지 고르는 창**으로 읽힌다 — 이 스킬은 그 판독이 곧 조작법이다.
	if kind == "skillbook_stealth":
		var nhb := float(params.get("next_hit_bonus", 0.0))
		if nhb > 0.0:
			prose += " 은신 후 **첫 타격의 피해가 %d%% 증가한다.**" % int(round(nhb * 100.0))
		if bool(params.get("hold_fire", false)):
			prose += " 은신 중에는 평타와 정체성이 멈춰 **시전을 준비할 시간이 생기며**, 첫 타격을 넣는 순간 은신이 풀린다. 다시 누르면 은신을 해제하지만, 그때는 증폭이 사라진다."
	# skillbook_silence 두 변주(DRIFT-133) — 광역·무피해(AB-044 힐러) ↔ **단일 잠금 + 타격**(AB-030 누커).
	# 단일 변주에 "대상 지역의 적"이라고 적으면 거짓말이 된다(잠금이라 조준한 1기만 맞는다).
	if kind == "skillbook_silence":
		if bool(params.get("single_target", false)):
			prose = Slice01Data.get_skill_desc("skillbook_silence_single")
		prose += " 침묵은 %s초간 지속되며, 시전 중이던 스킬이 있었다면 그 시전도 끊긴다." % _n(float(params.get("silence_s", 0.0)))
	# skillbook_shield 두 대상(DRIFT-116) — 지정 1인(AB-067) ↔ 파티 광역(AB-075). 힐러 방어 4종의
	# 차이축이 **대상**이라 문구에서 먼저 갈리게 한다(자기 DR / 지정 흡수 / 광역 흡수 / 자동 흡수→치유).
	if kind == "skillbook_shield":
		if bool(params.get("targeted", false)):
			prose = Slice01Data.get_skill_desc("skillbook_shield_single")
		prose += " 흡수량은 대상 최대 체력의 %d%%이며, **%s초 뒤 사라진다.**" % [
			int(round(float(params.get("shield_pct", 0.0)) * 100.0)), _n(float(params.get("duration_s", 0.0)))]
	# 보호막 계열은 **일시성**이 정체성이다(DRIFT-119) — 힐(3~10초 집중, 영구 회복)과 달리 즉시 걸리고
	# 곧 사라진다. 지속을 문장 끝에 못박아 "지금 막을 것"과 "미리 채울 것"이 툴팁에서 갈리게 한다.
	if kind == "skillbook_ward_heal":
		prose += " 흡수량은 대상 최대 체력의 %d%%이며 **%s초만 유지된다** — 그 안에 막아 낸 만큼이 치유로 돌아온다." % [
			int(round(float(params.get("shield_pct", 0.0)) * 100.0)), _n(float(params.get("ward_s", 0.0)))]
	# skillbook_channeling 4형상(DRIFT-115) — 「빔」이 아니라 **채널링**이 클러스터 축이라 형상마다
	# 읽는 법이 다르다. 공통으로 **틱 수·총 집중 시간·이동하면 끊긴다**를 실어, 채널이 왜 위험한
	# 스킬인지가 툴팁에서 먼저 보이게 한다(제자리에 서 있어야 하는 대가로 payoff가 크다).
	if kind == "skillbook_channeling":
		var cs := String(params.get("channel_shape", "line"))
		if cs != "line":
			prose = Slice01Data.get_skill_desc("skillbook_channeling_" + cs)
		var tk := int(params.get("ticks", 0))
		var iv := float(params.get("tick_interval_s", 0.0))
		match cs:
			"cone":
				prose += " 사거리 %sm · %d° 부채꼴." % [
					_n(float(params.get("range_m", 0.0))), int(round(2.0 * float(params.get("half_deg", 0.0))))]
			"cloud":
				prose += " 사거리 %sm · 반경 %sm." % [
					_n(float(params.get("range_m", 0.0))), _n(float(params.get("radius_m", 0.0)))]
			"nova":
				prose += " 반경 %sm · 끝까지 맞은 적은 %s초간 빙결(모든 행동 불가)." % [
					_n(float(params.get("radius_m", 0.0))), _n(float(params.get("freeze_s", 0.0)))]
			_:
				prose += " 사거리 %sm." % _n(float(params.get("range_m", 0.0)))
		prose += " %d회에 걸쳐 총 %s초간 집중하며, **이동하면 즉시 끊긴다**." % [tk, _n(float(tk) * iv)]
	if kind == "skillbook_bolt":
		if float(params.get("cast_s", 0.0)) > 0.0:
			prose = "에너지를 집중한 뒤 " + prose
		# 속성 맛 — `skillbook_fire`/`skillbook_cold` kind가 볼트로 흡수되면서(DRIFT-111) 문장도
		# **element로 갈린다**. 원형 문장 + 실제로 가진 속성만 덧붙는 조립 방식(DRIFT-085 ⑤).
		match String(params.get("element", "")):
			"lightning":
				prose += " 전격 속성이 더해져 맞은 대상을 감전시킨다."
			"fire":
				prose += " 화염 속성이 더해져 기름 등 가연물에 닿으면 불이 붙는다."
			"cold":
				prose += " 냉기 속성이 더해져 맞은 대상을 둔화시키고, 물에 닿으면 얼린다."
			"poison":
				prose += " 맹독 속성이 더해져 맞은 대상에 독을 누적시킨다."
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


## ~~`affix_lines`~~ — **M5 제거**(`D-018` §9). 스킬북 affix가 폐기돼 색구분할 것이 없다.
## gear 굴림 라인(`gear_roll_line`)은 남는다 — 그쪽은 `F-008` §3.10.1로 **극소화**됐을 뿐 살아 있다.
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
