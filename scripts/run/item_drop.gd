extends Node3D
## World item drop (from a defeated enemy). A small glowing, spinning cube colored by the
## item; hovering shows its name, right-click sends the controlled member to walk over and
## pick it up into the backpack (reuses the interaction + auto-move system). Does NOT block
## movement (collision is on the interact layer only). ref: world loop / F-010 loot.

var item: Dictionary = {}     # {id, w, h, color}
var _inv: Node = null         # InventoryUI


func setup(inv: Node, item_def: Dictionary) -> void:
	_inv = inv
	item = item_def


func _ready() -> void:
	add_to_group("interactable")
	_build()


func _process(delta: float) -> void:
	rotate_y(delta * 1.6)  # slow spin so drops read as pickups


# --- interactable contract (group "interactable") ------------------------------

func interact_prompt() -> String:
	return "%s\n[우클릭] 줍기" % String(item.get("id", "Item"))


func interact_anchor() -> Vector3:
	return global_position + Vector3(0, 0.95, 0)


func interact() -> void:
	if _inv == null:
		return
	var ok: bool = _inv.add_to_backpack(String(item.id), int(item.w), int(item.h), item.color)
	if ok:
		queue_free()  # picked up — remove from the world
	# else: backpack full — leave the drop so the player can free space first


func _build() -> void:
	var c: Color = item.get("color", Color(0.8, 0.8, 0.4))
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.5, 0.5)
	mi.mesh = bm
	mi.position.y = 0.4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 0.8   # glow so drops are visible on the floor
	mi.material_override = mat
	add_child(mi)

	# Collision for the hover raycast ONLY (interact layer); mask 0 → never blocks anyone.
	var body := StaticBody3D.new()
	body.collision_layer = 1 << 4
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 0.8, 0.8)      # a bit larger than the mesh for easier hover
	cs.shape = box
	cs.position.y = 0.4
	body.add_child(cs)
	add_child(body)
