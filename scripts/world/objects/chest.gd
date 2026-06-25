extends Node3D
## World chest — a lootable container holding inventory items (e.g. a key). Interacting
## (proximity + interact key) opens the loot view; items are dragged out into the player
## backpack (cross-container move). ref: world loop (chest→key→door→extraction) / F-010.

var title := "CHEST"
var tier := "fixed"          # "common" | "rare" | "fixed"(퀘스트/특수) — 비주얼·등급 표시
var items: Array = []        # [{id, w, h, col, row, color}] — persisted by InventoryUI
var _inv: Node = null        # InventoryUI


func setup(inv: Node) -> void:
	_inv = inv


func _ready() -> void:
	add_to_group("interactable")
	_build_visual()


# --- interactable contract (duck-typed, group "interactable") -------------------

func interact_prompt() -> String:
	var badge := "  ✦ 희귀" if tier == "rare" else ""
	return "%s%s\n[우클릭] 열기" % [title, badge]


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
	# 티어 비주얼 — 희귀(좋은) 상자는 금색 + 강한 발광으로 한눈에 구분. 일반/고정은 갈색.
	if tier == "rare":
		mat.albedo_color = Color(0.82, 0.66, 0.20)
		mat.emission = Color(0.85, 0.62, 0.12)
		mat.emission_energy_multiplier = 1.6
	else:
		mat.albedo_color = Color(0.55, 0.40, 0.18)
		mat.emission = Color(0.30, 0.22, 0.06)
		mat.emission_energy_multiplier = 0.6   # faint glow so it reads in dim rooms
	mat.emission_enabled = true
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
