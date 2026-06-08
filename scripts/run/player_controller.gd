extends Node
## Top-down input on parent CharacterBody3D (controlled party member only).

@export var move_speed: float = 9.0

## Phase 3 accel model — injected by party_controller when motion_feel block is present.
var use_accel_model: bool = false
var accel_mps2: float = 90.0
var decel_mps2: float = 120.0

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
		return
	if body.has_method("is_stunned") and body.is_stunned():
		body.velocity = Vector3.ZERO
		body.move_and_slide()
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var v_target := _target_velocity(input)
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
