extends Node
## Procedural placeholder VFX for the 4 Identity skills — distinct shape + color
## so each cast is readable at a glance. Self-animating, self-freeing (A-tier art TBD).

const GROUND_Y := 0.06
## Homing projectile flight time. EnemyAI defers the locked hit's damage by this so it lands
## exactly when the orb reaches the target (not at resolve). _enemy_shot/_poison_puff use it too.
const SHOT_FLIGHT_S := 0.4


# --- public per-skill effects ---

static func anchor_guard(parent: Node3D, pos: Vector3, radius: float) -> void:
	# Tank: blue ground pulse (to radius) + a translucent shield dome on the unit.
	_ground_pulse(parent, pos, radius, Color(0.32, 0.56, 1.0, 0.40), 1.3)
	_dome(parent, pos + Vector3(0, 0.75, 0), 0.95, Color(0.40, 0.62, 1.0, 0.28), 1.6)


static func press_line(parent: Node3D, pos: Vector3, axis: Vector3, range_m: float, half_deg: float) -> void:
	# DPS: teal forward cone flash along the attack axis.
	_cone(parent, pos + Vector3(0, 0.7, 0), axis, range_m, deg_to_rad(half_deg), Color(0.16, 0.92, 0.82, 0.45))


static func mark_ruin(parent: Node3D, target_pos: Vector3) -> void:
	# Nuker: purple vertical beam + impact burst on the target.
	_beam(parent, target_pos, Color(0.64, 0.36, 0.98, 0.7))
	_burst(parent, target_pos + Vector3(0, 0.7, 0), 1.5, Color(0.64, 0.36, 0.98, 0.6))


static func mend_circle(parent: Node3D, pos: Vector3, radius: float) -> void:
	# Healer: green ground pulse.
	_ground_pulse(parent, pos, radius, Color(0.30, 0.95, 0.46, 0.42), 1.4)


## Enemy cast wind-up warning at the target spot (F-021 telegraph).
static func telegraph(parent: Node3D, pos: Vector3, color: Color, radius: float = 1.9) -> void:
	_ground_pulse(parent, pos, radius, color, 0.5)


## Forward FAN telegraph (AB-099 전방 부채꼴 결계) — a flat ground sector spanning `deg`° around
## `facing`, radius `radius`, apex at `apex`. Conveys a directional zone (not a self-centered disc).
static func fan_telegraph(parent: Node3D, apex: Vector3, facing: Vector3, radius: float, deg: float, color: Color, dur: float) -> void:
	var f := facing
	f.y = 0.0
	if f.length() < 0.01:
		f = Vector3(0, 0, 1)
	f = f.normalized()
	var half := deg_to_rad(deg * 0.5)
	var segs := 14
	var verts := PackedVector3Array()
	for i in segs:
		var t0: float = lerpf(-half, half, float(i) / float(segs))
		var t1: float = lerpf(-half, half, float(i + 1) / float(segs))
		var d0 := f.rotated(Vector3.UP, t0) * radius
		var d1 := f.rotated(Vector3.UP, t1) * radius
		verts.append(Vector3.ZERO)
		verts.append(Vector3(d0.x, 0.0, d0.z))
		verts.append(Vector3(d1.x, 0.0, d1.z))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := _mat(color)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = Vector3(apex.x, GROUND_Y, apex.z)
	_fade_out(mi, mat, Vector3.ONE, dur)


## Revive channel — a green light pillar rising on a downed ally for `duration`s, then fades.
static func revive_pillar(parent: Node3D, pos: Vector3, duration: float) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.58
	cyl.height = 4.0
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 1.0, 0.62, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.45, 1.0, 0.6)
	mat.emission_energy_multiplier = 2.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.position = pos + Vector3(0, 2.0, 0)
	parent.add_child(mi)
	_ground_pulse(parent, pos, 1.4, Color(0.4, 1.0, 0.55, 0.45), duration)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale:y", 1.15, duration).from(0.35)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration).from(0.55).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(mi.queue_free)


# --- sub skills (player) — bigger / emissive ---

