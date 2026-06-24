extends Node3D
## Generic traveling projectile (delivery="projectile", Phase 1) — flies from the caster toward a
## destination, SEGMENT-raycasts each physics frame (prev→next, so it can't tunnel through thin walls),
## and on the FIRST blocker resolves its payload via the source effect's `resolve_at(caster, pos, params, ctx)`:
##  · Rampart barrier (group rampart_barrier) → absorbed (barrier soaks it), NO payload (RP-02 cover).
##  · world wall → fizzles, NO payload.
##  · a hostile unit, OR reaching the aim point untouched → payload at that point (single / AoE-on-impact).
## The hit mask EXCLUDES the caster's own side (no friendly fire / self-hit). The delivery (travel,
## blocking) is controller-agnostic; only the AIM differs (player vs AI). ref: AB-034 · F-021 · DRIFT-059.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")

const Y := 0.8                  # travel height (chest level — matches unit hit boxes)
const MAX_LIFETIME_S := 3.0
const ARRIVE_EPS := 0.35

var _caster: CharacterBody3D
var _dir: Vector3 = Vector3(0, 0, 1)
var _dest: Vector3
var _speed: float = 18.0
var _mask: int = 1
var _effect                     # source effect (RefCounted) exposing resolve_at()
var _params: Dictionary = {}
var _ctx
var _life := 0.0
var _done := false
var _mat: StandardMaterial3D
var _exclude: Array[RID] = []   # friendly barriers the shot passes through (owner's own team)


func setup(caster: CharacterBody3D, origin: Vector3, dest: Vector3, speed: float, mask: int, effect, params: Dictionary, ctx) -> void:
	_caster = caster
	_dest = Vector3(dest.x, Y, dest.z)
	_speed = maxf(speed, 1.0)
	_mask = mask
	_effect = effect
	_params = params.duplicate()   # snapshot (captures transient _coeff at cast time)
	_ctx = ctx
	global_position = Vector3(origin.x, Y, origin.z)
	var to := _dest - global_position
	to.y = 0.0
	_dir = to.normalized() if to.length() > 0.05 else Vector3(0, 0, 1)
	_build_visual()


func _build_visual() -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.20
	s.height = 0.40
	mi.mesh = s
	var col: Color
	if _params.has("proj_color"):                                    # explicit element tint (fire/cold/void)
		var a: Array = _params["proj_color"]
		col = Color(float(a[0]), float(a[1]), float(a[2])) if a.size() >= 3 else Color(0.85, 0.9, 1.0)
	elif bool(_params.get("lightning", false)):
		col = Color(0.62, 0.84, 1.0)                                 # electric blue
	else:
		col = Color(1.0, 0.78, 0.4)                                  # default warm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = col
	_mat.emission_enabled = true
	_mat.emission = col
	_mat.emission_energy_multiplier = 3.0
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = _mat
	add_child(mi)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_life += delta
	var step := _speed * delta
	var reached := global_position.distance_to(_dest) <= maxf(step, ARRIVE_EPS) or _life >= MAX_LIFETIME_S
	var to_point: Vector3 = _dest if reached else global_position + _dir * step
	var space := get_world_3d().direct_space_state
	# Segment-cast, skipping FRIENDLY Rampart barriers (the owner's own team passes through — RP-02:
	# a wall stops the ENEMY's shots, not your own). Bounded loop in case several stack.
	var hit := {}
	for _i in 6:
		var q := PhysicsRayQueryParameters3D.create(global_position, to_point, _mask)
		q.exclude = _exclude
		hit = space.intersect_ray(q)
		if hit.is_empty():
			break
		var c = hit.collider
		if c != null and c.is_in_group("rampart_barrier") and c.has_method("blocks_projectile_from") \
				and not c.blocks_projectile_from(_caster):
			_exclude.append(c.get_rid())   # friendly wall → ignore for the rest of the flight
			continue
		break
	if not hit.is_empty():
		var col = hit.collider
		var pos: Vector3 = hit.get("position", to_point)
		if col != null and col.is_in_group("rampart_barrier"):
			if col.has_method("absorb_projectile"):
				col.absorb_projectile()
			_impact(pos, false)     # HOSTILE Rampart soaks it — no payload (RP-02)
		elif col != null and (col.is_in_group("enemy") or col.is_in_group("party_member")):
			_impact(pos, true)      # hostile unit → resolve payload here
		else:
			_impact(pos, false)     # world wall → fizzle
		return
	global_position = to_point
	if reached:
		_impact(_dest, true)        # reached the aim point untouched → payload (AoE-on-arrival)


func _impact(pos: Vector3, run_payload: bool) -> void:
	_done = true
	if run_payload and _effect != null and _effect.has_method("resolve_at"):
		_effect.resolve_at(_caster, pos, _params, _ctx)
	elif not run_payload:
		SkillVfx.telegraph(_ctx, pos, Color(0.7, 0.75, 0.85), 0.9)   # blocked/fizzle puff
	queue_free()
