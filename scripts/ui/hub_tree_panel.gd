extends HubPanel
## **트리 패널** (`F-020` §3.10) — 두 건물이 **같은 데이터를 다른 눈으로** 본다.
##
##   · **필기 상점** = `Unlock`(해금) + `Upgrade`(강화) — 슬롯 스킬을 열고 키운다.
##   · **성소**      = `Doctrine`(운용 교리) — 4명을 어떤 순서·템포로 굴릴지.
##
## M6 건물 재편 전에는 넷이 한 화면에 있었는데, `Slot`은 대장간 tier가 게이트하고 `Doctrine`은
## chapel이 게이트하는 **기형**이었다("왜 성소에서 사는데 대장간을 올리라 하지"). 이제 사는 곳과
## 조건이 같은 건물이다. `Slot`은 대장간(모딩 패널)이 가져갔다.
##
## `Unlock`은 **역할 × AB 전수 63개**라 평면 목록이면 63줄이다 → **계열(`skill_family`)로 접고**,
## `Upgrade`는 자기 `Unlock` **아래 들여쓰기**로 붙여 선행 관계를 눈에 보이게 한다.
##
## 표는 `GridContainer` **한 장**이다. 그룹마다 컨테이너를 따로 두면 그룹별로 열 폭이 달라져
## 「폰트가 안 맞는」 것처럼 보인다 — 머리글은 빈 칸으로 한 줄을 채워 열 정렬을 유지한다.

const COLS := 5   # [유형] [이름] [설명] [비용] [행동]

## 노드 유형별 색 — 「무엇을 사는 중인가」가 한눈에 갈리게.
const TYPE_COLOR := {
	"Slot": Color(0.62, 0.86, 1.0), "Unlock": Color(0.70, 0.90, 0.70),
	"Upgrade": Color(1.0, 0.85, 0.45), "Doctrine": Color(0.85, 0.70, 1.0),
}
const TYPE_KO := {"Slot": "슬롯", "Unlock": "해금", "Upgrade": "발전", "Doctrine": "운용"}
const ROLES := ["Tank", "DPS", "Nuker", "Healer"]

## 이 패널 인스턴스가 담당하는 노드 유형·제목·게이트 시설 — 건물이 주입한다.
var types: Array = ["Unlock", "Upgrade"]
var title_text: String = "필기 상점 — 해금과 강화"
var gate_facility: String = "scribe_shop"

var _cls: String = "Tank"           # 역할 탭 — 클래스 트리(U6)라 한 번에 한 역할만 본다
var _open_fams: Dictionary = {}     # 계열 접기 상태
var _tabs: HBoxContainer

@onready var _hub: Node = get_node_or_null("/root/HubProfile")
@onready var _doc: Node = get_node_or_null("/root/DoctrineProfile")


func _ready() -> void:
	window_size = Vector2(960, 620)
	panel_title = title_text
	super()
	# 역할 탭 — 트리 단위가 클래스라(U6) 4역할을 한 화면에 쏟으면 250줄이 된다.
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", HubTheme.GAP_S)
	titlebar.add_child(_tabs)
	titlebar.move_child(_tabs, 1)
	for cls in ROLES:
		var tb := Button.new()
		tb.text = Slice01Data.get_role_label(cls)
		tb.pressed.connect(func() -> void:
			_cls = cls
			refresh())
		_tabs.add_child(tb)
	if _hub != null and _hub.has_signal("economy_changed"):
		_hub.economy_changed.connect(refresh)


func open_panel(cls: String = "") -> void:
	if cls != "":
		_cls = cls
	super()


func refresh() -> void:
	if body == null or _hub == null:
		return
	set_title(title_text)
	clear_body()
	for i in _tabs.get_child_count():
		var b: Button = _tabs.get_child(i) as Button
		if b != null:
			b.modulate = HubTheme.SEL if ROLES[i] == _cls else Color(0.78, 0.78, 0.82)

	var tier: int = int(_hub.facility_tier(gate_facility))
	var uncapped: bool = bool(_hub.PLAYTEST_TREE_ALL_UNLOCKED)
	set_status("%s T%d%s" % [Slice01Data.get_facility_def(gate_facility).get("display", gate_facility),
		tier, "  ·  플테: 전 노드 해금" if uncapped else ""],
		HubTheme.ACCENT if tier >= 1 else HubTheme.BAD)
	if tier < 1:
		body.add_child(HubTheme.para("이 건물이 아직 안 열렸다 — 「시설 승급」에서 세우면 열린다.", "", HubTheme.BAD))
		if gate_facility == "chapel":
			body.add_child(HubTheme.para(
				"성소 T0 = doctrine 0 = 중립 성장. 그 상태로도 클리어는 성립해야 한다(QA-032 §2.1).", "HubMeta"))

	# 이 건물이 담당하는 유형만, 이 역할 것만.
	var mine: Array = []
	for row in Slice01Data.tree_nodes_for_class(_cls):
		if types.has(String((row as Dictionary).get("type", ""))):
			mine.append(row)
	if mine.is_empty():
		body.add_child(HubTheme.para("%s에 해당하는 노드가 없다." % Slice01Data.get_role_label(_cls), "HubMeta"))
		return

	# `Upgrade`는 자기 `Unlock` 아래로 접어 넣는다(선행 관계 = 들여쓰기).
	var ups: Dictionary = {}          # unlock node_id -> [upgrade rows]
	var child_ids: Dictionary = {}
	for row2 in mine:
		if String(row2.get("type", "")) == "Upgrade" and String(row2.get("prerequisite", "")) != "":
			var pre := String(row2["prerequisite"])
			if not ups.has(pre):
				ups[pre] = []
			ups[pre].append(row2)
			child_ids[String(row2.get("node_id", ""))] = true

	var groups: Dictionary = {}       # family -> [rows]
	var order: Array = []
	for row3 in mine:
		if child_ids.has(String(row3.get("node_id", ""))):
			continue                  # 부모 밑에서 그린다
		var fam := _family_of(row3)
		if not groups.has(fam):
			groups[fam] = []
			order.append(fam)
		groups[fam].append(row3)

	var g := HubTheme.grid(COLS)
	body.add_child(g)
	for fam2 in order:
		var rows2: Array = groups[fam2]
		var open_g: bool = bool(_open_fams.get(fam2, order.size() <= 2))   # 그룹이 적으면 기본 펼침
		var tog := Button.new()
		tog.text = "%s  %s  (%d)" % ["▾" if open_g else "▸", fam2, rows2.size()]
		tog.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tog.flat = true
		tog.pressed.connect(func() -> void:
			_open_fams[fam2] = not open_g
			refresh())
		HubTheme.span_row(g, tog)
		if not open_g:
			continue
		for row4 in rows2:
			_node_row(g, row4, 1)
			for up in (ups.get(String(row4.get("node_id", "")), []) as Array):
				_node_row(g, up, 2)


