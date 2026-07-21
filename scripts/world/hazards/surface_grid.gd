extends Node3D
## SurfaceGrid — 환경 surface(존)의 셀 그리드 substrate. Target A: 원(`radius_m`) 저작 그대로, 내부에서
## 원을 셀로 래스터화. DOS2/BG3식 셀 단위 상태·반응·확산의 토대.
##
## **S1b (owned cells, 현재 · USE_SURFACE_GRID=true):** 존이 셀을 **stamp-once**(원→셀, origin·ttl 복사)하면
## 셀은 그때부터 **독립 지속·진화**한다(반응·확산이 셀을 소비/생성). 존은 lifetime(ttl/telegraph/clear)·
## geometry(radius/contains_point, Fatal 회피·carve용) 유지. render+outcome는 owned `_cells`를 읽는다.
## **flag OFF:** S0 shadow(원에서 매틱 파생 렌더) + HazardZone 자기완결 — A/B 폴백.
## **다음:** S2(셀 경계 반응)·S3(확산 CA)가 `_grid_tick`에 얹힌다. 소비 Fatal(회피/carve)는 원 유지(확산 안 함).
##
## CombatController 자식으로 마운트(dungeon_run·combat_sandbox 공짜 획득). 렌더는 top_level 월드 좌표.
## ref: docs/design/surface_grid.md · IMPL-DEC-20260721-001 · DRIFT-096 · F-021 §3.2 / INT-002 §6.1.

## outcome 권위 플래그·outcome 상수는 HazardZone과 공유(단방향 preload — HazardZone은 SurfaceGrid를 참조 안 함).
const HazardZone := preload("res://scripts/world/hazards/hazard_zone.gd")

const CELL_M := 0.1                 # 셀 한 변(m). 미세 셀(사용자 2026-07-21) — 부드러운 표면.
                                    # 비용 = (1/CELL)² 스케일. CA는 frontier로 O(perimeter) 유지(surface_bench 참조).
const GRID_TICK_S := 0.06           # 셀 stamp/수명/확산 주기 — 짧게(매틱 1셀 확산) → 부드러운 진행
const OUTCOME_TICK_S := 0.2         # 유닛 outcome 주기(hazard_zone.TICK_S와 동일)
const RENDER_CADENCE_S := 0.06      # 렌더 버퍼 업로드 주기(grid tick과 동기 = 확산 끊김 완화)

## 매질별 render 층서(hazard_zone.RENDER_ORDER 미러 — 상승 기체 위 > 지면 화염 > 지면 액체/고체).
const RENDER_ORDER := {
	"Smoke": 8, "Steam": 7, "Wind": 6, "ToxicGas": 5,
	"Fire": 4, "Fatal": 4,
	"Water": 3, "Ice": 2, "Vegetation": 1, "Oil": 0,
}
## 매질별 셀 색(hazard_zone.STATUS_COLORS albedo 미러; 반투명 페인트).
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
## primaryMedium 우선순위(EVENT-CORE §3 / INT-002 §6.1 미러). 겹침 시 랭크 작은(우선) 매질이 셀을 차지.
const RX_PRIORITY := ["Oil", "ToxicGas", "Water", "Fire", "Steam", "Smoke", "Ice", "Vegetation", "Wind"]

## S3 확산 CA — owned cells 위 frontier(경계 셀만). 사용자 결정(2026-07-22): 연료 위 Fire creep + 기체·불
## 바람 밀림, 속도 조금 빠르게. gas 확산·intensity 알파는 S5. ref: RX-FIRE-VEGETATION · RX-WIND-* · SPREAD-ZONE-*.
const _NEI4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## 연료별 grid tick(0.06s)당 Fire 전진 셀-링(속도). Oil 6 = Vegetation 1의 6배(사용자 2026-07-22, oil 대폭↑). 연료 없으면 안 번짐.
const FIRE_CREEP := {"Oil": 6, "Vegetation": 1}
const IGNITE_SEED_R := 0.6                   # Fire가 연료 명중 시 최소 점화 반경(불의 footprint가 더 크면 그쪽 사용)
const FIRE_CREEP_DPS := 8.0                  # 번진 Fire dps(reaction_system.FIRE_DPS 미러)
const FIRE_CREEP_TTL := 4.0                  # 번진 Fire 지속(reaction_system.FIRE_TTL 미러)
const WIND_PUSHABLE := ["Smoke", "Steam", "ToxicGas", "Fire"]   # B: 기체 + 불이 바람에 밀림(액체·기름 고착)
const WIND_PUSH_RINGS := 3                   # Wind gust당 downwind 밀림 셀
const WIND_MAX_PER_TICK := 600               # 틱당 바람 이동 셀 상한(폭주/성능 가드)


