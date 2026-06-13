extends Node
## Cross-scene run loadout (F-010) — the deployment screen sets the brought consumables; the
## dungeon scene reads them on start and adds them to the run inventory (At-Risk). Launching the
## dungeon directly (no deployment) leaves it empty. ref: F-010 §3.2 / F-007 §3.0.

var consumables: Dictionary = {}   # consumable_id -> count brought this run (deployment v1)
var backpack: Array = []           # brought run-inventory item dicts from the hub (At-Risk)
var member_subs: Array = []        # per party slot: [base_ability_id|"" ×3] equipped in the hub


func set_consumables(d: Dictionary) -> void:
	consumables = d.duplicate()
