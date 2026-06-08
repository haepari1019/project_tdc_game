extends RefCounted
## Shared XZ-plane spatial helpers. Combat distance checks are horizontal-only
## (party floats above enemies, so a 3D check would push in-range targets out by
## the height gap). ref: DEBT-DUP-SPATIAL — was hand-rolled in 5-6 query loops.


## Squared horizontal (x,z) distance between two points (ignores y).
static func h_dist2(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return dx * dx + dz * dz


## True if b is within radius r of a on the XZ plane.
static func within_xz(a: Vector3, b: Vector3, r: float) -> bool:
	return h_dist2(a, b) <= r * r
