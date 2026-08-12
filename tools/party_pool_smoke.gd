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

	# 2b) ctx 계약 파리티 — 파티(AbilityDispatch)·적(CastContext) 두 ctx 구현이 CTX_CONTRACT를 모두
	#     구현하는가. 암묵 중복 → 명시 계약: 새 ctx 메서드 추가 후 CastContext 갱신을 빠뜨리면 여기서 잡힌다.
	var CC = load("res://scripts/combat/abilities/cast_context.gd")
	var ad_ctx = AD.new()
	var cc_ctx = CC.new()
	for cm in AD.CTX_CONTRACT:
		_chk("ctx 계약 dispatch.%s" % cm, ad_ctx.has_method(cm))
		_chk("ctx 계약 CastContext.%s" % cm, cc_ctx.has_method(cm))
	ad_ctx.free()
	cc_ctx.free()

	# 2c) role/exec 전수검증 — enemy가 참조하는 모든 AB가 ability_roles.ROLES에 등록됐는가(미등록 →
	#     템포 캡 판정이 조용히 누락). exec 값도 유효(shared/ai_internal/hybrid).
	var ARoles = load("res://scripts/combat/abilities/ability_roles.gd")
	var VALID_EXEC := {"shared": true, "ai_internal": true, "hybrid": true}
	for eid in sd.get_enemy_ids():
		for ab_ref in sd.get_enemy_row(String(eid)).get("abilities", []):
			var abr := String((ab_ref as Dictionary).get("ref", ""))
			if abr == "":
				continue
			_chk("%s role 등록(%s)" % [abr, eid], ARoles.role_of(abr) != "")
			_chk("%s exec 유효" % abr, VALID_EXEC.has(ARoles.exec_of(abr)))

	# 3) New B1 ally-only skillbooks resolve with the right kind + key params.
	var want := {
		"AB-075": "skillbook_shield", "AB-062": "skillbook_stealth", "AB-054": "skillbook_channeling",
		"AB-034": "skillbook_barrier", "AB-070": "skillbook_purge", "AB-044": "skillbook_silence",
	}
	for ab in want:
		var c: Dictionary = sd.get_skillbook_master(ab).get("cast", {})
		_chk("%s kind=%s" % [ab, want[ab]], String(c.get("kind", "")) == want[ab])
	# AB-062 오프너 재정의(DRIFT-121) — 「평타 정지」와 「첫 타격 증폭」은 **한 쌍이어야만** 성립한다.
	# 증폭만 남고 hold_fire가 빠지면 은신 직후 평타가 증폭을 즉시 삼켜(평타는 은신을 깨지 않는다) 설계가
	# 통째로 무너지는데, 화면엔 "왜인지 한 방이 안 뜬다"로만 보여 눈으로는 못 잡는다 → 쌍을 게이트로 건다.
	var c62: Dictionary = sd.get_skillbook_master("AB-062").get("cast", {})
	_chk("AB-062 veil_s>0", float(c62.get("veil_s", 0.0)) > 0.0)
	_chk("AB-062 next_hit_bonus>0 (오프너)", float(c62.get("next_hit_bonus", 0.0)) > 0.0)
	_chk("AB-062 증폭 ⇒ hold_fire (평타 누수 방지)",
		float(c62.get("next_hit_bonus", 0.0)) <= 0.0 or bool(c62.get("hold_fire", false)))
	# 「준비 창」이 실제로 시전을 덮어야 성립한다 — 은신이 캐스트보다 짧으면 시전 도중 만료돼 평타가
	# 재개되고 증폭이 그리로 새어나간다. 누커가 실을 수 있는 **가장 긴 시전**보다 여유 있게 길어야 한다.
	var nuker_max_cast := 0.0
	for ab in sd._registry_list("ability_ids"):
		var mn: Dictionary = sd.get_skillbook_master(String(ab))
		if mn.is_empty() or not (mn.get("equip_classes", []) as Array).has("Nuker"):
			continue
		nuker_max_cast = maxf(nuker_max_cast, float(mn.get("cast", {}).get("cast_s", 0.0)))
	_chk("AB-062 준비 창 > 누커 최장 시전(%.1fs)" % nuker_max_cast, float(c62.get("veil_s", 0.0)) > nuker_max_cast)
	# 해제 시점 = **첫 타격**(시전 시작 아님). 시전 시작에 풀면 긴 캐스트 내내 노출돼 위 준비 창이 무의미해진다.
	# 헤드리스에선 전투 루프를 돌릴 수 없어 두 지점을 소스로 못박는다(DRIFT-119 ward_heal 선례).
	var adsrc := FileAccess.get_file_as_string("res://scripts/combat/abilities/ability_dispatch.gd")
	_chk("시전 시작은 오프너 은신을 풀지 않음", adsrc.contains("not (member.has_method(\"holds_fire\") and member.holds_fire())"))
	var ccsrc := FileAccess.get_file_as_string("res://scripts/combat/combat_controller.gd")
	_chk("첫 타격이 오프너 은신을 해제", ccsrc.contains("attacker.holds_fire()") and ccsrc.contains("attacker.break_veil()"))
	_chk("AB-054 ticks>0", int(sd.get_skillbook_master("AB-054").get("cast", {}).get("ticks", 0)) > 0)
	_chk("AB-044 silence_s>0", float(sd.get_skillbook_master("AB-044").get("cast", {}).get("silence_s", 0.0)) > 0.0)
	_chk("AB-034 barrier_hp>0", float(sd.get_skillbook_master("AB-034").get("cast", {}).get("barrier_hp", 0.0)) > 0.0)
	# T2 판정(DRIFT-102/104): AB-048 → **반격 2변주**(048a 시간형 / 048b 캐스팅 한정 타수형) · AB-074 폐기 ·
	# AB-046(자기)↔AB-047(파티) 반경 분화 · DR은 **시간 기반**(타수형은 체감 나빠 롤백).
	for ab in ["AB-048a", "AB-048b"]:
		var cr: Dictionary = sd.get_skillbook_master(ab).get("cast", {})
		_chk("%s kind=skillbook_reflect" % ab, String(cr.get("kind", "")) == "skillbook_reflect")
		_chk("%s reflect_frac>0" % ab, float(cr.get("reflect_frac", 0.0)) > 0.0)
		_chk("%s reflect_cap>0 (밸런싱 상한)" % ab, float(cr.get("reflect_cap", 0.0)) > 0.0)
		_chk("%s DR 잔재 없음" % ab, not cr.has("damage_reduction"))
	var c48a: Dictionary = sd.get_skillbook_master("AB-048a").get("cast", {})
	var c48b: Dictionary = sd.get_skillbook_master("AB-048b").get("cast", {})
	_chk("AB-048a = 시간형(타수 없음)", int(c48a.get("reflect_hits", 0)) == 0 and not bool(c48a.get("reflect_cast_only", false)))
	_chk("AB-048b = 타수형", int(c48b.get("reflect_hits", 0)) > 0)
	_chk("AB-048b = 캐스팅 한정", bool(c48b.get("reflect_cast_only", false)))
	_chk("AB-048 원본 제거(a/b로 분할)", sd.get_skillbook_master("AB-048").is_empty())
	_chk("AB-074 폐기", sd.get_skillbook_master("AB-074").is_empty())
	_chk("AB-046 자기(radius<=1)", float(sd.get_skillbook_master("AB-046").get("cast", {}).get("radius_m", 0.0)) <= 1.0)
	_chk("AB-047 파티(radius>1)", float(sd.get_skillbook_master("AB-047").get("cast", {}).get("radius_m", 0.0)) > 1.0)
	for ab in ["AB-046", "AB-047", "AB-068"]:
		var cdr: Dictionary = sd.get_skillbook_master(ab).get("cast", {})
		_chk("%s duration_s>0 (시간 기반)" % ab, float(cdr.get("duration_s", 0.0)) > 0.0)
		_chk("%s dr_label 有 (칩 분리)" % ab, String(cdr.get("dr_label", "")) != "")
		_chk("%s dr_hits 잔재 없음" % ab, not cdr.has("dr_hits"))
	# DR 곱연산 + 스택별 별개 버프 칩 + Sentinel 분리(버그 수정, DRIFT-103)
	var pmdr = PM.new()
	root.add_child(pmdr)   # popup_status(FloatText)가 트리를 요구
	pmdr.apply_damage_reduction(0.5, 2.0, "철벽")
	pmdr.apply_damage_reduction(0.2, 3.0, "수호진")
	_chk("DR 곱연산 0.5×0.8 → ×0.4", is_equal_approx(pmdr.damage_taken_mult, 0.4))
	var dr_chips: int = 0
	for st in pmdr.get_status_list():
		var nm := String(st.get("name", ""))
		if nm.begins_with("철벽") or nm.begins_with("수호진"):
			dr_chips += 1
			_chk("%s = 버프 칩" % nm, bool(st.get("buff", false)))
	_chk("DR 스택 2개 = 버프 칩 2개(별개)", dr_chips == 2)
	pmdr.apply_damage_reduction(0.5, 2.0, "철벽")   # 같은 label 재시전 = 갱신(칸 추가 아님)
	_chk("같은 label 재시전 = 갱신(칸 유지)", is_equal_approx(pmdr.damage_taken_mult, 0.4))
	pmdr.enter_sentinel(0.6, 4.0, 0.0)
	_chk("Sentinel × DR 곱연산 (0.4×0.4)", is_equal_approx(pmdr.damage_taken_mult, 0.16))
	pmdr.free()

	# D1 판정 — AB-055 산탄: 착탄 후 방사형 파편. 반경 서열(원형 AB-008 > 초탄 > 파편)이 설계 축이다.
	var c55: Dictionary = sd.get_skillbook_master("AB-055").get("cast", {})
	var c08: Dictionary = sd.get_skillbook_master("AB-008").get("cast", {})
	_chk("AB-055 scatter_pellets>0", int(c55.get("scatter_pellets", 0)) > 0)
	_chk("AB-055 초탄 반경 < 원형 AB-008", float(c55.get("radius_m", 9.0)) < float(c08.get("radius_m", 0.0)))
	_chk("AB-055 파편 반경 << 초탄 반경", float(c55.get("scatter_radius_m", 9.0)) < float(c55.get("radius_m", 0.0)) * 0.5)
	_chk("AB-055 파편이 착탄점보다 멀리 퍼짐", float(c55.get("scatter_range_m", 0.0)) > float(c55.get("radius_m", 0.0)))
	# 재귀 가드 — 산탄 params를 그대로 재사용하면 파편이 또 산탄을 낳는다(무한 증식).
	var boltfx = null
	for sc in AD._SKILL_SCRIPTS:
		var inst2 = sc.new()
		if String(inst2.kind()) == "skillbook_bolt":
			boltfx = inst2
	_chk("skillbook_bolt 이펙트 해소", boltfx != null)
	_chk("_scatter 재귀 가드 존재", boltfx != null and boltfx.has_method("_scatter"))
	# 데드존 — 착탄점에 적이 서 있어도 파편 6발이 그 자리에서 동시 폭발하지 않게 무장 거리를 둔다.
	# **조준 마커의 빈 공간과 같은 값**이어야 하므로 계산은 `deadzone_of` 한 곳이 SSOT.
	var SbBolt = load("res://scripts/combat/abilities/effects/sb_bolt.gd")
	var dz: float = SbBolt.deadzone_of(c55)
	_chk("AB-055 데드존 > 초탄 반경", dz > float(c55.get("radius_m", 0.0)))
	_chk("AB-055 데드존 < 파편 도달(띠가 생김)", dz < float(c55.get("scatter_range_m", 0.0)))
	_chk("AB-055 scatter_cone_deg < 360(부채꼴)", float(c55.get("scatter_cone_deg", 360.0)) < 360.0)
	# §0 딜 원칙(긴 캐스트 + 긴 쿨 + 큰 한방) — 산탄은 원형 AB-008보다 효과가 크므로 캐스트도 그 이상.
	_chk("AB-055 캐스트 ≥ 원형 AB-008", float(c55.get("cast_s", 0.0)) >= float(c08.get("cast_s", 0.0)))
	_chk("AB-055 총 주기 > 원형 AB-008", float(c55.get("cast_s", 0.0)) + float(c55.get("cooldown_s", 0.0))
		> float(c08.get("cast_s", 0.0)) + float(c08.get("cooldown_s", 0.0)))
	# D1 속성 커버(DRIFT-110) — 원형 008은 **무속성**으로 되돌리고 속성은 전부 변형이 진다.
	_chk("AB-008 원형 = 무속성(slag 제거)", not c08.has("element"))
	_chk("AB-058 주력 = Nuker(무주력 해소)", not (sd.get_skillbook_master("AB-058").get("sub_bands", {}) as Dictionary).has("Nuker"))
	var elems := {}
	for ab in sd._registry_list("ability_ids"):
		var mb: Dictionary = sd.get_skillbook_master(String(ab))
		if mb.is_empty():
			continue
		var cb: Dictionary = mb.get("cast", {})
		if String(cb.get("kind", "")) == "skillbook_bolt" and String(cb.get("element", "")) != "":
			elems[String(cb["element"])] = true
	for want_el in ["fire", "cold", "lightning"]:
		_chk("볼트 계열 %s 커버" % want_el, elems.has(want_el))

	# D5 채널링 재정의(DRIFT-115) — 클러스터 축이 「빔」에서 **채널링**으로 바뀌며 4형상 × 4속성.
	_chk("skillbook_beam kind 소멸", not kinds.has("skillbook_beam"))
	_chk("skillbook_channeling kind 등록", kinds.has("skillbook_channeling"))
	var shapes := {}
	var ch_elems := {}
	for ab in sd._registry_list("ability_ids"):
		var mc: Dictionary = sd.get_skillbook_master(String(ab))
		if mc.is_empty():
			continue
		var cc2: Dictionary = mc.get("cast", {})
		if String(cc2.get("kind", "")) != "skillbook_channeling":
			continue
		shapes[String(cc2.get("channel_shape", "line"))] = String(ab)
		ch_elems[String(cc2.get("element", ""))] = true
		# 채널은 **틱으로 성립**한다 — ticks/interval이 없으면 즉발이 되어 클러스터 정의가 깨진다.
		_chk("%s ticks>1(채널)" % ab, int(cc2.get("ticks", 0)) > 1)
		_chk("%s tick_interval_s>0" % ab, float(cc2.get("tick_interval_s", 0.0)) > 0.0)
		# **집중 체감 하한**(사용자 제보: *"너무 짧아서 집중 중인 느낌이 안 난다"*) — 채널이 짧으면
		# 즉발과 구분이 안 돼 클러스터의 존재 이유(제자리 대가)가 사라진다. 3초를 바닥으로 못박는다.
		_chk("%s 채널 지속 >=3s(집중 체감)" % ab,
			float(cc2.get("ticks", 0)) * float(cc2.get("tick_interval_s", 0.0)) >= 3.0)
	for want_shape in ["line", "cone", "cloud", "nova"]:
		_chk("채널 형상 %s 존재" % want_shape, shapes.has(want_shape))
	for want_el2 in ["lightning", "fire", "poison", "cold"]:
		_chk("채널 속성 %s 커버" % want_el2, ch_elems.has(want_el2))
	# 형상별 필수 params — 없으면 기하가 기본값으로 조용히 떨어져 툴팁과 실제가 어긋난다.
	var c109: Dictionary = sd.get_skillbook_master(String(shapes.get("cone", ""))).get("cast", {})
	var c110: Dictionary = sd.get_skillbook_master(String(shapes.get("cloud", ""))).get("cast", {})
	var c111: Dictionary = sd.get_skillbook_master(String(shapes.get("nova", ""))).get("cast", {})
	var c054: Dictionary = sd.get_skillbook_master(String(shapes.get("line", ""))).get("cast", {})
	_chk("cone half_deg >> line half_deg(부채꼴 ↔ 직선)",
		float(c109.get("half_deg", 0.0)) > float(c054.get("half_deg", 99.0)) * 2.0)
	_chk("cone 사거리 < line 사거리(근거리 분사)", float(c109.get("range_m", 99.0)) < float(c054.get("range_m", 0.0)))
	_chk("cloud radius_m>0", float(c110.get("radius_m", 0.0)) > 0.0)
	_chk("cloud poison_dps>0(피해 아닌 스택이 payoff)", float(c110.get("poison_dps", 0.0)) > 0.0)
	_chk("cloud 사거리 = 근거리 배치(<=10m)", float(c110.get("range_m", 99.0)) <= 10.0)
	_chk("nova = 자기중심(targeted 아님)", not bool(c111.get("targeted", false)))
	_chk("nova freeze_s>0(완주 payoff)", float(c111.get("freeze_s", 0.0)) > 0.0)
	# 빙결·냉각 심화 — 상태 규격이 실제로 동작하는가(표 등재만으론 안 걸린다).
	var OS_ = load("res://scripts/combat/outcome_status.gd")
	var oc = OS_.new()
	oc.apply("Chilled", 3.0, 0.0)
	var chill_base: float = oc.move_mult()
	var atk_base: float = oc.atk_mult()
	_chk("냉각 기본 = 종전 값 유지(mag 0 하위호환)", is_equal_approx(chill_base, float(OS_.MOVE_MULT["Chilled"])))
	_chk("냉각이 공속도 늦춘다", atk_base < 1.0)
	oc.apply("Chilled", 3.0, 1.0)
	_chk("냉각 심화(mag 1) → 이동 더 느려짐", oc.move_mult() < chill_base)
	_chk("냉각 심화(mag 1) → 공속 더 느려짐", oc.atk_mult() < atk_base)
	var oc2 = OS_.new()
	oc2.apply("Frozen", 2.0, 0.0)
	_chk("빙결 = 이동 0", is_equal_approx(oc2.move_mult(), 0.0))
	_chk("빙결 = 공격 0", is_equal_approx(oc2.atk_mult(), 0.0))
	var enf = EN.new()
	root.add_child(enf)
	enf.max_hp = 100.0
	enf.hp = 100.0
	_chk("적: 평시 is_frozen()=false", not enf.is_frozen())
	enf.apply_outcome("Frozen", 2.0)
	_chk("적: 빙결 시 is_frozen()=true(AI 정지 게이트)", enf.is_frozen())
	var base_iv: float = enf.attack_interval_s
	enf.apply_outcome("Chilled", 3.0, 0.0)
	_chk("적: 냉각이 공격 간격을 늘린다", enf.attack_interval_now() > base_iv)
	enf.free()
	# 샌드박스 로드아웃 유효성 — 유저가 체감하는 무대라 여기 목록이 낡으면 슬롯이 조용히 빈다
	# (`equip_skillbook_by_id`가 폐기 AB를 무시). AB-037 폐기 후 DPS/Nuker가 실제로 그랬다.
	var SB = load("res://scripts/dev/combat_sandbox.gd")
	for cls in SB.SANDBOX_SUBS:
		for ab_s in SB.SANDBOX_SUBS[cls]:
			if String(ab_s) == "":
				continue
			_chk("샌드박스 %s 슬롯 %s 실재" % [cls, ab_s], not sd.get_skillbook_master(String(ab_s)).is_empty())

	# H 블록 교정(DRIFT-116) — 힐러 방어 4종을 **대상**으로 갈랐고, 표적 없는 슬롯 2건을 정리했다.
	var h67: Dictionary = sd.get_skillbook_master("AB-067").get("cast", {})
	var h75: Dictionary = sd.get_skillbook_master("AB-075").get("cast", {})
	var h65: Dictionary = sd.get_skillbook_master("AB-065").get("cast", {})
	var h68: Dictionary = sd.get_skillbook_master("AB-068").get("cast", {})
	_chk("AB-067 = 아군 지정(자기중심 아님)", bool(h67.get("targeted", false)) and float(h67.get("range_m", 0.0)) > 0.0)
	_chk("AB-075 = 광역(미지정)", not bool(h75.get("targeted", false)) and float(h75.get("radius_m", 0.0)) > 1.0)
	# 힐러 자기 방어는 **AB-068 하나뿐**이어야 한다 — 067이 자기중심이던 시절엔 둘이었다.
	var self_def := 0
	for ab in ["AB-067", "AB-068", "AB-065", "AB-075"]:
		var cd2: Dictionary = sd.get_skillbook_master(String(ab)).get("cast", {})
		if not bool(cd2.get("targeted", false)) and float(cd2.get("radius_m", 9.0)) <= 1.0:
			self_def += 1
	_chk("힐러 자기 방어 슬롯 = 1개(068)", self_def == 1)
	# tier 서열 = 실성능 서열. 065(흡수+치유 전환)가 최강인데 Basic이고 075가 Master이던 역전을 교정.
	_chk("AB-065 tier=Master(실성능 최강)", String(sd.get_skillbook_master("AB-065").get("tier", "")) == "Master")
	_chk("AB-075 tier!=Master(흡수율 최저)", String(sd.get_skillbook_master("AB-075").get("tier", "")) != "Master")
	_chk("AB-065 흡수율 > AB-075 흡수율", float(h65.get("shield_pct", 0.0)) > float(h75.get("shield_pct", 9.0)))
	_chk("AB-068 = 유일 DR(감소) — 흡수와 방식이 다름", float(h68.get("damage_reduction", 0.0)) > 0.0)
	# **보호막 = 즉응·일시 / 힐 = 사전 대비**(DRIFT-119). 두 계열이 같은 "생존" 축에 있으므로
	# 사용성이 갈리려면 **캐스트·지속**이 반대 방향이어야 한다. 축이 무너지면 여기서 잡힌다.
	var heal_min := 9.9
	var heal_pct_min := 9.9
	for hab in ["AB-064", "AB-066"]:
		var hc: Dictionary = sd.get_skillbook_master(hab).get("cast", {})
		heal_min = minf(heal_min, float(hc.get("cast_s", 0.0)))
		heal_pct_min = minf(heal_pct_min, float(hc.get("heal_pct", 0.0)))
	for sab in ["AB-067", "AB-075", "AB-065"]:
		var sc3: Dictionary = sd.get_skillbook_master(sab).get("cast", {})
		# 즉발이 아니라 **짧은 캐스트** — §0 캐스터 원칙(즉발 최소)을 지키면서 힐보다 빠르다.
		_chk("%s 보호막 cast_s > 0(즉발 아님)" % sab, float(sc3.get("cast_s", 0.0)) > 0.0)
		# 절대 상한(1.5s)과 상대비(힐의 절반 이하)를 **둘 다** 본다 — 상대비만 쓰면 힐 캐스트를
		# 건드릴 때 경계에 걸리고, 절대값만 쓰면 두 계열의 대비가 무너져도 안 잡힌다.
		_chk("%s 보호막 cast <= 1.5s(즉응)" % sab, float(sc3.get("cast_s", 9.9)) <= 1.5)
		_chk("%s 보호막 cast <= 힐 cast(%.1fs)의 1/2" % [sab, heal_min],
			float(sc3.get("cast_s", 9.9)) <= heal_min * 0.5)
		# 일시성 — 오래 남으면 힐과 구분이 사라진다.
		var sdur: float = float(sc3.get("duration_s", sc3.get("ward_s", 99.0)))
		_chk("%s 보호막 지속 <= 3s(곧 사라짐)" % sab, sdur <= 3.0)
	# 흡수는 "힐량과 비슷하거나 조금 많게" — 단일 보호막(067)이 최소 힐량 이상이어야 한다.
	_chk("AB-067 흡수 >= 최소 힐량(%.2f)" % heal_pct_min, float(h67.get("shield_pct", 0.0)) >= heal_pct_min)
	# ⚠️ 흡수 기준 = **대상** max_hp(힐·보호막 공통). 캐스터 기준이면 힐러 HP가 최저라 수치가 거짓말이 된다.
	var wsrc := FileAccess.get_file_as_string("res://scripts/combat/abilities/effects/sb_ward_heal.gd")
	_chk("ward_heal 흡수 기준 = 대상 max_hp", wsrc.contains("target.max_hp") and not wsrc.contains("m.max_hp) * float(p.get(\"shield_pct"))
	# H5 — 침묵은 **광역**으로 밀어 Tank 단일 스턴(AB-011)과 역할을 가른다.
	var h44: Dictionary = sd.get_skillbook_master("AB-044").get("cast", {})
	var t11: Dictionary = sd.get_skillbook_master("AB-011").get("cast", {})
	_chk("AB-044 침묵 반경 > AB-011 스턴 반경(광역 ↔ 단일)",
		float(h44.get("radius_m", 0.0)) > float(t11.get("radius_m", 9.0)))
	_chk("AB-044 침묵 지속 > 스턴 지속", float(h44.get("silence_s", 0.0)) > float(t11.get("stun_s", 9.0)))
	# H6 — AB-101 아군판 폐기 + kind 소멸. 적측은 abilities.json enemy_only로 존치.
	_chk("AB-101 아군판 폐기", sd.get_skillbook_master("AB-101").is_empty())
	_chk("skillbook_scent kind 소멸", not kinds.has("skillbook_scent"))
	_chk("AB-101 적측 존치(enemy_only)", bool(sd.get_ability("AB-101").get("enemy_only", false)))
	# H7 — haste는 "오오라류는 길게"(T2 판정) 기준. DR 하한(6s)과 같은 잣대.
	_chk("AB-069 haste 지속 >=8s(오오라 기준)",
		float(sd.get_skillbook_master("AB-069").get("cast", {}).get("duration_s", 0.0)) >= 8.0)
	# H7 — 죽은 스키마(castTier/rootDuringCast/telegraph_s) 전수 0. AB-045가 마지막이었다.
	for ab in sd._registry_list("ability_ids"):
		var md: Dictionary = sd.get_skillbook_master(String(ab))
		if md.is_empty():
			continue
		var cs2: Dictionary = md.get("cast", {})
		_chk("%s 죽은 스키마 없음" % ab,
			not cs2.has("castTier") and not cs2.has("rootDuringCast") and not cs2.has("telegraph_s"))
	# H7 — purge 재정의: 아군 정화가 본체(적 강화 제거는 폴백).
	var pmp = PM.new()
	root.add_child(pmp)
	_chk("정화: 지울 게 없으면 빈 문자열", String(pmp.cleanse_debuff()) == "")
	pmp.apply_outcome("Chilled", 3.0)
	_chk("정화 전 냉각 보유", pmp.has_outcome("Chilled"))
	_chk("정화: 디버프 1건 제거", String(pmp.cleanse_debuff()) != "")
	_chk("정화 후 냉각 해제", not pmp.has_outcome("Chilled"))
	# 강화(buff)는 지우지 않는다 — 아군 haste를 힐러가 지우면 안 된다.
	pmp.apply_haste(0.2, 5.0)
	_chk("정화: 강화는 안 지운다", String(pmp.cleanse_debuff()) == "" and pmp.has_outcome("Hastened"))
	pmp.free()

	# 적 외형 구분(DRIFT-118) — 색만으로는 안 갈린다(부감·안개·색각). 특성에서 실루엣·표식을 파생한다.
	var UV = load("res://scripts/core/unit_visuals.gd")
	var seen_colors := {}
	var crest_by_role := {}
	for eid4 in sd.get_enemy_ids():
		var row4: Dictionary = sd.get_enemy_row(String(eid4))
		var vis4: Dictionary = UV.enemy_visual(String(eid4), row4)
		_chk("%s 외형 shape 유효" % eid4, ["box", "column"].has(String(vis4.get("shape", ""))))
		_chk("%s 외형 scale>0" % eid4, float(vis4.get("scale", 0.0)) > 0.0)
		seen_colors[str(vis4["color"])] = true   # Color엔 String() 생성자가 없다 — str() 사용
		crest_by_role[String(row4.get("role", ""))] = String(vis4.get("crest", ""))
		# 원거리 유닛은 기둥, 근접은 박스 — 실루엣이 교전 거리를 말해야 한다.
		var reach4 := float((row4.get("stats", {}) as Dictionary).get("attack_range_m", 1.6))
		_chk("%s 실루엣 = 교전거리(%.1fm)" % [eid4, reach4],
			String(vis4["shape"]) == ("column" if reach4 > UV.MELEE_RANGE_M else "box"))
	# **12종이 같은 갈색 박스**이던 문제 — 고유 색이 유닛 수에 가깝게 나와야 한다.
	_chk("적 색상 고유값 >= 유닛 수의 80%%", seen_colors.size() >= int(float(sd.get_enemy_ids().size()) * 0.8))
	# 역할 표식 — 위협 우선순위가 실루엣으로 읽혀야 한다. fodder는 **표식 없음이 곧 정보**.
	for r4 in ["support", "nuker", "cc", "elite"]:
		if crest_by_role.has(r4):
			_chk("%s 역할 표식 有" % r4, String(crest_by_role[r4]) != "")
	if crest_by_role.has("fodder"):
		_chk("fodder 표식 없음(그 자체가 정보)", String(crest_by_role["fodder"]) == "")
	_chk("볼트 계열 slag 소멸", not elems.has("slag"))
	# D1+D2 병합(DRIFT-111) — 속성 전용 kind가 볼트로 흡수되고 즉발 쌍둥이·신설 중복이 폐기됐다.
	for gone in ["AB-107", "AB-108", "AB-037", "AB-072"]:
		_chk("%s 폐기(병합 중복/즉발 쌍둥이)" % gone, sd.get_skillbook_master(gone).is_empty())
	for moved in ["AB-053", "AB-041"]:
		_chk("%s kind=skillbook_bolt(흡수)" % moved,
			String(sd.get_skillbook_master(moved).get("cast", {}).get("kind", "")) == "skillbook_bolt")
	_chk("skillbook_fire kind 소멸", not kinds.has("skillbook_fire"))
	_chk("skillbook_cold kind 소멸", not kinds.has("skillbook_cold"))

	# 매질 이관(DRIFT-112) — 아군 매질 스킬 5종 폐기 → 소모품. 적은 enemy_only로 존치.
	for z in ["AB-009", "AB-036", "AB-040", "AB-042", "AB-043"]:
		_chk("%s 아군 서브 폐기" % z, sd.get_skillbook_master(z).is_empty())
		_chk("%s 적 능력 존치 + enemy_only" % z, bool(sd.get_ability(z).get("enemy_only", false)))
	_chk("skillbook_zone kind 소멸", not kinds.has("skillbook_zone"))
	for fl in ["con_oil_flask", "con_water_flask", "con_frost_flask", "con_gust_flask", "con_briar_flask"]:
		var cm: Dictionary = sd.get_consumable_master(fl)
		_chk("%s 해소 + spawn_medium" % fl, not cm.is_empty() and String(cm.get("effect", "")) == "spawn_medium")
		_chk("%s medium/ttl 보유" % fl, String(cm.get("medium", "")) != "" and float(cm.get("ttl_s", 0.0)) > 0.0)
	# 가시덩굴 — 이동 거리 비례 피해(서 있으면 무피해·틱 상한).
	var HZ = load("res://scripts/world/hazards/hazard_zone.gd")
	var probe := Node3D.new()
	root.add_child(probe)
	probe.global_position = Vector3.ZERO
	var r0: Array = HZ.thorn_damage(probe, null)
	_chk("가시: 첫 틱은 무피해(기준 위치만 저장)", is_equal_approx(float(r0[0]), 0.0))
	var r1: Array = HZ.thorn_damage(probe, Vector3.ZERO)
	_chk("가시: 정지 시 무피해", is_equal_approx(float(r1[0]), 0.0))
	probe.global_position = Vector3(1.0, 0.0, 0.0)
	var r2: Array = HZ.thorn_damage(probe, Vector3.ZERO)
	_chk("가시: 1m 이동 = DMG_PER_M", is_equal_approx(float(r2[0]), HZ.THORN_DMG_PER_M))
	# 상한 없음(사용자 확정) — 돌진·넉백으로 크게 움직이면 그만큼 크게 아프다(창의적 사용을 여는 축).
	probe.global_position = Vector3(8.0, 0.0, 0.0)
	var r3: Array = HZ.thorn_damage(probe, Vector3.ZERO)
	_chk("가시: 8m 돌진 = 선형 8×DMG_PER_M(상한 없음)", is_equal_approx(float(r3[0]), 8.0 * HZ.THORN_DMG_PER_M))
	# 피해 표기 — 매질 틱(0.2s)마다가 아니라 **DoT와 같은 0.5s 리듬**으로 모아서 올린다.
	var pacc := {}
	HZ.thorn_popup(probe, 2.0, 0.2, pacc)
	_chk("가시 표기: 주기 전에는 누적만", is_equal_approx(float((pacc[probe] as Array)[0]), 2.0))
	HZ.thorn_popup(probe, 2.0, 0.2, pacc)
	HZ.thorn_popup(probe, 2.0, 0.2, pacc)   # 누적 0.6s ≥ 0.5s → 플러시
	_chk("가시 표기: 주기 도달 시 리셋(플러시)", is_equal_approx(float((pacc[probe] as Array)[1]), 0.0))
	_chk("가시 표기 주기 = DoT 리듬", is_equal_approx(HZ.THORN_POPUP_S, 0.5))
	probe.free()

	# T4b 판정(DRIFT-109) — AB-050 둔화 폐기 · AB-102 = DPS 「원거리 광역 뭉치기+속박」 콤보 셋업.
	_chk("AB-050 폐기", sd.get_skillbook_master("AB-050").is_empty())
	var m102: Dictionary = sd.get_skillbook_master("AB-102")
	var c102: Dictionary = m102.get("cast", {})
	_chk("AB-102 = DPS 주력 전용", (m102.get("equip_classes", []) as Array) == ["DPS"])
	_chk("AB-102 sub_bands 없음(Nuker 미부여)", (m102.get("sub_bands", {}) as Dictionary).is_empty())
	_chk("AB-102 gather_m > 0 (뭉치기)", float(c102.get("gather_m", 0.0)) > 0.0)
	# 콤보 성립 조건: 속박이 DPS 주력 광역기의 **최장 캐스트 + 투사체 비행**을 덮어야 한다.
	var max_dps_cast := 0.0
	for ab in sd._registry_list("ability_ids"):
		var mm: Dictionary = sd.get_skillbook_master(String(ab))
		if mm.is_empty():
			continue
		var eqc: Array = mm.get("equip_classes", [])
		var cc2: Dictionary = mm.get("cast", {})
		if eqc.has("DPS") and not (mm.get("sub_bands", {}) as Dictionary).has("DPS") 				and float(cc2.get("damage_mult", 0.0)) > 0.0:
			max_dps_cast = maxf(max_dps_cast, float(cc2.get("cast_s", 0.0)))
	_chk("AB-102 속박 ≥ DPS 최장 광역기 캐스트(%.1fs) + 비행" % max_dps_cast,
		float(c102.get("root_s", 0.0)) >= max_dps_cast + 0.4)
	# ccTenacity 드리프트 수정 — 하드 CC outcome도 저항을 받는다(EFFECT-CORE 규약).
	var tough = EN.new()
	tough.cc_tenacity = 2.0
	tough.hp = 100.0
	tough.apply_outcome("Rooted", 4.0)
	_chk("Rooted가 ccTenacity 적용(4.0 → 2.0)", is_equal_approx(tough._outcome._t.get("Rooted", 0.0), 2.0))
	tough.apply_outcome("Chilled", 3.0)
	_chk("soft 아웃컴은 지속 그대로(Chilled 3.0)", is_equal_approx(tough._outcome._t.get("Chilled", 0.0), 3.0))
	tough.free()

	# T4 판정(DRIFT-108) — AB-051 견인 → **원거리 단일 도발**(Tank 전용). AB-035와 사거리·위협으로 분화.
	var c51: Dictionary = sd.get_skillbook_master("AB-051").get("cast", {})
	var c35: Dictionary = sd.get_skillbook_master("AB-035").get("cast", {})
	_chk("AB-051 kind=skillbook_taunt", String(c51.get("kind", "")) == "skillbook_taunt")
	_chk("AB-051 pull 잔재 없음", not c51.has("pull_m"))
	_chk("AB-051 = Tank 전용", (sd.get_skillbook_master("AB-051").get("equip_classes", []) as Array) == ["Tank"])
	_chk("AB-051 sub_bands 없음(겸용 해제)", (sd.get_skillbook_master("AB-051").get("sub_bands", {}) as Dictionary).is_empty())
	_chk("AB-051 사거리 > AB-035", float(c51.get("range_m", 0.0)) > float(c35.get("range_m", 0.0)))
	_chk("AB-051 위협 < AB-035(사거리 대가)", float(c51.get("mark_threat", 0.0)) < float(c35.get("mark_threat", 0.0)))
	# 축 확정: AB-035 = 광역 + 캐스트 커밋 / AB-051 = 단일 + 즉발 원거리.
	_chk("AB-035 = 광역 도발(taunt_all)", bool(c35.get("taunt_all", false)))
	_chk("AB-035 = 캐스트 커밋 2.5s", is_equal_approx(float(c35.get("cast_s", 0.0)), 2.5))
	_chk("AB-051 = 단일(taunt_all 없음)", not bool(c51.get("taunt_all", false)))
	_chk("AB-051 = 즉발(cast_s 없음)", float(c51.get("cast_s", 0.0)) == 0.0)
	_chk("AB-035 반경 > AB-051(광역이 실제로 넓다)", float(c35.get("radius_m", 0.0)) > float(c51.get("radius_m", 0.0)))
	_chk("skillbook_pull 폐기(사용자 0)", sd.get_skillbook_master("AB-051").get("cast", {}).get("kind", "") != "skillbook_pull")

	# 도발이 **비전투 적을 교전으로 끌어내는지**(DRIFT-108) — 위협 수치만 올리면 dormant 적은 안 온다.
	var tn = EN.new()      # 트리 불요 — add_threat/perceive_attacker/pick_target은 순수 상태 조작
	var tk = PM.new()
	tn.engaged = false
	tn.returning = true
	tn.add_threat(tk, 90.0)
	_chk("add_threat만으로는 교전 안 됨(원인)", not tn.engaged)
	tn.perceive_attacker(tk)          # sb_taunt가 부르는 경로
	tn.returning = false
	_chk("도발 → 교전 상태 진입", tn.engaged)
	_chk("도발 → 귀환 취소", not tn.returning)
	_chk("도발 → 시전자 위치로 수색(LOS 없어도 이동)", tn.has_search)
	_chk("도발 대상 = 최고 위협(시전자)", tn.pick_target([tk], 1.2) == tk)
	tn.free()
	tk.free()

	# T3 판정(DRIFT-107) — AB-033 = shield → **전방위 돔 방벽**(물리 오브젝트). AB-034 벽과 형상·차단축이 갈린다.
	var c33: Dictionary = sd.get_skillbook_master("AB-033").get("cast", {})
	var c34: Dictionary = sd.get_skillbook_master("AB-034").get("cast", {})
	_chk("AB-033 kind=skillbook_barrier(실드 아님)", String(c33.get("kind", "")) == "skillbook_barrier")
	_chk("AB-033 shape=dome", String(c33.get("shape", "")) == "dome")
	_chk("AB-033 shield_pct 잔재 없음", not c33.has("shield_pct"))
	_chk("AB-034 = wall(기본형)", String(c34.get("shape", "wall")) == "wall")
	_chk("돔 HP << 벽 HP", float(c33.get("barrier_hp", 0.0)) > 0.0 and float(c33.get("barrier_hp", 0.0)) < float(c34.get("barrier_hp", 0.0)) * 0.5)
	# 레이어 분리 — 돔은 엄폐 전용(8)이라 이동을 막지 않고, 벽은 world(1)이라 이동까지 막는다.
	var RBar = load("res://scripts/world/objects/rampart_barrier.gd")
	var vfx_host := Node3D.new()
	root.add_child(vfx_host)
	var dome = RBar.new()
	root.add_child(dome)
	dome.setup(null, Vector3.ZERO, Vector3(0, 0, 1), {"shape": "dome", "radius_m": 3.0, "barrier_hp": 90.0, "duration_s": 5.0}, vfx_host)
	_chk("돔 = 엄폐 레이어(LAYER_COVER 8 — 이동 비차단)", dome.collision_layer == RBar.LAYER_COVER)
	_chk("돔이 유닛 이동 마스크(1)에 없음", (dome.collision_layer & 1) == 0)
	var wall = RBar.new()
	root.add_child(wall)
	wall.setup(null, Vector3(20, 0, 20), Vector3(0, 0, 1), {"barrier_hp": 300.0, "duration_s": 4.0, "stagger_s": 0.0}, vfx_host)
	_chk("벽 = world 레이어 1(이동 차단)", wall.collision_layer == 1)
	# ⚠️ 물리 space query 검증은 **넣지 않는다** — `--script` SceneTree 런에서 콜리전 등록 타이밍이
	# 불안정했다(process_frame로는 미등록, physics_frame await는 무한 대기). 별도 임시 스크립트로
	# 수동 실증은 마쳤다: 마스크 `1|8` 레이는 돔 표면(2.89, 0.8, 0)에 적중, 마스크 `1`은 통과.
	# 여기서는 레이어 상수 + 커버리지 수식만 잠근다(결정론적).
	# 완전 포함 판정(DRIFT-107) — 중심부는 보호, 가장자리에 걸치면 그대로 맞는다.
	_chk("돔 중심 = 완전 보호", dome.covers_point(Vector3.ZERO))
	var sr: float = dome.safe_radius()
	_chk("안전 반경 < 돔 외곽(걸침 구간 존재)", sr > 0.0 and sr < 3.0)
	_chk("안전 반경 안쪽 = 보호", dome.covers_point(Vector3(sr - 0.15, 0.0, 0.0)))
	_chk("안전 반경 바깥(돔 안이어도) = 미보호", not dome.covers_point(Vector3(sr + 0.25, 0.0, 0.0)))
	_chk("돔 밖 = 미보호", not dome.covers_point(Vector3(4.0, 0.0, 0.0)))
	_chk("벽은 방향성 엄폐(covers_point 항상 true)", wall.covers_point(Vector3(99, 0, 99)))
	print("      [dome] r=3.0 · 안전 반경 %.2fm (유닛 r0.40 · h1.60 기준)" % sr)
	# 투사체 흡수 → HP 감소 → Break. (근접 적은 방벽을 때리지 않는다 — DRIFT-107 §확인 결과)
	for _i in 9:
		if is_instance_valid(dome):
			dome.absorb_projectile()
	await process_frame
	_chk("돔 = 투사체 9발(90 HP)에 파괴", not is_instance_valid(dome))
	if is_instance_valid(wall):
		wall.queue_free()
	vfx_host.queue_free()

	# 지속형 오오라(DRIFT-106) — 스폰 · 같은 key 재시전 시 교체(중복 링 방지) · 지속 후 자기 소멸.
	var SV = load("res://scripts/combat/abilities/skill_vfx.gd")
	var host := Node3D.new()
	root.add_child(host)
	SV.aura_field(host, 0.9, Color(1.0, 0.86, 0.35), 0.25, "dr_test")
	_chk("오오라 생성", _aura_count(host) == 1)
	SV.aura_field(host, 0.9, Color(1.0, 0.86, 0.35), 0.25, "dr_test")   # 재시전 = 기존 교체
	await process_frame
	_chk("같은 key 재시전 = 링 교체(중복 없음)", _aura_count(host) == 1)
	var waited := 0
	while _aura_count(host) > 0 and waited < 240:
		await process_frame
		waited += 1
	_chk("지속 종료 후 자기 소멸", _aura_count(host) == 0)
	SV.aura_field(host, 0.9, Color(1.0, 0.86, 0.35), 5.0, "dr_test")
	SV.clear_aura(host, "dr_test")
	await process_frame
	_chk("clear_aura 즉시 제거", _aura_count(host) == 0)
	host.free()

	# 반격 게이트(DRIFT-104) — 048b는 **캐스팅 스킬 피격만** 반사하고 평타는 무시. 반사해도 내 피해는 그대로.
	var pmr = PM.new()
	root.add_child(pmr)
	var dummy = EN.new()
	root.add_child(dummy)
	dummy.max_hp = 500.0
	dummy.hp = 500.0
	pmr.max_hp = 400.0
	pmr.hp = 400.0
	pmr.apply_reflect(0.8, 6.0, 60.0, 2, true, "응수")
	pmr.take_damage(20.0, dummy, false)             # 평타 → 반사 없음
	_chk("응수: 평타는 반사 안 함", is_equal_approx(dummy.hp, 500.0))
	_chk("응수: 평타 피해는 그대로 들어옴", is_equal_approx(pmr.hp, 380.0))
	pmr.take_damage(20.0, dummy, true)              # 캐스팅 스킬 → 16 반사
	_chk("응수: 캐스팅 스킬은 반사(0.8×20)", is_equal_approx(dummy.hp, 484.0))
	_chk("응수: 반사해도 내 피해는 그대로", is_equal_approx(pmr.hp, 360.0))
	# 반격 오오라(DRIFT-106) — 타수가 소진되면 창 시간이 남아도 `_end_reflect`가 즉시 끈다.
	SV.aura_field(pmr, 1.0, Color(1.0, 0.5, 0.2), 6.0, "reflect", 8)   # 반격 = 가시 8개
	_chk("반격 오오라 부착", _aura_count(pmr) == 1)
	# 고슴도치 가시 — 링·돔 외 quills 컨테이너가 붙고 그 안에 가시 8개.
	var aura_root: Node = null
	for ch in pmr.get_children():
		if ch.has_meta("aura_key"):
			aura_root = ch
	var quill_n := 0
	if aura_root != null:
		for ch in aura_root.get_children():
			if ch.get_child_count() > 0:
				quill_n = ch.get_child_count()
	_chk("반격 오오라 = 가시 8개", quill_n == 8)
	pmr.take_damage(20.0, dummy, true)              # 2타째 → 소진 → _end_reflect → clear_aura
	await process_frame
	_chk("타수 소진 시 오오라 즉시 제거(창 시간 남아도)", _aura_count(pmr) == 0)
	# ⚠️ **시그니처 파리티** — enemy_ai는 대상 진영을 가리지 않고 `take_damage(dmg, attacker, from_ab)`
	# 3인자로 부른다. 적↔적 피격은 **진영전에서만** 열리는 경로라, 인자 수가 갈리면 그 조우가 뜬 판에서만
	# 런타임 에러가 난다(로컬 게이트는 통과하는데 CI만 실패 — 31058027571). 선언을 직접 비교해
	# 타이밍과 무관하게 고정한다. 인자 수가 갈리는 변경은 여기서 먼저 막힌다. ref: DRIFT-104.
	_chk("take_damage 시그니처 파리티(party ↔ enemy)", _argc(pmr, "take_damage") == 3 and _argc(dummy, "take_damage") == 3)
	dummy.take_damage(0.0, null, true)   # 3인자 실호출 — 선언만 맞고 호출이 깨지는 경우까지 잡는다
	pmr.free()
	dummy.free()

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
	_chk("veil 기본 = 평타 유지", not pm.holds_fire())      # hold_fire 미지정 = 종전 이탈용 은신(잠행 처치 은신 등)
	pm.apply_veil(1.5, true)
	_chk("veil hold_fire = 평타 정지", pm.holds_fire())     # AB-062 오프너 경로
	# next-hit 곱누산(DRIFT-121) — maxf였다면 0.3이 2.0에 통째로 먹혀 ×3.0이 나온다. 곱이면 1.3×3.0=×3.9.
	pm.grant_next_hit_bonus(0.3)
	pm.grant_next_hit_bonus(2.0)
	_chk("next-hit 곱누산 (1.3×3.0=3.9)", is_equal_approx(1.0 + pm.consume_next_hit_bonus(), 3.9))
	_chk("next-hit 1회만 소비", is_equal_approx(pm.consume_next_hit_bonus(), 0.0))
	pm.break_veil()
	_chk("break_veil = 은신·평타정지 동시 해제", not pm.is_veiled() and not pm.holds_fire())
	pm.free()

	# 「오프너 은신」 능동 취소(DRIFT-121 b) — 은신 중 은신 스킬 재입력 = 토글 오프. **쿨 중에도** 먹혀야
	# 한다(시전 쿨 14s < 은신 60s라 취소가 필요한 구간 대부분이 쿨 중) → 차지·쿨 게이트보다 앞이라는
	# 배치 자체가 검증 대상이다. cd/차지를 일부러 채워 두고 눌러, 게이트에 먼저 걸리면 실패로 잡는다.
	# ── 누커 화력 재조정(DRIFT-123) ──────────────────────────────────────────────
	# **목표 바닥선(사용자 확정): 은신 증폭(×3.0)을 실은 최대딜이 일반몹 상한(fodder 240)을 한 방에 죽인다.**
	# 이 한 줄이 이번 튜닝의 존재 이유라 게이트로 건다 — 배율·평타·은신 배수 셋 중 **아무거나** 나중에
	# 내려가면 목표가 조용히 깨지는데, 세 값이 서로 다른 파일에 있어 눈으로는 절대 못 잡는다.
	var starter_ba := 0.0
	for idr in sd.get_identity_rows():
		if String((idr as Dictionary).get("identity_skill_id", "")) == "nuker_mark_ruin":
			starter_ba = float((idr as Dictionary).get("combat", {}).get("basic_damage", 0.0))
	var veil_mult: float = 1.0 + float(sd.get_skillbook_master("AB-062").get("cast", {}).get("next_hit_bonus", 0.0))
	var top_mult: float = float(sd.get_skillbook_master("AB-059").get("cast", {}).get("damage_mult", 0.0))
	var FODDER_CAP := 240.0   # EN-012(500)는 이상치로 제외 — DRIFT-123 부수 발견
	_chk("스타터 누커 평타 위력 확인(%.0f)" % starter_ba, starter_ba > 0.0)
	_chk("은신 최대딜 %.0f >= 일반몹 상한 240" % (top_mult * starter_ba * veil_mult),
		top_mult * starter_ba * veil_mult >= FODDER_CAP)
	# 배율을 올린 만큼 쿨로 갚는다 — 상향 10종이 저쿨로 남으면 "무거운 한 방"이 아니라 그냥 상향이 된다.
	for ab in ["AB-059", "AB-073", "AB-005", "AB-058", "AB-004", "AB-013", "AB-106", "AB-056", "AB-100"]:
		var cb2: Dictionary = sd.get_skillbook_master(String(ab)).get("cast", {})
		_chk("%s 상향분 = 쿨 >= 9s" % ab, float(cb2.get("cooldown_s", 0.0)) >= 9.0)
	# 유틸은 딜러가 아니다 — 제어기 배율을 같이 올리면 N3·N5 클러스터 분화(제어 ↔ 피해)가 무너진다.
	var min_dealer: float = float(sd.get_skillbook_master("AB-056").get("cast", {}).get("damage_mult", 0.0))
	for ab in ["AB-030", "AB-103"]:
		_chk("%s 유틸 = 최소 딜러(%.1f)보다 낮음" % [ab, min_dealer],
			float(sd.get_skillbook_master(String(ab)).get("cast", {}).get("damage_mult", 9.0)) < min_dealer)

	# ── 이름·ID 위생(DRIFT-134) ─────────────────────────────────────────────────
	# ① 표시명은 **전부 한글**(사용자 확정). 영문이 섞이면 한글 UI에 영문 스킬명이 리 상태로 굳는다.
	#    스펙 `displayName`은 영문 카탈로그로 남으므로 **이 축은 전파 대조에서 제외**된다.
	var name_bad: Array = []
	var name_dup := {}
	for row in sd.get_skillbook_rows():
		var mn2: Dictionary = row
		var ab := String(mn2.get("base_ability_id", ""))
		var nm := String(mn2.get("display_name", ""))
		var has_ko := false
		for ch in nm:
			if ch >= "가" and ch <= "힣":
				has_ko = true
				break
		if not has_ko:
			name_bad.append(ab)
		if name_dup.has(nm):
			name_bad.append("%s(중복명 %s)" % [ab, nm])
		name_dup[nm] = true
	_chk("표시명 전부 한글 · 중복 없음 (%s)" % ("ok" if name_bad.is_empty() else str(name_bad)), name_bad.is_empty())
	# ② kind 라벨 = 그 스킬이 거는 상태 라벨. 어긋나면 「포박」처럼 한 단어가 둘을 가리킨다(DRIFT-134).
	var KIND_STATUS_KO := {"skillbook_pin": "고정", "skillbook_tether": "포박",
		"skillbook_root": "속박", "skillbook_haste": "가속"}
	for k in KIND_STATUS_KO:
		_chk("%s 라벨 = 상태 라벨(%s)" % [k, KIND_STATUS_KO[k]],
			sd.get_effect_label(String(k)) == String(KIND_STATUS_KO[k]))
	# ③ 번호 1~111이 **4분류로 빈틈없이 덮이는가** — 구현 / 미구현 백로그 / 영구 결번 / IDA 이관.
	#    "왜 비었지?"를 남기지 않는 것이 이 표들의 존재 이유다. 게이트를 처음 돌렸을 때 **미구현 17종을
	#    결번으로 잘못 묶은 내 분류 오류가 여기서 잡혔다** — 덮개 검사라 분류 자체의 오류도 걸린다.
	var regsrc := FileAccess.get_file_as_string("res://data/slice01/id_registry.json")
	var reg: Dictionary = JSON.parse_string(regsrc)
	var gaps: Dictionary = reg.get("ability_id_gaps", {})
	var have := {}
	for ab in (reg.get("ability_ids", []) as Array):
		var mm := (String(ab) as String).substr(3, 3)
		if mm.is_valid_int():
			have[int(mm)] = true
	var uncovered: Array = []
	for n in range(1, 112):
		if have.has(n):
			continue
		var key := "AB-%03d" % n
		if not gaps.has(key) and not (reg.get("ability_ids_pending", []) as Array).has(key):
			uncovered.append(key)
	_chk("번호 1~111 전수 분류 (미분류 %s)" % str(uncovered), uncovered.is_empty())
	_chk("ID 재사용 금지 규약 명시", String(reg.get("_note_ability_id_policy", "")).contains("재사용 금지"))

	# ── N5 재정의: AB-030 인터럽트 → 침묵 「제압」(DRIFT-133) ───────────────────
	# 실측이 판정을 뒤집었다 — 적이 쓰는 27종의 telegraph가 0.2~1.0s에 몰려 있어 cast 1.0짜리
	# 인터럽트로 끊을 수 있는 건 **AB-012 단 1종**이었다. 이름만 인터럽트였다.
	# 침묵은 **진행 중 시전을 끊지 않고 새 시전만 막는다** → "끊는다"가 아니라 "제압한다".
	var c030: Dictionary = sd.get_skillbook_master("AB-030").get("cast", {})
	_chk("AB-030 = 침묵 kind", String(c030.get("kind", "")) == "skillbook_silence")
	_chk("AB-030 stun 잔재 없음", not c030.has("stun_s"))
	_chk("AB-030 침묵 지속 > 0", float(c030.get("silence_s", 0.0)) > 0.0)
	# 「타격 후 침묵」이라 피해가 함께 있어야 한다 — 무피해면 AB-044(광역 봉인)와 형태가 겹친다.
	_chk("AB-030 타격 동반(damage_mult > 0)", float(c030.get("damage_mult", 0.0)) > 0.0)
	_chk("AB-030 단일 잠금", bool(c030.get("single_target", false)))
	# 2변주가 실제로 갈리는지 — 044는 광역·무피해, 030은 단일·타격.
	var c044: Dictionary = sd.get_skillbook_master("AB-044").get("cast", {})
	_chk("AB-044 = 광역 무피해(변주 대비)",
		not bool(c044.get("single_target", false)) and float(c044.get("damage_mult", 0.0)) <= 0.0)
	# 침묵이 실제로 시전을 막는 경로가 살아 있는지(적 AI 게이트).
	var aisrc2 := FileAccess.get_file_as_string("res://scripts/combat/enemy_ai.gd")
	_chk("적 AI가 침묵으로 캐스트를 막는다", aisrc2.contains("is_silenced()"))
	# 침묵이 **진행 중인 시전도** 끊는다(사용자 추가) — 새 시전 차단만으로는 "얻어걸리는 보너스"가 없다.
	_chk("침묵이 진행 중 시전을 끊는다", aisrc2.contains("if enemy.is_silenced() and enemy.winding:"))
	# 인터럽트 역할은 스턴(AB-011 Tank)이 계속 진다 — 누커에서 빠진 자리가 비지 않았는지.
	_chk("인터럽트 담당 = AB-011 스턴 존치",
		String(sd.get_skillbook_master("AB-011").get("cast", {}).get("kind", "")) == "skillbook_stun")

	# ── N3 콤보 복원: Tethered 실동작 · ON-KILL-FEED(DRIFT-132) ─────────────────
	# `Tethered`는 **아무 기제도 없는 표시용 배지**였다(MOVE_MULT·ATK_MULT·CC_TENACITY 어디에도 없고
	# leash 판정도 없었다). 스킬의 페이로드 전체가 없던 것이라 "툴팁만 참"인 상태였다.
	# 상태 자체를 런타임으로 돌려 **leash 안=무해 / 밖=피해+끌림**이 실제로 갈리는지 본다.
	var os1 = OS_.new()   # OS_ = 위(§냉각)에서 이미 로드한 outcome_status.gd
	var anchor := Node3D.new()
	root.add_child(anchor)
	anchor.global_position = Vector3.ZERO
	os1.apply_tether(4.0, anchor, 8.0, 3.0, 2.5)
	_chk("Tethered 부여됨", os1.has("Tethered"))
	# leash 안(3m) — 위치 속박이라 **아무 일도 없어야** 한다(감속·피해 0). AB-050 slow와의 차이축.
	var d_in := 0.0
	for i in 8:
		d_in += os1.tick(0.25, Vector3(3, 0, 0))
	_chk("leash 안 = 피해 0", is_equal_approx(d_in, 0.0))
	_chk("leash 안 = 끌림 0", os1.tether_pull().length() < 0.001)
	_chk("Tethered는 이동 감속이 아니다(위치 속박)", is_equal_approx(os1.move_mult(), 1.0))
	# leash 밖(12m) — 0.5s 리듬으로 3dps → 틱당 1.5. 끌림은 anchor 방향(−x).
	var os2 = OS_.new()
	os2.apply_tether(4.0, anchor, 8.0, 3.0, 2.5)
	var d_out := 0.0
	for i in 4:
		d_out += os2.tick(0.25, Vector3(12, 0, 0))
	_chk("leash 밖 = break DoT 들어감(%.2f)" % d_out, d_out > 0.0)
	var pull: Vector3 = os2.tether_pull()
	_chk("끌림 방향 = 시전자 쪽", pull.x < 0.0 and absf(pull.z) < 0.001)
	# anchor가 사라지면(시전자 사망) 조용히 멈춘다 — 죽은 참조로 피해가 계속되면 안 된다.
	anchor.queue_free()
	_chk("AB-103 leash 파라미터 실재",
		float(sd.get_skillbook_master("AB-103").get("cast", {}).get("leash_m", 0.0)) > 0.0
		and float(sd.get_skillbook_master("AB-103").get("cast", {}).get("tether_dps", 0.0)) > 0.0)
	# 적측 파리티 — 같은 AB가 진영에 따라 다른 스킬이 되면 안 된다(DRIFT-124).
	var e103: Dictionary = sd.get_ability("AB-103")
	for k in ["leash_m", "tether_dps", "tether_s"]:
		_chk("AB-103 %s 진영 파리티" % k,
			is_equal_approx(float(e103.get(k, -1.0)),
				float(sd.get_skillbook_master("AB-103").get("cast", {}).get(k, -2.0))))
	# ON-KILL-FEED — 처치 보상이 회복만이고 쿨 환급이 없으면 「다음 먹이로 연쇄」가 성립하지 않는다.
	var c106: Dictionary = sd.get_skillbook_master("AB-106").get("cast", {})
	_chk("AB-106 on_kill 회복 + 쿨 환급 둘 다",
		float(c106.get("on_kill_heal_pct", 0.0)) > 0.0 and float(c106.get("on_kill_cd_refund", 0.0)) > 0.0)
	_chk("AB-106 쿨 환급 < 전액(무한 연발 방지)", float(c106.get("on_kill_cd_refund", 1.0)) < 1.0)
	# 환급은 효과가 직접 못 깎는다 — `cast_s>0`은 해소 **뒤** 쿨을 덮어쓰므로 보고 채널이어야 한다.
	var adsrc2 := FileAccess.get_file_as_string("res://scripts/combat/abilities/ability_dispatch.gd")
	_chk("쿨 환급 = 보고 채널(덮어쓰기 뒤 적용)", adsrc2.contains("cd * (1.0 - _cd_refund_frac)"))

	# ── range_band ↔ 실사거리 정합(DRIFT-131) ───────────────────────────────────
	# `range_band`는 표기가 아니라 **잠행 결속(IDA-029)의 보상 계수를 정하는 실효 필드**다
	# (`FLANK.band_dmg` Melee 0.15 / Mid 0.25 / Long 0.5 · `band_cd` 0 / 0.10 / 0.20).
	# 밴드가 실사거리와 어긋나면 **"10m에서 쏘는데 근접이라 보상은 최소"** 처럼 조용히 손해를 본다 —
	# AB-106이 정확히 그랬다. 계수를 구동하는 건 잠행뿐이라 **누커 장착 가능 스킬만** 검사한다
	# (Tank 전용 AB-035는 밴드가 아무것도 구동하지 않아 대상 밖).
	# **`Melee` = 근접 교전 거리**(DRIFT-136). 두 형태를 **둘 다** 받는다:
	#   ① 자기중심(`range_m` 없음) — 현재 8종이 이 형태다.
	#   ② 조준 근접(`range_m` ≤ MELEE_MAX) — **근접 단일 공격**처럼 앞으로 들어올 형태.
	# ⚠️ DRIFT-135에서 실물 8/9가 자기중심인 것만 보고 **「Melee = 자기중심」으로 과교정**했었다.
	#    그러면 근접 단일이 들어올 자리가 없어진다(사용자 지적) — 확장성을 막는 규약이었다.
	# 상한 4.0은 **실측에서 유도**: 파티 근접 평타 최대 3.5(tank beacon_hook) · 잠행 강제 근접 2.8 ·
	#    적 근접 평타 최대 2.0. 그 다음 사거리 값이 **7.0**이라 3.5~7.0 사이에 실물이 없다 → 경계가 안전하다.
	const MELEE_MAX := 4.0
	var BAND_RANGE := {"Mid": [4.0, 12.0], "Long": [10.0, 9999.0]}
	var band_n := 0
	for ab in sd._registry_list("ability_ids"):
		var mb: Dictionary = sd.get_skillbook_master(String(ab))
		if mb.is_empty():
			continue
		var bd := String(mb.get("range_band", ""))
		var rm = mb.get("cast", {}).get("range_m")
		# ① Melee = 근접 교전 거리 — 자기중심이거나 사거리가 MELEE_MAX 이내(전 클래스 적용).
		if bd == "Melee":
			band_n += 1
			_chk("%s Melee = 근접(자기중심 or <= %.1fm)" % [ab, MELEE_MAX],
				rm == null or float(rm) <= MELEE_MAX)
			continue
		# ② Mid/Long은 실사거리와 정합해야 한다 — 밴드가 잠행 결속 계수를 구동하므로 누커 장착분만.
		if rm == null or not BAND_RANGE.has(bd):
			continue
		if not (mb.get("equip_classes", []) as Array).has("Nuker"):
			continue
		band_n += 1
		var lo: float = float((BAND_RANGE[bd] as Array)[0])
		var hi: float = float((BAND_RANGE[bd] as Array)[1])
		_chk("%s band %s ↔ 사거리 %s 정합" % [ab, bd, str(rm)], float(rm) > lo - 0.001 and float(rm) <= hi)
	_chk("밴드 정합 검사 대상 >= 20종", band_n >= 20)

	# ── 폐기 스킬의 유령 참조(DRIFT-130) ────────────────────────────────────────
	# 스킬북만 지우고 **획득 풀·결속·픽스처**를 놔두면 존재하지 않는 책을 가리키게 된다.
	# [[DRIFT-109]]가 `AB-050`으로 정확히 그랬고(ALLY_CACHE_POOL 잔존, 나중에 눈으로 발견),
	# 이번 `AB-060` 폐기도 같은 경로를 **6곳** 갖고 있었다. AB별 검사가 아니라 **참조처 전수**를
	# 카탈로그와 대조한다 — 다음 폐기 때도 자동으로 걸린다.
	var catalog := {}
	for ab in sd._registry_list("ability_ids"):
		if not sd.get_skillbook_master(String(ab)).is_empty():
			catalog[String(ab)] = true
	var DR = load("res://scripts/run/dungeon_run.gd")
	for ab in (DR.ALLY_CACHE_POOL as Array):
		_chk("ALLY_CACHE_POOL %s 실재" % ab, catalog.has(String(ab)))
	var BO = load("res://scripts/combat/abilities/bindings/binding_overlays.gd")
	for ov in (BO.OVERLAYS as Array):
		var sab := String((ov as Dictionary).get("slot_ab", ""))
		if sab == "":
			continue
		_chk("%s slot_ab %s 실재" % [String((ov as Dictionary).get("id", "?")), sab], catalog.has(sab))
	var CS = load("res://scripts/dev/combat_sandbox.gd")
	for fk in (CS._BIND_FIXTURES as Dictionary):
		for sub in ((CS._BIND_FIXTURES as Dictionary)[fk] as Dictionary).get("subs", []):
			_chk("픽스처 %s sub %s 실재" % [fk, sub], catalog.has(String(sub)))
	# N4 통폐합 결과 — 처형은 1종만 남는다(중복 쌍 해소, DRIFT-130).
	_chk("AB-060 아군판 폐기", sd.get_skillbook_master("AB-060").is_empty())
	var exec_n := 0
	for ab in sd._registry_list("ability_ids"):
		if String(sd.get_skillbook_master(String(ab)).get("cast", {}).get("kind", "")) == "skillbook_execute":
			exec_n += 1
	_chk("처형 스킬북 = 1종(중복 해소)", exec_n == 1)

	# ── 누커 = 캐스터: 즉발은 예외뿐(DRIFT-129) ─────────────────────────────────
	# **누커 주력에 즉발이 있으면 안 된다** — 화이트리스트 4종만 예외다. [[DRIFT-120]] ③이 즉발에
	# 자리를 준 건 "도발·DR·반격 같은 **반응·유지형**"이고, 누커는 그 계열이 아니다(딜·제어 중심).
	# 화이트리스트를 코드에 박는 이유: 신규 누커 스킬을 즉발로 추가하는 게 가장 흔한 이탈 경로인데,
	# 즉발은 화면에서 "편하다"로만 보여 리뷰로는 절대 안 잡힌다.
	var NUKER_INSTANT_OK := {
		"AB-062": "은신 — 맞고 나서 켜는 것. 시전을 붙이면 존재 이유가 사라진다(DRIFT-121)",
		"AB-007a": "이탈 — 위급할 때 누르는 도망. 시전을 붙이면 못 도망간다",
		"AB-007b": "저HP 자동 발동(패시브) — 시전 개념 자체가 없다",
		"AB-006": "접근 이동 · 무피해 — 목적지 이동이라 페이로드가 0",
	}
	var nuker_main := 0
	for ab in sd._registry_list("ability_ids"):
		var mnk: Dictionary = sd.get_skillbook_master(String(ab))
		if mnk.is_empty() or not (mnk.get("equip_classes", []) as Array).has("Nuker"):
			continue
		if String(mnk.get("sub_bands", {}).get("Nuker", "B0")) != "B0":
			continue   # 서브밴드로 빌려 쓰는 것은 원 클래스 규칙을 따른다
		nuker_main += 1
		if NUKER_INSTANT_OK.has(String(ab)):
			continue
		_chk("%s 누커 주력 = 캐스트(즉발 아님)" % ab, float(mnk.get("cast", {}).get("cast_s", 0.0)) > 0.0)
	_chk("누커 주력 표본 >= 16종", nuker_main >= 16)   # AB-060 폐기로 17 → 16(DRIFT-130)
	# 예외 목록이 조용히 늘어나는 것도 이탈이다 — "예외적"이 4종을 넘으면 원칙이 아니라 관행이 된다.
	_chk("즉발 예외 <= 4종", NUKER_INSTANT_OK.size() <= 4)

	# ── 속성 = 즉시 효과 정합(DRIFT-128) ────────────────────────────────────────
	# 툴팁은 `element`만 보고 "감전시킨다 / 둔화시킨다"를 붙이는데, 실제 부여는 `Elements.TABLE`의
	# `dur_key`를 params에서 읽어 결정된다. **lightning만 `dur_default`가 0.0**이라 `shock_s`를 빠뜨리면
	# 툴팁은 감전을 약속하고 코드는 아무것도 안 한다 — 화면에선 "가끔 감전 안 걸리네?"로만 보여 못 잡는다.
	# (fire는 `outcome`이 비어 있다 = 즉시 효과 없음·점화는 RX 조건부라 검사 대상이 아니다.)
	var ELS = load("res://scripts/combat/abilities/elements.gd")
	var el_n := 0
	for ab in sd._registry_list("ability_ids"):
		var ce: Dictionary = sd.get_skillbook_master(String(ab)).get("cast", {})
		var el := String(ce.get("element", ""))
		if not (ELS.TABLE as Dictionary).has(el):
			continue
		var et: Dictionary = (ELS.TABLE as Dictionary)[el]
		var dk := String(et.get("dur_key", ""))
		if dk == "":
			continue   # fire — 즉시 효과 없음(RX 조건부)
		el_n += 1
		_chk("%s %s 즉시효과 지속 > 0" % [ab, el],
			float(ce.get(dk, et.get("dur_default", 0.0))) > 0.0)
	_chk("속성 즉시효과 검사 대상 >= 7종", el_n >= 7)

	# ── 적 캐스터 체감(DRIFT-127) ───────────────────────────────────────────────
	# 후열 캐스터가 "무시해도 되는 존재"가 되지 않으려면 **한 방이 물몸 체력의 1/4 이상**이어야 한다.
	# EN-015는 unified AB-053을 쓰므로 피해 = `contact_damage × skillbooks의 damage_mult` — 두 파일에
	# 나뉜 값의 곱이라 한쪽만 내려가도 조용히 무력해진다. 그래서 곱한 결과를 직접 건다.
	var SQUISHY_HP := 85.0   # 파티 최저 HP(누커) — 캐스터 위협의 기준선
	var c053: Dictionary = sd.get_skillbook_master("AB-053").get("cast", {})
	var en15: Dictionary = sd.get_enemy_row("EN-015").get("stats", {})
	var cast_hit: float = float(en15.get("contact_damage", 0.0)) * float(c053.get("damage_mult", 0.0))
	_chk("EN-015 한 방 %.1f >= 물몸 HP의 25%%" % cast_hit, cast_hit >= SQUISHY_HP * 0.25)
	# 캐스터는 평타가 아니라 스킬이 위협이어야 한다 — 평타 한 대가 스킬만큼 아프면 정체성이 무너진다.
	_chk("EN-015 스킬 > 평타 2배", cast_hit > float(en15.get("contact_damage", 0.0)) * 2.0)
	# 배율을 올린 만큼 쿨로 갚았는지(DRIFT-123 원칙) — 안 갚으면 지속 화력이 통째로 2배가 된다.
	_chk("AB-053 지속 화력 동결(mult/cd <= 0.25)",
		float(c053.get("damage_mult", 0.0)) / maxf(float(c053.get("cooldown_s", 1.0)), 0.001) <= 0.25)
	# 3초 캐스트짜리가 1초급 배율이면 "기다린 보람"이 없다 — cast_s 대비 최소 사다리.
	_chk("AB-053 cast 3.0s 사다리(mult >= 2.0)", float(c053.get("damage_mult", 0.0)) >= 2.0)

	# ── ENC-NORM-004 후열 캐스터 조우(DRIFT-126) ────────────────────────────────
	# authored `units`는 던전 런에선 제너레이터가 덮지만(`_should_generate`) **샌드박스 ENC 스폰은
	# 그대로 쓴다** — 즉 이 파일은 "이 조합을 체감하겠다"는 선언이다. 그래서 조합 규칙을 게이트로 건다.
	var e004: Dictionary = sd.get_encounter("ENC-NORM-004")
	_chk("ENC-NORM-004 로드", not e004.is_empty())
	var u004: Array = e004.get("units", [])
	var ids004: Array = []
	var n004 := 0
	for u in u004:
		ids004.append(String((u as Dictionary).get("enemy_id", "")))
		n004 += int((u as Dictionary).get("count", 0))
	_chk("EN-015가 실제로 편성됨", ids004.has("EN-015"))
	_chk("group_size = 유닛 합(%d)" % n004, int(e004.get("group_size", -1)) == n004)
	# ENC-000 §2 cap: mechanicAxes = elite 수 + 고유 specialist axis 수 <= 2.
	var axes004 := 0
	var seen_ax := {}
	for eid4 in ids004:
		var t4: Dictionary = sd.get_enemy_tags(String(eid4))
		var bk := String(t4.get("bucket", ""))
		if bk == "Elite":
			axes004 += 1
		elif bk == "Specialist":
			var ax4 := String(t4.get("axis", ""))
			if not seen_ax.has(ax4):
				seen_ax[ax4] = true
				axes004 += 1
	_chk("mechanicAxes %d <= 2 (ENC-000 §2)" % axes004, axes004 <= 2)
	# §3 안티패턴 "원거리 poke 이중" — 원거리 Specialist와 원거리 fodder를 같이 두면 전열/후열 경계가
	# 무너진다. EN-011(BackPester 7.5m)이 그 짝이라 이 조우의 fodder는 근접만이어야 한다.
	var ranged_spec := false
	var ranged_fod := false
	for eid4 in ids004:
		var t4b: Dictionary = sd.get_enemy_tags(String(eid4))
		var rng4 := float(sd.get_enemy_row(String(eid4)).get("stats", {}).get("attack_range_m", 0.0))
		if rng4 >= 5.0:
			if String(t4b.get("bucket", "")) == "Specialist":
				ranged_spec = true
			elif String(t4b.get("bucket", "")) == "Fodder":
				ranged_fod = true
	_chk("원거리 poke 이중 없음(§3 안티패턴)", not (ranged_spec and ranged_fod))
	# 배선 3종 — 하나라도 빠지면 조우가 만들어져도 런에 안 뜨거나 전리품이 0이 된다.
	_chk("ENC-NORM-004 id 등록", (sd._registry_list("encounter_ids") as Array).has("ENC-NORM-004"))
	_chk("ENC-NORM-004 haul_drops 있음", (sd.get_haul_drops("ENC-NORM-004") as Array).size() > 0)
	var stsrc := FileAccess.get_file_as_string("res://data/slice01/spawn_table.json")
	_chk("ENC-NORM-004 spawn_table 편성", stsrc.contains("ENC-NORM-004"))

	# ── 적 표적 우선순위(DRIFT-125) ─────────────────────────────────────────────
	# 힐러 > 누커 > 딜러 > 탱커 순으로 노리되 **탱커가 위협을 쌓으면 되찾는다**(하드 오버라이드 아님).
	# 두 성질이 같이 성립해야 어그로 관리가 플레이가 되므로 둘 다 건다 — 하나만 맞으면 설계가 반쪽이다.
	var TP: Dictionary = EN.TARGET_PRIORITY
	_chk("우선순위 사다리 힐러>누커>딜러>탱커",
		float(TP["Healer"]) > float(TP["Nuker"]) and float(TP["Nuker"]) > float(TP["DPS"])
		and float(TP["DPS"]) > float(TP["Tank"]))
	var enp = EN.new()
	enp.attack_range_m = 100.0   # 전원 사거리 안 → 순수하게 우선순위만 본다
	var members := {}
	for cls in ["Healer", "Nuker", "DPS", "Tank"]:
		var pmx = PM.new()
		pmx.class_id = cls
		pmx.add_to_group("party_member")
		pmx.global_position = Vector3(1, 0, 0)
		members[cls] = pmx
		enp.add_threat(pmx, 100.0)   # 위협 동일 → 차이는 우선순위뿐
	var cand: Array = [members["Healer"], members["Nuker"], members["DPS"], members["Tank"]]
	_chk("동일 위협 → 힐러를 노림", enp.pick_target(cand, 1.25) == members["Healer"])
	# 탱커가 위협을 쌓으면 되찾아온다 — 이게 안 되면 어그로 관리가 무의미해진다.
	enp.add_threat(members["Tank"], 900.0)   # 탱커 1000×1.0 = 1000 > 힐러 100×3.0 = 300
	_chk("탱커가 위협 쌓으면 되찾음", enp.pick_target(cand, 1.25) == members["Tank"])
	for cls in members:
		members[cls].free()
	enp.free()
	# **인지 범위 우선**은 런타임으로 못 짚는다 — 거리·LOS 판정이 `global_position`과 물리 레이라
	# **트리 안**이어야 하는데, EnemyUnit을 root에 붙이면 `_ready`가 오토로드·비주얼을 끌고 오다
	# 헤드리스에서 **멈춘다**(FAIL이 아니라 hang — [[DRIFT-118]] 기록). 그래서 이 축은 소스로 못박는다.
	# 위 우선순위·탱커 되찾기는 위치와 무관해 실런타임으로 검증했다.
	var aisrc := FileAccess.get_file_as_string("res://scripts/combat/enemy_ai.gd")
	_chk("표적 후보 = 인지 범위(_huntable)", aisrc.contains("enemy.pick_target(_huntable(enemy, hostiles)"))
	_chk("_huntable = 교전중 or 반경+LOS",
		aisrc.contains("HUNT_RADIUS_M or not _has_los(enemy, h)"))
	# 우선순위는 **인지한 것들 중에서만** 적용돼야 한다 — 유닛 쪽에 거리 필터가 남아 있으면 층이 겹쳐
	# 두 번 걸러진다(근접 몹이 아무도 못 고르는 회귀). 유닛은 위협 장부만, 인지는 AI만.
	var eusrc := FileAccess.get_file_as_string("res://scripts/combat/enemy_unit.gd")
	_chk("유닛은 거리 필터를 갖지 않음(층 분리)", not eusrc.contains("attack_range_m * attack_range_m"))

	# ── Shared AB 배율 파리티(DRIFT-124) ────────────────────────────────────────
	# 같은 AB는 진영이 달라도 **같은 스킬**이어야 한다([[DRIFT-117]] ①). 양측 모두 `basic_damage`에
	# 곱하는 동일 구조라(적은 `contact_damage`가 그 별칭) 배율이 갈리는 순간 다른 스킬이 된다.
	# **진영별 세기 차이는 배율이 아니라 유닛 기본치로 낸다** — 이 게이트가 그 규약의 집행부다.
	# 전역으로 도는 이유: 아군 쪽만 튜닝하다 조용히 깨지는 게 이 규약의 유일한 파손 경로였다(DRIFT-123).
	# 배율과 쿨을 **같은 잣대로** 본다 — 배율만 맞추고 쿨이 갈리면 스킬의 리듬이 진영별로 달라져
	# 결국 다른 스킬이 된다. 면제는 사유를 남긴 **기존 미판정 잔여**뿐이고, 여기 없는 신규 이탈은 FAIL.
	var PARITY_EXEMPT := {
		"damage_mult": {
			"AB-005": "적측 정의가 orphan(EN-010에서 제거) — 죽은 데이터",
		},
		"cooldown_s": {
			"AB-005": "orphan",
		},
	}
	var parity_n := {"damage_mult": 0, "cooldown_s": 0}
	for ab in sd._registry_list("ability_ids"):
		var abs2 := String(ab)
		var acast: Dictionary = sd.get_skillbook_master(abs2).get("cast", {})
		var ecast: Dictionary = sd.get_ability(abs2)
		for field in ["damage_mult", "cooldown_s"]:
			var av = acast.get(field)
			var ev = ecast.get(field)
			if av == null or ev == null or (PARITY_EXEMPT[field] as Dictionary).has(abs2):
				continue
			parity_n[field] = int(parity_n[field]) + 1
			_chk("%s %s 파리티(아군 %.2f = 적 %.2f)" % [abs2, field, float(av), float(ev)],
				is_equal_approx(float(av), float(ev)))
	# 면제가 늘어 검사 대상이 줄어드는 것도 파손이다(게이트를 비워서 통과시키는 회피 차단).
	_chk("배율 파리티 대상 >= 7종", int(parity_n["damage_mult"]) >= 7)
	_chk("쿨 파리티 대상 >= 12종", int(parity_n["cooldown_s"]) >= 12)

	# ── 단일 대상 잠금(DRIFT-122) ────────────────────────────────────────────────
	# 잠금 대상 12종 = 판정의 SSOT. 목록을 코드에 박아 두는 이유: 반경·kind로는 못 가른다(같은
	# skillbook_bolt에 r4.0 광역이 섞여 있고, 반경을 튜닝하다 조준 방식이 조용히 바뀌면 안 된다).
	var LOCK_ABS := ["AB-004", "AB-012", "AB-013", "AB-030", "AB-056", "AB-057",
		"AB-059", "AB-073", "AB-100", "AB-103", "AB-106"]
	for ab in LOCK_ABS:
		var cl: Dictionary = sd.get_skillbook_master(String(ab)).get("cast", {})
		_chk("%s single_target" % ab, bool(cl.get("single_target", false)))
	# 광역은 잠금이 아니어야 한다 — 하나라도 잠기면 반경이 죽고 단일기가 된다(조용한 하향).
	for ab in ["AB-003", "AB-058", "AB-005", "AB-041", "AB-053"]:
		_chk("%s 광역 = 잠금 아님" % ab,
			not bool(sd.get_skillbook_master(String(ab)).get("cast", {}).get("single_target", false)))
	# 잠금은 조준 위에서만 성립한다 — targeted 없이 single_target이면 조준 모달을 안 타 대상을 못 고른다.
	for ab in sd._registry_list("ability_ids"):
		var ml: Dictionary = sd.get_skillbook_master(String(ab))
		if ml.is_empty():
			continue
		var cm: Dictionary = ml.get("cast", {})
		if bool(cm.get("single_target", false)):
			_chk("%s 잠금 ⇒ targeted" % ab, bool(cm.get("targeted", false)))
	# 해소 — 잠금이 실리면 반경·최근접과 무관하게 **그 유닛**이 나온다(fallback은 _combat이 필요해 제외).
	var adl = AD.new()
	var lock_tgt = EN.new()
	lock_tgt.hp = 10.0
	var plock := {"single_target": true, "_target": lock_tgt}
	_chk("resolve_target = 잠금 유닛", adl.resolve_target(plock, Vector3(999, 0, 999), 0.1) == lock_tgt)
	var lset: Array = adl.resolve_targets(plock, Vector3(999, 0, 999), 0.1)
	_chk("resolve_targets = 잠금 1체", lset.size() == 1 and lset[0] == lock_tgt)
	lock_tgt.free()
	adl.free()
	# 빈 지면 클릭 = 시전 안 함(무비용 취소). 조준 모달은 헤드리스에서 마우스를 못 만들어 소스로 못박는다.
	var acsrc := FileAccess.get_file_as_string("res://scripts/run/controllers/aim_controller.gd")
	_chk("빈 지면 = 취소(시전 없음)", acsrc.contains("if _single_target and unit == null:"))
	_chk("잠금 조준 = 유닛 레이픽", acsrc.contains("_pick_enemy_under_mouse"))

	var ad3 = AD.new()
	var pm4 = PM.new()
	pm4.set_skillbook(0, {"base_ability_id": "AB-062", "params": c62, "charges": 3, "cooldown_s": 14.0})
	pm4.apply_veil(60.0, true)
	pm4.grant_next_hit_bonus(float(c62.get("next_hit_bonus", 0.0)))
	ad3.cast_skillbook(pm4, 0)
	_chk("은신 재입력 = 취소(쿨 중에도)", not pm4.is_veiled() and not pm4.holds_fire())
	_chk("취소는 무비용(차지 불변)", int(pm4.get_skillbook(0).charges) == 3)
	# 취소로 증폭이 남으면 "은신 → 즉시 취소 → 강화 평타"가 은신을 건너뛰고 보상만 챙기는 경로가 된다.
	_chk("취소 = 증폭 폐기", is_equal_approx(pm4.consume_next_hit_bonus(), 0.0))
	pm4.free()
	ad3.free()

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
	_chk("identity 표시명", sd.get_identity_display("tank_iron_beacon") == "응징의 표식")
	_chk("effect 표시명", sd.get_effect_label("skillbook_silence") == "침묵")
	_chk("role 표시명", sd.get_role_label("Healer") == "힐러")
	_chk("미등록 ID 폴백", sd.get_effect_label("nonexistent_kind") == "nonexistent_kind")

	# 14) G3 — rolls mult 스탯 적용. 같은 기어 dmg_mult 1.0 vs 2.0 → basic_damage 2배 + cd_mult→cooldown_mult.
	var pmA = PM.new(); pmA.class_id = "Tank"
	var bpA = BP.new(); bpA.equipped = {"Tank": {"gear": "gear_ward_tank_anchor_bulwark", "rolls": {"dmg_mult": 1.0, "cd_mult": 1.0}, "subs": [null, null, null]}}
	bpA.apply_to_party(_PartyStub.new([pmA]))
	var d1 := float(pmA.basic_damage)
	var pmB = PM.new(); pmB.class_id = "Tank"
	var bpB = BP.new(); bpB.equipped = {"Tank": {"gear": "gear_ward_tank_anchor_bulwark", "rolls": {"dmg_mult": 2.0, "cd_mult": 0.9, "potency_mult": 1.1}, "subs": [null, null, null]}}
	bpB.apply_to_party(_PartyStub.new([pmB]))
	_chk("G3 dmg_mult 스탯 적용(2x)", d1 > 0.0 and is_equal_approx(float(pmB.basic_damage), d1 * 2.0))
	_chk("G3 cd_mult → cooldown_mult", is_equal_approx(float(pmB.cooldown_mult), 0.9))
	_chk("S6b potency_mult → identity_potency_mult", is_equal_approx(float(pmB.identity_potency_mult), 1.1))
	pmA.free(); pmB.free()

	# 이연 — 평타 특수거동(ba 아키타입): march_plate(ba_tank_march_stomp)=cleave+kb, 단일타 gear=0.
	var pmC = PM.new(); pmC.class_id = "Tank"
	var bpC = BP.new(); bpC.equipped = {"Tank": {"gear": "gear_ward_tank_march_plate", "subs": [null, null, null]}}
	bpC.apply_to_party(_PartyStub.new([pmC]))
	_chk("평타 cleave/kb(march_stomp)", is_equal_approx(float(pmC.basic_cleave_m), 3.0) and is_equal_approx(float(pmC.basic_knockback_m), 1.5))
	var pmD = PM.new(); pmD.class_id = "Tank"
	var bpD = BP.new(); bpD.equipped = {"Tank": {"gear": "gear_ward_tank_anchor_bulwark", "subs": [null, null, null]}}
	bpD.apply_to_party(_PartyStub.new([pmD]))
	_chk("평타 단일타 gear=cleave 0", is_equal_approx(float(pmD.basic_cleave_m), 0.0))
	# pierce — 원거리 ba 아키타입(weave_lance)=관통, cleave는 0.
	var pmE = PM.new(); pmE.class_id = "DPS"
	var bpE = BP.new(); bpE.equipped = {"DPS": {"gear": "gear_ward_dps_weave_staff", "subs": [null, null, null]}}
	bpE.apply_to_party(_PartyStub.new([pmE]))
	_chk("평타 pierce(weave_lance)=9·cleave 0", is_equal_approx(float(pmE.basic_pierce_m), 9.0) and is_equal_approx(float(pmE.basic_cleave_m), 0.0))
	pmC.free(); pmD.free(); pmE.free()

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
	# S7 — 시드 stash가 창고 T0 capacity(20) 안에 들어오는지(15기어+4스킬북=19). item_count=기어+스킬북.
	var stseed = StashScript.new()
	stseed.reset_to_seed()
	_chk("stash 시드 item_count 19 ≤ T0 20", stseed.item_count() == 19)
	stseed.free()

	# 15b) Stash 스킬북 인스턴스화(D-018 §7.3) — 문자열 정규화 + affix 보존 + remove는 plain 우선(affix본 보존).
	var st3 = StashScript.new()
	st3.apply_dict({"gear": [], "skillbooks": ["AB-002", {"base_ability_id": "AB-002", "affix": {"ids": ["affix_eff_plus"], "tier": "T1", "coeff": 0.09, "charges": 0, "cd_trade": 0.0}}], "consumables": {}})
	_chk("Stash 스킬북 문자열 정규화", typeof(st3.skillbooks[0]) == TYPE_DICTIONARY and String((st3.skillbooks[0] as Dictionary).get("base_ability_id", "")) == "AB-002")
	_chk("Stash 스킬북 affix 보존", not ((st3.skillbooks[1] as Dictionary).get("affix", {}) as Dictionary).is_empty())
	st3.remove_skillbook("AB-002")   # plain(0번) 우선 소멸 → affix본 잔존
	_chk("Stash remove plain 우선(affix본 보존)", st3.skillbooks.size() == 1 and not ((st3.skillbooks[0] as Dictionary).get("affix", {}) as Dictionary).is_empty())
	st3.free()

	# 16) 스킬북 affix(D-018 §7.3/§7.6) — roll cap 준수 + charges 가산 + capture/apply 영속.
	var AffixRoller = load("res://scripts/run/affix_roller.gd")
	var any_affix := false
	var caps_ok := true
	var ids_ok := true
	var multi_seen := false
	for _i in 600:
		var a: Dictionary = AffixRoller.roll_forced()   # 보장 굴림(병합 확인 표본 확보)
		if a.is_empty():
			continue
		any_affix = true
		if float(a.get("coeff", 0.0)) > 0.1501 or int(a.get("charges", 0)) < 0 or int(a.get("charges", 0)) > 6:
			caps_ok = false   # multi-affix: coeff 합산 ≤15%(§7.3), charges는 단일 charges종만 → 0..6 유지
		var ids := a.get("ids", []) as Array
		if ids.is_empty() or String(a.get("tier", "")).is_empty():
			ids_ok = false
		if ids.size() >= 2:
			multi_seen = true
	_chk("affix 발생", any_affix)
	_chk("affix coeff≤15%(합산캡)·탄0..6", caps_ok)
	_chk("multi-affix 병합(2종 ids) 발생", multi_seen)
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

	# 17b) 클래스 밸런스 소프트-피티 (loot_service) — 과대표 클래스 점감, 미표 클래스 유지(EN-001 Tank 쏠림 보완).
	var LS = load("res://scripts/run/loot_service.gd")
	var ls = LS.new()
	_chk("balance 초기 1.0", is_equal_approx(float(ls._class_balance_factor(["Tank"])), 1.0))
	for _j in 8:
		ls._record_class_drop(["Tank"])   # Tank만 8건 쌓기
	_chk("Tank 과대표 → 점감(<0.5)", float(ls._class_balance_factor(["Tank"])) < 0.5)
	_chk("Nuker 미표 → 1.0 유지", is_equal_approx(float(ls._class_balance_factor(["Nuker"])), 1.0))
	_chk("멀티클래스는 부족한 쪽 기준(통과)", is_equal_approx(float(ls._class_balance_factor(["Tank", "Nuker"])), 1.0))
	ls.free()

	# 18) 절차적 상자 루트 — roll_forced 항상 affix · rare 상자 스킬 affix 보장 · common 재료 위주.
	var AR = load("res://scripts/run/affix_roller.gd")
	var fa: Dictionary = AR.roll_forced()
	_chk("roll_forced 항상 affix", not fa.is_empty() and not (fa.get("ids", []) as Array).is_empty())
	var ls2 = LS.new()
	var rare_skill_seen := false
	var rare_skill_affixed := true
	for _k in 40:
		for it in ls2.build_chest_items("rare"):
			if String(it.get("kind", "")) == "skillbook":
				rare_skill_seen = true
				if (it.get("affix", {}) as Dictionary).is_empty():
					rare_skill_affixed = false
	_chk("rare 상자 스킬 등장", rare_skill_seen)
	_chk("rare 상자 스킬 affix 보장", rare_skill_affixed)
	var ch_haul := 0
	var ch_total := 0
	var consum_seen := false
	for _k in 40:
		for it in ls2.build_chest_items("common"):
			ch_total += 1
			if String(it.get("kind", "")) == "haul":
				ch_haul += 1
			elif String(it.get("kind", "")) == "consumable":
				consum_seen = true
	_chk("common 상자 재료 위주(>50%)", ch_total > 0 and float(ch_haul) / float(ch_total) > 0.5)
	_chk("상자 소모품 등장", consum_seen)
	ls2.free()

	# 18b) 몬스터 킬 = 스킬 OR 재화 — 비lootable 킬은 run_scrap 누적(킬 기어/재료 없음).
	var ls3 = LS.new()
	ls3.setup(null)
	ls3.on_enemy_defeated(Vector3.ZERO, [])            # fodder(lootable 없음) → 재화
	ls3.on_enemy_defeated(Vector3.ZERO, ["rom_basic"]) # 비lootable ref → 재화
	_chk("킬 재화 누적(스킬 미드롭)", int(ls3.run_scrap) == 2 * int(ls3.KILL_SCRAP))
	ls3.free()

	# 19) S5b EN-* 생성기 태그 — tier/archetype/bucket/axis/faction/placement + fodder_variant.
	var t1: Dictionary = sd.get_enemy_tags("EN-001")
	_chk("EN-001 태그 Elite/ShieldElite", String(t1.get("tier", "")) == "Elite" and String(t1.get("bucket", "")) == "Elite")
	_chk("EN-010 fodder_variant", String(sd.get_enemy_tags("EN-010").get("fodder_variant", "")) == "FrontRush")
	_chk("EN-3RD-01 faction", String(sd.get_enemy_tags("EN-3RD-01").get("faction", "")) == "ThirdFaction")
	var all_tagged := true
	for eid in sd.get_enemy_ids():
		if (sd.get_enemy_tags(String(eid)) as Dictionary).is_empty():
			all_tagged = false
	_chk("모든 EN 태그 보유", all_tagged)

	# 20) S5b P2 조합 제너레이터 — ENC-000 가드레일(mechanicAxes≤2·fodder 범위·variant min·고유 specialist 축) 항상 준수.
	var EG = load("res://scripts/run/encounter_generator.gd")
	var gen_ok := true
	var saw_specialist := false
	var saw_elite := false
	for diff in ["Normal", "Hard", "Extreme"]:
		var sc: Dictionary = EG.SCALE[diff]
		for s in range(1, 150):
			var c: Dictionary = EG.generate(diff, s)
			var fn := (c["fodder"] as Array).size()
			if int(c["mechanic_axes"]) > int(sc["axes_max"]): gen_ok = false
			if fn < int(sc["fodder_min"]) or fn > int(sc["fodder_max"]): gen_ok = false
			if (c["elites"] as Array).size() > int(sc["elite_max"]): gen_ok = false
			var axes: Dictionary = {}
			for sid in c["specialists"]:
				var ax := String(sd.get_enemy_tags(String(sid)).get("axis", ""))
				if axes.has(ax):
					gen_ok = false
				axes[ax] = true
			if not (c["specialists"] as Array).is_empty(): saw_specialist = true
			if not (c["elites"] as Array).is_empty(): saw_elite = true
			if fn >= 3:
				var vs: Dictionary = {}
				for fid in c["fodder"]:
					var tg: Dictionary = sd.get_enemy_tags(String(fid))
					vs[String(tg.get("fodder_variant", tg.get("axis", "")))] = true
				if vs.size() < int(sc["variant_min"]): gen_ok = false
	_chk("제너레이터 가드레일 준수(축≤2·fodder범위·variant)", gen_ok)
	_chk("제너레이터 elite/specialist 등장", saw_elite and saw_specialist)

	# 17) 스킬 설명문 + 색구분 툴팁 빌더 (display_names.skill_desc / SkillText).
	_chk("skill_desc(silence) 존재", not sd.get_skill_desc("skillbook_silence").is_empty())
	var ST = load("res://scripts/ui/skill_text.gd")
	var alines: Array = ST.affix_lines({"ids": ["affix_eff_plus"], "tier": "T1", "coeff": 0.09, "charges": 0, "cd_trade": 0.0})
	_chk("affix_lines 색태그", alines.size() >= 1 and String(alines[0]).contains("color="))
	_chk("band_pct 주력=0", ST.band_pct("AB-044", "Healer") == 0)
	_chk("gear_roll_line 색태그", String(ST.gear_roll_line({"dmg_mult": 1.1, "cd_mult": 0.95})).contains("color="))

	print("PARTY POOL SMOKE " + ("PASSED" if _ok else "FAILED"))
	quit(0 if _ok else 1)


## 유닛에 붙은 지속형 오오라 노드 수(meta "aura_key" 보유 자식). party_member는 _ready에서 체력바 등
## 자식을 만들므로 전체 child_count로는 셀 수 없다.
func _aura_count(unit: Node) -> int:
	var c := 0
	for ch in unit.get_children():
		if ch.has_meta("aura_key"):
			c += 1
	return c


## 선언된 인자 수(기본값 포함) — 시그니처 파리티 검사용.
func _argc(node: Object, method: String) -> int:
	for m in node.get_method_list():
		if String(m.get("name", "")) == method:
			return (m.get("args", []) as Array).size()
	return -1


func _chk(label: String, cond: bool) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_ok = false
