extends Node3D
## AbilityDispatch — dispatches party Identity (auto, NC + controlled) + Sub (player-only)
## skill effects by the LINKED ability's `kind`. Each EFFECT is its own drop-in file under
## effects/ implementing `kind() -> String` + `cast(actor, params, target_pos, ctx) -> bool`.
## This node is BOTH the dispatcher AND the `ctx` facade skills call back (spatial queries /
## damage / heal-threat / camera shake / reactions / VFX parent). Shared systems stay owned by
## CombatController + ReactionSystem; skills never touch them directly.
## **ADD A SKILL = drop a file in effects/ + add one line to _SKILL_SCRIPTS** (the kind()
## string lives in the file — no other central edit). ref: F-005 · F-009 · QA-005 §2.6.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")
const _SkillCast := preload("res://scripts/combat/abilities/effects/skill_cast.gd")  # P4a 캐스팅 시간 범용 래퍼
const _RampartBarrier := preload("res://scripts/world/objects/rampart_barrier.gd")  # AB-034 spawn
const _Projectile := preload("res://scripts/combat/abilities/projectile.gd")        # delivery=projectile

## Drop-in skill effects. Each is loaded + instantiated once at setup() and registered by its
## kind(). Horizontal expansion: new skill = new effects/<name>.gd + one preload line here.
const _SKILL_SCRIPTS := [
	preload("res://scripts/combat/abilities/effects/anchor_guard.gd"),
	preload("res://scripts/combat/abilities/effects/press_line.gd"),
	preload("res://scripts/combat/abilities/effects/mark_ruin.gd"),
	preload("res://scripts/combat/abilities/effects/mend_circle.gd"),
	preload("res://scripts/combat/abilities/effects/sb_strike.gd"),
	preload("res://scripts/combat/abilities/effects/sb_poison.gd"),
	preload("res://scripts/combat/abilities/effects/sb_stun.gd"),
	# sb_zone 제거 — 매질 생성은 **소모품**으로 이관(DRIFT-112). 적은 enemy_ai가 spawn_zone 직접 호출.
	# sb_fire·sb_cold 제거 — D1+D2 병합(DRIFT-111): element가 SSOT라 skillbook_bolt로 흡수.
	# P2-S6a — Third-faction lootables (AB-100~106 party side; DEC-20260621-001).
	preload("res://scripts/combat/abilities/effects/sb_root.gd"),    # AB-102 Snare Net (Tank)
	preload("res://scripts/combat/abilities/effects/sb_pin.gd"),     # AB-100 Pounce (Nuker)
	preload("res://scripts/combat/abilities/effects/sb_tether.gd"),  # AB-103 Tether (Nuker)
	# AB-104 Rampage(sb_charge) 제거 — T1 통폐합(DRIFT-101): AB-011로 흡수, 적 EN-3RD-03도 AB-011로 교체.
	preload("res://scripts/combat/abilities/effects/sb_execute.gd"), # AB-106 Devour (Nuker)
	# sb_scent 제거 — AB-101 아군판 폐기(DRIFT-116): Scented를 소비하는 코드가 enemy_ai의 팩 표적
	# 선정 하나뿐이라 **플레이어 쪽 효과가 0**이었다. 적측은 abilities.json `enemy_only`로 존치.
	# Gear-catalog Identity skills (non-starter identities; spec PT-pending → intent impl, params drift).
	preload("res://scripts/combat/abilities/effects/beacon_threat.gd"),  # IDA-021 Iron Beacon (Tank)
	preload("res://scripts/combat/abilities/effects/march_advance.gd"),  # IDA-022 Bulwark March (Tank)
	preload("res://scripts/combat/abilities/effects/sentinel_form.gd"),  # IDA-052 Sentinel Form (Tank)
	preload("res://scripts/combat/abilities/effects/arc_line.gd"),       # IDA-027 Arc Weave (DPS)
	preload("res://scripts/combat/abilities/effects/flank_dash.gd"),     # IDA-029 Flank Collapse (Nuker)
	# P2-S6a B1 — party lootable sub effect kinds (new, beyond reused strike/fire/stun/cold/zone).
	preload("res://scripts/combat/abilities/effects/sb_heal.gd"),        # AB-064 Quick Mend (Healer)
	preload("res://scripts/combat/abilities/effects/sb_channel_heal.gd"),# AB-064/066 집중 채널 힐 (Healer 킷 재설계)
	preload("res://scripts/combat/abilities/effects/sb_ward_heal.gd"),   # AB-065 수호-흡수 힐 (Healer 킷 재설계)
	preload("res://scripts/combat/abilities/effects/sb_dr.gd"),          # AB-046/047/068 Shield Wall·Aegis·Warding (Tank/Healer)
	preload("res://scripts/combat/abilities/effects/sb_reflect.gd"),     # AB-048 Counter Stance (Tank) — T2 재정의, DRIFT-102
	preload("res://scripts/combat/abilities/effects/sb_ally_shield.gd"), # AB-067 Aegis Blessing (Healer)
	preload("res://scripts/combat/abilities/effects/sb_hot.gd"),         # AB-065 Renewing Tide (Healer)
	preload("res://scripts/combat/abilities/effects/sb_blink.gd"),       # AB-006 Gap-Close / AB-007a·b (Nuker)
	preload("res://scripts/combat/abilities/effects/sb_vulnerable.gd"),  # AB-057 Focus Fire (Healer)
	preload("res://scripts/combat/abilities/effects/sb_polymorph.gd"),   # AB-012 Hex Bolt — 개구리 변이(Healer/Nuker)
	preload("res://scripts/combat/abilities/effects/sb_dash.gd"),        # AB-013 Backstab Dash — 단일 돌진+피해(Nuker)
	preload("res://scripts/combat/abilities/effects/sb_haste.gd"),       # AB-069 Swift Grace (Healer)
	# P2-S6a B1 잔여 — stealth/buff/channel/barrier/purge/silence (AB-075 reuses skillbook_shield).
	preload("res://scripts/combat/abilities/effects/sb_stealth.gd"),     # AB-062 Smoke Veil (Nuker, Veiled)
	preload("res://scripts/combat/abilities/effects/sb_channeling.gd"),  # AB-054/109/110/111 채널링 4형상 (DPS)
	preload("res://scripts/combat/abilities/effects/sb_barrier.gd"),     # AB-034 Rampart Slam (Tank, ENT-RAMPART-001)
	preload("res://scripts/combat/abilities/effects/sb_purge.gd"),       # AB-070 Purge Light (Healer)
	preload("res://scripts/combat/abilities/effects/sb_silence.gd"),     # AB-044 Hush Ward (Healer, Silenced)
	# P2-S6a B2 — remaining ranged/burst lootables → one targeted bolt kind (옵션 lightning→Shock).
	preload("res://scripts/combat/abilities/effects/sb_bolt.gd"),        # AB-003/004/008/055/056/058/059/073
	# P2-S6a B2 잔여 bespoke — Tank control + Healer utility.
	preload("res://scripts/combat/abilities/effects/sb_taunt.gd"),       # AB-035 Challenge Mark (Tank)
	# AB-051 sb_pull 제거 — T4 판정(DRIFT-108): 견인 → **원거리 단일 도발**로 재정의, skillbook_taunt 흡수.
	# AB-050 sb_slow 제거 — T4b 판정(DRIFT-109): 둔화 폐기(정지형 적 72%에 실효 없음).
	preload("res://scripts/combat/abilities/effects/sb_relocate_ally.gd"), # AB-045 Lifeline (Healer)
	preload("res://scripts/combat/abilities/effects/sb_reveal.gd"),      # AB-032 Beacon Sight (Healer)
]

# F-009 §3.2.1 / D-016 §3.2 / D-012 §2.4 — cross-class (sub) skillbook penalty by IDENTITY-DISTANCE
# BAND, not a flat −10% (that policy was retired, DEC-20260617-002). mainClasses (B0) = full coeff;
# subClasses carry a band (B1 인접 / B2 중간 / B3 이탈) read from the skillbook master's `sub_bands`
# {classId: band}. A class NOT listed in sub_bands = main (B0 = ×1.0). The Role Equip Gate stays
# `equip_classes` (= mainClasses ∪ subClasses). coeff numbers are TUNING (spec: 수치 TBD, band 라벨만
# SSOT — SPEC_DRIFT log only, DRIFT-057).
const BAND_COEFF := {"B0": 1.0, "B1": 0.9, "B2": 0.75, "B3": 0.55}
# Camera hit-feel for player SUB skills — ONE shake per cast (not per AOE target).
const SUB_SHAKE_MULT_REF := 8.0   # 타격감: trauma = sub damage_mult/ref
const HIT_SHAKE_CAP := 0.6

# ctx 계약 표면 (SSOT) — sb_* effect가 `ctx.` 로 호출하는 파사드 메서드 집합. ctx 구현이 둘(파티=이
# AbilityDispatch / 적 unified=CastContext)이라, 둘이 이 집합을 모두 구현하는지 party_pool_smoke가
# 파리티 검증한다(암묵 중복 → 명시 계약). **새 ctx 메서드 추가 시 여기 + CastContext 둘 다 갱신.**
const CTX_CONTRACT := [
	"deal_damage", "deal_heal", "deal_regen", "heal_threat", "sub_shake",
	"enemies_in_radius", "enemies_in_cone", "enemies_in_rect", "nearest_enemy_in_range",
	"allies_in_radius", "lowest_hp_enemy_in_radius", "reveal_enemies", "reduce_threat",
	"spawn_projectile", "spawn_zone", "spawn_barrier", "fire_hit", "cold_hit", "lightning_hit",
	"element_hit",
	"damage_destructibles", "report_hit_count", "report_hit_target", "nuker_focus_accumulate",
	"resolve_target", "resolve_targets", "report_cd_refund",
]