## 소유 셀 — 존에서 stamp된 뒤 독립 지속. origin_id=stamp한 존 instance_id(0=detached: 확산/반응 산물).
class Cell extends RefCounted:
	var medium: String = ""
	var dps: float = 0.0
	var slow: float = 0.0
	var source: Node = null
	var friendly_safe: bool = false
	var safe_faction: String = ""
	var lethal: bool = true
	var ttl: float = -1.0     # -1 = persist
	var age: float = 0.0
	var origin_id: int = 0


## A/B 디버그 모드: 0=원+셀 둘 다 · 1=셀만(원 숨김) · 2=원만(셀 숨김).
var _debug_mode: int = 0
var _render_accum: float = 0.0
var _grid_accum: float = 0.0
var _outcome_accum: float = 0.0
var _mm: Dictionary = {}             # medium:String -> MultiMeshInstance3D (매질당 1개)
var _quad: QuadMesh                  # 공유 flat quad(XZ 평면) — lazy(_make_medium_mesh)
var _cells: Dictionary = {}          # key:int -> Cell (소유)
var _stamped: Dictionary = {}        # zone instance_id -> [radius, lethal] (신규/변화 감지)
var _poison_accum: Dictionary = {}   # ToxicGas: unit → 스택 주기 누적(가스 밖 나가면 리셋)


# ── world↔cell 수학 ──────────────────────────────────────────────────────────

func cell_ix(x: float) -> int:
	return int(floor(x / CELL_M))


func cell_center(ix: int) -> float:
	return (float(ix) + 0.5) * CELL_M


## (ix,iz) → 단일 정수 키(음수 오프셋 안전).
func cell_key(ix: int, iz: int) -> int:
	return ((ix + 32768) << 16) | (iz + 32768)


## 원을 셀 집합으로 래스터화 → `out[key]=true` 누적. Target A 핵심 프리미티브(stamp·shadow·bench 공용).
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
			if dx * dx + dz * dz <= r2:
				out[cell_key(ix, iz)] = true


func _physics_process(delta: float) -> void:
	if HazardZone.USE_SURFACE_GRID:
		_grid_accum += delta
		if _grid_accum >= GRID_TICK_S:
			_grid_tick(_grid_accum)
			_grid_accum = 0.0
		_render_accum += delta
		if _render_accum >= RENDER_CADENCE_S:
			_render_accum = 0.0
			_render_cells()
	else:
		# flag OFF: S0 shadow(원에서 매틱 파생) — HazardZone이 effect/mesh 권위. A/B 폴백.
		_render_accum += delta
		if _render_accum >= RENDER_CADENCE_S:
			_render_accum = 0.0
			_rebuild_shadow()


# ── S1b: owned cell 생명주기 (stamp-once → 독립 지속) ─────────────────────────

## 셀 substrate 1틱: 존 stamp(신규/변화) → 수명 만료 → (S2 반응·S3 확산 여기) → outcome.
func _grid_tick(dt: float) -> void:
	_stamp_zones()
	_expire(dt)
	_spread_cells()          # S3 확산(Fire creep + Wind push) — grid tick(0.06s)마다 1셀 = 부드러운 진행
	_outcome_accum += dt
	if _outcome_accum >= OUTCOME_TICK_S:
		_tick_outcomes(_outcome_accum)
		_outcome_accum = 0.0


## 활성 존을 셀로 stamp — 신규 존, 또는 radius/lethal이 바뀐 존만(재스탬프). 사라진 존은 origin 셀 제거.
## ⚠️ 순서 중요: **사라진 존 정리를 먼저** 해야, 방금 소비된 존(예: 점화된 Oil)의 셀이 같은 자리에 새로 깔리는
## 존(Fire)의 stamp를 우선순위로 막지 않는다(안 그러면 Oil 소비 자리가 빈 칸이 됨 = 화염바닥 사라짐 버그).
func _stamp_zones() -> void:
	# pass 1: 살아있는 존 수집(id → node)
	var alive := {}
	for z in get_tree().get_nodes_in_group("ground_zone"):
		if not (z is Node3D) or not z.has_method("is_active") or not z.is_active():
			continue
		if not MEDIUM_COLOR.has(String(z.status)):
			continue
		alive[z.get_instance_id()] = z
	# pass 2: 사라진 존의 셀 먼저 제거(위 ⚠️).
	for id in _stamped.keys():
		if not alive.has(id):
			_remove_origin(id)
			_stamped.erase(id)
	# pass 3: 신규/변화 존 stamp.
	for id in alive:
		var z = alive[id]
		var r := float(z.radius)
		var lethal: bool = (not z.has_method("is_lethal")) or z.is_lethal()
		var prev = _stamped.get(id)
		if prev == null:
			_stamp_zone(z, id)
			_stamped[id] = [r, lethal]
		elif absf(float(prev[0]) - r) > 0.05 or bool(prev[1]) != lethal:
			_remove_origin(id)     # radius/lethal 변화 → 재스탬프(반응 前이라 덮어도 안전)
			_stamp_zone(z, id)
			_stamped[id] = [r, lethal]


