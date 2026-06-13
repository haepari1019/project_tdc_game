extends Node3D
## Ground hazard zone — a persistent circular ground area with a STATUS (Fatal / Oil /
## Fire / ToxicGas). Optionally ticks damage to ANY unit inside (피아무구분, F-021).
## Impassable zones (Fatal) join group "fatal_zone" → carved out of the navmesh + avoided
## by party AI (split). Passable zones (Oil/Fire/ToxicGas) only join "ground_zone" — you
## can walk on/through them, but they're hazardous / flammable (reactions). ref: F-006 /
## F-021 ZONE / F-027 (ZONE-OIL, RX-OIL-FIRE).
##
## Query: group "ground_zone" (all) / "fatal_zone" (impassable). `contains_point()`,
## `blocks_segment()`, `status`.

const TICK_S := 0.2
const UNIT_GROUPS := ["party_member", "enemy"]

## Per-status visual (albedo, emission). Fatal/Fire warm, Oil dark, ToxicGas green.
const STATUS_COLORS := {
	"Fatal":    {"albedo": Color(0.95, 0.18, 0.12, 0.5),  "emit": Color(0.95, 0.22, 0.10)},
	"Oil":      {"albedo": Color(0.09, 0.07, 0.05, 0.80), "emit": Color(0.18, 0.12, 0.04)},
	"Fire":     {"albedo": Color(1.0, 0.45, 0.10, 0.55),  "emit": Color(1.0, 0.40, 0.05)},
	"ToxicGas": {"albedo": Color(0.45, 0.85, 0.25, 0.40), "emit": Color(0.40, 0.85, 0.15)},
}
const WARN_COLOR := {"albedo": Color(0.98, 0.62, 0.12, 0.42), "emit": Color(0.95, 0.55, 0.10)}

var radius: float = 3.0
var dps: float = 0.0
var slow_factor: float = 0.0   # >0 = slows units inside (e.g. Oil slick); refreshed per tick
var status: String = "Fatal"
var impassable: bool = true     # Fatal → navmesh carve + party avoidance
var ttl: float = -1.0           # -1 = persists; >0 = auto-despawn after ttl seconds
var _telegraph_s: float = 0.0
var _lethal: bool = true        # damage gate (telegraph phase = false until it goes lethal)
var _active: bool = true
var _tick_accum: float = 0.0
var _age: float = 0.0
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _source: Node = null   # attacker credited for threat when this zone damages enemies


func setup(p_radius: float, p_dps: float, p_telegraph_s: float = 0.0, p_status: String = "Fatal", p_impassable: bool = true, p_ttl: float = -1.0, p_slow: float = 0.0) -> void:
	radius = p_radius
	dps = p_dps
	_telegraph_s = p_telegraph_s
	status = p_status
	impassable = p_impassable
	ttl = p_ttl
	slow_factor = p_slow


func _ready() -> void:
	add_to_group("ground_zone")
	if impassable:
		add_to_group("fatal_zone")  # carve + avoidance only for impassable (lethal) zones
	if _telegraph_s > 0.0:
		_lethal = false
		get_tree().create_timer(_telegraph_s).timeout.connect(_go_lethal)
	_build()
	if impassable:
		get_tree().call_group("navmap", "rebake_navigation")  # carve into the navmesh


func _go_lethal() -> void:
	_lethal = true
	_apply_color(false)


func is_active() -> bool:
	return _active


## Credit an attacker (e.g. the torch thrower) for threat when this zone damages enemies.
func set_source(s: Node) -> void:
	_source = s


## Is a world point inside the zone (horizontal disc)? Used by damage + party avoidance.
func contains_point(p: Vector3, pad: float = 0.0) -> bool:
	if not _active:
		return false
	var d := Vector2(p.x - global_position.x, p.z - global_position.z)
	return d.length() <= radius + pad


