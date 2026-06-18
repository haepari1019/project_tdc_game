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
const GEAR_PATH := SLICE01_DIR + "gear.json"
const SKILLBOOKS_PATH := SLICE01_DIR + "skillbooks.json"
const CONSUMABLES_PATH := SLICE01_DIR + "consumables.json"
const SPAWN_TABLE_PATH := SLICE01_DIR + "spawn_table.json"
const ENEMY_BASICS_PATH := SLICE01_DIR + "enemy_basics.json"
const PATTERNS_PATH := SLICE01_DIR + "patterns.json"

var _loaded: bool = false
var _manifest: Dictionary = {}
var _registry: Dictionary = {}
var _identities: Array = []
var _enemies: Dictionary = {}
var _abilities: Dictionary = {}
var _encounters: Dictionary = {}
var _rooms: Dictionary = {}
var _blueprint: Dictionary = {}
var _gear: Array = []
var _gear_by_id: Dictionary = {}
var _skillbooks: Array = []
var _skillbook_by_ability: Dictionary = {}
var _consumables: Array = []
var _consumable_by_id: Dictionary = {}
## LDG-SPAWN-DEMO-001 — (pool, difficulty, world_layer) -> encounter_ref rows + force overrides.
var _spawn_rows: Array = []
var _spawn_overrides: Dictionary = {}
## Enemy basic-attack archetypes (rom_*) — EN-COR-000 §rom_*. Keyed by rom id.
var _enemy_basics: Dictionary = {}
## Enemy combat patterns (PT-###) — D-017 / EN-AI-000 §1. Keyed by pattern id.
var _patterns: Dictionary = {}


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


## Identity row (identities.json) by identity_skill_id. {} if unknown.
func get_identity_row(identity_skill_id: String) -> Dictionary:
	for row in _identities:
		if typeof(row) == TYPE_DICTIONARY and String(row.get("identity_skill_id", "")) == identity_skill_id:
			return row.duplicate(true)
	return {}


## Identity Gear masters (gear.json). Identity is gear-bound (F-008 §3.7).
func get_gear_rows() -> Array:
	var out: Array = []
	for row in _gear:
		if row is Dictionary:
			out.append(row.duplicate(true))
	return out


func get_gear_master(base_gear_id: String) -> Dictionary:
	var g = _gear_by_id.get(base_gear_id, {})
	return g.duplicate(true) if typeof(g) == TYPE_DICTIONARY else {}


## Starter gear whose bundled identity == identity_skill_id (1:1). {} if none.
func get_starter_gear_for_identity(identity_skill_id: String) -> Dictionary:
	for row in _gear:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if bool(row.get("starter", false)) and String(row.get("bundled_identity_skill_id", "")) == identity_skill_id:
			return row.duplicate(true)
	return {}


## Skillbook masters (skillbooks.json). Looted per-kill from an enemy's lootable AB
## (F-009 / DEC-20260611-002). Keyed by base_ability_id (Shared AB).
func get_skillbook_rows() -> Array:
	var out: Array = []
	for row in _skillbooks:
		if row is Dictionary:
			out.append(row.duplicate(true))
	return out


func get_skillbook_master(base_ability_id: String) -> Dictionary:
	var s = _skillbook_by_ability.get(base_ability_id, {})
	return s.duplicate(true) if typeof(s) == TYPE_DICTIONARY else {}


## Consumable masters (consumables.json). Z/X/C hotkey items (F-010).
func get_consumable_rows() -> Array:
	var out: Array = []
	for row in _consumables:
		if row is Dictionary:
			out.append(row.duplicate(true))
	return out


func get_consumable_master(consumable_id: String) -> Dictionary:
	var c = _consumable_by_id.get(consumable_id, {})
	return c.duplicate(true) if typeof(c) == TYPE_DICTIONARY else {}


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