## 한 존의 원을 셀로 칠한다(priority-merge: 더 높은 우선순위 매질이 셀을 차지).
func _stamp_zone(z, id: int) -> void:
	var tmp := {}
	stamp_circle((z as Node3D).global_position, float(z.radius), tmp)
	var rank := _merge_rank(String(z.status))
	var src = z.get_source() if z.has_method("get_source") else null
	var lethal: bool = (not z.has_method("is_lethal")) or z.is_lethal()
	for key in tmp:
		var ex: Cell = _cells.get(key)
		if ex != null and ex.origin_id != id and _merge_rank(ex.medium) <= rank:
			continue   # 다른 존의 더-우선 셀 유지(단일 primaryMedium; 다매질 스택=S4)
		var c := Cell.new()
		c.medium = String(z.status)
		c.dps = float(z.dps)
		c.slow = float(z.slow_factor)
		c.source = src
		c.friendly_safe = bool(z.friendly_safe)
		c.safe_faction = String(z.safe_faction)
		c.lethal = lethal
		c.ttl = float(z.ttl)
		c.origin_id = id
		_cells[key] = c


## origin_id 존이 깐 셀 전부 제거(존 소멸·재스탬프 前).
func _remove_origin(id: int) -> void:
	for key in _cells.keys():
		if (_cells[key] as Cell).origin_id == id:
			_cells.erase(key)


## 셀 수명 — age 누적, ttl 만료 셀 제거.
func _expire(dt: float) -> void:
	for key in _cells.keys():
		var c: Cell = _cells[key]
		if c.ttl <= 0.0:
			continue   # 지속형(Oil/Vegetation 등) — age 누적 안 함(나중 Fire 변환 시 ttl 오판 방지)
		c.age += dt
		if c.age >= c.ttl:
			_cells.erase(key)


# ── outcome (유닛 → 자기 셀 매질 → 효과) ─────────────────────────────────────

## 유닛마다 자기 셀의 매질 효과 적용(hazard_zone._apply_medium 이식). owned 셀 룩업 O(유닛). 피아무구분(F-021).
func _tick_outcomes(dt: float) -> void:
	var now_gas := {}
	for grp in ["party_member", "enemy"]:
		for u in get_tree().get_nodes_in_group(grp):
			if not (u is Node3D):
				continue
			var pos: Vector3 = (u as Node3D).global_position
			var c: Cell = _cells.get(cell_key(cell_ix(pos.x), cell_ix(pos.z)))
			if c == null:
				continue
			if c.medium == "ToxicGas":
				now_gas[u] = true
			_apply_cell_outcome(u, c, dt, grp)
	for u in _poison_accum.keys():   # 가스 밖 유닛 스택 주기 리셋(쌓인 스택은 유닛에 잔류)
		if not now_gas.has(u) or not is_instance_valid(u):
			_poison_accum.erase(u)


## primaryMedium 우선순위 랭크(작을수록 우선). Fatal은 매질 리스트 밖 — 최고로 취급.
func _merge_rank(medium: String) -> int:
	if medium == "Fatal":
		return -1
	var idx := RX_PRIORITY.find(medium)
	return idx if idx >= 0 else 999


