extends Node
## Top-down input on parent CharacterBody3D (controlled party member only).

@export var move_speed: float = 9.0

## Phase 3 accel model — injected by party_controller when motion_feel block is present.
var use_accel_model: bool = false
var accel_mps2: float = 90.0
var decel_mps2: float = 120.0

## Auto-move order (right-click ground → walk there; an interactable → walk to it + interact).
## Follows the navmesh path (around walls/carved zones) + a stuck timeout; any WASD cancels it.
var _move_active: bool = false
var _move_target: Vector3 = Vector3.ZERO
var _move_cb: Callable = Callable()
var _arrive_dist: float = 2.0
var _stuck_time: float = 0.0

## Directional speed vs facing (= camera-forward): W fastest, A/D normal, S slowest.
const FORWARD_SPEED_MULT := 1.0
const STRAFE_SPEED_MULT := 0.75
const BACK_SPEED_MULT := 0.65


func _physics_process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	if body == null:
		return
	# Downed or stunned (F-021): no input, halt in place.
	if body.has_method("is_alive") and not body.is_alive():
		body.velocity = Vector3.ZERO
		_move_active = false
		return
	if body.has_method("is_stunned") and body.is_stunned():
		body.velocity = Vector3.ZERO
		body.move_and_slide()
		_move_active = false
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input != Vector2.ZERO:
		_move_active = false   # manual WASD cancels an auto-move order
	if _move_active:
		_drive_to_target(body, delta)
		return
	var v_target := _target_velocity(input)
	if body.has_method("move_speed_mult"):
		v_target *= body.move_speed_mult()  # Oil slick etc.
	if use_accel_model:
		var a: float = accel_mps2 if v_target.length_squared() > 0.01 else decel_mps2
		body.velocity = body.velocity.move_toward(v_target, a * delta)
	else:
		body.velocity = v_target
	body.move_and_slide()


## Camera-relative target velocity with directional speed: forward (W) fastest,
## strafe (A/D) normal, backpedal (S) slowest. "Forward" = camera-forward (screen-up).
func _target_velocity(input: Vector2) -> Vector3:
	var fwd := Vector3.FORWARD
	var dir := Vector3(input.x, 0.0, input.y)  # fallback: world-fixed
	var cam := get_viewport().get_camera_3d()
	if cam:
		var b := cam.global_transform.basis
		var cf := -b.z
		cf.y = 0.0
		var cr := b.x
		cr.y = 0.0
		if cf.length_squared() > 0.0001 and cr.length_squared() > 0.0001:
			fwd = cf.normalized()
			dir = cr.normalized() * input.x + fwd * (-input.y)
	if dir.length_squared() < 0.0001:
		return Vector3.ZERO
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	# Speed multiplier by alignment with facing: +1 forward, 0 strafe, -1 back.
	var fdot := dir.normalized().dot(fwd)
	var mult: float = (
		lerpf(STRAFE_SPEED_MULT, FORWARD_SPEED_MULT, fdot) if fdot >= 0.0
		else lerpf(STRAFE_SPEED_MULT, BACK_SPEED_MULT, -fdot)
	)
	return dir * (move_speed * mult)


# --- auto-move order (issued by InteractionController on right-click) -----------

## Walk to `target` (stopping `arrive_dist` short), then invoke `cb`. WASD cancels it.
## Follows the navmesh path (routes around walls + carved fatal zones) via the member's nav
## helpers; Identity skills keep auto-firing on cooldown the whole way (combat loop, not gated).
func order_move_to(target: Vector3, cb: Callable, arrive_dist: float) -> void:
	_move_target = target
	_move_cb = cb
	_arrive_dist = arrive_dist
	_stuck_time = 0.0
	_move_active = true
	var body := get_parent() as CharacterBody3D
	if body != null and body.has_method("nav_set_target"):
		body.nav_set_target(target)  # seed the navmesh path


func cancel_move() -> void:
	_move_active = false


func _drive_to_target(body: CharacterBody3D, delta: float) -> void:
	# Arrive once within tolerance of the FINAL target (XZ).
	var to_final := _move_target - body.global_position
	to_final.y = 0.0
	if to_final.length() <= _arrive_dist:
		_arrive(body)
		return
	# Steer toward the next navmesh waypoint (routes around walls + carved zones); falls back to
	# a straight line if the body has no nav helper.
	var wp := _move_target
	if body.has_method("nav_set_target"):
		body.nav_set_target(_move_target)        # recompute throttled inside (target-distance gated)
		wp = body.nav_get_next_position()
	var to := wp - body.global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.05:                              # path exhausted / unreachable → stop at best point
		_arrive(body)
		return
	var v_target := (to / dist) * move_speed
	if body.has_method("move_speed_mult"):
		v_target *= body.move_speed_mult()
	if use_accel_model:
		body.velocity = body.velocity.move_toward(v_target, accel_mps2 * delta)
	else:
		body.velocity = v_target
	body.move_and_slide()
	# Truly blocked (shouldn't happen with navmesh routing) → drop the order after a beat.
	var real := body.get_real_velocity()
	real.y = 0.0
	if real.length() < 0.6:
		_stuck_time += delta
		if _stuck_time > 0.8:
			_move_active = false
	else:
		_stuck_time = 0.0


func _arrive(body: CharacterBody3D) -> void:
	body.velocity = Vector3.ZERO
	body.move_and_slide()
	_move_active = false
	_stuck_time = 0.0
	if _move_cb.is_valid():
		_move_cb.call()
