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


func _chk(label: String, cond: bool) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_ok = false
