extends RefCounted
## **authored 맵 저작 규약 — 노드 이름이 계약이다.**
##
## Blender에서 지은 맵을 Godot으로 가져오면 남는 것은 **메시와 이름**뿐이다. Area3D·Marker3D 같은
## 런타임 노드는 glTF에 담기지 않는다. 그래서 「무엇이 방이고 무엇이 앵커인가」를 **이름 규약**으로
## 정하고, 임포트 후처리(`tools/import_post.gd`)와 런타임(`authored_map_source.gd`)이 같은 파서를
## 쓴다. 규약이 두 벌이 되면 그 순간 다시 어긋난다.
##
## ```
## RM-HALL-01/                    <- 방 루트 (이름 = room_ref)
##   GEO_walls-col                <- 아트 메시 + 콜리전(layer 1)
##   OCC_pillar_a-colonly         <- LOS 프록시(아트와 분리)
##   TRIG_room                    <- 방 트리거 (Area3D / BoxShape3D)
##   MK_spawn                     <- 방 기준점
##   MK_enc_1 / MK_enc_2          <- 인카운터 앵커(AmbushHold 2앵커 = 2개)
##   MK_loot_1..n                 <- 루팅 앵커
##   MK_int_CHEST-DEMO-01         <- 상호작용 (ref = 스펙 ID)
##   MK_int__ally_cache           <- 상호작용 (role = 스펙 ID가 없는 것)
##   MK_haz_trap_split_lever__plate <- 해저드 (ref__role)
##   MK_obs_pillar                <- 장애물(킷 타입)
##   MK_prop_ENT-TORCH-001        <- 소품
## ```
##
## `ref`와 `role`을 나눠 쓰는 이유: **ID 계약**(미등록 ID → 로드 abort) 때문에 스펙에 있는 것만
## `ref`로 쓰고, 없는 것(아군 유물함·레버)은 `role`로 둔다. 새 ID를 발명하지 않는다.
##
## ref: docs/design/map_upgrade_plan.html §Blender 저작 규약 · rooms.json `anchors`

const ROOM_PREFIX := "RM-"
const TRIGGER_NAME := "TRIG_room"
const MARKER_PREFIX := "MK_"
## role 구분자. `@`는 Godot 노드 이름에서 잘린다 — 아래 parse_marker 주석 참조.
const ROLE_SEP := "__"
const GEOMETRY_PREFIX := "GEO_"
const OCCLUDER_PREFIX := "OCC_"

## `MK_<슬러그>` 슬러그 → 앵커 kind(rooms.json `anchors`의 키와 같은 말). 나머지는 무시한다.
const MARKER_KINDS := {
	"spawn": "spawn",
	"enc": "encounters",
	"loot": "loot",
	"int": "interactions",
	"haz": "hazards",
	"obs": "obstacles",
	"prop": "props",
	"trans": "transitions",
}


## 이 노드가 방 루트인가. `room_refs`를 주면 **rooms.json에 실재하는 방인지**까지 본다
## (오타 난 `RM-HAL-01`이 조용히 새 방이 되는 걸 막는다).
static func is_room_node(name: String, room_refs: Array = []) -> bool:
	if not name.begins_with(ROOM_PREFIX):
		return false
	return room_refs.is_empty() or room_refs.has(name)


## 마커 이름 → {kind, ref, role, index}. 규약에 안 맞으면 빈 사전.
## 형태: `MK_<슬러그>[_<ref>][__<role>]`
##
## ⚠️ role 구분자가 `__`인 이유: **Godot 노드 이름은 `. : @ / " %` 를 못 쓴다** — 넣으면 노드 생성
## 시점에 조용히 잘려 나간다(문자열 파서는 통과하는데 실제 씬에서만 깨지는, 제일 나쁜 종류다.
## 실제로 `@`로 설계했다가 스모크가 잡았다). 스펙 ID에는 `__`가 없으므로 모호하지 않다.
## 게이트: tools/map_smoke.gd 「구분자가 Godot 노드 이름 정화를 견딘다」.
static func parse_marker(name: String) -> Dictionary:
	if not name.begins_with(MARKER_PREFIX):
		return {}
	var body := name.substr(MARKER_PREFIX.length())
	# Godot은 같은 이름이 겹치면 `MK_loot_1@2` 같은 접미사를 붙이지 않지만, Blender 쪽에서
	# `.001` 사본이 흔하다 — 그건 이름의 일부가 아니므로 떼어 낸다.
	var dot := body.find(".")
	if dot > 0:
		body = body.substr(0, dot)
	var role := ""
	var at := body.find(ROLE_SEP)
	if at >= 0:
		role = body.substr(at + ROLE_SEP.length())
		body = body.substr(0, at)
	var slug := body
	var rest := ""
	var us := body.find("_")
	if us > 0:
		slug = body.substr(0, us)
		rest = body.substr(us + 1)
	if not MARKER_KINDS.has(slug):
		return {}
	var out := {"kind": String(MARKER_KINDS[slug]), "ref": "", "role": role, "index": 0}
	# `MK_enc_1` 처럼 숫자면 index, 그 외에는 ref(스펙 ID) 또는 킷 타입.
	if rest.is_valid_int():
		out["index"] = int(rest)
	elif not rest.is_empty():
		out["ref"] = rest
	return out


## 콜리전/오클루더 프록시 판별 — 아트 메시(`GEO_`)와 프록시(`OCC_`)를 이름으로 가른다.
## 오클루더 **유도**는 콜라이더에서 하므로(map_source) 이 판별은 저작 검증용이다:
## 「LOS를 막아야 하는데 프록시가 없는 벽」을 임포트 시점에 잡는다.
static func is_geometry(name: String) -> bool:
	return name.begins_with(GEOMETRY_PREFIX)


static func is_occluder_proxy(name: String) -> bool:
	return name.begins_with(OCCLUDER_PREFIX)


## 방 노드 아래에서 규약 위반을 모아 돌려준다(빈 배열 = 통과).
## 임포트 후처리와 스모크가 같은 함수를 쓴다 — 규약 검사가 두 벌이 되지 않게.
static func validate_room(room: Node) -> Array:
	var problems: Array = []
	var has_trigger := false
	var has_spawn := false
	var unknown: Array = []
	for c in room.get_children():
		var n := String(c.name)
		if n == TRIGGER_NAME:
			has_trigger = true
		elif n.begins_with(MARKER_PREFIX):
			if parse_marker(n).is_empty():
				unknown.append(n)
			elif String(parse_marker(n).get("kind", "")) == "spawn":
				has_spawn = true
	if not has_trigger:
		problems.append("%s: %s 없음(방 트리거)" % [room.name, TRIGGER_NAME])
	if not has_spawn:
		problems.append("%s: MK_spawn 없음(방 기준점)" % room.name)
	for u in unknown:
		problems.append("%s: 규약에 없는 마커 이름 `%s`" % [room.name, u])
	return problems
