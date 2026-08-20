extends SceneTree
## QA-029 Hub smoke (P2-S4 B8) — 시설 승급 게이트 + vault + ENC haul 드롭표 + 런이벤트 퀘스트(B4).
## 실 저장을 건드리지 않도록 fresh HubProfile 인스턴스(persist=false)에서 검증. assert 실패 → exit 1.
## 사용: GODOT ... --script res://tools/hub_smoke.gd  (ci_smoke.sh가 호출)

var _ok := true


func _init() -> void:
	await process_frame
	await process_frame
	var sd = root.get_node_or_null("/root/Slice01Data")
	if sd == null or not sd.is_loaded():
		print("HUB SMOKE FAILED — Slice01Data not loaded")
		quit(1)
		return

	var hp = load("res://scripts/autoload/hub_profile.gd").new()
	hp.persist = false   # no disk writes (실 save 미오염)
	for f in hp.FACILITY_IDS:
		hp.facilities[f] = 0

	# T-HUB-003 — 재료/퀘스트 부족 시 승급 거부
	_expect(not bool(hp.upgrade_check("stash").get("ok", false)), "T-HUB-003 빈 상태 stash 승급 거부")

	# T-HUB-004 — 퀘스트+재료 충족 → 승급 성공 · vault 차감 · Tier+1 · 효과(capacity) 반영
	hp.add_haul("haul_ward_splinter", 5)
	hp.evaluate_quests()
	_expect(hp.is_quest_done("Q-HUB-002"), "Q-HUB-002 자동완료(파편≥2)")
	_expect(bool(hp.upgrade_check("stash").get("ok", false)), "stash 승급 가능(퀘+재료)")
	_expect(hp.attempt_upgrade("stash"), "stash 승급 적용")
	_expect(hp.facility_tier("stash") == 1, "stash Tier 1")
	_expect(hp.vault_count("haul_ward_splinter") == 0, "재료 차감(0)")
	_expect(hp.stash_capacity_tier() == 28, "stash capacity 28 (tier 실값 — 플테 우회와 분리)")

	# prereq 게이트 — scribe_shop T1은 scriptorium≥1 선행
	_expect(String(hp.upgrade_check("scribe_shop").get("reason", "")) == "prereq", "scribe_shop 선행 차단")

	# B4 — enc_cleared 기록 자체는 유지(다른 판정용). Q-HUB-020 판정은 아래 "무기고" 블록(절차생성 정합)에서.
	hp.record_enc_cleared("ENC-HARD-001", "Normal")
	_expect(bool(hp.enc_cleared.get("ENC-HARD-001", false)), "B4 enc_cleared 기록")

	# HUB-COR-000 — ENC별 haul 드롭표 (스펙 정확값 + 커버리지)
	_expect(sd.get_haul_drops("ENC-NORM-001").size() == 2, "haul_drops NORM-001 = 2행")
	_expect(not sd.get_haul_drops("ENC-BOSS-001").is_empty(), "haul_drops BOSS-001 존재")

	# F-009 §3.5 / D-018 §7.1 — Skillbook economy: 분석(N=3)→해금→상점 구매(ward_scrap).
	_expect(String(hp.submit_analysis("AB-037").get("reason", "")) == "facility", "분석 — scriptorium 잠김 거부")
	hp.facilities["scriptorium"] = 1   # 테스트: scriptorium T1 (분석 가능)
	var r1: Dictionary = hp.submit_analysis("AB-037")
	_expect(bool(r1.get("ok", false)) and int(r1.get("progress", 0)) == 1 and not bool(r1.get("unlocked", false)), "분석 1/3")
	hp.submit_analysis("AB-037")
	var r3: Dictionary = hp.submit_analysis("AB-037")
	_expect(bool(r3.get("unlocked", false)) and hp.is_shop_unlocked("AB-037"), "분석 3/3 → 해금")
	_expect(String(hp.submit_analysis("AB-037").get("reason", "")) == "already_unlocked", "해금 후 의뢰 거부")
	_expect(String(hp.buy_raw("AB-037").get("reason", "")) == "tier_ceiling", "상점 — scribe_shop 잠김 차단")
	hp.facilities["scribe_shop"] = 1   # 테스트: scribe_shop T1 (Basic 판매)
	_expect(String(hp.buy_raw("AB-037").get("reason", "")) == "scrap", "상점 — scrap 부족 차단")
	hp.add_scrap(30)
	var buy: Dictionary = hp.buy_raw("AB-037")
	_expect(bool(buy.get("ok", false)) and hp.scrap() == 18, "Basic 구매 -12 scrap (30→18)")
	_expect(String(hp.buy_raw("AB-099").get("reason", "")) == "locked", "미해금 base 구매 차단")

	# D-018 §7.5 중복 sink — 해금된 base=분해(8), 미해금=매각(4) + add_scrap 반영.
	_expect(hp.skillbook_sink_value("AB-037") == hp.SINK_DISASSEMBLE, "sink — 해금 base 분해값 8")
	_expect(hp.skillbook_sink_value("AB-099") == hp.SINK_SELL, "sink — 미해금 base 매각값 4")
	var scrap_before: int = hp.scrap()
	hp.add_scrap(hp.skillbook_sink_value("AB-037"))
	_expect(hp.scrap() == scrap_before + 8, "sink — 분해 시 ward_scrap +8")

	# 데모 이벤트 퀘스트(DRIFT-065) — 추출/전멸 횟수로 미구현 기능(2맵/복구/NPC) 대용.
	hp.persist = false
	hp.extraction_success = 0; hp.party_wiped = 0; hp.quest_completed.clear()
	hp.record_extraction_success()   # =1
	_expect(hp.is_quest_done("Q-HUB-050"), "군수 — 추출 1회로 해금")
	_expect(not hp.is_quest_done("Q-HUB-003"), "창고T2 — 추출 1회론 미해금")
	hp.record_extraction_success()   # =2
	_expect(hp.is_quest_done("Q-HUB-003"), "창고T2 — 추출 2회로 해금")
	_expect(not hp.is_quest_done("Q-HUB-040"), "성소 — 전멸 전 미해금")
	hp.record_party_wipe()
	_expect(hp.is_quest_done("Q-HUB-040"), "성소 — 전멸 1회로 해금")

	# Q-HUB-020(무기고 개방) — 절차생성 정합: 특정 ENC가 아니라 임의 Hard 인카운터 클리어로 판정.
	hp.hard_cleared = false
	hp.quest_completed.erase("Q-HUB-020")
	hp.record_enc_cleared("ENC-NORM-001", "Normal")
	_expect(not hp.is_quest_done("Q-HUB-020"), "무기고 — Normal 클리어론 미해금")
	hp.record_enc_cleared("ENC-HARD-007", "Hard")   # 어느 Hard ENC든 게이트 충족
	_expect(hp.is_quest_done("Q-HUB-020"), "무기고 — 임의 Hard 인카운터 클리어로 해금")

	# F-029 무기고 기어 상점 — armory Tier 게이트 + ward_scrap 차감.
	hp.facilities["armory"] = 0
	hp.ward_scrap = 100
	_expect(String(hp.buy_gear("gear_ward_tank_iron_set", 1).get("reason", "")) == "tier", "기어 — armory 잠김 차단")
	hp.facilities["armory"] = 1
	var gear_before: int = hp.scrap()
	_expect(bool(hp.buy_gear("gear_ward_tank_iron_set", 1).get("ok", false)) and hp.scrap() == gear_before - 40, "B세트 구매 -40 scrap")
	_expect(String(hp.buy_gear("gear_ward_dps_guardbreak_set", 2).get("reason", "")) == "tier", "C세트(T2) armory T1선 차단")

	# F-010 소모품 상점 — price(consumables.json) 차감, 게이트 없음.
	hp.ward_scrap = 50
	var consum_before: int = hp.scrap()
	_expect(bool(hp.buy_consumable("con_revive_scroll").get("ok", false)) and hp.scrap() == consum_before - 20, "소모품(부활) 구매 -20 scrap")
	hp.ward_scrap = 5
	_expect(String(hp.buy_consumable("con_revive_scroll").get("reason", "")) == "scrap", "소모품 — scrap 부족 차단")

	# S6b per-AB tier — skillbooks.json tier(스펙 abilityTier) + 상점 tier 천장 게이트.
	_expect(String(sd.get_skillbook_master("AB-002").get("tier", "")) == "Basic", "per-AB tier — AB-002 Basic")
	_expect(String(sd.get_skillbook_master("AB-004").get("tier", "")) == "Advanced", "per-AB tier — AB-004 Advanced")
	hp.shop_listing_unlocked["AB-004"] = true
	hp.ward_scrap = 200
	hp.facilities["scribe_shop"] = 1
	_expect(String(hp.buy_raw("AB-004", "Advanced").get("reason", "")) == "tier_ceiling", "Adv 생본 — scribe_shop T1선 차단")
	hp.facilities["scribe_shop"] = 2
	_expect(bool(hp.buy_raw("AB-004", "Advanced").get("ok", false)), "Adv 생본 — scribe_shop T2서 구매")

	# S7/QA-029 — capacity 게터 per tier (이번 세션 강제 축: 군수 런 운반 + 창고 영속).
	hp.facilities["quartermaster"] = 0
	_expect(hp.run_inventory_capacity() == 12, "군수 capacity T0=12")
	hp.facilities["quartermaster"] = 1
	_expect(hp.run_inventory_capacity() == 14, "군수 capacity T1=14")
	hp.facilities["quartermaster"] = 2
	_expect(hp.run_inventory_capacity() == 16, "군수 capacity T2=16")
	hp.facilities["stash"] = 0
	_expect(hp.stash_capacity_tier() == 20, "창고 capacity T0=20")
	hp.facilities["stash"] = 2
	_expect(hp.stash_capacity_tier() == 36, "창고 capacity T2=36")


	# ==========================================================================
	# 유령 참조 감사 (M0-4 · DRIFT-139) — 시드·픽스처가 가리키는 AB/gear ID가 카탈로그에
	# **실재**하는지 전수 확인. 이 게이트가 없어서 같은 사고가 세 번 났다:
	#   DRIFT-130 샌드박스 픽스처 AB-009 · DRIFT-137 스타터 AB-028 · DRIFT-139 스태시 시드 AB-037.
	# 전부 `equip_skillbook_by_id`가 마스터를 못 찾고 조용히 빈 슬롯을 만드는 경로였다 —
	# 게임은 정상으로 보이고 스킬만 안 나온다. 폐기는 앞으로도 계속 생기므로 사람이 아니라
	# 게이트가 잡아야 한다.
	# ==========================================================================
	var ghosts: Array = []

	# ① Backpack 스타터 시드 (StarterGrant)
	var bp = load("res://scripts/autoload/backpack.gd").new()
	bp._seed()
	for it in bp.loose:
		var aid := String(it.get("base_ability_id", ""))
		if aid != "" and sd.get_skillbook_master(aid).is_empty():
			ghosts.append("Backpack.loose 스킬북 %s" % aid)
		var gid_l := String(it.get("base_gear_id", ""))
		if gid_l != "" and sd.get_gear_master(gid_l).is_empty():
			ghosts.append("Backpack.loose 기어 %s" % gid_l)
	for key in bp.equipped:
		var e: Dictionary = bp.equipped[key]
		var wg := String(e.get("gear", ""))
		if wg != "" and sd.get_gear_master(wg).is_empty():
			ghosts.append("Backpack.equipped[%s].gear %s" % [key, wg])
		for sub in e.get("subs", []):
			if typeof(sub) == TYPE_DICTIONARY:
				var sid := String(sub.get("base_ability_id", ""))
				if sid != "" and sd.get_skillbook_master(sid).is_empty():
					ghosts.append("Backpack.equipped[%s].subs %s" % [key, sid])
	var bp_loose: int = bp.loose.size()
	var bp_equipped: int = bp.equipped.size()
	bp.free()
	_expect(bp_loose > 0 and bp_equipped == 4, "Backpack 시드 — 낱개 %d · 착용 %d역할" % [bp_loose, bp_equipped])

	# ② Stash 시드 — 카탈로그 파생이라 유령이 나올 수 없어야 한다(파생이 곧 증명).
	var st = load("res://scripts/autoload/stash.gd").new()
	root.add_child(st)          # Slice01Data를 /root 경로로 찾으므로 트리에 붙인다
	st._seed_from_catalog()
	for g in st.gear:
		var gid := String(g.get("base_gear_id", "")) if typeof(g) == TYPE_DICTIONARY else String(g)
		if sd.get_gear_master(gid).is_empty():
			ghosts.append("Stash.gear %s" % gid)
	for sb in st.skillbooks:
		var sbid := String(sb.get("base_ability_id", "")) if typeof(sb) == TYPE_DICTIONARY else String(sb)
		if sd.get_skillbook_master(sbid).is_empty():
			ghosts.append("Stash.skillbooks %s" % sbid)
	_expect(st.gear.size() > 0, "Stash 시드 기어 %d종(카탈로그 파생)" % st.gear.size())
	_expect(st.skillbooks.size() == sd.get_skillbook_rows().size(),
		"Stash 시드 서브 = 카탈로그 전량 %d종 (D4 전 카탈로그 개방)" % sd.get_skillbook_rows().size())
	st.free()

	# ②b 마석 (M1 · F-009 §3.8) — 비용표·스타터 정합.
	_expect(sd.manastone_cost_for("AB-053") == 1, "마석 비용 Basic=1 (AB-053)")
	_expect(sd.manastone_cost_for("AB-004") == 2, "마석 비용 Advanced=2 (AB-004)")
	_expect(sd.manastone_cost_for("AB-065") == 3, "마석 비용 Master=3 (AB-065)")
	_expect(sd.manastone_cost_for("AB-없음") == 0, "미등록 AB = 0 (모르는 스킬에 세금 금지)")
	_expect(sd.default_manastone_id() == "ms_weak", "기본 마석 = ms_weak")
	# 시드는 오토로드 순서 때문에 manastones.json 값을 **복제**해 둔다 — 어긋나면 첫 런 지급이 거짓이 된다.
	var seed_ms := 0
	var bp2 = load("res://scripts/autoload/backpack.gd").new()
	bp2._seed()
	for it2 in bp2.loose:
		if String(it2.get("kind", "")) == "manastone":
			seed_ms += int(it2.get("count", 0))
	bp2.free()
	_expect(seed_ms == sd.manastone_starter_grant(),
		"스타터 마석 시드 %d == manastones.json starter_grant %d" % [seed_ms, sd.manastone_starter_grant()])

	# ②c 참 (M2 · F-010 §3.11) — 카탈로그·스타터·합산.
	_expect(sd.get_charm_rows().size() == 7, "참 카탈로그 7종 (조건부 2 포함)")
	_expect(not sd.get_charm("charm_ward_scale").is_empty(), "참 조회 — charm_ward_scale")
	var seed_charms: Array = []
	var bp3 = load("res://scripts/autoload/backpack.gd").new()
	bp3._seed()
	for it3 in bp3.loose:
		if String(it3.get("kind", "")) == "charm":
			seed_charms.append(String(it3.get("charm_id", "")))
	bp3.free()
	var want_charms: Array = sd.charm_starter_grant()
	_expect(seed_charms == want_charms,
		"스타터 참 시드 %s == charms.json starter_grant %s" % [str(seed_charms), str(want_charms)])
	# 효과 키가 실제 소비처가 아는 축인지 — 오타 하나로 참이 조용히 무효가 된다.
	# **정적**(apply_charms가 합산해 멤버에 push) / **조건부**(멤버가 charm_condition_met로 판정) 구분.
	var known := ["damage_taken_mult", "outgoing_mult", "move_mult", "attack_speed_mult",
		"reflect_flat", "threat_mult"]                      # 정적 = mods 키
	var known_cond_eff := ["impair_resist_once"]            # 조건부 = 멤버가 직접 소비
	var bad_eff: Array = []
	for row in sd.get_charm_rows():
		var eff2 := String(row.get("effect", ""))
		var ok_eff: bool = known.has(eff2) if not row.has("condition") else known_cond_eff.has(eff2)
		if not ok_eff:
			bad_eff.append("%s(%s)" % [row.get("charm_id", "?"), eff2])
	_expect(bad_eff.is_empty(), "참 effect 키 전부 유효 (%s)" % ("없음" if bad_eff.is_empty() else ", ".join(bad_eff)))
	# CS-1(DEC-20260813-003) — 조건부 참 하드 제약. 스펙이 금지한 것들이 데이터로 새어 들어오면 잡는다.
	var roles := ["Tank", "DPS", "Nuker", "Healer"]
	var known_cond := ["has_shield"]
	var bad_charm: Array = []
	for row2 in sd.get_charm_rows():
		var cid3 := String(row2.get("charm_id", "?"))
		for r2 in row2.get("applies_to", []):
			if not roles.has(String(r2)):
				bad_charm.append("%s applies_to=%s" % [cid3, r2])
		if row2.has("condition") and not known_cond.has(String(row2["condition"])):
			bad_charm.append("%s condition=%s(미구현)" % [cid3, row2["condition"]])
		# 🚨 F-010 §3.11.1 금지 — controlContext는 doctrine 전용(D-021), 참에 나타나면 오류.
		if row2.has("controlContext") or row2.has("control_context"):
			bad_charm.append("%s controlContext(참 금지 — doctrine 전용)" % cid3)
		# 발동 입력 금지 — 시전·쿨·타겟·마석을 가지면 그 순간 AB-###이다.
		for banned in ["cast_s", "cooldown_s", "target", "manastone_cost"]:
			if row2.has(banned):
				bad_charm.append("%s %s(발동 입력 — 참 금지)" % [cid3, banned])
	_expect(bad_charm.is_empty(), "참 하드 제약 (%s)" % ("위반 없음" if bad_charm.is_empty() else ", ".join(bad_charm)))
	# CS-1 1-9 — 폐기 대상 유령 참조: tank_bluster는 게임에 원래 없어야 한다.
	_expect(sd.get_charm("tank_bluster").is_empty(), "tank_bluster 잔존 0 (Passive 폐기, DEC-20260813-003)")

	# ②d doctrine (CS-2 · F-030 / D-021) — 카탈로그 + 하드 제약. 스키마 위반은 Slice01Data 로드가
	# 이미 abort시키므로(여기까지 왔다 = 통과), 여기선 **구조 불변식**과 프로필 기본값을 본다.
	_expect(sd.get_doctrine_rows().size() == 2, "doctrine 카탈로그 2종 (Tank 파일럿)")
	_expect(sd.doctrines_for_identity("tank_anchor_guard").size() == 2, "Identity당 2개 (D-021)")
	var bad_doc: Array = []
	var nc_mod := 0
	for drow in sd.get_doctrine_rows():
		var dtr: Array = drow.get("traits", [])
		if dtr.size() < 1 or dtr.size() > 2:
			bad_doc.append("%s traits=%d" % [drow.get("doctrine_id", "?"), dtr.size()])
		for tr in dtr:
			if not tr.has("icd_s"):
				bad_doc.append("%s icd_s 누락" % tr.get("trait_id", "?"))
			if String(tr.get("payoff_kind", "")) == "NcModulation":
				nc_mod += 1
	_expect(bad_doc.is_empty(), "doctrine 하드 제약 (%s)" % ("위반 없음" if bad_doc.is_empty() else ", ".join(bad_doc)))
	# DOC-TNK-02는 NcModulation이 **없어야** 한다 — QA-032 §2.3의 대조군이다(NC 미개입).
	var t02_nc := 0
	for tr2 in sd.get_doctrine("DOC-TNK-02").get("traits", []):
		if String(tr2.get("payoff_kind", "")) == "NcModulation":
			t02_nc += 1
	_expect(t02_nc == 0, "DOC-TNK-02 = NC 미개입 대조군 (QA-032 §2.3 대상 아님)")
	# 🚨 controlContext는 doctrine에만 — 참·능력에 새어 나가면 대전제가 깨진다(D-021 §6-3).
	var leak: Array = []
	for crow in sd.get_charm_rows():
		if crow.has("control_context") or crow.has("controlContext"):
			leak.append("charm %s" % crow.get("charm_id", "?"))
	_expect(leak.is_empty(), "controlContext 누출 0 (doctrine 전용, D-021 §6-3)")

	# ②e DoctrineProfile (CS-2 · D-021 §4) — 구매/활성/중립. 순수 로직이라 씬 없이 검증 가능.
	var dpx = load("res://scripts/autoload/doctrine_profile.gd").new()
	_expect(dpx.is_neutral(), "DoctrineProfile 기본 = 중립 성장 (QA-032 §2.1 전제)")
	_expect(not dpx.set_active("Tank", "DOC-TNK-01"), "미구매 doctrine 활성 거부")
	dpx.mark_purchased("DOC-TNK-01")
	_expect(dpx.set_active("Tank", "DOC-TNK-01"), "구매 후 활성 가능")
	_expect(not dpx.is_neutral() and dpx.active_ids() == ["DOC-TNK-01"], "활성 반영")
	dpx.mark_purchased("DOC-TNK-02")
	_expect(dpx.set_active("Tank", "DOC-TNK-02"), "재배치 자유 — Identity당 1개라 이전 활성은 밀려남")
	_expect(dpx.active_ids() == ["DOC-TNK-02"], "활성 1개 유지 (D-021 §4)")
	_expect(not dpx.set_active("DPS", "DOC-TNK-01"), "클래스 불일치 활성 거부")
	# 환불 없음(F-030 §3.2) — 되사는 API가 **존재하지 않아야** 한다(있으면 결국 쓰인다).
	_expect(not dpx.has_method("refund") and not dpx.has_method("unpurchase"), "환불 API 부재 (F-030 §3.2)")
	dpx.clear_all()
	_expect(dpx.is_neutral(), "clear_all → 중립 복귀(기준선 스냅샷용)")
	dpx.free()

	# ②f 상태 라벨 등재 정합 — 상태를 추가하고 **라벨을 빠뜨리면 raw id가 화면에 뜬다**.
	# `Tethered`가 정확히 그렇게 새어 나갔다(DRIFT-132: outcome_status.KO엔 있는데 float_text엔 없어
	# 부여 팝업이 안 떴다). 세 표(COLOR/KO/OUTCOME_KO)를 대조해 다음 상태 추가 때 자동으로 잡는다.
	var OS_ = load("res://scripts/combat/outcome_status.gd")
	var FT_ = load("res://scripts/ui/float_text.gd")
	# 부여 팝업을 **일부러 안 태우는** 상태들 — 사유를 여기 적어 둔다(빈 예외는 곧 구멍이 된다).
	#  · Poison  = 호출부(enemy_unit/party_member)가 자체 "중독" 팝업을 띄운다 → 등재하면 **중복 팝업**.
	#  · Scorched = 화염존 **체류 중 매 프레임 재적용** → 일반 팝업이면 화면 도배.
	var popup_exempt := ["Poison", "Scorched"]
	var label_gap: Array = []
	for sid in OS_.COLOR.keys():
		if not OS_.KO.has(sid):
			label_gap.append("%s(KO 누락)" % sid)
		if not FT_.OUTCOME_KO.has(sid) and not OS_.BUFF.has(sid) and not popup_exempt.has(sid):
			label_gap.append("%s(부여 팝업 라벨 누락)" % sid)   # 버프는 팝업 경로가 달라 제외
	_expect(label_gap.is_empty(), "상태 라벨 등재 정합 (%s)" % ("빠짐 없음" if label_gap.is_empty() else ", ".join(label_gap)))
	_expect(OS_.KO.get("Taunted", "") == "도발", "Taunted = 정식 디버프 등재(DRIFT-149)")
	# 도발은 **이동·공속을 건드리지 않는다** — 어그로는 threat/floor 소관이고 이건 읽히게 하는 표식이다.
	_expect(not OS_.MOVE_MULT.has("Taunted") and not OS_.ATK_MULT.has("Taunted"),
		"Taunted — 이동·공속 미개입(어그로는 threat/floor 소관)")

	# ②g 스킬 트리 (M3 · F-020 §3.10) — 게이트·선행·재료·해금 파생.
	# 참조 무결성(노드→AB/doctrine/선행)은 Slice01Data 로드가 이미 abort시킨다(여기 왔다 = 통과).
	_expect(sd.get_tree_nodes().size() >= 10, "트리 카탈로그 %d노드" % sd.get_tree_nodes().size())
	_expect(sd.tree_nodes_for_class("Tank").size() >= 4, "클래스별 트리 — Tank 노드 존재(U6 클래스 단위)")
	var hp2 = load("res://scripts/autoload/hub_profile.gd").new()
	hp2.persist = false
	for f2 in hp2.FACILITY_IDS:
		hp2.facilities[f2] = 0
	hp2.tree_unlocked = {}
	_expect(String(hp2.tree_check("TREE-TNK-DOC1").get("reason", "")) == "facility", "트리 — chapel T0 잠김(F-029)")
	hp2.facilities["chapel"] = 1
	_expect(String(hp2.tree_check("TREE-TNK-DOC1").get("reason", "")) == "prereq", "트리 — 선행 노드 미해금 차단")
	_expect(bool(hp2.tree_check("TREE-TNK-ROOT").get("ok", false)), "트리 — 루트는 무비용 즉시 가능")
	_expect(bool(hp2.tree_buy("TREE-TNK-ROOT").get("ok", false)), "루트 구매")
	_expect(String(hp2.tree_check("TREE-TNK-DOC1").get("reason", "")) == "haul", "트리 — 재료 부족 차단")
	hp2.add_haul("haul_ward_splinter", 4)
	_expect(bool(hp2.tree_buy("TREE-TNK-DOC1").get("ok", false)), "재료 충족 → doctrine 노드 구매")
	_expect(hp2.vault_count("haul_ward_splinter") == 0, "구매 시 금고 재료 차감(sink)")
	_expect(String(hp2.tree_check("TREE-TNK-DOC1").get("reason", "")) == "already", "재구매 차단(환불 없음)")
	# 파생 — Slot 보너스 · Unlock → AB 해금 · Upgrade 배율.
	# ⚠️ 플테 플래그를 **끄고** 잰다 — 켜 두면 is_node_unlocked가 항상 true라 트리 로직을 안 타고
	# 전부 통과한다(게이트가 아무것도 증명하지 못한다).
	hp2.PLAYTEST_TREE_ALL_UNLOCKED = false
	_expect(not hp2.is_ability_unlocked("AB-033"), "미해금 AB는 잠김(플래그 off 기준)")
	_expect(hp2.tree_slot_bonus("Tank") == 1, "Slot 노드 → gear 슬롯 +1 (루트 구매분, M4가 소비)")
	_expect(hp2.tree_slot_bonus("DPS") == 0, "다른 클래스 Slot은 미해금 → 0")
	hp2.tree_unlocked["TREE-TNK-U1"] = true
	_expect(hp2.is_ability_unlocked("AB-033"), "Unlock 노드 해금 → AB 열림")
	_expect(hp2.is_shop_unlocked("AB-033"), "트리 해금이 상점 해금을 겸한다(구 분석 대체)")
	_expect(hp2.ability_upgrades("AB-033").is_empty(), "Upgrade 미해금 → 배율 없음")
	hp2.tree_unlocked["TREE-TNK-UP1"] = true
	_expect(is_equal_approx(float(hp2.ability_upgrades("AB-033").get("shield", 0.0)), 1.25), "Upgrade 해금 → 파라미터 배율")
	# 플래그 on = **노드가 있는** 것이 전부 열린다. 노드 없는 AB는 여전히 잠긴다(그게 맞다 —
	# 플래그는 "구매를 건너뛴다"이지 "카탈로그에 없는 걸 만든다"가 아니다).
	_expect(not hp2.is_ability_unlocked("AB-034"), "AB-034 — 노드 미해금 상태")
	hp2.PLAYTEST_TREE_ALL_UNLOCKED = true
	_expect(hp2.is_ability_unlocked("AB-034"), "플테 플래그 on → 노드 있는 AB 전부 해금(D4 트리판)")
	_expect(not hp2.is_ability_unlocked("AB-999"), "플래그 on이어도 노드 없는 AB는 잠김")
	hp2.free()

	# ②h gear 슬롯 귀속 모델 (M4 · D-019 §2/§3) — **모딩 패널의 판정층**. 패널은 UI라 스모크가 못 만지므로
	# 그 아래 모델을 전수로 잰다. 여기가 조용히 틀어지면 "끼웠는데 안 들어간다"가 플테에서 터진다.
	var fams: Dictionary = {}
	for sbr in sd.get_skillbook_rows():
		var f := String((sbr as Dictionary).get("skill_family", ""))
		if f == "":
			ghosts.append("skillbooks %s — skill_family 없음" % sbr.get("base_ability_id", "?"))
		else:
			fams[f] = true
	var gear_bad: Array = []
	for gr in sd.get_gear_rows():
		var gid_m := String((gr as Dictionary).get("base_gear_id", ""))
		var af: Array = gr.get("allowed_slot_families", [])
		var mx := int(gr.get("gear_skill_slot_count_max", 0))
		if af.is_empty() or mx < 1 or mx > 3:
			gear_bad.append("%s (fams %d · max %d)" % [gid_m, af.size(), mx])
		for f2 in af:
			if not fams.has(String(f2)):     # 오탈자 계열명 = 그 gear가 조용히 아무것도 못 받게 된다
				gear_bad.append("%s ← 미존재 계열 '%s'" % [gid_m, f2])
	_expect(gear_bad.is_empty(), "gear 27종 allowed_slot_families·slot_max 정합" if gear_bad.is_empty() else "gear 슬롯 메타 불량: %s" % ", ".join(gear_bad))

	var bpm = load("res://scripts/autoload/backpack.gd").new()
	bpm._seed()
	_expect(bpm.gear_slot_abilities("Tank").size() == 3, "시드 — slot_abilities 길이 3")
	# 스타터 gear는 max 1칸. 트리/대장간을 아무리 사도 gear 천장을 못 넘는다(D-019 §2).
	var starter_cap: int = bpm.gear_slot_count("Tank")
	_expect(starter_cap == 1, "스타터 건 = 1칸 (열린 칸 %d)" % starter_cap)
	# 첫 런에 **끼울 수 있는 게 하나도 없으면** 슬롯 스킬이 통째로 죽는다 — 역할별 최소 1종 보장.
	for cls2 in ["Tank", "DPS", "Nuker", "Healer"]:
		var any_ok := false
		for sbr2 in sd.get_skillbook_rows():
			if bool(bpm.slot_equip_check(cls2, 0, String((sbr2 as Dictionary).get("base_ability_id", ""))).get("ok", false)):
				any_ok = true
				break
		_expect(any_ok, "%s — 스타터 건에 끼울 수 있는 AB ≥1" % cls2)
	# 게이트 사유가 실제로 갈리는지(전부 통과/전부 거부면 게이트가 아니다).
	_expect(String(bpm.slot_equip_check("Tank", 2, "AB-033").get("reason", "")) == "slot", "잠긴 칸 거부 사유 = slot")
	_expect(String(bpm.slot_equip_check("Tank", 0, "AB-064").get("reason", "")) == "family", "Role/계열 불일치 거부")
	# D2 소멸 — 교체하면 슬롯이 비고, 잃은 목록이 **이름으로** 돌아온다(모달이 그걸 읽는다).
	bpm.set_gear_slot_ability("Tank", 0, "AB-033")
	_expect(String(bpm.gear_slot_abilities("Tank")[0].get("base_ability_id", "")) == "AB-033", "슬롯 장착 반영")
	var lost2: Array = bpm.set_member_gear("Tank", "gear_ward_tank_kite_shield")
	_expect(lost2 == ["AB-033"], "D2 — 건 교체 시 슬롯 AB 소멸(잃은 목록 반환)")
	_expect(bpm.gear_slot_abilities("Tank")[0] == null, "교체 후 슬롯 비었음")
	_expect(bpm.gear_slot_count("Tank") >= 1, "교체한 건(max 3)도 최소 1칸")
	# 마이그레이션 — 구 세이브(subs만)에 slot_abilities가 생기고, 값이 옮겨진다.
	var bpg = load("res://scripts/autoload/backpack.gd").new()
	bpg.equipped = {"Tank": {"gear": "gear_ward_tank_anchor_bulwark", "subs": [{"base_ability_id": "AB-033"}, null, null]}}
	bpg.migrate_subs_to_gear()
	_expect(String(bpg.gear_slot_abilities("Tank")[0].get("base_ability_id", "")) == "AB-033", "M4 마이그레이션 — subs → gear 슬롯")
	bpg.free()
	bpm.free()

	# ②i 공유 재료(M4-8) — per-kill 스킬북 드롭의 대체재가 **실재**하고 트리가 그걸 소비하는가.
	var ls = load("res://scripts/run/loot_service.gd")
	for mid in [ls.SHARED_SHARD_ID, ls.SHARED_CORE_ID]:
		if sd.get_haul_material(String(mid)).is_empty():
			ghosts.append("loot_service 공유 재료 %s — 카탈로그 미등재" % mid)
	var uses_shared := false
	for tn in sd.get_tree_nodes():
		if (tn.get("cost", {}) as Dictionary).has(ls.SHARED_SHARD_ID):
			uses_shared = true
	_expect(uses_shared, "트리 Unlock이 공유 재료를 소비 — 처치→재료→금고→해금 루프 성립")

	# ③ 샌드박스 픽스처 — dev 툴이지만 유저의 실제 체감 무대라 낡으면 "그 스킬 안 나오는데?"가 된다.
	var sandbox = load("res://scripts/dev/combat_sandbox.gd")
	for cls in sandbox.SANDBOX_SUBS:
		for aid2 in sandbox.SANDBOX_SUBS[cls]:
			if String(aid2) != "" and sd.get_skillbook_master(String(aid2)).is_empty():
				ghosts.append("SANDBOX_SUBS[%s] %s" % [cls, aid2])
	for key2 in sandbox._BIND_FIXTURES:
		var cfg: Dictionary = sandbox._BIND_FIXTURES[key2]
		if sd.get_gear_master(String(cfg.get("gear", ""))).is_empty():
			ghosts.append("_BIND_FIXTURES[%s].gear %s" % [key2, cfg.get("gear", "")])
		for aid3 in cfg.get("subs", []):
			if String(aid3) != "" and sd.get_skillbook_master(String(aid3)).is_empty():
				ghosts.append("_BIND_FIXTURES[%s] %s" % [key2, aid3])

	for gh in ghosts:
		print("  GHOST  " + gh)
	_expect(ghosts.is_empty(), "유령 참조 0건 (시드·픽스처 전수)")

	hp.free()
	if _ok:
		print("HUB SMOKE PASSED")
		quit(0)
	else:
		print("HUB SMOKE FAILED")
		quit(1)


func _expect(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_ok = false
