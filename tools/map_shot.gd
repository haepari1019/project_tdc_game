extends SceneTree
## **맵 평면 스냅샷** — 맵을 띄워 직교 카메라로 위에서 찍는다. 맵 고도화의 **시각 검증 채널**.
##
## 왜 필요한가: 맵 편집은 판정 기준이 「보기에 맞다」인데, 데이터를 고치는 쪽(에이전트)은 3D
## 뷰포트를 못 본다. `map_smoke`가 기하 불변식(도달성·공유벽·navmesh)을 대신 보고, 이 도구가
## **배치·동선·개구부**를 그림으로 돌려준다. 둘이 있어야 「고쳤다 → 확인」 루프가 닫힌다.
## 판별 한계는 방 단위다 — 기둥 30 cm 이동 같은 건 여기 안 보인다(그건 에디터에서 손으로).
##
## 방향: **북(+Z) 위 · 동(+X) 왼쪽** — 인게임 미니맵과 같은 방향(플레이 화면의 180° 회전).
## 위에서 내려다보는 카메라로는 「북 위 + 동 오른쪽」이 성립하지 않는다(반사가 필요하다).
## docs/design 의 ASCII 도면은 동을 오른쪽에 그리므로 X가 서로 뒤집혀 있다 — 대조할 때 주의.
##
## 안개는 끈다(탐색 전이라 전부 검다) · HUD는 숨긴다 · 방 라벨(Label3D)은 남긴다.
## 렌더는 창이 아니라 **SubViewport**에 한다 — 창 크기·DPI에 좌우되지 않는 정확한 픽셀 크기.
##
## Run (헤드리스 아님 — 렌더가 필요하다):
##   GODOT --path . --script res://tools/map_shot.gd -- <출력경로.png>

const LONG_SIDE_PX := 1500     # 긴 축 해상도
const PAD_M := 6.0             # 맵 외곽 여백
const CAM_Y := 300.0


func _init() -> void:
	for _i in 3:
		await process_frame

	var out_path := "user://map_top.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_path = String(args[0])

	var scn = load("res://scenes/run/dungeon_run.tscn").instantiate()
	root.add_child(scn)
	for _i in 40:                  # navmesh 베이크 + 안개 셋업 + 스폰까지
		await process_frame

	var map: Node = null
	for c in scn.get_children():
		if c.has_method("get_room_rects"):
			map = c
			break
	if map == null:
		print("MAP SHOT FAILED — 맵 노드 없음")
		quit(1)
		return

	# 안개 끄기 — 스냅샷은 탐색 상태가 아니라 **구조**를 보는 그림이다.
	_walk(scn, func(n: Node) -> void:
		if n.has_method("toggle_world_fog"):
			n.call("toggle_world_fog"))
	var hud: Node = scn.get_node_or_null("HUD")
	if hud != null and hud is CanvasLayer:
		(hud as CanvasLayer).visible = false

	# 맵 바운드 → 직교 크기·이미지 비율.
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for r in map.get_room_rects():
		var c: Vector3 = r["center"]
		var s: Vector3 = r["size"]
		mn.x = minf(mn.x, c.x - s.x * 0.5); mn.y = minf(mn.y, c.z - s.z * 0.5)
		mx.x = maxf(mx.x, c.x + s.x * 0.5); mx.y = maxf(mx.y, c.z + s.z * 0.5)
	mn -= Vector2(PAD_M, PAD_M)
	mx += Vector2(PAD_M, PAD_M)
	var span := mx - mn
	var mid := (mn + mx) * 0.5

	var px: Vector2i
	if span.y >= span.x:
		px = Vector2i(maxi(64, int(round(LONG_SIDE_PX * span.x / span.y))), LONG_SIDE_PX)
	else:
		px = Vector2i(LONG_SIDE_PX, maxi(64, int(round(LONG_SIDE_PX * span.y / span.x))))

	# 평면 가독용 광원 — 던전 조명은 어둡게 튜닝돼 있어 위에서 보면 형태가 안 읽힌다.
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.6
	sun.rotation_degrees = Vector3(-70, -30, 0)
	scn.add_child(sun)

	# 같은 World3D를 공유하는 SubViewport에 렌더 → 정확히 px 크기의 이미지.
	var sv := SubViewport.new()
	sv.size = px
	sv.own_world_3d = false
	sv.world_3d = (scn as Node3D).get_world_3d()
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = span.y                      # 세로(Z 범위)가 기준 — 가로는 비율로 따라온다
	cam.near = 1.0
	cam.far = CAM_Y * 2.0
	sv.add_child(cam)
	# +Z(북)를 화면 위로. up 벡터가 시선(-Y)과 직교하므로 안전하다.
	cam.look_at_from_position(Vector3(mid.x, CAM_Y, mid.y), Vector3(mid.x, 0.0, mid.y), Vector3(0, 0, 1))
	cam.make_current()

	for _i in 8:
		await process_frame

	var img := sv.get_texture().get_image()
	var err := img.save_png(out_path)
	if err != OK:
		print("MAP SHOT FAILED — save_png %s (err %d)" % [out_path, err])
		quit(1)
		return
	print("MAP SHOT OK — %s  (%dx%d px · %.0f×%.0f m · 1px≈%.2f m · 북 위/동 왼쪽)" % [
		ProjectSettings.globalize_path(out_path) if out_path.begins_with("user://") else out_path,
		img.get_width(), img.get_height(), span.x, span.y, span.y / float(px.y)])
	quit(0)


func _walk(n: Node, fn: Callable) -> void:
	fn.call(n)
	for c in n.get_children():
		_walk(c, fn)
