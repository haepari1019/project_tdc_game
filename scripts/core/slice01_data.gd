extends Node
## Loads and validates res://data/slice01/* at startup. ref: QA-030 §2, ENC-000 §8.

const IdValidate := preload("res://scripts/core/validate_ids.gd")

const SLICE01_DIR := "res://data/slice01/"
const MANIFEST_PATH := SLICE01_DIR + "manifest.json"
const REGISTRY_PATH := SLICE01_DIR + "id_registry.json"
const IDENTITIES_PATH := SLICE01_DIR + "identities.json"
const ENEMIES_PATH := SLICE01_DIR + "enemies.json"
const ABILITIES_PATH := SLICE01_DIR + "abilities.json"
const ROOMS_PATH := SLICE01_DIR + "rooms.json"
const BLUEPRINT_PATH := SLICE01_DIR + "blueprint.json"

var _loaded: bool = false
var _manifest: Dictionary = {}
var _registry: Dictionary = {}
var _identities: Array = []
var _enemies: Dictionary = {}
var _abilities: Dictionary = {}
var _encounters: Dictionary = {}
var _rooms: Dictionary = {}
var _blueprint: Dictionary = {}


func _ready() -> void:
	if not _load_and_validate():
		push_error("[TDC] Slice01 data validation failed — aborting")
		call_deferred("_abort")


func _abort() -> void:
	get_tree().quit(1)


func is_loaded() -> bool:
	return _loaded


func get_manifest() -> Dictionary:
	return _manifest.duplicate(true)


func get_identity_rows() -> Array:
	var out: Array = []
	for row in _identities:
		if row is Dictionary:
			out.append(row.duplicate(true))
	return out


func get_identity_skill_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for row in _identities:
		if row is Dictionary:
			out.append(String(row.get("identity_skill_id", "")))
	return out


func get_encounter(encounter_id: String) -> Dictionary:
	if _encounters.has(encounter_id):
		return _encounters[encounter_id].duplicate(true)
	return {}


## Demo placeholder defaults — merged when an enemy row omits a stat field.
const _DEFAULT_ENEMY_STATS := {
	"hp": 50.0, "move_speed": 3.5, "contact_damage": 6.0,
	"attack_range_m": 1.6, "attack_interval_s": 1.2,
}


## Returns the enemy row with a fully-populated `stats` block (defaults merged).
func get_enemy_row(enemy_id: String) -> Dictionary:
	if not _enemies.has(enemy_id):
		return {}
	var row: Dictionary = _enemies[enemy_id].duplicate(true)
	var stats: Dictionary = _DEFAULT_ENEMY_STATS.duplicate()
	var raw_stats = row.get("stats", {})
	if typeof(raw_stats) == TYPE_DICTIONARY:
		stats.merge(raw_stats, true)
	row["stats"] = stats
	return row


## Shared ability effect/params by id (party identity + enemy). {} if unknown.
## Characters/units link to abilities by id — assign a skill once, use anywhere.
func get_ability(ability_id: String) -> Dictionary:
	var ab = _abilities.get(ability_id, {})
	return ab.duplicate(true) if typeof(ab) == TYPE_DICTIONARY else {}


func get_blueprint() -> Dictionary:
	return _blueprint.duplicate(true)


func get_rooms_document() -> Dictionary:
	return _rooms.duplicate(true)


func get_room_row(room_ref: String) -> Dictionary:
	for row in _rooms.get("rooms", []):
		if typeof(row) == TYPE_DICTIONARY and String(row.get("room_ref", "")) == room_ref:
			return row.duplicate(true)
	return {}


func get_pool_encounter(pool_slot: String) -> String:
	var enc_map: Dictionary = _manifest.get("encounters", {})
	if typeof(enc_map) != TYPE_DICTIONARY:
		return ""
	return String(enc_map.get(pool_slot, ""))


func get_summary() -> String:
	return "slice01 manifest=%s encounters=%d identities=%d" % [
		_manifest.get("contract", "?"),
		_encounters.size(),
		_identities.size(),
	]


