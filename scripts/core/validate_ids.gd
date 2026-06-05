extends RefCounted
## Slice-01 id registry checks (preloaded by Slice01Data).
## ENC-000 §8 spirit — unknown canonical IDs fail load (Slice-01 registry).


static func contains_id(id: String, allowed: Array) -> bool:
	return allowed.has(id)


static func unknown_id_error(id: String, domain: String) -> String:
	return "Unknown %s id: '%s' (not in slice01 id_registry)" % [domain, id]


static func require_id(id: String, allowed: Array, domain: String, errors: Array[String]) -> void:
	if not contains_id(id, allowed):
		errors.append(unknown_id_error(id, domain))