static func sub_taunt(parent: Node3D, pos: Vector3, radius: float) -> void:
	_ground_pulse(parent, pos, radius, Color(0.30, 0.55, 1.0, 0.55), 1.5)
	_dome(parent, pos + Vector3(0, 0.85, 0), 1.4, Color(0.40, 0.62, 1.0, 0.35), 1.9)
	_burst_glow(parent, pos + Vector3(0, 0.85, 0), 2.4, Color(0.42, 0.62, 1.0))


static func sub_lunge(parent: Node3D, from: Vector3, to: Vector3) -> void:
	_enemy_shot(parent, from + Vector3(0, 0.7, 0), to + Vector3(0, 0.7, 0), Color(0.16, 0.95, 0.85))
	_burst_glow(parent, to + Vector3(0, 0.7, 0), 2.0, Color(0.16, 0.95, 0.85))


static func sub_nova(parent: Node3D, pos: Vector3, radius: float) -> void:
	_ground_pulse(parent, pos, radius, Color(0.60, 0.35, 0.97, 0.55), 1.7)
	_burst_glow(parent, pos + Vector3(0, 0.85, 0), 2.8, Color(0.62, 0.36, 0.98))


static func sub_sanctuary(parent: Node3D, pos: Vector3, radius: float) -> void:
	_ground_pulse(parent, pos, radius, Color(0.97, 0.86, 0.35, 0.55), 1.7)
	_dome(parent, pos + Vector3(0, 0.95, 0), 1.7, Color(1.0, 0.9, 0.42, 0.35), 2.1)


# --- enemy ability cues (keyed by ability catalog `vfx`) ---

## `target` is the struck actor NODE (not a frozen point): flying shots HOME to its live position
## so a target-LOCKED hit lands ON it. Instant cues (lightning/strike/bash) use the resolve point.
static func enemy_vfx(key: String, parent: Node3D, from: Vector3, target: Node3D) -> void:
	var y := Vector3(0, 0.8, 0)
	var to: Vector3 = (target.global_position if is_instance_valid(target) else from)
	match key:
		"projectile":  # generic basic pebble — round sphere (the plain look ABs break from)
			_enemy_shot(parent, from + y, to + y, Color(0.7, 0.85, 0.4), "sphere", target)
		"shot_lightning":  # AB-004 Voltaic — fast jagged bolt (lands on the damage/shake frame)
			lightning_bolt(parent, from, to, Color(0.55, 0.8, 1.0))
		"shot_venom":  # AB-010 Venom — toxic-green ELLIPSOID glob + lingering poison puff (DoT)
			_enemy_shot(parent, from + y, to + y, Color(0.4, 0.95, 0.3), "ellipsoid", target)
			_poison_puff(target, Color(0.42, 0.85, 0.22))
		"shot_hex":  # AB-012 Hex Bolt — purple CONE dart (rune spike pointing forward)
			_enemy_shot(parent, from + y, to + y, Color(0.72, 0.4, 0.95), "cone", target)
		"shot_slag":  # AB-008 Slag Spit — orange CUBE chunk (jagged slag lump)
			_enemy_shot(parent, from + y, to + y, Color(0.95, 0.6, 0.25), "cube", target)
		"shot_frost":  # AB-041 Glacial Bolt — cyan CONE frost spike (homing)
			_enemy_shot(parent, from + y, to + y, Color(0.6, 0.9, 1.0), "cone", target)
		"strike":  # AB-013 Backstab — crimson directional stab (no big ground ring)
			_enemy_strike(parent, to + y, to - from, Color(0.92, 0.18, 0.22))
		"shield_bash":  # AB-002 Shield Bash — blue knockback shockwave
			_knockback_blast(parent, to, to - from, Color(0.40, 0.62, 1.0))


