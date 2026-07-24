extends RefCounted
class_name OutcomeStatus
## STATUS-OUTCOME-CORE — elemental outcome statuses (F-021/F-027), shared by party_member AND
## enemy_unit so both carry the same zone outcomes. One container per unit. ref: STATUS-OUTCOME-CORE.
##
## - Movement statuses fold into ONE speed multiplier by **곱연산**(모든 배율을 곱한다) — 감속(<1.0)과
##   부스트(>1.0, IceGlide·Hastened) 양방향. `Slippery`(is_slippery) = **관성 개념명**: INERTIA 집합
##   (OilSlick 기름·IceGlide 빙판)의 상태가 관성 이동(the mover lerps velocity)을 유발한다.
## - Ignited is a DoT, polled each tick (whole-HP ticks, like poison) and applied by the unit.
## - WindBuffeted = a display tag only; the real effect is a continuous downwind DRIFT applied by
##   SurfaceGrid._wind_push_units while a unit stands in a Wind zone (AB-042; no MOVE_MULT here).
## DEMO PH magnitudes (SPEC_DRIFT) — real RX→status mapping/numbers land in P2-S3d.

# Movement-outcome → speed multiplier (strongest slow taken when several stack).
# Rooted/Pinned (STATUS-ACTOR-CORE CC, AB-102/AB-100) = full move LOCK (0.0) but the unit can still
# act — they only zero movement, unlike Stunned which freezes the whole AI. ref: DEC-20260621-001.
const MOVE_MULT := {
	"Sodden": 0.7, "Chilled": 0.6, "SteamHaze": 0.85, "Shock": 0.55,
	"OilSlick": 0.85, "IceGlide": 1.5,   # 기름=끈적(감속)+관성 · 빙판=질주(부스트)+관성. 둘 다 INERTIA
	"Rooted": 0.0, "Pinned": 0.0,
}
# 관성(inertial) 이동 상태 → accel scale(낮을수록 관성 큼). 컨트롤러가 SLIP_ACCEL × 이 값으로 미끄럼 강도 조절.
# `Slippery`(is_slippery)는 이 집합을 가리키는 개념명. 기름=1.0(기준), 빙판=0.7(마찰 더 없음 → 관성 살짝 더 큼).
const INERTIA := { "OilSlick": 1.0, "IceGlide": 0.7 }
# Buff outcomes (drawn green-ish / flagged buff in the overlay). Bloodlust = AB-105 self-rage.
const BUFF := { "Bloodlust": true, "IceGlide": true, "Hastened": true }   # 부스트류 = buff 표시
# Status orb / overlay colour per outcome.
const COLOR := {
	"Sodden": Color(0.40, 0.62, 0.95), "Chilled": Color(0.62, 0.86, 1.0),
	"SteamHaze": Color(0.80, 0.85, 0.90), "Shock": Color(0.60, 0.80, 1.0),
	"OilSlick": Color(0.72, 0.60, 0.32), "IceGlide": Color(0.62, 0.90, 1.0), "Hastened": Color(0.85, 1.0, 0.45),
	"Ignited": Color(1.0, 0.50, 0.20),
	"Scorched": Color(1.0, 0.72, 0.30),   # 화염존 체류 표식(점화 DoT와 별개 — 나가면 즉시 해제)
	"WindBuffeted": Color(0.70, 1.0, 0.86),
	# Third faction (DEC-20260621-001): Scented(추적 마크)·Rooted(이동봉쇄)·Pinned(짧은 고정)·
	# Tethered(거리 끈)·Bloodlust(저HP 자가 rage).
	"Scented": Color(0.92, 0.18, 0.20), "Rooted": Color(0.55, 0.45, 0.28),
	"Pinned": Color(0.80, 0.70, 0.30), "Tethered": Color(0.70, 0.62, 0.22),
	"Bloodlust": Color(1.0, 0.20, 0.15),
	# Party debuff (AB-057 Focus Fire) — Vulnerable: 받는 피해 +mag (enemy take_damage가 읽음).
	"Vulnerable": Color(1.0, 0.45, 0.55),
	# AB-010 Venom Spit — 스택형 독 DoT 디버프(mag = 누적 dps; 재적용마다 세짐).
	"Poison": Color(0.45, 0.85, 0.30),
}
# Korean display name per outcome (status-chip label in enemy_info). Superset of float_text.OUTCOME_KO
# (adds Tethered/Bloodlust). Unknown ids fall back to the raw id.
const KO := {
	"Sodden": "침수", "Chilled": "냉각", "SteamHaze": "증기", "Shock": "감전",
	"OilSlick": "기름", "IceGlide": "빙판", "Hastened": "가속", "Ignited": "점화", "WindBuffeted": "돌풍", "Scorched": "화염",
	"Scented": "혈향", "Rooted": "속박", "Pinned": "고정", "Tethered": "포박",
	"Bloodlust": "광폭", "Vulnerable": "취약", "Poison": "중독",
}
const DEFAULT_IGNITE_DPS := 8.0
# ── 지속피해(DoT) 공통 규격 (DRIFT-089) ──────────────────────────────────────────────────────
# **모든 DoT는 같은 리듬·같은 표기**로 뜬다(중독이 기준, 점화도 동일). 예전엔 점화만 "누적 1HP마다
# take_damage" 라 팝업이 아예 없었고(피해가 조용히 들어감) 중독만 0.5s 팝업이 있었다.
const DOT_TICK_S := 0.5                      # 틱 주기 — 이 리듬으로 피해 + 팝업
const DOT_IDS := ["Poison", "Ignited"]       # 틱형 DoT (새 DoT는 여기 + DOT_COLOR에 추가)
const DOT_COLOR := {                         # 팝업 색 — 상태 오브 색과 별개(가독성 우선)
	"Poison": Color(0.72, 0.38, 0.95),       # 보라
	"Ignited": Color(1.0, 0.55, 0.15),       # 주황
}

