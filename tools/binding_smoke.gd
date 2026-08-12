extends SceneTree
## P4a Kit Binding — resolveEffectiveAbility 매칭 smoke (no scene/combat). 결속은 착용 즉시 내재 적용(토글 없음).
## **DRIFT-138 이후 키 = `bindingProfileId`(기본값 = effective identity)** — gear 아키타입 ID가 아니다.
## ref: binding_overlays.gd `binding_profile()` · QA-005 §2.12 · P4b_WORK_ORDER §2b.
func _init() -> void:
	var fails := 0
	await process_frame          # Slice01Data 오토로드 대기(카탈로그 전수 스윕이 필요로 함)
	await process_frame

	# ANCHOR triple-match → BIND-001 (GEAR-011 + IDA-020 + AB-033 @ Q).
	if String(BindingOverlays.resolve("gear_ward_tank_anchor_bulwark", "IDA-020", "AB-033", 0).get("id", "")) != "BIND-001":
		fails += 1; push_error("[BIND] ANCHOR Q should resolve BIND-001")

	# BEACON triple-match → BIND-006 (GEAR-012 + IDA-021 + AB-035 @ R).
	if String(BindingOverlays.resolve("gear_ward_tank_kite_shield", "IDA-021", "AB-035", 2).get("id", "")) != "BIND-006":
		fails += 1; push_error("[BIND] BEACON R should resolve BIND-006")

	# **DRIFT-138에서 뒤집힌 단언.** 예전엔 "gear가 다르면 결속 없음"이었다(구 gear-키 모델). 이제 키는
	# 프로필(기본 = 정체성)이라, kite_shield에 IDA-020을 굴려 끼우면 방벽 결속이 **정상 작동해야** 한다.
	# 이게 바로 스페어 gear 13종의 시그니처를 죽이던 조항이었다.
	if String(BindingOverlays.resolve("gear_ward_tank_kite_shield", "IDA-020", "AB-033", 0).get("id", "")) != "BIND-001":
		fails += 1; push_error("[BIND] 굴림 정체성(IDA-020)은 gear가 달라도 결속돼야 한다")
	# 뒤집어도 같다 — anchor gear에 IDA-021을 굴려 끼우면 **표식** 결속(BIND-004)이 붙는다.
	# 결속을 이끄는 건 gear가 아니라 정체성이기 때문이다.
	if String(BindingOverlays.resolve("gear_ward_tank_anchor_bulwark", "IDA-021", "AB-033", 0).get("theme", "")) != "mark":
		fails += 1; push_error("[BIND] anchor gear + 굴림 IDA-021 → 표식 결속이어야 한다")
	# 그래도 **정체성이 다르면 안 걸린다** — 프로필 키가 identity를 무시한다는 뜻이 아니다.
	# IDA-024(초월)엔 AB-033 변주가 없으므로 빈 결과(= GENERIC 폴백은 resolve_effective 소관).
	if not BindingOverlays.resolve("gear_ward_tank_anchor_bulwark", "IDA-024", "AB-033", 0).is_empty():
		fails += 1; push_error("[BIND] 변주가 없는 정체성엔 오버레이가 걸리면 안 된다")

	# Right gear+identity+slot-AB but WRONG slotIndex → no overlay.
	if not BindingOverlays.resolve("gear_ward_tank_anchor_bulwark", "IDA-020", "AB-033", 1).is_empty():
		fails += 1; push_error("[BIND] wrong slotIndex must NOT activate an overlay")

	# All 36 overlays (+ AB-007 이탈 033~036 · **BIND-037/038 AB-013 Backstab Dash 집중/잠행 변주**).
	# DPS 초월 아군안심기름(구 BIND-027 · AB-009)은 **제거** — DRIFT-112가 AB-009 아군 스킬북을 폐기해
	# triple-match가 성립할 수 없는 죽은 항목이었다(DRIFT-130). 37 → 36.
	if BindingOverlays.OVERLAYS.size() != 36:
		fails += 1; push_error("[BIND] expected 36 overlays, got %d" % BindingOverlays.OVERLAYS.size())
	# 이탈 결속은 slot 무관(-1) — 어느 슬롯에 있어도 resolve.
	if String(BindingOverlays.resolve("gear_ward_nuker_ruin_sight", "IDA-025", "AB-007a", 2).get("delta", "")) != "disengage_focus":
		fails += 1; push_error("[BIND] 이탈(AB-007a)+집중 should resolve disengage_focus at any slot")
	if String(BindingOverlays.resolve("gear_ward_nuker_flank_knife", "IDA-029", "AB-007b", 0).get("delta", "")) != "disengage_veil":
		fails += 1; push_error("[BIND] 이탈(AB-007b)+잠행 should resolve disengage_veil")
	# 폐기 스킬은 결속이 걸리지 않아야 한다 — AB-009(아군 스킬북 폐기, DRIFT-112)로 resolve하면 빈 결과.
	# 종전엔 여기서 safeslick을 기대했다(DRIFT-094). 죽은 오버레이를 지웠으므로 기대도 뒤집힌다.
	if not BindingOverlays.resolve("gear_ward_dps_press_rod", "IDA-024", "AB-009", 0).is_empty():
		fails += 1; push_error("[BIND] 폐기 AB-009에 결속이 남아 있다")

	# 규약(covenant) — identity가 자기완결 규약을 선언(Beacon=표식 / Anchor=방벽 충전).
	var sig_b := BindingOverlays.signature_for("gear_ward_tank_kite_shield", "IDA-021")
	if String(sig_b.get("name", "")) != "표식" or String(sig_b.get("covenant", "")).is_empty():
		fails += 1; push_error("[BIND] Beacon covenant missing")
	var sig_a := BindingOverlays.signature_for("gear_ward_tank_anchor_bulwark", "IDA-020")
	if String(sig_a.get("name", "")) != "방벽 충전" or String(sig_a.get("covenant", "")).is_empty():
		fails += 1; push_error("[BIND] Anchor covenant missing")
	# 규약도 정체성을 따라간다(구: gear 일치 필요 — DRIFT-138에서 뒤집힘).
	if String(BindingOverlays.signature_for("gear_ward_tank_kite_shield", "IDA-020").get("name", "")) != "방벽 충전":
		fails += 1; push_error("[BIND] 규약은 gear가 아니라 정체성을 따라가야 한다")

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


	# ==========================================================================
	# M0b-5 전수 스윕 (DRIFT-138) — **카탈로그의 모든 gear가 자기 정체성 규약대로 작동하는가.**
	# 구 gear-키 모델에서는 OVERLAYS에 등재된 8종만 살아 있고 나머지는 조용히 죽어 있었다
	# (rampart_wall = IDA-020인데 방벽이 안 쌓이고, scout_frame = IDA-025인데 집중이 안 쌓임).
	# 이 스윕이 그 회귀를 다시 못 들어오게 막는다.
	# ==========================================================================
	var sd = root.get_node_or_null("/root/Slice01Data")
	if sd == null or not sd.is_loaded():
		fails += 1; push_error("[BIND] Slice01Data 미로드 — 전수 스윕 불가")
	else:
		var dead: Array = []
		var pending: Array = []      # 규약 미확정(IDA-022/052) — 실패가 아니라 미결로 분류
		var live := 0
		for row in sd.get_gear_rows():
			var gid := String(row.get("base_gear_id", ""))
			var iid := String(row.get("bundled_identity_skill_id", ""))
			var ab := String(sd.get_identity_row(iid).get("ability_id", ""))
			if ab == "":
				continue
			if not BindingOverlays.SIGNATURE.has(ab):
				pending.append("%s (%s)" % [gid, ab])       # U2 — 규약 곧 추가 예정
				continue
			if BindingOverlays.signature_for(gid, ab).is_empty():
				dead.append("%s (%s)" % [gid, ab])
			else:
				live += 1
		for d in dead:
			push_error("[BIND] 시그니처 미작동: " + d)
		if not dead.is_empty():
			fails += 1
		print("[BIND] 시그니처 스윕 — 작동 %d종 · 규약미확정 %d종(%s)" % [live, pending.size(), ", ".join(pending)])
		# 굴림 정체성 교차검증: 아무 Tank gear에 어떤 Tank 정체성을 굴려 끼워도 그 정체성 규약이 붙는다.
		for g2 in ["gear_ward_tank_rampart_wall", "gear_ward_tank_beacon_hook", "gear_ward_tank_iron_set"]:
			if BindingOverlays.signature_for(g2, "IDA-021").is_empty():
				fails += 1; push_error("[BIND] 굴림 IDA-021이 %s에서 규약을 잃는다" % g2)

	if fails == 0:
		print("BINDING SMOKE PASSED")
	else:
		print("BINDING SMOKE FAILED: %d assertion(s)" % fails)
	quit(1 if fails > 0 else 0)
