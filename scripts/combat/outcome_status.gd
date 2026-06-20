extends RefCounted
## STATUS-OUTCOME-CORE — elemental outcome statuses (F-021/F-027), shared by party_member AND
## enemy_unit so both carry the same zone outcomes. One container per unit. ref: STATUS-OUTCOME-CORE.
##
## - Movement statuses (Sodden/Chilled/SteamHaze/Shock/Slippery) fold into ONE speed multiplier —
##   strongest slow wins. Slippery ALSO flags inertial movement (the mover lerps velocity).
## - Ignited is a DoT, polled each tick (whole-HP ticks, like poison) and applied by the unit.
## - WindBuffeted is a one-shot impulse (the source applies a knockback) + a brief display tag here.
## DEMO PH magnitudes (SPEC_DRIFT) — real RX→status mapping/numbers land in P2-S3d.

# Movement-outcome → speed multiplier (strongest slow taken when several stack).
const MOVE_MULT := {
	"Sodden": 0.7, "Chilled": 0.6, "SteamHaze": 0.85, "Shock": 0.55, "Slippery": 0.85,
}
# Status orb / overlay colour per outcome.
const COLOR := {
	"Sodden": Color(0.40, 0.62, 0.95), "Chilled": Color(0.62, 0.86, 1.0),
	"SteamHaze": Color(0.80, 0.85, 0.90), "Shock": Color(0.60, 0.80, 1.0),
	"Slippery": Color(0.72, 0.60, 0.32), "Ignited": Color(1.0, 0.50, 0.20),
	"WindBuffeted": Color(0.70, 1.0, 0.86),
}
const DEFAULT_IGNITE_DPS := 8.0

var _t: Dictionary = {}    # id -> remaining seconds
var _mag: Dictionary = {}  # id -> magnitude (Ignited: dps)
var _dur: Dictionary = {}  # id -> full duration (for overlay arc)
var _ignite_accum: float = 0.0


## Apply / refresh an outcome status. `mag` optional (Ignited: dps; others use MOVE_MULT consts).
func apply(id: String, dur: float, mag: float = 0.0) -> void:
	_t[id] = maxf(float(_t.get(id, 0.0)), dur)
	_dur[id] = maxf(float(_dur.get(id, 0.0)), _t[id])
	if mag > 0.0:
		_mag[id] = mag


## Decrement timers (expire), and return the whole-HP Ignited DoT to apply this frame (0 if none).
func tick(delta: float) -> float:
	for id in _t.keys():
		_t[id] = float(_t[id]) - delta
		if _t[id] <= 0.0:
			_t.erase(id)
			_mag.erase(id)
			_dur.erase(id)
	var dmg := 0.0
	if _t.has("Ignited"):
		_ignite_accum += float(_mag.get("Ignited", DEFAULT_IGNITE_DPS)) * delta
		if _ignite_accum >= 1.0:
			dmg = floorf(_ignite_accum)
			_ignite_accum -= dmg
	return dmg


func has(id: String) -> bool:
	return _t.has(id)


func is_slippery() -> bool:
	return _t.has("Slippery")


func any() -> bool:
	return not _t.is_empty()


## Strongest movement slow currently active (1.0 = none).
func move_mult() -> float:
	var m := 1.0
	for id in _t.keys():
		if MOVE_MULT.has(id):
			m = minf(m, float(MOVE_MULT[id]))
	return m


## Active outcomes for the status overlay: [{color, ratio (0 fresh → 1 expiring), buff=false}].
func status_list() -> Array:
	var out: Array = []
	for id in _t.keys():
		out.append({
			"color": COLOR.get(id, Color(0.8, 0.8, 0.8)),
			"ratio": 1.0 - clampf(float(_t[id]) / maxf(float(_dur.get(id, 0.01)), 0.01), 0.0, 1.0),
			"buff": false,
		})
	return out


## The highest-priority active outcome colour (for the single overhead orb), or null if none.
func orb_color():
	# fire > shock > the rest, roughly by threat readability.
	for id in ["Ignited", "Shock", "Chilled", "Sodden", "Slippery", "SteamHaze", "WindBuffeted"]:
		if _t.has(id):
			return COLOR[id]
	return null


func clear() -> void:
	_t.clear()
	_mag.clear()
	_dur.clear()
	_ignite_accum = 0.0
