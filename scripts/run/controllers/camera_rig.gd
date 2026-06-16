extends Node3D
## CameraRig — owns the gameplay camera feel: tight follow / swap glide (accel·
## decel) / RMB-drag orbit yaw / trauma shake (rotational + directional kick).
## Attached to the CameraPivot node (Camera3D is its child). dungeon_run drives it
## via set_follow_target / glide_to_current / orbit_yaw / add_shake — keeping scene
## orchestration and camera feel separate (extracted from dungeon_run). ref: F-012.

# RMB + horizontal drag yaws the pivot around the controlled char.
const YAW_SENS := 0.006  # radians per pixel of horizontal drag
# RMB + vertical drag tilts the pitch (drag down → lower angle toward horizontal).
const PITCH_DRAG_SENS := 0.15  # degrees per pixel of vertical drag

# Camera placement (code-driven so angle + zoom are tweakable + scroll-zoomable, overriding the
# scene transform). Lower PITCH = more horizontal → better enemy silhouette/motion readability
# for reading squad composition; 90 = top-down. DISTANCE = zoom (scroll wheel). ref: F-012.
# Isometric framing (genre standard: Diablo/Lost Ark/Hades) — moderate angle + moderate distance.
# Bird's-eye-far = detached "commander"; zoomed-close = cramped; shallow = camera behind walls.
# Tunable live in-game: scroll = distance, [ / ] = pitch (console prints the values to bake).
const PITCH_DEG := 40.0          # initial down-tilt (low cinematic; see-through handles wall occlusion)
const PITCH_MIN := 15.0   # low cinematic (lowered from 30; wall_xray handles the wall occlusion)
const PITCH_MAX := 85.0   # near top-down (raised from 65 — the top-down limit came too fast)
const DISTANCE_DEFAULT := 19.0   # a bit further out
const DISTANCE_MIN := 12.0
const DISTANCE_MAX := 24.0
const ZOOM_STEP := 1.5           # metres per scroll notch
const PITCH_STEP := 3.0          # degrees per [ / ] press

# Swap glide — on 1~4 swap the pivot eases to the new char (accel/decel) instead of
# teleporting; normal follow stays tight (no lag).
const SWAP_MAX_SPEED := 60.0     # m/s glide cap
const SWAP_ACCEL := 320.0        # m/s² velocity ramp (accel in / decel out)
const SWAP_ARRIVE_GAIN := 6.0    # desired speed = dist*gain (arrive ease-out), capped

# Shake (trauma model). 탑다운 원거리 카메라라 위치 흔들림은 거의 안 보여 → 흔들림은
# **회전(rotational)** 으로(거리 무관 체감), 방향 킥만 위치 오프셋. 진폭 = trauma^1.5.
const SHAKE_DECAY := 1.8         # trauma/s 감쇠
const SHAKE_MAX_ROT_DEG := 3.5   # trauma=1일 때 최대 회전 흔들림(도)
const KICK_RETURN := 7.0         # 방향 킥이 0으로 복귀(m/s)

@onready var _camera: Camera3D = $Camera3D

var _follow_target: Node3D = null
var _gliding: bool = false
var _follow_vel: Vector3 = Vector3.ZERO
var _trauma: float = 0.0
var _kick: Vector3 = Vector3.ZERO          # world XZ; per-frame 화면기준으로 변환 적용
var _cam_base_pos: Vector3 = Vector3.ZERO  # rig offset to add the directional kick on top of
var _cam_base_rot: Vector3 = Vector3.ZERO  # base look angle to jitter (rotational shake)
var _distance: float = DISTANCE_DEFAULT    # current zoom (scroll wheel)
var _pitch: float = PITCH_DEG               # current down-tilt ([ / ] keys)


func _ready() -> void:
	_apply_placement()  # code-driven angle/distance (overrides the scene Camera3D transform)
	# Face the dungeon's forward progression (+Z: Entry→Advance→Extraction) up-screen
	# at entry, so W moves into the dungeon. RMB-drag rotates relative to this.
	rotation.y = PI


## Place the camera behind+above at PITCH_DEG, looking at the pivot (the controlled char).
## Re-applied on zoom; updates the shake base so trauma/kick layer on top of the placement.
func _apply_placement() -> void:
	var p := deg_to_rad(_pitch)
	_camera.position = Vector3(0.0, _distance * sin(p), _distance * cos(p))
	_camera.rotation = Vector3(-p, 0.0, 0.0)  # look down `_pitch` toward the pivot origin
	_cam_base_pos = _camera.position
	_cam_base_rot = _camera.rotation


