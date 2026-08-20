extends Control
## **성채 — 마을 화면** (`UI-005` §3 / `UI-029`). 건물을 눌러 들어가고, 하단 파티 스트립이 4인의
## 현재 구성을 항상 보여준다.
##
## M6 이전엔 560×400 패널에 버튼이 세로로 쌓인 **테이블**이었고, 실제 상태(누가 뭘 들었는지)는
## 어디에도 안 보였다 — 스태시를 열어야만 알 수 있었다. P4b가 성장을 「캐릭터 강화」에서
## **「이 건을 어떤 무기로 만들까」**로 옮긴 이상, 허브의 1급 정보는 **파티 4인의 건 구성**이다.
##
## **건물 = `F-029` 시설**이다. 새로 발명한 화면이 아니라 이미 있는 tier 표를 공간으로 옮긴 것이며,
## 좌표는 `facilities_tiers.json` `map_pos`가 소유한다(아트가 코드 없이 재배치할 수 있게).
## 미건립(T0)은 **폐허로 보인다** — 안 보이면 「여기 뭐가 더 있나」를 알 길이 없다.
##
## **~~Confirm Loadout~~ · ~~난이도 선택~~ 제거**(M6). 전자는 gear=정체성 동기화라 확정할 것이
## 없었고, 후자는 지역·입장조건이 그 축을 가져간다. 출정 게이트는 **성문**이 소유한다.

const DUNGEON_SCENE := "res://scenes/run/dungeon_run.tscn"
const PartyController := preload("res://scripts/party/party_controller.gd")
const InventoryUI := preload("res://scripts/ui/inventory/inventory_ui.gd")
const StashSource := preload("res://scripts/ui/inventory/stash_source.gd")
const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")
const BindingOverlays := preload("res://scripts/combat/abilities/bindings/binding_overlays.gd")
## `RichTooltip`은 `Panel`(비컨테이너)이라 자식을 배치하지도 자식에 맞춰 커지지도 않는다 —
## 카드·건물처럼 **내용에 맞춰 자라야 하는** 것은 `RichPanel`(PanelContainer판)을 쓴다.
const RichPanel := preload("res://scripts/ui/rich_panel.gd")
const HubBuildingPanel := preload("res://scripts/ui/hub_building_panel.gd")
const HubEconomyPanel := preload("res://scripts/ui/hub_economy_panel.gd")
const HubQuestPanel := preload("res://scripts/ui/hub_quest_panel.gd")
const HubTreePanel := preload("res://scripts/ui/hub_tree_panel.gd")
const HubModdingPanel := preload("res://scripts/ui/hub_modding_panel.gd")
const HubGatePanel := preload("res://scripts/ui/hub_gate_panel.gd")

const ROLES := ["Tank", "DPS", "Nuker", "Healer"]
const SLOT_KEY := ["Q", "E", "R"]
## 색·글자크기는 **`HubTheme`가 유일한 출처**다. 화면마다 상수를 다시 선언하면 같은 「경고」가
## 화면마다 다른 빨강이 되고, 그게 「정리가 안 된 느낌」의 실체였다.
const BAD := HubTheme.BAD
const DIM := HubTheme.DIM
const ACCENT := HubTheme.ACCENT

## 건물 → 어느 화면이 열리는가. **라우팅 SSOT** — `hub_smoke`가 `FACILITY_IDS`와 1:1 대조해서
## 「갈 곳 없는 건물」과 「건물 없는 화면」을 둘 다 잡는다.
const BUILDING_ROUTE := {
	"smithy": "modding", "scribe_shop": "skills", "chapel": "doctrine",
	"armory": "gear_shop", "quartermaster": "supply", "stash": "stash", "barracks": "gate",
}
## 처음부터 서 있는 건물 — tier 0이 곧 기능인 곳(`F-029`: 막사 = 배치, 창고 = capacity 20).
## 나머지는 T0가 「미건립」이라 폐허로 보인다.
const ALWAYS_BUILT := ["barracks", "stash"]