var _t: Dictionary = {}    # id -> remaining seconds
var _mag: Dictionary = {}  # id -> magnitude (Ignited: dps)
var _dur: Dictionary = {}  # id -> full duration (for overlay arc)
var _dot_accum: Dictionary = {}   # id -> 경과 시간(DOT_TICK_S 주기 타이머)
var _dot_ticks: Array = []        # [{id, dmg}] 직전 틱들 — 유닛이 take_dot_ticks()로 소비해 팝업
var _stacks: Dictionary = {}     # id -> 스택 수(누적 표시용; apply_stack이 갱신)


## Apply / refresh an outcome status. `mag` optional (Ignited: dps; others use MOVE_MULT consts).
func apply(id: String, dur: float, mag: float = 0.0) -> void:
	_t[id] = maxf(float(_t.get(id, 0.0)), dur)
	_dur[id] = maxf(float(_dur.get(id, 0.0)), _t[id])
	if mag > 0.0:
		_mag[id] = mag


## 스택형 상태 — mag를 누적(add)하며 지속 갱신. 독 스택처럼 재적용마다 세짐. cap로 폭주 방지. ref: AB-010.
## unit_mag = "스택 1개"의 기본 크기. 호출마다 add_mag가 달라도(예: 맹독폭주는 3스택을 한 번에 = add_mag 3배)
## 표시 스택은 이 단위로 일관 계산 — add_mag로 나누면 폭주 시 mag 32를 round(32/24)=1로 오표기하던 버그.
func apply_stack(id: String, dur: float, add_mag: float, cap_mag: float, unit_mag: float) -> void:
	_t[id] = maxf(float(_t.get(id, 0.0)), dur)
	_dur[id] = maxf(float(_dur.get(id, 0.0)), _t[id])
	_mag[id] = minf(float(_mag.get(id, 0.0)) + add_mag, cap_mag)
	if unit_mag > 0.0:
		_stacks[id] = int(round(_mag[id] / unit_mag))   # 스택 수 = 누적 DoT / 스택당 기본값(add_mag 아님)


