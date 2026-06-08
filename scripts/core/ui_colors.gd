extends RefCounted
## Shared HUD color ramps — single source of truth for HP-ratio coloring.
## ref: DEBT-DUP-HP — previously duplicated (and drifted) across
## party_sheet.gd / controlled_sheet.gd / health_bar.gd.


## HP fill color: green > 0.5, yellow > 0.25, red otherwise.
static func hp_color(r: float) -> Color:
	if r > 0.5:
		return Color(0.30, 0.85, 0.35)
	elif r > 0.25:
		return Color(0.92, 0.80, 0.22)
	return Color(0.90, 0.25, 0.22)
