extends Node3D
## Ground hazard zone — a persistent circular ground area carrying an environment MEDIUM
## (STATUS-ENV-CORE: Fatal/Oil/Water/Fire/Ice/Vegetation/Wind/Steam/Smoke/ToxicGas). The medium
## decides the per-tick OUTCOME applied to ANY unit inside (피아무구분, F-021): Fire→Ignited,
## ToxicGas→Poisoned, Water→Sodden, Ice→IceGlide(질주+관성), Oil→OilSlick(감속+관성), Steam→SteamHaze, Wind→WindBuffeted,
## Smoke/Vegetation→harmless (Smoke=vision[deferred], Veg=flammable only), Fatal→raw damage.
## ref: F-021 ZONE · F-027 · STATUS-ENV-CORE/OUTCOME-CORE.
##
## `status` = the primary medium (single for now; activeMedia[]/primaryMedium multi-stacking = S3d).
## Impassable (Fatal) → group "fatal_zone" (navmesh carve + party avoidance). All → "ground_zone".
## Query: `contains_point()`, `blocks_segment()`, `status`.

const TICK_S := 0.2
const UNIT_GROUPS := ["party_member", "enemy"]
const OUTCOME_DUR := TICK_S * 2.5   # outcome refresh while inside (~0.5s residual after leaving)
## Fire 존은 **두 가지를 따로** 건다(DRIFT-089): ① `Scorched` = "불 위에 서 있다"는 **존 체류 표식**
## (다른 매체와 동일하게 OUTCOME_DUR로 갱신 → 나오면 ~0.5s 내 소멸) ② `Ignited` = **점화 DoT**로,
## 자체 지속을 갖고 **존을 나와도 끝날 때까지 남는다**(머리 위 아이콘의 시계방향 잔여시간이 여기서 읽힌다).
## 예전엔 둘을 Ignited 하나로 뭉쳐 OUTCOME_DUR(0.5s)을 물려, 나오는 즉시 꺼져 잔여시간이 안 보였다.
const IGNITE_DUR := 5.0   # 점화 DoT 지속 — spec APPLY-IGNITED-…-5S / reaction_system.IGNITE_DUR와 동일
## ToxicGas 독존(AB-010 병합) — 체류 중 POISON_STACK_S마다 독 스택 +1 + 독 지속 리셋(캡이어도 리셋 → 존 안에선 안 풀림).
## dps=스택당 dps. AB-010 시전이 즉시 1스택(강화 4) 깔고 남은 zone이 누적. ref: outcome_status Poison.
const POISON_STACK_S := 3.0     # 독 스택 1 증가 주기(초)
const POISON_STACK_CAP := 5     # 존이 쌓을 수 있는 최대 스택
const POISON_STACK_DUR := 8.0   # 스택 지속 = AB-010 poison_dur_s(8) → 존 스택이 독 지속(해제 쿨)을 '전체' 리셋(clock 100%). 나가면 이만큼 잔류
## Media that apply a movement OUTCOME each tick (tick even with no dps).
const MOVEMENT_MEDIA := ["Water", "Ice", "Oil", "Steam", "Wind"]
## Medium → outcome status applied to units inside (STATUS-OUTCOME-CORE).
const MEDIUM_OUTCOME := {
	"Water": "Sodden", "Ice": "IceGlide", "Oil": "OilSlick",
	"Steam": "SteamHaze", "Wind": "WindBuffeted",
}

## Per-medium visual (albedo, emission). 9-medium preset catalog (STATUS-ENV-CORE).
const STATUS_COLORS := {
	"Fatal":      {"albedo": Color(0.95, 0.18, 0.12, 0.5),  "emit": Color(0.95, 0.22, 0.10)},
	"Oil":        {"albedo": Color(0.09, 0.07, 0.05, 0.80), "emit": Color(0.18, 0.12, 0.04)},
	"Fire":       {"albedo": Color(1.0, 0.45, 0.10, 0.55),  "emit": Color(1.0, 0.40, 0.05)},
	"ToxicGas":   {"albedo": Color(0.45, 0.85, 0.25, 0.40), "emit": Color(0.40, 0.85, 0.15)},
	"Water":      {"albedo": Color(0.25, 0.50, 0.95, 0.38), "emit": Color(0.18, 0.40, 0.85)},
	"Ice":        {"albedo": Color(0.62, 0.86, 1.0, 0.42),  "emit": Color(0.50, 0.78, 1.0)},
	"Steam":      {"albedo": Color(0.82, 0.86, 0.90, 0.34), "emit": Color(0.70, 0.74, 0.80)},
	"Smoke":      {"albedo": Color(0.32, 0.32, 0.34, 0.42), "emit": Color(0.20, 0.20, 0.22)},
	"Vegetation": {"albedo": Color(0.28, 0.55, 0.22, 0.45), "emit": Color(0.18, 0.42, 0.12)},
	"Wind":       {"albedo": Color(0.70, 0.95, 0.85, 0.26), "emit": Color(0.55, 0.85, 0.72)},
}
const WARN_COLOR := {"albedo": Color(0.98, 0.62, 0.12, 0.42), "emit": Color(0.95, 0.55, 0.10)}
## 겹친 반투명 존의 render 층서(DRIFT-095) — 큰 값일수록 나중에 그림 = 위. **현실 물리**: 가벼운 기체
## (연기·증기·바람·가스)는 위로 피어오르고, 지면 화염·액체·고체는 아래. 매체별 고정이라 겹쳐도 draw
## order가 안정 = 깜빡임 제거(예전엔 전부 priority 2·y 0.4 동일 → Fire↔Smoke 순서가 매 프레임 뒤집힘).
const RENDER_ORDER := {
	"Smoke": 8, "Steam": 7, "Wind": 6, "ToxicGas": 5,   # 상승 기체 — 위
	"Fire": 4, "Fatal": 4,                               # 지면 화염 — 연기 아래
	"Water": 3, "Ice": 2, "Vegetation": 1,               # 지면 액체/고체 — 아래
}

