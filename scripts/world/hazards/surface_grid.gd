extends Node3D
## SurfaceGrid — 환경 surface(존)의 셀 그리드 substrate. Target A: 원(`radius_m`) 저작 그대로, 내부에서
## 원을 셀로 래스터화. DOS2/BG3식 셀 단위 상태·반응·확산의 토대.
##
## **S0 (shadow, 현재):** `ground_zone` 원을 매 틱 관측→셀로 래스터화→매질별 MultiMesh로 그림. 원이 여전히
## 권위(effect/nav/회피는 기존 HazardZone). 스폰부·소비부 **무침습**. A/B 디버그 토글로 원↔셀 시각 비교.
## **S1~ (예정):** 셀이 상태·outcome·멤버십·ttl 권위, HazardZone tick/mesh 은퇴, 소비 4곳 그리드 쿼리 이주.
##
## CombatController 자식으로 마운트(dungeon_run·combat_sandbox 공짜 획득). 렌더는 top_level 월드 좌표.
## ref: docs/design/surface_grid.md · IMPL-DEC-20260721-001 · DRIFT-096 · F-021 §3.2 / INT-002 §6.1.

## S1 outcome 권위 플래그·outcome 상수는 HazardZone과 공유(단방향 preload — HazardZone은 SurfaceGrid를 참조 안 함).
const HazardZone := preload("res://scripts/world/hazards/hazard_zone.gd")

const CELL_M := 0.1                 # 셀 한 변(m). 미세 셀(사용자 2026-07-21) — 부드러운 표면.
                                    # ⚠️ 셀 수·틱·CA/nav/회피 비용 = (1/CELL)² 스케일(0.1=1.0 대비 100×). S1 전 재검토 여지.
const RENDER_CADENCE_S := 0.1       # shadow 렌더 갱신 주기(관측·버퍼 업로드)

## 매질별 render 층서(hazard_zone.RENDER_ORDER 미러 — 상승 기체 위 > 지면 화염 > 지면 액체/고체).
const RENDER_ORDER := {
	"Smoke": 8, "Steam": 7, "Wind": 6, "ToxicGas": 5,
	"Fire": 4, "Fatal": 4,
	"Water": 3, "Ice": 2, "Vegetation": 1, "Oil": 0,
}
## 매질별 셀 색(hazard_zone.STATUS_COLORS albedo 미러; shadow 렌더용 반투명 페인트).
const MEDIUM_COLOR := {
	"Fatal":      Color(0.95, 0.18, 0.12, 0.5),
	"Oil":        Color(0.09, 0.07, 0.05, 0.80),
	"Fire":       Color(1.0, 0.45, 0.10, 0.55),
	"ToxicGas":   Color(0.45, 0.85, 0.25, 0.40),
	"Water":      Color(0.25, 0.50, 0.95, 0.38),
	"Ice":        Color(0.62, 0.86, 1.0, 0.42),
	"Steam":      Color(0.82, 0.86, 0.90, 0.34),
	"Smoke":      Color(0.32, 0.32, 0.34, 0.42),
	"Vegetation": Color(0.28, 0.55, 0.22, 0.45),
	"Wind":       Color(0.70, 0.95, 0.85, 0.26),
}
## S1 outcome 틱 주기(hazard_zone.TICK_S와 동일) + primaryMedium 우선순위(EVENT-CORE §3 / INT-002 §6.1 미러).
const OUTCOME_TICK_S := 0.2
const RX_PRIORITY := ["Oil", "ToxicGas", "Water", "Fire", "Steam", "Smoke", "Ice", "Vegetation", "Wind"]

## A/B 디버그 모드: 0=원+셀 둘 다 · 1=셀만(원 숨김) · 2=원만(셀 숨김).
var _debug_mode: int = 0
var _accum: float = 0.0
var _mm: Dictionary = {}             # medium:String -> MultiMeshInstance3D (매질당 1개)
var _quad: QuadMesh                  # 공유 flat quad(XZ 평면) — lazy(_make_medium_mesh)
var _outcome_accum: float = 0.0      # S1 outcome 틱 누적(OUTCOME_TICK_S)
var _poison_accum: Dictionary = {}   # ToxicGas: unit → 스택 주기 누적(가스 밖 나가면 리셋)


# ── world↔cell 수학 ──────────────────────────────────────────────────────────

## 월드 XZ → 셀 인덱스(정수).
func cell_ix(x: float) -> int:
	return int(floor(x / CELL_M))


## 셀 인덱스 → 셀 중심 월드 좌표(1축).
func cell_center(ix: int) -> float:
	return (float(ix) + 0.5) * CELL_M


## (ix,iz) → 단일 정수 키(음수 오프셋 안전, ±32k 셀 = ±32km @1m).
func cell_key(ix: int, iz: int) -> int:
	return ((ix + 32768) << 16) | (iz + 32768)


# ── 래스터화 (stamp) ─────────────────────────────────────────────────────────