var _party: Node
var _inv: InventoryUI
var _stash_src: Node

var _panels: Dictionary = {}       # route -> Control
var _gate: Control
var _modding: Control
var _map_layer: Control
var _wallet: Label
var _pin_lbl: Label
var _cards: Dictionary = {}        # role -> {panel, gear}

@onready var _stash: Node = get_node("/root/Stash")
@onready var _run_loadout: Node = get_node("/root/RunLoadout")
@onready var _hub: Node = get_node_or_null("/root/HubProfile")


func _ready() -> void:
	_build_layout()
	if not Slice01Data.is_loaded():
		_pin_lbl.text = "Slice01 data FAILED — see Output"
		_pin_lbl.modulate = BAD
		push_error("[TDC] Slice01 data not loaded")
		return
	_setup_hub()
	var pin := GameBootstrap.get_spec_pin_summary()
	_pin_lbl.text = "%s · %s" % [pin, Slice01Data.get_summary()]
	print("[TDC] Hub ready — ", pin)
	refresh_all()


# --- 레이아웃 ------------------------------------------------------------------

func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HubTheme.get_theme()   # 하위 전체가 상속 → 노드별 font_size override 불필요
	var bg := ColorRect.new()
	bg.color = HubTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for sd in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(sd, 12)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	root.add_child(_build_topbar())

	# 마을 — 건물이 **정규화 좌표**로 놓이는 자유 배치 층. 컨테이너를 쓰지 않는 이유: 건물 위치는
	# 데이터 소유라 레이아웃 규칙이 아니라 좌표가 결정해야 한다(아트 교체 시 코드 불변).
	_map_layer = Control.new()
	_map_layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_layer.clip_contents = true
	_map_layer.resized.connect(_place_buildings)
	root.add_child(_map_layer)
	var ground := ColorRect.new()
	ground.color = Color(0.095, 0.10, 0.12)
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_layer.add_child(ground)

	root.add_child(_build_party_strip())

	_pin_lbl = HubTheme.label("", "HubMeta")
	root.add_child(_pin_lbl)


## 상단 — **세 지갑**(모딩 시술비 `ward_scrap` · 시전 자원 마석 · 금고 재료)이 항상 보인다.
## 「지금 뭘 할 수 있나」가 여기서 갈리는데, 예전엔 패널을 열어야만 알 수 있었다.
func _build_topbar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	bar.add_child(HubTheme.label("성채", "HubTitle"))
	_wallet = HubTheme.label("")
	_wallet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_wallet)
	return bar


## 하단 파티 스트립 — 카드에는 **건 이름만**. 나머지(정체성·Q/E/R·결속)는 **마우스 오버 툴팁**으로.
## 카드에 다 적으면 4장이 화면을 먹고, 그러면 마을이 안 보인다. 여기서 필요한 건 「누가 뭘 들었나」의
## 즉답이고, 상세는 물어봤을 때 나오면 된다.
func _build_party_strip() -> Control:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", HubTheme.GAP_M)
	strip.custom_minimum_size = Vector2(0, 74)
	for role in ROLES:
		var pc := RichPanel.new()   # BBCode 툴팁(색) — 결속·규약을 색으로 구분
		pc.theme_type_variation = "HubCard"
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pc.mouse_filter = Control.MOUSE_FILTER_STOP
		pc.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
				_modding.open_panel(role))
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 1)
		pc.add_child(vb)
		var head := HBoxContainer.new()
		vb.add_child(head)
		var dot := ColorRect.new()
		dot.color = UnitVisuals.role_color(role)
		dot.custom_minimum_size = Vector2(5, 15)
		head.add_child(dot)
		head.add_child(HubTheme.label("  " + Slice01Data.get_role_label(role), "HubMeta"))
		# **한 줄 + 말줄임.** 여기서 autowrap을 켜면 폭이 0이 돼 「거암 / 의 대 / 방패」로 쪼개진다.
		# 잘린 이름의 전문·정체성·Q/E/R은 전부 툴팁에 있으므로 정보가 사라지지 않는다.
		var gear := HubTheme.line("", "HubSection", HubTheme.TEXT)
		gear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(gear)
		_cards[role] = {"panel": pc, "gear": gear}
		strip.add_child(pc)
	return strip


