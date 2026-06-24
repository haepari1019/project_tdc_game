extends Node
## Backpack — the single persistent CARRIED inventory (At-Risk), the SoT for what the party brings
## into a run and keeps between runs (B-model unification). Distinct from Stash (safe storage).
##  · loose[]   = serializable item DESCRIPTORS in the pack (gear/skillbook/haul/consumable/generic).
##  · equipped{} = per-member assignment {member_key: {gear: base_gear_id, subs: [{base_ability_id,charges}×3]}}.
## Persisted as SaveProfile "backpack" section (single user://save.json). Loaded by BOTH the hub
## editor and the run inventory (autoload survives the scene change → it IS the hub→run bridge).
## SETTLE: extract keeps everything; death clears At-Risk = loose + equipped SUBS, but equipped GEAR
## is Safe (F-009 §3.7). ref: 사용자 B안 / F-007 / F-009 / DEC(meta-save).

var loose: Array = []          # [{id, kind, base_gear_id|base_ability_id|haul_material_id|consumable_id, w, h, count?, charges?, charges_max?, at_risk}]
var equipped: Dictionary = {}  # member_key(String) -> {"gear": base_gear_id|"", "subs": [ {base_ability_id, charges} | null ×3 ]}
var _seeded: bool = false
## 스타터 기어 id 스펙 정렬(GEAR-COR-000 §2) — 구 세이브의 _set id를 spec 슬러그로 1회 마이그레이션.
const GEAR_ID_ALIAS := {
	"gear_ward_tank_anchor_set": "gear_ward_tank_anchor_bulwark",
	"gear_ward_dps_press_set": "gear_ward_dps_press_rod",
	"gear_ward_nuker_ruin_set": "gear_ward_nuker_ruin_sight",
	"gear_ward_healer_mend_set": "gear_ward_healer_mend_lantern",
}


func _ready() -> void:
	var sp := get_node_or_null("/root/SaveProfile")
	var s: Dictionary = sp.section("backpack") if sp != null else {}
	if s.is_empty():
		_seed()
		save()
	else:
		loose = s.get("loose", [])
		equipped = s.get("equipped", {})
		_seeded = true
		_migrate_gear_ids()   # 구 세이브 _set id → spec 슬러그 (1회)


## Rewrite legacy starter gear ids (equipped + loose) to the spec slugs. ref: GEAR-COR-000 §2.
func _migrate_gear_ids() -> void:
	var dirty := false
	for k in equipped.keys():
		var e: Dictionary = equipped[k]
		var g := String(e.get("gear", ""))
		if GEAR_ID_ALIAS.has(g):
			e["gear"] = GEAR_ID_ALIAS[g]
			equipped[k] = e
			dirty = true
	for it in loose:
		if typeof(it) == TYPE_DICTIONARY and GEAR_ID_ALIAS.has(String(it.get("base_gear_id", ""))):
			it["base_gear_id"] = GEAR_ID_ALIAS[String(it["base_gear_id"])]
			dirty = true
	if dirty:
		save()


func save() -> void:
	var sp := get_node_or_null("/root/SaveProfile")
	if sp != null:
		sp.put("backpack", {"loose": loose, "equipped": equipped})


## First-run starting kit (demo seed — the old inventory_ui hardcoded backpack). Plain descriptors;
## the grid rebuilds full visuals via ItemFactory when it loads these.
func _seed() -> void:
	if _seeded:
		return
	_seeded = true
	# F-009 §3.1.1 Hub Starter Skillbooks (StarterGrant) — 역할별 핵심 유틸 1권(Healer 2권), 분석 불요·
	# 즉시 장착 가능. + 부활 소비. Gear는 equipped, haul은 런 중 드롭. (구 데모 Ember 스타터 → 스펙 정렬)
	loose = [
		{"id": "Intercept Step", "kind": "skillbook", "base_ability_id": "AB-033", "charges": 6, "charges_max": 6, "w": 1, "h": 1, "at_risk": true},
		{"id": "Guard Break Rhythm", "kind": "skillbook", "base_ability_id": "AB-028", "charges": 8, "charges_max": 8, "w": 1, "h": 1, "at_risk": true},
		{"id": "Voltaic Interrupt", "kind": "skillbook", "base_ability_id": "AB-030", "charges": 6, "charges_max": 6, "w": 1, "h": 1, "at_risk": true},
		{"id": "Hush Ward", "kind": "skillbook", "base_ability_id": "AB-044", "charges": 6, "charges_max": 6, "w": 1, "h": 1, "at_risk": true},
		{"id": "Lifeline", "kind": "skillbook", "base_ability_id": "AB-045", "charges": 5, "charges_max": 5, "w": 1, "h": 1, "at_risk": true},
		{"id": "con_revive_scroll", "kind": "consumable", "consumable_id": "con_revive_scroll", "count": 3, "w": 1, "h": 1},
	]
	# Worn starter Identity Gear per role (F-008 §3.7). Gear lives in equipped (Safe on death),
	# NOT in the Stash library — equipping a spare from the stash consumes it; the worn gear here.
	equipped = {
		"Tank": {"gear": "gear_ward_tank_anchor_bulwark", "subs": [null, null, null]},
		"DPS": {"gear": "gear_ward_dps_press_rod", "subs": [null, null, null]},
		"Nuker": {"gear": "gear_ward_nuker_ruin_sight", "subs": [null, null, null]},
		"Healer": {"gear": "gear_ward_healer_mend_lantern", "subs": [null, null, null]},
	}