var _combat: Node3D    # CombatController — spatial queries / damage / threat / shake owner
var _reactions: Node3D  # ReactionSystem — destructibles + RX-OIL-FIRE chain
var _skills: Dictionary = {}  # kind -> skill instance (built from _SKILL_SCRIPTS)
## AB-005 focus_dump — 직전 서브 이펙트가 때린 적 수(sb_strike가 report). 단일(1)→집중 소모 / 그외→빌드.
var _last_hit_count: int = 0
var _last_hit_target: CharacterBody3D = null   # 직전 서브가 맞춘 주 대상(AB-007 이탈 마무리딜 대상 → 집중 결속이 조회)
## ON-KILL-FEED 쿨 환급(AB-106 · DRIFT-132) — 효과가 직접 `inst.cooldown_s`를 깎을 수 없다.
## `cast_s>0` 경로는 **효과 해소 뒤에** `inst.cooldown_s = cd`로 통째 덮어쓰기 때문(잠행 AB-013의
## kill-reset이 자기 캐스트의 처치엔 안 먹던 것도 같은 이유). 효과는 여기 프랙션만 보고하고,
## 디스패처가 쿨을 건 **직후**에 접는다. `report_hit_target` 규약과 같은 채널.
var _cd_refund_frac: float = 0.0


func setup(combat: Node3D, reactions: Node3D) -> void:
	_combat = combat
	_reactions = reactions
	for s in _SKILL_SCRIPTS:
		var skill = s.new()
		_skills[String(skill.kind())] = skill


## Dispatch Identity skill by the LINKED ability's `kind` (not class) — any character with
## that ability_id gets the behavior. Returns true if cast. (party auto-attack: Identity first.)
func try_identity(m: CharacterBody3D) -> bool:
	var p: Dictionary = m.identity_params
	var kind := String(p.get("kind", ""))
	var skill = _skills.get(kind)
	if skill == null:
		# kind="" = 정당한 없음(정체성 미보유). 비어있지 않은데 미등록 = _SKILL_SCRIPTS 누락 버그 → 시끄럽게.
		if kind != "":
			push_error("[dispatch] identity kind '%s' 미등록 — _SKILL_SCRIPTS 확인 (ab=%s)" % [kind, m.ability_id])
		return false
	# F-008 §3.7 gear potency_mult 옵션 roll → identity 위력(per-cast _coeff). 직전 set이라 공유 dict 순차안전.
	p["_coeff"] = float(m.identity_potency_mult) if "identity_potency_mult" in m else 1.0
	if skill.cast(m, p, Vector3.ZERO, self):
		# F-008 §3.7 gear cd_mult 옵션 roll → identity 쿨다운에 곱(낮을수록 빠름). 1.0 = none.
		var cdm: float = float(m.cooldown_mult) if "cooldown_mult" in m else 1.0
		m.identity_cooldown_s = float(p.get("cooldown_s", 6.0)) * cdm
		# P4a Kit Binding 「표식」 — Beacon 정체성은 시전 시 눈앞의 적에게 표식을 남긴다. 결속=조작 전용
		# (NC 미적용, F-020 §3.3) → is_controlled 게이트. 표식 대상 처치 시 링크 전 슬롯 쿨 감소.
		if m.is_controlled() and BindingOverlays.identity_marks(String(m.base_gear_id), String(m.ability_id)):
			var mk: Dictionary = BindingOverlays.MARK
			var e: CharacterBody3D = nearest_enemy_in_range(m.global_position, float(mk["radius_m"]))
			if e != null:
				m.binding_mark(e, float(mk["window_s"]), float(mk["cd_reduce"]))
		# P4a Kit Binding 「집중」 — 집중은 여기서 씨앗 안 뿌린다. mark_ruin 누커가 **적을 명중할 때마다**(평타
		# _resolve_basic · 정체성 mark_ruin · 서브 _nuker_focus_stack) nuker_focus_accumulate로 seed/stack한다.
		# **is_controlled 무관**(AI 누커도 빌드) — 8m 정체성만 씨앗 뿌리던 조작-전용 방식은 원거리/AI에서 안 떴다. DRIFT-076.
		# P4a 「성역」 — Mend Circle 정체성은 발밑에 좁은 성역을 세운다(스티키 — 유지 중이면 유지, 만료 시 재설치).
		if m.is_controlled() and BindingOverlays.identity_sanctuaries(String(m.base_gear_id), String(m.ability_id)):
			if not m.has_sanctuary():
				var s: Dictionary = BindingOverlays.SANCT
				m.binding_sanctuary(m.global_position, float(s["radius_m"]), float(s["dur"]))
		return true
	return false




## Cross-class coeff for `cid` using a skillbook whose master carries `sub_bands` {classId: band}.
## main class (not listed) → ×1.0 (B0); sub class → its band's coeff. ref: D-016 §3.2 · D-012 §2.4.
func _band_coeff(cid: String, sub_bands: Dictionary) -> float:
	return float(BAND_COEFF.get(String(sub_bands.get(cid, "B0")), 1.0))


## 이 서브가 멤버 클래스의 **주력**인가 — `sub_bands`에 그 클래스가 없으면 main(B0). 결속 변형 게이트로
## 쓴다(비주력 = 밴드 피해 패널티 + 정체성 payoff 없음). ref: D-016 §3.2 · DRIFT-087.
func _is_main_class_sub(member: CharacterBody3D, inst) -> bool:
	var bands: Dictionary = Slice01Data.get_skillbook_master(
			String(inst.get("base_ability_id", ""))).get("sub_bands", {})
	return String(bands.get(String(member.class_id), "B0")) == "B0"