# --- 건물 --------------------------------------------------------------------

## 건물 플레이트를 `map_pos`(정규화 0..1) 위에 놓는다. 아트가 들어오면 이 노드에 `TextureRect`를
## 붙이기만 하면 되도록 **위치 계산과 표시를 분리**해 뒀다.
func _place_buildings() -> void:
	if _map_layer == null:
		return
	var msize := _map_layer.size
	for ch in _map_layer.get_children():
		if not ch.has_meta("fid"):
			continue
		var pos: Array = Slice01Data.get_facility_def(String(ch.get_meta("fid"))).get("map_pos", [0.5, 0.5])
		var c := ch as Control
		var w: float = maxf(c.size.x, c.custom_minimum_size.x)
		var h: float = maxf(c.size.y, 52.0)
		c.position = Vector2(
			clampf(float(pos[0]) * msize.x - w * 0.5, 4.0, maxf(4.0, msize.x - w - 4.0)),
			clampf(float(pos[1]) * msize.y - h * 0.5, 4.0, maxf(4.0, msize.y - h - 4.0)))


func _build_buildings() -> void:
	for fid in _hub.FACILITY_IDS:
		var def: Dictionary = Slice01Data.get_facility_def(String(fid))
		if def.is_empty():
			push_warning("[TDC] 마을 — 시설 '%s' 데이터 없음(건물 미배치)" % fid)
			continue
		_map_layer.add_child(_building_plate(String(fid), def))
	_place_buildings()


## 건물 하나. **T0 = 폐허**: 지을 수 있다는 걸 보여주는 것이 목표 가시화다(다키스트던전식).
## `F-029` `smithy` T0 「맵 비표시」와 어긋나므로 드리프트로 기록했다 — 숨기면 첫 플레이에
## 빈 땅만 보이고 「여기 뭐가 더 있나」를 알 길이 없다.
func _building_plate(fid: String, def: Dictionary) -> Control:
	var tier: int = int(_hub.facility_tier(fid))
	var built: bool = tier >= 1 or ALWAYS_BUILT.has(fid)
	var pc := RichPanel.new()
	pc.theme_type_variation = "HubCard"
	pc.set_meta("fid", fid)
	pc.custom_minimum_size = Vector2(196, 0)   # 높이는 내용이 정한다(PanelContainer라 자란다)
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.modulate = Color(1, 1, 1) if built else Color(0.58, 0.58, 0.64)
	pc.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			var mb := e as InputEventMouseButton
			_enter_building(fid, built, mb.button_index == MOUSE_BUTTON_RIGHT))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	pc.add_child(vb)
	# 「여기 할 일이 있다」를 **마을에서** 읽히게 — 시설 목록 화면을 없앴으므로(M6) 어느 건물을
	# 눌러야 하는지는 카드가 스스로 말해야 한다. 뱃지가 없으면 전 건물을 하나씩 눌러 봐야 한다.
	var act := String(_hub.building_action(fid)) if _hub != null else ""
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	vb.add_child(head)
	var nm := HubTheme.line("%s%s" % ["░ " if not built else "", String(def.get("display", fid))],
		"HubSection", HubTheme.TEXT if built else HubTheme.DISABLED)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	if act != "":
		head.add_child(HubTheme.label("!" if act == "accept" else "▲", "HubSection",
			HubTheme.BAD if act == "accept" else HubTheme.OK))
	# 부제도 **한 줄**이다 — 효과 문구는 길이가 제각각이라 줄바꿈을 허용하면 카드 높이가 들쭉날쭉해지고
	# 마을이 지저분해진다. 전문은 툴팁에.
	vb.add_child(HubTheme.line(("T%d · %s" % [tier, _tier_effect(fid, tier)]) if built else "폐허 — 눌러서 건립",
		"HubMeta", HubTheme.ACCENT if built else HubTheme.DIM))
	pc.tooltip_text = _building_tip(fid, def, tier, built, act)
	return pc


