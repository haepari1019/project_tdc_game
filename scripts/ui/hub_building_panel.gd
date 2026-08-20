extends HubPanel
## **건물 한 채** — 의뢰를 받고, 짓고, 올린다. (`F-029` · `UI-029`)
##
## M6에서 **시설 승급 패널을 대체**했다. 전에는 「마을에서 폐허를 눌러도 목록 화면이 열리고, 거기서
## 다시 그 건물을 골라야」 했다 — 마을을 만든 이유가 사라지는 동선이다. 이제 **폐허 앞에 서면 그
## 폐허의 이야기가 나온다**.
##
## 의뢰도 여기서 받는다(사용자 판정): *「퀘스트를 그 퀘스트의 결과로 해금되는 공간에서 주고
## 승낙할 수 있게」*. 장부를 열어 목록을 훑는 것보다, **폐허 앞에서 「이걸 세워 주게」를 듣고
## 수락하는 것**이 마을을 일으킨다는 감각에 가깝다.
##
## **수락하지 않은 의뢰는 완료되지 않는다**(`HubProfile._q_if` / `set_quest_completed`) — 조건을
## 우연히 충족해도 마찬가지다. 그래야 수락이 형식이 아니라 선택이 된다.

var _fid: String = "smithy"
@onready var _hub: Node = get_node_or_null("/root/HubProfile")


func _ready() -> void:
	window_size = Vector2(720, 480)
	panel_title = "건물"
	super()
	if _hub != null and _hub.has_signal("facilities_changed"):
		_hub.facilities_changed.connect(refresh)
		_hub.vault_changed.connect(refresh)


func open_panel(fid: String = "") -> void:
	if fid != "":
		_fid = fid
	super()


func refresh() -> void:
	if body == null or _hub == null:
		return
	var def: Dictionary = Slice01Data.get_facility_def(_fid)
	if def.is_empty():
		return
	var tier: int = int(_hub.facility_tier(_fid))
	set_title(String(def.get("display", _fid)))
	set_status("T%d" % tier, HubTheme.ACCENT if tier >= 1 else HubTheme.DIM)
	clear_body()

	# 지금 이 건물이 무엇인가.
	body.add_child(HubTheme.section("지금"))
	body.add_child(HubTheme.para(String(Slice01Data.get_facility_tier(_fid, tier).get("effect", "")),
		"", HubTheme.TEXT if tier >= 1 else HubTheme.DIM, 640))

	var chk: Dictionary = _hub.upgrade_check(_fid)
	if String(chk.get("reason", "")) == "max":
		body.add_child(HubTheme.spacer())
		body.add_child(HubTheme.label("더 올릴 단계가 없다.", "HubMeta"))
		return
	var nt: int = int(chk.get("next_tier", tier + 1))
	var nxt: Dictionary = Slice01Data.get_facility_tier(_fid, nt)
	body.add_child(HubTheme.spacer())
	body.add_child(HubTheme.section("다음 — T%d" % nt))
	body.add_child(HubTheme.para(String(nxt.get("effect", "")), "", HubTheme.ACCENT, 640))

	_render_quest(String(nxt.get("quest", "")))
	_render_cost(nxt)

	body.add_child(HubTheme.spacer())
	var ok: bool = bool(chk.get("ok", false))
	var up := Button.new()
	up.text = ("건립" if tier < 1 else "승급") if ok else ("건립 불가" if tier < 1 else "승급 불가")
	up.disabled = not ok
	up.custom_minimum_size = Vector2(0, 40)
	up.tooltip_text = "" if ok else _blocked_reason(String(chk.get("reason", "")))
	up.pressed.connect(func() -> void:
		_hub.attempt_upgrade(_fid)   # → facilities_changed → refresh
		refresh())
	body.add_child(up)


## 의뢰 — **여기가 수락처다.** 미수락이면 제안문 + [수락], 수락했으면 진행 조건, 완료면 완료 표시.
func _render_quest(qid: String) -> void:
	if qid == "":
		return
	var q: Dictionary = Slice01Data.get_quest(qid)
	var done: bool = _hub.is_quest_done(qid)
	var accepted: bool = _hub.is_quest_accepted(qid)
	body.add_child(HubTheme.spacer())
	body.add_child(HubTheme.section("의뢰"))
	var g := HubTheme.grid(2)
	body.add_child(g)
	g.add_child(HubTheme.label("이름", "HubMeta"))
	g.add_child(HubTheme.label(String(q.get("one_liner", qid)), "", HubTheme.TEXT))
	g.add_child(HubTheme.label("조건", "HubMeta"))
	g.add_child(HubTheme.label(String(q.get("completion", "?")), "HubMeta"))
	g.add_child(HubTheme.label("상태", "HubMeta"))
	g.add_child(HubTheme.label(
		"✓ 완료" if done else ("진행 중" if accepted else "미수락"),
		"", HubTheme.OK if done else (HubTheme.ACCENT if accepted else HubTheme.BAD)))

	if done or accepted:
		return
	# 아직 안 받은 의뢰 — 제안하고 받게 한다. 이게 이 화면의 존재 이유다.
	body.add_child(HubTheme.para(
		"아직 이 일을 맡지 않았다. 수락해야 조건을 채워도 완료로 친다.", "HubMeta", null, 640))
	var take := Button.new()
	take.text = "의뢰를 맡는다"
	take.custom_minimum_size = Vector2(0, 34)
	take.pressed.connect(func() -> void:
		_hub.accept_quest(qid)
		refresh())
	body.add_child(take)


## 재료 — **읽기 전용**이다. 여기서 채울 수 있으면 런에서 회수할 이유가 없어진다.
func _render_cost(nxt: Dictionary) -> void:
	var haul: Dictionary = nxt.get("haul", {})
	var pre: Dictionary = nxt.get("prereq", {})
	if haul.is_empty() and pre.is_empty():
		return
	body.add_child(HubTheme.spacer())
	body.add_child(HubTheme.section("필요"))
	var g := HubTheme.grid(3)
	body.add_child(g)
	for pid in pre:
		var need_t := int(pre[pid])
		var have_t: int = int(_hub.facility_tier(String(pid)))
		g.add_child(HubTheme.label("선행", "HubMeta"))
		g.add_child(HubTheme.label("%s T%d 이상" % [
			String(Slice01Data.get_facility_def(String(pid)).get("display", pid)), need_t], "HubMeta"))
		g.add_child(HubTheme.label("현재 T%d" % have_t, "HubMeta",
			HubTheme.OK if have_t >= need_t else HubTheme.BAD))
	for hid in haul:
		var need := int(haul[hid])
		var have: int = int(_hub.vault_count(String(hid)))
		g.add_child(HubTheme.label("재료", "HubMeta"))
		g.add_child(HubTheme.label(String(Slice01Data.get_haul_material(String(hid)).get("display", hid)), "HubMeta"))
		g.add_child(HubTheme.label("%d / %d" % [have, need], "HubMeta",
			HubTheme.OK if have >= need else HubTheme.BAD))
	if not haul.is_empty():
		body.add_child(HubTheme.para("재료는 던전에서 회수해 탈출하면 금고에 쌓인다.", "HubMeta", null, 640))


func _blocked_reason(reason: String) -> String:
	match reason:
		"quest": return "의뢰를 먼저 맡고 끝내야 한다"
		"haul": return "금고 재료가 모자란다 — 던전에서 회수해 오자"
		"prereq": return "선행 건물을 먼저 올려야 한다"
		"max": return "최대 단계"
		_: return "아직 조건이 안 됐다"