## S1 — 셀 substrate 권위 플래그. true면 이 존은 mesh·outcome 틱을 SurfaceGrid에 위임(관측→셀 렌더+효과)하고
## 자신은 lifetime(ttl/telegraph/clear)·geometry(radius/contains_point)·group 멤버십만 유지. false = 기존 원
## 자기완결(mesh+자기틱). A/B 폴백 스위치. ref: docs/design/surface_grid.md · IMPL-DEC-20260721-001.
const USE_SURFACE_GRID := true

var radius: float = 3.0
var dps: float = 0.0
var slow_factor: float = 0.0   # >0 = slows units inside (e.g. Oil slick); refreshed per tick
var status: String = "Fatal"
var impassable: bool = true     # Fatal → navmesh carve + party avoidance
var ttl: float = -1.0           # -1 = persists; >0 = auto-despawn after ttl seconds
var _telegraph_s: float = 0.0
var _lethal: bool = true        # damage gate (telegraph phase = false until it goes lethal)
var _active: bool = true
var _tick_accum: float = 0.0
var _age: float = 0.0
var _inside: Dictionary = {}   # units currently inside (edge detection → EnterZone/ExitZone events)
var _poison_accum: Dictionary = {}   # ToxicGas: unit → 마지막 스택 이후 체류 시간(주기 도달 시 스택 +1)
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _source: Node = null   # attacker credited for threat when this zone damages enemies
## F-021 §3.3.1 예외 — 초월 「아군 안심 기름」(DRIFT-094): friendly_safe면 safe_faction 진영 유닛은
## 이 존의 효과(미끄럼·피해)를 **전부** 면제받는다. 결속이 환경 피아무구분 규칙을 뒤집는 첫 사례.
var friendly_safe: bool = false
var safe_faction: String = ""


func setup(p_radius: float, p_dps: float, p_telegraph_s: float = 0.0, p_status: String = "Fatal", p_impassable: bool = true, p_ttl: float = -1.0, p_slow: float = 0.0) -> void:
	radius = p_radius
	dps = p_dps
	_telegraph_s = p_telegraph_s
	status = p_status
	impassable = p_impassable
	ttl = p_ttl
	slow_factor = p_slow


func _ready() -> void:
	add_to_group("ground_zone")
	if impassable:
		add_to_group("fatal_zone")  # carve + avoidance only for impassable (lethal) zones
	if _telegraph_s > 0.0:
		_lethal = false
		get_tree().create_timer(_telegraph_s).timeout.connect(_go_lethal)
	_build()
	if impassable:
		get_tree().call_group("navmap", "rebake_navigation")  # carve into the navmesh


func _go_lethal() -> void:
	_lethal = true
	_apply_color(false)


func is_active() -> bool:
	return _active


## Credit an attacker (e.g. the torch thrower) for threat when this zone damages enemies.
func set_source(s: Node) -> void:
	_source = s


## SurfaceGrid outcome 틱이 읽는 발신원/치명(telegraph 해제) 상태 — S1 셀 권위판 게터.
func get_source() -> Node:
	return _source


func is_lethal() -> bool:
	return _lethal


## 초월 「아군 안심 기름」 표식(DRIFT-094) — 이 존을 지정 진영에 무해로 만들고, 매질 색은 그대로 두되
## 청록 파티클 오버레이로 "이전과 다르다"를 표기(Oil·직후 Fire 공통). ref: 사용자 결정 2026-07-21.
func set_friendly_safe(faction: String) -> void:
	friendly_safe = true
	safe_faction = faction
	_add_safe_particles()