func _tier_effect(fid: String, tier: int) -> String:
	return String(Slice01Data.get_facility_tier(fid, tier).get("effect", ""))


func _building_tip(fid: String, def: Dictionary, tier: int, built: bool, act: String) -> String:
	var out: Array = ["[b]%s[/b]  [color=#9aa4b2]T%d[/color]" % [String(def.get("display", fid)), tier]]
	out.append("[color=#f0b64a]%s[/color]" % _tier_effect(fid, tier))
	if not built:
		out.append("[color=#ff8080]아직 세워지지 않았다[/color]")
	var nxt: Dictionary = Slice01Data.get_facility_tier(fid, tier + 1)
	if not nxt.is_empty():
		out.append("[color=#9aa4b2]다음 단계 — %s[/color]" % String(nxt.get("effect", "")))
	match act:
		"accept":
			out.append("[color=#ff8080]! 맡을 의뢰가 있다[/color]")
		"upgrade":
			out.append("[color=#8be58b]▲ 지금 %s할 수 있다[/color]" % ("건립" if tier < 1 else "승급"))
	out.append("[color=#6a6a70]좌클릭 — %s  ·  우클릭 — 건물 정보·의뢰[/color]" % (
		"이 건물의 일" if built else "건물 정보"))
	return "
".join(out)


## 건물 진입 — **좌클릭 = 그 건물의 일 / 우클릭 = 건물 자체**(의뢰·건립·승급).
## 폐허는 아직 할 일이 없으므로 좌클릭도 건물 화면으로 보낸다: 「눌렀는데 아무 일도 없다」가 되면
## 유저는 그 건물을 다시 안 누른다.
func _enter_building(fid: String, built: bool, want_info: bool = false) -> void:
	if not built or want_info:
		_panels["building"].open_panel(fid)
		return
	var route := String(BUILDING_ROUTE.get(fid, ""))
	if route == "stash":
		_open_stash()
		return
	if _panels.has(route):
		_panels[route].open_panel()
	else:
		push_warning("[TDC] 마을 — '%s'에 연결된 화면이 없다" % fid)


# --- 허브 구성 -----------------------------------------------------------------

func _setup_hub() -> void:
	_party = PartyController.new()
	var members_node := Node3D.new()   # PartyController expects a $Members child
	members_node.name = "Members"
	_party.add_child(members_node)
	add_child(_party)
	_party.set_physics_process(false)   # no nav/MIA/formation in the hub — members just hold data
	_party.set_process(false)
	_inv = InventoryUI.new()
	add_child(_inv)
	_inv.setup_party(_party, null)      # combat=null → equip allowed (F-008 §4.2 in-combat gate off)
	var bp := get_node_or_null("/root/Backpack")
	if bp != null:
		bp.apply_to_party(_party)       # 영속 장착 gear + 슬롯 AB 복원
	_inv.stash_item_discarded.connect(_on_stash_item_discarded)
	_stash_src = StashSource.new()
	_stash_src.items = _build_stash_items()

	_build_panels()
	_build_buildings()
	if _hub != null and _hub.has_signal("economy_changed"):
		_hub.economy_changed.connect(refresh_all)


