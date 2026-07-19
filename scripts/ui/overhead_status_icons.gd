extends Node3D
class_name OverheadStatusIcons
## 유닛 머리 위 "디버프 아이콘 로우" — 각 디버프를 **색 코인**으로 나란히, 시계방향 회색 부채꼴
## (status_icon.gdshader)로 잔여시간을 표시. enemy_unit/party_member가 get_status_list(디버프만)로 매 틱 sync.
## 카메라 정면 평면 빌보드(루트 basis만 카메라에 맞춰 자식 타일이 화면 가로로 정렬).
##
## **글자 없음(DRIFT-089):** 예전엔 코인 위에 한글 심볼 1자를 얹었는데, Label3D가 `fixed_size`(화면상 고정
## 크기)라 **카메라가 멀어지면 코인은 작아지는데 글자는 그대로**여서 원이 안 보이고 글자만 남았다. 체력바
## 위 요소는 **직관성(색·부채꼴) 우선** → 글자를 제거하고, 대신 **마우스 호버 시 이름+효과 팝업**을 띄운다.
## 호버 판정·팝업을 이 노드가 자체 처리하므로 씬별 배선이 없다(던전/샌드박스 자동 동일 — 입력 파리티).
##
## 스택은 코인 개수가 아니라 팝업의 "N중첩"으로 읽는다(예전엔 심볼 뒤 숫자).

const _Shader := preload("res://scripts/ui/status_icon.gdshader")
const _RichTooltip := preload("res://scripts/ui/rich_tooltip.gd")
const TILE := 0.30      # 코인 지름(m)
const GAP := 0.05       # 타일 간격(m)
const HOVER_PAD_PX := 4.0   # 호버 판정 여유(작은 코인도 집기 쉽게)

## 표시명 → 효과 한 줄(호버 팝업). 키는 **표시명**(KO) — 상태 원본 id가 없는 레거시 타이머 항목
## (기절/둔화/도발 등)도 같은 경로로 읽히게 하려는 의도. 없으면 이름만 표시.
const DESC := {
	"점화": "불에 타는 중 — 시간에 걸쳐 화염 피해를 입는다.",
	"화염": "불길 위에 서 있다 — 벗어나지 않으면 점화가 계속 갱신된다.",
	"중독": "독에 중독됨 — 시간에 걸쳐 피해를 입는다. 중첩될수록 강해진다.",
	"감전": "감전 — 이동이 크게 느려진다.",
	"냉각": "냉기 — 이동이 느려진다.",
	"침수": "젖음 — 이동이 느려지고 전격에 전도된다.",
	"증기": "증기 — 시야가 흐려지고 이동이 약간 느려진다.",
	"빙판": "미끄러운 바닥 — 방향 전환이 미끄러진다.",
	"돌풍": "돌풍에 밀림.",
	"기절": "기절 — 행동 불가. 시전 중이었다면 취소된다.",
	"둔화": "둔화 — 이동 속도가 감소한다.",
	"취약": "취약 — 받는 피해가 증가한다.",
	"속박": "속박 — 이동할 수 없다(행동은 가능).",
	"고정": "고정 — 잠시 제자리에 묶인다.",
	"포박": "포박 — 사슬로 연결되어 멀어질 수 없다.",
	"혈향": "혈향 — 추적 표식이 남아 적에게 위치가 드러난다.",
	"침묵": "침묵 — 액티브 스킬을 쓸 수 없다.",
	"도발": "도발 — 대상을 강제로 공격하게 된다.",
	"광폭": "광폭 — 공격이 빨라지고 강해진다.",
}

# 공용 호버 팝업 — 유닛마다 만들지 않고 화면 최상위 CanvasLayer 하나를 지연 생성해 돌려 쓴다.
static var _tip_layer: CanvasLayer = null
static var _tip_box: Control = null
static var _tip_owner: Node = null   # 현재 팝업을 점유한 아이콘 노드(다른 유닛이 뺏어가도 일관되게)

var _tiles: Array = []   # [{root:Node3D, mat:ShaderMaterial, data:Dictionary}]
var _cam: Camera3D = null
var _hover: int = -1


func _process(_dt: float) -> void:
	# 평면 빌보드 — 루트 basis를 카메라 basis에 맞춰 자식 로우가 화면 가로로 정렬되게(origin 보존).
	if _cam == null or not is_instance_valid(_cam):
		_cam = get_viewport().get_camera_3d()
	if _cam == null:
		return
	var b := _cam.global_transform.basis
	var xf := global_transform
	xf.basis = Basis(b.x, b.y, b.z)
	global_transform = xf
	_update_hover()


