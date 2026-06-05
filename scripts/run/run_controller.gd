extends Node
## Demo run state — DBP-DEMO-001 / QA-030 T-S01-BOOT. ref: F-006 §3.1.1

const RunPhase := preload("res://scripts/run/run_phase.gd")

signal run_booted(state: Dictionary)
signal run_phase_changed(phase: String)
signal room_changed(room_ref: String)

var blueprint_id: String = ""
var map_id: String = ""
var contract_id: String = ""
var difficulty_profile: String = ""
var run_phase: String = ""
var current_room_ref: String = ""
var third_faction_enabled: bool = false
var party_in_combat: bool = false

var _phase_index: int = 0


func start_run(spawn_room_ref: String = "RM-ENTRY-01") -> void:
	if not Slice01Data.is_loaded():
		push_error("[TDC] RunController: Slice01Data not loaded")
		return
	var manifest := Slice01Data.get_manifest()
	var bp := Slice01Data.get_blueprint()
	blueprint_id = String(manifest.get("blueprint_id", ""))
	map_id = String(manifest.get("map_id", ""))
	contract_id = String(manifest.get("contract_id", ""))
	difficulty_profile = String(manifest.get("difficulty_profile", "Normal"))
	third_faction_enabled = bool(bp.get("third_faction", {}).get("enabled", false))
	_phase_index = 0
	run_phase = RunPhase.ENTRY
	current_room_ref = spawn_room_ref
	var state := get_state()
	run_booted.emit(state)
	run_phase_changed.emit(run_phase)
	room_changed.emit(current_room_ref)
	print("[TDC] Run boot — mapId=%s runPhase=%s room=%s thirdFaction=%s" % [
		map_id, run_phase, current_room_ref, third_faction_enabled
	])


func get_state() -> Dictionary:
	return {
		"blueprint_id": blueprint_id,
		"map_id": map_id,
		"contract_id": contract_id,
		"difficulty_profile": difficulty_profile,
		"run_phase": run_phase,
		"current_room_ref": current_room_ref,
		"third_faction_enabled": third_faction_enabled,
		"party_in_combat": party_in_combat,
	}


func can_swap() -> bool:
	return not party_in_combat


func on_player_entered_room(room_ref: String) -> void:
	if room_ref == current_room_ref:
		return
	current_room_ref = room_ref
	room_changed.emit(room_ref)
	var row := Slice01Data.get_room_row(room_ref)
	var pool := String(row.get("pool_slot", ""))
	if not pool.is_empty():
		var enc := Slice01Data.get_pool_encounter(pool)
		print("[TDC] Pool %s -> %s (spawn deferred step 4+)" % [pool, enc])
	if room_ref == "RM-OBJ-01" and run_phase == RunPhase.ADVANCE:
		_set_phase(RunPhase.OBJECTIVE)
	elif room_ref == "RM-ROUTE-01" and run_phase == RunPhase.OBJECTIVE:
		_set_phase(RunPhase.ADVANCE_EXTRACTION)
	elif room_ref == "RM-EXT-01":
		_set_phase(RunPhase.EXTRACTION)


func advance_phase_debug() -> void:
	if _phase_index >= RunPhase.SEQUENCE.size() - 1:
		return
	_phase_index += 1
	_set_phase(RunPhase.SEQUENCE[_phase_index])


func _set_phase(phase: String) -> void:
	if run_phase == phase:
		return
	run_phase = phase
	_phase_index = RunPhase.SEQUENCE.find(phase)
	run_phase_changed.emit(run_phase)
	print("[TDC] runPhase -> ", run_phase)
