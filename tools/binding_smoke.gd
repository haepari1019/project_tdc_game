extends SceneTree
## P4a Kit Binding pilot — resolveEffectiveAbility triple-match + enabled-gate logic smoke (no scene/
## combat). Asserts BindingFixtures.resolve() activates only on a full gear+identity+slot match and is
## suppressed when binding is OFF (TANK-P4A-BASE, F-020 §3.7 step 5). ref: binding_fixtures.gd · QA-005 §2.12.
func _init() -> void:
	var fails := 0

	BindingFixtures.enabled = true

	# ANCHOR triple-match → BIND-PILOT-001 (GEAR-011 + IDA-020 + AB-033 @ Q).
	if String(BindingFixtures.resolve("gear_ward_tank_anchor_bulwark", "IDA-020", "AB-033", 0).get("id", "")) != "BIND-PILOT-001":
		fails += 1; push_error("[BIND] ANCHOR Q should resolve BIND-PILOT-001")

	# BEACON triple-match → BIND-PILOT-006 (GEAR-012 + IDA-021 + AB-035 @ R).
	if String(BindingFixtures.resolve("gear_ward_tank_kite_shield", "IDA-021", "AB-035", 2).get("id", "")) != "BIND-PILOT-006":
		fails += 1; push_error("[BIND] BEACON R should resolve BIND-PILOT-006")

	# Identity-only match with the WRONG gear → no overlay (spec F-020 §3.7 IDA-020+GEAR-012 example).
	if not BindingFixtures.resolve("gear_ward_tank_kite_shield", "IDA-020", "AB-033", 0).is_empty():
		fails += 1; push_error("[BIND] wrong gear must NOT activate an overlay")

	# Right gear+identity+slot-AB but WRONG slotIndex → no overlay.
	if not BindingFixtures.resolve("gear_ward_tank_anchor_bulwark", "IDA-020", "AB-033", 1).is_empty():
		fails += 1; push_error("[BIND] wrong slotIndex must NOT activate an overlay")

	# TANK-P4A-BASE regression: binding OFF → no overlay even on a full match (step 5).
	BindingFixtures.enabled = false
	if not BindingFixtures.resolve("gear_ward_tank_anchor_bulwark", "IDA-020", "AB-033", 0).is_empty():
		fails += 1; push_error("[BIND] enabled=false must suppress all overlays (BASE regression)")
	BindingFixtures.enabled = true

	# All 6 pilot overlays present (BIND-PILOT-001~006).
	if BindingFixtures.OVERLAYS.size() != 6:
		fails += 1; push_error("[BIND] expected 6 pilot overlays, got %d" % BindingFixtures.OVERLAYS.size())

	# 규약(covenant) — identity가 자기완결 규약을 선언(Beacon=표식 / Anchor=방벽 충전).
	var sig_b := BindingFixtures.signature_for("gear_ward_tank_kite_shield", "IDA-021")
	if String(sig_b.get("name", "")) != "표식" or String(sig_b.get("covenant", "")).is_empty():
		fails += 1; push_error("[BIND] Beacon covenant missing")
	var sig_a := BindingFixtures.signature_for("gear_ward_tank_anchor_bulwark", "IDA-020")
	if String(sig_a.get("name", "")) != "방벽 충전" or String(sig_a.get("covenant", "")).is_empty():
		fails += 1; push_error("[BIND] Anchor covenant missing")
	if not BindingFixtures.signature_for("gear_ward_tank_kite_shield", "IDA-020").is_empty():
		fails += 1; push_error("[BIND] wrong gear+identity must expose no covenant")

	# 표식 킷(Beacon)만 identity가 표식을 남긴다(Anchor는 아님).
	if not BindingFixtures.identity_marks("gear_ward_tank_kite_shield", "IDA-021"):
		fails += 1; push_error("[BIND] Beacon identity should mark")
	if BindingFixtures.identity_marks("gear_ward_tank_anchor_bulwark", "IDA-020"):
		fails += 1; push_error("[BIND] Anchor identity should NOT mark")

	if fails == 0:
		print("BINDING SMOKE PASSED")
	else:
		print("BINDING SMOKE FAILED: %d assertion(s)" % fails)
	quit(1 if fails > 0 else 0)