## Fire↔Water 같은 passive 존 반응으로 서서히 소진될 때 반경을 줄인다(원 단위 확산 근사). 최소 이하면 소멸.
func shrink(amount: float) -> void:
	radius = radius - amount
	if radius < 0.4:
		clear_zone()
		return
	if _mesh != null and _mesh.mesh is CylinderMesh:
		_mesh.mesh.top_radius = radius
		_mesh.mesh.bottom_radius = radius


func _add_safe_particles() -> void:
	var p := CPUParticles3D.new()
	p.amount = 22
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = maxf(radius * 0.85, 0.5)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0.0, 0.5, 0.0)          # 위로 천천히 떠오름 = "보호받는 안전지대"
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.16
	p.color = Color(0.35, 0.95, 0.85)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.2, 0.2)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pm.emission_enabled = true
	pm.albedo_color = Color(0.35, 0.95, 0.85)
	pm.emission = Color(0.30, 0.90, 0.80)
	qm.material = pm
	p.mesh = qm
	p.position.y = 0.15
	add_child(p)


## Is a world point inside the zone (horizontal disc)? Used by damage + party avoidance.
func contains_point(p: Vector3, pad: float = 0.0) -> bool:
	if not _active:
		return false
	var d := Vector2(p.x - global_position.x, p.z - global_position.z)
	return d.length() <= radius + pad


## Does the segment a→b pass through the zone (with padding)? Used by follower avoidance.
func blocks_segment(a: Vector3, b: Vector3, pad: float = 0.6) -> bool:
	if not _active:
		return false
	var c := Vector2(global_position.x, global_position.z)
	var p := Vector2(a.x, a.z)
	var q := Vector2(b.x, b.z)
	var pq := q - p
	var l2 := pq.length_squared()
	var nearest: Vector2 = p if l2 < 0.0001 else p + pq * clampf((c - p).dot(pq) / l2, 0.0, 1.0)
	return (c - nearest).length() <= radius + pad


## Clear/despawn — fade out and free. Un-carves the navmesh if it was impassable.
func clear_zone() -> void:
	if not _active:
		return
	_active = false
	remove_from_group("ground_zone")
	if impassable:
		remove_from_group("fatal_zone")
		get_tree().call_group("navmap", "rebake_navigation")
	if _mesh == null or _mat == null:
		queue_free()   # S1: mesh 없는 존(SurfaceGrid 권위) — 트윈 없이 즉시 해제
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_mat, "albedo_color:a", 0.0, 0.4)
	tw.tween_property(_mesh, "scale:y", 0.04, 0.4)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	if ttl > 0.0:
		_age += delta
		if _age >= ttl:
			clear_zone()
			return
	if USE_SURFACE_GRID:
		return   # S1: 효과·멤버십은 SurfaceGrid._tick_outcomes가 중앙 1틱으로 담당
	if not _lethal:
		return  # telegraph phase — no membership / effect yet
	_tick_accum += delta
	if _tick_accum < TICK_S:
		return
	var dt := _tick_accum
	var dmg := dps * dt
	_tick_accum = 0.0
	# Effects apply for hazardous / movement media. Harmless Smoke/Vegetation still track membership
	# so EnterZone/ExitZone edges fire for the event bus (RX consumers land in S3d).
	var apply_fx := dps > 0.0 or slow_factor > 0.0 or MOVEMENT_MEDIA.has(status)
	var now: Dictionary = {}
	for g in UNIT_GROUPS:
		for u in get_tree().get_nodes_in_group(g):
			if not (u is Node3D) or not contains_point((u as Node3D).global_position):
				continue
			now[u] = true
			if not _inside.has(u):
				_emit_zone_event("EnterZone", u)  # entry edge
			if apply_fx and not (friendly_safe and g == safe_faction):
				_apply_medium(u, dmg, dt, g)   # 초월 아군안심 기름 = safe_faction 유닛 효과 면제(F-021 예외)
	for u in _inside:
		if not now.has(u):
			_poison_accum.erase(u)   # 존을 나가면 스택 주기 리셋(쌓인 스택은 유닛에 잔류)
			if is_instance_valid(u):
				_emit_zone_event("ExitZone", u)  # exit edge
	_inside = now


## Emit an EnterZone/ExitZone event to the bus (group "event_bus" → ReactionSystem.emit_event).
## RX consumers (RX-*-ENTER) land in S3d; for now these are foundation edges.
func _emit_zone_event(kind: String, u: Node) -> void:
	get_tree().call_group("event_bus", "emit_event", kind, {
		"subjectId": u,
		"zoneId": self,
		"zoneMedium": status,
		"position": (u as Node3D).global_position,
		"enterKind": "walk",
	})