## Orthonormal basis with local +Y aligned to `dir` (used to point cone tips / ellipsoid long-axes
## along the travel direction). `dir` is assumed non-vertical (callers flatten the Y component).
static func _aim_basis(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := Vector3.UP.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## Enemy ranged strike: a glowing projectile that HOMES to the target's live position, then bursts
## on impact. These hits are target-LOCKED (damage already applied at resolve) so the orb must
## connect — not fall on the spot the target just left (which reads as a dodge). `shape` gives each
## attack a DISTINCT silhouette (not just a recoloured ball): sphere(평타) / ellipsoid(독 glob) /
## cone(hex 다트) / cube(slag 덩어리). Cone/ellipsoid re-aim along travel each frame.
static func _enemy_shot(parent: Node3D, from: Vector3, to: Vector3, color: Color, shape: String = "sphere", target: Node3D = null) -> void:
	var mi := MeshInstance3D.new()
	match shape:
		"ellipsoid":
			var e := SphereMesh.new()
			e.radius = 0.24
			e.height = 1.25
			mi.mesh = e
		"cone":
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.34
			c.height = 1.1
			mi.mesh = c
		"cube":
			var b := BoxMesh.new()
			b.size = Vector3(0.52, 0.52, 0.52)
			mi.mesh = b
		_:
			var s := SphereMesh.new()
			s.radius = 0.3
			s.height = 0.6
			mi.mesh = s
	var mat := _emat(color)
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = from
	if shape == "cube":
		mi.rotation = Vector3(0.6, 0.8, 0.0)  # tilt the chunk so it reads as a jagged lump
	var aim := shape == "ellipsoid" or shape == "cone"
	var tw := mi.create_tween()
	# Flight: if a `target` node is given, HOME to its LIVE position (locked hits can't be outrun);
	# otherwise fly straight to the fixed `to` (positional uses like sub_lunge). At t=1 → on target.
	tw.tween_method(func(t: float) -> void:
		var dst := to
		if is_instance_valid(target):
			dst = target.global_position + Vector3(0, 0.8, 0)
		var prev := mi.global_position
		var pos := from.lerp(dst, t)
		if aim:
			var d := pos - prev
			d.y = 0.0
			if d.length() > 0.001:
				mi.global_transform = Transform3D(_aim_basis(d.normalized()), pos)
			else:
				mi.global_position = pos
		else:
			mi.global_position = pos
	, 0.0, 1.0, SHOT_FLIGHT_S)
	tw.tween_property(mi, "scale", Vector3(4.5, 4.5, 4.5), 0.3)  # impact pop on the target
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(mi.queue_free)


## Lingering poison puff ON the target — parented to the target so it FOLLOWS it (lands on a
## moving target, not the spot it left). Blooms after `delay` (timed to the homing bolt's arrival),
## then expands + slowly fades, reading as the DoT cloud.
static func _poison_puff(target: Node3D, color: Color, delay: float = SHOT_FLIGHT_S) -> void:
	if not is_instance_valid(target):
		return
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	mi.mesh = s
	var mat := _emat(color)
	mat.albedo_color.a = 0.0
	mi.material_override = mat
	target.add_child(mi)  # follow the target
	mi.position = Vector3(0, 0.4, 0)
	mi.scale = Vector3(0.3, 0.3, 0.3)
	var tw := mi.create_tween()
	tw.tween_interval(delay)  # wait for the homing bolt to land
	tw.tween_property(mat, "albedo_color:a", 0.55, 0.12)  # bloom in on impact
	tw.parallel().tween_property(mi, "scale", Vector3(1.7, 1.2, 1.7), 0.55)  # expand cloud
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.95)  # linger + fade (DoT feel)
	tw.tween_callback(mi.queue_free)


## Dash trail — an emissive streak along the lunge path, colored by the dash's INTENT (teal =
## reposition / crimson = strike) so AB-006 gap-close and AB-013 backstab read differently mid-dash.
static func dash_streak(parent: Node3D, from: Vector3, to: Vector3, color: Color) -> void:
	var a := from + Vector3(0, 0.7, 0)
	var b := to + Vector3(0, 0.7, 0)
	var seg := a.distance_to(b)
	if seg < 0.15:
		return
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.16, seg)  # thin, long along local Z (the path)
	mi.mesh = box
	var mat := _emat(color)
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = (a + b) * 0.5
	mi.look_at(b, Vector3.UP)  # local Z spans a→b
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.3).from(maxf(color.a, 0.6))
	tw.parallel().tween_property(mi, "scale", Vector3(0.3, 0.3, 1.0), 0.3)  # thin out as it fades
	tw.tween_callback(mi.queue_free)