## 마우스가 어느 코인 위인지 — 코인 중심과 가장자리를 각각 화면에 투영해 **화면상 반지름**을 구한다
## (줌/거리 무관). 뒤에 있는 타일은 제외. 히트가 바뀔 때만 팝업을 갱신한다.
func _update_hover() -> void:
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var hit := -1
	for i in range(_tiles.size()):
		var root: Node3D = _tiles[i]["root"]
		if not root.visible or _cam.is_position_behind(root.global_position):
			continue
		var c: Vector2 = _cam.unproject_position(root.global_position)
		var edge: Vector2 = _cam.unproject_position(
				root.global_position + _cam.global_transform.basis.x * (TILE * 0.5))
		if mouse.distance_to(c) <= maxf(c.distance_to(edge), 1.0) + HOVER_PAD_PX:
			hit = i
			break
	if hit == _hover and (hit < 0 or _tip_owner == self):
		if hit >= 0:
			_place_tip(mouse)
		return
	_hover = hit
	if hit < 0:
		if _tip_owner == self:
			_hide_tip()
		return
	_show_tip(_tiles[hit].get("data", {}), mouse)


func _show_tip(s: Dictionary, at: Vector2) -> void:
	var nm := String(s.get("name", "?"))
	var st := int(s.get("stacks", 0))
	var title := "[b]%s[/b]" % nm
	if st > 1:
		title += "  [color=#%s]%d중첩[/color]" % [_RichTooltip.ACCENT, st]
	var body := String(DESC.get(nm, ""))
	var txt := title if body == "" else "%s\n[color=#%s]%s[/color]" % [title, _RichTooltip.DIM, body]
	if _tip_layer == null or not is_instance_valid(_tip_layer):
		_tip_layer = CanvasLayer.new()
		_tip_layer.layer = 128          # 다른 HUD 위
		get_tree().root.add_child(_tip_layer)
	if _tip_box != null and is_instance_valid(_tip_box):
		_tip_box.queue_free()
	_tip_box = _RichTooltip.make(txt)
	_tip_layer.add_child(_tip_box)
	_tip_owner = self
	_place_tip(at)


## 팝업을 커서 오른쪽 아래에 두되, 화면 밖으로 나가면 반대편으로 접는다.
func _place_tip(at: Vector2) -> void:
	if _tip_box == null or not is_instance_valid(_tip_box):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var sz: Vector2 = _tip_box.get_combined_minimum_size()
	var p := at + Vector2(16, 14)
	if p.x + sz.x > vp.x:
		p.x = at.x - sz.x - 16
	if p.y + sz.y > vp.y:
		p.y = at.y - sz.y - 14
	_tip_box.position = p


func _hide_tip() -> void:
	if _tip_box != null and is_instance_valid(_tip_box):
		_tip_box.queue_free()
	_tip_box = null
	_tip_owner = null


## 유닛이 죽거나 씬이 바뀔 때 팝업이 남지 않게.
func _exit_tree() -> void:
	if _tip_owner == self:
		_hide_tip()


func _make_tile() -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var mesh := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(TILE, TILE)
	mesh.mesh = qm
	var mat := ShaderMaterial.new()
	mat.shader = _Shader
	mesh.material_override = mat
	root.add_child(mesh)
	return {"root": root, "mat": mat, "data": {}}


## list: [{name:String, color:Color, ratio:float, stacks:int}] — 디버프만(호출측이 버프 필터).
func sync(list: Array) -> void:
	while _tiles.size() < list.size():
		_tiles.append(_make_tile())
	var n := list.size()
	var total := float(n) * TILE + maxf(0.0, float(n - 1)) * GAP
	for i in range(_tiles.size()):
		var t: Dictionary = _tiles[i]
		var root: Node3D = t["root"]
		if i < n:
			var s: Dictionary = list[i]
			root.visible = true
			root.position = Vector3(-total * 0.5 + TILE * 0.5 + float(i) * (TILE + GAP), 0.0, 0.0)
			var mat: ShaderMaterial = t["mat"]
			mat.set_shader_parameter("color", s.get("color", Color.WHITE))
			mat.set_shader_parameter("progress", clampf(float(s.get("ratio", 0.0)), 0.0, 1.0))
			t["data"] = s          # 호버 팝업이 읽는다(이름·스택)
		else:
			root.visible = false
			if _hover == i:        # 사라진 타일을 물고 있었으면 팝업 해제
				_hover = -1
				if _tip_owner == self:
					_hide_tip()
