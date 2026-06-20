extends Node3D
## Ground hazard zone — a persistent circular ground area carrying an environment MEDIUM
## (STATUS-ENV-CORE: Fatal/Oil/Water/Fire/Ice/Vegetation/Wind/Steam/Smoke/ToxicGas). The medium
## decides the per-tick OUTCOME applied to ANY unit inside (피아무구분, F-021): Fire→Ignited,
## ToxicGas→Poisoned, Water→Sodden, Ice→Chilled, Oil→Slippery, Steam→SteamHaze, Wind→WindBuffeted,
## Smoke/Vegetation→harmless (Smoke=vision[deferred], Veg=flammable only), Fatal→raw damage.
## ref: F-021 ZONE · F-027 · STATUS-ENV-CORE/OUTCOME-CORE.
##
## `status` = the primary medium (single for now; activeMedia[]/primaryMedium multi-stacking = S3d).
## Impassable (Fatal) → group "fatal_zone" (navmesh carve + party avoidance). All → "ground_zone".
## Query: `contains_point()`, `blocks_segment()`, `status`.

const TICK_S := 0.2
const UNIT_GROUPS := ["party_member", "enemy"]
const OUTCOME_DUR := TICK_S * 2.5   # outcome refresh while inside (~0.5s residual after leaving)
## Media that apply a movement OUTCOME each tick (tick even with no dps).
const MOVEMENT_MEDIA := ["Water", "Ice", "Oil", "Steam", "Wind"]
## Medium → outcome status applied to units inside (STATUS-OUTCOME-CORE).
const MEDIUM_OUTCOME := {
	"Water": "Sodden", "Ice": "Chilled", "Oil": "Slippery",
	"Steam": "SteamHaze", "Wind": "WindBuffeted",
}

## Per-medium visual (albedo, emission). 9-medium preset catalog (STATUS-ENV-CORE).
const STATUS_COLORS := {
	"Fatal":      {"albedo": Color(0.95, 0.18, 0.12, 0.5),  "emit": Color(0.95, 0.22, 0.10)},
	"Oil":        {"albedo": Color(0.09, 0.07, 0.05, 0.80), "emit": Color(0.18, 0.12, 0.04)},
	"Fire":       {"albedo": Color(1.0, 0.45, 0.10, 0.55),  "emit": Color(1.0, 0.40, 0.05)},
	"ToxicGas":   {"albedo": Color(0.45, 0.85, 0.25, 0.40), "emit": Color(0.40, 0.85, 0.15)},
	"Water":      {"albedo": Color(0.25, 0.50, 0.95, 0.38), "emit": Color(0.18, 0.40, 0.85)},
	"Ice":        {"albedo": Color(0.62, 0.86, 1.0, 0.42),  "emit": Color(0.50, 0.78, 1.0)},
	"Steam":      {"albedo": Color(0.82, 0.86, 0.90, 0.34), "emit": Color(0.70, 0.74, 0.80)},
	"Smoke":      {"albedo": Color(0.32, 0.32, 0.34, 0.42), "emit": Color(0.20, 0.20, 0.22)},
	"Vegetation": {"albedo": Color(0.28, 0.55, 0.22, 0.45), "emit": Color(0.18, 0.42, 0.12)},
	"Wind":       {"albedo": Color(0.70, 0.95, 0.85, 0.26), "emit": Color(0.55, 0.85, 0.72)},
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
	if dps <= 0.0 and slow_factor <= 0.0 and not MOVEMENT_MEDIA.has(status):
		return  # inert (harmless Smoke/Vegetation, or empty)
	_tick_accum += delta
	if _tick_accum < TICK_S:
		return
	var dmg := dps * _tick_accum
	_tick_accum = 0.0
	for g in UNIT_GROUPS:
		for u in get_tree().get_nodes_in_group(g):
			if not (u is Node3D) or not contains_point((u as Node3D).global_position):
				continue
			_apply_medium(u, dmg, g)


## Apply this medium's per-tick outcome to a unit inside (피아무구분, F-021). 매체→결과 디스패치.
func _apply_medium(u: Node, dmg: float, g: String) -> void:
	match status:
		"Fire":  # 점화 — Ignited DoT (carries dps); raw fallback for units w/o the outcome system
			if u.has_method("apply_outcome"):
				u.apply_outcome("Ignited", OUTCOME_DUR, dps)
			elif u.has_method("take_damage"):
				u.take_damage(dmg)
			_credit(u, dmg, g)
		"ToxicGas":  # 독기 — Poisoned DoT (party); raw for enemies (no poison status)
			if u.has_method("apply_poison"):
				u.apply_poison(OUTCOME_DUR, dps)
			elif u.has_method("take_damage"):
				u.take_damage(dmg)
			_credit(u, dmg, g)
		"Smoke", "Vegetation":
			pass  # harmless — Smoke = vision (deferred), Vegetation = flammable only
		_:
			if MEDIUM_OUTCOME.has(status) and u.has_method("apply_outcome"):
				u.apply_outcome(MEDIUM_OUTCOME[status], OUTCOME_DUR)  # Water/Ice/Oil/Steam/Wind
			elif dps > 0.0 and u.has_method("take_damage"):  # Fatal + unknown → raw
				u.take_damage(dmg)
				_credit(u, dmg, g)
	if slow_factor > 0.0 and u.has_method("apply_slow"):
		u.apply_slow(slow_factor, OUTCOME_DUR)  # legacy explicit slow (separate from medium)


## Torch fire / zone damage on an enemy pulls aggro onto the credited source (F-021).
func _credit(u: Node, dmg: float, g: String) -> void:
	if g == "enemy" and _source != null and is_instance_valid(_source) and u.has_method("add_threat"):
		u.add_threat(_source, dmg)
		if u.has_method("perceive_attacker"):
			u.perceive_attacker(_source)


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