## Dash landing ring — a soft ground pulse where a NON-damaging gap-close ends (reads "repositioned
## here", no strike). Distinguishes AB-006's blink from AB-013's crimson stab.
static func dash_land(parent: Node3D, pos: Vector3, color: Color) -> void:
	_ground_pulse(parent, pos, 1.3, Color(color.r, color.g, color.b, 0.45), 0.4)


## Wind-up cue ON the caster (target-locked attacks) — a small emissive orb at the enemy's body
## that pulses over the telegraph, then fades. Says "this enemy is about to strike" — react via
## cover/interrupt/swap, NOT a ground "dodge this zone" marker (you can't sidestep a locked hit).
static func windup_cue(parent: Node3D, pos: Vector3, dur: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.32
	s.height = 0.64
	mi.mesh = s
	var mat := _emat(color)
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 1.4, 0)  # at the enemy's chest/head
	mi.scale = Vector3(0.35, 0.35, 0.35)
	var d := maxf(dur, 0.12)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1.0, 1.0, 1.0), d)
	tw.tween_property(mat, "albedo_color:a", 0.0, d).from(0.85)
	tw.chain().tween_callback(mi.queue_free)


## Charge-up build (AB-004 channel) — an emissive orb on the caster that grows + intensifies
## over `dur` (the telegraph), then snaps out as the bolt fires. Conveys "charging".
static func charge_up(parent: Node3D, pos: Vector3, dur: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.45
	s.height = 0.9
	mi.mesh = s
	var mat := _emat(color)
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 1.0, 0)
	mi.scale = Vector3(0.22, 0.22, 0.22)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1.4, 1.4, 1.4), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(mat, "emission_energy_multiplier", 5.5, dur).from(1.5)
	tw.chain().tween_property(mat, "albedo_color:a", 0.0, 0.1)
	tw.tween_callback(mi.queue_free)


## Fast lightning bolt (AB-004 release) — a jagged segmented arc from `from` to `to` that flashes
## near-instantly then fades (~0.14s), so the impact lands ON the damage/shake frame (not a slow
## travelling orb). Built from thin emissive segments along a perpendicular-jittered path.
static func lightning_bolt(parent: Node3D, from: Vector3, to: Vector3, color: Color) -> void:
	var a := from + Vector3(0, 1.0, 0)
	var b := to + Vector3(0, 1.0, 0)
	var holder := Node3D.new()
	parent.add_child(holder)
	var mat := _emat(color)
	mat.emission_energy_multiplier = 4.5
	var axis := b - a
	axis.y = 0.0
	var perp := Vector3(-axis.z, 0.0, axis.x)
	perp = perp.normalized() if perp.length() > 0.01 else Vector3.RIGHT
	var segs := 7
	var prev := a
	for i in range(1, segs + 1):
		var t := float(i) / float(segs)
		var p := a.lerp(b, t)
		if i < segs:
			p += perp * randf_range(-0.7, 0.7) + Vector3(0, randf_range(-0.5, 0.5), 0)
		_bolt_seg(holder, prev, p, mat)
		prev = p
	var tw := holder.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.14).from(0.95)
	tw.tween_callback(holder.queue_free)


## One thin emissive box spanning p0→p1 (a lightning segment), oriented along the segment.
static func _bolt_seg(holder: Node3D, p0: Vector3, p1: Vector3, mat: StandardMaterial3D) -> void:
	var d := p1 - p0
	var seg_len := d.length()
	if seg_len < 0.05:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.14, 0.14, seg_len)
	mi.mesh = bm
	mi.material_override = mat
	holder.add_child(mi)
	var z := d / seg_len
	var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	var y := z.cross(x).normalized()
	mi.global_transform = Transform3D(Basis(x, y, z), (p0 + p1) * 0.5)


## Directional stab (flank backstab) — a short narrow wedge in the strike direction + a tight
## impact burst at the target. No big ground ring (that's the shield-bash shockwave).
static func _enemy_strike(parent: Node3D, pos: Vector3, dir: Vector3, color: Color) -> void:
	var d := dir
	d.y = 0.0
	if d.length() > 0.01:
		_cone(parent, pos, d.normalized(), 1.8, deg_to_rad(18.0), Color(color.r, color.g, color.b, 0.6))
	_burst_glow(parent, pos, 0.8, color)


