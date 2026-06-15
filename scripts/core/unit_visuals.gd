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


static func enemy_visual(enemy_id: String) -> Dictionary:
	var v: Dictionary = (ENEMY_VISUALS.get(enemy_id, ENEMY_DEFAULT) as Dictionary).duplicate()
	v["scale"] = float(v.get("scale", 1.0)) * UNIT_SCALE
	return v