## Player-cast a sub skillbook from slot Q/E/R. Charges + cooldown gated; on success
## -1 charge + set the slot's cooldown. Effect = the Shared AB applied to enemies.
func cast_skillbook(member: CharacterBody3D, slot_index: int, target_pos: Vector3 = Vector3.ZERO, target_unit = null) -> void:
	if member == null or not is_instance_valid(member) or not member.is_alive():
		return
	if member.has_method("is_channeling") and member.is_channeling():
		return   # 집중 채널 중 — 점유(다른 서브 시전 차단)
	var inst = member.get_skillbook(slot_index)
	if inst == null:
		return
	# 「이탈」 패시브 모드(auto_disengage) — 저HP 자동 발동이라 수동 시전 불가. 액티브(누름·패시브 없음)
	# 모드는 flag=false. 효과는 동일(마무리딜+후퇴+어그로↓), 발동 방식만 다름 — 스킬트리 택1 예정.
	if bool(inst.params.get("auto_disengage", false)):
		return
	# 「오프너 은신」 능동 취소(DRIFT-121) — 은신 중 **은신 스킬을 다시 누르면 취소**(토글 오프). 자동
	# 공격이 멈춰 있어 은신을 끝내는 유일한 수단이 「때리는 것」인데, 피해 수단이 전부 쿨·탄약 소진이면
	# 스스로 빠져나올 길이 없다. 차지·쿨 게이트보다 **앞**에 둔다 — 시전 쿨(14s)이 은신(60s)보다 훨씬
	# 짧아 취소가 필요한 구간 대부분이 쿨 중이기 때문. 취소는 **무비용**(차지·쿨 불변)이되 **대기 중인
	# next-hit 증폭은 폐기**한다 — 증폭이 남으면 "은신 → 즉시 취소 → 강화 평타"가 은신을 건너뛰고
	# 보상만 챙기는 경로가 된다. 취소는 탈출구이지 시전 방식이 아니다.
	if bool(inst.params.get("hold_fire", false)) and member.has_method("holds_fire") and member.holds_fire():
		member.break_veil()
		if member.has_method("consume_next_hit_bonus"):
			member.consume_next_hit_bonus()   # 읽고 버림 = 초기화. 다른 소스(AB-006 등)와 곱해진 값도 함께 사라진다
		print("[SB] %s 은신 취소(재입력) — 증폭 폐기" % member.class_id)
		return
	if int(inst.charges) <= 0:
		print("[SB] %s depleted" % inst.get("display_name", "?"))
		return
	if float(inst.cooldown_s) > 0.0:
		return
	# F-009 §3.8 마석 — **슬롯(서브) 스킬 시전만** 소모한다. Identity는 무소모(`I-007` §6): NC 3인이
	# 자동으로 쓰는 채널이라 여기에 자원을 물리면 파티가 통째로 고갈된다.
	# 비용 = 스킬 tier 차등(Basic 1 / Advanced 2 / Master 3 · 사용자 결정 (나)). 고갈은 **의도된 고역**
	# 이지만 소프트락이 아니다 — 거부는 반드시 **사유를 보이게** 한다(조용한 무발동 금지, DRIFT-139 교훈).
	# 차감은 여기서 **선차감하지 않는다**: 아래 charges 선차감과 달리 실제 발현(`_resolve_sub`) 성공 후에
	# 빠져나가야 시전 실패에 자원만 녹는 걸 막는다.
	var ms_cost: int = Slice01Data.manastone_cost_for(String(inst.get("base_ability_id", "")))
	if ms_cost > 0 and not _combat.manastone_unlimited() and _combat.manastone_count() < ms_cost:
		if member.has_method("popup_status"):
			member.popup_status("마석 부족 %d" % ms_cost, Color(0.72, 0.55, 1.0))
		return
	# 은신 해제 시점(DRIFT-121 개정) — 「오프너 은신」(hold_fire)은 **첫 타격까지 유지**한다. 시전 시작에
	# 풀면 긴 캐스트 내내 표적으로 노출돼 "숨어서 준비한다"가 성립하지 않는다(해제는 combat_controller.
	# _deal_damage로 이동 = 증폭 소비와 같은 지점). 자동 공격이 계속되는 도주용 은신(잠행 처치 은신 등)은
	# 종전대로 **시전 = 능동 노출**로 즉시 해제한다 — 그쪽은 캐스팅을 실을 창이 아니라 도망 시간이다.
	if member.has_method("break_veil") and not (member.has_method("holds_fire") and member.holds_fire()):
		member.break_veil()
	# 채널 중 새 스킬을 쓰면 채널을 막지 않고 대신 중단시킨다(이동 중단은 channel_field가 처리).
	# 이 시점은 차지/쿨 검증을 통과해 새 시전이 실제로 진행될 때뿐 — 실패한 시도로는 채널을 끊지 않는다.
	if member.has_method("interrupt_active_channel"):
		member.interrupt_active_channel()
	var p: Dictionary = inst.params
	# D-016 §3.2 / D-012 §2.4 — sub-class use is penalised by identity-distance band (the master's
	# `sub_bands`); main class = full coeff. (was: flat −10% off the first equip class.)
	var bands: Dictionary = Slice01Data.get_skillbook_master(String(inst.get("base_ability_id", ""))).get("sub_bands", {})
	# D-018 §7.3 — affix coeffMult는 cross-class 밴드와 **독립**으로 곱(합산 ≤15% 안전 클램프). cd_trade는 쿨 가산.
	var affix: Dictionary = inst.get("affix", {})
	p["_coeff"] = _band_coeff(String(member.class_id), bands) * (1.0 + clampf(float(affix.get("coeff", 0.0)), -0.15, 0.15))
	p["_slot"] = slot_index   # 캐스트 취소 시 쿨/차지 환급용(skill_cast이 이 슬롯을 되돌림)
	# 단일 대상 잠금(DRIFT-122) — 조준에서 고른 **유닛 자체**를 params로 실어 보낸다(`_coeff`·`_slot`과
	# 같은 주입 경로). `get_skillbook_master`가 deep-duplicate를 주므로 이 dict는 인스턴스 전용 —
	# 다른 캐스터·적 unified 경로로 새지 않는다. 조준점도 **대상의 현재 위치**로 덮어써서, 사거리 밖을
	# 찍어 걸어가서 시전하는 경로(order_move_to 콜백)에서도 그 사이 이동한 대상을 그대로 따라간다.
	p["_target"] = target_unit
	if target_unit != null and is_instance_valid(target_unit):
		target_pos = target_unit.global_position
	var cd: float = float(p.get("cooldown_s", 6.0)) * (1.0 + float(affix.get("cd_trade", 0.0)))
	# P4a 「캐스팅 시간」(DRIFT-075) — cast_s>0이면 캐스트바 진행 후 **완료 시점에** 발현+결속(취소 시 환급).
	# 캐스터(Nuker/DPS/Healer) 스킬은 이 경로가 기본. cast_s=0(즉발)은 아래 즉시 발현.
	var cast_s: float = float(p.get("cast_s", 0.0))
	if cast_s > 0.0:
		inst.charges = int(inst.charges) - 1   # commit — 캐스트 시작에 선차감(취소면 skill_cast이 환급)
		var node = _SkillCast.new()
		add_child(node)
		var pd: Dictionary = p.duplicate()     # 완료 시점 파라미터 고정
		# 쿨은 캐스트 '완료' 시점에 시작(취소 시 미발동·환급) — 캐스트 중엔 is_channeling이 재시전을 막는다.
		# (쿨 시작을 시전에 걸면 캐스트 도중 쿨이 소모돼 cd≈cast_s일 때 '무한쿨'처럼 됨.)
		var on_done := func() -> void:
			_cd_refund_frac = 0.0
			_resolve_sub(member, slot_index, pd, target_pos)
			inst.cooldown_s = cd * (1.0 - _cd_refund_frac)   # ON-KILL-FEED 환급(DRIFT-132)
			_cd_refund_frac = 0.0
		node.setup(member, slot_index, cast_s, self, on_done,
			float(p.get("cast_range_disc_m", 0.0)), _cast_bar_color(String(p.get("kind", ""))),
			_cast_charge_color(p))
		return
	# 즉발 — 발현 성공 시에만 차감.
	_cd_refund_frac = 0.0
	if _resolve_sub(member, slot_index, p, target_pos):
		inst.charges = int(inst.charges) - 1
		inst.cooldown_s = cd * (1.0 - _cd_refund_frac)   # ON-KILL-FEED 환급(DRIFT-132)
	_cd_refund_frac = 0.0


## 슬롯에 꽂힌 서브의 `base_ability_id`(없으면 ""). 마석 비용 조회용.
func _slot_ability_id(member: CharacterBody3D, slot_index: int) -> String:
	var inst = member.get_skillbook(slot_index) if member.has_method("get_skillbook") else null
	return String(inst.get("base_ability_id", "")) if inst != null else ""


## 서브 발현(즉발/캐스트 완료 공용) — effect 실행 + **결속 델타를 발현 시점에** 적용 + 집중 소모 아키타입. 성공 여부 반환.
func _resolve_sub(member: CharacterBody3D, slot_index: int, p: Dictionary, target_pos: Vector3) -> bool:
	var kind := String(p.get("kind", ""))
	var skill = _skills.get(kind)
	if skill == null:
		# kind="" = 정당한 없음. 비어있지 않은데 미등록 = _SKILL_SCRIPTS 누락 버그 → 시끄럽게.
		if kind != "":
			push_error("[dispatch] sub kind '%s' 미등록 — _SKILL_SCRIPTS 확인 (ab=%s)" % [kind, member.ability_id])
		return false
	# F-009 §3.8 마석 — **발현 직전에 원자적으로 차감**한다. `cast_skillbook`의 사전 검사는 긴 캐스트를
	# 헛돌리지 않으려는 빠른 거부일 뿐이고, 실제 소유권 이전은 여기다: 캐스트 도중 다른 멤버가 마석을
	# 써서 그 사이 부족해질 수 있으므로 **발현 직전에 다시 확인**해야 두 번 쓰이지 않는다. 실패하면
	# `skill.cast` 이전이라 아무것도 일어나지 않는다(탄·쿨도 호출부가 성공 시에만 소모).
	var ms: int = Slice01Data.manastone_cost_for(String(_slot_ability_id(member, slot_index)))
	if ms > 0 and not _combat.spend_manastone(ms):
		if member.has_method("popup_status"):
			member.popup_status("마석 부족 %d" % ms, Color(0.72, 0.55, 1.0))
		return false
	if not skill.cast(member, p, target_pos, self):
		return false
	_apply_binding(member, slot_index, target_pos)   # 오버레이 델타(bulwark/mark/focus/flank/…)
	if BindingOverlays.is_focus_spender(String(p.get("kind", ""))):
		_nuker_focus_spend(member)                   # execute-kind → 집중 소모(아키타입)
	return true


## 캐스트바 색 — 힐 계열은 초록, 그 외는 파랑.
func _cast_bar_color(kind: String) -> Color:
	return Color(0.45, 0.9, 0.7) if kind.contains("heal") else Color(0.5, 0.72, 1.0)


## 캐스트 「전격 모으기」 차징 VFX 색 — 전격(lightning) 계열만 charge_up 표시(적 enemy_charge와 동일 톤).
## 그 외(힐·냉기·화염 등)는 투명 → 미표시. ref: skill_cast.charge_color.
func _cast_charge_color(p: Dictionary) -> Color:
	return Color(0.4, 0.7, 1.0, 0.55) if String(p.get("element", "")) == "lightning" else Color(0, 0, 0, 0)


# ============================================================================
# P4a Kit Binding (결속) — resolveEffectiveAbility overlay application (F-020 §3.7). After a base sub
# cast, triple-match the member's LIVE gear + identity + slot sub against the pilot fixtures and apply
# the overlay's runtime DELTA (AB files are NOT cloned). NON-CANONICAL pilot; NC never reaches here
# (cast_skillbook is ally-only). ref: binding_overlays.gd · ROLE-010 §4.5 · QA-005 §2.12.
# ============================================================================

