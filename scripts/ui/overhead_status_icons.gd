extends Node3D
class_name OverheadStatusIcons
## 유닛 머리 위 "디버프 아이콘 로우" — 각 디버프를 색 코인+한글 심볼 타일로 나란히,
## 시계방향 회색 부채꼴(status_icon.gdshader)로 잔여시간을 표시. 독 등 스택형은 심볼에 스택 수를 붙인다(예 "독5").
## enemy_unit이 get_status_list(디버프만)로 매 틱 sync. 카메라 정면 평면 빌보드(루트 basis만 카메라에 맞춰
## 자식 타일이 화면 가로로 정렬). class_name 있으나 preload const 참조 권장(FloatText/OverheadBadges와 동일 패턴).

const _Shader := preload("res://scripts/ui/status_icon.gdshader")
const TILE := 0.30      # 코인 지름(m)
const GAP := 0.05       # 타일 간격(m)

# 디버프 표시명 → 심볼 1자(첫 글자 충돌 회피: 침묵→묵 / 침수→수). 없으면 이름 첫 글자.
const SYM := {
	"중독": "독", "점화": "화", "감전": "전", "냉각": "냉", "침묵": "묵", "침수": "수",
	"둔화": "둔", "기절": "기", "취약": "취", "속박": "속", "빙판": "빙", "증기": "증",
	"돌풍": "풍", "고정": "정", "포박": "포", "혈향": "향",
}

var _tiles: Array = []   # [{root:Node3D, mat:ShaderMaterial, label:Label3D}]
var _cam: Camera3D = null


func _process(_dt: float) -> void:
	# 평면 빌보드 — 루트 basis를 카메라 basis에 맞춰 자식 로우가 화면 가로로 정렬되게(origin 보존).
	if _cam == null or not is_instance_valid(_cam):
		_cam = get_viewport().get_camera_3d()
	if _cam != null:
		var b := _cam.global_transform.basis
		var xf := global_transform
		xf.basis = Basis(b.x, b.y, b.z)
		global_transform = xf


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
	var label := Label3D.new()
	label.font_size = 30
	label.fixed_size = true
	label.pixel_size = 0.0005
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED   # 루트가 이미 카메라 정면
	label.no_depth_test = true
	label.outline_size = 6
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	label.position = Vector3(0.0, 0.0, 0.01)              # 코인 앞(뷰어 쪽)
	root.add_child(label)
	return {"root": root, "mat": mat, "label": label}


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
			var nm := String(s.get("name", "?"))
			var sym: String = SYM.get(nm, nm.substr(0, 1) if nm.length() > 0 else "?")
			var st := int(s.get("stacks", 0))
			(t["label"] as Label3D).text = (sym + str(st)) if st > 1 else sym
		else:
			root.visible = false
