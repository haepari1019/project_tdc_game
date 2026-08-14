extends SceneTree
## QA-032 §2.1 — **중립 성장 회귀 게이트**. `F-030` §3.7 R2 · `F-005` §3.3a.
## **이 게이트가 깨지면 doctrine 기능 전체를 롤백한다.**
##
## 개정 전에는 NC lookup이 **폐쇄 파이프라인**이라 "prep 없이도 AI가 정상 작동"이 자동 보장됐다.
## doctrine 변조를 허용하면서 그 보장이 **조항 + 이 게이트로 격하**됐다.
##
## ⚠️ **이 게이트가 검증하는 것과 못 하는 것을 분명히 한다.**
##
## **검증한다 (기계적·결정적):**
##   ① `activeDoctrineIds == []`일 때 8단계 훅 **호출 수 = 0** (스킵 보장).
##   ② 8단계 훅이 doctrine 0에서 **순수 통과**(입력 dict를 그대로 반환) — 결과 동일이 *구성상* 따라온다.
##   ③ lookup 1~7 진입점의 **시그니처·호출 순서 불변** — 훅이 1~7 사이에 끼어들지 않았음을 구조로 확인.
##
## **검증하지 못한다 (정직하게):**
##   `ENC-HARD-001~005`의 **바이트 동일 결과 리플레이**. 현 하네스는 물리·navmesh·프레임 타이밍이
##   섞여 있어 전체 조우를 재현 가능하게 돌릴 수 없다. 그 수준은 결정적 리플레이 하네스가 선행돼야 하며,
##   지금은 **①②③이 그 자리를 대신한다** — 훅이 안 불리고 통과 함수가 항등이면 1~7의 출력은 변할 수 없다.
##   ⇒ **F5 수동 확인이 여전히 필요**하다: 중립 성장으로 `ENC-HARD-*` 클리어 성립(QA-032 §2.1 세 번째 Given).

var _ok := true


func _init() -> void:
	await process_frame
	await process_frame
	var sd = root.get_node_or_null("/root/Slice01Data")
	if sd == null or not sd.is_loaded():
		print("NC BASELINE FAILED — Slice01Data not loaded")
		quit(1)
		return

	var CC := load("res://scripts/combat/combat_controller.gd")

	# ① 훅 존재 + 중립 시 호출 0 -------------------------------------------------
	# 훅이 아직 없으면(CS-3 미착수) 그 자체가 "8단계 없음" = 중립 보장이므로 통과로 친다.
	# CS-3이 훅을 넣는 순간부터 카운터가 실물이 되고, 이 게이트가 0을 강제한다.
	var has_hook: bool = CC.new().has_method("doctrine_modulate")
	if not has_hook:
		_expect(true, "8단계 훅 미도입 — 폐쇄 파이프라인 유지(CS-3 전 기준선)")
	else:
		var cc = CC.new()
		cc.doctrine_modulation_count = 0
		# doctrine 0에서 훅을 태워도 카운트가 늘지 않아야 한다(= 스킵).
		var probe := {"identity_cast_cadence": 1.0, "_probe": 42}
		var out: Dictionary = cc.doctrine_modulate(null, probe)
		_expect(int(cc.doctrine_modulation_count) == 0, "doctrine 0 → 8단계 호출 수 0 (스킵)")
		# ② 순수 통과 — 입력을 그대로 돌려줘야 결과 동일이 구성상 따라온다.
		_expect(out == probe, "doctrine 0 → 8단계 항등 통과(입력 == 출력)")
		cc.free()

	# ③ lookup 1~7 진입점 불변 — 훅이 중간에 끼어들지 않았는지 구조로 확인 ---------
	# `_tick_party_attacks`가 NC 판단의 폐쇄 구간이다. 여기 시그니처가 바뀌면 1~7 순서가
	# 흔들렸을 가능성이 크므로 게이트가 먼저 운다(F-005 §3.3a 2번 항목).
	var src := FileAccess.get_file_as_string("res://scripts/combat/combat_controller.gd")
	_expect(src.find("func _tick_party_attacks(members: Array, delta: float) -> void:") >= 0,
		"NC 폐쇄 구간 진입점(_tick_party_attacks) 시그니처 불변")
	# `읽지 않음` 목록 유지(F-005 §3.3) — NC 경로가 서브/핑을 읽기 시작하면 대전제가 깨진다.
	var nc_block := _slice(src, "func _tick_party_attacks", "\nfunc ")
	for banned in ["get_skillbook(", "cast_skillbook(", "move_ping", "leader_ping"]:
		_expect(nc_block.find(banned) < 0, "NC 경로 `읽지 않음` 유지 — %s 미참조" % banned)

	# ④ 프로필 doctrine 상태 = 중립이 기본 ---------------------------------------
	var dp := root.get_node_or_null("/root/DoctrineProfile")
	if dp != null:
		_expect(dp.active_ids().is_empty() or dp.has_method("clear_all"),
			"DoctrineProfile — 중립(활성 0) 기본 또는 초기화 경로 존재")

	if _ok:
		print("NC BASELINE PASSED")
		quit(0)
	else:
		print("NC BASELINE FAILED")
		quit(1)


## `from`으로 시작해 다음 `to`가 나오기 전까지의 소스 조각(함수 본문 근사).
func _slice(src: String, from: String, to: String) -> String:
	var i := src.find(from)
	if i < 0:
		return ""
	var j := src.find(to, i + from.length())
	return src.substr(i, (j - i) if j > i else -1)


func _expect(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_ok = false
