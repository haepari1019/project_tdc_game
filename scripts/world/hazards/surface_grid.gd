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

const CELL_M := 0.25                # 셀 한 변(m). 0.1→0.25(사용자 2026-07-22, 성능) — 셀 ~6배↓ = 지속셀 순회/렌더 비용↓.
                                    # nav cell_size와 동일. 엣지 미세함은 S5 렌더 셰이더로 보완. ⚠️ cell-count 상수
                                    # (creep rings·wind·smoke expand)는 셀 크기 바뀌면 m/s가 변함 — 체감 후 튜닝.
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
## 연료별 grid tick(0.06s)당 Fire 전진 셀-링(속도). 0.25m 기준(Oil 2 ≈ 8 m/s ≈ 0.1m의 6링). 연료 없으면 안 번짐.
## ⚠️ 셀 크기 바뀌면 m/s가 변함 — cell-count 튜닝이라 재조정 필요(체감 후).
const FIRE_CREEP := {"Oil": 2, "Vegetation": 1}
const IGNITE_SEED_R := 0.6                   # Fire가 연료 명중 시 최소 점화 반경(불의 footprint가 더 크면 그쪽 사용)
## 확산 유기화: frontier가 인접 연료를 태울 확률을 **공간 노이즈로 변조**(<1) → 직선/다이아몬드 전선 대신 불규칙
## fingers. 안 붙은 셀은 다음 틱 재시도 → 결국 다 탐. min 하한으로 저노이즈 셀도 결국 붙음.
const FIRE_CREEP_BASE_PROB := 0.72
const FIRE_CREEP_MIN_PROB := 0.30
const FIRE_NOISE_FREQ := 0.5                 # 확산 노이즈 무늬 스케일(m 좌표 — 낮을수록 큰 무늬)
const FIRE_CREEP_DPS := 8.0                  # 번진 Fire dps(reaction_system.FIRE_DPS 미러)
const FIRE_CREEP_TTL := 4.0                  # 번진 Fire 지속(reaction_system.FIRE_TTL 미러)
const SMOKE_AFTER_TTL := 3.5                 # 불이 꺼진 자리 → 연기 잔류(불이 번진 만큼 연기가 따라 퍼짐)
const SMOKE_EXPAND_CADENCE := 0.15           # 연기 외곽 팽창 주기(탄 영역보다 크게 번지도록)
const SMOKE_EXPAND_MIN_TTL := 1.5            # 남은 ttl이 이보다 클 때만 팽창(가장자리로 갈수록 페이드·정지)
const STEAM_CELL_TTL := 5.0                  # Fire↔Water 경계 반응 산물 Steam 지속(reaction_system.STEAM_TTL 미러)
const WIND_PUSHABLE := ["Smoke", "Steam", "ToxicGas", "Fire"]   # B: 기체 + 불이 바람에 밀림(액체·기름 고착)
const WIND_PUSH_RINGS := 1                   # Wind gust당 downwind 밀림 셀(0.25m 기준 ≈ 0.1m의 3링)
const WIND_MAX_PER_TICK := 600               # 틱당 바람 이동 셀 상한(폭주/성능 가드)


## 소유 셀 — 존에서 stamp된 뒤 독립 지속. origin_id=stamp한 존 instance_id(0=detached: 확산/반응 산물).
## S4: 겹친 하위 매질 1개의 상태. primaryMedium=Cell 평면 필드, 하위 매질=Cell.extra[medium]=MediumState.
class MediumState extends RefCounted:
	var medium: String = ""
	var dps: float = 0.0
	var slow: float = 0.0
	var source: Node = null
	var friendly_safe: bool = false
	var safe_faction: String = ""
	var lethal: bool = true
	var ttl: float = -1.0
	var age: float = 0.0
	var origin_id: int = 0