## 화면은 전부 풀스크린 오버레이다. 닫을 때 마을을 다시 그린다 — 건물 tier·재화·건 구성이 안에서
## 바뀌었을 수 있고, 나왔는데 마을이 그대로면 방금 한 일이 없던 일처럼 보인다.
func _build_panels() -> void:
	# 건물 한 채 화면 — 의뢰 수락·건립·승급. **시설 승급 목록 패널을 대체**했다(M6): 마을에서
	# 폐허를 눌렀는데 목록이 열리고 거기서 다시 그 건물을 고르는 건 마을을 만든 이유를 지운다.
	var building := HubBuildingPanel.new()
	add_child(building)
	_panels["building"] = building

	var quests := HubQuestPanel.new()
	add_child(quests)
	_panels["quests"] = quests

	# 필기 상점 = 해금·강화 / 성소 = 운용 교리. **같은 스크립트, 다른 눈**(M6 건물 재편).
	var skills := HubTreePanel.new()
	skills.types = ["Unlock", "Upgrade"]
	skills.title_text = "필기 상점 — 해금과 강화"
	skills.gate_facility = "scribe_shop"
	add_child(skills)
	_panels["skills"] = skills

	var doctrine := HubTreePanel.new()
	doctrine.types = ["Doctrine"]
	doctrine.title_text = "성소 — 운용 교리"
	doctrine.gate_facility = "chapel"
	add_child(doctrine)
	_panels["doctrine"] = doctrine

	# 무기고 = gear / 군수 = 보급. 재고가 달라야 마을에 문이 둘일 이유가 있다.
	var gear_shop := HubEconomyPanel.new()
	gear_shop.mode = "gear"
	add_child(gear_shop)
	_panels["gear_shop"] = gear_shop

	var supply := HubEconomyPanel.new()
	supply.mode = "supply"
	add_child(supply)
	_panels["supply"] = supply

	_modding = HubModdingPanel.new()
	_modding.party = _party
	add_child(_modding)
	_panels["modding"] = _modding

	_gate = HubGatePanel.new()
	_gate.party = _party
	add_child(_gate)
	_gate.deploy_requested.connect(_deploy)
	_panels["gate"] = _gate

	# 상점·모딩은 스태시 소유를 바꾼다 → 닫을 때 에디터 소스를 재빌드하지 않으면 deploy 동기화가
	# 옛 스냅샷으로 덮어써 유실된다(상점 패널이 과거에 정확히 이랬다).
	for p in [gear_shop, supply, _modding]:
		p.closed.connect(func() -> void:
			_stash_src.items = _build_stash_items()
			refresh_all())
	for p2 in [building, quests, skills, doctrine, _gate]:
		p2.closed.connect(refresh_all)

	# 퀘스트는 건물이 아니다(**장부**다) → 상단 바에 남긴다. 받고 맡는 일은 각 건물에서 하고,
	# 여기서는 「지금 무엇을 하고 있었나」를 훑는다. ~~시설 승급 버튼~~은 제거 — 승급은 건물에서.
	var bar: HBoxContainer = _wallet.get_parent()
	var qb := Button.new()
	qb.text = "의뢰 장부"
	qb.pressed.connect(quests.open_panel)
	bar.add_child(qb)
	var reset := Button.new()
	reset.text = "저장 초기화"
	reset.modulate = BAD
	reset.pressed.connect(_confirm_reset_save)
	bar.add_child(reset)


# --- 갱신 ----------------------------------------------------------------------

func refresh_all() -> void:
	if _party == null:
		return
	_refresh_wallet()
	_refresh_strip()
	for ch in _map_layer.get_children():
		if ch.has_meta("fid"):
			_map_layer.remove_child(ch)
			ch.queue_free()
	_build_buildings()


func _refresh_wallet() -> void:
	var carried := 0
	var charms := 0
	var bp := get_node_or_null("/root/Backpack")
	if bp != null:
		for it in bp.loose:
			match String(it.get("kind", "")):
				"manastone":
					carried += int(it.get("count", 0))
				"charm":
					charms += 1
	var stored: int = int(_stash.manastone_count()) if _stash.has_method("manastone_count") else 0
	var scrap: int = int(_hub.scrap()) if _hub != null else 0
	var vault := 0
	if _hub != null:
		for k in _hub.hub_haul_vault:
			vault += int(_hub.hub_haul_vault[k])
	_wallet.text = "   시술비 ⚙%d   ·   마석 ◈%d 반입 / %d 보관   ·   참 %d   ·   금고 재료 %d" % [
		scrap, carried, stored, charms, vault]
	_wallet.modulate = ACCENT if carried > 0 else BAD


