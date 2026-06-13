extends RefCounted
## Consumable effect (effect=revive_ally) — revive the first dead party member at 50% HP.
## Drop-in effect: ADD A CONSUMABLE EFFECT = new file here + one preload line in
## ConsumableController._EFFECT_SCRIPTS. kind() = the consumable master's `effect` string. ref: D-020.

func kind() -> String:
	return "revive_ally"


## ctx = ConsumableController (exposes get_party()). Returns true if applied.
func apply(_master: Dictionary, ctx) -> bool:
	var party = ctx.get_party()
	if party == null:
		return false
	for m in party.get_members():
		if not (m as Node).is_alive():
			return (m as Node).revive(0.5)
	return false
