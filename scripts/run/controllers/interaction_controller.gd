extends Node
## Hover interaction — raycasts under the mouse for an interactable (collision layer
## "interactable") at ANY distance, and shows a floating label above it (name + open key)
## so the player can see what's interactable without walking up to it. A right-click orders
## the controlled member to walk to the object and interact on arrival. Suppressed while the
## inventory is open. ref: world loop (chest / door).
##
## Interactables duck-type: `interact_prompt() -> String`, `interact_anchor() -> Vector3`
## (world point above the object), `interact() -> void`; their collision body is on the
## INTERACT layer and the interactable Node3D is that body's parent (group "interactable").

const INTERACT_MASK := 1 << 4   # collision layer 5 = interactable (chest/door also on world)
const LABEL_GAP_PX := 12.0
const ARRIVE_DIST := 2.0        # how close the auto-move stops to the object
const INTERACT_RANGE := 4.0     # F-key reach to the nearest interactable (mouse-independent)
const MOVE_ARRIVE_DIST := 0.4   # click-to-move stop tolerance at the clicked ground point

var _party: Node3D = null
var _label: Label = null
var _inv: Node = null
## 지면 평면의 높이를 아는 유일한 통로 — **활성 층의 바닥**이다(레이어마다 다르다).
var _map: Node = null


func setup(party: Node3D, label: Label, inv: Node, map: Node = null) -> void:
	_party = party
	_label = label
	_inv = inv
	_map = map


func _process(_delta: float) -> void:
	if _label == null:
		return
	var it := _hovered()
	if it != null:
		var cam := get_viewport().get_camera_3d()
		_label.text = it.interact_prompt()
		_label.reset_size()
		var sp: Vector2 = cam.unproject_position(it.interact_anchor())
		_label.position = (sp - Vector2(_label.size.x * 0.5, _label.size.y + LABEL_GAP_PX)).round()
		_label.visible = true
	elif _label.visible:
		_label.visible = false


## RMB click: an interactable under the cursor → walk to it + interact on arrival; otherwise
## the empty ground → click-to-move to that point. Identity skills keep auto-firing on cooldown
## while the move order drives the controlled member (movement doesn't gate the combat loop).
func try_interact() -> void:
	if _inv != null and _inv.is_open():
		return
	var ctrl: Node3D = _party.get_controlled()
	if ctrl == null:
		return
	var pc := ctrl.get_node_or_null("Control")
	var it := _hovered()
	if it != null:
		# Walk to the interactable and interact on arrival (or interact now if no controller).
		if pc != null and pc.has_method("order_move_to"):
			pc.order_move_to((it as Node3D).global_position, Callable(it, "interact"), ARRIVE_DIST)
		else:
			it.interact()
		return
	# Empty ground → move the controlled member to the clicked point (click-to-move, no callback).
	if pc != null and pc.has_method("order_move_to"):
		var gp = _ground_under_mouse()
		if gp != null:
			pc.order_move_to(gp, Callable(), MOVE_ARRIVE_DIST)


## Ground point under the cursor via the floor plane. null if the ray is ~parallel.
func _ground_under_mouse():
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	return ground_at(cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))


## **지면 평면의 높이 = 활성 층의 바닥.** 예전에는 `y = 0` 고정이었다 — 지상만 있을 땐 맞지만
## 백레이어(바닥 −8 m)에서는 클릭한 곳이 **8 m 어긋난다**. 층마다 단차가 다르므로 상수로 둘 수 없고,
## 맵 문서 `layer_floor_y`가 소유한다.
func ground_plane_y() -> float:
	if _map != null and _map.has_method("layer_floor_y") and _map.has_method("get_active_layer"):
		return _map.layer_floor_y(_map.get_active_layer())
	return 0.0


## 광선 ↔ 지면 평면 교점. 평행이거나 뒤쪽이면 null. (테스트가 부를 수 있게 분리했다 —
## 마우스 좌표가 없어도 「어느 평면을 쓰는가」를 물을 수 있어야 한다.)
func ground_at(from: Vector3, dir: Vector3):
	if absf(dir.y) < 0.0001:
		return null
	var t := (ground_plane_y() - from.y) / dir.y
	if t <= 0.0:
		return null
	return from + dir * t


## F-key interaction: interact with the nearest interactable within range of the
## controlled member, regardless of where the mouse points.
func interact_nearest() -> void:
	if _inv != null and _inv.is_open():
		return
	var ctrl: Node3D = _party.get_controlled()
	if ctrl == null:
		return
	var nearest: Node = null
	var best := INTERACT_RANGE * INTERACT_RANGE
	for n in get_tree().get_nodes_in_group("interactable"):
		if not (n is Node3D):
			continue
		var d := (n as Node3D).global_position.distance_squared_to(ctrl.global_position)
		if d < best:
			best = d
			nearest = n
	if nearest == null:
		return
	nearest.interact()  # already in range → interact immediately (works while moving, no auto-walk)


## The interactable under the mouse cursor that is within range of the controlled member.
func _hovered() -> Node:
	if _inv != null and _inv.is_open():
		return null
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var to := from + cam.project_ray_normal(mouse) * 1000.0
	var q := PhysicsRayQueryParameters3D.create(from, to, INTERACT_MASK)
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var node: Node = (hit.collider as Node).get_parent()  # interactable owns the collision body
	if node == null or not node.is_in_group("interactable"):
		return null
	return node
