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
## **가시덩굴(Vegetation) — 이동 거리 비례 피해**(DRIFT-112, 사용자: 이름값대로 "가시").
## 서 있으면 안 아프고 **움직일 때마다** 아프다 → "가시밭을 헤친다"가 규칙으로 성립하고,
## 다른 매질(체류 dps·상태부여)과 축이 겹치지 않는다.
## **틱 상한 없음(사용자 확정):** 돌진·넉백처럼 한 번에 크게 움직이면 그만큼 크게 아픈 게 맞다 —
## 가시밭을 깔아 **돌진을 억제**하거나 **넉백으로 추가 딜**을 넣는 창의적 사용을 열어 두기 위함.
## 상한을 두면 "많이 움직이면 손해"라는 규칙 자체가 무뎌진다.
const THORN_DMG_PER_M := 3.0     # 이동 1m당 피해 — 상한 없이 선형
const THORN_MIN_MOVE_M := 0.05   # 이보다 적게 움직이면 정지로 간주(부동 시 무피해)
const THORN_POPUP_S := 0.5       # 피해 표기 주기 — `OutcomeStatus.DOT_TICK_S`와 같은 리듬(DoT 장판과 통일)
const THORN_POPUP_COLOR := Color(0.92, 0.96, 0.90)   # 하얀 가시 색과 맞춘 표기색


## 가시 피해 계산 — `last` = 직전 위치(없으면 null). 반환 [피해, 갱신할 위치].
## ⚠️ **존을 벗어나며 생긴 큰 이동은 계산되지 않는다** — 틱은 "지금 안에 있는 유닛"만 돌고, 나가는
## 순간 exit 엣지가 `_thorn_last`를 지운다. 즉 안에서 움직인 만큼만 아프다(밖으로 블링크 = 무피해).
## 두 매질 경로(원 모델 `hazard_zone` · 셀 CA `surface_grid`)가 **같은 식**을 쓰도록 여기 한 곳에 둔다.
static func thorn_damage(u: Node3D, last) -> Array:
	var cur: Vector3 = u.global_position
	if last == null:
		return [0.0, cur]
	var d: Vector3 = cur - (last as Vector3)
	d.y = 0.0
	var moved := d.length()
	if moved < THORN_MIN_MOVE_M:
		return [0.0, cur]
	return [moved * THORN_DMG_PER_M, cur]   # 선형 — 크게 움직일수록 크게 아프다


## 가시 피해 **표기** — 매질 틱(0.2s)마다 띄우면 시끄러우므로 **DoT와 같은 0.5s 리듬**으로 모아서
## 한 번에 올린다(사용자: "다른 dot 장판처럼 옆에 데미지 표기"). `acc`는 호출자 소유 딕셔너리
## (원 모델·셀 CA 두 경로가 각자 갖되 **누적·플러시 규칙은 여기 한 곳**). 반환 없음.
static func thorn_popup(u, dmg: float, dt: float, acc: Dictionary) -> void:
	var e: Array = acc.get(u, [0.0, 0.0])   # [누적 피해, 누적 시간]
	e[0] = float(e[0]) + dmg
	e[1] = float(e[1]) + dt
	if float(e[1]) >= THORN_POPUP_S:
		if float(e[0]) >= 1.0 and u.has_method("popup_status"):
			u.popup_status("-%d" % int(round(float(e[0]))), THORN_POPUP_COLOR)
		e = [0.0, 0.0]
	acc[u] = e

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
var _poison_accum: Dictionary = {}
var _thorn_last: Dictionary = {}   # Vegetation: unit → 직전 위치(이동 거리 산출용)
var _thorn_pop: Dictionary = {}    # Vegetation: unit → [누적 피해, 누적 시간] (표기 리듬)   # ToxicGas: unit → 마지막 스택 이후 체류 시간(주기 도달 시 스택 +1)
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _source: Node = null   # attacker credited for threat when this zone damages enemies
## F-021 §3.3.1 예외 — 초월 「아군 안심 기름」(DRIFT-094): friendly_safe면 safe_faction 진영 유닛은
## 이 존의 효과(미끄럼·피해)를 **전부** 면제받는다. 결속이 환경 피아무구분 규칙을 뒤집는 첫 사례.
var friendly_safe: bool = false
var safe_faction: String = ""
## AB-042 Wind 방향성 복도 — 기본은 원형(shape="circle"·radius). rect면 wind_dir 축 방향으로 길이 length,
## 직각 폭 width의 직사각(global_position = 복도 **중앙**). SurfaceGrid가 stamp_rect·_wind_field로 읽는다.
var shape: String = "circle"
var wind_dir: Vector3 = Vector3.ZERO
var length: float = 0.0
var width: float = 0.0


func setup(p_radius: float, p_dps: float, p_telegraph_s: float = 0.0, p_status: String = "Fatal", p_impassable: bool = true, p_ttl: float = -1.0, p_slow: float = 0.0) -> void:
	radius = p_radius
	dps = p_dps
	_telegraph_s = p_telegraph_s
	status = p_status
	impassable = p_impassable
	ttl = p_ttl
	slow_factor = p_slow


