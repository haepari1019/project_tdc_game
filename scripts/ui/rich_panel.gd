extends PanelContainer
class_name RichPanel
## **BBCode 툴팁을 갖는 `PanelContainer`** — `RichTooltip`(`Panel`)의 컨테이너판.
##
## 왜 필요했나: `RichTooltip`은 `Panel`이라 **컨테이너가 아니다**. 자식을 배치하지도, 자식에 맞춰
## 커지지도 않는다. 마을 건물·파티 카드를 그걸로 만들었더니 ① 내용 여백이 없어 글자가 모서리에
## 붙고 ② `custom_minimum_size`의 높이를 0으로 두는 순간 **배경이 0px가 돼 화면이 통째로 비었다**.
##
## 여기는 `PanelContainer`라 자식을 배치하고 내용에 맞춰 커지며, 테마 `content_margin`이 여백이 된다.
## 툴팁 렌더는 `RichTooltip.make()`를 그대로 재사용한다 — 툴팁 모양은 한 곳에서만 정의된다.

const RichTooltip := preload("res://scripts/ui/rich_tooltip.gd")


func _make_custom_tooltip(for_text: String) -> Object:
	return RichTooltip.make(for_text)
