extends Node3D
## **채널링 공통 틱커** (kind=`skillbook_channeling`) — 시전 시점에 고정된 원점/방향에서 `ticks`번
## 틱을 굴린다. 형상은 `channel_shape`가 정하고, **틱 루프·중단 규칙·채널 바는 4형상이 공유**한다.
## 예전 이름은 `beam_channel`이었다 — 클러스터가 「빔」에서 **「채널링」**으로 재정의되면서(사용자
## 판정, DRIFT-115) 빔은 4형상 중 하나(`line`)로 내려왔다.
##
##   · `line`  — 직선(좁은 원뿔 half≈7°) · 전격. 원형.
##   · `cone`  — 부채꼴이 **틱마다 앞으로 뻗어나간다**(reach = range × (i+1)/ticks) · 화염.
##   · `cloud` — **조준점**에 머무는 구름, 틱마다 독 스택 · 맹독.
##   · `nova`  — 자기중심 원형, 틱마다 냉각이 깊어지고 **전 틱을 다 맞은 대상만 빙결** · 냉기.
##
## **채널은 이동 = 중단**이다(MOVE_CANCEL_M) — 4형상 전부에 적용된다. 다운/스턴/다른 캐스트 시작도
## 끊는다. 즉 "움직이면 구름이 사라진다"는 독 구름만의 규칙이 아니라 **채널의 공통 계약**이다.
## ref: F-009 · AB-054/109/110/111 · DRIFT-115.

const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")
const CastBar := preload("res://scripts/combat/abilities/effects/cast_bar.gd")
const MOVE_CANCEL_M := 0.3            # 시전 지점에서 이 거리 이상 움직이면 채널 취소(이동=중단)
const CHANNEL_BAR_COLOR := Color(0.35, 0.9, 0.85)  # 캐스팅(파랑)과 구분되는 채널 전용 색(청록)

var _caster: CharacterBody3D
var _cast_spot: Vector3     # **이동 중단 기준** = 시전 당시 캐스터 위치. `cloud`는 원점이 조준점이라 별도로 든다.
var _origin: Vector3        # 기하 원점 — line/cone/nova = 캐스터 / cloud = 조준점
var _dir: Vector3
var _range: float
var _half: float            # cone half-angle (rad)
var _radius: float          # cloud/nova 반경
var _shape: String = "line"
var _dmg: float             # per-tick damage
var _interval: float
var _ticks_left: int
var _ticks_total: int
var _ctx
var _params: Dictionary = {}   # 속성 seam(element_hit)이 읽는 원본 cast params. DRIFT-088.
var _t: float = 0.0
var _bar                    # CastBar (depleting) over the caster
var _elapsed: float = 0.0
var _total_dur: float = 0.0
var _finished: bool = false
## nova 전용 — 대상 instance_id → **연속 피격 틱 수**. 반경을 벗어나면 표에서 빠져 0으로 리셋된다.
var _streak: Dictionary = {}


func setup(caster: CharacterBody3D, origin: Vector3, dir: Vector3, range_m: float, half_deg: float,
		dmg_per_tick: float, ticks: int, interval: float, ctx, params: Dictionary = {}) -> void:
	_caster = caster
	_cast_spot = caster.global_position
	_origin = origin
	_dir = dir
	_range = range_m
	_half = deg_to_rad(half_deg)
	_dmg = dmg_per_tick
	_ticks_left = ticks
	_ticks_total = maxi(ticks, 1)
	_interval = interval
	_ctx = ctx
	_params = params
	_shape = String(params.get("channel_shape", "line"))
	_radius = float(params.get("radius_m", 3.0))
	# 첫 틱은 즉발(t=0), 마지막 틱은 (ticks-1)*interval에 발사 → 그 시점에 채널 종료.
	# 바가 정확히 그때 0에 닿도록 총 지속을 (ticks-1)*interval로 잡는다.
	_total_dur = maxf(float(ticks - 1) * interval, 0.001)
	global_position = origin
	# Depleting channel bar (starts full, drains) — reuses CastBar fed the REMAINING fraction, so the
	# fill recedes leftward (opposite of a cast bar filling rightward). Teal to differentiate.
	_bar = CastBar.new()
	add_child(_bar)
	_bar.setup(caster, 2.9, CHANNEL_BAR_COLOR)
	_bar.set_progress(1.0)
	_do_tick()  # first tick fires immediately (the channel "connects" on cast)


func _process(delta: float) -> void:
	if _finished:
		return
	# Interrupt: caster gone / downed / stunned, OR the caster moved off the cast spot (moving cancels).
	if _caster == null or not is_instance_valid(_caster) or not _caster.is_alive() \
			or (_caster.has_method("is_stunned") and _caster.is_stunned()) \
			or (_caster.has_method("is_polymorphed") and _caster.is_polymorphed()) \
			or _caster.global_position.distance_to(_cast_spot) > MOVE_CANCEL_M:
		_finish()
		return
	_elapsed += delta
	if _bar != null and is_instance_valid(_bar):
		_bar.set_progress(clampf(1.0 - _elapsed / maxf(_total_dur, 0.001), 0.0, 1.0))  # drain
	_t += delta
	if _t >= _interval:
		_t -= _interval
		_do_tick()
		if _ticks_left <= 0:
			_finish()


## Public interrupt — a new cast (interrupt_active_channel) cancels the remaining channel.
func cancel_channel() -> void:
	_finish()


## End (natural completion OR interrupt): drop the bar, release the caster's channel ref, self-free.
func _finish() -> void:
	if _finished:
		return
	_finished = true
	if _caster != null and is_instance_valid(_caster) and _caster.has_method("clear_active_channel"):
		_caster.clear_active_channel(self)
	queue_free()


