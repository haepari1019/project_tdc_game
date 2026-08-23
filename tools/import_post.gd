@tool
extends EditorScenePostImport
## **임포트 후처리 — 이름 규약을 런타임 노드로 바꾸고, 위반을 임포트 시점에 세운다.**
##
## glTF/.blend에는 Area3D·Marker3D가 담기지 않는다. Blender에서 놓은 Empty는 그냥 `Node3D`로
## 들어온다. 그래서 `map_convention.gd`의 이름 규약대로:
##   `TRIG_room` (Empty/Cube) → **Area3D + BoxShape3D** (방 트리거)
##   `MK_*`      (Empty)      → **Marker3D**            (앵커)
## 로 바꾸고, 방마다 `validate_room()`을 돌려 **임포트가 실패하게** 한다 — 규약 위반을 런타임까지
## 끌고 가면 「왜 열쇠 상자가 원점에 있지」로 발견된다.
##
## 쓰는 법: 임포트할 `.glb`/`.blend`의 Import 독 → **Import Script**에 이 파일을 지정.
##
## ⚠️ **미검증 — 실제 `.glb`로 돌려 본 적이 없다.** 검증된 것은 `convert_tree()`(아래 static)이며
## `tools/map_smoke.gd`가 합성 트리로 매 커밋 돌린다. 실제 임포트에서 처음 만날 것으로 예상되는 차이:
##   1. **Blender Empty가 어떤 노드로 들어오는지** — 보통 `Node3D`지만 Empty 종류/내보내기 옵션에
##      따라 다를 수 있다. `convert_tree`는 「`Node3D`이고 이름이 규약에 맞으면」으로만 판정한다.
##   2. **`-col` 접미사 처리 시점** — Godot이 콜리전을 만들면서 이름에서 접미사를 떼는지 남기는지.
##      규약 파서는 `GEO_`/`OCC_` **접두사**만 보므로 어느 쪽이든 영향받지 않게 해 뒀다.
##   3. **`.001` 사본 접미사** — Blender에서 흔하다. 파서가 떼어 낸다(스모크 케이스 있음).
##   4. **스케일/단위** — Blender 1 unit = 1 m 전제. 아니면 `TRIG_room` 크기가 통째로 어긋난다.
##      `_trigger_size()`가 노드 스케일을 곱하므로 균등 스케일이면 흡수된다.
## 실제 맵이 처음 들어오는 날 이 목록부터 확인할 것.
##
## ref: docs/design/map_upgrade_plan.html §Blender 저작 규약 · scripts/world/authored_map_source.gd

const MapConvention := preload("res://scripts/world/map_convention.gd")


func _post_import(scene: Node) -> Object:
	var problems: Array = convert_tree(scene)
	for p in problems:
		push_error("[MAP IMPORT] %s" % p)
	if problems.is_empty():
		print("[MAP IMPORT] %s — 규약 통과" % scene.name)
	return scene


## **여기가 실제 로직이고, 스모크가 돌리는 곳이다.** 트리를 규약대로 변환하고 위반 목록을 돌려준다.
## `EditorScenePostImport`에 의존하지 않으므로 헤드리스에서 그대로 시험할 수 있다.
static func convert_tree(root: Node) -> Array:
	var problems: Array = []
	var rooms := 0
	for child in root.get_children():
		if not (child is Node3D) or not MapConvention.is_room_node(String(child.name)):
			continue
		rooms += 1
		_convert_room(child as Node3D, problems)
	if rooms == 0:
		problems.append("%s: `RM-*` 방 노드가 하나도 없다(방 루트 이름 = room_ref)" % root.name)
	return problems


static func _convert_room(room: Node3D, problems: Array) -> void:
	# 자식 목록을 먼저 뜬다 — 교체하면서 순회하면 빠뜨린다.
	for c in room.get_children():
		var n := String(c.name)
		if n == MapConvention.TRIGGER_NAME and not (c is Area3D):
			_replace(room, c as Node3D, _make_trigger(c as Node3D))
		elif n.begins_with(MapConvention.MARKER_PREFIX) and not (c is Marker3D):
			if MapConvention.parse_marker(n).is_empty():
				continue                      # 규약 위반은 validate_room이 보고한다(여기선 안 건드린다)
			_replace(room, c as Node3D, _make_marker(c as Node3D))
	for p in MapConvention.validate_room(room):
		problems.append(p)


## Empty(또는 박스 메시) → Area3D + BoxShape3D. 크기는 원본의 AABB에서, 없으면 노드 스케일에서.
static func _make_trigger(src: Node3D) -> Area3D:
	var area := Area3D.new()
	area.transform = src.transform
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = _extent_of(src)
	cs.shape = box
	area.add_child(cs)
	# 배선(layer/mask/signal)은 런타임이 한다 — authored_map_source._wire_trigger.
	return area


static func _make_marker(src: Node3D) -> Marker3D:
	var mk := Marker3D.new()
	mk.transform = src.transform
	return mk


## 트리거 크기 — 메시가 있으면 그 AABB, 없으면 Empty의 스케일을 크기로 읽는다(Blender에서
## Empty를 방 크기로 늘려 놓는 흔한 저작 방식). 둘 다 없으면 보수적 기본값.
static func _extent_of(n: Node3D) -> Vector3:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var a: AABB = (n as MeshInstance3D).mesh.get_aabb()
		return Vector3(a.size.x, maxf(a.size.y, 4.0), a.size.z)
	var sc: Vector3 = n.scale
	if sc.length() > 0.01 and not sc.is_equal_approx(Vector3.ONE):
		return Vector3(absf(sc.x) * 2.0, 4.0, absf(sc.z) * 2.0)
	return Vector3(8.0, 4.0, 8.0)


## 원본 노드를 새 노드로 갈아끼운다 — **이름과 자식과 위치를 그대로 물려준다**.
## 이름을 물려주지 않으면 규약이 끊긴다(런타임 파서가 같은 이름을 다시 읽는다).
static func _replace(parent: Node, src: Node3D, dst: Node3D) -> void:
	var name := String(src.name)
	var idx := src.get_index()
	for c in src.get_children():
		src.remove_child(c)
		dst.add_child(c)
		if c is Node:
			c.owner = null                    # owner는 후처리 뒤 Godot이 다시 잡는다
	parent.remove_child(src)
	src.queue_free()
	dst.name = name
	parent.add_child(dst)
	parent.move_child(dst, idx)
	dst.owner = parent.get_owner() if parent.get_owner() != null else parent
