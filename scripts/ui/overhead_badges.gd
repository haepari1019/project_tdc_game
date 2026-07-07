extends Node3D
class_name OverheadBadges
## 유닛 머리 위 "스택 배지 스트립" — 여러 스택형 상태(방벽/표식/집중/…)를 한 유닛에 모아 표시.
## 각 상태가 개별 Label3D를 만들지 않고 이 스트립에 badge로 등록 → **가로 한 줄**로 모여서 여러 개가 동시에
## 떠도 세로로 나열되지 않아 읽기 쉽다. 단일 Label3D(조인 문자열)라 줌과 무관하게 간격이 일정하다.
## 참조: 결속 시각화 개선(누커 게이트 피드백 — 「집중/방벽 등 동시 발현 시 라벨 나열 가독성」).
##
## class_name은 있지만 신규 파일 global-class 캐시 미갱신 대비 **preload const로 참조**할 것(FloatText와 동일 패턴).
## 사용: `const _OB := preload(".../overhead_badges.gd")` → `var strip = _OB.new(); add_child(strip)` → set_badge/clear_badge.

## 표시 정렬 순서(왼→오). 목록에 없는 key는 뒤에 붙는다. 새 결속 상태는 여기에 추가.
const PRIORITY := ["veil", "mark", "bulwark", "focus", "sunder", "ward", "chain", "vulnerable"]

var _badges := {}   # key -> String (짧게: 아이콘+숫자, 예 "🎯5" "🛡◆◆◇" "◈")
var _accent := {}   # key -> bool (강조 상태면 스트립 전체를 금색으로 — 예: 집중 MAX)
var _label: Label3D = null


func _ensure() -> void:
	if _label != null:
		return
	_label = Label3D.new()
	_label.font_size = 36
	_label.fixed_size = true          # 카메라 거리와 무관하게 화면상 일정 크기
	_label.pixel_size = 0.0005
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.outline_size = 8           # 배경 대비 가독(검은 테두리)
	_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.75)
	add_child(_label)


## 상태 배지 등록/갱신. text는 짧게(아이콘+숫자). accent=true면 스트립을 금색으로(준비/캡 강조).
func set_badge(key: String, text: String, accent: bool = false) -> void:
	_ensure()
	_badges[key] = text
	_accent[key] = accent
	_render()


func clear_badge(key: String) -> void:
	if _badges.erase(key):
		_accent.erase(key)
		_render()


func clear_all() -> void:
	_badges.clear()
	_accent.clear()
	_render()


func _render() -> void:
	if _label == null:
		return
	var parts := PackedStringArray()
	var hot := false
	for k in PRIORITY:                 # 우선순위 순서 먼저
		if _badges.has(k):
			parts.append(String(_badges[k]))
			if bool(_accent.get(k, false)):
				hot = true
	for k in _badges.keys():           # 목록에 없는 key는 뒤에
		if not PRIORITY.has(k):
			parts.append(String(_badges[k]))
	_label.text = "  ".join(parts)
	_label.visible = not parts.is_empty()
	_label.modulate = Color(1.0, 0.82, 0.3) if hot else Color(1.0, 1.0, 1.0)