## Enemy basic-attack archetype (rom_*) effect/params by id. {} if unknown.
## Separate catalog from AB-### (EN-COR-000 §rom_*; not D-016). Enemy basics bind here.
func get_enemy_basic(rom_id: String) -> Dictionary:
	var b = _enemy_basics.get(rom_id, {})
	return b.duplicate(true) if typeof(b) == TYPE_DICTIONARY else {}


## Enemy combat pattern (PT-###) catalog row by id — D-017 / EN-AI-000. {} if unknown.
## Drives engaged positioning (engage profile + tuning) in enemy_ai.
func get_pattern(pattern_id: String) -> Dictionary:
	var p = _patterns.get(pattern_id, {})
	return p.duplicate(true) if typeof(p) == TYPE_DICTIONARY else {}


func get_blueprint() -> Dictionary:
	return _blueprint.duplicate(true)


func get_rooms_document() -> Dictionary:
	return _rooms.duplicate(true)


func get_room_row(room_ref: String) -> Dictionary:
	for row in _rooms.get("rooms", []):
		if typeof(row) == TYPE_DICTIONARY and String(row.get("room_ref", "")) == room_ref:
			return row.duplicate(true)
	return {}


## Legacy direct manifest lookup (DBP-DEMO-001 §5 flat binding). Prefer
## get_encounter_for_pool() — kept for back-compat / fallback.
func get_pool_encounter(pool_slot: String) -> String:
	var enc_map: Dictionary = _manifest.get("encounters", {})
	if typeof(enc_map) != TYPE_DICTIONARY:
		return ""
	return String(enc_map.get(pool_slot, ""))


## Resolve a pool slot's encounter via the spawn table (LDG-SPAWN-DEMO-001):
## force override > exact (pool, difficulty, world_layer) > (pool, difficulty) any-layer > "".
## Returns "" when no row matches the run's difficulty for this pool (difficulty-gated slot).
func get_encounter_for_pool(pool_slot: String, difficulty: String, world_layer: String) -> String:
	if pool_slot.is_empty():
		return ""
	if _spawn_overrides.has(pool_slot):
		return String(_spawn_overrides[pool_slot])
	var any_layer := ""
	for row in _spawn_rows:
		var r := row as Dictionary
		if String(r.get("pool_slot", "")) != pool_slot:
			continue
		if String(r.get("difficulty", "")) != difficulty:
			continue
		if String(r.get("world_layer", "")) == world_layer:
			return String(r.get("encounter_ref", ""))
		if any_layer.is_empty():
			any_layer = String(r.get("encounter_ref", ""))
	return any_layer