func _apply_binding(member: CharacterBody3D, slot_index: int, target_pos: Vector3) -> void:
	var inst = member.get_skillbook(slot_index)
	if inst == null:
		return
	var ov: Dictionary = BindingOverlays.resolve_effective(
		String(member.base_gear_id), String(member.ability_id),
		String(inst.get("base_ability_id", "")), slot_index)
	if ov.is_empty():
		return
	var pos: Vector3 = member.global_position
	var aim: Vector3 = target_pos if target_pos != Vector3.ZERO else pos
	match String(ov.get("delta", "")):
		# --- March 「진격」: 모든 서브가 밀어내기를 얻고, 이미 밀린 적을 또 밀면 넘어뜨림(캡스톤) ---
		"march_shove":
			_march_shove(member, aim)
		# --- Sentinel 「응보」: 태세 중 쌓인 피격 누적을 서브에 실어 되돌림(태세 밖이면 base만) ---
		"retribution_release":
			_sentinel_retribution(member, aim)
		# --- Anchor 「방벽 충전」: 모든 서브가 방벽 +1(공통 버프) → 세 겹이면 기절(캡스톤) ---
		"bulwark_charge":
			_anchor_stack(member, pos)
		# --- Beacon 「표식」: 모든 서브가 표식 대상에게 추가 위협(상태-조건부). 표식 없으면 base만 ---
		"beacon_mark":
			_beacon_mark_threat(member)
		"beacon_mark_refresh":   # R 도전 선포 — 위협 + 표식 유지 시간 갱신.
			_beacon_mark_threat(member)
			var mk: Dictionary = BindingOverlays.MARK
			member.binding_remark(nearest_enemy_in_range(aim, float(mk["radius_m"])), float(mk["window_s"]))
			# --- Mark&Ruin 「집중」 빌더: 딜링 서브는 집중 대상 명중 시 누적+추가타. 소모는 아키타입 규칙(cast_skillbook) ---
		"focus_dump":   # AB-005 — 레인에 적 1명이면 집중 소모(덤프 처형), 여럿이면 빌드/유지
			if _last_hit_count == 1:
				_nuker_focus_spend(member)
			else:
				_nuker_focus_stack(member, aim)
		"focus_stack":
			_nuker_focus_stack(member, aim)
		"focus_spread":   # E — 누적 추가타 후 집중을 근처 적으로 전이(누적 유지)
			_nuker_focus_stack(member, aim)
			_nuker_focus_spread(member)
			# --- Flank Collapse 「잠행」: 근접화된 링크 스킬이 원래 사거리 비례 이득(1차 뎀 / 2차 쿨감). 처치→은신은 kill 훅 ---
		"flank_strike":
			_nuker_flank_strike(member, slot_index, aim)
		"flank_dash":     # E — 사거리 비례 이득 후 적 반대편으로 원래 사거리만큼 순간 이탈
			_nuker_flank_strike(member, slot_index, aim)
			_nuker_flank_dash(member, slot_index, aim)
		"focus_backstab":   # AB-013 — 집중 2스택 + 캡 도달/이미 캡이면 준 피해만큼 캐스터 보호막(1s)
			_nuker_focus_backstab(member, slot_index, aim)
		"flank_backstab":   # AB-013 — 캐스트 시 특수 없음(사거리 무패널티=aim 분기 / 쿨 초기화=notify_kill)
			pass
			# --- DPS press_line 「초월」: 서브 명중 시 게이지 충전(비발동) / 초월 중이면 서브 강화 변형(겁화·중력·절대영도) ---
		"overdrive_charge":
			_dps_overdrive(member, slot_index, aim, ov)
			# --- DPS arc_weave 「혈풍」: 서브 시전당 HP 대가 + 광역 명중 적 수 비례 회복(3기+ 이득) ---
		"blood_soak":
			_dps_blood_soak(member, slot_index, aim, ov)
			# --- AB-007 이탈 결속(Nuker) ---
		"disengage_focus":   # 집중 — 이탈 마무리 대상에 집중 1스택 누적(처형 준비)
			if _last_hit_target != null and is_instance_valid(_last_hit_target):
				_nuker_focus_stack(member, _last_hit_target.global_position)
		"disengage_veil":    # 잠행 — 이탈 후 은신 유지(평타 정지) + 은신 첫 스킬 강타
			var fk: Dictionary = BindingOverlays.FLANK
			member.apply_veil(float(fk.get("disengage_veil_s", 4.0)), true)
			member.grant_next_hit_bonus(float(fk.get("disengage_bonus", 0.3)))


## Bulwark March 「진격」 — 링크 스킬이 **밀어내기를 얻는다**(원래 넉백이 없어도). 밀린 적에겐 「밀림」이
## 짧게 남고, **그 창 안에 또 밀면 넘어진다**(Rooted). 한 번은 자리만 바뀌지만 연달아 밀면 무너진다 —
## 라인 정리라는 정체성 축(`IDA-022` GEOMETRY·OPENER)을 서브까지 관통시킨 것.
## 대상 = 조준점 주변 적 전부(광역 서브면 그만큼 여럿이 밀린다). ref: BindingOverlays.MARCH.
func _march_shove(member: CharacterBody3D, aim: Vector3) -> void:
	var mc: Dictionary = BindingOverlays.MARCH
	for e in enemies_in_radius(aim, float(mc["radius_m"])):
		if e == null or not is_instance_valid(e):
			continue
		var dir: Vector3 = e.global_position - member.global_position
		dir.y = 0.0
		if dir.length() < 0.05:
			dir = Vector3.FORWARD
		# **밀어내기가 먼저**다. 2타째(캡스톤)에도 밀림은 그대로 일어나고, **밀려난 그 자리에서** 속박이
		# 걸린다(사용자, 2026-08-13) — 속박부터 걸면 "붙잡혔으니 안 밀린다"로 읽혀 진격이라는 축이 죽는다.
		#
		# ⚠️ **「넉백 우선」의 실제 강제 지점은 여기가 아니라 `enemy_ai`의 틱 순서다**(DRIFT-143).
		# `apply_knockback`은 즉시 이동이 아니라 `kb_vel`을 KB_TIME에 걸쳐 미는 예약이라, 이 함수 안에서
		# 순서를 바꿔도 **같은 프레임엔 아무 차이가 없다**. 실제로 순서를 뒤집던 건 적 AI가 기절 게이트를
		# `tick_knockback`보다 먼저 태워 기절 중 넉백이 아예 안 굴러가던 것이었다. 여기 순서는 읽는
		# 사람을 위한 규약 표현이고, 강제는 `enemy_ai._tick_*`가 한다.
		#
		# **CC 중첩:** 서브 자체의 기절과 캡스톤 속박은 **같은 프레임에 나란히** 걸린다(별개 타이머가
		# 동시 진행) → 총 행동불가 = max(기절, 속박)이지 합이 아니다. 순차로 이어붙지 않는다.
		var capstone: bool = e.has_method("is_shoved") and e.is_shoved()
		if e.has_method("apply_knockback"):
			e.apply_knockback(dir.normalized(), float(mc["shove_m"]))
		if capstone:
			# 캡스톤 — 이미 무너진 자세에 한 번 더. 밀어낸 뒤 그 자리에 붙잡고 「밀림」은 소모한다
			# (소모 안 하면 밀 때마다 재속박 = 영구 CC).
			if e.has_method("apply_outcome"):
				e.apply_outcome("Rooted", float(mc["root_s"]))
			if e.has_method("clear_shove"):
				e.clear_shove()
			if e.has_method("popup_status"):
				e.popup_status("넘어짐", Color(1.0, 0.8, 0.35))
		elif e.has_method("apply_shove"):
			e.apply_shove(float(mc["window_s"]))


## Sentinel Form 「응보」 — 태세 중 받아 낸 피해가 `_retribution`에 쌓여 있다. 링크 서브를 쓰면 그 누적을
## **전부 꺼내** 조준점 주변 적에게 실어 보낸다. 태세 밖이면 누적이 0이라 아무 일도 없다(= base 스킬만).
## 캐스터 max_hp 기준 상한으로 폭주를 막는다 — 장시간 얻어맞은 뒤 한 방에 쏟는 걸 제한.
func _sentinel_retribution(member: CharacterBody3D, aim: Vector3) -> void:
	if not member.has_method("retribution_take"):
		return
	var rc: Dictionary = BindingOverlays.RETRIB
	var pool: float = float(member.retribution_take())
	if pool <= 0.0:
		return
	var dmg: float = minf(pool * float(rc["release_mult"]), float(member.max_hp) * float(rc["cap_mult"]))
	if dmg <= 0.0:
		return
	var hit := false
	for e in enemies_in_radius(aim, float(rc["radius_m"])):
		if e != null and is_instance_valid(e):
			deal_damage(e, member, dmg)
			hit = true
	if hit and member.has_method("popup_status"):
		member.popup_status("응보 %d" % int(dmg), Color(1.0, 0.75, 0.35))


## Anchor 「방벽 충전」 — add a BulwarkCharge; on the 3-stack consume, stun the nearest enemy (capstone).
func _anchor_stack(member: CharacterBody3D, pos: Vector3) -> void:
	var b: Dictionary = BindingOverlays.BULWARK
	if member.binding_bulwark_add(int(b["stacks_needed"]), float(b["icd_s"])):
		var e: CharacterBody3D = nearest_enemy_in_range(pos, float(b["radius_m"]))
		if e != null and e.has_method("apply_stun"):
			# F-030 MagnitudeScale — doctrine이 이 **1회 페이오프의 배율만** 올려 뒀을 수 있다(DOC-TNK-02-T2).
			var mult: float = float(member.get("bulwark_payoff_mult"))
			e.apply_stun(float(b["stun_s"]) * mult)
			if mult != 1.0:
				member.bulwark_payoff_mult = 1.0
				member.popup_status("복귀 정산 ×%.1f" % mult, Color(0.75, 0.9, 1.0))


