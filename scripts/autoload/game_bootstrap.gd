extends Node
## Loads spec_ref.json at startup. Rules SSOT remains in project_tdc (spec repo).

const SPEC_REF_PATH := "res://spec_ref.json"

var _spec_ref: Dictionary = {}


func _ready() -> void:
	_load_spec_ref()


func _load_spec_ref() -> void:
	if not FileAccess.file_exists(SPEC_REF_PATH):
		push_error("[TDC] Missing spec_ref.json")
		return
	var f := FileAccess.open(SPEC_REF_PATH, FileAccess.READ)
	if f == null:
		push_error("[TDC] Cannot open spec_ref.json")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[TDC] spec_ref.json must be a JSON object")
		return
	_spec_ref = parsed


func get_spec_ref() -> Dictionary:
	return _spec_ref.duplicate(true)


func get_spec_pin_summary() -> String:
	if _spec_ref.is_empty():
		return "(unloaded)"
	return "%s@%s (%s)" % [
		_spec_ref.get("spec_branch", "?"),
		_spec_ref.get("spec_commit_short", _spec_ref.get("spec_commit", "?")),
		_spec_ref.get("playable_contract_id", "?"),
	]


func get_identity_ids() -> PackedStringArray:
	# QA-030 §2 — loaded from data/slice01 (Slice01Data autoload)
	if Slice01Data.is_loaded():
		return Slice01Data.get_identity_skill_ids()
	return PackedStringArray()
