extends Node3D
## Keyed door — blocks the path to the extraction room until opened. Opening requires a
## key in the player backpack; on open it clears its collision + mesh and completes the
## run objective (RM-OBJ-01 chest → key → this door → extraction). ref: world loop / F-007.

const SIZE := Vector3(6.4, 3.2, 0.9)  # spans the ~6-wide route→extraction opening

var _inv: Node = null     # InventoryUI (key check)
var _run: Node = null     # RunController (objective)
var _opened := false
var _body: StaticBody3D = null
var _mesh: MeshInstance3D = null
var _occluders: Array = []   # F2: fog/cone occluders (closed door) — freed on open


func setup(inv: Node, run: Node) -> void:
	_inv = inv
	_run = run


## F2: dynamic fog/cone occluders for the closed door (registered by dungeon_run). The closed door
## now casts a vision shadow; opening frees them so light/cones pass through (fog updates next frame).
func set_occluders(occ: Array) -> void:
	_occluders = occ


func _ready() -> void:
	add_to_group("interactable")
	_build()


func interact_prompt() -> String:
	if _inv != null and _inv.backpack_has_key():
		return "문\n[우클릭] 열기"
	return "잠긴 문\n🔒 열쇠 필요"


func interact_anchor() -> Vector3:
	return global_position + Vector3(0, SIZE.y + 0.4, 0)  # above the door


func interact() -> void:
	if _opened:
		return
	if _inv == null or not _inv.backpack_has_key():
		return  # locked — prompt already says a key is needed
	_opened = true
	if _inv.has_method("consume_key"):
		_inv.consume_key()                    # 키 소모 — 문 열면 사라짐 (사용자 요청)
	remove_from_group("interactable")        # no more prompt / interaction
	if _body:
		_body.queue_free()                    # clear the barrier — path open
	if _mesh:
		_mesh.visible = false
	for o in _occluders:                      # F2: door open → vision (fog + cones) passes through
		if is_instance_valid(o):
			o.queue_free()
	if _run and _run.has_method("complete_objective"):
		_run.complete_objective()             # objective = door opened
	print("[TDC] Door opened with key — extraction path clear")


func _build() -> void:
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = SIZE
	_mesh.mesh = bm
	_mesh.position.y = SIZE.y * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.30, 0.20)
	mat.emission_enabled = true
	mat.emission = Color(0.32, 0.13, 0.05)
	mat.emission_energy_multiplier = 0.5
	_mesh.material_override = mat
	add_child(_mesh)

	_body = StaticBody3D.new()
	_body.collision_layer = 1 | (1 << 4)      # world (blocks movement/LOS) + interactable (hover)
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	cs.shape = box
	cs.position.y = SIZE.y * 0.5
	_body.add_child(cs)
	add_child(_body)
