extends RefCounted
## ENC-000 §2 조합 제너레이터 (S5b P2) — (difficulty, seed) → EN-* 조합(enemy_id 리스트).
## 가드레일: mechanicAxes(= eliteCount + 고유 specialist axis 수) ≤ axes_max · fodder min/max · variant min.
## EN-* 태그(Slice01Data.get_enemy_tags, P1) 소비. 제3세력(faction≠Monster)은 base 조합에서 제외 —
## 창발 모디파이어(P3)로 주입. authored set-piece(보스·QA핀)는 이 제너레이터를 우회(하이브리드).
## 결정적: 전달된 seed로 RandomNumberGenerator 시드 → 같은 (difficulty, seed) = 같은 조합. ref: encounter_variety_architecture.md.

## 난이도별 예산(ENC-000 §2 표). axes_max = mechanicAxes 상한(데모 2, F-024 §3.2.1).
const SCALE := {
	"Normal":  {"fodder_min": 2, "fodder_max": 4, "elite_max": 1, "specialist_max": 1, "axes_max": 2, "variant_min": 2},
	"Hard":    {"fodder_min": 2, "fodder_max": 5, "elite_max": 1, "specialist_max": 1, "axes_max": 2, "variant_min": 2},
	"Extreme": {"fodder_min": 0, "fodder_max": 6, "elite_max": 1, "specialist_max": 2, "axes_max": 2, "variant_min": 1},
}
const SPECIALIST_CHANCE := 0.6   # 축 예산이 남아도 매번 specialist를 넣진 않음(다양성). (tuning)
const ELITE_SKIP_CHANCE := 0.15  # fodder-only 워밍업 허용(fodder_min=0 난이도 한정). (tuning)


## difficulty + seed → 조합. 반환 {enemies:[id], elites, specialists, fodder, mechanic_axes, difficulty}.
static func generate(difficulty: String, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var sc: Dictionary = SCALE.get(difficulty, SCALE["Normal"])
	var pools := _bucket_pools()
	var axes_max := int(sc["axes_max"])
	var used_axes := 0
	var elites: Array = []
	var specialists: Array = []

	# 1) Elite — 보통 1(전형 "Elite 1 + …"). fodder_min=0 난이도에선 낮은 확률로 생략(fodder-only 워밍업).
	if not pools["Elite"].is_empty() and int(sc["elite_max"]) > 0:
		var allow_skip := int(sc["fodder_min"]) == 0 and rng.randf() < ELITE_SKIP_CHANCE
		if not allow_skip:
			elites.append(_pick(pools["Elite"], rng))
			used_axes += 1

	# 2) Specialist — 고유 axis만, 축 예산(axes_max) + specialist_max 안에서.
	var spec_pool: Array = pools["Specialist"].duplicate()
	_shuffle(spec_pool, rng)
	var seen_axes: Dictionary = {}
	for sid in spec_pool:
		if used_axes >= axes_max or specialists.size() >= int(sc["specialist_max"]):
			break
		var ax := String(Slice01Data.get_enemy_tags(String(sid)).get("axis", ""))
		if ax.is_empty() or seen_axes.has(ax):
			continue   # 동일 종류 2마리는 1축 — 고유 종류만 카운트(ENC-000 §2)
		if rng.randf() < SPECIALIST_CHANCE:
			specialists.append(sid)
			seen_axes[ax] = true
			used_axes += 1

	# 3) Fodder — fodder_min~max, count≥3이면 variant_min 종류 이상(반복 피로 완화).
	var fc := rng.randi_range(int(sc["fodder_min"]), int(sc["fodder_max"]))
	var fodder := _pick_fodder(pools["Fodder"], fc, int(sc["variant_min"]), rng)

	var enemies: Array = []
	enemies.append_array(elites)
	enemies.append_array(specialists)
	enemies.append_array(fodder)
	return {
		"enemies": enemies,
		"elites": elites,
		"specialists": specialists,
		"fodder": fodder,
		"mechanic_axes": used_axes,   # eliteCount + 고유 specialist axis 수 (≤ axes_max)
		"difficulty": difficulty,
	}


## Monster faction의 bucket별 enemy_id 풀. 제3세력 제외(P3 창발 주입).
static func _bucket_pools() -> Dictionary:
	var out := {"Elite": [], "Specialist": [], "Fodder": []}
	for eid in Slice01Data.get_enemy_ids():
		var t: Dictionary = Slice01Data.get_enemy_tags(String(eid))
		if t.is_empty() or String(t.get("faction", "Monster")) != "Monster":
			continue
		var b := String(t.get("bucket", ""))
		if out.has(b):
			out[b].append(String(eid))
	return out


## fodder count개 추첨 — count≥3이면 서로 다른 variant ≥ variant_min 보장 후 나머지 랜덤 채움.
static func _pick_fodder(pool: Array, count: int, variant_min: int, rng: RandomNumberGenerator) -> Array:
	if pool.is_empty() or count <= 0:
		return []
	var by_variant: Dictionary = {}
	for fid in pool:
		var t: Dictionary = Slice01Data.get_enemy_tags(String(fid))
		var v := String(t.get("fodder_variant", t.get("axis", "misc")))
		if not by_variant.has(v):
			by_variant[v] = []
		by_variant[v].append(fid)
	var variants: Array = by_variant.keys()
	_shuffle(variants, rng)
	var out: Array = []
	var need_distinct: int = mini(variant_min if count >= 3 else 1, variants.size())
	for i in need_distinct:
		out.append(_pick(by_variant[variants[i]], rng))
	while out.size() < count:
		out.append(_pick(pool, rng))
	return out


static func _pick(arr: Array, rng: RandomNumberGenerator) -> String:
	return String(arr[rng.randi_range(0, arr.size() - 1)])


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