func _refresh_strip() -> void:
	for role in ROLES:
		var c: Dictionary = _cards[role]
		var e: Dictionary = _member_entry(role)
		var gid := String(e.get("gear", ""))
		var gm: Dictionary = Slice01Data.get_gear_master(gid)
		if gm.is_empty():
			c["gear"].text = "건 미착용"
			c["gear"].modulate = BAD
			(c["panel"] as Control).tooltip_text = "[color=#ff8080]건을 착용하지 않았다 — 대장간에서 신는다[/color]"
			continue
		c["gear"].text = String(gm.get("display_name", gid))
		c["gear"].modulate = Color(1, 1, 1)
		(c["panel"] as Control).tooltip_text = _member_tip(role, gid, gm)


## 파티 카드 툴팁 — **정체성 규약 + Q/E/R + 결속 1줄**. 카드에 안 적고 여기 모은 것들이다.
## 결속은 gear × 정체성 × 슬롯의 삼중 매치라 어느 한 축만 봐서는 알 수 없다 → 한자리에서 읽힌다.
func _member_tip(role: String, gid: String, gm: Dictionary) -> String:
	var iab := _identity_ab(role)
	var sig: Dictionary = BindingOverlays.signature_for(gid, iab)
	var lines: Array = [
		"[b]%s[/b]  [color=#9aa4b2]· %s[/color]" % [String(gm.get("display_name", gid)), Slice01Data.get_role_label(role)],
		"[color=#f0b64a]정체성 — %s (%s)[/color]" % [
			String(sig.get("name", Slice01Data.get_identity_display(_identity_skill_id(role)))), iab],
	]
	if sig.has("covenant"):
		lines.append("[color=#cfe0f5]%s[/color]" % String(sig["covenant"]))
	lines.append("[color=#9aa4b2]평타 %s · 사거리대 %s[/color]" % [
		String(gm.get("basic_attack_profile_id", "—")), String(gm.get("range_band", "—"))])
	var bp := get_node_or_null("/root/Backpack")
	if bp == null:
		return "\n".join(lines)
	var open_n: int = int(bp.gear_slot_count(role))
	var slots: Array = bp.gear_slot_abilities(role)
	for j in 3:
		if j >= open_n:
			lines.append("[color=#6a6a70][%s] 잠김[/color]" % SLOT_KEY[j])
			continue
		var sd = slots[j]
		if typeof(sd) != TYPE_DICTIONARY:
			lines.append("[color=#9aa4b2][%s] 비어 있음[/color]" % SLOT_KEY[j])
			continue
		var abid := String(sd.get("base_ability_id", ""))
		var m: Dictionary = Slice01Data.get_skillbook_master(abid)
		lines.append("[b][%s] %s[/b]  [color=#b48aff]◈%d[/color]" % [SLOT_KEY[j],
			String(m.get("display_name", abid)), Slice01Data.manastone_cost_for(abid)])
		var ov: Dictionary = BindingOverlays.resolve_effective(gid, iab, abid, j)
		if not ov.is_empty():
			lines.append("   [color=#8fb4ff]└ %s[/color]" % String(ov.get("desc_ko", ov.get("payoff", "—"))))
	lines.append("[color=#6a6a70]클릭 — 대장간에서 이 건을 손본다[/color]")
	return "\n".join(lines)


# --- 조회 헬퍼 -----------------------------------------------------------------

func _member_entry(role: String) -> Dictionary:
	var bp := get_node_or_null("/root/Backpack")
	return bp.member_entry(role) if bp != null else {}


func _identity_skill_id(role: String) -> String:
	var e: Dictionary = _member_entry(role)
	var rid := String(e.get("rolled_identity", ""))
	if rid != "":
		return rid
	return String(Slice01Data.get_gear_master(String(e.get("gear", ""))).get("bundled_identity_skill_id", ""))


func _identity_ab(role: String) -> String:
	return String(Slice01Data.get_identity_row(_identity_skill_id(role)).get("ability_id", ""))