## Scroll-zoom (dir = +1 in / -1 out), clamped. Keeps the look angle (dolly).
func zoom(dir: int) -> void:
	_distance = clampf(_distance - dir * ZOOM_STEP, DISTANCE_MIN, DISTANCE_MAX)
	_apply_placement()
	print("[CAM] pitch=%.0f°  distance=%.1f" % [_pitch, _distance])


## Live pitch tune ([ / ] keys). Console prints the values so the chosen feel can be baked in.
func adjust_pitch(delta_deg: float) -> void:
	_pitch = clampf(_pitch + delta_deg, PITCH_MIN, PITCH_MAX)
	_apply_placement()
	print("[CAM] pitch=%.0f°  distance=%.1f" % [_pitch, _distance])


## Follow this node. `glide` eases over (swap transition); else resume tight follow.
func set_follow_target(target: Node3D, glide: bool = true) -> void:
	_follow_target = target
	if glide:
		_gliding = true
		_follow_vel = Vector3.ZERO


## Re-glide to the current target (covers swap where the target node is unchanged).
func glide_to_current() -> void:
	_gliding = true
	_follow_vel = Vector3.ZERO


## RMB-drag horizontal motion → yaw around the controlled char.
func orbit_yaw(dx_pixels: float) -> void:
	rotate_y(-dx_pixels * YAW_SENS)


## RMB-drag vertical motion → tilt the pitch (inverted). Drag DOWN (dy_pixels > 0) raises the
## angle toward top-down; drag up lowers it toward horizontal. Clamped to [PITCH_MIN, PITCH_MAX].
func pitch_by_drag(dy_pixels: float) -> void:
	_pitch = clampf(_pitch + dy_pixels * PITCH_DRAG_SENS, PITCH_MIN, PITCH_MAX)
	_apply_placement()


## CombatController feeds trauma (0..1) + a world directional kick (피격=방향,
## 타격감=ZERO). Trauma is clamped (non-stacking blowup); kick adds (then decays).
func add_shake(trauma: float, kick_world: Vector3) -> void:
	_trauma = minf(1.0, _trauma + trauma)
	_kick += kick_world


func _process(delta: float) -> void:
	if _follow_target and is_instance_valid(_follow_target):
		if _gliding:
			_glide(_follow_target.global_position, delta)  # swap transition (accel/decel)
		else:
			global_position = _follow_target.global_position  # tight follow
	_apply_shake(delta)


## Ease the pivot toward `target` with accel + arrive-decel; snap & end on arrival.
func _glide(target: Vector3, delta: float) -> void:
	var to: Vector3 = target - global_position
	var dist := to.length()
	if dist < 0.2:
		global_position = target
		_follow_vel = Vector3.ZERO
		_gliding = false
		return
	var desired_speed: float = minf(dist * SWAP_ARRIVE_GAIN, SWAP_MAX_SPEED)
	var desired_vel: Vector3 = (to / dist) * desired_speed
	_follow_vel = _follow_vel.move_toward(desired_vel, SWAP_ACCEL * delta)
	global_position += _follow_vel * delta


## trauma^1.5 shake + decaying directional kick applied to the camera (not the pivot
## — keeps follow/glide untouched). Kick is rotated into screen space so it always
## points the hit direction regardless of orbit yaw.
func _apply_shake(delta: float) -> void:
	_trauma = maxf(0.0, _trauma - SHAKE_DECAY * delta)
	_kick = _kick.move_toward(Vector3.ZERO, KICK_RETURN * delta)
	var amp := pow(_trauma, 1.5)  # 작은 trauma는 미세, 큰 건 펀치(²보다 덜 깎임)
	# Rotational shake — felt regardless of the far top-down distance (roll 약하게).
	var r := deg_to_rad(SHAKE_MAX_ROT_DEG) * amp
	_camera.rotation = _cam_base_rot + Vector3(
		randf_range(-1.0, 1.0) * r,
		randf_range(-1.0, 1.0) * r,
		randf_range(-1.0, 1.0) * r * 0.5
	)
	# Directional kick stays positional (맞은 방향), screen-space via -pivot yaw.
	var kick_local := _kick.rotated(Vector3.UP, -rotation.y)
	_camera.position = _cam_base_pos + kick_local
