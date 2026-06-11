extends Node3D
## Lever — interactable that resets a linked Trap (clears its fatal zone + re-arms it),
## re-opening the chokepoint the trap split. Placed on the far (front) side so resolving
## the split requires the crossed-over member to walk to it. ref: world loop / F-006.

const POST := Vector3(0.5, 1.4, 0.5)

var _trap: Node = null
var _handle: MeshInstance3D


func setup(trap: Node) -> void:
	_trap = trap


func _ready() -> void:
	add_to_group("interactable")
	_build()


func interact_prompt() -> String:
	if _trap != null and _trap.has_method("has_active_zone") and _trap.has_active_zone():
		return "레버\n[우클릭] 함정 회복 (장판 해제)"
	return "레버\n[우클릭] 당기기"


func interact_anchor() -> Vector3:
	return global_position + Vector3(0, POST.y + 0.7, 0)


func interact() -> void:
	if _trap != null and _trap.has_method("reset"):
		_trap.reset()
		print("[TDC] Lever pulled — trap reset, fatal zone cleared")
	if _handle:
		var tw := _handle.create_tween()
		tw.tween_property(_handle, "rotation_degrees:x", -45.0, 0.15)
		tw.tween_property(_handle, "rotation_degrees:x", 0.0, 0.5)


func _build() -> void:
	var post := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = POST
	post.mesh = bm
	post.position.y = POST.y * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.32, 0.40)
	mat.emission_enabled = true
	mat.emission = Color(0.20, 0.42, 0.7)
	mat.emission_energy_multiplier = 0.7
	post.material_override = mat
	add_child(post)

	_handle = MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.18, 1.0, 0.18)
	_handle.mesh = hb
	_handle.position = Vector3(0, POST.y + 0.3, 0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.85, 0.72, 0.30)
	hmat.emission_enabled = true
	hmat.emission = Color(0.7, 0.5, 0.1)
	_handle.material_override = hmat
	add_child(_handle)

	var body := StaticBody3D.new()
	body.collision_layer = 1 | (1 << 4)   # world + interactable (hover/raycast)
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, POST.y + 1.2, 0.9)
	cs.position.y = (POST.y + 1.2) * 0.5
	cs.shape = box
	body.add_child(cs)
	add_child(body)
