extends Node3D
## Fixed lantern — a stationary, contained light for stable room lighting (room centers /
## major entry points). Unlike ENT-TORCH it is NOT carriable/throwable and does NOT ignite oil
## (no "torch"/"interactable"/enemy_usable surface), so neither players nor enemies can grab it
## and the room stays lit. configure_light() sets per-room brightness. ref: lighting (not F-021).

var _light: OmniLight3D


## Tune the lantern's light (room placement sets per-profile energy/range/color).
func configure_light(energy: float, rng: float, color: Color) -> void:
	if _light == null:
		return
	_light.light_energy = energy
	_light.omni_range = rng
	_light.light_color = color


func _ready() -> void:
	add_to_group("lantern")
	_build()


func _build() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.16, 0.15, 0.14)
	metal.metallic = 0.5
	metal.roughness = 0.5

	# Wide flat base — reads as a standing floor fixture (not a handheld torch).
	var base := MeshInstance3D.new()
	var bcyl := CylinderMesh.new()
	bcyl.top_radius = 0.20
	bcyl.bottom_radius = 0.27
	bcyl.height = 0.12
	base.mesh = bcyl
	base.position.y = 0.06
	base.material_override = metal
	add_child(base)

	# Tall thin pole.
	var pole := MeshInstance3D.new()
	var pcyl := CylinderMesh.new()
	pcyl.top_radius = 0.045
	pcyl.bottom_radius = 0.06
	pcyl.height = 2.0
	pole.mesh = pcyl
	pole.position.y = 1.05
	pole.material_override = metal
	add_child(pole)

	# Caged glowing housing (boxy, contained) — distinct from the torch's pointed open flame.
	var head := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.30, 0.40, 0.30)
	head.mesh = box
	head.position.y = 2.10
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(1.0, 0.90, 0.66)
	hm.emission_enabled = true
	hm.emission = Color(1.0, 0.84, 0.52)
	hm.emission_energy_multiplier = 1.8
	head.material_override = hm
	add_child(head)

	# Roof cap (lantern lid).
	var cap := MeshInstance3D.new()
	var ccyl := CylinderMesh.new()
	ccyl.top_radius = 0.02
	ccyl.bottom_radius = 0.25
	ccyl.height = 0.14
	cap.mesh = ccyl
	cap.position.y = 2.37
	cap.material_override = metal
	add_child(cap)

	# Light — pale gold, STEADY (no flicker) vs the torch's hot, flickering orange.
	_light = OmniLight3D.new()
	_light.position.y = 2.10
	_light.light_color = Color(1.0, 0.87, 0.64)
	_light.light_energy = 1.5
	_light.omni_range = 13.0
	_light.omni_attenuation = 1.0
	_light.shadow_enabled = false
	add_child(_light)