## 원을 셀 집합으로 래스터화 → `out[key]=true` 누적. Target A의 핵심 프리미티브(관측·실스탬프 공용).
## noise 훅(스플래터 seed)은 S3/S5에서 경계식에 더한다 — 지금은 순수 disc.
func stamp_circle(center: Vector3, radius: float, out: Dictionary) -> void:
	if radius <= 0.0:
		return
	var r2 := radius * radius
	var ix0 := cell_ix(center.x - radius)
	var ix1 := cell_ix(center.x + radius)
	var iz0 := cell_ix(center.z - radius)
	var iz1 := cell_ix(center.z + radius)
	for ix in range(ix0, ix1 + 1):
		var cx := cell_center(ix)
		var dx := cx - center.x
		for iz in range(iz0, iz1 + 1):
			var cz := cell_center(iz)
			var dz := cz - center.z
			if dx * dx + dz * dz <= r2:      # 셀 중심이 원 안이면 in(중심 샘플 — MVP)
				out[cell_key(ix, iz)] = true


# ── S0 shadow: ground_zone 관측 → 매질별 셀 렌더 ─────────────────────────────

func _physics_process(delta: float) -> void:
	if HazardZone.USE_SURFACE_GRID:   # S1: 셀이 효과 권위 — 유닛 outcome 중앙 1틱(존별 자기틱 은퇴)
		_outcome_accum += delta
		if _outcome_accum >= OUTCOME_TICK_S:
			_tick_outcomes(_outcome_accum)
			_outcome_accum = 0.0
	_accum += delta
	if _accum < RENDER_CADENCE_S:
		return
	_accum = 0.0
	_rebuild_shadow()


## 활성 ground_zone 원들을 매질별 셀 집합으로 래스터화하고 MultiMesh에 업로드. 원이 권위(무침습).
func _rebuild_shadow() -> void:
	var by_medium: Dictionary = {}       # medium -> {key:true}
	for z in get_tree().get_nodes_in_group("ground_zone"):
		if not (z is Node3D) or not z.has_method("is_active") or not z.is_active():
			continue
		var medium := String(z.status)
		if not MEDIUM_COLOR.has(medium):
			continue
		if not by_medium.has(medium):
			by_medium[medium] = {}
		stamp_circle(z.global_position, float(z.radius), by_medium[medium])
	var cells_visible := _debug_mode != 2
	for medium in MEDIUM_COLOR:
		_update_medium_mesh(medium, by_medium.get(medium, {}), cells_visible)
	_apply_circle_visibility()


## 한 매질의 셀 집합 → 그 매질 MultiMeshInstance3D 인스턴스 트랜스폼 갱신.
func _update_medium_mesh(medium: String, cells: Dictionary, visible_flag: bool) -> void:
	var mmi: MultiMeshInstance3D = _mm.get(medium)
	if cells.is_empty():
		if mmi != null:
			mmi.multimesh.instance_count = 0
			mmi.visible = false
		return
	if mmi == null:
		mmi = _make_medium_mesh(medium)
		_mm[medium] = mmi
	mmi.visible = visible_flag
	var order: int = int(RENDER_ORDER.get(medium, 0))
	var y := 0.06 + float(order) * 0.012      # 매질별 층서(연기 위·기름 아래) + z-fighting 방지
	var basis := Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0))   # quad(+Z) → 바닥(+Y) 눕힘
	var mm := mmi.multimesh
	mm.instance_count = cells.size()
	var i := 0
	for key in cells:
		var iz: int = (key & 0xFFFF) - 32768
		var ix: int = ((key >> 16) & 0xFFFF) - 32768
		mm.set_instance_transform(i, Transform3D(basis, Vector3(cell_center(ix), y, cell_center(iz))))
		i += 1


## 매질당 MultiMeshInstance3D(top_level 월드 좌표, 반투명 unshaded, 매질색). 최초 1회 생성.
func _make_medium_mesh(medium: String) -> MultiMeshInstance3D:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(CELL_M, CELL_M)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _quad
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.top_level = true            # per-instance transform = 월드 좌표(부모 트랜스폼 무시)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.albedo_color = MEDIUM_COLOR[medium]
	mat.emission = Color(MEDIUM_COLOR[medium].r, MEDIUM_COLOR[medium].g, MEDIUM_COLOR[medium].b)
	mat.render_priority = int(RENDER_ORDER.get(medium, 0))
	mmi.material_override = mat
	add_child(mmi)
	return mmi


## 디버그 모드에 따라 원(HazardZone 노드) 표시/숨김. mode 1(셀만)에서만 숨긴다.
func _apply_circle_visibility() -> void:
	var circles_visible := _debug_mode != 1
	for z in get_tree().get_nodes_in_group("ground_zone"):
		if z is Node3D:
			(z as Node3D).visible = circles_visible


# ── S1: 셀 outcome 권위 (유닛 → 커버 존 primaryMedium → 효과) ─────────────────

