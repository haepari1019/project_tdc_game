extends RefCounted
## AB-062 Smoke Veil (kind=skillbook_stealth) — self stealth: the caster gains Veiled for veil_s,
## dropping enemy targeting for the window (party_member.apply_veil → enemy_ai._is_hostile skips it).
## Pure escape tool, no damage. Drop-in skillbook effect. ref: F-009 · STATUS Veiled · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")


func kind() -> String:
	return "skillbook_stealth"


func cast(m: CharacterBody3D, p: Dictionary, _t: Vector3, ctx) -> bool:
	if not m.has_method("apply_veil"):
		return false
	var dur := float(p.get("veil_s", 1.5))
	m.apply_veil(dur)
	SkillVfx.smoke_puff(ctx, m.global_position)
	print("[SB] %s Smoke Veil — Veiled %.1fs" % [m.class_id, dur])
	return true