class Cell extends RefCounted:
	var medium: String = ""        # primaryMedium(최우선). activeMedia = [medium] + extra.keys()
	var dps: float = 0.0
	var slow: float = 0.0
	var source: Node = null
	var friendly_safe: bool = false
	var safe_faction: String = ""
	var lethal: bool = true
	var ttl: float = -1.0     # -1 = persist
	var age: float = 0.0
	var origin_id: int = 0
	var extra: Dictionary = {}     # S4: medium:String → MediumState (겹친 하위 매질). 비면 단일 매질(=오늘 동작).


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
var _last_ignite_center: Vector3 = Vector3.ZERO   # 마지막 fire_hits_fuel이 실제 점화한 셀들의 중심(연기/폭발 배치용)
var _last_ignite_radius: float = 0.0              # 그 점화 영역 반경(셀 수→면적)
var _smoke_accum: float = 0.0                     # 연기 팽창 틱 누적
var _by_medium: Dictionary = {}                   # perf: {medium → {key:true}} — 각 연산이 관련 셀만 순회(전체 스캔 회피)
var _creep_noise: FastNoiseLite = null            # 확산 유기화용 공간 노이즈(lazy)


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
			_render_cells()      # grid tick 직후(인덱스 신선) — 별도 render cadence 불필요
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
	_rebuild_index()         # perf: 이후 연산·렌더는 _by_medium/_finite 부분집합만 순회(전체 스캔 회피)
	_expire(dt)
	_react_same_cell()       # S4c 셀-내 반응(같은 셀 Fire+Water 공존 → Steam) — 겹침 내부(S2 인접의 보완)
	_react_cells()           # S2 셀 경계 반응(Fire↔Water 인접 → Steam) — 중점/shrink 근사 대체(DRIFT-096 종결)
	_spread_cells()          # S3 확산(Fire creep + Wind push) — grid tick(0.06s)마다 1셀 = 부드러운 진행
	_outcome_accum += dt
	if _outcome_accum >= OUTCOME_TICK_S:
		_tick_outcomes(_outcome_accum)
		_outcome_accum = 0.0


## perf 인덱스: 매질별 셀 집합 + 유한 ttl 셀 집합을 1패스로 구축(틱 시작 상태). 이후 연산은 부분집합만 순회하고
## 신선도는 각자 `_cells[key].medium` 재확인으로 가드(틱 중 바뀐 셀은 다음 틱 반영 = CA 표준).
func _rebuild_index() -> void:
	_by_medium.clear()
	for key in _cells:
		var c: Cell = _cells[key]
		var bucket = _by_medium.get(c.medium)
		if bucket == null:
			bucket = {}
			_by_medium[c.medium] = bucket
		bucket[key] = true


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


## 한 존의 원을 셀로 칠한다. S4: 겹친 매질을 **버리지 않고 스택**(primaryMedium=최우선, 나머지=extra) → S1a 복원.
func _stamp_zone(z, id: int) -> void:
	var tmp := {}
	stamp_circle((z as Node3D).global_position, float(z.radius), tmp)
	var src = z.get_source() if z.has_method("get_source") else null
	var lethal: bool = (not z.has_method("is_lethal")) or z.is_lethal()
	var medium := String(z.status)
	var dps := float(z.dps)
	var slow := float(z.slow_factor)
	var fs := bool(z.friendly_safe)
	var sf := String(z.safe_faction)
	var ttl := float(z.ttl)
	for key in tmp:
		var c: Cell = _cells.get(key)
		if c == null:
			c = Cell.new()
			c.medium = medium
			c.dps = dps
			c.slow = slow
			c.source = src
			c.friendly_safe = fs
			c.safe_faction = sf
			c.lethal = lethal
			c.ttl = ttl
			c.origin_id = id
			_cells[key] = c
		else:
			_merge_medium_into(c, medium, dps, slow, src, fs, sf, lethal, ttl, id)


