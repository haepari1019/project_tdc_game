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

	# --- 6) 추종 오더(DRIFT-196) — 목적지가 **좌표가 아니라 유닛**이다 ---
	# 단일 대상 스킬을 사거리 밖에 쓰면 목적지가 대상에 고정된다. 예전엔 클릭 순간의 좌표라
	# 적이 자리를 뜨면 빈 땅으로 걸어가 사거리에 못 들었다. 아래 두 검사는 **nav 비의존**이다 —
	# 추종 갱신도 대상 소멸 처리도 nav 분기보다 **앞**에서 끝나므로 헤드리스에서 결정적이다.
	m.provoked_timer_s = 0.0
	var tgt = scene.instantiate()
	root.add_child(tgt)
	await process_frame
	tgt.global_position = Vector3(30, 0, 0)
	m.global_position = Vector3.ZERO
	var cast_fired := [false]
	m.order_move_to(tgt.global_position, func() -> void: cast_fired[0] = true, 2.0, tgt)
	_chk("추종 오더 → 대상 노출", m.order_follow_target() == tgt)
	tgt.global_position = Vector3(40, 0, 5)                  # 대상이 자리를 뜬다
	m.order_desired_velocity(9.0, 0.016)
	_chk("대상이 움직이면 목표가 따라간다", m.order_target().is_equal_approx(Vector3(40, 0, 5)))
	m.cancel_order()
	_chk("cancel_order → 추종 해제", m.order_follow_target() == null)

	# 좌표 오더는 추종이 없다 — 색·표식이 갈리는 근거가 이 값 하나다(오버레이가 이걸 읽는다).
	m.order_move_to(Vector3(50, 0, 50), Callable(), 0.4)
	_chk("좌표 오더 → 추종 없음(연두 점선)", m.order_follow_target() == null)
	m.cancel_order()

	# 대상이 죽으면 쫓아갈 이유가 없다 → 오더를 놓되 **콜백은 쏘지 않는다**(= 시전도 안 일어난다).
	cast_fired[0] = false
	m.order_move_to(tgt.global_position, func() -> void: cast_fired[0] = true, 2.0, tgt)
	tgt.take_damage(99999.0)
	_chk("대상 사망 확인", not tgt.is_alive())
	m.order_desired_velocity(9.0, 0.016)
	# ⚠ `has_any_order()`만 보면 **공허한 검사**다 — 추종 처리를 빼도 nav 분기(`dist<0.05`)가 오더를
	# 끝내 버려 똑같이 false가 된다(반증 확인에서 실제로 통과했다). 취소와 완료를 가르는 것은
	# **콜백이 쐈는가** 하나뿐이므로 둘을 한 검사로 묶는다.
	_chk("대상 사망 → 오더 취소 + 시전 미발화", not m.has_any_order() and not cast_fired[0])
	tgt.queue_free()

	# --- 7) 시전 중 조준 표식(DRIFT-197) — 표식이 사라지는 시점 = **스킬이 나가는 시점** ---
	# 사거리 **안**이면 접근 오더가 아예 없어 6)의 추종 경로를 안 탄다. 그래서 표식 수명을
	# 오더가 아니라 **시전 점유**(begin/end_channel)에 매달았다 — 캐스트의 모든 출구가 지나는 문.
	var ct = scene.instantiate()
	root.add_child(ct)
	await process_frame
	_chk("시전 전 = 대상 없음", m.cast_target() == null)
	m.begin_channel(3.0, ct)
	_chk("시전 시작 → 대상 노출(오더 없이도)", m.cast_target() == ct and not m.has_any_order())
	m.end_channel()
	_chk("시전 종료 → 표식 해제", m.cast_target() == null)
	# 자기제한 — 점유 타이머가 소진되면 `end_channel` 없이도 표식이 남지 않는다.
	m.begin_channel(0.0, ct)
	_chk("점유 소진 → 표식 자동 소멸", not m.is_channeling() and m.cast_target() == null)
	# 대상이 죽으면 시체에 표식을 남기지 않는다.
	m.begin_channel(3.0, ct)
	ct.take_damage(99999.0)
	_chk("대상 사망 → 표식 해제(시체에 안 남김)", m.cast_target() == null)
	m.end_channel()
	# 대상 없는 캐스트(광역·자기중심)는 표식이 없다 — 단일 대상 스킬만의 표시다.
	m.begin_channel(3.0, null)
	_chk("대상 없는 캐스트 → 표식 없음", m.is_channeling() and m.cast_target() == null)
	m.end_channel()
	ct.queue_free()

	# --- 8) 관대한 적 선택(DRIFT-198) — 스냅 반경·제외 규칙은 **실동작으로** 검사한다 ---
	# 레이픽(마우스)은 헤드리스에서 못 돌지만 스냅 계산은 카메라와 그룹만 있으면 순수 함수다.
	# 위에서 아래로 내려보는 카메라를 세우면 월드 XZ ↔ 화면 XY가 선형이라 픽셀 거리를 손으로 잡을 수 있다.
	var AC = load("res://scripts/run/controllers/aim_controller.gd")
	var ac = AC.new()
	root.add_child(ac)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 20, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)   # 수직 하향 — XZ가 화면 XY로 곧장 투영된다
	cam.make_current()
	await process_frame
	var EN = load("res://scripts/combat/enemy_unit.gd")
	var ea = EN.new()
	root.add_child(ea)
	ea.add_to_group("enemy")                    # setup() 없이 쓰므로 그룹만 손으로 넣는다
	ea.global_position = Vector3.ZERO
	var eb = EN.new()
	root.add_child(eb)
	eb.add_to_group("enemy")
	eb.global_position = Vector3(5, 0, 0)       # 멀리 — 스냅 후보에서 벗어나 있어야 한다
	await process_frame
	var sa: Vector2 = cam.unproject_position(ea.global_position + Vector3(0, 0.7, 0))
	var sb: Vector2 = cam.unproject_position(eb.global_position + Vector3(0, 0.7, 0))
	var ppm: float = sa.distance_to(sb) / 5.0   # px/m — 카메라 설정에서 실측(하드코딩 금지)
	_chk("투영 유효(px/m > 0)", ppm > 1.0)
	_chk("커서가 적 위 → 스냅", ac._nearest_enemy_on_screen(cam, sa) == ea)
	# 슬랙 안/밖을 **경계 양쪽**으로 민다 — 반경이 실제로 그 값인지 확인(있기만 한지가 아니라).
	var slack: float = ac.PICK_SLACK_PX
	# ⚠ 아래 0.8×/1.2× 검사는 **자기참조적**이다 — 상수를 2px로 줄이면 오프셋도 같이 줄어 통과한다
	# (반증에서 실제로 통과했다). 그것들이 고정하는 건 「스냅 반경 == PICK_SLACK_PX」라는 **기제**이지
	# 값이 쓸모 있는지가 아니다. 값의 **의도**는 따로 못박는다: 관대 선택의 목적이 「몸통보다 후하게」인
	# 이상, 슬랙은 적 몸통 반폭(0.35m)의 화면 크기보다 확실히 커야 한다. 튜닝 리터럴이 아니라
	# 몸통에서 유도하므로 줌·해상도를 바꿔도 살아남는다(DRIFT-195의 교훈).
	_chk("슬랙이 몸통 반폭보다 관대하다(보정이 실재)", slack > 0.35 * ppm * 1.5)
	_chk("슬랙 안(0.8×) → 스냅", ac._nearest_enemy_on_screen(cam, sa + Vector2(slack * 0.8, 0)) == ea)
	_chk("슬랙 밖(1.2×) → 미선택(빈 지면 = 취소 유지)", ac._nearest_enemy_on_screen(cam, sa + Vector2(slack * 1.2, 0)) == null)
	# 더 가까운 쪽을 고른다 — 두 적 사이 중간보다 A쪽으로 치우친 지점.
	eb.global_position = Vector3(slack * 1.4 / ppm, 0, 0)
	await process_frame
	var sb2: Vector2 = cam.unproject_position(eb.global_position + Vector3(0, 0.7, 0))
	_chk("두 적 중 화면상 더 가까운 쪽", ac._nearest_enemy_on_screen(cam, sb2 + Vector2(4, 0)) == eb)
	# 제외 규칙 2종 — 안개 너머와 시체는 스냅 대상이 아니다.
	eb.hp = 0.0
	ea.set_seen(false)
	_chk("안 보이는 적 제외(스냅이 투시 수단이 되면 안 된다)", ac._nearest_enemy_on_screen(cam, sa) == null)
	ea.set_seen(true)
	_chk("죽은 적 제외(시체 스냅 방지)", ac._nearest_enemy_on_screen(cam, sb2) == null and ac._nearest_enemy_on_screen(cam, sa) == ea)
	ea.queue_free()
	eb.queue_free()
	cam.queue_free()
	ac.queue_free()

	# --- 9) 「시전 중엔 안 끌려간다」 술어(DRIFT-199) ---
	# `is_channeling()`은 `begin_channel` **점유**만 본다 = cast_s 윈드업·채널힐뿐. `sb_channeling`
	# (AB-054/109/110/111)은 일부러 점유를 안 잡으므로 그 술어로는 **채널링 스킬이 안 걸렸다** —
	# 스왑 후 다른 멤버를 움직이면 채널 중인 멤버가 진형을 따라 끌려가 스스로 채널을 끊었다.
	_chk("평시 = 시전 중 아님", not m.is_casting_or_channeling())
	m.begin_channel(3.0)
	_chk("캐스트 점유 → 시전 중", m.is_casting_or_channeling())
	m.end_channel()
	_chk("점유 해제 → 시전 중 아님", not m.is_casting_or_channeling())
	# 채널 노드 경로 — 점유를 안 잡는 쪽. 이게 예전 술어가 놓치던 자리다.
	var chn := Node.new()
	root.add_child(chn)
	m.set_active_channel(chn)
	_chk("채널 노드 등록 → 시전 중(점유 없이도)", m.is_casting_or_channeling() and not m.is_channeling())
	m.clear_active_channel(chn)
	_chk("채널 종료 → 시전 중 아님", not m.is_casting_or_channeling())
	# 노드가 해제 통보 없이 사라져도 얼어붙지 않는다(stale 참조로 영구 정지 방지).
	m.set_active_channel(chn)
	chn.free()
	_chk("채널 노드 소멸 → 자동 해소(영구 정지 없음)", not m.is_casting_or_channeling())

	# --- 10) 이동선은 시전 지점까지, 착탄점은 따로(DRIFT-200) ---
	# 범위기를 사거리 밖에 쓰면 오더 목표는 **착탄점**이지만 멤버는 `arrive_dist`(= 시전 사거리)만큼
	# 못 미쳐 멈춘다. 선이 목표까지 이어지면 「착탄점까지 걸어간다」고 거짓말한다.
	var MPO = load("res://scripts/run/controllers/move_path_overlay.gd")
	var line := PackedVector3Array([Vector3.ZERO, Vector3(10, 0, 0)])
	var cut: PackedVector3Array = MPO._truncate(line, Vector3(10, 0, 0), 3.0)
	_chk("이동선이 도착 반경에서 잘린다", cut.size() == 2 and is_equal_approx(cut[1].x, 7.0))
	_chk("잘린 끝 = 시전 지점(목표 아님)", cut[cut.size() - 1].distance_to(Vector3(10, 0, 0)) > 2.9)
	# 꺾인 경로에서도 **처음 닿는 지점**에서 잘려야 한다(마지막 구간만 보면 안 된다).
	var bent := PackedVector3Array([Vector3.ZERO, Vector3(10, 0, 0), Vector3(10, 0, 10)])
	var cut2: PackedVector3Array = MPO._truncate(bent, Vector3(10, 0, 0), 3.0)
	_chk("꺾인 경로도 첫 진입점에서 잘린다", cut2.size() == 2 and is_equal_approx(cut2[1].x, 7.0))
	_chk("도착 반경 0 → 선 그대로", (MPO._truncate(line, Vector3(10, 0, 0), 0.0) as PackedVector3Array).size() == 2)
	_chk("이미 반경 안 → 선 없음", (MPO._truncate(PackedVector3Array([Vector3(9, 0, 0)]), Vector3(10, 0, 0), 3.0) as PackedVector3Array).size() == 0)

	# 착탄 표기 수명 — 오더 구간(order_aim_radius)과 시전 구간(cast_aim_radius)이 이어진다.
	_chk("평시 = 착탄 표기 없음", m.order_aim_radius() < 0.0 and m.cast_aim_radius() < 0.0)
	m.order_move_to(Vector3(20, 0, 0), func() -> void: pass, 6.0, null, 4.5)
	_chk("범위기 접근 오더 → 착탄 반경 노출", is_equal_approx(m.order_aim_radius(), 4.5))
	_chk("접근 오더의 도착 거리 = 시전 사거리", is_equal_approx(m.order_arrive_dist(), 6.0))
	m.cancel_order()
	_chk("오더 해제 → 착탄 표기 없음(이동선과 함께 사라진다)", m.order_aim_radius() < 0.0)
	# 순수 이동 오더는 착탄점이 아니다 — 표기가 붙으면 안 된다.
	m.order_move_to(Vector3(20, 0, 0), Callable(), 0.4)
	_chk("순수 이동 오더 → 착탄 표기 없음", m.order_aim_radius() < 0.0)
	m.cancel_order()
	# 시전 구간 — 대상 유닛이 없는 범위기는 「어디에」를 시전 내내 보여 준다.
	m.begin_channel(3.0, null, Vector3(20, 0, 0), 4.5)
	_chk("시전 중 → 착탄 표기 유지(대상 유닛 없이도)", is_equal_approx(m.cast_aim_radius(), 4.5)
		and m.cast_aim_pos().is_equal_approx(Vector3(20, 0, 0)) and m.cast_target() == null)
	m.end_channel()
	_chk("시전 종료 → 착탄 표기 해제(스킬 나가는 시점)", m.cast_aim_radius() < 0.0)
	m.begin_channel(0.0, null, Vector3(20, 0, 0), 4.5)
	_chk("점유 소진 → 착탄 표기 자동 소멸", m.cast_aim_radius() < 0.0)
	m.end_channel()

	# 배선 두 지점은 헤드리스에서 못 돈다(조준 모달 = 마우스 · 오버레이 = 렌더) → **소스로 못박는다**
	# (DRIFT-119 ward_heal 선례). 위 상태기계가 옳아도 이 둘이 안 이어지면 화면엔 아무 변화가 없다.
	var aim := FileAccess.get_file_as_string("res://scripts/run/controllers/aim_controller.gd")
	# 핀 작성 규칙(세 번 깨지고 배운 것) — **인자 목록의 끝을 붙들지 않는다.** 변수명을 박으면
	# 리네임에 깨지고(`target_pos`→`aim_pos`), 닫는 괄호까지 박으면 **인자를 하나 추가할 때마다**
	# 깨진다(`unit)` → `unit, aim_r)`). 둘 다 회귀가 아니라 리팩터를 잡는 것이다. 지켜야 할 계약은
	# 「그 인자가 그 호출에 실린다」이므로 **닫는 괄호 없이** 조각만 본다.
	_chk("조준 확정이 대상을 추종 인자로 넘긴다", aim.contains("order_move_to(") and aim.contains(", rng, unit"))
	_chk("사거리 판정이 대상 기준(관대 선택 정합)", aim.contains("unit.global_position if unit != null"))
	_chk("적 선택이 레이픽 실패 시 근접 스냅으로 넘어간다", aim.contains("_nearest_enemy_on_screen(cam, mp)"))
	_chk("스냅이 안 보이는 적을 제외한다", aim.contains("is_seen") and aim.contains("PICK_SLACK_PX"))
	var ov := FileAccess.get_file_as_string("res://scripts/run/controllers/move_path_overlay.gd")
	_chk("오버레이가 추종 여부로 색을 가른다", ov.contains("order_follow_target") and ov.contains("COLOR_CAST_ACTIVE"))
	_chk("오버레이가 추종 시 조준 표식을 그린다", ov.contains("_draw_lock(goal, col)"))
	_chk("오버레이 점선이 자기 Y 기준(층 대응)", ov.contains("a.y + GROUND_LIFT") and not ov.contains("GROUND_Y"))
	_chk("오버레이가 시전 중 대상 표식을 그린다", ov.contains("m.cast_target()") and ov.contains("_draw_lock(casting.global_position"))
	# 자동 이동 3경로가 **같은 술어**를 쓰는가 — 하나라도 옛 술어면 그 경로로 다시 끌려간다.
	# (진형 추종 Pass 1 / 비조작 앵커 Pass 3 / 조작캐 오더 일시정지)
	var pc_src := FileAccess.get_file_as_string("res://scripts/party/party_controller.gd")
	_chk("진형·앵커 2경로가 통합 술어 사용", pc_src.count("is_casting_or_channeling()") >= 2 and not pc_src.contains("is_channeling()"))
	var plc := FileAccess.get_file_as_string("res://scripts/run/controllers/player_controller.gd")
	_chk("오더 일시정지도 통합 술어 사용", plc.contains("is_casting_or_channeling()") and not plc.contains("is_channeling()"))
	var disp := FileAccess.get_file_as_string("res://scripts/combat/abilities/ability_dispatch.gd")
	_chk("캐스트 노드가 시전 대상을 받는다", disp.contains("_cast_charge_color(p), target_unit"))
	var sc := FileAccess.get_file_as_string("res://scripts/combat/abilities/effects/skill_cast.gd")
	_chk("캐스트가 점유와 함께 대상·착탄점을 싣는다", sc.contains("caster.begin_channel(dur, target, aim, aim_radius)"))
	# 착탄 분류는 **조준이 소유한다** — dispatch에서 kind/반경으로 다시 판정하면 조준 프리뷰와 갈라진다.
	_chk("착탄 반경이 접근 오더와 시전 양쪽에 실린다",
		aim.contains("rng, unit, aim_r") and aim.contains("cast_skillbook(m, slot, aim_pos, unit, aim_r"))
	_chk("착탄 분류가 조준 프리뷰(disc)에서 나온다", aim.contains("_aim_radius = disc"))
	_chk("오버레이가 이동선을 도착 거리에서 자른다", ov.contains("_truncate(pts, goal, stop_r)"))
	_chk("오버레이가 착탄 표기를 따로 그린다", ov.contains("_draw_impact(goal, aim_r, col)") and ov.contains("_draw_impact(m.cast_aim_pos(), cast_r, cast_col)"))

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