func _load_and_validate() -> bool:
	var errors: Array[String] = []
	_manifest = _read_json_dict(MANIFEST_PATH, "manifest", errors)
	_registry = _read_json_dict(REGISTRY_PATH, "id_registry", errors)
	var identities_doc := _read_json_dict(IDENTITIES_PATH, "identities", errors)
	var enemies_doc := _read_json_dict(ENEMIES_PATH, "enemies", errors)
	var abilities_doc := _read_json_dict(ABILITIES_PATH, "abilities", errors)
	_rooms = _read_json_dict(ROOMS_PATH, "rooms", errors)
	_blueprint = _read_json_dict(BLUEPRINT_PATH, "blueprint", errors)

	if errors.is_empty():
		_validate_blueprint(errors)
		_parse_identities(identities_doc, errors)
		_parse_enemies(enemies_doc, errors)
		_parse_abilities(abilities_doc, errors)
		_validate_manifest(errors)
		_load_encounters(errors)
		_validate_rooms(errors)

	if not errors.is_empty():
		for err in errors:
			push_error("[TDC] " + err)
		return false

	_loaded = true
	return true


func _read_json_dict(path: String, label: String, errors: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("Missing %s: %s" % [label, path])
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		errors.append("Cannot open %s: %s" % [label, path])
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("%s must be a JSON object: %s" % [label, path])
		return {}
	return parsed


func _registry_list(key: String) -> Array:
	var raw = _registry.get(key, [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	return raw


func _parse_identities(doc: Dictionary, errors: Array[String]) -> void:
	var raw = doc.get("identities", [])
	if typeof(raw) != TYPE_ARRAY:
		errors.append("identities.json: 'identities' must be an array")
		return
	_identities.clear()
	var allowed_identity: Array = _registry_list("identity_skill_ids")
	var allowed_class: Array = _registry_list("class_ids")
	var allowed_ability: Array = _registry_list("ability_ids")
	var allowed_pattern: Array = _registry_list("pattern_ids")
	for row in raw:
		if typeof(row) != TYPE_DICTIONARY:
			errors.append("identities.json: each identity must be an object")
			continue
		var iid := String(row.get("identity_skill_id", ""))
		IdValidate.require_id(iid, allowed_identity, "identity_skill_id", errors)
		IdValidate.require_id(String(row.get("class_id", "")), allowed_class, "class_id", errors)
		IdValidate.require_id(String(row.get("ability_id", "")), allowed_ability, "ability_id", errors)
		var sub_id := String(row.get("sub_ability_id", ""))
		if not sub_id.is_empty():
			IdValidate.require_id(sub_id, allowed_ability, "sub_ability_id", errors)
		IdValidate.require_id(String(row.get("pattern_id", "")), allowed_pattern, "pattern_id", errors)
		_identities.append(row)


func _parse_enemies(doc: Dictionary, errors: Array[String]) -> void:
	var raw = doc.get("enemies", [])
	if typeof(raw) != TYPE_ARRAY:
		errors.append("enemies.json: 'enemies' must be an array")
		return
	_enemies.clear()
	var allowed: Array = _registry_list("enemy_ids")
	for row in raw:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var eid := String(row.get("enemy_id", ""))
		IdValidate.require_id(eid, allowed, "enemy_id", errors)
		_enemies[eid] = row


func _parse_abilities(doc: Dictionary, errors: Array[String]) -> void:
	var raw = doc.get("abilities", {})
	_abilities = raw if typeof(raw) == TYPE_DICTIONARY else {}
	# DRIFT-006: enforce id_registry on the unified ability catalog (ENC-000 §8 spirit).
	var allowed: Array = _registry_list("ability_ids")
	for ab_id in _abilities.keys():
		IdValidate.require_id(String(ab_id), allowed, "ability_id", errors)


func _validate_blueprint(errors: Array[String]) -> void:
	IdValidate.require_id(
		String(_blueprint.get("blueprint_id", "")),
		_registry_list("blueprint_ids"),
		"blueprint_id",
		errors
	)
	if String(_blueprint.get("map_id", "")) != String(_manifest.get("map_id", "")):
		errors.append("blueprint.json map_id must match manifest")
	if String(_blueprint.get("contract_id", "")) != String(_manifest.get("contract_id", "")):
		errors.append("blueprint.json contract_id must match manifest")
	if bool(_blueprint.get("third_faction", {}).get("enabled", false)):
		errors.append("Slice-01: third_faction must be disabled in blueprint.json")


func _validate_manifest(errors: Array[String]) -> void:
	IdValidate.require_id(
		String(_manifest.get("blueprint_id", "")),
		_registry_list("blueprint_ids"),
		"blueprint_id",
		errors
	)
	IdValidate.require_id(
		String(_manifest.get("map_id", "")),
		_registry_list("map_ids"),
		"map_id",
		errors
	)
	IdValidate.require_id(
		String(_manifest.get("contract_id", "")),
		_registry_list("contract_ids"),
		"contract_id",
		errors
	)
	var required_enc := String(_manifest.get("required_encounter_smoke", ""))
	IdValidate.require_id(required_enc, _registry_list("encounter_ids"), "encounter_id", errors)
	var manifest_identities: Array = _manifest.get("identity_skill_ids", [])
	if typeof(manifest_identities) != TYPE_ARRAY:
		errors.append("manifest.json: identity_skill_ids must be an array")
		return
	var allowed_identity: Array = _registry_list("identity_skill_ids")
	for iid in manifest_identities:
		IdValidate.require_id(String(iid), allowed_identity, "identity_skill_id", errors)
	if manifest_identities.size() != 4:
		errors.append("manifest.json: expected 4 identity_skill_ids (QA-030)")
	var enc_map: Dictionary = _manifest.get("encounters", {})
	if typeof(enc_map) != TYPE_DICTIONARY:
		errors.append("manifest.json: encounters must be an object")
		return
	var allowed_enc: Array = _registry_list("encounter_ids")
	var allowed_pools: Array = _registry_list("pool_slots")
	for pool_key in enc_map.keys():
		IdValidate.require_id(String(pool_key), allowed_pools, "pool_slot", errors)
		IdValidate.require_id(String(enc_map[pool_key]), allowed_enc, "encounter_id", errors)


func _load_encounters(errors: Array[String]) -> void:
	_encounters.clear()
	var enc_map: Dictionary = _manifest.get("encounters", {})
	if typeof(enc_map) != TYPE_DICTIONARY:
		return
	var seen: Dictionary = {}
	for pool_key in enc_map.keys():
		var enc_id := String(enc_map[pool_key])
		if seen.has(enc_id):
			continue
		seen[enc_id] = true
		var path := SLICE01_DIR + "encounters/%s.json" % enc_id
		var doc := _read_json_dict(path, "encounter", errors)
		if doc.is_empty():
			errors.append("Missing encounter data for '%s' at %s" % [enc_id, path])
			continue
		if String(doc.get("encounter_id", "")) != enc_id:
			errors.append("encounter_id mismatch in %s (expected %s)" % [path, enc_id])
		_validate_encounter_units(doc, errors)
		_encounters[enc_id] = doc


func _validate_encounter_units(doc: Dictionary, errors: Array[String]) -> void:
	var units: Array = doc.get("units", [])
	if typeof(units) != TYPE_ARRAY:
		errors.append("encounter %s: units must be an array" % doc.get("encounter_id", "?"))
		return
	for u in units:
		if typeof(u) != TYPE_DICTIONARY:
			continue
		var eid := String(u.get("enemy_id", ""))
		if not _enemies.has(eid):
			IdValidate.require_id(eid, _registry_list("enemy_ids"), "enemy_id", errors)


func _validate_rooms(errors: Array[String]) -> void:
	if String(_rooms.get("map_id", "")) != String(_manifest.get("map_id", "")):
		errors.append("rooms.json map_id must match manifest map_id")
	var allowed_rooms: Array = _registry_list("room_refs")
	var raw: Array = _rooms.get("rooms", [])
	if typeof(raw) != TYPE_ARRAY:
		errors.append("rooms.json: rooms must be an array")
		return
	for row in raw:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		IdValidate.require_id(String(row.get("room_ref", "")), allowed_rooms, "room_ref", errors)
