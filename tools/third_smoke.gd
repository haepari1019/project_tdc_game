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
		"AB-103": "enemy_tether", "AB-105": "enemy_frenzy", "AB-106": "enemy_execute",
	}
	for ab in want_kind:
		var e: Dictionary = sd.get_ability(ab)
		_chk("%s kind=%s" % [ab, want_kind[ab]], not e.is_empty() and String(e.get("kind", "")) == want_kind[ab])
	_chk("AB-100 Pounce pin_s>0", float(sd.get_ability("AB-100").get("pin_s", 0.0)) > 0.0)
	# T1 통폐합(DRIFT-101): AB-104 Rampage 폐기 → EN-3RD-03 오프너는 AB-011 Toll Stun.
	_chk("EN-3RD-03 kit has AB-011 (AB-104 폐기)", "AB-011" in str(sd.get_enemy_row("EN-3RD-03").get("abilities", [])))
	_chk("AB-104 removed from catalog", sd.get_ability("AB-104").is_empty())
	_chk("AB-106 Devour on-kill heal", float(sd.get_ability("AB-106").get("on_kill_heal_pct", 0.0)) > 0.0)
	for b in ["rom_stalker_rip", "rom_snarer_dart", "rom_reaver_cleave"]:
		_chk("%s resolves" % b, not sd.get_enemy_basic(b).is_empty())
	_chk("PT-023 target_pref=weakest", String(sd.get_pattern("PT-023").get("target_pref", "")) == "weakest")
	_chk("PT-024 target_pref=scented", String(sd.get_pattern("PT-024").get("target_pref", "")) == "scented")
	_chk("PT-025 engage=advance", String(sd.get_pattern("PT-025").get("engage", "")) == "advance")
	for en in ["EN-3RD-01", "EN-3RD-02", "EN-3RD-03", "EN-3RD-04"]:
		_chk("%s row resolves" % en, not sd.get_enemy_row(en).is_empty())
	var enc: Dictionary = sd.get_encounter("ENC-3RD-001")
	_chk("ENC-3RD-001 faction=Third", String(enc.get("faction", "")) == "Third")
	# 서포터 합류로 3 → 4(DRIFT-117). 3세력 = "다른 추출조"라 상대 분대에 **위생병이 있는 게 정상**이고,
	# 그걸 먼저 끊는 것이 누커의 역할이 된다. 구성이 줄어들지 않았는지만 본다(추가는 허용).
	_chk("ENC-3RD-001 units >= 4", (enc.get("units", []) as Array).size() >= 4)
	var has_support := false
	for u3 in (enc.get("units", []) as Array):
		if String((u3 as Dictionary).get("enemy_id", "")) == "EN-3RD-04":
			has_support = true
	_chk("ENC-3RD-001 서포터(EN-3RD-04) 편성", has_support)
	# 적 지원 킷 — 힐/보호막/정화가 적 진영에 실제로 존재하는가(분대 대 분대의 전제).
	var sup_kinds := {}
	for eid3 in sd.get_enemy_ids():
		for abr3 in sd.get_enemy_row(String(eid3)).get("abilities", []):
			sup_kinds[String(sd.get_ability(String((abr3 as Dictionary).get("ref", ""))).get("kind", ""))] = true
	for want3 in ["enemy_heal", "enemy_shield", "enemy_cleanse"]:
		_chk("적 진영 지원 킷 %s 보유" % want3, sup_kinds.has(want3))

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
		"AB-100": "skillbook_pin", "AB-102": "skillbook_root",   # AB-101 아군판 폐기(DRIFT-116)
		"AB-103": "skillbook_tether", "AB-106": "skillbook_execute",
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
