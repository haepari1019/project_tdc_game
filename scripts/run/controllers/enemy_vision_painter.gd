extends Node2D
## Draws every enemy's vision sector into the EnemyVisionOverlay SubViewport as a top-down UNION
## (opaque polygons — overlaps merge in the raster, no per-cone translucent geometry on screen).
## Two global passes so combat-red always sits on top of alert-yellow. Redrawn each frame.
## ref: vision cone union (replaces per-enemy cone meshes that z-fought / alpha-stacked).

const SEGS := 32  # arc segments — higher = smoother curved far edge
const COL_VISION := Color(1.0, 0.85, 0.2, 1.0)   # alert zone (yellow)
const COL_COMBAT := Color(0.95, 0.25, 0.2, 1.0)  # combat zone (red)

var bounds_min := Vector2.ZERO
var px_per_m := 8.0


func _process(_delta: float) -> void:
	queue_redraw()  # enemies move/turn every frame → repaint the union


func _draw() -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	# Pass 1: alert (vision) sectors. Pass 2: combat sectors on top → red wins globally.
	for e in enemies:
		var d := _data(e)
		if not d.is_empty():
			_sector(_center(e), float(d["range"]) * px_per_m, float(d["facing"]), float(d["fov_half"]), COL_VISION)
	for e in enemies:
		var d := _data(e)
		if not d.is_empty():
			_sector(_center(e), float(d["combat_r"]) * px_per_m, float(d["facing"]), float(d["fov_half"]), COL_COMBAT)


func _data(e: Object) -> Dictionary:
	if not is_instance_valid(e) or not e.has_method("vision_cone_data"):
		return {}
	var d: Dictionary = e.vision_cone_data()
	return d if d.get("active", false) else {}


func _center(e: Object) -> Vector2:
	var p: Vector3 = (e as Node3D).global_position
	return (Vector2(p.x, p.z) - bounds_min) * px_per_m


## Filled fan sector of radius r, half-angle `half`, centred on world-space angle `ang`.
## 2D maps world x→x, world z→y (matching the overlay's world→UV), so dir = (sin, cos).
func _sector(c: Vector2, r: float, ang: float, half: float, col: Color) -> void:
	if r <= 0.0:
		return
	var pts := PackedVector2Array()
	pts.append(c)
	for i in SEGS + 1:
		var a := ang - half + (2.0 * half) * (float(i) / float(SEGS))
		pts.append(c + Vector2(sin(a), cos(a)) * r)
	draw_colored_polygon(pts, col)