## Decrement timers (expire), and return the whole-HP Ignited DoT to apply this frame (0 if none).
func tick(delta: float) -> float:
	for id in _t.keys():
		_t[id] = float(_t[id]) - delta
		if _t[id] <= 0.0:
			_t.erase(id)
			_mag.erase(id)
			_dur.erase(id)
			_stacks.erase(id)
	# DoT — 종류 무관 **동일 리듬**(DOT_TICK_S)으로 피해를 넣고 팝업 큐에 쌓는다.
	var dmg := 0.0
	for id in DOT_IDS:
		if not _t.has(id):
			_dot_accum.erase(id)
			continue
		_dot_accum[id] = float(_dot_accum.get(id, 0.0)) + delta
		if float(_dot_accum[id]) < DOT_TICK_S:
			continue
		_dot_accum[id] = float(_dot_accum[id]) - DOT_TICK_S
		var per := float(_mag.get(id, DEFAULT_IGNITE_DPS if id == "Ignited" else 0.0)) * DOT_TICK_S
		if per > 0.0:
			dmg += per
			_dot_ticks.append({"id": id, "dmg": per})
	return dmg


## 직전 틱들 [{id, dmg}] — 읽으면 비운다. 유닛이 매 tick 후 조회해 **DoT별 색으로 팝업**한다.
func take_dot_ticks() -> Array:
	var out: Array = _dot_ticks
	_dot_ticks = []
	return out


## DoT 팝업 색 — 종류별 고정(중독=보라 / 점화=주황).
static func dot_color(id: String) -> Color:
	return DOT_COLOR.get(id, Color(1.0, 1.0, 1.0))


func has(id: String) -> bool:
	return _t.has(id)


## Magnitude stored for an active outcome (Ignited dps / Vulnerable extra-damage frac). 0 if absent.
func mag(id: String) -> float:
	return float(_mag.get(id, 0.0))


func is_slippery() -> bool:
	for id in _t.keys():
		if INERTIA.has(id):
			return true
	return false


## 활성 관성 상태 중 가장 센 것(가장 낮은 accel scale). 관성 없으면 1.0. 컨트롤러가 SLIP_ACCEL에 곱한다.
func inertia_scale() -> float:
	var s := 1.0
	var found := false
	for id in _t.keys():
		if INERTIA.has(id):
			s = minf(s, float(INERTIA[id]))
			found = true
	return s if found else 1.0


func any() -> bool:
	return not _t.is_empty()


## 곱연산 속도 배율(감속 × 부스트, 1.0 = none). 여러 이동상태가 겹치면 전부 곱해진다(min 아님).
## Hastened(AB-069)는 고정배율이 아니라 mag(pct) 기반이라 별도로 (1+mag)를 곱한다.
func move_mult() -> float:
	var m := 1.0
	for id in _t.keys():
		if MOVE_MULT.has(id):
			m *= float(MOVE_MULT[id])
	if _t.has("Hastened"):
		m *= 1.0 + mag("Hastened")
	return m


## Active outcomes for the status overlay: [{name, color, ratio (0 fresh → 1 expiring), buff}].
func status_list() -> Array:
	var out: Array = []
	for id in _t.keys():
		out.append({
			"name": KO.get(id, id),
			"color": COLOR.get(id, Color(0.8, 0.8, 0.8)),
			"ratio": 1.0 - clampf(float(_t[id]) / maxf(float(_dur.get(id, 0.01)), 0.01), 0.0, 1.0),
			"buff": BUFF.has(id),
			"stacks": int(_stacks.get(id, 0)),
		})
	return out


## The highest-priority active outcome colour (for the single overhead orb), or null if none.
func orb_color():
	# fire > shock > the rest, roughly by threat readability.
	for id in ["Ignited", "Shock", "Chilled", "Sodden", "OilSlick", "IceGlide", "Hastened", "SteamHaze", "WindBuffeted",
			"Rooted", "Pinned", "Scented", "Tethered", "Bloodlust", "Vulnerable"]:
		if _t.has(id):
			return COLOR[id]
	return null


func clear() -> void:
	_t.clear()
	_mag.clear()
	_dur.clear()
	_dot_accum.clear()
	_dot_ticks.clear()
	_stacks.clear()


## Remove one specific outcome (cleanse). No-op if absent.
func remove(id: String) -> void:
	_t.erase(id)
	_mag.erase(id)
	_dur.erase(id)
	_stacks.erase(id)


## Cleanse one debuff — the first active non-buff outcome. Returns the removed id ("" if none).
func cleanse_one() -> String:
	for id in _t.keys():
		if not BUFF.has(id):
			remove(id)
			return id
	return ""
