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

## `parent` 위 `base_y` 높이에 텍스트를 띄운다. x를 살짝 흩어 동시 다발 효과를 구분.
static func popup(parent: Node3D, txt: String, color: Color, base_y: float) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var ft := FloatText.new()
	ft.text = txt
	ft.modulate = color
	ft.position = Vector3(randf_range(-0.4, 0.4), base_y, 0.0)
	parent.add_child(ft)


func _ready() -> void:
	font_size = 30
	fixed_size = true           # 카메라 거리와 무관하게 화면상 일정 크기
	pixel_size = 0.0005
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	outline_size = 8            # 배경 대비 가독성(검은 테두리)
	outline_modulate = Color(0.0, 0.0, 0.0, 0.75)


func _process(delta: float) -> void:
	_t += delta
	if _t >= DUR:
		queue_free()
		return
	var f := _t / DUR
	position.y += RISE * delta / DUR                       # 위로 상승
	if f > FADE_START:                                     # 후반부 페이드아웃
		var a := 1.0 - (f - FADE_START) / (1.0 - FADE_START)
		modulate.a = a
		outline_modulate.a = a * 0.75