## Knockback shockwave: blue ground ring + directional push wedge + impact glow.
static func _knockback_blast(parent: Node3D, pos: Vector3, dir: Vector3, color: Color) -> void:
	_ground_pulse(parent, pos, 3.2, Color(color.r, color.g, color.b, 0.5), 1.0)
	var d := dir
	d.y = 0.0
	if d.length() > 0.01:
		_cone(parent, pos + Vector3(0, 0.6, 0), d, 3.4, deg_to_rad(38.0), Color(color.r, color.g, color.b, 0.55))
	_burst_glow(parent, pos + Vector3(0, 0.8, 0), 1.3, color)


## Bright expanding burst (emissive).
static func _burst_glow(parent: Node3D, center: Vector3, radius: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mi.mesh = sphere
	var mat := _emat(Color(color.r, color.g, color.b, 0.7))
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = center
	mi.scale = Vector3(0.2, 0.2, 0.2)
	_fade_out(mi, mat, Vector3(1.0, 1.0, 1.0), 0.9)


# --- builders ---

static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Emissive variant — brighter/glowing for high-impact cues.
static func _emat(color: Color) -> StandardMaterial3D:
	var m := _mat(color)
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = 2.5
	return m


static func _fade_out(node: Node3D, mat: StandardMaterial3D, end_scale: Vector3, dur: float) -> void:
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "scale", end_scale, dur)
	tw.tween_property(mat, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(node.queue_free)


## Flat expanding disc on the ground.
static func _ground_pulse(parent: Node3D, pos: Vector3, radius: float, color: Color, dur: float) -> void:
	var mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.06
	mi.mesh = disc
	var mat := _mat(color)
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, GROUND_Y, pos.z)
	mi.scale = Vector3(0.12, 1.0, 0.12)
	_fade_out(mi, mat, Vector3.ONE, dur)


## Translucent hemisphere-ish dome on the unit.
static func _dome(parent: Node3D, center: Vector3, radius: float, color: Color, dur: float) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mi.mesh = sphere
	var mat := _mat(color)
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = center
	mi.scale = Vector3(0.7, 0.7, 0.7)
	_fade_out(mi, mat, Vector3(1.1, 1.1, 1.1), dur)


## Cone pointing from `pos` outward along `axis` (apex at pos).
static func _cone(parent: Node3D, pos: Vector3, axis: Vector3, range_m: float, half_angle: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = maxf(0.4, range_m * tan(half_angle))
	cone.height = range_m
	mi.mesh = cone
	var mat := _mat(color)
	mi.material_override = mat
	parent.add_child(mi)
	var dir := axis
	dir.y = 0.0
	dir = dir.normalized()
	# Local +Y is the apex (top_radius 0). Map +Y → -dir so the apex sits at `pos`.
	var y_axis := -dir
	var x_axis := Vector3.UP.cross(y_axis)
	if x_axis.length() < 0.01:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	mi.transform = Transform3D(Basis(x_axis, y_axis, z_axis), pos + dir * (range_m * 0.5))
	mi.scale = Vector3(0.7, 1.0, 0.7)
	_fade_out(mi, mat, Vector3(1.0, 1.0, 1.0), 1.1)


## Tall thin vertical beam at a position.
static func _beam(parent: Node3D, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 4.0, 0.5)
	mi.mesh = box
	var mat := _mat(color)
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 2.0, pos.z)
	mi.scale = Vector3(1.0, 1.0, 1.0)
	_fade_out(mi, mat, Vector3(1.6, 1.0, 1.6), 1.2)


## Expanding sphere burst.
static func _burst(parent: Node3D, center: Vector3, radius: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mi.mesh = sphere
	var mat := _mat(color)
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = center
	mi.scale = Vector3(0.2, 0.2, 0.2)
	_fade_out(mi, mat, Vector3(1.0, 1.0, 1.0), 1.0)