## 한 매질을 셀에 병합(S4 스택). 같은 매질=갱신 / 더 우선=primary 교체(기존 primary는 extra 강등) / 하위=extra 추가.
func _merge_medium_into(c: Cell, medium: String, dps: float, slow: float, source, fs: bool, sf: String, lethal: bool, ttl: float, origin_id: int) -> void:
	if c.medium == medium:
		c.dps = dps; c.slow = slow; c.source = source; c.friendly_safe = fs
		c.safe_faction = sf; c.lethal = lethal; c.ttl = ttl; c.age = 0.0; c.origin_id = origin_id
		return
	if _merge_rank(medium) < _merge_rank(c.medium):
		_demote_primary_to_extra(c)          # 기존 primary → extra
		c.medium = medium; c.dps = dps; c.slow = slow; c.source = source; c.friendly_safe = fs
		c.safe_faction = sf; c.lethal = lethal; c.ttl = ttl; c.age = 0.0; c.origin_id = origin_id
		c.extra.erase(medium)                # 혹시 extra에 있던 동일 매질 제거(primary로 승격)
	else:
		var ms: MediumState = c.extra.get(medium)
		if ms == null:
			ms = MediumState.new()
			c.extra[medium] = ms
		ms.medium = medium; ms.dps = dps; ms.slow = slow; ms.source = source; ms.friendly_safe = fs
		ms.safe_faction = sf; ms.lethal = lethal; ms.ttl = ttl; ms.age = 0.0; ms.origin_id = origin_id


## 현재 primary 매질을 extra로 강등(더 우선 매질이 들어올 때).
func _demote_primary_to_extra(c: Cell) -> void:
	var ms := MediumState.new()
	ms.medium = c.medium; ms.dps = c.dps; ms.slow = c.slow; ms.source = c.source; ms.friendly_safe = c.friendly_safe
	ms.safe_faction = c.safe_faction; ms.lethal = c.lethal; ms.ttl = c.ttl; ms.age = c.age; ms.origin_id = c.origin_id
	c.extra[c.medium] = ms


## origin_id 존이 깐 매질 제거(존 소멸·재스탬프 前). S4: 매질별 — extra면 그 매질만, primary면 하위 승격 or 셀 제거.
func _remove_origin(id: int) -> void:
	for key in _cells.keys():
		var c: Cell = _cells[key]
		if not c.extra.is_empty():
			for em in c.extra.keys():
				if (c.extra[em] as MediumState).origin_id == id:
					c.extra.erase(em)
		if c.origin_id == id:
			if not c.extra.is_empty():
				_promote_extra(c)   # 하위 매질을 primary로 승격(셀 유지)
			else:
				_cells.erase(key)


## 셀 수명 — age 누적, ttl 만료. S4: 하위 매질(extra)은 개별 만료, primary 만료 시 하위 승격(셀 유지).
func _expire(dt: float) -> void:
	for key in _cells.keys():
		var c: Cell = _cells[key]
		# 하위 매질(extra) 개별 만료(primary가 지속형이어도)
		if not c.extra.is_empty():
			for em in c.extra.keys():
				var ms: MediumState = c.extra[em]
				if ms.ttl <= 0.0:
					continue
				ms.age += dt
				if ms.age >= ms.ttl:
					c.extra.erase(em)
					if ms.medium == "Fire":
						_add_smoke_extra(c)   # 하위 불 다 탄 자리 → 연기
		# primary 만료
		if c.ttl <= 0.0:
			continue   # 지속형(Oil/Vegetation 등) — age 누적 안 함(self-sufficient: 인덱스 불요)
		c.age += dt
		if c.age >= c.ttl:
			if c.medium == "Fire":
				# 불이 다 탄 자리 → 연기로 전환(제거 대신). 불이 번진 만큼 연기가 따라 퍼진다 = 발화 지점 원 아님.
				c.medium = "Smoke"
				c.ttl = SMOKE_AFTER_TTL
				c.age = 0.0
				c.dps = 0.0
				c.slow = 0.0
				c.friendly_safe = false
				c.origin_id = 0
				c.extra.erase("Smoke")   # primary==extra 매질 중복 방지
			elif not c.extra.is_empty():
				_promote_extra(c)        # 하위 매질을 primary로 승격(셀 유지)
			else:
				_cells.erase(key)


