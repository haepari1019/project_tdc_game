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
	_expect(sd.get_charm_rows().size() == 5, "참 카탈로그 5종")
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
	# 효과 키가 apply_charms가 아는 축인지 — 오타 하나로 참이 조용히 무효가 된다.
	var known := ["damage_taken_mult", "outgoing_mult", "move_mult", "attack_speed_mult", "reflect_flat"]
	var bad_eff: Array = []
	for row in sd.get_charm_rows():
		if not known.has(String(row.get("effect", ""))):
			bad_eff.append("%s(%s)" % [row.get("charm_id", "?"), row.get("effect", "?")])
	_expect(bad_eff.is_empty(), "참 effect 키 전부 유효 (%s)" % ("없음" if bad_eff.is_empty() else ", ".join(bad_eff)))

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