# --- 창고 · 출정 ---------------------------------------------------------------

func _open_stash() -> void:
	if _inv.is_open():
		_inv.toggle()
		_sync_stash_from_source()                 # 닫기 = 에디터 상태를 Stash에 반영(상점과 단일 SoT)
		refresh_all()
	else:
		_stash_src.items = _build_stash_items()   # 열기 = 최신 Stash(상점 구매 포함) 반영
		_inv.open_loot(_stash_src)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _inv != null and _inv.is_open():
		_inv.toggle()
		_sync_stash_from_source()   # ESC 닫기도 Stash에 반영(open 시 재빌드와 짝)
		refresh_all()


## Build the stash container items (gear 2×2, 소모품·마석·참 1×1) with grid placement, from the Stash
## autoload. **모든 항목을 표시해야** deploy 시 `_sync_stash_from_source`(에디터 = 스태시 최종 상태)가
## 표시 안 된 항목을 잃지 않는다. 넘치는 분은 `InventoryUI.loot_overflow`가 들고 있다가 되돌려 넣는다.
func _build_stash_items() -> Array:
	_stash.ensure_seeded()   # 오토로드 순서로 시드가 밀렸으면 여기서 확정(카탈로그 파생, DRIFT-139)
	var items: Array = []
	var cols: int = int(_stash_src.cols) if _stash_src != null and "cols" in _stash_src else 10
	var gear_per_row: int = maxi(1, cols / 2)   # 기어 2×2 — 위쪽 블록에 고정 배치
	var g := 0
	for i in _stash.gear.size():
		var it: Dictionary = _inv.make_gear_stash_item(_stash.gear[i])   # 인스턴스 dict(rolled/rolls 포함)
		if it.is_empty():
			continue
		@warning_ignore("integer_division")
		it["col"] = (g % gear_per_row) * 2
		@warning_ignore("integer_division")
		it["row"] = (g / gear_per_row) * 2
		items.append(it)
		g += 1
	for cid in _stash.consumables:
		var ci: Dictionary = _inv.make_consumable_stash_item(String(cid), int(_stash.consumables[cid]))
		if not ci.is_empty():
			items.append(ci)
	for mid in _stash.manastones:
		var mi: Dictionary = _inv.make_manastone_stash_item(String(mid), int(_stash.manastones[mid]))
		if not mi.is_empty():
			items.append(mi)
	for chid in _stash.charms:
		var hi: Dictionary = _inv.make_charm_stash_item(String(chid))
		if not hi.is_empty():
			items.append(hi)
	return items


## Shift+우클릭 스태시 버리기 → 소유 목록(Stash autoload)에서 영구 제거.
func _on_stash_item_discarded(item: Dictionary) -> void:
	match String(item.get("kind", "")):
		"gear":
			_stash.remove_gear(String(item.get("base_gear_id", "")))
		"consumable":
			_stash.take_consumable(String(item.get("consumable_id", "")), int(item.get("count", 1)))


func _deploy() -> void:
	_commit_run_loadout()
	if _hub != null:
		_hub.mark_run_started()   # F-020 §3.2.0 첫 런 게이트 — 출정 확정 시점에 오른다
	get_tree().change_scene_to_file(DUNGEON_SCENE)


func _commit_run_loadout() -> void:
	_sync_stash_from_source()         # 에디터에서 캐릭터/백팩으로 옮긴 소비 = 스태시에서 제거 (중복 방지)
	_inv.commit_loose_to_backpack()   # 허브 백팩 편집 → 영속 Backpack(loose, 소비 포함)
	var bp := get_node_or_null("/root/Backpack")
	if bp != null:
		bp.capture_from_party(_party)   # 허브 장착 기어 → Backpack.equipped
	var form: Array = []
	var offsets: Dictionary = _gate.get_formation_offsets()
	for cid in offsets:
		var o: Vector2 = offsets[cid]
		form.append({"class_id": String(cid), "offset": [o.x, o.y]})  # o.y holds z (forward)
	_run_loadout.formation = form
	# 난이도는 **설정하지 않는다**(M6) — `RunLoadout.get_difficulty()`가 manifest 기본값으로 폴백한다.
	# 지역·입장조건이 이 축을 가져갈 때 그 자리에 값을 넣으면 된다.


