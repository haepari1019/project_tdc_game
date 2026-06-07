extends Node
## Top-down input on parent CharacterBody3D (controlled party member only).

@export var move_speed: float = 9.0

## Phase 3 accel model — injected by party_controller when motion_feel block is present.
var use_accel_model: bool = false
var accel_mps2: float = 90.0
var decel_mps2: float = 120.0


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
	var direction := Vector3(input.x, 0, input.y)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	var v_target := direction * move_speed
	if use_accel_model:
		var a: float = accel_mps2 if direction.length_squared() > 0.01 else decel_mps2
		body.velocity = body.velocity.move_toward(v_target, a * delta)
	else:
		body.velocity = v_target
	body.move_and_slide()
