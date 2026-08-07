extends RefCounted
## Single source of truth for code-placeholder unit visuals — role palette + enemy table.
## ref: DEBT-DUP-COLOR (was split: party_controller CLASS_COLORS/CLASS_SCALES + combat_controller ENEMY_VISUALS).
## PH spec: WORK_ORDER §코드 플레이스홀더 — 아군=원기둥/한색(cool), 적=박스/난색(warm).

## Global unit-vs-map scale. Units were too big vs the map ("miniature" feel + camera felt close);
## shrinking them makes the world read bigger. Applied to party + enemy mesh scale here; the
## SAME factor scales formation slot offsets + slot_min_distance in party_controller so the party
## stays proportional (else steering re-spreads it). 1.0 = original. ref: F-012.
const UNIT_SCALE := 0.65


# --- Party roles (cool palette) ---
const ROLE_COLORS: Dictionary = {
	"Tank": Color(0.19, 0.44, 0.80),    # #3070CC Blue
	"DPS": Color(0.13, 0.63, 0.63),     # #20A0A0 Teal
	"Nuker": Color(0.38, 0.25, 0.69),   # #6040B0 Indigo
	"Healer": Color(0.19, 0.63, 0.31),  # #30A050 Green
}
## Role-based mesh scale multiplier (relative to default 1.0).
const ROLE_SCALES: Dictionary = {
	"Tank": 1.1,
	"DPS": 1.0,
	"Nuker": 0.95,
	"Healer": 0.9,
}

# --- Enemies (warm palette) — color + relative box scale ---
const ENEMY_VISUALS: Dictionary = {
	"EN-001": {"color": Color(0.75, 0.19, 0.19), "scale": 1.30},  # Crimson, large (elite)
	"EN-010": {"color": Color(0.82, 0.50, 0.13), "scale": 1.00},  # Orange
	"EN-011": {"color": Color(0.75, 0.69, 0.19), "scale": 0.85},  # Yellow, small
	"EN-012": {"color": Color(0.55, 0.25, 0.13), "scale": 1.25},  # Brown-red, large
	"EN-013": {"color": Color(0.80, 0.74, 0.30), "scale": 0.90},  # Skitter
	"EN-006": {"color": Color(0.86, 0.24, 0.42), "scale": 1.05},  # Bell Ringer (CC) — magenta
	"EN-005": {"color": Color(0.82, 0.66, 0.16), "scale": 0.92},  # Gutter Stinger (poison) — amber
}
const ENEMY_DEFAULT := {"color": Color(0.70, 0.40, 0.20), "scale": 1.00}


static func role_color(class_id: String) -> Color:
	return ROLE_COLORS.get(class_id, Color.GRAY)


static func role_scale(class_id: String) -> float:
	return ROLE_SCALES.get(class_id, 1.0) * UNIT_SCALE


## 역할별 기본 난색 — **손으로 키를 박지 않은 적**이 전부 같은 갈색 박스로 나오던 문제를 없앤다
## (19종 중 12종이 `ENEMY_DEFAULT` 하나를 공유했다). 색은 **보조 축**이고, 진짜 구분은 아래 실루엣·표식이 진다.
const ROLE_ENEMY_COLORS: Dictionary = {
	"elite": Color(0.75, 0.19, 0.19),       # 진홍 — 분대의 중심
	"boss": Color(0.62, 0.10, 0.24),        # 암적
	"nuker": Color(0.85, 0.62, 0.15),       # 앰버 — 시전자
	"cc": Color(0.86, 0.24, 0.42),          # 마젠타 — 제어
	"support": Color(0.72, 0.68, 0.30),     # 황록 — 지원(후광 링이 초록이라 몸은 탁하게)
	"fodder": Color(0.82, 0.50, 0.13),      # 주황 — 잡몹
	"specialist": Color(0.70, 0.40, 0.20),
}
## tier별 체급 — Elite는 눈에 띄게 크다. 손키 scale이 있으면 그쪽이 이긴다.
const TIER_SCALES: Dictionary = {"Trash": 1.0, "Elite": 1.30, "Boss": 1.45}
## 이 사거리 이하 = 근접 실루엣(넓고 낮은 박스). 초과 = 원거리 실루엣(좁고 높은 기둥).
const MELEE_RANGE_M := 2.5


## **특성 → 외형 파생**(DRIFT-118). 색만으로는 적이 안 갈린다(부감 시점 · 안개 · 색각) → 데이터에
## 이미 있는 축을 **실루엣·표식**으로 옮긴다. 손으로 19종을 칠하는 대신 규칙이 낳게 한다:
##   · `shape`  = 교전 거리 — 근접 `box`(넓고 낮음) ↔ 원거리 `column`(좁고 높음, 8각기둥)
##   · `scale`  = `tags.tier` (Trash 1.0 / Elite 1.3 / Boss 1.45)
##   · `crest`  = `role` — 머리 위 표식이 **가장 강한 구분자**다:
##                support=후광 링 · nuker=떠 있는 오브 · cc=뿔 2개 · elite/boss=왕관 · fodder=없음
##                (**표식 없음 = 잡몹**이라는 것도 정보다 — 위협 우선순위가 실루엣으로 읽힌다)
##   · `color`  = 손키 우선, 없으면 role 팔레트 + id 해시로 미세 변주(같은 role끼리도 안 겹치게)
## 진영(3세력)은 이 위에 `apply_faction_shape()`가 콘+보라로 덮어쓴다 — 진영이 최상위 축이라 의도된 것.
static func enemy_visual(enemy_id: String, row: Dictionary = {}) -> Dictionary:
	var hand: Dictionary = ENEMY_VISUALS.get(enemy_id, {})
	var role := String(row.get("role", ""))
	var tags: Dictionary = row.get("tags", {})
	var tier := String(tags.get("tier", "Trash"))
	var stats: Dictionary = row.get("stats", {})
	var reach := float(stats.get("attack_range_m", 1.6))
	var v := {}
	v["color"] = hand.get("color", _role_enemy_color(enemy_id, role))
	v["scale"] = float(hand.get("scale", TIER_SCALES.get(tier, 1.0))) * UNIT_SCALE
	v["shape"] = "column" if reach > MELEE_RANGE_M else "box"
	v["crest"] = CREST_BY_ROLE.get(role, "")
	return v


## 역할 팔레트 + id 해시 변주 — 같은 role이 여럿이어도 완전히 같은 색은 안 나온다.
static func _role_enemy_color(enemy_id: String, role: String) -> Color:
	var base: Color = ROLE_ENEMY_COLORS.get(role, ENEMY_DEFAULT["color"])
	var j: float = (float(hash(enemy_id) % 1000) / 1000.0 - 0.5) * 0.18   # ±9%
	return Color(clampf(base.r + j, 0.08, 1.0), clampf(base.g + j * 0.6, 0.05, 1.0),
		clampf(base.b - j * 0.4, 0.05, 1.0))


const CREST_BY_ROLE: Dictionary = {
	"support": "halo",    # 후광 링 — "이놈을 먼저 끊어라"(DRIFT-117)가 실루엣으로 읽혀야 한다
	"nuker": "orb",       # 떠 있는 오브 — 시전자
	"cc": "horns",        # 뿔 2개 — 제어
	"elite": "crown",     # 왕관 — 분대장
	"boss": "crown",
}