## 방향성 직사각 복도로 전환(AB-042 Wind). setup() 뒤에 호출. dir = 바람 축(캐스터→조준점), global_position=중앙.
func setup_rect(dir: Vector3, p_length: float, p_width: float) -> void:
	shape = "rect"
	var d := Vector3(dir.x, 0.0, dir.z)
	wind_dir = d.normalized() if d.length() > 0.001 else Vector3(0.0, 0.0, 1.0)
	length = p_length
	width = p_width


func _ready() -> void:
	add_to_group("ground_zone")
	if impassable:
		add_to_group("fatal_zone")  # carve + avoidance only for impassable (lethal) zones
	if _telegraph_s > 0.0:
		_lethal = false
		get_tree().create_timer(_telegraph_s).timeout.connect(_go_lethal)
	_build()
	if status == "Vegetation":
		_build_thorns()   # 하얀 가시 장식 — 매질 필드(셀 CA)와 별개인 **표현 레이어**
	if impassable:
		get_tree().call_group("navmap", "rebake_navigation")  # carve into the navmesh


## **가시덩굴 표현**(DRIFT-112) — 이름값대로 **하얀 작은 가시가 촘촘히** 돋은 바닥. 매질 필드
## (`surface_grid`의 coverage plane)는 색만 칠하므로, 형태는 이 장식 레이어가 준다.
## MultiMesh 1개로 수백 개를 한 드로콜에 그린다(존마다 노드 수백 개는 비용이 크다).
## ⚠️ 존 노드 기준이라 **바람으로 번진 셀까지 따라가진 않는다**(Vegetation은 자체 확산이 없고
## `SPREADABLE_MEDIA` 바람 확산만 있어 실사용에선 대부분 일치). 표현 한계로 기록만.
const THORN_DENSITY_PER_M2 := 26.0   # 촘촘함 — 1m²당 가시 수
const THORN_MAX := 420               # 큰 존에서의 인스턴스 상한(성능 가드)
func _build_thorns() -> void:
	var area: float = (length * width) if shape == "rect" else (PI * radius * radius)
	var n: int = clampi(int(area * THORN_DENSITY_PER_M2), 12, THORN_MAX)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.035      # 얇고 작게 — "가시"
	cone.height = 0.24
	cone.radial_segments = 4        # 저폴리(수백 개라 각 하나는 최소로)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.94, 0.97, 0.92)     # 하얀 가시
	mat.emission_enabled = true
	mat.emission = Color(0.85, 0.92, 0.86)
	mat.emission_energy_multiplier = 0.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = n
	var half_l: float = length * 0.5
	var half_w: float = width * 0.5
	for i in n:
		var off: Vector3
		if shape == "rect":
			off = Vector3(randf_range(-half_w, half_w), 0.0, randf_range(-half_l, half_l))
		else:
			# 원 안 균등 분포(sqrt 보정 — 안 하면 중심에 몰린다)
			var a := randf() * TAU
			var r := radius * sqrt(randf())
			off = Vector3(cos(a) * r, 0.0, sin(a) * r)
		var b := Basis()
		b = b.rotated(Vector3.UP, randf() * TAU)
		# 살짝 눕혀 제각각 — 똑바로만 서 있으면 인공적으로 보인다
		b = b.rotated(Vector3(cos(randf() * TAU), 0.0, sin(randf() * TAU)), randf_range(-0.35, 0.35))
		b = b.scaled(Vector3.ONE * randf_range(0.7, 1.35))
		mm.set_instance_transform(i, Transform3D(b, off + Vector3(0.0, 0.10, 0.0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	if shape == "rect":
		mmi.rotation = Vector3(0.0, atan2(wind_dir.x, wind_dir.z), 0.0)   # 복도 축 정렬


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
	if shape == "rect":
		var rel := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
		var along := rel.dot(wind_dir)
		var perp := rel.x * -wind_dir.z + rel.z * wind_dir.x
		return absf(along) <= length * 0.5 + pad and absf(perp) <= width * 0.5 + pad
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
			_thorn_last.erase(u)     # 가시밭을 나가면 위치 추적도 리셋(재진입 시 첫 틱 무피해)
			_thorn_pop.erase(u)
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
		"Vegetation":  # 가시덩굴 — **움직인 거리만큼** 찔린다(서 있으면 무피해)
			if u.has_method("take_damage"):
				var tr: Array = thorn_damage(u, _thorn_last.get(u))
				_thorn_last[u] = tr[1]
				if float(tr[0]) > 0.0:
					u.take_damage(float(tr[0]))
					_credit(u, float(tr[0]), g)
				thorn_popup(u, float(tr[0]), dt, _thorn_pop)
		"Smoke":
			pass  # harmless — Smoke = vision (deferred)
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
