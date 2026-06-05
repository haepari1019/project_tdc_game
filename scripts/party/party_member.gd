extends CharacterBody3D
## One party slot — capsule placeholder (A2 replaces mesh).

signal became_controlled
signal became_non_controlled

const LAYER_PARTY := 2
const MASK_PARTY := 3
const MASK_WORLD_ONLY := 1
const DEFAULT_COLLISION_RADIUS := 0.26
const DEFAULT_COLLISION_HEIGHT := 1.15

const CONTROLLED_SCALE := 1.15
const CONTROLLED_EMISSION := 0.55

var identity_skill_id: String = ""
var class_id: String = ""
var ability_id: String = ""
var slot_index: int = -1
## Seconds to wait before moving toward a new slot after layout forward changes.
var follow_reposition_delay_s: float = 0.0

var _controlled: bool = false
var _base_color: Color = Color.WHITE
var _body_material: StandardMaterial3D


func setup(row: Dictionary, index: int, color: Color, collision_radius: float = -1.0, collision_height: float = -1.0) -> void:
	identity_skill_id = String(row.get("identity_skill_id", ""))
	class_id = String(row.get("class_id", ""))
	ability_id = String(row.get("ability_id", ""))
	slot_index = index
	_base_color = color
	name = identity_skill_id
	_apply_collision_size(collision_radius, collision_height)
	_ensure_unique_material(color)
	collision_layer = LAYER_PARTY
	collision_mask = MASK_PARTY
	add_to_group("party_member")
	_apply_controlled_visual(false)


func set_controlled(active: bool) -> void:
	if _controlled == active:
		return
	_controlled = active
	if active:
		add_to_group("player")
		became_controlled.emit()
	else:
		remove_from_group("player")
		became_non_controlled.emit()
	_apply_controlled_visual(active)


func is_controlled() -> bool:
	return _controlled


func set_party_member_collision(enabled: bool) -> void:
	collision_mask = MASK_PARTY if enabled else MASK_WORLD_ONLY


func _apply_collision_size(radius: float, height: float) -> void:
	var col_shape := $CollisionShape3D.shape as CapsuleShape3D
	if col_shape == null:
		return
	col_shape.radius = radius if radius > 0.0 else DEFAULT_COLLISION_RADIUS
	col_shape.height = height if height > 0.0 else DEFAULT_COLLISION_HEIGHT


func _ensure_unique_material(color: Color) -> void:
	var mesh := get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null:
		return
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = color
	_body_material.roughness = 0.45
	mesh.material_override = _body_material


func _apply_controlled_visual(active: bool) -> void:
	if _body_material:
		_body_material.emission_enabled = active
		_body_material.emission = _base_color * CONTROLLED_EMISSION if active else Color.BLACK
	scale = Vector3.ONE * CONTROLLED_SCALE if active else Vector3.ONE
