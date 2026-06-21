extends SceneTree
## Third-faction (Stalker Pack, DEC-20260621-001) smoke — validates the new OUTCOME logic
## (Rooted/Pinned move-lock, Bloodlust buff, Scented) in isolation, and the data wiring
## (AB-100~106 kinds, rom_* basics, PT-023/024/025 engage/target_pref, ENC-3RD-001 units).
## Run: GODOT --headless --path . --script res://tools/third_smoke.gd

var _ok := true


func _initialize() -> void:
	# 1) OUTCOME logic (pure RefCounted — no autoload needed).
	var oc = preload("res://scripts/combat/outcome_status.gd").new()
	oc.apply("Rooted", 2.0)
	_chk("Rooted → move_mult 0", is_equal_approx(oc.move_mult(), 0.0))
	oc.clear(); oc.apply("Pinned", 0.6)
	_chk("Pinned → move_mult 0", is_equal_approx(oc.move_mult(), 0.0))
	oc.clear(); oc.apply("Bloodlust", 999.0)
	_chk("Bloodlust present", oc.has("Bloodlust"))
	var sl: Array = oc.status_list()
	_chk("Bloodlust flagged buff", sl.size() > 0 and bool(sl[0].get("buff", false)))
	oc.clear(); oc.apply("Scented", 6.0)
	_chk("Scented present + slow-free", oc.has("Scented") and is_equal_approx(oc.move_mult(), 1.0))

	# 2) Data wiring — instantiate Slice01Data so its _ready loads + validates the catalogs.
	var sd = preload("res://scripts/autoload/slice01_data.gd").new()
	sd.name = "Slice01Data"
	root.add_child(sd)
	await process_frame
	var want_kind := {
		"AB-100": "enemy_dash", "AB-101": "enemy_mark", "AB-102": "enemy_root",
		"AB-103": "enemy_tether", "AB-104": "enemy_dash", "AB-105": "enemy_frenzy", "AB-106": "enemy_execute",
	}
	for ab in want_kind:
		var e: Dictionary = sd.get_ability(ab)
		_chk("%s kind=%s" % [ab, want_kind[ab]], not e.is_empty() and String(e.get("kind", "")) == want_kind[ab])
	_chk("AB-100 Pounce pin_s>0", float(sd.get_ability("AB-100").get("pin_s", 0.0)) > 0.0)
	_chk("AB-104 Rampage line", bool(sd.get_ability("AB-104").get("line", false)))
	_chk("AB-106 Devour on-kill heal", float(sd.get_ability("AB-106").get("on_kill_heal_pct", 0.0)) > 0.0)
	for b in ["rom_stalker_rip", "rom_snarer_dart", "rom_reaver_cleave"]:
		_chk("%s resolves" % b, not sd.get_enemy_basic(b).is_empty())
	_chk("PT-023 target_pref=weakest", String(sd.get_pattern("PT-023").get("target_pref", "")) == "weakest")
	_chk("PT-024 target_pref=scented", String(sd.get_pattern("PT-024").get("target_pref", "")) == "scented")
	_chk("PT-025 engage=advance", String(sd.get_pattern("PT-025").get("engage", "")) == "advance")
	for en in ["EN-3RD-01", "EN-3RD-02", "EN-3RD-03"]:
		_chk("%s row resolves" % en, not sd.get_enemy_row(en).is_empty())
	var enc: Dictionary = sd.get_encounter("ENC-3RD-001")
	_chk("ENC-3RD-001 faction=Third", String(enc.get("faction", "")) == "Third")
	_chk("ENC-3RD-001 has 3 units", (enc.get("units", []) as Array).size() == 3)

	# 3) Cone visual marker — spawn an EN-3RD unit, apply the faction shape, verify box→cone swap.
	var u: CharacterBody3D = load("res://scenes/combat/enemy_unit.tscn").instantiate()
	root.add_child(u)
	u.setup(sd.get_enemy_row("EN-3RD-01"), Color(0.8, 0.4, 0.9), 1.0)
	u.faction = "Third"
	u.apply_faction_shape()
	var mn := u.get_node_or_null("Mesh") as MeshInstance3D
	var m: Mesh = mn.mesh if mn else null
	_chk("EN-3RD mesh = cone (CylinderMesh top_radius 0)", m is CylinderMesh and is_equal_approx((m as CylinderMesh).top_radius, 0.0))
	u.queue_free()

	# 4) P2-S6a party lootables — the 6 Third-faction skillbook masters resolve with the right kind.
	var sb_kind := {
		"AB-100": "skillbook_pin", "AB-101": "skillbook_scent", "AB-102": "skillbook_root",
		"AB-103": "skillbook_tether", "AB-104": "skillbook_charge", "AB-106": "skillbook_execute",
	}
	for ab in sb_kind:
		var sbm: Dictionary = sd.get_skillbook_master(ab)
		var k := String(sbm.get("cast", {}).get("kind", "")) if not sbm.is_empty() else ""
		_chk("%s skillbook kind=%s" % [ab, sb_kind[ab]], k == sb_kind[ab])

	print("THIRD SMOKE " + ("PASSED" if _ok else "FAILED"))
	quit(0 if _ok else 1)


func _chk(label: String, cond: bool) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_ok = false
