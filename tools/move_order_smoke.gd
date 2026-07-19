extends SceneTree
## Move-order state machine smoke (DRIFT-090) — RMB 클릭이동 오더가 스왑을 넘어 살아남고,
## 각 멤버를 따로 배치할 수 있게 하는 3-상태(NONE/MOVING/HOLD) 전이를 검증한다.
## 특히 **cb 유무로 도착 후 거동이 갈리는 규칙**(순수 이동=HOLD 배치 / 심부름=NONE 복귀)은
## 상자·캐스트 접근이 진형에서 영구 이탈하는 걸 막는 핵심이라 회귀 게이트가 필요하다.
## 이동 실거동(진형 우선순위·점선·집합키 체감)은 F5 플레이테스트 몫.
## Run: GODOT --headless --path . --script res://tools/move_order_smoke.gd

const MEMBER_SCENE := "res://scenes/party/party_member.tscn"

var _ok := true


func _initialize() -> void:
	var scene: PackedScene = load(MEMBER_SCENE)
	if scene == null:
		print("  FAIL party_member.tscn 로드 실패")
		print("MOVE ORDER SMOKE FAILED")
		quit(1)
		return

	# --- 1) 순수 이동 오더(cb 없음): 도착 → HOLD(그 자리 배치) ---
	var m := scene.instantiate()
	root.add_child(m)
	await process_frame   # _initialize 는 트리 구성 전 — 한 프레임 넘겨야 global_position 이 유효
	_chk("초기 상태 = NONE", not m.has_move_order() and not m.is_order_holding() and not m.has_any_order())
	m.order_move_to(Vector3(50, 0, 50), Callable(), 0.4)
	_chk("오더 직후 = MOVING", m.has_move_order() and m.has_any_order() and not m.is_order_holding())
	_chk("오더 목표 보존", m.order_target().is_equal_approx(Vector3(50, 0, 50)))
	# 도착 판정: 목표를 자기 위치로 다시 찍으면 arrive_dist 안 → 도착 분기.
	m.order_move_to(m.global_position, Callable(), 0.4)
	var v: Vector3 = m.order_desired_velocity(9.0, 0.016)
	_chk("도착 프레임 속도 = ZERO", v == Vector3.ZERO)
	_chk("순수 이동 도착 → HOLD", m.is_order_holding() and not m.has_move_order())
	_chk("HOLD 도 오더 보유로 집계(집합키 대상)", m.has_any_order())
	m.cancel_order()
	_chk("cancel_order → NONE", not m.has_any_order())

	# --- 2) 심부름 오더(cb 있음): 도착 → 콜백 발화 + NONE(진형 복귀) ---
	var fired := [false]
	m.order_move_to(m.global_position, func() -> void: fired[0] = true, 0.4)
	_chk("cb 오더 직후 = MOVING", m.has_move_order())
	m.order_desired_velocity(9.0, 0.016)
	_chk("cb 도착 → 콜백 발화", fired[0])
	_chk("cb 도착 → NONE(HOLD 아님)", not m.has_any_order())

	# --- 3) 상태 이벤트가 오더를 취소하는가 ---
	m.order_move_to(Vector3(50, 0, 50), Callable(), 0.4)
	m.set_mia(true)
	_chk("MIA → 오더 취소(제자리 대기, F-004 §3.4)", not m.has_any_order())
	m.set_mia(false)
	m.order_move_to(Vector3(50, 0, 50), Callable(), 0.4)
	m.apply_provoke(m, 2.0)
	_chk("도발(AB-099) → 오더 취소", not m.has_any_order())

	# --- 3b) 기절은 오더를 취소하지 않는다(잠시 멈췄다가 풀리면 목표로 재출발) ---
	m.provoked_timer_s = 0.0
	m.order_move_to(Vector3(50, 0, 50), Callable(), 0.4)
	m.apply_stun(1.0)
	_chk("기절 중에도 오더 유지(MOVING)", m.is_stunned() and m.has_move_order())
	m.stun_timer_s = 0.0
	_chk("기절 해제 후에도 오더 유지 → 재출발 가능", not m.is_stunned() and m.has_move_order())
	_chk("기절 해제 후 목표 보존", m.order_target().is_equal_approx(Vector3(50, 0, 50)))
	m.cancel_order()

	# --- 3c) 캐스팅도 오더를 취소하지 않는다(시전 중 정지 → 끝나면 목표로 재출발) ---
	m.order_move_to(Vector3(50, 0, 50), Callable(), 0.4)
	m.begin_channel(1.5)
	_chk("캐스팅 중에도 오더 유지(MOVING)", m.is_channeling() and m.has_move_order())
	m.end_channel()
	_chk("시전 종료 후에도 오더 유지 → 재출발 가능", not m.is_channeling() and m.has_move_order())
	_chk("시전 종료 후 목표 보존", m.order_target().is_equal_approx(Vector3(50, 0, 50)))
	m.cancel_order()

	# --- 4) MIA/다운 상태에서는 새 오더를 받지 않는다 ---
	m.provoked_timer_s = 0.0
	m.set_mia(true)
	m.order_move_to(Vector3(9, 0, 9), Callable(), 0.4)
	_chk("MIA 중 신규 오더 거부", not m.has_any_order())
	m.set_mia(false)

	# --- 5) nav 캐시 무효화 — 오더↔진형 전환에서 stale path 재사용 차단 ---
	m.nav_set_target(Vector3(3, 0, 3))
	m.nav_invalidate()
	_chk("nav_invalidate → 남은 경로 없음", m.nav_path_remaining().is_empty() and not m.nav_has_path())

	m.queue_free()
	print("MOVE ORDER SMOKE " + ("PASSED" if _ok else "FAILED"))
	quit(0 if _ok else 1)


func _chk(label: String, cond: bool) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_ok = false
