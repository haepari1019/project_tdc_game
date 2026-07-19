extends Node3D
## Faction-agnostic cast context (PILOT — AB-003 통합) — the sb_* effect facade parameterized by caster
## faction, so ONE skillbook effect (e.g. sb_bolt) drives BOTH ally and enemy casts identically. Ally
## casts already flow through AbilityDispatch (party ctx); this serves ENEMY casts of UNIFIED abilities.
## Only the faction-specific surface branches (hostile set / damage routing / projectile mask); all
## faction-agnostic helpers delegate to the party dispatch. Must be a Node (SkillVfx VFX parent).
## ref: _WIP_casting_expansion_pass §통합 · "능력 해소 1개 + 캐스팅 프론트엔드 2개".

const _Projectile := preload("res://scripts/combat/abilities/projectile.gd")

var _combat: Node3D   # CombatController — spatial queries
var _dispatch         # AbilityDispatch — faction-agnostic helpers (shake / lightning / destructibles / mask)
var _faction: String = "enemy"   # caster side; "enemy" → hostiles = party


func setup(combat: Node3D, dispatch, faction: String = "enemy") -> void:
	_combat = combat
	_dispatch = dispatch
	_faction = faction


# --- faction-specific --------------------------------------------------------
## 시전자의 적 유닛 배열(공간쿼리 대상): 적 캐스터 → 파티, 파티 캐스터 → 적. 공간 필터의 대상 배열로 넘긴다.
func _hostiles() -> Array:
	return _combat._party_members() if _faction == "enemy" else _combat._enemies


## Hostiles of the caster: enemy caster → party members; party caster → enemies.
func enemies_in_radius(pos: Vector3, r: float) -> Array:
	return _combat._allies_in_radius(pos, r) if _faction == "enemy" else _combat._enemies_in_radius(pos, r)


## 시전자의 적 중 최근접 1체(진영 flip) — sb_strike/sb_stun 등이 조준 어시스트로 씀.
func nearest_enemy_in_range(pos: Vector3, r: float) -> CharacterBody3D:
	return _combat._nearest_in_range(_hostiles(), pos, r)


## 시전자의 적을 원뿔/전방레인으로(진영 flip) — sb_charge(Reaver)·sb_slow 등.
func enemies_in_cone(pos: Vector3, axis: Vector3, r: float, half: float) -> Array:
	return _combat._in_cone(_hostiles(), pos, axis, r, half)


func enemies_in_rect(pos: Vector3, axis: Vector3, length: float, half_width: float) -> Array:
	return _combat._in_rect(_hostiles(), pos, axis, length, half_width)


## 시전자의 아군(적 캐스터 → 다른 적) — 힐/버프 대상 검색. 진영 반대로 flip.
func allies_in_radius(pos: Vector3, r: float) -> Array:
	return _combat._enemies_in_radius(pos, r) if _faction == "enemy" else _combat._allies_in_radius(pos, r)


## 적 캐스터는 mark_ruin(파티 전용 identity)·정찰(AB-032 Healer)을 안 써 미사용 — 게이트 존재 보장용 no-op.
func lowest_hp_enemy_in_radius(_pos: Vector3, _r: float) -> CharacterBody3D:
	return null


func reveal_enemies(_dur: float) -> void:
	pass


## 적 힐(EN-014 등) — 결속/성역은 파티 전용이라 타지 않는다. 순수 회복만(대상=시전자의 아군).
func deal_heal(target, _healer, amount: float) -> float:
	if target == null or not target.has_method("heal"):
		return 0.0
	return target.heal(amount)


func deal_regen(target, _healer, pct_per_s: float, dur: float) -> void:
	if target != null and target.has_method("apply_regen"):
		target.apply_regen(pct_per_s, dur)


## 적은 파티 위협 테이블이 없다 → no-op(reduce_threat과 대칭).
func heal_threat(_healer, _ally, _eff: float) -> void:
	pass


## RX/월드는 진영 무관 → party dispatch로 순수 위임.
func fire_hit(center: Vector3, r: float, depth: int, source: Node = null) -> void:
	_dispatch.fire_hit(center, r, depth, source)


func cold_hit(center: Vector3, radius: float, source: Node = null) -> void:
	_dispatch.cold_hit(center, radius, source)


func spawn_barrier(caster: CharacterBody3D, pos: Vector3, facing: Vector3, p: Dictionary) -> void:
	_dispatch.spawn_barrier(caster, pos, facing, p)


## 파티 전용(집중 결속·hit 보고) — 적은 결속이 없어 no-op.
func report_hit_count(_n: int) -> void:
	pass


func report_hit_target(_t: CharacterBody3D) -> void:
	pass


func nuker_focus_accumulate(_member, _enemy) -> float:
	return 0.0


## Enemy→party damage routes through take_damage (attacker passed → Sentinel reflect); party→enemy
## uses the F-022 threat path.
func deal_damage(target: CharacterBody3D, source: CharacterBody3D, dmg: float) -> void:
	if _faction == "enemy":
		if target != null and is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(dmg, source)
	else:
		_combat._deal_damage(target, source, dmg)


## Own spawn so the projectile carries THIS ctx (faction-correct resolve_at) + caster-side mask.
func spawn_projectile(effect, caster: CharacterBody3D, target_pos: Vector3, params: Dictionary) -> void:
	var proj = _Projectile.new()
	add_child(proj)
	proj.setup(caster, caster.global_position, target_pos, float(params.get("speed_mps", 18.0)),
		_dispatch._projectile_mask(caster), effect, params, self)


# --- faction-agnostic (delegate to party dispatch) ---------------------------
func sub_shake(p: Dictionary) -> void:
	_dispatch.sub_shake(p)


## 지면 존 생성(피아무구분 — 존이 내부 유닛에 매체 결과 적용). AB-010 병합(옛 AB-039 독존)이 여기로 위임.
func spawn_zone(medium: String, pos: Vector3, radius: float, dps: float, ttl: float, source: Node = null) -> void:
	_dispatch.spawn_zone(medium, pos, radius, dps, ttl, source)


## AB-007 이탈 — 적은 파티 위협 테이블이 없음 → 후퇴 자체가 이탈이라 no-op(아군↔적 통일 대칭).
func reduce_threat(_caster: CharacterBody3D, _frac: float) -> void:
	pass


func lightning_hit(center: Vector3, radius: float, source: Node = null) -> void:
	_dispatch.lightning_hit(center, radius, source)


## 속성 타격 seam — 즉시 효과 + RX(조건부 효과의 입구). 진영 무관이라 그대로 위임. ref: DRIFT-088.
func element_hit(element: String, center: Vector3, radius: float, source: Node, p: Dictionary, targets: Array = []) -> void:
	_dispatch.element_hit(element, center, radius, source, p, targets)


func damage_destructibles(pos: Vector3, r: float, dmg: float) -> bool:
	return _dispatch.damage_destructibles(pos, r, dmg)