## 하위 매질 중 최우선(rank 최소)을 primary로 승격(primary 소멸 시 셀 유지).
func _promote_extra(c: Cell) -> void:
	var best := ""
	var best_rank := 9999
	for em in c.extra:
		var r := _merge_rank(em)
		if r < best_rank:
			best_rank = r
			best = em
	if best == "":
		return
	var ms: MediumState = c.extra[best]
	c.extra.erase(best)
	c.medium = ms.medium
	c.dps = ms.dps
	c.slow = ms.slow
	c.source = ms.source
	c.friendly_safe = ms.friendly_safe
	c.safe_faction = ms.safe_faction
	c.lethal = ms.lethal
	c.ttl = ms.ttl
	c.age = ms.age
	c.origin_id = ms.origin_id


## 셀에 Smoke 하위 매질 추가/갱신(하위 불 소멸 산물).
func _add_smoke_extra(c: Cell) -> void:
	if c.medium == "Smoke":
		return
	var ms: MediumState = c.extra.get("Smoke")
	if ms == null:
		ms = MediumState.new()
		ms.medium = "Smoke"
		c.extra["Smoke"] = ms
	ms.ttl = SMOKE_AFTER_TTL
	ms.age = 0.0
	ms.dps = 0.0
	ms.slow = 0.0
	ms.lethal = false
	ms.origin_id = 0


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
			if c.medium == "ToxicGas" or c.extra.has("ToxicGas"):
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


## 셀의 활성 매질 전부를 유닛에 적용(primary + extra). S4 다매질 스택 — 겹친 존 outcome 전부 적용(S1a 복원).
func _apply_cell_outcome(u, c: Cell, dt: float, grp: String) -> void:
	_apply_medium_outcome(u, c.medium, c.dps, c.slow, c.source, c.friendly_safe, c.safe_faction, c.lethal, dt, grp)
	for em in c.extra:
		var ms: MediumState = c.extra[em]
		_apply_medium_outcome(u, ms.medium, ms.dps, ms.slow, ms.source, ms.friendly_safe, ms.safe_faction, ms.lethal, dt, grp)


## 매질 1개 효과를 유닛에 적용(primary/extra 공용, hazard_zone._apply_medium 이식). 피아무구분.
func _apply_medium_outcome(u, medium: String, dps: float, slow: float, source, friendly_safe: bool, safe_faction: String, lethal: bool, dt: float, grp: String) -> void:
	if friendly_safe and grp == safe_faction:
		return   # 초월 아군안심 기름 면제(F-021 예외·DRIFT-094)
	if not lethal:
		return   # telegraph phase — no effect yet
	var dmg := dps * dt
	match medium:
		"Fire":
			if u.has_method("apply_outcome"):
				u.apply_outcome("Scorched", HazardZone.OUTCOME_DUR)       # 존 체류 표식(나가면 소멸)
				u.apply_outcome("Ignited", HazardZone.IGNITE_DUR, dps)    # 점화 DoT(나가도 자체 지속)
			elif u.has_method("take_damage"):
				u.take_damage(dmg)
			_credit(u, dmg, grp, source)
		"ToxicGas":
			if u.has_method("apply_poison_stack"):
				var acc: float = float(_poison_accum.get(u, 0.0)) + dt
				if acc >= HazardZone.POISON_STACK_S:
					acc -= HazardZone.POISON_STACK_S
					u.apply_poison_stack(HazardZone.POISON_STACK_DUR, dps, dps * float(HazardZone.POISON_STACK_CAP), dps)
					_credit(u, dps * HazardZone.POISON_STACK_S, grp, source)
				_poison_accum[u] = acc
			elif u.has_method("take_damage"):
				u.take_damage(dmg)
				_credit(u, dmg, grp, source)
		"Smoke", "Vegetation":
			pass   # harmless — Smoke=vision(deferred), Vegetation=flammable only
		_:
			if HazardZone.MEDIUM_OUTCOME.has(medium) and u.has_method("apply_outcome"):
				u.apply_outcome(HazardZone.MEDIUM_OUTCOME[medium], HazardZone.OUTCOME_DUR)  # Water/Ice/Oil/Steam/Wind
			elif dps > 0.0 and u.has_method("take_damage"):   # Fatal + unknown → raw
				u.take_damage(dmg)
				_credit(u, dmg, grp, source)
	if slow > 0.0 and u.has_method("apply_slow"):
		u.apply_slow(slow, HazardZone.OUTCOME_DUR)