## Does the segment a→b pass through the zone (with padding)? Used by follower avoidance.
func blocks_segment(a: Vector3, b: Vector3, pad: float = 0.6) -> bool:
	if not _active:
		return false
	var c := Vector2(global_position.x, global_position.z)
	var p := Vector2(a.x, a.z)
	var q := Vector2(b.x, b.z)
	var pq := q - p
	var l2 := pq.length_squared()
	var nearest: Vector2 = p if l2 < 0.0001 else p + pq * clampf((c - p).dot(pq) / l2, 0.0, 1.0)
	return (c - nearest).length() <= radius + pad


## Clear/despawn — fade out and free. Un-carves the navmesh if it was impassable.
func clear_zone() -> void:
	if not _active:
		return
	_active = false
	remove_from_group("ground_zone")
	if impassable:
		remove_from_group("fatal_zone")
		get_tree().call_group("navmap", "rebake_navigation")
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_mat, "albedo_color:a", 0.0, 0.4)
	tw.tween_property(_mesh, "scale:y", 0.04, 0.4)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	if ttl > 0.0:
		_age += delta
		if _age >= ttl:
			clear_zone()
			return
	if not _lethal:
		return  # telegraph phase — no effect yet
	if dps <= 0.0 and slow_factor <= 0.0:
		return  # inert zone
	_tick_accum += delta
	if _tick_accum < TICK_S:
		return
	var dmg := dps * _tick_accum
	_tick_accum = 0.0
	var is_dot := status == "Fire" or status == "ToxicGas"
	for g in UNIT_GROUPS:
		for u in get_tree().get_nodes_in_group(g):
			if not (u is Node3D) or not contains_point((u as Node3D).global_position):
				continue
			if dps > 0.0:
				# DoT zones (Fire/ToxicGas) apply a status so it reads on the party sheet;
				# Fatal (and units w/o apply_poison, e.g. enemies) take raw damage.
				if is_dot and u.has_method("apply_poison"):
					u.apply_poison(TICK_S * 2.5, dps)
				elif u.has_method("take_damage"):
					u.take_damage(dmg)
				# Torch fire pulls aggro onto its source (F-021 - the thrower / carrier).
				if g == "enemy" and _source != null and is_instance_valid(_source) and u.has_method("add_threat"):
					u.add_threat(_source, dmg)
					if u.has_method("perceive_attacker"):
						u.perceive_attacker(_source)
			if slow_factor > 0.0 and u.has_method("apply_slow"):
				u.apply_slow(slow_factor, TICK_S * 2.5)  # refreshed while standing in it


func _apply_color(warn: bool) -> void:
	if _mat == null:
		return
	var c: Dictionary = WARN_COLOR if warn else STATUS_COLORS.get(status, STATUS_COLORS["Fatal"])
	_mat.albedo_color = c["albedo"]
	_mat.emission = c["emit"]


func _build() -> void:
	_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.12
	cyl.radial_segments = 32
	_mesh.mesh = cyl
	_mat = StandardMaterial3D.new()
	_mat.emission_enabled = true
	_mat.emission_energy_multiplier = 1.6
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if status == "Oil":
		# Persistent ground slick → OPAQUE, hugging the floor. Rendering in the opaque pass
		# makes depth resolve correctly: units standing in it are NOT covered (the slick sits
		# below them), and the depth-writing vision cone (transparent, drawn later) only tints
		# it rather than hiding it. (A floating transparent disk covered enemies' lower bodies.)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		_mesh.position.y = 0.07
	else:
		# Transient telegraph → transparent, floated above the vision cone (y=0.3, depth-writing)
		# so the cone can't occlude it; render_priority draws it after the cones.
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.render_priority = 2
		_mesh.position.y = 0.4
	_apply_color(not _lethal)
	_mesh.material_override = _mat
	add_child(_mesh)
	# emissive pulse so an active hazard reads — skip for inert Oil (it just sits, dark).
	if status != "Oil":
		var tw := create_tween().set_loops()
		tw.tween_property(_mat, "emission_energy_multiplier", 2.6, 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_mat, "emission_energy_multiplier", 1.4, 0.6).set_trans(Tween.TRANS_SINE)