## Beacon 「표식」 — 규약의 상태-조건부 버프: 유효한 표식 대상이 있을 때만 그 대상에게 추가 위협을 얹는다.
## 표식이 없으면(정체성이 아직 안 남겼거나 대상 사망) 아무것도 하지 않는다 → base 스킬만 발현.
func _beacon_mark_threat(member: CharacterBody3D) -> void:
	var e = member.get_marked_enemy()
	if e == null:
		return
	var t: float = float(BindingOverlays.MARK["threat"])
	if e.has_method("add_threat"):
		e.add_threat(member, t)
	if e.has_method("set_threat_floor"):
		e.set_threat_floor(member, t)


## Mark&Ruin 「집중」 빌드(공용·ungated) — mark_ruin 누커가 enemy를 명중하면 그 적에게 집중을 seed/stack.
## **is_controlled 무관**(조작/AI 공통) — AI 누커도 평타·정체성 명중으로 집중을 쌓아 🎯 표시(소모=execute만
## 서브라 자연히 조작 전용). 반환 = 이 명중에 곱할 증폭 배수(1.0 + 누적×pct); 집중-누커 아니거나 무효 대상이면
## 1.0(무증폭). 평타(_resolve_basic)·정체성(mark_ruin)·서브(_nuker_focus_stack)가 각자 자기 딜에 곱한다. DRIFT-076.
func nuker_focus_accumulate(member, enemy) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return 1.0
	if String(member.class_id) != "Nuker" \
			or not BindingOverlays.identity_focuses(String(member.base_gear_id), String(member.ability_id)):
		return 1.0
	var f: Dictionary = BindingOverlays.FOCUS
	if member.get_focus_enemy() != enemy:
		member.binding_focus(enemy, float(f["window_s"]))   # 새/다른 대상 → 집중 재설정(스택 0부터 재누적)
	var stacks: int = member.binding_focus_add(int(f["stack_cap"]), float(f["window_s"]))
	return 1.0 + float(stacks) * float(f["stack_dmg_pct"])


## 「집중」 딜링 서브(전격/공허창) — 조준 지점 근접 적(seed_radius_m)을 명중 대상으로 삼아 집중 빌드 후,
## 증폭분을 진홍 추가타로 가시화(서브는 discrete 캐스트라 페이오프를 팝업으로 강조). 근처 적 없으면 no-op.
func _nuker_focus_stack(member: CharacterBody3D, aim: Vector3) -> void:
	var f: Dictionary = BindingOverlays.FOCUS
	var hit: CharacterBody3D = nearest_enemy_in_range(aim, float(f["seed_radius_m"]))
	if hit == null:
		return
	var bonus: float = (nuker_focus_accumulate(member, hit) - 1.0) * member.basic_damage
	if bonus > 0.0:
		deal_damage(hit, member, bonus)
		if hit.has_method("popup_status"):   # C — 증폭 추가타를 진홍 숫자로(스택 클수록 커짐 → 증폭 가시화)
			hit.popup_status("+%d" % int(round(bonus)), Color(1.0, 0.35, 0.3))


## Mark&Ruin 「집중」 소모 아키타입 — 스택-소모 계열 스킬을 쓰면 쌓인 집중을 모두 소모해 누적 수 비례 폭발.
## 캡스톤은 특정 처형 스킬이 아니라 카테고리 규칙(is_focus_spender). 집중 대상은 유지(살아있으면) → 재누적·재소모
## 가능. 집중이 없거나 누적 0이면 아무 일도 없음(순수 base 스킬만). ref: binding_overlays.gd FOCUS_SPEND_KINDS.
func _nuker_focus_spend(member: CharacterBody3D) -> void:
	if not member.has_focus():
		return
	var e = member.get_focus_enemy()
	var stacks: int = member.binding_focus_take()   # 누적 소모(0으로) — 집중 대상은 유지
	if e != null and stacks > 0:
		var burst: float = float(stacks) * float(BindingOverlays.FOCUS["spend_mult"]) * member.basic_damage
		deal_damage(e, member, burst)
		SkillVfx.mark_ruin(self, e.global_position)
		if e.has_method("popup_status"):   # B+C — 소모 스택 수 + 폭발 피해를 금색 팝업으로(페이오프 가시화)
			e.popup_status("집중 %d ⟶ %d" % [stacks, int(round(burst))], Color(1.0, 0.82, 0.3))