## Apply this medium's per-tick outcome to a unit inside (피아무구분, F-021). 매체→결과 디스패치.
func _apply_medium(u: Node, dmg: float, dt: float, g: String) -> void:
	match status:
		"Fire":  # 점화 — Ignited DoT (carries dps); raw fallback for units w/o the outcome system
			if u.has_method("apply_outcome"):
				u.apply_outcome("Scorched", OUTCOME_DUR)         # 존 체류 표식 — 나가면 즉시 해제
				u.apply_outcome("Ignited", IGNITE_DUR, dps)      # 점화 DoT — 나가도 자체 지속만큼 남음
			elif u.has_method("take_damage"):
				u.take_damage(dmg)
			_credit(u, dmg, g)
		"ToxicGas":  # 독존 — 체류 중 POISON_STACK_S마다 독 스택 +1(누적 DoT). dps=스택당 dps. 피아무구분.
			if u.has_method("apply_poison_stack"):
				var acc: float = float(_poison_accum.get(u, 0.0)) + dt
				if acc >= POISON_STACK_S:
					acc -= POISON_STACK_S
					u.apply_poison_stack(POISON_STACK_DUR, dps, dps * float(POISON_STACK_CAP), dps)
					_credit(u, dps * POISON_STACK_S, g)   # 스택 주기당 어그로(연속 dps와 동률)
				_poison_accum[u] = acc
			elif u.has_method("take_damage"):   # 독 시스템 없는 유닛 폴백 = 연속 피해
				u.take_damage(dmg)
				_credit(u, dmg, g)
		"Smoke", "Vegetation":
			pass  # harmless — Smoke = vision (deferred), Vegetation = flammable only
		_:
			if MEDIUM_OUTCOME.has(status) and u.has_method("apply_outcome"):
				u.apply_outcome(MEDIUM_OUTCOME[status], OUTCOME_DUR)  # Water/Ice/Oil/Steam/Wind
			elif dps > 0.0 and u.has_method("take_damage"):  # Fatal + unknown → raw
				u.take_damage(dmg)
				_credit(u, dmg, g)
	if slow_factor > 0.0 and u.has_method("apply_slow"):
		u.apply_slow(slow_factor, OUTCOME_DUR)  # legacy explicit slow (separate from medium)


## Torch fire / zone damage on an enemy pulls aggro onto the credited source (F-021).
func _credit(u: Node, dmg: float, g: String) -> void:
	if g == "enemy" and _source != null and is_instance_valid(_source) and u.has_method("add_threat"):
		u.add_threat(_source, dmg)
		if u.has_method("perceive_attacker"):
			u.perceive_attacker(_source)


func _apply_color(warn: bool) -> void:
	if _mat == null:
		return
	var c: Dictionary = WARN_COLOR if warn else STATUS_COLORS.get(status, STATUS_COLORS["Fatal"])
	_mat.albedo_color = c["albedo"]
	_mat.emission = c["emit"]
	# 아군 안심(DRIFT-094) 표기는 색을 바꾸지 않고 **파티클 오버레이**로 한다(set_friendly_safe) — 매질 색 통일.


func _build() -> void:
	if USE_SURFACE_GRID:
		return   # S1: 존별 개별 mesh 은퇴 — SurfaceGrid MultiMesh가 그린다
	_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.12
	cyl.radial_segments = 32
	_mesh.mesh = cyl
	_mat = StandardMaterial3D.new()
	_mat.emission_enabled = true
	_mat.emission_energy_multiplier = 1.6
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if status == "Oil":
		# Persistent ground slick → OPAQUE, hugging the floor. Rendering in the opaque pass
		# makes depth resolve correctly: units standing in it are NOT covered (the slick sits
		# below them), and the depth-writing vision cone (transparent, drawn later) only tints
		# it rather than hiding it. (A floating transparent disk covered enemies' lower bodies.)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		_mesh.position.y = 0.07
	else:
		# Transient telegraph → transparent, floated above the vision cone (depth-writing) so the cone
		# can't occlude it. render_priority = 2(시야콘 위) + 매체별 물리 층서(RENDER_ORDER) → 겹친 존들의
		# draw order가 매체별로 고정돼 깜빡임이 사라진다. y도 층서만큼 올려 연기가 실제로 더 높이 뜬다.
		var order: int = int(RENDER_ORDER.get(status, 0))
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.render_priority = 2 + order
		_mesh.position.y = 0.4 + order * 0.01
	_apply_color(not _lethal)
	_mesh.material_override = _mat
	add_child(_mesh)
	# emissive pulse so an active hazard reads — skip for inert Oil (it just sits, dark).
	if status != "Oil":
		var tw := create_tween().set_loops()
		tw.tween_property(_mat, "emission_energy_multiplier", 2.6, 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_mat, "emission_energy_multiplier", 1.4, 0.6).set_trans(Tween.TRANS_SINE)