## Deploy 시 스태시 오토로드를 에디터의 최종 상태(_stash_src, 닫을 때 export됨)로 맞춘다.
func _sync_stash_from_source() -> void:
	var gear: Array = []
	var consumables: Dictionary = {}
	var manastones: Dictionary = {}
	var charms: Array = []
	# 그리드에 자리가 없어 표시되지 못한 소유분을 **먼저 되돌려 넣는다.** 이 sync는 Stash를 통째로
	# 재작성하므로, 안 보인 아이템 = 영구 삭제였다(과거 실사고).
	var src: Array = (_stash_src.items as Array).duplicate()
	src.append_array(_inv.loot_overflow())
	for it in src:
		match String(it.get("kind", "")):
			"gear":
				# 보관분만(장착=Backpack.equipped로 빠짐). F-008 §3.7 인스턴스 — 스페어도 굴린 정체성·옵션 보존.
				var gi := {"base_gear_id": String(it.get("base_gear_id", ""))}
				var rid := String(it.get("rolled_identity_skill_id", ""))
				if not rid.is_empty():
					gi["rolled_identity_skill_id"] = rid
				if it.has("rolls"):
					gi["rolls"] = it["rolls"]
				gear.append(gi)
			"consumable":
				var cid := String(it.get("consumable_id", ""))
				consumables[cid] = int(consumables.get(cid, 0)) + int(it.get("count", 1))
			"manastone":
				var mid := String(it.get("manastone_id", ""))
				manastones[mid] = int(manastones.get(mid, 0)) + int(it.get("count", 1))
			"charm":
				charms.append(String(it.get("charm_id", "")))   # 비스택 — 항목 수 = 칸 수
			_:
				# ⚠️ **모르는 kind = 조용한 삭제**였다. 이 sync는 Stash를 통째로 재작성하므로 분기가
				# 없는 종류는 그대로 증발한다 — 마석이 정확히 이랬다(M1이 런 쪽만 배선, DRIFT-145).
				# **새 아이템 종류를 추가하면 여기 + `_build_stash_items` 둘 다 봐야 한다.**
				push_warning("[TDC] 스태시 sync — 미처리 kind '%s' (소유 유실 위험)" % String(it.get("kind", "")))
	# `skillbooks`는 **넘기지 않는다** — M5에서 스태시가 스킬북을 소유하지 않으므로 빈 배열이 정본이다.
	_stash.apply_dict({"gear": gear, "consumables": consumables, "manastones": manastones, "charms": charms})
	_stash.save_stash()


## 저장 초기화 — 파괴적이라 확인 후 진행. (테스트/디버그)
func _confirm_reset_save() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "저장 초기화"
	dlg.dialog_text = "저장 데이터를 전부 초기화합니다.\n스태시·백팩·허브 메타(시설/창고/퀘스트/트리) → 데모 시드.\n되돌릴 수 없습니다. 진행할까요?"
	dlg.ok_button_text = "초기화"
	dlg.cancel_button_text = "취소"
	add_child(dlg)
	dlg.confirmed.connect(_reset_save)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered()


## SaveProfile 파일 비우기 + 각 도메인 오토로드 시드 리셋 + 마을 리로드(UI 재구성).
func _reset_save() -> void:
	var sp := get_node_or_null("/root/SaveProfile")
	if sp != null and sp.has_method("wipe"):
		sp.wipe()
	for path in ["/root/Stash", "/root/Backpack", "/root/HubProfile"]:
		var n := get_node_or_null(path)
		if n != null and n.has_method("reset_to_seed"):
			n.reset_to_seed()
	get_tree().reload_current_scene()   # 마을 재구성 — 리셋된 오토로드에서 새로 빌드
