extends Node3D
## Party-union LOS occlusion — F-011 pre-step (occlusion only; full vision/perception deferred).
## An enemy is "seen" if ANY alive party member has a clear line of sight to it
## (raycast masked to world layer 1 = walls + cover obstacles). On lose-sight the
## enemy fades out (enemy_unit.set_seen) and stores last_seen_pos for a future marker.

const EYE_HEIGHT := 1.2       # observer eye above feet-origin
const TARGET_HEIGHT := 0.7    # enemy center above feet-origin
const WORLD_MASK := 1         # walls + obstacles (units are layers 2/3, ignored)
const EVAL_INTERVAL_S := 0.1  # re-evaluate at 10 Hz; the fade tween smooths between

var _party: Node3D
var _accum := 0.0


func setup(party: Node3D) -> void:
	_party = party


func _physics_process(delta: float) -> void:
	if _party == null:
		return
	_accum += delta
	if _accum < EVAL_INTERVAL_S:
		return
	_accum = 0.0

	var enemies := get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return
	var eyes: Array[Vector3] = []
	for m in _party.get_members():
		if is_instance_valid(m) and m.is_alive():
			eyes.append(m.global_position + Vector3(0, EYE_HEIGHT, 0))
	if eyes.is_empty():
		return

	# Mask = world layer (1) only → blocked by walls/obstacles, never by units
	# (party = layer 2, enemy = layer 3; neither on the world bit).
	var space := get_world_3d().direct_space_state
	for e in enemies:
		if not is_instance_valid(e) or not e.has_method("set_seen"):
			continue
		var target: Vector3 = e.global_position + Vector3(0, TARGET_HEIGHT, 0)
		var seen := false
		for eye in eyes:
			var q := PhysicsRayQueryParameters3D.create(eye, target, WORLD_MASK)
			if space.intersect_ray(q).is_empty():
				seen = true  # clear LOS from at least one member
				break
		e.set_seen(seen)
