extends Node3D
## ENT-TORCH-001 — a lit, carriable, throwable fire source (F-021 §3.1.2, F-027
## ENT-TORCH → FireDamageHit). Lifecycle: PLACED on the ground (interactable, lit) →
## carried by a unit (ally via a consumable slot, enemy via AI) → thrown to a point where
## it lands and ignites. It is ALWAYS lit, so touching an Oil zone ignites it on the spot
## (RX-OIL-FIRE) — carrying it over oil is a real risk. ref: F-021, F-027.

const ID := "ENT-TORCH-001"
const IGNITE_RADIUS := 2.4
const CARRY_OFFSET := Vector3(0.0, 1.4, 0.0)
const THROW_DUR := 0.55
const THROW_ARC := 2.5            # peak height of the toss arc (m)
const OIL_CHECK_S := 0.12

signal pickup_requested(torch)    # ally F-interact → scene picks the slot + calls pick_up()
signal dropped(torch)             # carrier died → torch fell (scene clears its carry state)

var _combat: Node3D = null        # provides ignite_at(pos, radius) → FireDamageHit
var _carrier: Node3D = null
var _thrower: Node3D = null    # last carrier — credited for threat when this torch's fire hits
var _thrown: bool = false
var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _t: float = 0.0
var _oil_timer: float = 0.0
var _rest_y: float = 0.0
var _body: StaticBody3D
var _light: OmniLight3D       # the flame's glow — moves with carry/throw (diegetic room light)


func setup(combat: Node3D) -> void:
	_combat = combat


func _ready() -> void:
	_rest_y = position.y
	add_to_group("interactable")
	add_to_group("carriable")
	add_to_group("torch")
	_build_visual()


## Tune the torch's light (room placement sets per-profile energy/range; default is warm).
func configure_light(energy: float, rng: float, color: Color) -> void:
	if _light == null:
		return
	_light.light_energy = energy
	_light.omni_range = rng
	_light.light_color = color


# --- interactable contract (duck-typed, group "interactable") -------------------
func interact_prompt() -> String:
	return "횃불  (F: 들기)"


func interact_anchor() -> Vector3:
	return global_position + Vector3(0.0, 1.9, 0.0)


func interact() -> void:
	if is_available():
		pickup_requested.emit(self)   # scene runs the ally slot-pick → pick_up()


# --- carry / throw API ----------------------------------------------------------
func is_available() -> bool:
	return _carrier == null and not _thrown


func pick_up(carrier: Node3D) -> void:
	_carrier = carrier
	_thrown = false
	remove_from_group("interactable")   # not interactable while held
	_set_body_enabled(false)


## Throw to a ground point — arcs over THROW_DUR, then lands + ignites (FireDamageHit).
func throw_to(target: Vector3) -> void:
	_thrower = _carrier   # the thrower takes the aggro from this torch's fire
	_carrier = null
	_thrown = true
	_from = global_position
	_to = Vector3(target.x, _rest_y, target.z)
	_t = 0.0


## Carrier died / removed — the torch falls where it is and stays (re-grabbable), NOT consumed.
func drop() -> void:
	_carrier = null
	_thrown = false
	global_position.y = _rest_y
	add_to_group("interactable")
	_set_body_enabled(true)
	dropped.emit(self)


func _process(delta: float) -> void:
	if _carrier != null:
		if not is_instance_valid(_carrier) or (_carrier.has_method("is_alive") and not _carrier.is_alive()):
			drop()
		else:
			global_position = _carrier.global_position + CARRY_OFFSET
	elif _thrown:
		_t = minf(1.0, _t + delta / THROW_DUR)
		var p: Vector3 = _from.lerp(_to, _t)
		p.y += sin(_t * PI) * THROW_ARC
		global_position = p
		if _t >= 1.0:
			_land_thrown()
	# Always lit: contact with an active Oil zone ignites it here (risk while carried).
	_oil_timer -= delta
	if _oil_timer <= 0.0:
		_oil_timer = OIL_CHECK_S
		_check_oil_contact()


func _check_oil_contact() -> void:
	if _combat == null or not _combat.has_method("ignite_at"):
		return
	for z in get_tree().get_nodes_in_group("ground_zone"):
		if z.has_method("is_active") and z.is_active() and String(z.status) == "Oil":
			var d := Vector2(z.global_position.x - global_position.x, z.global_position.z - global_position.z)
			if d.length() <= float(z.radius):
				_combat.ignite_at(global_position, IGNITE_RADIUS, _carrier if _carrier != null else _thrower)
				return


## A thrown torch lands → FireDamageHit (ignites oil / lays fire) → breaks (consumed).
## ref: F-021 §3.1.2 — a thrown torch is spent.
func _land_thrown() -> void:
	_thrown = false
	global_position = Vector3(_to.x, _rest_y, _to.z)
	if _combat != null and _combat.has_method("ignite_at"):
		_combat.ignite_at(global_position, IGNITE_RADIUS, _thrower)
	queue_free()   # thrown torch is consumed / destroyed


func _set_body_enabled(on: bool) -> void:
	if _body != null:
		_body.collision_layer = (1 << 4) if on else 0   # interactable raycast only when placed


func _build_visual() -> void:
	var handle := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.09
	cyl.height = 1.0
	handle.mesh = cyl
	handle.position.y = 0.5
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.32, 0.2, 0.1)
	handle.material_override = hm
	add_child(handle)

	var flame := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.22
	sph.height = 0.5
	flame.mesh = sph
	flame.position.y = 1.18
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.55, 0.15)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.5, 0.1)
	fm.emission_energy_multiplier = 2.6
	flame.material_override = fm
	add_child(flame)

	_light = OmniLight3D.new()      # warm flame glow (shadowless — many torches light the rooms)
	_light.position.y = 1.18
	_light.light_color = Color(1.0, 0.72, 0.42)
	_light.light_energy = 1.6
	_light.omni_range = 13.0
	_light.omni_attenuation = 1.0
	_light.shadow_enabled = false
	add_child(_light)

	_body = StaticBody3D.new()
	_body.collision_layer = 1 << 4   # interactable layer (hover/F raycast); NOT world → walk-through
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 1.4, 0.5)
	cs.shape = box
	cs.position.y = 0.7
	_body.add_child(cs)
	add_child(_body)
