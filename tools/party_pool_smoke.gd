extends SceneTree
## P2-S6a party-pool smoke (DRIFT-057) — non-scene logic check: every skillbook cast.kind has a
## registered drop-in effect, the band penalty (D-016/D-012 §2.4) resolves, the new B1 ally-only ABs
## (034/044/054/062/070/075) are wired, and the new statuses behave (Veiled / Silenced / Purge).
## Scripts that reference the Slice01Data autoload are load()-ed at RUNTIME after the singleton child
## exists (autoload globals aren't registered in a --script run; mirrors third_smoke.gd).
## Run: GODOT --headless --path . --script res://tools/party_pool_smoke.gd

var _ok := true


## Minimal party stand-in for Backpack.apply_to_party (it only calls get_members()).
class _PartyStub:
	var _m: Array = []
	func _init(arr: Array) -> void:
		_m = arr
	func get_members() -> Array:
		return _m


func _initialize() -> void:
	# Data — instantiate Slice01Data so its _ready loads + validates the catalogs (aborts on bad ID).
	var sd = preload("res://scripts/autoload/slice01_data.gd").new()
	sd.name = "Slice01Data"
	root.add_child(sd)
	await process_frame

	# Load (compile) the Slice01Data-referencing scripts now that /root/Slice01Data exists.
	var AD = load("res://scripts/combat/abilities/ability_dispatch.gd")
	var PM = load("res://scripts/party/party_member.gd")
	var EN = load("res://scripts/combat/enemy_unit.gd")

	# 1) Registered effect kinds, gathered from the dispatch drop-in list.
	var kinds := {}
	for s in AD._SKILL_SCRIPTS:
		kinds[String(s.new().kind())] = true

	# 2) Every skillbook master's cast.kind must have a registered effect (no silent dead skill).
	for ab in sd._registry_list("ability_ids"):
		var m: Dictionary = sd.get_skillbook_master(String(ab))
		if m.is_empty():
			continue
		var k := String(m.get("cast", {}).get("kind", ""))
		_chk("%s kind '%s' has effect" % [ab, k], kinds.has(k))

	# 3) New B1 ally-only skillbooks resolve with the right kind + key params.
	var want := {
		"AB-075": "skillbook_shield", "AB-062": "skillbook_stealth", "AB-054": "skillbook_beam",
		"AB-034": "skillbook_barrier", "AB-070": "skillbook_purge", "AB-044": "skillbook_silence",
	}
	for ab in want:
		var c: Dictionary = sd.get_skillbook_master(ab).get("cast", {})
		_chk("%s kind=%s" % [ab, want[ab]], String(c.get("kind", "")) == want[ab])
	_chk("AB-062 veil_s>0", float(sd.get_skillbook_master("AB-062").get("cast", {}).get("veil_s", 0.0)) > 0.0)
	_chk("AB-054 ticks>0", int(sd.get_skillbook_master("AB-054").get("cast", {}).get("ticks", 0)) > 0)
	_chk("AB-044 silence_s>0", float(sd.get_skillbook_master("AB-044").get("cast", {}).get("silence_s", 0.0)) > 0.0)
	_chk("AB-034 barrier_hp>0", float(sd.get_skillbook_master("AB-034").get("cast", {}).get("barrier_hp", 0.0)) > 0.0)

	# 4) Band penalty — coeff table + sub_bands data sanity + the dispatch coeff helper.
	_chk("BAND_COEFF B0=1.0", is_equal_approx(float(AD.BAND_COEFF["B0"]), 1.0))
	_chk("BAND_COEFF B2<B1", float(AD.BAND_COEFF["B2"]) < float(AD.BAND_COEFF["B1"]))
	_chk("BAND_COEFF B3<B2", float(AD.BAND_COEFF["B3"]) < float(AD.BAND_COEFF["B2"]))
	for ab in sd._registry_list("ability_ids"):
		var m: Dictionary = sd.get_skillbook_master(String(ab))
		if m.is_empty():
			continue
		var eq: Array = m.get("equip_classes", [])
		for cls in m.get("sub_bands", {}):
			var band := String(m.get("sub_bands", {})[cls])
			_chk("%s sub_band %s in equip" % [ab, cls], eq.has(cls))
			_chk("%s band %s valid" % [ab, band], AD.BAND_COEFF.has(band))
	var ad = AD.new()
	_chk("Nuker B2 coeff 0.75", is_equal_approx(ad._band_coeff("Nuker", {"Nuker": "B2"}), 0.75))
	_chk("main class full coeff", is_equal_approx(ad._band_coeff("DPS", {"Nuker": "B2"}), 1.0))
	ad.free()

	# 5) Status behaviour — Veiled (party), Silenced + Purge (enemy) on bare instances (no scene).
	var pm = PM.new()
	pm.apply_veil(1.5)
	_chk("party Veiled active", pm.is_veiled())
	pm.free()

	var en = EN.new()
	en.apply_silence(3.0)
	_chk("enemy Silenced active", en.is_silenced())
	en.tick_silence(3.1)
	_chk("enemy Silence expires", not en.is_silenced())
	en.apply_outcome("Bloodlust", 999.0)
	_chk("Purge removes Bloodlust", en.purge_one_buff() == "Bloodlust" and not en.is_bloodlust())
	_chk("Purge nothing -> ''", en.purge_one_buff() == "")
	en.free()

	# 6) I5 charge persistence — Backpack.apply_to_party restores a sub's stored 탄수 (not max).
	var BP = load("res://scripts/autoload/backpack.gd")
	var bp = BP.new()   # bare instance (not in tree → no _ready seed)
	bp.set_member_subs("Healer", [{"base_ability_id": "AB-064", "charges": 3}, null, null])
	var pm2 = PM.new()
	pm2.class_id = "Healer"
	bp.apply_to_party(_PartyStub.new([pm2]))
	var inst0 = pm2.get_skillbook(0)
	_chk("charge persist (stored 3, not max)", inst0 != null and int(inst0.charges) == 3 and int(inst0.charges_max) > 3)
	pm2.free()

	# 7) Deferred ability details — Shadowstep next-hit, Beam channel flag, Sentinel reflect.
	var pm3 = PM.new()
	pm3.grant_next_hit_bonus(0.2)
	_chk("next-hit bonus consume 0.2", is_equal_approx(pm3.consume_next_hit_bonus(), 0.2))
	_chk("next-hit bonus one-shot", is_equal_approx(pm3.consume_next_hit_bonus(), 0.0))
	pm3.begin_channel(1.0)
	_chk("channel active", pm3.is_channeling())
	var atk = EN.new()
	var atk_hp0 := float(atk.hp)
	pm3.enter_sentinel(0.5, 4.0, 0.4)
	pm3.take_damage(100.0, atk)
	_chk("Sentinel reflects 40% to attacker", is_equal_approx(float(atk.hp), atk_hp0 - 40.0))
	atk.free()
	pm3.free()

	# 8) Bloodlust HP-scale (AB-105) — rage scales with missing HP (≈half at 50%, full near death).
	var en2 = EN.new()
	en2.bloodlust_dmg_mult = 1.3   # MAX rage (at 0 HP)
	en2.apply_outcome("Bloodlust", 999.0)
	en2.hp = en2.max_hp * 0.5      # 50% missing → ~15% dmg bonus (half of 30%)
	var half_mult := float(en2.contact_damage_mult())
	en2.hp = en2.max_hp * 0.01     # ~100% missing → ~full 30% bonus
	var low_mult := float(en2.contact_damage_mult())
	_chk("Bloodlust scales with missing HP", half_mult > 1.0 and low_mult > half_mult)
	en2.free()

	# 9) Projectile delivery (Phase 1) — AB-056 flagged + sb_bolt resolve_at payload + dispatch hook.
	_chk("AB-056 delivery=projectile", String(sd.get_skillbook_master("AB-056").get("cast", {}).get("delivery", "")) == "projectile")
	var bolt_eff = null
	for s in AD._SKILL_SCRIPTS:
		var inst = s.new()
		if String(inst.kind()) == "skillbook_bolt":
			bolt_eff = inst
			break
	_chk("sb_bolt exposes resolve_at", bolt_eff != null and bolt_eff.has_method("resolve_at"))
	var adp = AD.new()
	_chk("dispatch has spawn_projectile", adp.has_method("spawn_projectile"))
	adp.free()

	# 10) Rampart faction filter (DRIFT-059) — a wall blocks HOSTILE projectiles, friendly pass through.
	var RB = load("res://scripts/world/objects/rampart_barrier.gd")
	var bar = RB.new()
	var ally_a = PM.new(); ally_a.add_to_group("party_member")
	var ally_b = PM.new(); ally_b.add_to_group("party_member")
	bar._caster = ally_a   # wall owned by a party member
	_chk("ally wall PASSES ally shot", not bar.blocks_projectile_from(ally_b))
	var foe = EN.new()     # enemy shooter (not party_member)
	_chk("ally wall BLOCKS enemy shot", bar.blocks_projectile_from(foe))
	bar.free(); ally_a.free(); ally_b.free(); foe.free()

	# 11) Gear roll-table G1 (F-008 §3.7) — 스타터 spec id 정렬 + 파생 롤테이블(main bundled w50 + 동클래스).
	_chk("starter gear id 스펙 정렬", not sd.get_gear_master("gear_ward_tank_anchor_bulwark").is_empty())
	var rt: Array = sd.get_gear_identity_roll_table("gear_ward_tank_anchor_bulwark")
	_chk("roll-table main=bundled w50", rt.size() >= 1 and String(rt[0].get("skill_id", "")) == "tank_anchor_guard" and int(rt[0].get("weight", 0)) == 50)
	_chk("roll-table Tank 후보 다수", rt.size() >= 2)

	# 12) Gear roll-table G2 — equipped 인스턴스의 rolled identity가 apply/capture로 영속(bundled 아님).
	var bp2 = BP.new()   # bare instance (no _ready seed)
	bp2.equipped = {"Tank": {"gear": "gear_ward_tank_anchor_bulwark", "rolled_identity": "tank_iron_beacon", "rolls": {"dmg_mult": 1.1}, "subs": [null, null, null]}}
	var tank = PM.new()
	tank.class_id = "Tank"
	bp2.apply_to_party(_PartyStub.new([tank]))
	_chk("G2 rolled identity 적용(bundled 아님)", String(tank.identity_skill_id) == "tank_iron_beacon")
	_chk("G2 rolls 저장", float((tank.gear_rolls as Dictionary).get("dmg_mult", 0.0)) > 1.0)
	bp2.capture_from_party(_PartyStub.new([tank]))
	_chk("G2 rolled identity capture 영속", String((bp2.equipped["Tank"] as Dictionary).get("rolled_identity", "")) == "tank_iron_beacon")
	tank.free()

	# 13) 유저 표시명 (display_names.json) — 백엔드 ID 분리, 매핑 없으면 ID 폴백.
	_chk("identity 표시명", sd.get_identity_display("tank_iron_beacon") == "강철 봉화")
	_chk("effect 표시명", sd.get_effect_label("skillbook_silence") == "침묵")
	_chk("role 표시명", sd.get_role_label("Healer") == "힐러")
	_chk("미등록 ID 폴백", sd.get_effect_label("nonexistent_kind") == "nonexistent_kind")

	# 14) G3 — rolls mult 스탯 적용. 같은 기어 dmg_mult 1.0 vs 2.0 → basic_damage 2배 + cd_mult→cooldown_mult.
	var pmA = PM.new(); pmA.class_id = "Tank"
	var bpA = BP.new(); bpA.equipped = {"Tank": {"gear": "gear_ward_tank_anchor_bulwark", "rolls": {"dmg_mult": 1.0, "cd_mult": 1.0}, "subs": [null, null, null]}}
	bpA.apply_to_party(_PartyStub.new([pmA]))
	var d1 := float(pmA.basic_damage)
	var pmB = PM.new(); pmB.class_id = "Tank"
	var bpB = BP.new(); bpB.equipped = {"Tank": {"gear": "gear_ward_tank_anchor_bulwark", "rolls": {"dmg_mult": 2.0, "cd_mult": 0.9}, "subs": [null, null, null]}}
	bpB.apply_to_party(_PartyStub.new([pmB]))
	_chk("G3 dmg_mult 스탯 적용(2x)", d1 > 0.0 and is_equal_approx(float(pmB.basic_damage), d1 * 2.0))
	_chk("G3 cd_mult → cooldown_mult", is_equal_approx(float(pmB.cooldown_mult), 0.9))
	pmA.free(); pmB.free()

	# 15) Stash 인스턴스화(F-008 §3.7) — 레거시 문자열 정규화 + 굴린 인스턴스 round-trip(apply_dict/to_dict).
	#     add_child 안 함(autoload 없는 --script에서 _ready/save_stash의 get_node 절대경로 회피).
	var StashScript = load("res://scripts/autoload/stash.gd")
	var st = StashScript.new()
	st.apply_dict({"gear": ["gear_ward_tank_kite_shield", {"base_gear_id": "gear_ward_dps_ember_wand", "rolled_identity_skill_id": "dps_arc_weave", "rolls": {"dmg_mult": 1.2}}], "skillbooks": [], "consumables": {}})
	_chk("Stash 레거시 문자열 정규화", typeof(st.gear[0]) == TYPE_DICTIONARY and String((st.gear[0] as Dictionary).get("base_gear_id", "")) == "gear_ward_tank_kite_shield")
	_chk("Stash 굴린 인스턴스 보존", String((st.gear[1] as Dictionary).get("rolled_identity_skill_id", "")) == "dps_arc_weave")
	var st2 = StashScript.new()
	st2.apply_dict(st.to_dict())
	_chk("Stash round-trip rolled 유지", String((st2.gear[1] as Dictionary).get("rolled_identity_skill_id", "")) == "dps_arc_weave" and is_equal_approx(float((st2.gear[1] as Dictionary).get("rolls", {}).get("dmg_mult", 0.0)), 1.2))
	st.free(); st2.free()

	# 16) 스킬북 affix(D-018 §7.3/§7.6) — roll cap 준수 + charges 가산 + capture/apply 영속.
	var AffixRoller = load("res://scripts/run/affix_roller.gd")
	var any_affix := false
	var caps_ok := true
	var ids_ok := true
	for _i in 300:
		var a: Dictionary = AffixRoller.roll()
		if a.is_empty():
			continue
		any_affix = true
		if float(a.get("coeff", 0.0)) > 0.1201 or int(a.get("charges", 0)) < 0 or int(a.get("charges", 0)) > 6:
			caps_ok = false
		if (a.get("ids", []) as Array).is_empty() or String(a.get("tier", "")).is_empty():
			ids_ok = false
	_chk("affix 발생(300샘플)", any_affix)
	_chk("affix coeff≤12%·탄0..6", caps_ok)
	_chk("affix ids·tier 존재", ids_ok)
	# charges 가산 + 인스턴스 저장
	var base_cmax := int(sd.get_skillbook_master("AB-044").get("charges_max", 30))
	var pmc = PM.new(); pmc.class_id = "Healer"
	pmc.equip_skillbook_by_id(0, "AB-044", {"ids": ["affix_charges_small"], "tier": "T1", "coeff": 0.0, "charges": 5, "cd_trade": 0.0})
	var sb0 = pmc.get_skillbook(0)
	_chk("affix charges_max +5", sb0 != null and int(sb0.charges_max) == base_cmax + 5)
	_chk("affix 인스턴스 저장", sb0 != null and int((sb0.affix as Dictionary).get("charges", 0)) == 5)
	# capture/apply 영속 round-trip
	var bpc = BP.new()
	bpc.capture_from_party(_PartyStub.new([pmc]))
	var pmc2 = PM.new(); pmc2.class_id = "Healer"
	bpc.apply_to_party(_PartyStub.new([pmc2]))
	var sb1 = pmc2.get_skillbook(0)
	_chk("affix 영속(capture/apply)", sb1 != null and int((sb1.affix as Dictionary).get("charges", 0)) == 5 and int(sb1.charges_max) == base_cmax + 5)
	pmc.free(); pmc2.free()

	# 17) 스킬 설명문 + 색구분 툴팁 빌더 (display_names.skill_desc / SkillText).
	_chk("skill_desc(silence) 존재", not sd.get_skill_desc("skillbook_silence").is_empty())
	var ST = load("res://scripts/ui/skill_text.gd")
	var alines: Array = ST.affix_lines({"ids": ["affix_eff_plus"], "tier": "T1", "coeff": 0.09, "charges": 0, "cd_trade": 0.0})
	_chk("affix_lines 색태그", alines.size() >= 1 and String(alines[0]).contains("color="))
	_chk("band_pct 주력=0", ST.band_pct("AB-044", "Healer") == 0)
	_chk("gear_roll_line 색태그", String(ST.gear_roll_line({"dmg_mult": 1.1, "cd_mult": 0.95})).contains("color="))

	print("PARTY POOL SMOKE " + ("PASSED" if _ok else "FAILED"))
	quit(0 if _ok else 1)


func _chk(label: String, cond: bool) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_ok = false
