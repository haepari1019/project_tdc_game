extends SceneTree
## P4a Kit Binding pilot — resolveEffectiveAbility triple-match logic smoke (no scene/combat). 결속은 착용 즉시
## 내재 적용(토글 없음) — resolve()는 gear+identity+slot 완전 일치일 때만 활성. ref: binding_overlays.gd · QA-005 §2.12.
func _init() -> void:
	var fails := 0

	# ANCHOR triple-match → BIND-001 (GEAR-011 + IDA-020 + AB-033 @ Q).
	if String(BindingOverlays.resolve("gear_ward_tank_anchor_bulwark", "IDA-020", "AB-033", 0).get("id", "")) != "BIND-001":
		fails += 1; push_error("[BIND] ANCHOR Q should resolve BIND-001")

	# BEACON triple-match → BIND-006 (GEAR-012 + IDA-021 + AB-035 @ R).
	if String(BindingOverlays.resolve("gear_ward_tank_kite_shield", "IDA-021", "AB-035", 2).get("id", "")) != "BIND-006":
		fails += 1; push_error("[BIND] BEACON R should resolve BIND-006")

	# Identity-only match with the WRONG gear → no overlay (spec F-020 §3.7 IDA-020+GEAR-012 example).
	if not BindingOverlays.resolve("gear_ward_tank_kite_shield", "IDA-020", "AB-033", 0).is_empty():
		fails += 1; push_error("[BIND] wrong gear must NOT activate an overlay")

	# Right gear+identity+slot-AB but WRONG slotIndex → no overlay.
	if not BindingOverlays.resolve("gear_ward_tank_anchor_bulwark", "IDA-020", "AB-033", 1).is_empty():
		fails += 1; push_error("[BIND] wrong slotIndex must NOT activate an overlay")

	# All 28 pilot overlays (Tank 001~006/029(방벽)/030(표식) + Nuker 007~008/027/010~012/028 + Healer 013~018 + DPS 초월 019~021/026 + DPS 혈풍 022~024).
	if BindingOverlays.OVERLAYS.size() != 28:
		fails += 1; push_error("[BIND] expected 28 pilot overlays, got %d" % BindingOverlays.OVERLAYS.size())

	# 규약(covenant) — identity가 자기완결 규약을 선언(Beacon=표식 / Anchor=방벽 충전).
	var sig_b := BindingOverlays.signature_for("gear_ward_tank_kite_shield", "IDA-021")
	if String(sig_b.get("name", "")) != "표식" or String(sig_b.get("covenant", "")).is_empty():
		fails += 1; push_error("[BIND] Beacon covenant missing")
	var sig_a := BindingOverlays.signature_for("gear_ward_tank_anchor_bulwark", "IDA-020")
	if String(sig_a.get("name", "")) != "방벽 충전" or String(sig_a.get("covenant", "")).is_empty():
		fails += 1; push_error("[BIND] Anchor covenant missing")
	if not BindingOverlays.signature_for("gear_ward_tank_kite_shield", "IDA-020").is_empty():
		fails += 1; push_error("[BIND] wrong gear+identity must expose no covenant")

	# 표식 킷(Beacon)만 identity가 표식을 남긴다(Anchor는 아님).
	if not BindingOverlays.identity_marks("gear_ward_tank_kite_shield", "IDA-021"):
		fails += 1; push_error("[BIND] Beacon identity should mark")
	if BindingOverlays.identity_marks("gear_ward_tank_anchor_bulwark", "IDA-020"):
		fails += 1; push_error("[BIND] Anchor identity should NOT mark")

	# --- Nuker Mark&Ruin 「집중」 — 빌더 서브 누적(focus_stack, BIND-007~008) + 소모 아키타입(is_focus_spender) ---
	if String(BindingOverlays.resolve("gear_ward_nuker_ruin_sight", "IDA-025", "AB-004", 0).get("delta", "")) != "focus_stack":
		fails += 1; push_error("[BIND] Nuker Q should resolve focus_stack (BIND-007)")
	# 소모는 특정 처형 AB가 아니라 kind 아키타입이 담당 — execute-kind는 소모형, bolt-kind는 아님.
	if not BindingOverlays.is_focus_spender("skillbook_execute"):
		fails += 1; push_error("[BIND] skillbook_execute should be a focus spender archetype")
	if BindingOverlays.is_focus_spender("skillbook_bolt"):
		fails += 1; push_error("[BIND] skillbook_bolt must NOT be a focus spender")
	# 집중 킷(Mark&Ruin)만 identity가 집중을 새긴다(Beacon은 표식이지 집중이 아님).
	if not BindingOverlays.identity_focuses("gear_ward_nuker_ruin_sight", "IDA-025"):
		fails += 1; push_error("[BIND] Mark&Ruin identity should focus")
	if BindingOverlays.identity_focuses("gear_ward_tank_kite_shield", "IDA-021"):
		fails += 1; push_error("[BIND] Beacon identity should NOT focus")
	# 규약(covenant) — Mark&Ruin=집중 자기완결 규약.
	var sig_n := BindingOverlays.signature_for("gear_ward_nuker_ruin_sight", "IDA-025")
	if String(sig_n.get("name", "")) != "집중" or String(sig_n.get("covenant", "")).is_empty():
		fails += 1; push_error("[BIND] Mark&Ruin covenant missing")

	# --- Nuker Flank Collapse 「잠행」 (BIND-010~012) — 근접화 + 사거리 비례 이득(flank_strike) + 처치→은신 ---
	if String(BindingOverlays.resolve("gear_ward_nuker_flank_knife", "IDA-029", "AB-059", 1).get("delta", "")) != "flank_dash":
		fails += 1; push_error("[BIND] Flank E(공허창) should resolve flank_dash (BIND-011)")
	if String(BindingOverlays.resolve("gear_ward_nuker_flank_knife", "IDA-029", "AB-004", 0).get("delta", "")) != "flank_strike":
		fails += 1; push_error("[BIND] Flank Q(전격) should resolve flank_strike (BIND-010)")
	# 잠행 킷만 처치→은신 게이트가 열린다(집중 킷은 아님).
	if not BindingOverlays.identity_flanks("gear_ward_nuker_flank_knife", "IDA-029"):
		fails += 1; push_error("[BIND] Flank identity should gate veil-on-kill")
	if BindingOverlays.identity_flanks("gear_ward_nuker_ruin_sight", "IDA-025"):
		fails += 1; push_error("[BIND] Mark&Ruin identity should NOT flank")
	# 사거리 비례 이득 테이블 — Long > Mid > Melee (1차 뎀 / 2차 쿨감 모두 단조 증가).
	var bd: Dictionary = BindingOverlays.FLANK["band_dmg"]
	if not (float(bd["Long"]) > float(bd["Mid"]) and float(bd["Mid"]) > float(bd["Melee"])):
		fails += 1; push_error("[BIND] FLANK band_dmg must increase Melee<Mid<Long")
	# 규약(covenant) — Flank=잠행 자기완결 규약.
	var sig_f := BindingOverlays.signature_for("gear_ward_nuker_flank_knife", "IDA-029")
	if String(sig_f.get("name", "")) != "잠행" or String(sig_f.get("covenant", "")).is_empty():
		fails += 1; push_error("[BIND] Flank covenant missing")

	# --- Healer 지속치유 「DoT」 (BIND-013~015) — 가호 폐지, 치유 choke가 정체성 게이트로 즉시→HoT 전환 ---
	if String(BindingOverlays.resolve("gear_ward_healer_ward_sigil", "IDA-031", "AB-064", 0).get("theme", "")) != "dot_heal":
		fails += 1; push_error("[BIND] Healer Q(QuickMend) should resolve dot_heal (BIND-013)")
	if not BindingOverlays.identity_dot_heals("gear_ward_healer_ward_sigil", "IDA-031"):
		fails += 1; push_error("[BIND] DoT-heal identity should gate heal→HoT")
	if BindingOverlays.identity_dot_heals("gear_ward_healer_mend_lantern", "IDA-026"):
		fails += 1; push_error("[BIND] Mend Circle identity should NOT dot-heal")
	var sig_h := BindingOverlays.signature_for("gear_ward_healer_ward_sigil", "IDA-031")
	if String(sig_h.get("name", "")) != "지속 치유" or String(sig_h.get("covenant", "")).is_empty():
		fails += 1; push_error("[BIND] DoT-heal covenant missing")

	# --- Healer 성역 「Mend Circle」 (BIND-016~018) — 좁은 zone, in-zone 시전 시 치유 증폭(choke) ---
	if String(BindingOverlays.resolve("gear_ward_healer_mend_lantern", "IDA-026", "AB-064", 0).get("theme", "")) != "sanctuary":
		fails += 1; push_error("[BIND] Healer Q should resolve sanctuary (BIND-016)")
	if not BindingOverlays.identity_sanctuaries("gear_ward_healer_mend_lantern", "IDA-026"):
		fails += 1; push_error("[BIND] Mend Circle identity should sanctuary")
	if BindingOverlays.identity_sanctuaries("gear_ward_healer_ward_sigil", "IDA-031"):
		fails += 1; push_error("[BIND] DoT-heal identity should NOT sanctuary")
	var sig_s := BindingOverlays.signature_for("gear_ward_healer_mend_lantern", "IDA-026")
	if String(sig_s.get("name", "")) != "성역" or String(sig_s.get("covenant", "")).is_empty():
		fails += 1; push_error("[BIND] Sanctuary covenant missing")

	# --- DPS press_line 「초월」 (BIND-019~021) — 명중 게이지 → dur초 강화 변형(fire/beam/cold 분기) ---
	if String(BindingOverlays.resolve("gear_ward_dps_press_rod", "IDA-024", "AB-053", 0).get("delta", "")) != "overdrive_charge":
		fails += 1; push_error("[BIND] DPS Q(작열) should resolve overdrive_charge (BIND-019)")
	if not BindingOverlays.identity_overdrive("gear_ward_dps_press_rod", "IDA-024"):
		fails += 1; push_error("[BIND] press_line identity should overdrive")
	if BindingOverlays.identity_overdrive("gear_ward_dps_weave_staff", "IDA-027"):
		fails += 1; push_error("[BIND] arc_weave identity should NOT overdrive")
	var sig_o := BindingOverlays.signature_for("gear_ward_dps_press_rod", "IDA-024")
	if String(sig_o.get("name", "")) != "초월" or String(sig_o.get("covenant", "")).is_empty():
		fails += 1; push_error("[BIND] Overdrive covenant missing")

	# --- DPS arc_weave 「혈풍」 (BIND-022~024) — 서브 HP 대가 + 광역 명중 적 비례 회복 ---
	if String(BindingOverlays.resolve("gear_ward_dps_weave_staff", "IDA-027", "AB-053", 0).get("delta", "")) != "blood_soak":
		fails += 1; push_error("[BIND] DPS Q(작열) should resolve blood_soak (BIND-022)")
	if not BindingOverlays.identity_bloodgale("gear_ward_dps_weave_staff", "IDA-027"):
		fails += 1; push_error("[BIND] arc_weave identity should bloodgale")
	if BindingOverlays.identity_bloodgale("gear_ward_dps_press_rod", "IDA-024"):
		fails += 1; push_error("[BIND] press_line identity should NOT bloodgale")
	var sig_bg := BindingOverlays.signature_for("gear_ward_dps_weave_staff", "IDA-027")
	if String(sig_bg.get("name", "")) != "혈풍" or String(sig_bg.get("covenant", "")).is_empty():
		fails += 1; push_error("[BIND] Blood Gale covenant missing")

	if fails == 0:
		print("BINDING SMOKE PASSED")
	else:
		print("BINDING SMOKE FAILED: %d assertion(s)" % fails)
	quit(1 if fails > 0 else 0)