## 셀 하나의 매질 효과를 유닛에 적용(hazard_zone._apply_medium 이식). 피아무구분.
func _apply_cell_outcome(u, c: Cell, dt: float, grp: String) -> void:
	if c.friendly_safe and grp == c.safe_faction:
		return   # 초월 아군안심 기름 면제(F-021 예외·DRIFT-094)
	if not c.lethal:
		return   # telegraph phase — no effect yet
	var dmg := c.dps * dt
	match c.medium:
		"Fire":
			if u.has_method("apply_outcome"):
				u.apply_outcome("Scorched", HazardZone.OUTCOME_DUR)       # 존 체류 표식(나가면 소멸)
				u.apply_outcome("Ignited", HazardZone.IGNITE_DUR, c.dps)  # 점화 DoT(나가도 자체 지속)
			elif u.has_method("take_damage"):
				u.take_damage(dmg)
			_credit(u, dmg, grp, c.source)
		"ToxicGas":
			if u.has_method("apply_poison_stack"):
				var acc: float = float(_poison_accum.get(u, 0.0)) + dt
				if acc >= HazardZone.POISON_STACK_S:
					acc -= HazardZone.POISON_STACK_S
					u.apply_poison_stack(HazardZone.POISON_STACK_DUR, c.dps, c.dps * float(HazardZone.POISON_STACK_CAP), c.dps)
					_credit(u, c.dps * HazardZone.POISON_STACK_S, grp, c.source)
				_poison_accum[u] = acc
			elif u.has_method("take_damage"):
				u.take_damage(dmg)
				_credit(u, dmg, grp, c.source)
		"Smoke", "Vegetation":
			pass   # harmless — Smoke=vision(deferred), Vegetation=flammable only
		_:
			if HazardZone.MEDIUM_OUTCOME.has(c.medium) and u.has_method("apply_outcome"):
				u.apply_outcome(HazardZone.MEDIUM_OUTCOME[c.medium], HazardZone.OUTCOME_DUR)  # Water/Ice/Oil/Steam/Wind
			elif c.dps > 0.0 and u.has_method("take_damage"):   # Fatal + unknown → raw
				u.take_damage(dmg)
				_credit(u, dmg, grp, c.source)
	if c.slow > 0.0 and u.has_method("apply_slow"):
		u.apply_slow(c.slow, HazardZone.OUTCOME_DUR)


## 셀 피해가 적을 때 발신원에게 threat 크레딧(F-021).
func _credit(u, dmg: float, grp: String, src) -> void:
	if grp == "enemy" and src != null and is_instance_valid(src) and u.has_method("add_threat"):
		u.add_threat(src, dmg)
		if u.has_method("perceive_attacker"):
			u.perceive_attacker(src)


# ── S3: 확산 CA (owned cells 위 frontier) ────────────────────────────────────

## 확산 1스텝: Fire creep(연료 타고 번짐) + Wind push(기체·불 downwind 밀림). frontier만 건드린다.
func _spread_cells() -> void:
	_fire_creep()
	_wind_push()


## Fire가 인접 연료(Oil/Vegetation) 셀로 번진다 → 그 셀을 Fire로 전환. 연료 없으면 안 번짐(무한확산 방지).
## FIRE_CREEP_RINGS만큼 셀-링 전진(속도). 순회 중 dict 수정 방지 → 링별로 수집 후 일괄 적용.
func _fire_creep() -> void:
	for fuel in FIRE_CREEP:
		_creep_fuel(String(fuel), int(FIRE_CREEP[fuel]))


## 지정 연료(Oil/Vegetation) 셀을 인접 Fire가 rings 셀-링만큼 태운다(그 셀 → Fire). 링별 수집 후 일괄 적용.
func _creep_fuel(fuel: String, rings: int) -> void:
	for _r in rings:
		var convert := {}
		for key in _cells:
			if (_cells[key] as Cell).medium != "Fire":
				continue
			var iz: int = (key & 0xFFFF) - 32768
			var ix: int = ((key >> 16) & 0xFFFF) - 32768
			for d in _NEI4:
				var nkey := cell_key(ix + d.x, iz + d.y)
				var nc: Cell = _cells.get(nkey)
				if nc != null and nc.medium == fuel:
					convert[nkey] = true
		if convert.is_empty():
			return
		for nkey in convert:
			var f := Cell.new()
			f.medium = "Fire"
			f.dps = FIRE_CREEP_DPS
			f.ttl = FIRE_CREEP_TTL
			f.lethal = true
			f.origin_id = 0            # 확산 산물 = detached(원 존과 무관, 자체 ttl)
			_cells[nkey] = f


