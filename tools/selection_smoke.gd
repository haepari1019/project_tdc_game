extends SceneTree
## Drag-box selection coverage gate (DRIFT-090 후속).
##
## 예전 판정은 아군의 **원점(발밑) 한 점**이 박스에 드는지만 봤다. 그런데 40° 피치 카메라에서
## 원점은 캐릭터 화면 사각형의 **세로 ~86% 지점**(거의 바닥)에 찍힌다 → 박스가 발치만 스쳐도
## 선택됐고, 거기에 "좌측 우선" 규칙이 겹쳐 의도한 가운데 아군 대신 왼쪽에 걸친 아군이
## 가로챘다. 이제 화면상 사각형의 겹친 **면적 비율**이 SELECT_COVER_MIN 이상이어야 후보다.
##
## 이 게이트가 지키는 것: ① 원점이 여전히 사각형 바닥 근처라는 전제(카메라 피치가 바뀌면
## 깨진다) ② 발치만 걸친 박스는 탈락 ③ 제대로 감싼 박스는 통과 ④ 임계 경계 근처의 방향성.
## Run: GODOT --headless --path . --script res://tools/selection_smoke.gd

const MEMBER := "res://scenes/party/party_member.tscn"
const SEL := "res://scripts/run/controllers/selection_controller.gd"
const PITCH_DEG := 40.0   # camera_rig.PITCH_DEG
const DIST := 19.0        # camera_rig.DISTANCE_DEFAULT

var _ok := true


func _initialize() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	var p := deg_to_rad(PITCH_DEG)
	cam.position = Vector3(0.0, DIST * sin(p), DIST * cos(p))
	cam.rotation = Vector3(-p, 0.0, 0.0)
	cam.current = true

	var m = load(MEMBER).instantiate()
	root.add_child(m)
	await process_frame
	m.global_position = Vector3.ZERO
	await process_frame

	var sel = load(SEL).new()
	root.add_child(sel)
	var gate: float = sel.SELECT_COVER_MIN

	var body: Rect2 = sel._screen_rect_of(cam, m)
	_chk("화면 사각형이 유효(투영 성공)", body.size.x > 0.0 and body.size.y > 0.0)
	if body.size.y <= 0.0:
		_done()
		return

	# 원점이 사각형 바닥 쪽에 있어야 "발치만 걸쳐도 선택되던" 옛 실패가 성립한다.
	var origin := cam.unproject_position(m.global_position)
	var origin_pct := (origin.y - body.position.y) / body.size.y * 100.0
	_chk("원점(발밑)이 사각형 하단부 (%.0f%% ≥ 70%%)" % origin_pct, origin_pct >= 70.0)

	# ① 발치만 덮는 박스 — 예전엔 선택, 이제는 탈락.
	var feet := Rect2(body.position + Vector2(0.0, body.size.y * 0.60),
			Vector2(body.size.x, body.size.y * 0.40))
	_chk("발치 박스가 원점을 포함(옛 규칙이면 선택됐음 = 회귀 의미 확인)", feet.has_point(origin))
	_chk("발치 박스 탈락 (%.2f < %.2f)" % [_ratio(feet, body), gate], _ratio(feet, body) < gate)

	# ② 제대로 감싼 박스 — 통과.
	var good := Rect2(body.position, Vector2(body.size.x, body.size.y * 0.85))
	_chk("85%% 박스 통과 (%.2f ≥ %.2f)" % [_ratio(good, body), gate], _ratio(good, body) >= gate)

	# ③ 임계 바로 아래 — 탈락(게이트가 실제로 값을 보고 있는지).
	var edge := Rect2(body.position, Vector2(body.size.x, body.size.y * (gate - 0.05)))
	_chk("임계-5%p 박스 탈락", _ratio(edge, body) < gate)

	_done()


func _ratio(box: Rect2, body: Rect2) -> float:
	if body.size.x <= 0.0 or body.size.y <= 0.0:
		return 0.0
	var c := box.intersection(body)
	return (c.size.x * c.size.y) / (body.size.x * body.size.y)


func _chk(label: String, cond: bool) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_ok = false


func _done() -> void:
	print("SELECTION SMOKE " + ("PASSED" if _ok else "FAILED"))
	quit(0 if _ok else 1)
