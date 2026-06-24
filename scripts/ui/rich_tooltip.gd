extends Panel
## 색을 쓸 수 있는 커스텀 툴팁 — Godot의 기본 `tooltip_text`는 평문이라 폰트색이 안 된다.
## 이 Panel 서브클래스를 쓰는 컨트롤은 `tooltip_text`에 BBCode를 넣으면 색이 적용된다(affix 등 강조).
## static `make()`는 BBCode 문자열 → 다크 패널+RichTextLabel 툴팁 노드. 다른 컨트롤(RadialCooldown)도 재사용.

## 공용 색 (다크 배경 가독) — 긍정(버프/보너스) 초록 · 부정(패널티/트레이드) 빨강 · affix 강조(특별) 금색.
const POS := "8be58b"
const NEG := "ff8a6a"
const ACCENT := "ffcf6b"
const DIM := "9aa4b2"


static func make(for_text: String) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.10, 0.97)
	sb.border_color = Color(0.30, 0.33, 0.42)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	pc.add_theme_stylebox_override("panel", sb)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.custom_minimum_size = Vector2(300, 0)
	rt.text = for_text
	pc.add_child(rt)
	return pc


func _make_custom_tooltip(for_text: String) -> Object:
	return make(for_text)