## 유닛마다 자기 위치를 덮는 활성 존 중 primaryMedium(최고 우선순위) 1개를 골라 그 효과를 적용. HazardZone
## 자기틱을 대체(중앙 1틱). 겹침 = 단일 primaryMedium만(연속 다매질 스택 = S4, ⚠️현재 한계). 피아무구분(F-021).
func _tick_outcomes(dt: float) -> void:
	var now_gas := {}
	for grp in ["party_member", "enemy"]:
		for u in get_tree().get_nodes_in_group(grp):
			if not (u is Node3D):
				continue
			var pos: Vector3 = (u as Node3D).global_position
			var best = null
			var best_rank := 999
			for z in get_tree().get_nodes_in_group("ground_zone"):
				if not z.is_active() or not z.contains_point(pos):
					continue
				var rank := _merge_rank(String(z.status))
				if rank < best_rank:
					best_rank = rank
					best = z
			if best == null:
				continue
			if String(best.status) == "ToxicGas":
				now_gas[u] = true
			_apply_zone_outcome(u, best, dt, grp)
	for u in _poison_accum.keys():   # 가스 밖 유닛 스택 주기 리셋(쌓인 스택은 유닛에 잔류)
		if not now_gas.has(u) or not is_instance_valid(u):
			_poison_accum.erase(u)


## primaryMedium 우선순위 랭크(작을수록 우선). Fatal은 매질 리스트 밖 — 최고로 취급.
func _merge_rank(medium: String) -> int:
	if medium == "Fatal":
		return -1
	var idx := RX_PRIORITY.find(medium)
	return idx if idx >= 0 else 999


## 존 하나의 매질 효과를 유닛에 적용(hazard_zone._apply_medium 이식, 셀 권위판). 피아무구분.
func _apply_zone_outcome(u, z, dt: float, grp: String) -> void:
	if bool(z.friendly_safe) and grp == String(z.safe_faction):
		return   # 초월 아군안심 기름 면제(F-021 예외·DRIFT-094)
	if z.has_method("is_lethal") and not z.is_lethal():
		return   # telegraph phase — no effect yet
	var dps := float(z.dps)
	var dmg := dps * dt
	var src = z.get_source() if z.has_method("get_source") else null
	match String(z.status):
		"Fire":
			if u.has_method("apply_outcome"):
				u.apply_outcome("Scorched", HazardZone.OUTCOME_DUR)      # 존 체류 표식(나가면 소멸)
				u.apply_outcome("Ignited", HazardZone.IGNITE_DUR, dps)   # 점화 DoT(나가도 자체 지속)
			elif u.has_method("take_damage"):
				u.take_damage(dmg)
			_credit(u, dmg, grp, src)
		"ToxicGas":
			if u.has_method("apply_poison_stack"):
				var acc: float = float(_poison_accum.get(u, 0.0)) + dt
				if acc >= HazardZone.POISON_STACK_S:
					acc -= HazardZone.POISON_STACK_S
					u.apply_poison_stack(HazardZone.POISON_STACK_DUR, dps, dps * float(HazardZone.POISON_STACK_CAP), dps)
					_credit(u, dps * HazardZone.POISON_STACK_S, grp, src)
				_poison_accum[u] = acc
			elif u.has_method("take_damage"):
				u.take_damage(dmg)
				_credit(u, dmg, grp, src)
		"Smoke", "Vegetation":
			pass   # harmless — Smoke=vision(deferred), Vegetation=flammable only
		_:
			if HazardZone.MEDIUM_OUTCOME.has(String(z.status)) and u.has_method("apply_outcome"):
				u.apply_outcome(HazardZone.MEDIUM_OUTCOME[String(z.status)], HazardZone.OUTCOME_DUR)  # Water/Ice/Oil/Steam/Wind
			elif dps > 0.0 and u.has_method("take_damage"):   # Fatal + unknown → raw
				u.take_damage(dmg)
				_credit(u, dmg, grp, src)
	if float(z.slow_factor) > 0.0 and u.has_method("apply_slow"):
		u.apply_slow(float(z.slow_factor), HazardZone.OUTCOME_DUR)


## 존 피해가 적을 때 발신원에게 threat 크레딧(F-021).
func _credit(u, dmg: float, grp: String, src) -> void:
	if grp == "enemy" and src != null and is_instance_valid(src) and u.has_method("add_threat"):
		u.add_threat(src, dmg)
		if u.has_method("perceive_attacker"):
			u.perceive_attacker(src)


# ── 디버그 토글 (S0-d) ───────────────────────────────────────────────────────

## 원+셀 → 셀만 → 원만 → … 순환.
func cycle_debug() -> String:
	_debug_mode = (_debug_mode + 1) % 3
	if _debug_mode == 2:                 # 셀 숨김 즉시 반영(다음 rebuild 전)
		for mmi in _mm.values():
			(mmi as MultiMeshInstance3D).visible = false
	return debug_label()


func debug_label() -> String:
	match _debug_mode:
		1: return "cells only"
		2: return "circles only"
		_: return "circles + cells"