## Mark&Ruin 「집중」 E(공허창) — 누적 추가타 후 현재 집중을 근처(spread_m) 다른 적으로 전이(누적 유지). 근처 없으면 유지.
func _nuker_focus_spread(member: CharacterBody3D) -> void:
	var cur = member.get_focus_enemy()
	if cur == null:
		return
	var best: CharacterBody3D = null
	var best_d: float = INF
	for e in enemies_in_radius(cur.global_position, float(BindingOverlays.FOCUS["spread_m"])):
		if e == cur or e == null or not is_instance_valid(e):
			continue
		var d: float = e.global_position.distance_to(cur.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best != null:
		member.binding_focus_transfer(best)


## Flank Collapse 「잠행」 링크 서브 — 근접화(사거리는 aim_controller가 melee로 강제)된 대가로 원래 range_band에
## 비례한 이득: 1차 = 추가 피해(주 대상), 2차 = 이 슬롯 재사용 즉시 감소. 처치→은신은 kill 훅(notify_kill)이 별도.
func _nuker_flank_strike(member: CharacterBody3D, slot_index: int, aim: Vector3) -> void:
	var inst = member.get_skillbook(slot_index)
	if inst == null:
		return
	var band := String(Slice01Data.get_skillbook_master(String(inst.get("base_ability_id", ""))).get("range_band", "Mid"))
	var fl: Dictionary = BindingOverlays.FLANK
	var dmg_pct: float = float(fl["band_dmg"].get(band, 0.0))
	var cd_pct: float = float(fl["band_cd"].get(band, 0.0))
	if dmg_pct > 0.0:                                   # 1차: 원거리일수록 큰 추가 피해 → 조준점 근처 주 대상
		var e = nearest_enemy_in_range(aim, 3.0)
		if e != null:
			var bonus: float = dmg_pct * member.basic_damage
			deal_damage(e, member, bonus)
			if e.has_method("popup_status"):
				e.popup_status("+%d" % int(round(bonus)), Color(1.0, 0.35, 0.3))
	if cd_pct > 0.0:                                    # 2차: 재사용 감소(먼 사거리일수록 큼)
		inst.cooldown_s = float(inst.cooldown_s) * (1.0 - cd_pct)


## Flank Collapse 「잠행」 E(공허창) — 발현 후 적의 반대편으로 **짧은 고정 거리(FLANK.dash_m)**만큼 순간 이탈(암살
## 후 짧게 빠지기). 원래 서브 사거리(공허창 15m)를 쓰면 맵을 가로질러 튕겨 나가 너무 멀었음. DRIFT-076.
func _nuker_flank_dash(member: CharacterBody3D, _slot_index: int, aim: Vector3) -> void:
	var tgt = nearest_enemy_in_range(aim, 6.0)
	var away: Vector3 = member.global_position - (tgt.global_position if tgt != null else aim)
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(0, 0, -1)
	var start: Vector3 = member.global_position
	member.global_position += away.normalized() * float(BindingOverlays.FLANK["dash_m"])
	SkillVfx.dash_streak(self, start, member.global_position, Color(0.7, 0.4, 0.5))


## AB-013 Backstab Dash 「집중」 변주 — 명중 대상에 집중 **2스택** + 캡 도달/이미 캡이면 **준 피해만큼 캐스터
## 보호막(1s)**(돌진 리스크 상쇄 보상). 돌진이 방금 명중한 대상(report_hit_target) 우선.
func _nuker_focus_backstab(member: CharacterBody3D, slot_index: int, aim: Vector3) -> void:
	var f: Dictionary = BindingOverlays.FOCUS
	var hit = _last_hit_target if (_last_hit_target != null and is_instance_valid(_last_hit_target)) else nearest_enemy_in_range(aim, float(f["seed_radius_m"]))
	if hit == null or not is_instance_valid(hit):
		return
	var cap: int = int(f["stack_cap"])
	if member.get_focus_enemy() != hit:
		member.binding_focus(hit, float(f["window_s"]))   # 새/다른 대상 → 집중 재설정(0부터)
	member.binding_focus_add(cap, float(f["window_s"]))                       # +1
	var stacks: int = member.binding_focus_add(cap, float(f["window_s"]))    # +1 → 총 2스택(캡 클램프)
	var bonus: float = float(stacks) * float(f["stack_dmg_pct"]) * member.basic_damage
	if bonus > 0.0:
		deal_damage(hit, member, bonus)
		if hit.has_method("popup_status"):
			hit.popup_status("+%d" % int(round(bonus)), Color(1.0, 0.35, 0.3))
	if stacks >= cap:   # 이 스킬로 max 도달 or 이미 max 대상 → 캐스터 보호막(준 피해만큼, 1s)
		var inst = member.get_skillbook(slot_index)
		var master: Dictionary = Slice01Data.get_skillbook_master(String(inst.get("base_ability_id", "")) if inst != null else "")
		var shield_amt: float = float(master.get("cast", {}).get("damage_mult", 1.5)) * member.basic_damage
		member.add_shield(shield_amt, 1.0)
		if member.has_method("popup_status"):
			member.popup_status("보호막 +%d" % int(round(shield_amt)), Color(0.55, 0.85, 1.0))


# ============================================================================
# DPS Kit Binding — 「초월(Overdrive)」 / 「혈풍(Blood Gale)」. 서브가 애초에 광역(fire 원형·beam 라인·cold 원형)
# 이라 스플래시 강제 없이 자연 성립. 강화 = 효과 변화(카르마 Mantra식): fire→화상 / beam→끌기 / cold→빙결.
# 조작/AI 공통(is_controlled 무관). ref: binding_overlays.gd OVERDRIVE/BLOODGALE · docs/design/dps_binding_kit.md.
# ============================================================================

## 「초월」 서브 델타 — 명중 게이지를 충전(명중 적 수 비례, 광역이 빨리 참)하고, 이번 시전이 게이지를 채웠다면
## 같은 시전에서 즉시 강화 변형을 실행(충전 완료 = 그 시전이 폭주 — 오프바이원 없음). 조작/AI 공통.
func _dps_overdrive(member: CharacterBody3D, slot_index: int, aim: Vector3, ov: Dictionary) -> void:
	var od: Dictionary = BindingOverlays.OVERDRIVE
	var hits: int = clampi(_count_sub_hits(member, slot_index, aim), 1, int(od["hits_cap"]))
	member.overdrive_add(float(od["sub_gain"]) * float(hits), float(od["gauge_max"]))
	# **소모는 강화가 실제로 발현됐을 때만**(사용자 결정 2026-07-20, DRIFT-087). 예전엔 무조건 reset이라
	# 비주력 서브·변형 미저작 서브가 아무 이득 없이 초월을 날렸다("소모했는데 아무 일도 안 일어남").
	if member.overdrive_is_active() and _dps_overdrive_empower(member, slot_index, aim, od, ov):
		member.overdrive_reset()   # 강화 1회 = 초월 소모


## 「초월」 강화 변형(발동 중 서브) — **BIND 항목의 `variant`로 분기(AB 단 지정)**. kind로 분기하면 같은 kind의
## 두 번째 AB를 등록하는 순간 구분이 불가능해진다(볼트 8종·존 5종 등) — 원형/변형 체계와 충돌. DRIFT-085.
## 전부 대상 한정이라 아군 무피해(장판 대신 화상 DoT).
## **반환 = 강화가 실제로 발현됐나** — false면 호출부가 초월을 소모하지 않는다(비주력·변형 미저작).
func _dps_overdrive_empower(member: CharacterBody3D, slot_index: int, aim: Vector3, od: Dictionary, ov: Dictionary) -> bool:
	var inst = member.get_skillbook(slot_index)
	if inst == null:
		return false
	# 비주력(서브 클래스) 서브에는 강화 변형을 붙이지 않는다 — 게이지는 차되 폭주 시 base 그대로(사용자
	# 결정 2026-07-19, DRIFT-087). 밴드 패널티(피해 −%)에 더해 "정체성 payoff 자체가 없다"는 2차 벽.
	if not _is_main_class_sub(member, inst):
		return false   # 초월 미소모 — 발현이 없으니 아껴 뒀다가 주력 서브에 쓴다
	var variant := String(ov.get("variant", ""))
	var r: float = float(inst.params.get("radius_m", 2.5)) + float(od["radius_bonus_m"])
	match variant:
		"burn":               # 겁화 — 명중 적에게 화상(Ignited) 지속딜(장판 아님 = 아군 무피해)
			var dps: float = float(od["burn_dps_pct"]) * member.basic_damage
			for e in enemies_in_radius(aim, r):
				if e.has_method("apply_outcome"):
					e.apply_outcome("Ignited", float(od["burn_dur"]), dps)
			SkillVfx.telegraph(self, aim, Color(1.0, 0.35, 0.1), r)
		"freeze":             # 절대영도 — 감속(Chilled)을 빙결(Rooted)로 격상 + 반경 확대
			for e in enemies_in_radius(aim, r):
				if e.has_method("apply_outcome"):
					e.apply_outcome("Rooted", float(od["cold_root_s"]))
			SkillVfx.telegraph(self, aim, Color(0.6, 0.9, 1.0), r)
		"gravity":            # 중력 광선 — 빔 원뿔 내 적을 빔 중심선으로 끌어당김(군집화)
			_dps_overdrive_beam_pull(member, aim, od)
		"silence":            # 감전 폭주 — 명중 적을 침묵(액티브 캐스트 봉쇄). AB-044 Hush Ward와 동일 API 재사용.
			for e in enemies_in_radius(aim, r):
				if e.has_method("apply_silence"):
					e.apply_silence(float(od["bolt_silence_s"]))
			SkillVfx.telegraph(self, aim, Color(0.62, 0.42, 0.95), r)
		"safeslick":          # 아군 안심 기름 — 초월 중 aim에 깐 Oil zone을 아군 무해로(미끄럼·피해 전부 + 직후 RX). F-021 예외(DRIFT-094).
			var faction := "party_member" if member.is_in_group("party_member") else "enemy"
			var tagged := false
			for z in get_tree().get_nodes_in_group("ground_zone"):
				if z.is_active() and String(z.status) == "Oil" and z.has_method("set_friendly_safe"):
					var d := Vector2(z.global_position.x - aim.x, z.global_position.z - aim.z)
					if d.length() <= r:
						z.set_friendly_safe(faction)
						tagged = true
			if not tagged:
				return false   # aim에 Oil 없음(장판 미형성) → 초월 미소모
			SkillVfx.telegraph(self, aim, Color(0.25, 0.95, 0.85), r)
		"venom":              # 맹독 폭주 — 초월 중 독 스택 폭증 + 독 zone 잔류(payoff). base/적/비초월엔 zone 없음.
			var pdps: float = float(inst.params.get("poison_dps", 8.0))
			var pcap: float = pdps * float(inst.params.get("poison_stack_cap", 5))
			for e in enemies_in_radius(aim, r):
				if e.has_method("apply_poison_stack"):
					e.apply_poison_stack(float(inst.params.get("poison_dur_s", 8.0)), pdps * float(od["poison_overdrive_stacks"]), pcap, pdps)
			var zttl: float = float(inst.params.get("zone_ttl_s", 0.0))   # 독장판 = 초월 결속 payoff(체류 시 3s마다 스택↑)
			if zttl > 0.0:
				spawn_zone("ToxicGas", aim, float(inst.params.get("zone_radius_m", 5.0)), pdps, zttl, member)
			SkillVfx.telegraph(self, aim, Color(0.4, 0.85, 0.3), r)
		"":                   # 기본 델타(GENERIC) = 게이지 충전만 — 강화 변형 저작 전. 정상 상태(DRIFT-087).
			return false      # 초월 미소모
		_:                    # OVERLAYS 항목인데 variant가 미구현 = 저작 버그 → 시끄럽게(DRIFT-084 규약)
			push_error("[binding] 초월 variant '%s' 미구현 — BIND=%s ab=%s"
					% [variant, String(ov.get("id", "?")), String(inst.get("base_ability_id", "?"))])
			return false
	return true


## 중력 광선 — 빔 방향(member→aim) 원뿔 내 적을 각자 빔 축선의 최근접점으로 끌어당긴다(넉백 역방향).
func _dps_overdrive_beam_pull(member: CharacterBody3D, aim: Vector3, od: Dictionary) -> void:
	var dir: Vector3 = aim - member.global_position
	dir.y = 0.0
	if dir.length() < 0.1:
		return
	dir = dir.normalized()
	var range_m := 16.0
	for e in enemies_in_cone(member.global_position, dir, range_m, deg_to_rad(float(od["beam_half_deg"]))):
		if not e.has_method("apply_knockback"):
			continue
		var to: Vector3 = e.global_position - member.global_position
		to.y = 0.0
		var along: float = clampf(to.dot(dir), 0.0, range_m)
		var pull: Vector3 = (member.global_position + dir * along) - e.global_position
		pull.y = 0.0
		if pull.length() > 0.05:
			e.apply_knockback(pull.normalized(), minf(float(od["beam_pull_m"]), pull.length()))


## 「혈풍」 서브 델타 — HP 대가 소모 + 명중 적 수 비례 회복(3기+ 순이득). **서브별 변형**(kind 분기, 초월과 대칭):
## fire=흡수 폭발(기본 회복) / beam=흡혈 광선(채널 사이펀 → 회복 증폭) / cold=혈빙(과회복분 임시 보호막).
func _dps_blood_soak(member: CharacterBody3D, slot_index: int, aim: Vector3, ov: Dictionary) -> void:
	var inst = member.get_skillbook(slot_index)
	if inst == null:
		return
	var bg: Dictionary = BindingOverlays.BLOODGALE
	var variant := String(ov.get("variant", ""))   # AB 단 지정(BIND 항목) — kind 분기 아님. DRIFT-085.
	var cost: float = float(bg["hp_cost_pct"]) * member.max_hp
	var hits: Array = _sub_hit_enemies(member, slot_index, aim)
	var base_refund: float = float(bg["refund_pct"]) * member.max_hp * float(hits.size())
	# 흡혈 연출 — 맞은 적들에서 붉은 오브가 시전자로 빨려들며 흡수(회복 있을 때만). ref: SkillVfx.blood_siphon.
	if not hits.is_empty():
		var srcs: Array = []
		for e in hits:
			if e != null and is_instance_valid(e):
				srcs.append(e.global_position)
		if not srcs.is_empty():
			SkillVfx.blood_siphon(self, srcs, member.global_position)
	match variant:
		"siphon":           # 흡혈 광선 — 채널 사이펀: 회복 증폭
			member.blood_soak(cost, base_refund * float(bg["beam_refund_mult"]), float(bg["hp_floor"]))
		"iceblood":         # 혈빙 — 과회복(max_hp 초과)분을 임시 보호막으로
			member.blood_soak(cost, base_refund, float(bg["hp_floor"]), float(bg["shield_dur"]))
		"burst":            # 흡수 폭발 — 기본 회복(작열·독 살포)
			member.blood_soak(cost, base_refund, float(bg["hp_floor"]))
		_:                  # variant 미구현 — 기본 회복으로 살리되 시끄럽게(DRIFT-084 규약).
			member.blood_soak(cost, base_refund, float(bg["hp_floor"]))   # GENERIC 기본은 "burst"라 여기 안 옴
			push_error("[binding] 혈풍 variant '%s' 미구현 — BIND=%s ab=%s"
					% [variant, String(ov.get("id", "?")), String(inst.get("base_ability_id", "?"))])


## 서브가 실제로 때린 적 목록 — fire/cold는 명중점 반경, beam은 원뿔 근사. 초월 충전량/혈풍 회복·흡혈 VFX 공용.
func _sub_hit_enemies(member: CharacterBody3D, slot_index: int, aim: Vector3) -> Array:
	var inst = member.get_skillbook(slot_index)
	if inst == null:
		return []
	var kind := String(inst.params.get("kind", ""))
	# 채널링 — line/cone은 원뿔 판정(cone은 **최대 사거리** 기준 = 완주해야 닿는 범위), cloud/nova는 원형.
	if kind == "skillbook_channeling":
		var cshape := String(inst.params.get("channel_shape", "line"))
		if cshape == "cloud":
			return enemies_in_radius(aim, float(inst.params.get("radius_m", 3.0)))
		if cshape == "nova":
			return enemies_in_radius(member.global_position, float(inst.params.get("radius_m", 5.0)))
		var dir: Vector3 = aim - member.global_position
		dir.y = 0.0
		if dir.length() < 0.1:
			return []
		return enemies_in_cone(member.global_position, dir.normalized(),
			float(inst.params.get("range_m", 14.0)), deg_to_rad(float(inst.params.get("half_deg", 7.0))))
	return enemies_in_radius(aim, float(inst.params.get("radius_m", 2.5)))


## 서브가 실제로 때린 적 수 — 초월 충전량/혈풍 회복 정산 공용.
func _count_sub_hits(member: CharacterBody3D, slot_index: int, aim: Vector3) -> int:
	return _sub_hit_enemies(member, slot_index, aim).size()


## DPS 「초월」 평타 게이지 빌드 — press_line 정체성 평타 명중마다 충전(발동 중엔 무시). combat_controller._resolve_basic 호출.
func dps_overdrive_on_basic(member: CharacterBody3D) -> void:
	if String(member.class_id) != "DPS" \
			or not BindingOverlays.identity_overdrive(String(member.base_gear_id), String(member.ability_id)):
		return
	var od: Dictionary = BindingOverlays.OVERDRIVE
	member.overdrive_add(float(od["basic_gain"]), float(od["gauge_max"]))


# ============================================================================
# ctx facade — drop-in skills call these (shared systems stay single-owned).
# ============================================================================

## PILOT — skill effect instance by kind (CastContext routes enemy UNIFIED casts through the same
## effects the ally uses — one definition, two front-ends). ref: cast_context.gd.
func skill_for(kind: String):
	return _skills.get(kind, null)


## 이펙트가 이번 캐스트로 때린 적 수 보고 — focus_dump(AB-005)가 단일/광역을 판정하는 데 사용.
func report_hit_count(n: int) -> void:
	_last_hit_count = n


func report_hit_target(t: CharacterBody3D) -> void:
	_last_hit_target = t


## 이번 서브 해소가 「처치 보상」으로 남은 쿨의 frac(0~1)을 돌려받는다고 보고. 디스패처가 쿨 설정 직후 적용.
func report_cd_refund(frac: float) -> void:
	_cd_refund_frac = maxf(_cd_refund_frac, clampf(frac, 0.0, 1.0))


func enemies_in_radius(pos: Vector3, r: float) -> Array:
	return _combat._enemies_in_radius(pos, r)


func nearest_enemy_in_range(pos: Vector3, r: float) -> CharacterBody3D:
	return _combat._nearest_enemy_in_range(pos, r)


func enemies_in_cone(pos: Vector3, axis: Vector3, r: float, half: float) -> Array:
	return _combat._enemies_in_cone(pos, axis, r, half)


func enemies_in_rect(pos: Vector3, axis: Vector3, length: float, half_width: float) -> Array:
	return _combat._enemies_in_rect(pos, axis, length, half_width)


func lowest_hp_enemy_in_radius(pos: Vector3, r: float) -> CharacterBody3D:
	return _combat._lowest_hp_enemy_in_radius(pos, r)


func allies_in_radius(pos: Vector3, r: float) -> Array:
	return _combat._allies_in_radius(pos, r)


func deal_damage(e: CharacterBody3D, source: CharacterBody3D, dmg: float) -> void:
	_combat._deal_damage(e, source, dmg)


## 단일 대상 잠금 해소(DRIFT-122) — `single_target` 스킬은 조준에서 **클릭한 유닛**이 곧 대상이다.
## 잠금이 없거나(적 시전·AI) 대상이 사라졌으면 종전 근접 줍기로 떨어진다 — 조용한 무발동을 만들지 않는다.
func resolve_target(p: Dictionary, center: Vector3, radius: float) -> CharacterBody3D:
	var t = p.get("_target")
	if bool(p.get("single_target", false)) and t != null and is_instance_valid(t) \
			and (not t.has_method("is_alive") or t.is_alive()):
		return t
	return nearest_enemy_in_range(center, radius)


## 광역 형태(pin·vulnerable)의 잠금판 — 잠겼으면 그 하나만, 아니면 종전 반경 전체.
func resolve_targets(p: Dictionary, center: Vector3, radius: float) -> Array:
	var t = p.get("_target")
	if bool(p.get("single_target", false)) and t != null and is_instance_valid(t) \
			and (not t.has_method("is_alive") or t.is_alive()):
		return [t]
	return enemies_in_radius(center, radius)


## AB-007 이탈 — 이 시전자의 전 적 위협을 frac만큼 감소(어그로 흘리기). 아군 전용(적 CastContext는 no-op).
func reduce_threat(caster: CharacterBody3D, frac: float) -> void:
	var k := clampf(1.0 - frac, 0.0, 1.0)
	for e in _combat._enemies:
		if is_instance_valid(e) and e.has_method("scale_threat"):
			e.scale_threat(caster, k)


# AB-007 이탈 auto-trigger(아군) — HP가 trigger_frac 아래로 교차 시 1회 발동(회복 후 재무장). 적은 enemy_ai가 구동.
var _disengage_armed: Dictionary = {}   # member → 재무장 상태(회복 시 true, 발동 시 false)

## combat_controller가 매 틱 호출 — 저HP 아군의 이탈 서브(skillbook_blink+auto_disengage)를 저절로 발동.
func tick_ally_disengage(party: Array) -> void:
	for m in party:
		if not is_instance_valid(m) or not m.is_alive():
			continue
		var slot := _auto_disengage_slot(m)
		if slot < 0:
			continue
		var inst = m.get_skillbook(slot)
		var frac: float = float(m.hp) / maxf(float(m.max_hp), 1.0)
		var armed: bool = bool(_disengage_armed.get(m, true))
		if armed and frac < float(inst.params.get("trigger_frac", 0.4)) \
				and float(inst.cooldown_s) <= 0.0 and int(inst.charges) > 0:
			_disengage_armed[m] = false
			var p: Dictionary = inst.params.duplicate()
			p["_coeff"] = 1.0
			p["_slot"] = slot
			_resolve_sub(m, slot, p, m.global_position)   # 효과 + 결속(집중/잠행) 적용
			inst.charges = int(inst.charges) - 1
			inst.cooldown_s = float(inst.params.get("cooldown_s", 8.0))
		elif not armed and frac > float(inst.params.get("rearm_frac", 0.45)):
			_disengage_armed[m] = true


## 멤버의 auto-disengage 서브 슬롯(skillbook_blink + auto_disengage) — 없으면 -1.
func _auto_disengage_slot(m: CharacterBody3D) -> int:
	for i in range(3):
		var inst = m.get_skillbook(i)
		if inst != null and String(inst.params.get("kind", "")) == "skillbook_blink" \
				and bool(inst.params.get("auto_disengage", false)):
			return i
	return -1


func heal_threat(healer: CharacterBody3D, ally: CharacterBody3D, eff: float) -> void:
	_combat._heal_threat(healer, ally, eff)


## 치유 choke — 즉시 치유. healer가 「지속 치유」(IDA-031) 정체성이면 즉시 회복 대신 HoT로 전환(총량×total_mult, dur초).
## 반환 = 위협 계산용 회복량(즉시=실효, HoT=예정 총량). 전환은 기존 apply_regen 재사용(pct=총량/(maxHP·dur)). 신규 상태 없음.
func deal_heal(target, healer, amount: float) -> float:
	if healer != null and BindingOverlays.identity_dot_heals(String(healer.base_gear_id), String(healer.ability_id)):
		var d: Dictionary = BindingOverlays.DOT
		var total: float = amount * float(d["total_mult"])
		var dur: float = float(d["dur"])
		if target != null and target.has_method("apply_regen") and float(target.max_hp) > 0.0:
			target.apply_regen(total / (float(target.max_hp) * dur), dur)
		return total
	# 성역(IDA-026) 안에서 시전 → 회복량 증폭. 증폭 발생 시 "기본 + 성역 버프" 분리 표기(직관적 파악).
	var amped: float = _sanctuary_amp(healer, amount)
	if target == null or not target.has_method("heal"):
		return 0.0
	var healed: float = target.heal(amped)
	if amped > amount + 0.5 and healed > 0.5 and target.has_method("popup_heal_split"):
		var base_h: float = healed * (amount / amped)     # 실효 회복 중 기본분
		target.popup_heal_split(base_h, healed - base_h)  # 초록 기본 + 금빛 성역 버프
	return healed


## 치유 choke — HoT(재생) 계열. 「지속 치유」면 총 회복량 × total_mult, 「성역」 안 시전이면 × amp 로 강화(pct_per_s 배수).
## base 와 성역 추가분(bonus)을 분리해 넘긴다 → HoT 틱마다 초록/금색으로 나눠 표기(직관적 파악).
func deal_regen(target, healer, pct_per_s: float, dur: float) -> void:
	var p: float = pct_per_s
	if healer != null and BindingOverlays.identity_dot_heals(String(healer.base_gear_id), String(healer.ability_id)):
		p *= float(BindingOverlays.DOT["total_mult"])
	var amped: float = _sanctuary_amp(healer, p)   # 성역 안 시전 → 증폭
	if target != null and target.has_method("apply_regen"):
		target.apply_regen(p, dur, amped - p)      # base=p, bonus=성역 추가분(틱마다 금색 분리)


## 성역(Mend Circle IDA-026) 증폭 — 성역 정체성 + 시전자가 성역 안에 있을 때만 치유값을 amp배. 밖이면 그대로.
func _sanctuary_amp(healer, value: float) -> float:
	if healer != null and healer.has_method("in_sanctuary") \
			and BindingOverlays.identity_sanctuaries(String(healer.base_gear_id), String(healer.ability_id)) \
			and healer.in_sanctuary():
		return value * float(BindingOverlays.SANCT["amp"])
	return value


func shake(trauma: float) -> void:
	_combat.camera_shake.emit(trauma, Vector3.ZERO)


## SUB hit-feel: ONE shake per cast, scaled by damage_mult (capped). Skills call after impact.
func sub_shake(p: Dictionary) -> void:
	var t: float = clampf(float(p.get("damage_mult", 1.0)) / SUB_SHAKE_MULT_REF, 0.0, HIT_SHAKE_CAP)
	_combat.camera_shake.emit(t, Vector3.ZERO)


func damage_destructibles(pos: Vector3, r: float, dmg: float) -> bool:
	return _reactions.damage_destructibles(pos, r, dmg)


func fire_hit(center: Vector3, r: float, depth: int, source: Node = null) -> void:
	_reactions.fire_hit(center, r, depth, source)


## Spawn a medium ground zone (party spawn-zone subs: AB-009/036/039/040/042/043).
func spawn_zone(medium: String, pos: Vector3, radius: float, dps: float, ttl: float, source: Node = null, opts: Dictionary = {}) -> void:
	_reactions.spawn_zone(medium, pos, radius, dps, ttl, source, opts)


## Emit a ColdDamageHit at a point (party Glacial Bolt, AB-041) → Cold RX (Water→Ice, Veg→Slowed).
func cold_hit(center: Vector3, radius: float, source: Node = null) -> void:
	_reactions.emit_event("ColdDamageHit", {"position": center, "radius": radius, "source": source})


## Emit a LightningHit at a point (party Rending Beam, AB-054) → Shock RX (Water/Steam conduct).
func lightning_hit(center: Vector3, radius: float, source: Node = null) -> void:
	_reactions.emit_event("LightningHit", {"position": center, "radius": radius, "source": source})


## **속성 타격 seam (DRIFT-088)** — AB의 `element`가 타격 시점에 두 가지를 한다:
##   ① **즉시 효과**: 맞은 대상에게 속성 상태를 직접 부여(무조건).
##   ② **RX 이벤트**: 반응계로 넘긴다 → **조건부** 효과는 거기서만 발현(예: fire는 여기서 Ignited를
##      걸지 않고, 가연 대상에서 RX가 점화시킨다).
## 표에 없는 속성(slag·void 등)은 둘 다 없음 = 무반응(의도). `targets` = 이번 타격이 실제로 때린 적들.
func element_hit(element: String, center: Vector3, radius: float, source: Node, p: Dictionary, targets: Array = []) -> void:
	var e: Dictionary = Elements.of(element)
	if e.is_empty():
		return
	var oc := String(e.get("outcome", ""))          # ① 즉시 효과
	if oc != "":
		var dur := float(p.get(String(e.get("dur_key", "")), float(e.get("dur_default", 0.0))))
		if dur > 0.0:
			for t in targets:
				if t != null and is_instance_valid(t) and t.has_method("apply_outcome"):
					t.apply_outcome(oc, dur)
	var rx := String(e.get("rx", ""))               # ② RX — 조건부 효과의 입구
	if rx == "":
		return
	if String(e.get("scope", "area")) == "per_target":
		var pr := float(e.get("per_target_radius_m", 1.2))   # 대상 발치마다 → 전도 판정이 개별 성립
		for t in targets:
			if t != null and is_instance_valid(t):
				_emit_element_rx(rx, t.global_position, pr, source)
	else:
		_emit_element_rx(rx, center, radius, source)


## RX 이벤트 발신 — 불만 전용 진입점(`fire_hit`)이 기름 연쇄 depth를 다루므로 그쪽으로 위임한다.
func _emit_element_rx(rx: String, pos: Vector3, radius: float, source: Node) -> void:
	if rx == "FireDamageHit":
		fire_hit(pos, radius, 0, source)
	else:
		_reactions.emit_event(rx, {"position": pos, "radius": radius, "source": source})


## Spawn a Rampart Barrier (AB-034) — a destructible forward wall. Parented under the dispatch node
## (a world child), so it persists through the cast and self-frees on Break. ref: ENT-RAMPART-001.
func spawn_barrier(caster: CharacterBody3D, pos: Vector3, facing: Vector3, p: Dictionary) -> void:
	var bar = _RampartBarrier.new()
	add_child(bar)
	bar.setup(caster, pos, facing, p, self)


## Scout reveal (AB-032 Beacon Sight) — force every enemy visible through the fog for `dur`s
## (EnemyVisibility owns set_seen; it holds the reveal for the window). ref: F-011 · AB-032.
func reveal_enemies(dur: float) -> void:
	for v in get_tree().get_nodes_in_group("enemy_visibility"):
		if v.has_method("reveal"):
			v.reveal(dur)


## Spawn a traveling projectile (delivery="projectile") that carries `effect` as its payload — on
## impact it calls effect.resolve_at(). Hit mask excludes the caster's own side (no friendly fire);
## Rampart (world layer) blocks/absorbs it. ref: F-021 · AB-034 · DRIFT-059.
## `origin` = 발사 시작점. 기본(null) = 캐스터 위치. **착탄점에서 2차 투사체를 뿌리는 산탄**
## (AB-055)처럼 캐스터가 아닌 곳에서 출발해야 하는 경우에만 지정한다. ref: IMPL-DEC-20260728-002.
func spawn_projectile(effect, caster: CharacterBody3D, target_pos: Vector3, params: Dictionary, origin = null) -> void:
	var proj = _Projectile.new()
	add_child(proj)
	var from: Vector3 = (origin as Vector3) if origin != null else caster.global_position
	proj.setup(caster, from, target_pos, float(params.get("speed_mps", 18.0)),
		_projectile_mask(caster), effect, params, self)


## Projectile hit mask by caster side: ally → world(1) + enemy(4); enemy → world(1) + party(2).
## **+ 엄폐 레이어(8, `rampart_barrier.LAYER_COVER`)** — AB-033 돔은 이동을 안 막으므로 world(1)에
## 없다. 투사체는 이 비트로만 돔을 만난다(DRIFT-107).
## Rampart Barrier sits on world(1), so it's hit either way. The caster's own layer is excluded.
func _projectile_mask(caster: CharacterBody3D) -> int:
	return (1 | 4 | 8) if caster.is_in_group("party_member") else (1 | 2 | 8)
