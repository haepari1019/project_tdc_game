extends StaticBody3D
## ENT-RAMPART-001 — 물리 방벽 오브젝트. **두 형상**(DRIFT-107):
##  · `shape: "wall"`(기본, AB-034 Rampart Slam) — 전방 직사각 벽. **단일 방향**을 두껍게 막고
##    world 레이어라 **이동까지** 차단한다(파티·적 공통). 높은 HP.
##  · `shape: "dome"`(AB-033 철벽 차단) — 시전자 중심 **전방위** 반구. **이동은 막지 않는다**
##    (막으면 시전자가 자기 돔에 갇힌다) — 전용 **엄폐 레이어(LAYER_COVER)** 에만 올려
##    투사체 레이캐스트에만 걸린다. 대신 HP가 훨씬 낮아 몇 발 받아내고 깨진다.
## 공통: 적대 투사체를 흡수(발당 `DMG_PER_SHOT`)하고 HP 0이면 Break. 아군 진영 투사체는 통과.
## ⚠️ **근접 적은 방벽을 때리지 않는다** — 전투 모델이 target-locked라 근접 피해가 월드 지오메트리로
## 라우팅되지 않는다(우회하거나 벽 앞에서 막힌다). 방벽 HP를 깎는 건 **투사체 흡수뿐**.
## A destructible forward wall: blocks movement
## (world collision layer, so party + enemies alike) for `duration_s`, or until `barrier_hp` hits 0 →
## Break. On spawn, briefly staggers small/normal enemies touching it. Max 1 per caster
## (spec: 동시 2개 이상 유지 금지). Projectile-absorb / threat-on-hit are DEFERRED — the combat model
## applies damage target-locked, not via world-geometry projectiles, so nothing routes hits into the
## wall yet (take_damage is wired for when it does). ref: AB-034 · ENT-RAMPART-001 · DRIFT-057.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")

## 엄폐 전용 레이어 — 투사체 레이캐스트(`projectile._mask` / `enemy_ai._shot_blocked`)만 이 비트를 본다.
## 유닛 `collision_mask`(1|2|4)에는 없으므로 **이동을 막지 않는다**.
const LAYER_COVER := 8
const DMG_PER_SHOT := 10.0
## 커버리지 판정용 표준 유닛 치수(파티 메시: bottom_radius 0.40 · height 1.4 × role_scale ≤1.15).
## 돔은 **완전히 감싼 대상만** 보호한다 — 몸이 걸치면 피해가 그대로 들어간다(사용자 확정, DRIFT-107).
const DEFAULT_UNIT_R := 0.40
const DEFAULT_UNIT_H := 1.60

var _hp: float = 300.0
var _ttl: float = 4.0
var _dome: bool = false
var _radius: float = 3.0
var _caster: CharacterBody3D = null
var _mat: StandardMaterial3D = null


func setup(caster: CharacterBody3D, pos: Vector3, facing: Vector3, p: Dictionary, ctx) -> void:
	_caster = caster
	_hp = float(p.get("barrier_hp", 300.0))
	_ttl = float(p.get("duration_s", 4.0))
	_dome = String(p.get("shape", "wall")) == "dome"
	var w := float(p.get("width_m", 3.5))
	var h := float(p.get("height_m", 2.0))
	var depth := 0.4
	add_to_group("rampart_barrier")
	# Max 1 per caster — drop this Tank's older wall before standing a new one.
	for b in get_tree().get_nodes_in_group("rampart_barrier"):
		if b != self and is_instance_valid(b) and b.get("_caster") == _caster:
			b.queue_free()
	var f := facing
	f.y = 0.0
	f = f.normalized() if f.length() > 0.05 else Vector3(0, 0, 1)
	var x := Vector3.UP.cross(f).normalized()   # width axis (perpendicular to facing)
	# Mesh — wall = 반투명 슬래브(정면 법선 = facing) / dome = 시전자 중심 반구.
	var r := float(p.get("radius_m", 3.0))
	_radius = r
	var mi := MeshInstance3D.new()
	if _dome:
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r          # ⚠️ 반구는 height가 **보이는 높이**다. r*2를 주면 수직으로만 2배 솟아
		sm.is_hemisphere = true # 찌그러진 총알 모양이 된다(DRIFT-107 수정). height = radius = 정상 반구.
		mi.mesh = sm
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(w, h, depth)
		mi.mesh = bm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.45, 0.72, 0.95, 0.30) if _dome else Color(0.55, 0.58, 0.66, 0.85)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.emission_enabled = true
	_mat.emission = Color(0.40, 0.50, 0.70)
	_mat.emission_energy_multiplier = 0.5
	mi.material_override = _mat
	add_child(mi)
	# wall = world 레이어(이동까지 차단) / dome = 엄폐 레이어 전용(투사체만 차단, 이동 자유).
	collision_layer = LAYER_COVER if _dome else 1
	collision_mask = 0
	var cs := CollisionShape3D.new()
	if _dome:
		var sph := SphereShape3D.new()
		sph.radius = r
		cs.shape = sph
	else:
		var box := BoxShape3D.new()
		box.size = Vector3(w, h, depth)
		cs.shape = box
	add_child(cs)
	if _dome:
		global_transform = Transform3D(Basis(), Vector3(pos.x, 0.0, pos.z))
	else:
		global_transform = Transform3D(Basis(x, Vector3.UP, f), Vector3(pos.x, h * 0.5, pos.z))
	# Spawn impact: brief stagger on small/normal enemies touching the wall (skip miniboss/elite cores).
	var stagger := 0.0 if _dome else float(p.get("stagger_s", 0.5))   # 밀어붙이는 벽 전용(돔은 통과 가능)
	if stagger > 0.0:
		for e in ctx.enemies_in_radius(global_position, maxf(w, 1.5) * 0.6):
			if e != null and is_instance_valid(e) and e.has_method("apply_stun") and not bool(e.get("miniboss")):
				e.apply_stun(stagger)
	if _dome:
		# 완전 보호 반경 링 — 돔 외곽(r)과 실제 안전 반경이 다르므로 "어디까지 들어와야 하는지"를 보여준다.
		var sr := safe_radius()
		if sr > 0.2:
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = maxf(sr - 0.10, 0.05)
			torus.outer_radius = sr
			ring.mesh = torus
			var rmat := StandardMaterial3D.new()
			rmat.albedo_color = Color(0.55, 0.85, 1.0, 0.55)
			rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			rmat.emission_enabled = true
			rmat.emission = Color(0.55, 0.85, 1.0)
			ring.material_override = rmat
			ring.position = Vector3(0.0, 0.06, 0.0)
			add_child(ring)
		SkillVfx.telegraph(ctx, Vector3(pos.x, 0.0, pos.z), Color(0.45, 0.75, 1.0), r)
	else:
		SkillVfx.telegraph(ctx, Vector3(pos.x, 0.0, pos.z), Color(0.50, 0.60, 0.90), maxf(w, 2.0) * 0.6)