## 셀 피해가 적을 때 발신원에게 threat 크레딧(F-021).
func _credit(u, dmg: float, grp: String, src) -> void:
	if grp == "enemy" and src != null and is_instance_valid(src) and u.has_method("add_threat"):
		u.add_threat(src, dmg)
		if u.has_method("perceive_attacker"):
			u.perceive_attacker(src)


# ── S2: 셀 경계 반응 (DRIFT-096 정식 종결) ───────────────────────────────────

## Fire 셀과 Water 셀이 **인접**하면 그 경계 셀들만 Steam으로(양쪽 소진). 중점 Steam+원 shrink 근사 대체 —
## 교집합/경계만 반응 + 매틱 1셀씩 서로 잠식 = 서서히. 물이 불을 끄고 증기가 피어오르는 셀 단위 반응.
func _react_cells() -> void:
	var to_steam := {}
	for key in _by_medium.get("Water", {}):   # perf: Water 셀만
		var wc: Cell = _cells.get(key)
		if wc == null or wc.medium != "Water":
			continue   # index 신선도 가드
		var iz: int = (key & 0xFFFF) - 32768
		var ix: int = ((key >> 16) & 0xFFFF) - 32768
		for d in _NEI4:
			var nkey := cell_key(ix + d.x, iz + d.y)
			var nc: Cell = _cells.get(nkey)
			if nc != null and nc.medium == "Fire":
				to_steam[key] = true    # Water → Steam(증발)
				to_steam[nkey] = true   # Fire → Steam(꺼짐)
				break
	for key in to_steam:
		_set_cell_single(_cells[key], "Steam", STEAM_CELL_TTL, 0.0, 0.0, true)


## S4c: 셀 안에 공존하는 반응쌍 해소(Overlap combo RX, per-cell). 현재 = Fire+Water 공존 → Steam(양쪽 소진).
## Oil+Fire·Fire+Veg는 reaction_system._resolve_zone_pair→fire_hits_fuel(폭발/detach 포함)가 처리 → 여기서 안 건드림.
## _by_medium는 primary-only라 _cells 직접 순회하되 extra 빈 셀(대다수)은 즉시 skip → stacked 셀만 처리.
func _react_same_cell() -> void:
	for key in _cells.keys():
		var c: Cell = _cells[key]
		if c.extra.is_empty():
			continue
		var has_fire: bool = c.medium == "Fire" or c.extra.has("Fire")
		if not has_fire:
			continue
		if c.medium == "Water" or c.extra.has("Water"):
			_set_cell_single(c, "Steam", STEAM_CELL_TTL, 0.0, 0.0, true)   # Fire+Water → Steam(양쪽 소진)


## 셀을 단일 매질로 붕괴(extra 비움). 반응 산물로 셀 내용을 대체할 때 공용.
func _set_cell_single(c: Cell, medium: String, ttl: float, dps: float, slow: float, lethal: bool) -> void:
	c.medium = medium
	c.ttl = ttl
	c.age = 0.0
	c.dps = dps
	c.slow = slow
	c.lethal = lethal
	c.friendly_safe = false
	c.safe_faction = ""
	c.source = null
	c.origin_id = 0
	c.extra.clear()


