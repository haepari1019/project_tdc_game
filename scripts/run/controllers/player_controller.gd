extends Node
## Top-down input on parent CharacterBody3D (controlled party member only).

@export var move_speed: float = 9.0

## Phase 3 accel model — injected by party_controller when motion_feel block is present.
var use_accel_model: bool = false
var accel_mps2: float = 90.0
var decel_mps2: float = 120.0

## Auto-move order (right-click ground → walk there; an interactable → walk to it + interact).
## 오더 상태·이동 규칙은 **party_member 가 소유**한다(스왑을 넘어 살아남아야 하고, 비조작
## 멤버는 party_controller 가 같은 규칙으로 구동해야 하므로). 여기서는 조작 중인 멤버에 대해
## WASD 우선 → 없으면 멤버 오더 소비, 만 한다. 어떤 WASD 입력이든 오더를 취소한다.

## Directional speed vs facing (= camera-forward): W fastest, A/D normal, S slowest.
const SLIP_ACCEL_MPS2 := 10.0   # Slippery (oil): low accel/decel — slidey, hard to stop/turn
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
		return  # 기절은 일시적 — 오더는 유지(풀리면 이어서 걸어간다)
	# Provoked (AB-099): movement input is locked — the member is forced toward the caster
	# (so it gets into basic range; the forced attack itself runs in CombatController).
	# 오더는 apply_provoke 가 이미 취소했다.
	if body.has_method("is_provoked") and body.is_provoked():
		_drive_provoked(body)
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input != Vector2.ZERO:
		body.cancel_order()    # manual WASD cancels an auto-move order (HOLD 포함)
	elif body.has_move_order():
		# 캐스팅(윈드업/채널) 중이면 오더 이동을 **일시정지**한다 — 오더는 유지되므로 시전이
		# 끝나면 목표 지점으로 이어서 걸어간다. WASD 는 위에서 이미 오더를 취소했으니 여기
		# 오지 않는다(직접 움직이면 시전 취소 = 기존 규칙 유지). 비조작 멤버는
		# party_controller Pass 1/3 이 채널 분기에서 같은 처리를 이미 한다.
		# 정지 중엔 order_desired_velocity 를 부르지 않으므로 끼임 타이머도 안 쌓인다.
		if body.has_method("is_channeling") and body.is_channeling():
			body.velocity = Vector3.ZERO
			body.move_and_slide()
			return
		_drive_order(body, delta)
		return
	elif body.is_order_holding():
		body.velocity = Vector3.ZERO   # 도착 후 정지 유지(WASD 로만 풀린다)
		body.move_and_slide()
		return
	var v_target := _target_velocity(input)
	if body.has_method("move_speed_mult"):
		v_target *= body.move_speed_mult()  # Oil slick etc.
	if body.has_method("is_slippery") and body.is_slippery():
		# Slippery (oil): low accel/decel → slides, hard to start/stop or change direction.
		body.velocity = body.velocity.move_toward(v_target, SLIP_ACCEL_MPS2 * delta)
	elif use_accel_model:
		var a: float = accel_mps2 if v_target.length_squared() > 0.01 else decel_mps2
		body.velocity = body.velocity.move_toward(v_target, a * delta)
	else:
		body.velocity = v_target
	body.move_and_slide()


## Provoked forced movement: walk toward the taunt caster until inside basic range, then
## hold (the forced attack runs in CombatController). Navmesh-routed; faces the caster.
func _drive_provoked(body: CharacterBody3D) -> void:
	var src = body.get_provoke_source()
	if src == null or not is_instance_valid(src):
		body.velocity = Vector3.ZERO
		body.move_and_slide()
		return
	var to: Vector3 = src.global_position - body.global_position
	to.y = 0.0
	var stop_at: float = maxf(float(body.get("basic_range_m")) - 0.3, 0.6)
	if to.length() <= stop_at:
		body.velocity = Vector3.ZERO
	else:
		var wp: Vector3 = src.global_position
		if body.has_method("nav_set_target"):
			body.nav_set_target(src.global_position)  # route around walls
			wp = body.nav_get_next_position()
		var d: Vector3 = wp - body.global_position
		d.y = 0.0
		body.velocity = (d.normalized() * move_speed) if d.length() > 0.05 else Vector3.ZERO
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
## 오더 자체는 멤버가 소유한다 — 여기서는 조작 중인 멤버에게 전달만 한다. 스왑해도 살아남아
## party_controller 가 이어서 구동한다. cb 있는 심부름(상호작용·캐스트 접근)은 도착 시 풀리고,
## cb 없는 순수 이동 오더는 그 자리에 HOLD 한다.
func order_move_to(target: Vector3, cb: Callable, arrive_dist: float) -> void:
	var body := get_parent() as CharacterBody3D
	if body != null and body.has_method("order_move_to"):
		body.order_move_to(target, cb, arrive_dist)


func cancel_move() -> void:
	var body := get_parent() as CharacterBody3D
	if body != null and body.has_method("cancel_order"):
		body.cancel_order()


## 조작 중인 멤버의 오더 구동. 웨이포인트 추종·도착·끼임 판정은 멤버가 소유하고 여기서는
## 가속 모델만 얹는다 — 비조작 경로(party_controller Pass 1/3)와 동일 규칙을 쓰기 위해.
func _drive_order(body: CharacterBody3D, delta: float) -> void:
	var v_target: Vector3 = body.order_desired_velocity(move_speed, delta)
	if v_target != Vector3.ZERO and body.has_method("move_speed_mult"):
		v_target *= body.move_speed_mult()
	if use_accel_model:
		body.velocity = body.velocity.move_toward(v_target, accel_mps2 * delta)
	else:
		body.velocity = v_target
	body.move_and_slide()
