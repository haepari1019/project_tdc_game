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

	# All 11 pilot overlays (Tank 001~006 + Nuker 집중빌더 007~008 + Nuker 잠행 010~012; 집중소모=아키타입).
	if BindingFixtures.OVERLAYS.size() != 11:
		fails += 1; push_error("[BIND] expected 11 pilot overlays, got %d" % BindingFixtures.OVERLAYS.size())

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

	# --- Nuker Mark&Ruin 「집중」 — 빌더 서브 누적(focus_stack, BIND-PILOT-007~008) + 소모 아키타입(is_focus_spender) ---
	if String(BindingFixtures.resolve("gear_ward_nuker_ruin_sight", "IDA-025", "AB-055", 0).get("delta", "")) != "focus_stack":
		fails += 1; push_error("[BIND] Nuker Q should resolve focus_stack (BIND-PILOT-007)")
	# 소모는 특정 처형 AB가 아니라 kind 아키타입이 담당 — execute-kind는 소모형, bolt-kind는 아님.
	if not BindingFixtures.is_focus_spender("skillbook_execute"):
		fails += 1; push_error("[BIND] skillbook_execute should be a focus spender archetype")
	if BindingFixtures.is_focus_spender("skillbook_bolt"):
		fails += 1; push_error("[BIND] skillbook_bolt must NOT be a focus spender")
	# 결속 OFF면 소모 아키타입도 비활성(enabled 게이트).
	BindingFixtures.enabled = false
	if BindingFixtures.is_focus_spender("skillbook_execute"):
		fails += 1; push_error("[BIND] enabled=false must suppress the spender archetype")
	BindingFixtures.enabled = true
	# 집중 킷(Mark&Ruin)만 identity가 집중을 새긴다(Beacon은 표식이지 집중이 아님).
	if not BindingFixtures.identity_focuses("gear_ward_nuker_ruin_sight", "IDA-025"):
		fails += 1; push_error("[BIND] Mark&Ruin identity should focus")
	if BindingFixtures.identity_focuses("gear_ward_tank_kite_shield", "IDA-021"):
		fails += 1; push_error("[BIND] Beacon identity should NOT focus")
	# 규약(covenant) — Mark&Ruin=집중 자기완결 규약.
	var sig_n := BindingFixtures.signature_for("gear_ward_nuker_ruin_sight", "IDA-025")
	if String(sig_n.get("name", "")) != "집중" or String(sig_n.get("covenant", "")).is_empty():
		fails += 1; push_error("[BIND] Mark&Ruin covenant missing")

	# --- Nuker Flank Collapse 「잠행」 (BIND-PILOT-010~012) — 근접화 + 사거리 비례 이득(flank_strike) + 처치→은신 ---
	if String(BindingFixtures.resolve("gear_ward_nuker_flank_knife", "IDA-029", "AB-072", 1).get("delta", "")) != "flank_strike":
		fails += 1; push_error("[BIND] Flank E(Long) should resolve flank_strike (BIND-PILOT-011)")
	# 잠행 킷만 처치→은신 게이트가 열린다(집중 킷은 아님).
	if not BindingFixtures.identity_flanks("gear_ward_nuker_flank_knife", "IDA-029"):
		fails += 1; push_error("[BIND] Flank identity should gate veil-on-kill")
	if BindingFixtures.identity_flanks("gear_ward_nuker_ruin_sight", "IDA-025"):
		fails += 1; push_error("[BIND] Mark&Ruin identity should NOT flank")
	# 사거리 비례 이득 테이블 — Long > Mid > Melee (1차 뎀 / 2차 쿨감 모두 단조 증가).
	var bd: Dictionary = BindingFixtures.FLANK["band_dmg"]
	if not (float(bd["Long"]) > float(bd["Mid"]) and float(bd["Mid"]) > float(bd["Melee"])):
		fails += 1; push_error("[BIND] FLANK band_dmg must increase Melee<Mid<Long")
	# 규약(covenant) — Flank=잠행 자기완결 규약.
	var sig_f := BindingFixtures.signature_for("gear_ward_nuker_flank_knife", "IDA-029")
	if String(sig_f.get("name", "")) != "잠행" or String(sig_f.get("covenant", "")).is_empty():
		fails += 1; push_error("[BIND] Flank covenant missing")

	if fails == 0:
		print("BINDING SMOKE PASSED")
	else:
		print("BINDING SMOKE FAILED: %d assertion(s)" % fails)
	quit(1 if fails > 0 else 0)