## 테스트/디버그 — 캐리(낱개 + 장착)를 데모 시드로 초기화.
func reset_to_seed() -> void:
	loose = []
	equipped = {}
	_seeded = false
	_seed()
	save()


# --- loose carry API ---------------------------------------------------------

## Replace the loose contents (the run/hub commit their grid here). Strips runtime-only fields.
func set_loose(items: Array) -> void:
	loose = []
	for it in items:
		loose.append(_strip(it))
	save()


## A copy of the loose descriptors (the grid rebuilds full items from these).
func get_loose() -> Array:
	return loose.duplicate(true)


## Death (F-007 §3.7) — the whole loose carry is At-Risk → lost. Stash (safe) untouched.
func clear_loose() -> void:
	loose = []
	save()


# --- equipped assignment API (I3/I4 wire member slots to these) --------------

func set_member_gear(member_key: String, base_gear_id: String) -> void:
	var e: Dictionary = equipped.get(member_key, {})
	e["gear"] = base_gear_id
	equipped[member_key] = e
	save()


func set_member_subs(member_key: String, subs: Array) -> void:
	var e: Dictionary = equipped.get(member_key, {})
	e["subs"] = subs
	equipped[member_key] = e
	save()


func member_entry(member_key: String) -> Dictionary:
	var e = equipped.get(member_key, {})
	return e if typeof(e) == TYPE_DICTIONARY else {}


## Death — equipped SUBS are At-Risk (lost), equipped GEAR is Safe (kept). F-009 §3.7.
func clear_at_risk_equipped() -> void:
	for k in equipped.keys():
		var e: Dictionary = equipped[k]
		e["subs"] = [null, null, null]
		equipped[k] = e
	save()


## Apply persisted equipped GEAR + SUBS to a LIVE party (run start / hub load). Keyed by class_id
## (4 distinct roles). Gear overrides the starter spawn (F-008); equipping a sub resets it to max
## 탄수, so we then RESTORE the persisted remaining charges (I5) — a partially-spent skillbook carries
## its 탄수 across runs (F-009).
func apply_to_party(party) -> void:
	if party == null or not party.has_method("get_members"):
		return
	for m in party.get_members():
		if m == null or not is_instance_valid(m):
			continue
		var e: Dictionary = member_entry(String(m.get("class_id")))
		# Equipped Identity Gear — restore the persisted worn gear (overrides party_controller starter).
		var gid: String = String(e.get("gear", ""))
		if gid != "" and m.has_method("equip_gear"):
			var gm: Dictionary = Slice01Data.get_gear_master(gid)
			if not gm.is_empty():
				# F-008 §3.7 — 인스턴스 rolled identity/rolls 주입(있을 때만 → 없으면 bundled 폴백, G2).
				var rid := String(e.get("rolled_identity", ""))
				if rid != "":
					gm["rolled_identity_skill_id"] = rid
				if e.has("rolls") and typeof(e["rolls"]) == TYPE_DICTIONARY and not (e["rolls"] as Dictionary).is_empty():
					gm["rolls"] = e["rolls"]
				m.equip_gear(gm)
		# Equipped subs (Q/E/R)
		if m.has_method("equip_skillbook_by_id"):
			var subs: Array = e.get("subs", [])
			for j in mini(3, subs.size()):
				var s = subs[j]
				if typeof(s) == TYPE_DICTIONARY and String(s.get("base_ability_id", "")) != "":
					m.equip_skillbook_by_id(j, String(s["base_ability_id"]))
					# Restore persisted remaining 탄수 (equip set it to max). I5 charge persistence.
					if s.has("charges"):
						var inst = m.get_skillbook(j)
						if inst != null:
							inst.charges = clampi(int(s["charges"]), 0, int(inst.charges_max))


## Capture a live party's equipped GEAR + SUBS into the persistent store (extract / hub deploy). One save.
func capture_from_party(party) -> void:
	if party == null or not party.has_method("get_members"):
		return
	for m in party.get_members():
		if m == null or not is_instance_valid(m):
			continue
		var e: Dictionary = equipped.get(String(m.get("class_id")), {})
		e["gear"] = String(m.get("base_gear_id"))   # worn Identity Gear archetype (Safe on death — F-009 §3.7)
		e["rolled_identity"] = String(m.get("identity_skill_id"))   # F-008 §3.7 effective rolled identity (Node.get = 1-arg)
		var gr = m.get("gear_rolls")
		if typeof(gr) == TYPE_DICTIONARY and not (gr as Dictionary).is_empty():
			e["rolls"] = gr
		else:
			e.erase("rolls")
		if m.has_method("get_skillbook"):
			var subs: Array = []
			for j in 3:
				var sb = m.get_skillbook(j)
				if sb != null:
					subs.append({"base_ability_id": String(sb.get("base_ability_id", "")), "charges": int(sb.get("charges", 0))})
				else:
					subs.append(null)
			e["subs"] = subs
		equipped[String(m.get("class_id"))] = e
	save()


## Strip runtime/non-serializable fields (live grid Panel node, transient grid col/row) from an
## item dict so only the persistent descriptor is stored. Color is rebuilt from kind/id on load.
func _strip(it: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in ["id", "kind", "base_gear_id", "base_ability_id", "haul_material_id",
			"consumable_id", "w", "h", "count", "charges", "charges_max", "at_risk", "equipped",
			"rolled_identity_skill_id", "rolls"]:   # F-008 §3.7 gear 인스턴스 굴림 보존(G2)
		if it.has(key):
			out[key] = it[key]
	return out