func _do_tick() -> void:
	var i: int = _ticks_total - _ticks_left   # 0-based 틱 번호 — cone의 뻗는 길이·nova의 마지막 틱 판정에 쓴다
	_ticks_left -= 1
	match _shape:
		"cone":
			_tick_cone(i)
		"cloud":
			_tick_cloud()
		"nova":
			_tick_nova(i)
		_:
			_tick_line()


## 공통 — 대상 배열에 틱 피해를 넣고 맞은 목록을 돌려준다.
func _hit_all(units: Array) -> Array:
	var hits: Array = []
	for e in units:
		if e != null and is_instance_valid(e) and e.has_method("take_damage"):
			if _dmg > 0.0:
				_ctx.deal_damage(e, _caster, _dmg)
			hits.append(e)
	return hits


## `line` — 원형(AB-054 절단 광선). 좁은 원뿔 = 직선 빔.
func _tick_line() -> void:
	var hits := _hit_all(_ctx.enemies_in_cone(_origin, _dir, _range, _half))
	_ctx.element_hit(String(_params.get("element", "")), _origin, _range, _caster, _params, hits)
	SkillVfx.lightning_bolt(_ctx, _origin, _origin + _dir * _range, Color(0.70, 0.85, 1.0))


## `cone` — **뻗어나가는** 부채꼴(AB-109 화염 분사). 사거리가 틱마다 자란다: 1틱은 발밑, 마지막 틱에
## 최대 사거리. 한 번에 전 범위를 덮지 않으므로 **가까운 적부터 순서대로** 맞고, 멀리 있는 적은
## 불길이 도달할 때까지 시간이 있다(= 채널을 끝까지 유지해야 뒷줄까지 닿는다).
func _tick_cone(i: int) -> void:
	var reach: float = _range * (float(i + 1) / float(_ticks_total))
	var hits := _hit_all(_ctx.enemies_in_cone(_origin, _dir, reach, _half))
	# 화염은 **즉시 효과 없이 순수 피해**다(Elements 규약: 점화는 RX 조건부 — 기름 위에서만 붙는다).
	# 사용자 판정(DRIFT-115 ③): 속성 추가 피해는 향후 피해 배율 축으로 얹는다.
	_ctx.element_hit(String(_params.get("element", "")), _origin, reach, _caster, _params, hits)
	# 불길은 **뿜어져 나가는 것**이라 지면 팬(전조 마커)으로는 안 읽힌다 — 전용 VFX가 이동·식는 색·
	# 성장 셋을 태운다. 수명(`_interval * 1.6`)이 틱 간격보다 길어 틱끼리 겹치며 연속 분사로 보인다.
	SkillVfx.flame_cone(_ctx, _origin, _dir, reach, _half, _interval * 1.6)


## `cloud` — **조준점**에 머무는 독 구름(AB-110). 틱마다 독 스택을 누적한다(AB-010과 같은 API).
## 피해가 아니라 **스택**이 payoff라 `_dmg`는 0에 가깝게 잡는다.
func _tick_cloud() -> void:
	var unit_dps := float(_params.get("poison_dps", 6.0))
	var dur := float(_params.get("poison_dur_s", 8.0))
	var cap: float = unit_dps * float(_params.get("poison_stack_cap", 5))
	var hits := _hit_all(_ctx.enemies_in_radius(_origin, _radius))
	for e in hits:
		if e.has_method("apply_poison_stack"):
			e.apply_poison_stack(dur, unit_dps, cap, unit_dps)
	_ctx.element_hit(String(_params.get("element", "")), _origin, _radius, _caster, _params, hits)
	SkillVfx.element_field("poison", _ctx, _origin, _radius)


## `nova` — 자기중심 냉기 폭풍(AB-111). 틱마다 **냉각이 깊어지고**(Chilled.mag = 연속 피격 비율),
## **마지막 틱까지 전부 맞은 대상만 빙결**된다. 반경을 한 번이라도 벗어나면 연속 카운트가 끊겨
## 빙결이 무산된다 — 즉 **적이 빠져나갈 여지가 있는 CC**이고, 그게 세기의 대가다.
func _tick_nova(i: int) -> void:
	var chill_s := float(_params.get("chill_dur_s", 3.0))
	var freeze_s := float(_params.get("freeze_s", 2.0))
	var hits := _hit_all(_ctx.enemies_in_radius(_origin, _radius))
	var next: Dictionary = {}
	var last: bool = (i >= _ticks_total - 1)
	for e in hits:
		var key: int = e.get_instance_id()
		var n: int = int(_streak.get(key, 0)) + 1
		next[key] = n
		if not e.has_method("apply_outcome"):
			continue
		# 심화도 = 연속으로 맞은 비율(0~1). OutcomeStatus가 이 mag로 감속 깊이를 보간한다.
		e.apply_outcome("Chilled", chill_s, clampf(float(n) / float(_ticks_total), 0.0, 1.0))
		if last and n >= _ticks_total:
			e.apply_outcome("Frozen", freeze_s)
	_streak = next   # 이번 틱에 안 맞은 대상은 표에서 빠진다 = 연속 끊김
	# 속성 seam — 냉기 RX(물 → 얼음)도 틱마다 성립한다. 여기서 다시 걸리는 Chilled는 mag 0이라
	# 위에서 넣은 심화도를 덮지 않는다(OutcomeStatus.apply은 mag>0일 때만 갱신).
	_ctx.element_hit(String(_params.get("element", "")), _origin, _radius, _caster, _params, hits)
	SkillVfx.element_field("cold", _ctx, _origin, _radius)
