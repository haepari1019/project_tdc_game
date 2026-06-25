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
	_expect(hp.stash_capacity() == 28, "stash capacity 28")

	# prereq 게이트 — scribe_shop T1은 scriptorium≥1 선행
	_expect(String(hp.upgrade_check("scribe_shop").get("reason", "")) == "prereq", "scribe_shop 선행 차단")

	# B4 — ENC-HARD-001 클리어 기록 → Q-HUB-020(armory T1 퀘스트) 완료
	hp.record_enc_cleared("ENC-HARD-001")
	hp.evaluate_quests()
	_expect(hp.is_quest_done("Q-HUB-020"), "B4 Q-HUB-020 (ENC-HARD-001 클리어)")

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