## Wind 존 인근의 밀림 매질(기체·불) 셀을 downwind(=존 중심에서 바깥)로 WIND_PUSH_RINGS만큼 이동. 빈 셀로만.
## WindGust 자식-원 해킹(reaction_system._spread_tick) 대체. 틱당 WIND_MAX_PER_TICK 상한.
func _wind_push() -> void:
	var winds := []
	for z in get_tree().get_nodes_in_group("ground_zone"):
		if z is Node3D and z.has_method("is_active") and z.is_active() and String(z.status) == "Wind":
			winds.append(z)
	if winds.is_empty():
		return
	var moved := 0
	for key in _cells.keys():
		if moved >= WIND_MAX_PER_TICK:
			break
		var c: Cell = _cells[key]
		if not WIND_PUSHABLE.has(c.medium):
			continue
		var iz: int = (key & 0xFFFF) - 32768
		var ix: int = ((key >> 16) & 0xFFFF) - 32768
		var px := cell_center(ix)
		var pz := cell_center(iz)
		for w in winds:
			var wc: Vector3 = (w as Node3D).global_position
			var dx := px - wc.x
			var dz := pz - wc.z
			var d2 := dx * dx + dz * dz
			var reach := float(w.radius) + float(WIND_PUSH_RINGS) * CELL_M
			if d2 > 0.0001 and d2 <= reach * reach:
				var inv := 1.0 / sqrt(d2)
				var nkey := cell_key(ix + int(round(dx * inv * WIND_PUSH_RINGS)), iz + int(round(dz * inv * WIND_PUSH_RINGS)))
				if nkey != key and not _cells.has(nkey):
					_cells[nkey] = c       # downwind 이동(빈 셀로만)
					_cells.erase(key)
					moved += 1
				break


## 불이 닿은 영역(center, 반경 radius)의 **연료 셀(fuel=Oil/Vegetation)을 Fire로 전환**(origin→0). 존 소속 무관 —
## zone-owned·detach된 연료 모두 잡는다(재점화 가능). 불의 실제 footprint로 점화 = **맞힌 자리부터**. 나머지 연료는
## Fire creep이 이 불에서 번져 태운다. return: 하나라도 점화했나. ref: RX-OIL-FIRE / RX-FIRE-VEGETATION(셀판) · S2.
func fire_hits_fuel(center: Vector3, radius: float, fuel: String) -> bool:
	var seed := {}
	stamp_circle(center, maxf(radius, IGNITE_SEED_R), seed)   # 최소 IGNITE_SEED_R 보장
	var any := false
	for key in seed:
		var c: Cell = _cells.get(key)
		if c != null and c.medium == fuel:
			c.medium = "Fire"
			c.dps = FIRE_CREEP_DPS
			c.ttl = FIRE_CREEP_TTL
			c.age = 0.0            # ⚠️ 필수: 기존 연료 셀의 누적 age를 안 지우면 ttl 즉시 초과 → 불이 안 남고 사라짐
			c.lethal = true
			c.origin_id = 0
			any = true
	return any


## oil 존의 남은 셀을 detach(origin→0) → 존이 clear돼도 셀 생존(creep이 태움·hit로 재점화). 재스탬프 금지.
func detach_zone_cells(oil) -> void:
	var oil_id: int = (oil as Object).get_instance_id()
	for key in _cells:
		var c: Cell = _cells[key]
		if c.origin_id == oil_id:
			c.origin_id = 0
	_stamped.erase(oil_id)


# ── 렌더 ─────────────────────────────────────────────────────────────────────

## owned 셀 → 매질별 버킷 → MultiMesh(flag ON).
func _render_cells() -> void:
	var buckets := {}
	for key in _cells:
		var m: String = (_cells[key] as Cell).medium
		if not MEDIUM_COLOR.has(m):
			continue
		if not buckets.has(m):
			buckets[m] = {}
		buckets[m][key] = true
	var vis := _debug_mode != 2
	for medium in MEDIUM_COLOR:
		_update_medium_mesh(medium, buckets.get(medium, {}), vis)
	_apply_circle_visibility()


## flag OFF 폴백: 활성 원을 매질별 셀로 매틱 파생 렌더(S0 shadow 오버레이).
func _rebuild_shadow() -> void:
	var by_medium := {}
	for z in get_tree().get_nodes_in_group("ground_zone"):
		if not (z is Node3D) or not z.has_method("is_active") or not z.is_active():
			continue
		var medium := String(z.status)
		if not MEDIUM_COLOR.has(medium):
			continue
		if not by_medium.has(medium):
			by_medium[medium] = {}
		stamp_circle((z as Node3D).global_position, float(z.radius), by_medium[medium])
	var vis := _debug_mode != 2
	for medium in MEDIUM_COLOR:
		_update_medium_mesh(medium, by_medium.get(medium, {}), vis)
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


# ── 디버그 토글 ──────────────────────────────────────────────────────────────

## 원+셀 → 셀만 → 원만 → … 순환.
func cycle_debug() -> String:
	_debug_mode = (_debug_mode + 1) % 3
	if _debug_mode == 2:                 # 셀 숨김 즉시 반영(다음 render 전)
		for mmi in _mm.values():
			(mmi as MultiMeshInstance3D).visible = false
	return debug_label()


func debug_label() -> String:
	match _debug_mode:
		1: return "cells only"
		2: return "circles only"
		_: return "circles + cells"
