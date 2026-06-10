extends Node3D
## World chest — a lootable container holding inventory items (e.g. a key). Interacting
## (proximity + interact key) opens the loot view; items are dragged out into the player
## backpack (cross-container move). ref: world loop (chest→key→door→extraction) / F-010.

var title := "CHEST"
var items: Array = []        # [{id, w, h, col, row, color}] — persisted by InventoryUI
var _inv: Node = null        # InventoryUI


func setup(inv: Node) -> void:
	_inv = inv


func _ready() -> void:
	add_to_group("interactable")
	_build_visual()


# --- interactable contract (duck-typed, group "interactable") -------------------

func interact_prompt() -> String:
	return "%s\n[우클릭] 열기" % title


func interact_anchor() -> Vector3:
	return global_position + Vector3(0, 1.6, 0)  # just above the chest


func interact() -> void:
	if _inv:
		_inv.open_loot(self)


func _build_visual() -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.5, 1.1, 1.1)
	mi.mesh = bm
	mi.position.y = 0.55
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.40, 0.18)
	mat.emission_enabled = true
	mat.emission = Color(0.30, 0.22, 0.06)
	mat.emission_energy_multiplier = 0.6   # faint glow so it reads in dim rooms
	mi.material_override = mat
	add_child(mi)

	var body := StaticBody3D.new()
	body.collision_layer = 1 | (1 << 4)    # world (solid/cover) + interactable (hover raycast)
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.1, 1.1)
	cs.shape = box
	cs.position.y = 0.55
	body.add_child(cs)
	add_child(body)
