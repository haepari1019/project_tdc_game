extends Node
## Cross-scene RUN CONFIG (F-010) — formation / difficulty / run seed chosen in the hub and read by
## the dungeon scene at run start. Inventory (consumables / skillbooks / gear) is NOT carried here:
## it moved to the **Backpack** autoload (loose + equipped) in the B-model unification (I2b/I3/I4),
## which survives the scene change and IS the hub→run bridge. This node is config-only now
## (the old consumables/backpack/member_subs bridges were removed in I5). ref: F-010 §3.2 / F-007.

var formation: Array = []     # [{class_id, offset:[x,z]}] formation slot offsets (hub editor)
var difficulty: String = ""   # hub-chosen run difficulty ("Normal"/"Hard"); "" = manifest default
var run_seed: int = 0         # per-run seed: weighted ENC resolve + spawn scatter (LDG-SPAWN-DEMO-001 §2)


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
