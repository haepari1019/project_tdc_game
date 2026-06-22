extends RefCounted
## AB-031 Ward Pulse (kind=ward_shield) — shield the most-hurt nearby ally + cleanse one debuff
## (CC recovery trade vs Mend Circle's raw HPS). Fires in combat as a proactive ward.
## Drop-in identity effect. ref: GEAR-042 · DEC(gear catalog).


func kind() -> String:
	return "ward_shield"


func cast(m: CharacterBody3D, p: Dictionary, _target_pos: Vector3, ctx) -> bool:
	if ctx.enemies_in_radius(m.global_position, 10.0).is_empty():
		return false   # only ward in combat
	var target: CharacterBody3D = m
	var worst: float = m.hp / maxf(m.max_hp, 1.0)
	for a in ctx.allies_in_radius(m.global_position, float(p.get("range_m", 12.0))):
		if a == null or not is_instance_valid(a):
			continue
		var r: float = float(a.hp) / maxf(float(a.max_hp), 1.0)
		if r < worst:
			worst = r
			target = a
	target.add_shield(float(p.get("shield_base", 90.0)), float(p.get("shield_duration_s", 5.0)))
	var cleansed := ""
	if int(p.get("cleanse", 1)) > 0 and target.has_method("cleanse_one"):
		cleansed = target.cleanse_one()
	print("[ID] %s Ward Pulse — shield %s%s" % [m.identity_skill_id, target.class_id, (" cleanse " + cleansed) if cleansed != "" else ""])
	return true
