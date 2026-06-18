extends Node
## Demo run state — DBP-DEMO-001 / QA-030 T-S01-BOOT. ref: F-006 §3.1.1

const RunPhase := preload("res://scripts/run/run_phase.gd")

signal run_booted(state: Dictionary)
signal run_phase_changed(phase: String)
signal room_changed(room_ref: String)
signal encounter_triggered(encounter_id: String, room_ref: String)
signal run_ended(result: String)
signal run_settled(summary: Dictionary)   # F-007 §3.8 — full settlement payload for the UI

var blueprint_id: String = ""
var map_id: String = ""
var contract_id: String = ""
var difficulty_profile: String = ""
var run_phase: String = ""
var current_room_ref: String = ""
var third_faction_enabled: bool = false
## GIMMICK-DEMO-01 objective state (F-007 풀 파이프라인 제외 — 스텁).
var objective_complete: bool = false
var run_over: bool = false

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
	}


## F-001 §3.3: swap works in combat too. §3.6: only Control Lock / MIA block it
## (neither implemented in slice-01) — so swap is always allowed for now.
## partyInCombat tracks combat state for other systems, NOT for gating swap.
func can_swap() -> bool:
	return true


func on_player_entered_room(room_ref: String) -> void:
	if room_ref == current_room_ref:
		return
	current_room_ref = room_ref
	room_changed.emit(room_ref)
	var row := Slice01Data.get_room_row(room_ref)
	var pool := String(row.get("pool_slot", ""))
	if not pool.is_empty():
		var layer := String(row.get("world_layer", "Upper"))
		var enc := Slice01Data.get_encounter_for_pool(pool, difficulty_profile, layer)
		if not enc.is_empty():
			encounter_triggered.emit(enc, room_ref)
	# Phase progression is data-driven (rooms.json `run_phase_on_enter`), advanced
	# monotonically along RunPhase.SEQUENCE so re-entering / branching never rewinds it.
	# Objective is NOT auto-completed on entry — the key-gate door calls
	# complete_objective() (GIMMICK-DEMO-01); the phase only mirrors room progression.
	var target_phase := String(row.get("run_phase_on_enter", ""))
	if not target_phase.is_empty():
		var ti := RunPhase.SEQUENCE.find(target_phase)
		if ti > _phase_index:
			_set_phase(target_phase)


func complete_objective() -> void:
	if objective_complete:
		return
	objective_complete = true
	print("[TDC] Objective GIMMICK-DEMO-01 complete (stub)")


## ExtractionActivate precondition (F-007 §3.1.2) — objective done + run still active.
## The cohesion gate (§3.6.2) and casualty/loot composition live in the scene
## (dungeon_run), which owns the party + inventory and calls settle_extraction().
func can_extract() -> bool:
	return not run_over and objective_complete


## F-007 §3.6 — finalize Extraction Success (incl. Partial). `summary` is built by the
## scene from party survivors/casualties + run-inventory At-Risk → Safe.
func settle_extraction(summary: Dictionary) -> void:
	if run_over:
		return
	run_over = true
	var result := String(summary.get("result", "Extraction Success"))
	run_ended.emit(result)
	run_settled.emit(summary)
	print("[TDC] Run settled: %s — survivors=%s casualties=%s safe=%d stacks" % [
		result, summary.get("survivors", []), summary.get("casualties", []),
		(summary.get("safe_items", []) as Array).size()])


## F-007 §3.7 — finalize Run Failure (PartyWipe/RunAbandon). Run-inventory At-Risk
## becomes the Loss Bundle (Recovery Target persistence deferred to a later increment).
func settle_failure(cause: String, summary: Dictionary) -> void:
	if run_over:
		return
	run_over = true
	run_ended.emit("Run Failure")
	run_settled.emit(summary)
	print("[TDC] Run FAILURE: %s — loss bundle=%d At-Risk stacks (Recovery Target deferred)" % [
		cause, (summary.get("lost_items", []) as Array).size()])


func _set_phase(phase: String) -> void:
	if run_phase == phase:
		return
	run_phase = phase
	_phase_index = RunPhase.SEQUENCE.find(phase)
	run_phase_changed.emit(run_phase)
	print("[TDC] runPhase -> ", run_phase)
