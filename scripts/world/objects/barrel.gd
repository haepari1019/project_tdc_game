extends Node3D
## ENT-BARREL — a breakable barrel. Takes damage (group "destructible"); on Break it
## spawns an Oil HazardZone (passable, flammable, persists). A fire hit on the oil triggers
## the ignition reaction (RX-OIL-FIRE, chunk 2). ref: ENT-BARREL-001 / F-027.

const HazardZone := preload("res://scripts/world/hazards/hazard_zone.gd")

const OIL_RADIUS := 3.0

var max_hp: float = 40.0
var hp: float = 40.0
var _broken: bool = false
var _mat: StandardMaterial3D
var _flash_tw: Tween


func _ready() -> void:
	add_to_group("destructible")
	add_to_group("interactable")   # 적이 seek 가능(enemy_usable) — F-021 §3.1.2
	_build()


# --- enemy-usable object protocol (F-021 §3.1.2) — 즉발형(INSTANT). torch(held형)와 달리 enemy_use가
# 즉시 부수고 held_object를 설정하지 않으므로 enemy_combat_tick(held 거동)은 구현하지 않는다(optional 훅).
# 거동 로직은 오브젝트가 소유(enemy AI는 제네릭하게 호출만). ref: enemy_ai.ENEMY_USABLE_OBJECTS. ---

## 적이 seek + 사용 가능한가(안 부서졌으면). 구현 = "적이 나를 쓸 수 있다" opt-in.
func enemy_usable() -> bool:
	return not _broken


## 적이 도달 → 즉발 파괴(oil pool 생성). held 안 함 → 다음 틱 적은 일반 교전 복귀.
func enemy_use(_enemy: Node3D) -> void:
	if _broken:
		return
	_break()   # 재사용(기존 파괴 경로) → oil pool. RX-OIL-FIRE는 불 소스가 닿을 때 별도 점화.


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
	oil.setup(OIL_RADIUS, 0.0, 0.0, "Oil", false, 10.0, 0.5)  # passable; slows(slick). 10s 지속(영속 제거 — 리소스 유계 원칙)
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
