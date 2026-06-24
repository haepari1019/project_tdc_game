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

	print("PARTY POOL SMOKE " + ("PASSED" if _ok else "FAILED"))
	quit(0 if _ok else 1)


func _chk(label: String, cond: bool) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_ok = false
