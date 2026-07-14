extends Label3D
class_name FloatText
## MMO식 floating combat text — 버프/디버프가 걸릴 때 대상 위에 잠깐 떴다가 위로 떠오르며 페이드아웃 후
## 자기 소멸. 동시에 여러 개가 나와도 각자 위로 떠오르고 x가 살짝 흩어져 구분된다. 대상(parent)의 자식이라
## 대상을 따라다닌다. 화면 고정 크기(fixed_size)라 줌과 무관하게 가독.

const DUR := 1.2           # 총 수명(초)
const RISE := 1.0          # 총 상승 높이(월드 단위)
const FADE_START := 0.45   # 이 수명 비율을 지나면 페이드 시작

## 원소 OUTCOME id → 유저 표시명(팝업용). STATUS-OUTCOME-CORE.
const OUTCOME_KO := {
	"Sodden": "침수", "Chilled": "냉각", "SteamHaze": "증기", "Slippery": "빙판",
	"Shock": "감전", "Ignited": "점화", "WindBuffeted": "돌풍", "Vulnerable": "취약",
	"Rooted": "속박", "Pinned": "고정", "Scented": "혈향",
}

var _t := 0.0
var _x_off := 0.0   # 화면(카메라) 우측 오프셋(m) — 매 프레임 카메라 오른쪽을 부모 로컬로 환산해 적용

## `parent` 위 `base_y` 높이에 텍스트를 띄운다. x를 살짝 흩어 동시 다발 효과를 구분.
## x_off: 중앙(체력바·상태 아이콘)을 피해 옆으로 미는 오프셋 — 데미지 수치는 오른쪽으로 빗겨 상단 UI에 안 가리게.
static func popup(parent: Node3D, txt: String, color: Color, base_y: float, x_off: float = 0.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var ft := FloatText.new()
	ft.text = txt
	ft.modulate = color
	ft._x_off = x_off + randf_range(-0.2, 0.2)
	ft.position = Vector3(0.0, base_y, 0.0)   # x/z는 _process가 카메라(화면) 우측으로 세팅
	parent.add_child(ft)


func _ready() -> void:
	font_size = 48            # 수치 가독성 — 화면상 크게(fixed_size라 줌 무관)
	fixed_size = true           # 카메라 거리와 무관하게 화면상 일정 크기
	pixel_size = 0.0005
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	outline_size = 10           # 배경 대비 가독성(검은 테두리)
	outline_modulate = Color(0.0, 0.0, 0.0, 0.75)


func _process(delta: float) -> void:
	_t += delta
	if _t >= DUR:
		queue_free()
		return
	var f := _t / DUR
	# 화면(카메라) 우측 오프셋 — 카메라 월드 오른쪽(수평)을 부모 로컬로 환산 → 적/카메라 회전 무관하게 항상 화면 우측.
	var par := get_parent()
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if par is Node3D and cam != null:
		var cr: Vector3 = cam.global_transform.basis.x
		cr.y = 0.0
		if cr.length() > 0.001:
			var lo: Vector3 = (par as Node3D).global_transform.basis.inverse() * (cr.normalized() * _x_off)
			position.x = lo.x
			position.z = lo.z
	position.y += RISE * delta / DUR                       # 위로 상승
	if f > FADE_START:                                     # 후반부 페이드아웃
		var a := 1.0 - (f - FADE_START) / (1.0 - FADE_START)
		modulate.a = a
		outline_modulate.a = a * 0.75
