extends "res://scripts/world/map_source.gd"
## **AuthoredMapSource — 손으로 지은 맵(Blender glTF / Godot 씬)의 MapSource 구현.**
##
## `map_demo_layout`(절차 그레이박스)의 자매 구현이다. 같은 계약(`map_source.gd`)을 만족하므로
## **호출부는 하나도 바뀌지 않는다** — 런·전투·파티·안개·미니맵은 어느 쪽인지 모른다.
##
## 소유권이 뒤집힌다는 점이 핵심이다:
##   - 절차: 데이터가 좌표를 갖는다(`rooms.json` `geometry`/`anchors`) → 코드가 박스를 만든다.
##   - authored: **씬이 좌표를 갖는다**(`TRIG_room`·`MK_*` 마커) → 데이터에는 종류·개수·ref만 남는다.
## 그래서 아티스트가 에디터에서 기둥을 30 cm 옮겨도 **데이터는 한 글자도 안 바뀐다**.
##
## 쓰는 법: 임포트한 씬(또는 그 인스턴스)을 자식으로 두고 이 스크립트를 부모에 붙인다.
## 규약은 `map_convention.gd`가 소유하고, 임포트 후처리(`tools/import_post.gd`)가 같은 파서로
## Empty → Area3D/Marker3D 변환 + 규약 검증을 한다.
##
## ⚠️ **아직 실제 `.glb`로 통과시켜 본 적이 없다.** 검증된 것은 `tools/map_smoke.gd`가 만드는
## **합성 authored 씬**까지다(계약 getter·앵커·오클루더·트리거). 실제 임포트에서 처음 만날 것으로
## 예상되는 차이는 `tools/import_post.gd` 머리에 적어 뒀다.
## ref: docs/design/map_upgrade_plan.html §Phase 0

const MapConvention := preload("res://scripts/world/map_convention.gd")

## 씬 루트(임포트된 맵). 비우면 이 노드의 첫 자식을 쓴다.
@export var authored_root_path: NodePath

var _root: Node3D


func _ready() -> void:
	add_to_group(NAVMAP_GROUP)
	_root = _find_root()
	if _root == null:
		push_error("[MAP] AuthoredMapSource: 씬 루트를 못 찾았다(authored_root_path)")
		return
	_root.add_to_group(GEOMETRY_GROUP)
	build_from_scene(_root)
	derive_occluders()
	bake_navigation()


func geometry_root() -> Node3D:
	return _root if _root != null else self


## 씬 → 계약 상태(`_room_points` · `_extraction_point` · `_anchors`) + 방 트리거 배선.
## `_ready` 밖에서도 부를 수 있게 분리했다 — 스모크가 합성 씬으로 이걸 직접 시험한다.
func build_from_scene(root: Node3D) -> void:
	_root = root
	_room_points.clear()
	_anchors.clear()
	var room_refs := _known_room_refs()
	for child in root.get_children():
		if not (child is Node3D) or not MapConvention.is_room_node(String(child.name), room_refs):
			continue
		_ingest_room(child as Node3D)


## 이 맵이 다루는 방 목록(rooms.json). 오타 난 방 이름이 조용히 새 방이 되는 걸 막는다.
func _known_room_refs() -> Array:
	var out: Array = []
	for row in _rooms_doc().get("rooms", []):
		if typeof(row) == TYPE_DICTIONARY:
			out.append(String((row as Dictionary).get("room_ref", "")))
	return out


func _ingest_room(room: Node3D) -> void:
	var ref := String(room.name)
	var spawn := room.global_position
	var size := Vector3(8, 0, 8)
	var by_kind: Dictionary = {}

	for c in room.get_children():
		var n := String(c.name)
		if n == MapConvention.TRIGGER_NAME and c is Area3D:
			size = _trigger_size(c as Area3D)
			spawn = (c as Area3D).global_position       # 트리거 중심 = 방 중심
			_wire_trigger(c as Area3D, ref)
			continue
		if not (c is Node3D):
			continue
		var m := MapConvention.parse_marker(n)
		if m.is_empty():
			continue
		var kind := String(m["kind"])
		if kind == "spawn":
			spawn = (c as Node3D).global_position
			continue
		var e: Dictionary = {"pos": (c as Node3D).global_position}
		if not String(m["ref"]).is_empty():
			# 킷 타입(obstacles)은 `type`, 그 외는 스펙 ID(`ref`)로 싣는다 — rooms.json과 같은 모양.
			e["type" if kind == "obstacles" else "ref"] = String(m["ref"])
		if not String(m["role"]).is_empty():
			e["role"] = String(m["role"])
		if int(m["index"]) > 0:
			e["index"] = int(m["index"])
		if not by_kind.has(kind):
			by_kind[kind] = []
		(by_kind[kind] as Array).append(e)

	# 방 기준점은 `MK_spawn` > 트리거 중심 > 노드 위치 순. y는 그대로 나른다(단차 대비).
	_room_points[ref] = {"spawn": spawn, "size": size}
	if not by_kind.is_empty():
		_anchors[ref] = by_kind
	# 추출 지점: rooms.json이 이 방을 추출 방으로 지정했으면 그 방의 기준점을 쓴다.
	var row: Dictionary = _room_row(ref)
	if not String(row.get("extraction_point_id", "")).is_empty():
		_extraction_point = spawn


func _trigger_size(area: Area3D) -> Vector3:
	for c in area.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
			var bs := ((c as CollisionShape3D).shape as BoxShape3D).size
			var sc: Vector3 = area.global_transform.basis.get_scale()
			return Vector3(bs.x * sc.x, 0.0, bs.z * sc.z)
	return Vector3(8, 0, 8)


func _wire_trigger(area: Area3D, room_ref: String) -> void:
	area.monitoring = true
	area.monitorable = false
	area.collision_layer = 0
	area.collision_mask = 2                     # 파티 레이어
	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered.bind(room_ref))


func _find_root() -> Node3D:
	if not authored_root_path.is_empty():
		var n := get_node_or_null(authored_root_path)
		if n is Node3D:
			return n as Node3D
	for c in get_children():
		if c is Node3D:
			return c as Node3D
	return null
