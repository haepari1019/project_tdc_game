extends HubPanel
## **의뢰 장부** (`F-029` §3.3) — 지금 무엇을 맡고 있고, 무엇이 남았는지 훑는 곳.
##
## **받고 맡는 일은 여기서 안 한다**(M6, 사용자 판정) — 의뢰는 **그 의뢰가 여는 건물에서** 준다.
## 폐허 앞에서 「이걸 세워 주게」를 듣고 수락하는 것이, 장부를 열어 목록을 훑는 것보다 마을을
## 일으킨다는 감각에 가깝기 때문이다. 그래서 이 화면은 **읽기 전용**이고, 대신 각 줄에
## **어디서 받는지**를 적는다.
##
## 표는 `GridContainer` 5열이라 상태·받는 곳·이름·조건이 **줄마다 같은 x에** 선다. 예전엔 한 줄을
## 문자열로 이어 붙였는데(`"%s %s · %s T%d — %s"`), 한글 폭이 달라 시설 이름부터 계단처럼 밀렸다.

const COLS := 5   # [상태] [받는 곳] [이름] [조건] [수락]

var _grid: GridContainer
@onready var _hub: Node = get_node_or_null("/root/HubProfile")


func _ready() -> void:
	window_size = Vector2(820, 560)
	panel_title = "의뢰 장부"
	super()
	body.add_child(HubTheme.para(
		"의뢰는 **그 의뢰가 여는 건물**에서 받는다 — 마을에서 건물을 눌러 맡는다.", "HubMeta"))


func refresh() -> void:
	if body == null:
		return
	if _hub != null and _hub.has_method("evaluate_quests"):
		_hub.evaluate_quests()   # 자동평가형(재료/시설Tier 등) 갱신 후 표시
	clear_body()
	body.add_child(HubTheme.para(
		"의뢰는 그 의뢰가 여는 건물에서 받는다 — 마을에서 건물을 눌러 맡는다.", "HubMeta"))

	# **세 무더기**로 나눈다: 맡은 것 / 아직 안 맡은 것 / 끝낸 것. 「지금 뭘 하고 있나」가
	# 「뭐가 더 있나」와 섞이면 장부를 볼 이유가 없다.
	var quests: Dictionary = Slice01Data.get_quests()
	var active: Array = []
	var offered: Array = []
	var done: Array = []
	for qid in quests:
		var q := String(qid)
		if _hub != null and _hub.is_quest_done(q):
			done.append(q)
		elif _hub != null and _hub.is_quest_accepted(q):
			active.append(q)
		else:
			offered.append(q)
	active.sort()
	offered.sort()
	done.sort()
	set_status("맡은 %d · 미수락 %d · 완료 %d" % [active.size(), offered.size(), done.size()], HubTheme.DIM)

	_grid = HubTheme.grid(COLS)
	body.add_child(_grid)
	HubTheme.span_row(_grid, HubTheme.section("맡은 의뢰 (%d)" % active.size()))
	if active.is_empty():
		HubTheme.span_row(_grid, HubTheme.label("맡은 의뢰가 없다 — 마을에서 건물을 눌러 받는다.",
			"HubMeta", HubTheme.BAD))
	for qid1 in active:
		_row(qid1, quests[qid1], "active")
	HubTheme.span_row(_grid, HubTheme.spacer())
	HubTheme.span_row(_grid, HubTheme.section("아직 맡지 않음 (%d)" % offered.size()))
	for qid2 in offered:
		_row(qid2, quests[qid2], "offered")
	HubTheme.span_row(_grid, HubTheme.spacer())
	HubTheme.span_row(_grid, HubTheme.section("완료 (%d)" % done.size()))
	for qid3 in done:
		_row(qid3, quests[qid3], "done")


## 한 줄 = 셀 5개. **어느 분기로 가도 5개** — 하나라도 빠지면 그 아래 전부가 한 칸씩 밀린다.
func _row(qid: String, q: Dictionary, state: String) -> void:
	var fac := String(q.get("facility", ""))
	var fac_name := String(Slice01Data.get_facility_def(fac).get("display", fac))
	var mark: String = {"done": "✓", "active": "▶", "offered": "·"}.get(state, "·")
	var col: Color = {"done": HubTheme.OK, "active": HubTheme.ACCENT}.get(state, HubTheme.DIM)
	_grid.add_child(HubTheme.label(mark, "", col))
	_grid.add_child(HubTheme.label("%s T%d" % [fac_name, int(q.get("tier", 0))], "HubMeta"))
	_grid.add_child(HubTheme.label(String(q.get("one_liner", qid)), "",
		HubTheme.DIM if state == "done" else HubTheme.TEXT))
	var cond := HubTheme.label("" if state == "done" else String(q.get("completion", "?")), "HubMeta")
	cond.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_child(cond)
	# 「어디서 받나」 — 이 장부는 읽기 전용이므로 **가야 할 곳**을 알려주는 것이 마지막 칸의 일이다.
	_grid.add_child(HubTheme.label("%s에서 수락" % fac_name if state == "offered" else "", "HubMeta",
		HubTheme.BAD))