func get_summary() -> String:
	return "slice01 manifest=%s encounters=%d identities=%d gear=%d skillbooks=%d" % [
		_manifest.get("contract", "?"),
		_encounters.size(),
		_identities.size(),
		_gear.size(),
		_skillbooks.size(),
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
	var gear_doc := _read_json_dict(GEAR_PATH, "gear", errors)
	var skillbooks_doc := _read_json_dict(SKILLBOOKS_PATH, "skillbooks", errors)
	var consumables_doc := _read_json_dict(CONSUMABLES_PATH, "consumables", errors)
	var spawn_table_doc := _read_json_dict(SPAWN_TABLE_PATH, "spawn_table", errors)
	var enemy_basics_doc := _read_json_dict(ENEMY_BASICS_PATH, "enemy_basics", errors)
	var patterns_doc := _read_json_dict(PATTERNS_PATH, "patterns", errors)

	if errors.is_empty():
		_validate_blueprint(errors)
		_parse_identities(identities_doc, errors)
		_parse_gear(gear_doc, errors)
		_parse_skillbooks(skillbooks_doc, errors)
		_parse_consumables(consumables_doc, errors)
		_parse_enemy_basics(enemy_basics_doc, errors)
		_parse_patterns(patterns_doc, errors)
		_parse_enemies(enemies_doc, errors)
		_parse_abilities(abilities_doc, errors)
		_validate_manifest(errors)
		_parse_spawn_table(spawn_table_doc, errors)
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
		IdValidate.require_id(String(row.get("pattern_id", "")), allowed_pattern, "pattern_id", errors)
		_identities.append(row)


const _GEAR_KINDS := ["WardGear", "Magitech"]
const _RANGE_BANDS := ["Melee", "Mid", "Long"]
const _UNLOCK_STATES := ["Locked", "Purchasable", "Owned"]


## Identity Gear masters (F-008 §3.7). base_gear_id, bundled identity (-> identities),
## basic attack profile, equip_classes (role gate). Validated against id_registry.
func _parse_gear(doc: Dictionary, errors: Array[String]) -> void:
	var raw = doc.get("gear", [])
	if typeof(raw) != TYPE_ARRAY:
		errors.append("gear.json: 'gear' must be an array")
		return
	_gear.clear()
	_gear_by_id.clear()
	var allowed_gear: Array = _registry_list("base_gear_ids")
	var allowed_identity: Array = _registry_list("identity_skill_ids")
	var allowed_class: Array = _registry_list("class_ids")
	var allowed_ba: Array = _registry_list("basic_attack_profile_ids")
	for row in raw:
		if typeof(row) != TYPE_DICTIONARY:
			errors.append("gear.json: each gear must be an object")
			continue
		var gid := String(row.get("base_gear_id", ""))
		IdValidate.require_id(gid, allowed_gear, "base_gear_id", errors)
		var bid := String(row.get("bundled_identity_skill_id", ""))
		IdValidate.require_id(bid, allowed_identity, "bundled_identity_skill_id", errors)
		IdValidate.require_id(String(row.get("basic_attack_profile_id", "")), allowed_ba, "basic_attack_profile_id", errors)
		var classes = row.get("equip_classes", [])
		if typeof(classes) != TYPE_ARRAY or classes.is_empty():
			errors.append("gear.json %s: equip_classes must be a non-empty array" % gid)
		else:
			for c in classes:
				IdValidate.require_id(String(c), allowed_class, "equip_classes", errors)
		if not _GEAR_KINDS.has(String(row.get("gear_kind", ""))):
			errors.append("gear.json %s: invalid gear_kind" % gid)
		if not _RANGE_BANDS.has(String(row.get("range_band", ""))):
			errors.append("gear.json %s: invalid range_band" % gid)
		if not _UNLOCK_STATES.has(String(row.get("unlock_state", "Owned"))):
			errors.append("gear.json %s: invalid unlock_state" % gid)
		# 1:1 bundled identity must resolve to an identities.json row (F-008 §3.7, QA-008).
		if not bid.is_empty() and get_identity_row(bid).is_empty():
			errors.append("gear.json %s: bundled_identity_skill_id '%s' not in identities.json" % [gid, bid])
		_gear.append(row)
		_gear_by_id[gid] = row


## Skillbook masters (F-009 §3.2 / DEC-20260611-002). base_ability_id (Shared AB,
## D-016), equip_classes (role gate), charges_max (탄수), player-cast effect (cast).
func _parse_skillbooks(doc: Dictionary, errors: Array[String]) -> void:
	var raw = doc.get("skillbooks", [])
	if typeof(raw) != TYPE_ARRAY:
		errors.append("skillbooks.json: 'skillbooks' must be an array")
		return
	_skillbooks.clear()
	_skillbook_by_ability.clear()
	var allowed_ability: Array = _registry_list("ability_ids")
	var allowed_class: Array = _registry_list("class_ids")
	for row in raw:
		if typeof(row) != TYPE_DICTIONARY:
			errors.append("skillbooks.json: each skillbook must be an object")
			continue
		var aid := String(row.get("base_ability_id", ""))
		IdValidate.require_id(aid, allowed_ability, "base_ability_id", errors)
		var classes = row.get("equip_classes", [])
		if typeof(classes) != TYPE_ARRAY or classes.is_empty():
			errors.append("skillbooks.json %s: equip_classes must be a non-empty array" % aid)
		else:
			for c in classes:
				IdValidate.require_id(String(c), allowed_class, "equip_classes", errors)
		if not _RANGE_BANDS.has(String(row.get("range_band", ""))):
			errors.append("skillbooks.json %s: invalid range_band" % aid)
		if int(row.get("charges_max", 0)) <= 0:
			errors.append("skillbooks.json %s: charges_max must be > 0" % aid)
		var cast = row.get("cast", {})
		if typeof(cast) != TYPE_DICTIONARY or String(cast.get("kind", "")).is_empty():
			errors.append("skillbooks.json %s: cast.kind required" % aid)
		_skillbooks.append(row)
		_skillbook_by_ability[aid] = row


## Consumable masters (F-010 / D-020). consumable_id, effect, max_stack, usable_in_combat.
func _parse_consumables(doc: Dictionary, errors: Array[String]) -> void:
	var raw = doc.get("consumables", [])
	if typeof(raw) != TYPE_ARRAY:
		errors.append("consumables.json: 'consumables' must be an array")
		return
	_consumables.clear()
	_consumable_by_id.clear()
	var allowed: Array = _registry_list("consumable_ids")
	for row in raw:
		if typeof(row) != TYPE_DICTIONARY:
			errors.append("consumables.json: each consumable must be an object")
			continue
		var cid := String(row.get("consumable_id", ""))
		IdValidate.require_id(cid, allowed, "consumable_id", errors)
		if String(row.get("effect", "")).is_empty():
			errors.append("consumables.json %s: effect required" % cid)
		if int(row.get("max_stack", 0)) <= 0:
			errors.append("consumables.json %s: max_stack must be > 0" % cid)
		_consumables.append(row)
		_consumable_by_id[cid] = row


## Spawn table (LDG-SPAWN-DEMO-001). Rows = (pool, difficulty, world_layer) -> encounter_ref;
## force_overrides win per pool (DBP-DEMO-001 §5.1). pool/encounter validated against id_registry.
func _parse_spawn_table(doc: Dictionary, errors: Array[String]) -> void:
	_spawn_rows.clear()
	_spawn_overrides.clear()
	var allowed_enc: Array = _registry_list("encounter_ids")
	var allowed_pools: Array = _registry_list("pool_slots")
	var rows = doc.get("rows", [])
	if typeof(rows) != TYPE_ARRAY:
		errors.append("spawn_table.json: 'rows' must be an array")
		return
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			errors.append("spawn_table.json: each row must be an object")
			continue
		IdValidate.require_id(String(row.get("pool_slot", "")), allowed_pools, "pool_slot", errors)
		IdValidate.require_id(String(row.get("encounter_ref", "")), allowed_enc, "encounter_id", errors)
		_spawn_rows.append(row)
	var ov = doc.get("force_overrides", {})
	if typeof(ov) == TYPE_DICTIONARY:
		for pool_key in ov.keys():
			IdValidate.require_id(String(pool_key), allowed_pools, "pool_slot", errors)
			IdValidate.require_id(String(ov[pool_key]), allowed_enc, "encounter_id", errors)
			_spawn_overrides[String(pool_key)] = String(ov[pool_key])


## Enemy basic-attack archetypes (rom_*). Keyed by rom id, validated against id_registry.
func _parse_enemy_basics(doc: Dictionary, errors: Array[String]) -> void:
	_enemy_basics.clear()
	var raw = doc.get("basics", {})
	if typeof(raw) != TYPE_DICTIONARY:
		errors.append("enemy_basics.json: 'basics' must be an object")
		return
	var allowed: Array = _registry_list("enemy_basic_attack_ids")
	for rom_id in raw.keys():
		IdValidate.require_id(String(rom_id), allowed, "enemy_basic_attack_id", errors)
		if typeof(raw[rom_id]) == TYPE_DICTIONARY:
			_enemy_basics[String(rom_id)] = raw[rom_id]


## Enemy combat patterns (PT-###, D-017 / EN-AI-000 §1). Keyed by pattern id, validated
## against id_registry. 'engage' (positioning dispatch) gated to the known profile enum.
const _ENGAGE_PROFILES := ["advance", "standoff", "kite", "zone", "orbit", "probe", "surround"]


func _parse_patterns(doc: Dictionary, errors: Array[String]) -> void:
	_patterns.clear()
	var raw = doc.get("patterns", {})
	if typeof(raw) != TYPE_DICTIONARY:
		errors.append("patterns.json: 'patterns' must be an object")
		return
	var allowed: Array = _registry_list("pattern_ids")
	for pat_id in raw.keys():
		IdValidate.require_id(String(pat_id), allowed, "pattern_id", errors)
		var row = raw[pat_id]
		if typeof(row) != TYPE_DICTIONARY:
			errors.append("patterns.json %s: row must be an object" % pat_id)
			continue
		var engage := String(row.get("engage", ""))
		if not _ENGAGE_PROFILES.has(engage):
			errors.append("patterns.json %s: invalid engage '%s'" % [pat_id, engage])
		_patterns[String(pat_id)] = row


func _parse_enemies(doc: Dictionary, errors: Array[String]) -> void:
	var raw = doc.get("enemies", [])
	if typeof(raw) != TYPE_ARRAY:
		errors.append("enemies.json: 'enemies' must be an array")
		return
	_enemies.clear()
	var allowed: Array = _registry_list("enemy_ids")
	var allowed_basics: Array = _registry_list("enemy_basic_attack_ids")
	var allowed_ability: Array = _registry_list("ability_ids")
	var allowed_pattern: Array = _registry_list("pattern_ids")
	for row in raw:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var eid := String(row.get("enemy_id", ""))
		IdValidate.require_id(eid, allowed, "enemy_id", errors)
		# Basic attack = rom_* archetype (enemy_basics); signature abilities[].ref = AB-### catalog.
		var basic := String(row.get("basic_attack", ""))
		if not basic.is_empty():
			IdValidate.require_id(basic, allowed_basics, "enemy_basic_attack_id", errors)
		for ab in row.get("abilities", []):
			if typeof(ab) == TYPE_DICTIONARY:
				IdValidate.require_id(String(ab.get("ref", "")), allowed_ability, "ability_id", errors)
		# Engaged positioning pattern (EN-AI-000) — must resolve to patterns.json (PT-###).
		var pat := String(row.get("pattern_ref", ""))
		IdValidate.require_id(pat, allowed_pattern, "pattern_ref", errors)
		if not pat.is_empty() and not _patterns.has(pat):
			errors.append("enemies.json %s: pattern_ref '%s' not in patterns.json" % [eid, pat])
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


## Load every encounter referenced by the manifest (flat/forced) AND the spawn table
## (rows + force overrides), so resolver-bound MID/DEEP/BOSS encounters are spawnable.
func _load_encounters(errors: Array[String]) -> void:
	_encounters.clear()
	var seen: Dictionary = {}
	var enc_ids: Array = []
	var enc_map: Dictionary = _manifest.get("encounters", {})
	if typeof(enc_map) == TYPE_DICTIONARY:
		for pool_key in enc_map.keys():
			var e := String(enc_map[pool_key])
			if not e.is_empty() and not seen.has(e):
				seen[e] = true
				enc_ids.append(e)
	for row in _spawn_rows:
		var e := String((row as Dictionary).get("encounter_ref", ""))
		if not e.is_empty() and not seen.has(e):
			seen[e] = true
			enc_ids.append(e)
	for pool_key in _spawn_overrides.keys():
		var e := String(_spawn_overrides[pool_key])
		if not e.is_empty() and not seen.has(e):
			seen[e] = true
			enc_ids.append(e)
	for enc_id in enc_ids:
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