# ── S3: 확산 CA (owned cells 위 frontier) ────────────────────────────────────

## 확산 1스텝: Fire creep(연료 타고 번짐) + Wind push(기체·불 downwind 밀림). frontier만 건드린다.
func _spread_cells() -> void:
	_fire_creep()
	_wind_push()
	_smoke_accum += GRID_TICK_S
	if _smoke_accum >= SMOKE_EXPAND_CADENCE:
		_smoke_accum = 0.0
		_smoke_expand()


## 연기(Smoke)가 외곽 빈 셀로 번지며 옅어진다(기체 팽창) → 탄 영역보다 크게. 남은 ttl 낮은(가장자리) 연기는 멈춤.
func _smoke_expand() -> void:
	var add := {}
	for key in _by_medium.get("Smoke", {}):   # perf: Smoke 셀만
		var c: Cell = _cells.get(key)
		if c == null or c.medium != "Smoke":
			continue
		if (c.ttl - c.age) < SMOKE_EXPAND_MIN_TTL:
			continue   # 옅어진 연기는 안 번짐(가장자리 페이드·정지)
		var iz: int = (key & 0xFFFF) - 32768
		var ix: int = ((key >> 16) & 0xFFFF) - 32768
		for d in _NEI4:
			var nkey := cell_key(ix + d.x, iz + d.y)
			if not _cells.has(nkey) and not add.has(nkey):
				add[nkey] = c.ttl - c.age
	for nkey in add:
		var s := Cell.new()
		s.medium = "Smoke"
		s.ttl = float(add[nkey]) * 0.75   # 번진 연기는 짧게(외곽으로 갈수록 페이드)
		s.lethal = false
		s.origin_id = 0
		_cells[nkey] = s


## Fire가 인접 연료(Oil/Vegetation) 셀로 번진다 → 그 셀을 Fire로 전환. 연료 없으면 안 번짐(무한확산 방지).
## FIRE_CREEP_RINGS만큼 셀-링 전진(속도). 순회 중 dict 수정 방지 → 링별로 수집 후 일괄 적용.
func _fire_creep() -> void:
	for fuel in FIRE_CREEP:
		_creep_fuel(String(fuel), int(FIRE_CREEP[fuel]))


## 지정 연료(Oil/Vegetation) 셀을 인접 Fire가 rings 셀-링만큼 태운다(그 셀 → Fire). frontier BFS: 첫 wave =
## 현재 Fire 셀(인덱스), 이후 링은 **새로 붙은 fire만** 확장 → 전체 재스캔(6패스) 회피. 연료 셀은 자리에서 재사용.
func _creep_fuel(fuel: String, rings: int) -> void:
	var wave := {}
	for key in _by_medium.get("Fire", {}):
		var fc: Cell = _cells.get(key)
		if fc != null and fc.medium == "Fire":
			wave[key] = true
	for _r in rings:
		if wave.is_empty():
			return
		var next_wave := {}
		for key in wave:
			var iz: int = (key & 0xFFFF) - 32768
			var ix: int = ((key >> 16) & 0xFFFF) - 32768
			for d in _NEI4:
				var nkey := cell_key(ix + d.x, iz + d.y)
				var nc: Cell = _cells.get(nkey)
				if nc == null or nc.medium != fuel:
					continue
				# 노이즈 변조 확률로 태운다 → 직선/다이아몬드 전선 대신 불규칙 fingers. 안 붙으면 다음 틱 재시도.
				var np := clampf(FIRE_CREEP_BASE_PROB * (0.5 + 0.5 * _creep_noise_at(nkey)), FIRE_CREEP_MIN_PROB, 1.0)
				if randf() > np:
					continue
				nc.medium = "Fire"          # 연료 셀 자리에서 재사용(할당 회피). 확산 산물 = detached
				nc.dps = FIRE_CREEP_DPS
				nc.slow = 0.0
				nc.ttl = FIRE_CREEP_TTL
				nc.age = 0.0
				nc.lethal = true
				nc.friendly_safe = false
				nc.origin_id = 0
				nc.extra.clear()           # S4c: 연료 점화 산물은 단일 Fire(겹친 하위 매질 소진)
				next_wave[nkey] = true
		wave = next_wave