## Forward-compat: drop the wall's HP (Break at 0). Nothing routes combat hits here yet (see header).
func take_damage(amount: float) -> void:
	if _hp <= 0.0:
		return
	_hp = maxf(0.0, _hp - amount)
	if _hp <= 0.0:
		queue_free()   # Break — barrier hp 0


## A barrier blocks/absorbs only HOSTILE projectiles — the owner's own team passes through (RP-02:
## the tank's wall stops the ENEMY's shots, not the party's own). party↔party + same-faction enemies
## = friendly (pass); party↔enemy + cross-faction = hostile (block). ref: AB-034 · ENT-RAMPART-001 · DRIFT-059.
func blocks_projectile_from(shooter) -> bool:
	if _caster == null or not is_instance_valid(_caster) or shooter == null:
		return true   # unknown owner → block (safe default)
	var owner_party := _caster.is_in_group("party_member")
	var shooter_party: bool = shooter.is_in_group("party_member")
	if owner_party and shooter_party:
		return false  # both party → friendly
	if not owner_party and not shooter_party:
		return String(_caster.get("faction")) != String(shooter.get("faction"))   # cross-faction only
	return true       # party vs enemy → hostile


## **완전 포함 판정**(돔 전용) — 유닛의 "가장 바깥·가장 높은 점"이 반구 안에 들어오는가.
## 반구는 반지름 `r`, 높이도 `r`이라 수평거리 `d`에서의 천장 높이 = `sqrt(r²−d²)`.
## 따라서 조건은 `(d + unit_r)² + unit_h² ≤ r²` — 가장자리에 걸친 유닛은 자동으로 탈락한다.
## 벽(`wall`)은 방향성 엄폐라 기하(레이캐스트)가 판정을 대신하므로 항상 true.
func covers_point(pos: Vector3, unit_r: float = DEFAULT_UNIT_R, unit_h: float = DEFAULT_UNIT_H) -> bool:
	if not _dome:
		return true
	var dx: float = pos.x - global_position.x
	var dz: float = pos.z - global_position.z
	var d: float = sqrt(dx * dx + dz * dz) + unit_r
	var r: float = _radius
	return (d * d + unit_h * unit_h) <= r * r


## 실제로 보호되는 수평 반경(시각 링용) — 위 조건을 d에 대해 푼 값. 유닛 키가 클수록 좁아진다.
func safe_radius(unit_r: float = DEFAULT_UNIT_R, unit_h: float = DEFAULT_UNIT_H) -> float:
	var inner: float = _radius * _radius - unit_h * unit_h
	return maxf(sqrt(inner) - unit_r, 0.0) if inner > 0.0 else 0.0


## Absorb one HOSTILE projectile (delivery=projectile) — RP-02 / RX-PHYSICAL-BARRIER-001: the barrier
## soaks the shot, taking DMG-BARRIER-HIT (10) per projectile, with an impact flash. ref: AB-034 · DRIFT-059.
func absorb_projectile(hit_pos = null) -> void:
	# 섬광은 **맞은 자리**에. 예전엔 항상 오브젝트 중심이라 돔(반경 3m)에서는 어디서 막혔는지 안 보였다.
	var at: Vector3 = (hit_pos as Vector3) if hit_pos != null else global_position
	SkillVfx.telegraph(self, at, Color(0.55, 0.70, 1.0), 1.0)   # soak flash
	take_damage(DMG_PER_SHOT)


func _process(delta: float) -> void:
	_ttl -= delta
	if _ttl <= 0.0:
		queue_free()   # Break — duration elapsed
	elif _mat != null and _ttl < 1.0:
		_mat.albedo_color.a = clampf(_ttl, 0.0, 1.0) * 0.85   # fade out over the last second
