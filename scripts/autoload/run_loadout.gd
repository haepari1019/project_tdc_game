extends Node
## Cross-scene run loadout (F-010) — the deployment screen sets the brought consumables; the
## dungeon scene reads them on start and adds them to the run inventory (At-Risk). Launching the
## dungeon directly (no deployment) leaves it empty. ref: F-010 §3.2 / F-007 §3.0.

var consumables: Dictionary = {}   # consumable_id -> count brought this run (deployment v1)
var backpack: Array = []           # brought run-inventory item dicts from the hub (At-Risk)
var member_subs: Array = []        # per party slot: [base_ability_id|"" ×3] equipped in the hub
var formation: Array = []          # [{class_id, offset:[x,z]}] formation slot offsets (hub editor)
var difficulty: String = ""        # hub-chosen run difficulty ("Normal"/"Hard"); "" = manifest default
var run_seed: int = 0              # per-run seed: weighted ENC resolve + spawn-position scatter (LDG-SPAWN-DEMO-001 §2)


func set_consumables(d: Dictionary) -> void:
	consumables = d.duplicate()


## Single source of truth for the run's difficulty: the hub selection if set, else the
## manifest default (so launching the dungeon scene directly still resolves a difficulty).
func get_difficulty() -> String:
	if not difficulty.is_empty():
		return difficulty
	return String(Slice01Data.get_manifest().get("difficulty_profile", "Normal"))


## Roll a fresh per-run seed (call once at run start). Drives the weighted ENC resolve +
## spawn-position scatter so repeated runs vary; stable for the whole run (reproducible).
func roll_run_seed() -> int:
	run_seed = randi()
	return run_seed


func get_run_seed() -> int:
	return run_seed
