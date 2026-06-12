extends Node3D
## ENT-BARREL — a breakable barrel. Takes damage (group "destructible"); on Break it
## spawns an Oil HazardZone (passable, flammable, persists). A fire hit on the oil triggers
## the ignition reaction (RX-OIL-FIRE, chunk 2). ref: ENT-BARREL-001 / F-027.

const HazardZone := preload("res://scripts/run/hazard_zone.gd")

const OIL_RADIUS := 3.0

var max_hp: float = 40.0
var hp: float = 40.0
var _broken: bool = false
var _mat: StandardMaterial3D
var _flash_tw: Tween


func _ready() -> void:
	add_to_group("destructible")
	_build()


## Damaged by AoE skills (ability_dispatch). Breaks at 0 HP → oil pool.
func take_damage(amount: float) -> void:
	if _broken:
		return
	hp = maxf(0.0, hp - amount)
	_flash()
	if hp <= 0.0:
		_break()


func is_alive() -> bool:
	return not _broken


func _break() -> void:
	_broken = true
	remove_from_group("destructible")
	var oil := HazardZone.new()
	oil.setup(OIL_RADIUS, 0.0, 0.0, "Oil", false, -1.0, 0.5)  # passable; slows units (slick), persists
	oil.position = Vector3(global_position.x, 0.0, global_position.z)
	get_parent().add_child(oil)
	print("[TDC] Barrel broken → oil pool")
	queue_free()


func _flash() -> void:
	if _mat == null:
		return
	if _flash_tw and _flash_tw.is_valid():
		_flash_tw.kill()
	_mat.albedo_color = Color(1.0, 0.7, 0.4)
	_flash_tw = create_tween()
	_flash_tw.tween_property(_mat, "albedo_color", Color(0.35, 0.22, 0.10), 0.18)


func _build() -> void:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.65
	cyl.height = 1.5
	mesh.mesh = cyl
	mesh.position.y = 0.75
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.35, 0.22, 0.10)
	_mat.metallic = 0.25
	_mat.roughness = 0.6
	mesh.material_override = _mat
	add_child(mesh)
	var body := StaticBody3D.new()
	body.collision_layer = 1  # world (blocks movement / LOS)
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.6
	shape.height = 1.5
	cs.shape = shape
	cs.position.y = 0.75
	body.add_child(cs)
	add_child(body)