## 노드의 그룹 축 = **계열**(`skill_family`). 모딩 화면의 필터와 **같은 축**이라 「여기서 연 걸
## 저기서 끼운다」가 이어진다. AB가 없는 노드(`Doctrine`)는 자기 유형 이름으로 묶는다.
func _family_of(row: Dictionary) -> String:
	var ab := String(row.get("base_ability_id", ""))
	if ab != "":
		return String(Slice01Data.get_skillbook_master(ab).get("skill_family", "기타"))
	return String(TYPE_KO.get(String(row.get("type", "")), "기타"))


## 한 줄 = 그리드 셀 5개. **셀 수가 어긋나면 그 아래 전부가 밀린다** — 어느 분기로 가도 5개를 넣는다.
func _node_row(g: GridContainer, row: Dictionary, depth: int) -> void:
	var nid := String(row.get("node_id", ""))
	var ty := String(row.get("type", ""))
	var bought: bool = bool(_hub.tree_unlocked.get(nid, false))
	var chk: Dictionary = _hub.tree_check(nid)
	var ok: bool = bool(chk.get("ok", false))

	g.add_child(HubTheme.label("%s%s %s" % ["      ".repeat(depth - 1), "└" if depth >= 2 else "·",
		TYPE_KO.get(ty, ty)], "HubMeta", TYPE_COLOR.get(ty, HubTheme.DIM)))
	g.add_child(HubTheme.label(String(row.get("display_name", nid)), "",
		HubTheme.TEXT if (bought or ok) else HubTheme.DISABLED))
	var desc := HubTheme.label(String(row.get("desc", "")), "HubMeta")
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(desc)
	g.add_child(HubTheme.label(_cost_text(row.get("cost", {})), "HubMeta",
		HubTheme.OK if ok else HubTheme.DIM))

	if bought:
		# `Doctrine`은 구매만으로 끝이 아니다 — **활성은 별도**(Identity당 1개, 재배치 자유·환불 없음).
		if ty == "Doctrine" and _doc != null:
			var did := String(row.get("doctrine_id", ""))
			var on: bool = String(_doc.active.get(_cls, "")) == did
			var act := Button.new()
			act.text = "활성 해제" if on else "활성"
			act.modulate = HubTheme.ACCENT if on else Color(1, 1, 1)
			act.pressed.connect(func() -> void:
				_doc.set_active(_cls, "" if on else did)
				refresh())
			g.add_child(act)
		else:
			g.add_child(HubTheme.label("✔ 해금", "HubMeta", HubTheme.OK))
	else:
		var buy := Button.new()
		buy.text = "구매"
		buy.disabled = not ok
		buy.tooltip_text = _reason_text(String(chk.get("reason", "")))
		buy.pressed.connect(func() -> void:
			_hub.tree_buy(nid)
			refresh())
		g.add_child(buy)


func _cost_text(cost: Dictionary) -> String:
	if cost.is_empty():
		return "무료"
	var parts: Array = []
	for m in cost:
		var have: int = int(_hub.vault_count(String(m)))
		var need := int(cost[m])
		parts.append("%s %d/%d" % [Slice01Data.get_haul_material(String(m)).get("display", m), have, need])
	return " · ".join(parts)


## 거부 사유를 **말로** 돌려준다 — 비활성 버튼만 있고 이유가 없으면 「왜 못 사지」가 남는다.
func _reason_text(reason: String) -> String:
	match reason:
		"facility": return "이 건물을 먼저 세워야 한다 — 「시설 승급」"
		"facility_req": return "대장간(smithy) 승급 필요 — 슬롯 사다리는 시설에 묶여 있다 (F-008 §3.10)"
		"tier_ceiling": return "필기 상점 등급 부족 — 이 tier의 스킬을 아직 못 연다"
		"prereq": return "선행 노드를 먼저 해금해야 한다"
		"haul": return "금고 재료 부족 — 런에서 회수해 입금"
		"already": return "이미 해금됨 (환불 없음 — F-030 §3.2)"
		_: return ""
