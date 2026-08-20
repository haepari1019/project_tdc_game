extends RefCounted
class_name HubTheme
## **허브 UI 토큰 + 공용 `Theme`** — 색·글자크기·간격의 단일 출처.
##
## 왜 필요했나: 허브 화면 8개가 각자 `const OK/BAD/DIM/ACCENT`를 선언하고, 노드마다
## `add_theme_font_size_override`를 47번 부르고 있었다. 그래서 같은 「제목」이 화면마다 다른 크기였고,
## 같은 「경고」가 화면마다 다른 빨강이었다 — 「정리가 안 된 느낌」의 실체가 이것이다.
##
## Godot 방식대로 **타입 변주(type variation)** 로 푼다: 노드에 `theme_type_variation = "HubTitle"`만
## 걸면 크기·색이 테마에서 온다. 노드별 override는 **예외를 표시할 때만** 쓴다 — 그러면 override가
## 보이는 곳이 곧 "여기는 규칙에서 벗어난다"는 신호가 된다.

# --- 색 토큰 ------------------------------------------------------------------
## 의미로 이름 붙인다(`GREEN`이 아니라 `OK`) — 나중에 팔레트를 갈 때 의미가 남는다.
const OK := Color(0.55, 0.92, 0.60)        # 가능·완료·충족
const BAD := Color(1.0, 0.52, 0.48)        # 불가·부족·경고
const ACCENT := Color(1.0, 0.78, 0.38)     # 강조(정체성·티어 효과·재화)
const DIM := Color(0.60, 0.61, 0.66)       # 보조 정보
const TEXT := Color(0.92, 0.93, 0.95)      # 본문
const SEL := Color(0.55, 0.83, 1.0)        # 선택 중
const LINK := Color(0.66, 0.78, 1.0)       # 결속·파생 관계
const DISABLED := Color(0.42, 0.42, 0.47)  # 잠김

const BG := Color(0.075, 0.078, 0.095)     # 화면 바닥
const SURFACE := Color(0.125, 0.13, 0.155) # 창·카드 면
const SURFACE_HI := Color(0.17, 0.18, 0.21) # 선택된 면
const LINE := Color(0.26, 0.27, 0.32)      # 테두리·구분선

# --- 크기·간격 토큰 -----------------------------------------------------------
const F_TITLE := 20
const F_SECTION := 15
const F_BODY := 13
const F_META := 11
const GAP_S := 4
const GAP_M := 8
const GAP_L := 14
const PAD := 14

static var _cached: Theme = null


## 공용 테마 — 패널 루트에 한 번 붙이면 하위 전체가 상속한다.
static func get_theme() -> Theme:
	if _cached != null:
		return _cached
	var t := Theme.new()
	t.default_font_size = F_BODY
	t.set_font_size("font_size", "Label", F_BODY)
	t.set_font_size("font_size", "Button", F_BODY)
	t.set_color("font_color", "Label", TEXT)

	# 글자 크기 변주 — 노드는 `theme_type_variation`만 지정한다.
	_font_variation(t, "HubTitle", F_TITLE, TEXT)
	_font_variation(t, "HubSection", F_SECTION, ACCENT)
	_font_variation(t, "HubMeta", F_META, DIM)

	# 면 변주 — 창/카드/선택카드. 테두리 두께로 위계를 만든다(색만으로는 어두운 배경에서 안 갈린다).
	t.set_type_variation("HubWindow", "PanelContainer")
	t.set_stylebox("panel", "HubWindow", _box(SURFACE, LINE, 1, 6))
	t.set_type_variation("HubCard", "PanelContainer")
	t.set_stylebox("panel", "HubCard", _box(SURFACE, LINE, 1, 4))
	t.set_type_variation("HubCardSel", "PanelContainer")
	t.set_stylebox("panel", "HubCardSel", _box(SURFACE_HI, SEL, 2, 4))
	## 목록 행 — 면은 거의 없고 **아래 실선**만. 줄이 많을 때 카드로 만들면 화면이 벽돌이 된다.
	t.set_type_variation("HubRow", "PanelContainer")
	var row := StyleBoxFlat.new()
	row.bg_color = Color(1, 1, 1, 0.02)
	row.border_width_bottom = 1
	row.border_color = Color(1, 1, 1, 0.05)
	row.content_margin_left = 6
	row.content_margin_right = 6
	row.content_margin_top = 3
	row.content_margin_bottom = 3
	t.set_stylebox("panel", "HubRow", row)
	_cached = t
	return t


static func _font_variation(t: Theme, name: String, size: int, col: Color) -> void:
	t.set_type_variation(name, "Label")
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, col)


static func _box(bg: Color, border: Color, w: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	return sb


# --- 조립 헬퍼 ----------------------------------------------------------------

## 라벨 하나. `variation`으로 크기·기본색이 정해지고, `col`을 주면 그것만 덮는다(상태색).
## **세로 중앙 정렬이 기본**이다 — 행 안에서 글자 높이가 다르면 그것만으로 어긋나 보인다.
static func label(text: String, variation: String = "", col = null) -> Label:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if variation != "":
		l.theme_type_variation = variation
	if col != null:
		l.add_theme_color_override("font_color", col)
	return l


## 줄바꿈되는 문단(설명·규약). **`min_w`를 반드시 준다.**
##
## ⚠️ Godot에서 `autowrap`을 켜면 라벨의 **최소 폭이 0**이 된다 — 부모가 폭을 강제하지 않으면
## 「글자 한두 개마다 줄바꿈」이 일어나고, 카드는 그 좁은 폭에 맞춰 쪼그라들어 글자가 밖으로
## 흘러넘친다(실제로 그렇게 됐다). 좁은 칸(카드·타일)에서는 `line()`을, 넓은 본문에서만 `para()`를.
static func para(text: String, variation: String = "", col = null, min_w: float = 320.0) -> Label:
	var l := label(text, variation, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.custom_minimum_size.x = min_w
	return l


## **한 줄** — 넘치면 말줄임(…). 카드·타일·표 셀처럼 폭이 정해진 자리는 전부 이쪽이다.
## 잘린 전체 문장은 툴팁이 갖고 있으므로 정보가 사라지지 않는다.
static func line(text: String, variation: String = "", col = null, min_w: float = 0.0) -> Label:
	var l := label(text, variation, col)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	if min_w > 0.0:
		l.custom_minimum_size.x = min_w
	return l


## **진짜 컬럼**. `HBox + custom_minimum_size`는 컬럼이 아니라 「최소 폭 힌트」라, 한글처럼 글자 폭이
## 들쭉날쭉하면 줄마다 어긋난다. `GridContainer`는 열 폭을 **가장 넓은 셀**로 맞춰 실제로 정렬한다.
static func grid(columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 3)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return g


## 그리드에서 한 줄을 통째로 쓰는 항목(그룹 머리글 등). 나머지 칸을 빈 노드로 채워 **열 정렬을
## 깨지 않는다** — 별도 컨테이너로 빼면 그룹마다 열 폭이 달라진다.
static func span_row(g: GridContainer, node: Control) -> void:
	g.add_child(node)
	for _i in maxi(0, g.columns - 1):
		var pad := Control.new()
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.add_child(pad)


static func section(text: String) -> Label:
	var l := label(text, "HubSection")
	return l


static func spacer(h: int = GAP_M) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## 세로로 늘어나는 빈 칸 — 아래쪽 요소(출정 버튼 등)를 바닥에 붙인다.
static func grow() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
