extends StaticBody3D
## ENT-RAMPART-001 — Rampart Barrier (Tank AB-034). A destructible forward wall: blocks movement
## (world collision layer, so party + enemies alike) for `duration_s`, or until `barrier_hp` hits 0 →
## Break. On spawn, briefly staggers small/normal enemies touching it. Max 1 per caster
## (spec: 동시 2개 이상 유지 금지). Projectile-absorb / threat-on-hit are DEFERRED — the combat model
## applies damage target-locked, not via world-geometry projectiles, so nothing routes hits into the
## wall yet (take_damage is wired for when it does). ref: AB-034 · ENT-RAMPART-001 · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")

var _hp: float = 300.0
var _ttl: float = 4.0
var _caster: CharacterBody3D = null
var _mat: StandardMaterial3D = null


func setup(caster: CharacterBody3D, pos: Vector3, facing: Vector3, p: Dictionary, ctx) -> void:
	_caster = caster
	_hp = float(p.get("barrier_hp", 300.0))
	_ttl = float(p.get("duration_s", 4.0))
	var w := float(p.get("width_m", 3.5))
	var h := float(p.get("height_m", 2.0))
	var depth := 0.4
	add_to_group("rampart_barrier")
	# Max 1 per caster — drop this Tank's older wall before standing a new one.
	for b in get_tree().get_nodes_in_group("rampart_barrier"):
		if b != self and is_instance_valid(b) and b.get("_caster") == _caster:
			b.queue_free()
	var f := facing
	f.y = 0.0
	f = f.normalized() if f.length() > 0.05 else Vector3(0, 0, 1)
	var x := Vector3.UP.cross(f).normalized()   # width axis (perpendicular to facing)
	# Mesh — a translucent slab; broad face normal = facing (blocks forward advance).
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, depth)
	mi.mesh = bm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.55, 0.58, 0.66, 0.85)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.emission_enabled = true
	_mat.emission = Color(0.40, 0.50, 0.70)
	_mat.emission_energy_multiplier = 0.5
	mi.material_override = _mat
	add_child(mi)
	# Collision on the world layer so both party and enemies are physically blocked.
	collision_layer = 1
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, h, depth)
	cs.shape = box
	add_child(cs)
	global_transform = Transform3D(Basis(x, Vector3.UP, f), Vector3(pos.x, h * 0.5, pos.z))
	# Spawn impact: brief stagger on small/normal enemies touching the wall (skip miniboss/elite cores).
	var stagger := float(p.get("stagger_s", 0.5))
	if stagger > 0.0:
		for e in ctx.enemies_in_radius(global_position, maxf(w, 1.5) * 0.6):
			if e != null and is_instance_valid(e) and e.has_method("apply_stun") and not bool(e.get("miniboss")):
				e.apply_stun(stagger)
	SkillVfx.telegraph(ctx, Vector3(pos.x, 0.0, pos.z), Color(0.50, 0.60, 0.90), maxf(w, 2.0) * 0.6)


## Forward-compat: drop the wall's HP (Break at 0). Nothing routes combat hits here yet (see header).
func take_damage(amount: float) -> void:
	if _hp <= 0.0:
		return
	_hp = maxf(0.0, _hp - amount)
	if _hp <= 0.0:
		queue_free()   # Break — barrier hp 0


func _process(delta: float) -> void:
	_ttl -= delta
	if _ttl <= 0.0:
		queue_free()   # Break — duration elapsed
	elif _mat != null and _ttl < 1.0:
		_mat.albedo_color.a = clampf(_ttl, 0.0, 1.0) * 0.85   # fade out over the last second
