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
## Hostiles of the caster: enemy caster → party members; party caster → enemies.
func enemies_in_radius(pos: Vector3, r: float) -> Array:
	return _combat._allies_in_radius(pos, r) if _faction == "enemy" else _combat._enemies_in_radius(pos, r)


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


func damage_destructibles(pos: Vector3, r: float, dmg: float) -> bool:
	return _dispatch.damage_destructibles(pos, r, dmg)