## 확산 유기화용 공간 노이즈(-1..1) — frontier 전환 확률 변조. lazy FastNoiseLite.
func _creep_noise_at(key: int) -> float:
	if _creep_noise == null:
		_creep_noise = FastNoiseLite.new()
		_creep_noise.frequency = FIRE_NOISE_FREQ
	var iz: int = (key & 0xFFFF) - 32768
	var ix: int = ((key >> 16) & 0xFFFF) - 32768
	return _creep_noise.get_noise_2d(cell_center(ix), cell_center(iz))


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
	for medium in WIND_PUSHABLE:
		for key in _by_medium.get(medium, {}):   # perf: 밀림 매질(기체·불) 셀만
			if moved >= WIND_MAX_PER_TICK:
				return
			var c: Cell = _cells.get(key)
			if c == null or c.medium != medium:
				continue   # index 신선도 가드
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
	var sx := 0.0
	var sz := 0.0
	var n := 0
	for key in seed:
		var c: Cell = _cells.get(key)
		if c != null and c.medium == fuel:
			c.medium = "Fire"
			c.dps = FIRE_CREEP_DPS
			c.ttl = FIRE_CREEP_TTL
			c.age = 0.0            # ⚠️ 필수: 기존 연료 셀의 누적 age를 안 지우면 ttl 즉시 초과 → 불이 안 남고 사라짐
			c.lethal = true
			c.origin_id = 0
			c.extra.clear()        # S4c: 점화 산물은 단일 Fire(겹친 하위 매질 소진)
			any = true
			var iz: int = (key & 0xFFFF) - 32768   # 실제 점화 셀 중심 누적(연기/폭발을 탄 자리에 두기 위해)
			var ix: int = ((key >> 16) & 0xFFFF) - 32768
			sx += cell_center(ix)
			sz += cell_center(iz)
			n += 1
	if n > 0:
		_last_ignite_center = Vector3(sx / float(n), center.y, sz / float(n))
		_last_ignite_radius = sqrt(float(n) * CELL_M * CELL_M / PI)   # 셀 수 → 등가 반경
	return any


func get_last_ignite_center() -> Vector3:
	return _last_ignite_center


func get_last_ignite_radius() -> float:
	return _last_ignite_radius


## oil 존의 남은 셀을 detach(origin→0) → 존이 clear돼도 셀 생존(creep이 태움·hit로 재점화). 재스탬프 금지.
## S4: primary/extra 어디에 있든 그 origin 매질을 detach.
func detach_zone_cells(oil) -> void:
	var oil_id: int = (oil as Object).get_instance_id()
	for key in _cells:
		var c: Cell = _cells[key]
		if c.origin_id == oil_id:
			c.origin_id = 0
		if not c.extra.is_empty():
			for em in c.extra:
				var ms: MediumState = c.extra[em]
				if ms.origin_id == oil_id:
					ms.origin_id = 0
	_stamped.erase(oil_id)


# ── 렌더 ─────────────────────────────────────────────────────────────────────

## owned 셀 → 매질별 버킷 → MultiMesh(flag ON).
func _render_cells() -> void:
	var buckets := {}
	for key in _cells:
		var cell := _cells[key] as Cell
		var m: String = cell.medium
		if MEDIUM_COLOR.has(m):
			if not buckets.has(m):
				buckets[m] = {}
			buckets[m][key] = true
		for em in cell.extra:                    # S4: 겹친 하위 매질도 렌더(RENDER_ORDER 층서)
			if MEDIUM_COLOR.has(em):
				if not buckets.has(em):
					buckets[em] = {}
				buckets[em][key] = true
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
