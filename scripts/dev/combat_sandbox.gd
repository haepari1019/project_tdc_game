extends Node3D
## DEBUG combat sandbox — a one-room arena + an ENC dropdown. Spawn ANY encounter to watch its
## combat behavior in isolation (no fog, no run-loop, no traversal). Run this scene directly.
## Reuses the real PartyController / CombatController / CameraRig so behavior matches the game.
## dev tooling only — not referenced by the shipping flow. ref: ROADMAP P2 (F5 debugging).

const SandboxMap := preload("res://scripts/dev/sandbox_map.gd")
const PartyController := preload("res://scripts/party/party_controller.gd")
const CombatController := preload("res://scripts/combat/combat_controller.gd")
const CameraRig := preload("res://scripts/run/controllers/camera_rig.gd")
const PartySheet := preload("res://scripts/ui/party_sheet.gd")          # UI-002 party HP + sub radials
const ControlledSheet := preload("res://scripts/ui/controlled_sheet.gd")  # UI-003 Identity + Q/E/R cooldowns
const HazardZone := preload("res://scripts/world/hazards/hazard_zone.gd")  # S3b zone media (test laying)

# ZONE laying (S3b test): medium → spawn defaults. Fire/ToxicGas damage; movement media outcome-only
# (dps 0, tick via MOVEMENT_MEDIA); Smoke/Vegetation harmless; Fatal lethal+impassable.
const ZONE_MEDIA := ["Oil", "Fire", "Smoke", "ToxicGas", "Water", "Ice", "Steam", "Wind", "Vegetation", "Fatal"]
const ZONE_SPAWN := {
	"Fire": {"dps": 8.0}, "ToxicGas": {"dps": 8.0},
	"Fatal": {"dps": 30.0, "impassable": true},
}
const ZONE_RADIUS := 3.0

# Skillbooks auto-equipped so Q/E/R subs (incl. Toll Stun for channel-interrupt testing) work
# without the hub deploy step. slot -> base_ability_id (role gate is bypassed for the sandbox).
const SANDBOX_SUBS := {
	"Tank": ["AB-002", "AB-011", ""],     # Shield Bash, Toll Stun
	"DPS": ["AB-037", "AB-011", ""],      # Ember Lance, Toll Stun
	"Nuker": ["AB-010", "AB-037", ""],    # Venom, Ember Lance
	"Healer": ["AB-010", "AB-002", ""],   # Venom, Shield Bash
}

# Per-engage-profile one-line behavior summary (shown in the info panel; matches _engage_move).
const ENGAGE_DESC := {
	"advance": "근접까지 직진 추격 후 평타 (전선)",
	"standoff": "사거리서 hold·평타 — 적이 붙어도 도망 안 감",
	"kite": "적이 4m 안에 들면 후퇴(leash 클램프) — 거리 유지하며 사격",
	"healer": "적 근접 시 후퇴 + 무리를 따라 이동(체력 낮은 아군 우선)·힐 사거리 유지(평타 안 붙음)",
	"zone": "스폰 앵커 zone 내에서만 교전 · 타겟이 zone 밖이면 앵커 복귀",
	"orbit": "정면 아닌 측면 arc로 접근 (플랭크)",
	"probe": "평타 후 짧게 백스텝 (맞고 빠지기)",
	"surround": "타겟 둘레 링으로 포위 (여러 마리일 때)",
}

# Per-enemy 검증 체크리스트 (info 패널 우상단). 거동(engage)·기본타·시그니처는 라이브 데이터에서
# 읽고, 아래는 "이걸 눈으로 확인" 가이드.
const UNIT_VERIFY := {
	"EN-001": "• 전선 hold\n• 쿨 3s마다 AB-002 방패치기(넉백)\n• 전방 4m 파티 있으면 AB-099 도발(조작 멤버 이동·Q/E/R 잠김 + 강제 평타 + 스왑 탈출)\n• 도발 채널을 Toll Stun으로 끊으면 취소",
	"EN-002": "• 사거리서 hold·안 도망(standoff)\n• 쿨 5s마다 AB-004 1.0s 충전 → 2x 한 방 + Shock 둔화\n• BOSS-001로 띄우면 50%HP에서 충전 빨라짐 + 스턴 저항",
	"EN-003": "• 측면 arc로 접근(orbit)\n• 갭 생기면 AB-006 [청록] 대시 → 타겟 앞에 직선 갭클로즈(데미지 X, 착지링) → 평타 flurry",
	"EN-004": "• zone 고수, 타겟이 멀어지면 앵커 복귀(추격 X)\n• 쿨 2.5s마다 AB-008 착탄 splash(주변 파티원도 피해)\n• AB-009 Oil 장판(밟으면 Slippery·인화성) + AB-042 Wind 장판 설치(타겟 발밑 전조→생성)",
	"EN-005": "• 적 4m 진입 시 후퇴(kite)\n• 쿨 2s마다 AB-010 독(둔화 아님, 도트)\n• AB-039 독안개(ToxicGas) 장판 설치 — Ember로 점화 시 toxic flash",
	"EN-006": "• 때리고 짧게 빠짐(probe)\n• 쿨 5s마다 AB-011 스턴",
	"EN-007": "• 사거리 hold(standoff)\n• 쿨 4s마다 AB-012 hex 둔화(보라 룬탄)\n• AB-036 Water·AB-040 Ice·AB-043 Vegetation 장판 설치(Water→Sodden·Ice→Chilled·Veg→인화성) — Ember 연쇄 fodder\n• AB-041 cold = 배치2",
	"EN-008": "• 치고-빠지는 측면 암살자(통합 루프)\n• REPOSITION: 파티 spine(탱커↔최후열)에 수직인 '옆구리'로 standoff(6m) 유지·근접하면 burst-kite\n• STRIKE: 측면 각도+쿨 차면 AB-013 백스탭(1.5x+넉백, 크림슨) — 정면에선 안 쏨\n• RESET: 찌른 뒤 다시 빠져 측면 복귀",
	"EN-009": "• 링 포위(surround) — count 여러 개로 띄워야 의미\n• rom_swarm_nip 평타만",
	"EN-010": "• 직진 추격(advance)\n• rom_fodder_melee_tap 평타",
	"EN-011": "• 사거리서 조약돌·안 도망(standoff)\n• AssassinTransform 태그는 ENC 전용 — 단일 스폰엔 없음(NORM-003/HARD-011 ENC로 확인)",
	"EN-012": "• 느린 직진(advance)\n• HP 높은 탱키 fodder",
	"EN-013": "• 빠른 추격(advance +10%) — 다른 advance(EN-010/012)보다 눈에 띄게 빠른지",
	"EN-014": "• 적 근접 시 후퇴 + 무리를 따라 이동(체력 낮은 아군 우선, 없으면 최근접 아군) — 낙오 X\n• 혼자일 때만 hold(부들부들 X)\n• 아군 <90% HP면 AB-098 녹색 힐펄스(쿨 8s)\n• 힐 채널을 Toll Stun으로 끊기",
}

var _map: Node3D
var _party: Node3D
var _combat: Node3D
var _camera: Node3D
var _enc_dropdown: OptionButton
var _unit_dropdown: OptionButton
var _zone_dropdown: OptionButton
var _count_spin: SpinBox
var _engaged_chk: CheckBox
var _status: Label
var _formation_lbl: Label
var _info_label: RichTextLabel
var _identity_dd: OptionButton
var _sub_dd: Array = []   # [OptionButton ×3] — Q/E/R sub loadout for the controlled member
var _cam_dragging := false


func _ready() -> void:
	_build_environment()

	_map = Node3D.new()
	_map.set_script(SandboxMap)
	_map.name = "SandboxMap"
	add_child(_map)

	# PartyController needs a "Members" child before its _ready runs.
	_party = Node3D.new()
	_party.set_script(PartyController)
	_party.name = "PartyController"
	var members := Node3D.new()
	members.name = "Members"
	_party.add_child(members)
	add_child(_party)

	_combat = Node3D.new()
	_combat.set_script(CombatController)
	_combat.name = "CombatController"
	add_child(_combat)

	# CameraRig wants a $Camera3D child present when its _ready runs → add the child, set the
	# script, THEN add the pivot to the tree (so _ready sees the camera).
	_camera = Node3D.new()
	_camera.name = "CameraPivot"
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	_camera.add_child(cam)
	_camera.set_script(CameraRig)
	add_child(_camera)

	# Wire the systems exactly like dungeon_run (minus fog/HUD/run-loop).
	_combat.setup(_party, _map)
	_party.bind_combat(_combat)
	if _combat.has_signal("camera_shake"):
		_combat.camera_shake.connect(_camera.add_shake)
	_party.spawn_at(_map.get_spawn_position("SANDBOX"))
	_equip_sandbox_subs()
	_camera.set_follow_target(_party.get_controlled())
	_party.controlled_changed.connect(func(_m: Node) -> void: _camera.set_follow_target(_party.get_controlled()))

	_build_ui()


## Auto-equip a couple of looted-skill stand-ins per member so Q/E/R subs work for testing
## (esp. AB-011 Toll Stun → channel interrupt). Bypasses the role gate via direct slot set.
func _equip_sandbox_subs() -> void:
	for m in _party.get_members():
		var subs: Array = SANDBOX_SUBS.get(String(m.get("class_id")), [])
		for i in mini(subs.size(), 3):
			if String(subs[i]) != "" and m.has_method("equip_skillbook_by_id"):
				m.equip_skillbook_by_id(i, String(subs[i]))


func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(40.0), 0.0)
	sun.light_energy = 1.1
	add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.10, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.62)
	env.ambient_light_energy = 0.7
	we.environment = env
	add_child(we)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_build_game_hud(layer)      # real in-game HUD (party sheet + controlled skill cooldowns)
	_build_control_panel(layer)
	_build_info_panel(layer)


## The shipping HUD pieces that show ally skill cooldowns/charges — UI-002 PartySheet (HP + Q/E/R
## sub radials) + UI-003 ControlledSheet (Identity cooldown + Q/E/R charges/cooldown). Both
## self-build in setup() + self-update via their own _process. Consumable bar omitted (needs
## the inventory system). party sheet sits beside the dev panel; char sheet bottom-center (game).
func _build_game_hud(layer: CanvasLayer) -> void:
	var party_sheet := Control.new()
	party_sheet.set_script(PartySheet)
	party_sheet.position = Vector2(300, 16)   # right of the dev control panel (avoid overlap)
	layer.add_child(party_sheet)
	party_sheet.setup(_party.get_members())

	var ctrl_sheet := Control.new()
	ctrl_sheet.set_script(ControlledSheet)
	ctrl_sheet.anchor_left = 0.0
	ctrl_sheet.anchor_right = 1.0
	ctrl_sheet.anchor_top = 1.0
	ctrl_sheet.anchor_bottom = 1.0
	ctrl_sheet.offset_top = -140.0           # bottom strip → its CenterContainer centers = bottom-center
	ctrl_sheet.offset_bottom = -12.0
	layer.add_child(ctrl_sheet)
	ctrl_sheet.setup(_party)


## Top-LEFT control panel — ENC spawn (replace) + single-unit spawn (additive) + shared toggles.
func _build_control_panel(layer: CanvasLayer) -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(16, 16)
	box.add_theme_constant_override("separation", 5)
	layer.add_child(box)

	var title := Label.new()
	title.text = "COMBAT SANDBOX (dev)"
	box.add_child(title)

	# --- Encounter (replaces all) ---
	box.add_child(_section("ENCOUNTER (replace)"))
	_enc_dropdown = OptionButton.new()
	_enc_dropdown.custom_minimum_size = Vector2(240, 0)
	for eid in Slice01Data.get_encounter_ids():
		_enc_dropdown.add_item(String(eid))
	_enc_dropdown.item_selected.connect(func(_i: int) -> void: _refresh_info())
	box.add_child(_enc_dropdown)
	var spawn_enc := Button.new()
	spawn_enc.text = "Spawn ENC (clears first)"
	spawn_enc.pressed.connect(_on_spawn_enc)
	box.add_child(spawn_enc)

	# --- Single unit (additive) ---
	box.add_child(_section("SINGLE UNIT (add)"))
	_unit_dropdown = OptionButton.new()
	_unit_dropdown.custom_minimum_size = Vector2(240, 0)
	_unit_dropdown.add_item("(none — show ENC)")
	_unit_dropdown.set_item_metadata(0, "")
	for eid in Slice01Data.get_enemy_ids():
		var row: Dictionary = Slice01Data.get_enemy_row(String(eid))
		_unit_dropdown.add_item("%s — %s" % [eid, row.get("display_name", "?")])
		_unit_dropdown.set_item_metadata(_unit_dropdown.item_count - 1, String(eid))
	_unit_dropdown.item_selected.connect(func(_i: int) -> void: _refresh_info())
	box.add_child(_unit_dropdown)
	var row_h := HBoxContainer.new()
	var cnt_lbl := Label.new()
	cnt_lbl.text = "count"
	row_h.add_child(cnt_lbl)
	_count_spin = SpinBox.new()
	_count_spin.min_value = 1
	_count_spin.max_value = 8
	_count_spin.value = 1
	row_h.add_child(_count_spin)
	box.add_child(row_h)
	var spawn_unit := Button.new()
	spawn_unit.text = "Spawn Unit (+add)"
	spawn_unit.pressed.connect(_on_spawn_unit)
	box.add_child(spawn_unit)

	# --- shared ---
	box.add_child(_section("OPTIONS"))
	_engaged_chk = CheckBox.new()
	_engaged_chk.text = "spawn engaged (skip perception)"
	_engaged_chk.button_pressed = true
	box.add_child(_engaged_chk)
	var clear_btn := Button.new()
	clear_btn.text = "Clear all enemies"
	clear_btn.pressed.connect(_on_clear)
	box.add_child(clear_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset party (HP/status/CD)"
	reset_btn.pressed.connect(_on_reset_party)
	box.add_child(reset_btn)

	# --- ZONE (S3b: lay a medium zone at the controlled member; X ignites overlapping Oil) ---
	box.add_child(_section("ZONE (lay @ controlled — Z)"))
	_zone_dropdown = OptionButton.new()
	_zone_dropdown.custom_minimum_size = Vector2(240, 0)
	for m in ZONE_MEDIA:
		_zone_dropdown.add_item(m)
	box.add_child(_zone_dropdown)
	var lay_btn := Button.new()
	lay_btn.text = "Lay Zone (Z)"
	lay_btn.pressed.connect(_on_lay_zone)
	box.add_child(lay_btn)
	var clear_zones_btn := Button.new()
	clear_zones_btn.text = "Clear zones"
	clear_zones_btn.pressed.connect(_on_clear_zones)
	box.add_child(clear_zones_btn)

	# --- Loadout (controlled member) — swap Identity skill + Q/E/R subs for ability testing.
	# Data-driven: auto-fills from identities.json / skillbooks.json (future ABs appear here).
	box.add_child(_section("LOADOUT (controlled — 1-4)"))
	_identity_dd = OptionButton.new()
	_identity_dd.custom_minimum_size = Vector2(240, 0)
	for row in Slice01Data.get_identity_rows():
		_identity_dd.add_item("ID: %s (%s)" % [row.get("identity_skill_id", "?"), row.get("ability_id", "?")])
		_identity_dd.set_item_metadata(_identity_dd.item_count - 1, String(row.get("identity_skill_id", "")))
	_identity_dd.item_selected.connect(_on_identity_changed)
	box.add_child(_identity_dd)
	for slot in 3:
		var dd := OptionButton.new()
		dd.custom_minimum_size = Vector2(240, 0)
		dd.add_item("%s: (none)" % ["Q", "E", "R"][slot])
		dd.set_item_metadata(0, "")
		for row in Slice01Data.get_skillbook_rows():
			dd.add_item("%s: %s (%s)" % [["Q", "E", "R"][slot], row.get("display_name", "?"), row.get("base_ability_id", "?")])
			dd.set_item_metadata(dd.item_count - 1, String(row.get("base_ability_id", "")))
		dd.item_selected.connect(_on_sub_changed.bind(slot))
		box.add_child(dd)
		_sub_dd.append(dd)

	var hint := Label.new()
	hint.text = "1-4 swap · WASD · Q/E/R sub · G 진형/전투우선 · Z zone깔기 · wheel zoom · RMB-drag orbit · [ ] pitch"
	hint.add_theme_font_size_override("font_size", 11)
	box.add_child(hint)
	_formation_lbl = Label.new()
	box.add_child(_formation_lbl)
	_party.formation_priority_changed.connect(_on_formation_priority_changed)
	_on_formation_priority_changed(_party.is_formation_priority())  # initial state
	_status = Label.new()
	box.add_child(_status)

	# Loadout dropdowns track the controlled member (swap 1-4 → reflect that member's loadout).
	_party.controlled_changed.connect(func(_m: Node) -> void: _refresh_loadout_ui())
	_refresh_loadout_ui()


## Top-RIGHT info panel — selected single unit's behavior + 검증 체크리스트 (or ENC composition).
func _build_info_panel(layer: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -396.0
	panel.offset_right = -16.0
	panel.offset_top = 16.0
	layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content = true
	_info_label.custom_minimum_size = Vector2(360, 0)
	margin.add_child(_info_label)
	_refresh_info()


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = "── %s ──" % text
	l.add_theme_font_size_override("font_size", 11)
	l.modulate = Color(0.7, 0.85, 1.0)
	return l


func _on_spawn_enc() -> void:
	if _enc_dropdown.selected < 0:
		return
	var eid := _enc_dropdown.get_item_text(_enc_dropdown.selected)
	_combat.debug_spawn_only(eid, "SANDBOX", _engaged_chk.button_pressed)
	_status.text = "ENC: %s%s" % [eid, "  (engaged)" if _engaged_chk.button_pressed else "  (dormant)"]


func _on_spawn_unit() -> void:
	var eid := _selected_unit_id()
	if eid == "":
		return
	_combat.debug_spawn_unit(eid, int(_count_spin.value), "SANDBOX", _engaged_chk.button_pressed)
	_status.text = "+%d × %s" % [int(_count_spin.value), eid]


func _on_clear() -> void:
	_combat.debug_spawn_only("", "SANDBOX")
	_status.text = "cleared"


func _on_reset_party() -> void:
	for m in _party.get_members():
		if m.has_method("debug_reset"):
			m.debug_reset()
	_refresh_loadout_ui()
	_status.text = "party reset — full HP, status/CD cleared"


func _on_formation_priority_changed(on: bool) -> void:
	if _formation_lbl != null:
		_formation_lbl.text = "[G] %s" % ("진형우선" if on else "전투우선")


## Lay the selected medium zone at the controlled member (S3b test). Outcome applies on contact.
func _on_lay_zone() -> void:
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl == null:
		return
	var medium: String = ZONE_MEDIA[_zone_dropdown.selected] if _zone_dropdown != null else "Fire"
	var preset: Dictionary = ZONE_SPAWN.get(medium, {})
	var z := HazardZone.new()
	z.setup(ZONE_RADIUS, float(preset.get("dps", 0.0)), 0.0, medium, bool(preset.get("impassable", false)), -1.0)
	_map.add_child(z)
	z.global_position = ctrl.global_position
	_status.text = "zone: %s @ controlled (r%.0f)" % [medium, ZONE_RADIUS]


func _on_clear_zones() -> void:
	for z in get_tree().get_nodes_in_group("ground_zone"):
		if z.has_method("clear_zone"):
			z.clear_zone()
	_status.text = "zones cleared"


func _on_identity_changed(index: int) -> void:
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl == null or not ctrl.has_method("debug_set_identity"):
		return
	var iid := String(_identity_dd.get_item_metadata(index))
	ctrl.debug_set_identity(iid)
	_status.text = "%s identity → %s" % [ctrl.get("class_id"), iid]


func _on_sub_changed(index: int, slot: int) -> void:
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl == null:
		return
	var aid := String(_sub_dd[slot].get_item_metadata(index))
	if aid == "":
		ctrl.set_skillbook(slot, null)
	else:
		ctrl.equip_skillbook_by_id(slot, aid)
	_status.text = "%s slot %s → %s" % [ctrl.get("class_id"), ["Q", "E", "R"][slot], aid if aid != "" else "(none)"]


## Reflect the CONTROLLED member's current identity + Q/E/R subs in the loadout dropdowns
## (so swapping 1-4 shows that member's loadout). Selection-only — does not re-apply.
func _refresh_loadout_ui() -> void:
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl == null or _identity_dd == null:
		return
	var cur_id := String(ctrl.get("identity_skill_id"))
	for i in _identity_dd.item_count:
		if String(_identity_dd.get_item_metadata(i)) == cur_id:
			_identity_dd.select(i)
			break
	for slot in 3:
		var inst = ctrl.get_skillbook(slot)
		var cur_sub := String(inst.get("base_ability_id", "")) if inst != null else ""
		var dd: OptionButton = _sub_dd[slot]
		for i in dd.item_count:
			if String(dd.get_item_metadata(i)) == cur_sub:
				dd.select(i)
				break


func _selected_unit_id() -> String:
	if _unit_dropdown == null or _unit_dropdown.selected < 0:
		return ""
	return String(_unit_dropdown.get_item_metadata(_unit_dropdown.selected))


## Refresh the right panel: detailed single-unit behavior+verify, else ENC composition.
func _refresh_info() -> void:
	if _info_label == null:
		return
	var uid := _selected_unit_id()
	if uid != "":
		_info_label.text = _unit_info_text(uid)
	else:
		_info_label.text = _enc_info_text()


func _unit_info_text(eid: String) -> String:
	var row: Dictionary = Slice01Data.get_enemy_row(eid)
	var pat: Dictionary = Slice01Data.get_pattern(String(row.get("pattern_ref", "")))
	var engage := String(pat.get("engage", "?"))
	var sigs: Array = []
	for ab in row.get("abilities", []):
		if typeof(ab) == TYPE_DICTIONARY:
			var aref := String(ab.get("ref", "?"))
			var acd := float(Slice01Data.get_ability(aref).get("cooldown_s", 0.0))
			sigs.append("%s(cd%.1fs)" % [aref, acd])
	var stats: Dictionary = row.get("stats", {})
	var t := "[b]%s — %s[/b]\n" % [eid, row.get("display_name", "?")]
	t += "role [b]%s[/b] · pattern [b]%s → %s[/b]\n" % [row.get("role", "?"), row.get("pattern_ref", "?"), engage]
	t += "기본타: %s · range %.1fm · int %.1fs · hp %d\n" % [row.get("basic_attack", "?"), stats.get("attack_range_m", 0.0), stats.get("attack_interval_s", 0.0), int(stats.get("hp", 0))]
	t += "시그니처: %s\n" % ("· ".join(sigs) if not sigs.is_empty() else "없음")
	t += "[color=#9fd]거동:[/color] %s\n" % ENGAGE_DESC.get(engage, "?")
	t += "\n[color=#fd9][b]검증 대상[/b][/color]\n%s" % UNIT_VERIFY.get(eid, "(없음)")
	return t


func _enc_info_text() -> String:
	if _enc_dropdown == null or _enc_dropdown.selected < 0:
		return "[i]단일 유닛을 고르면 거동·검증이 여기 표시됩니다.[/i]"
	var enc := Slice01Data.get_encounter(_enc_dropdown.get_item_text(_enc_dropdown.selected))
	var t := "[b]%s[/b]  (%s)\n" % [enc.get("encounter_id", "?"), enc.get("difficulty_profile", "?")]
	for u in enc.get("units", []):
		var row: Dictionary = Slice01Data.get_enemy_row(String(u.get("enemy_id", "")))
		var pat: Dictionary = Slice01Data.get_pattern(String(row.get("pattern_ref", "")))
		var tags := ""
		if u.get("assassin", false): tags += " [color=#f88][ASSASSIN][/color]"
		if u.get("boss", false): tags += " [color=#fc8][BOSS][/color]"
		t += "• %d× %s (%s)%s\n" % [int(u.get("count", 1)), u.get("enemy_id", "?"), pat.get("engage", "?"), tags]
	var reinf: Dictionary = enc.get("reinforcement", {})
	if not reinf.is_empty():
		t += "[color=#f99]증원[/color] %s %ss: " % [reinf.get("direction", "rear"), reinf.get("delay_s", "?")]
		for u in reinf.get("units", []):
			t += "%d×%s " % [int(u.get("count", 1)), u.get("enemy_id", "?")]
		t += "\n"
	t += "\n[i]단일 유닛 드롭다운을 고르면 그 유닛의 검증 체크리스트가 뜹니다.[/i]"
	return t


# --- minimal input (swap + camera) — mirrors dungeon_run's forwarding ---
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_camera.zoom(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_camera.zoom(-1)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_cam_dragging = event.pressed
	if event is InputEventMouseMotion and _cam_dragging:
		_camera.orbit_yaw(event.relative.x)
		_camera.pitch_by_drag(event.relative.y)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _party.try_swap_to(0)
			KEY_2: _party.try_swap_to(1)
			KEY_3: _party.try_swap_to(2)
			KEY_4: _party.try_swap_to(3)
			KEY_BRACKETLEFT: _camera.adjust_pitch(-3.0)
			KEY_BRACKETRIGHT: _camera.adjust_pitch(3.0)
			KEY_Q: _cast_sub(0)
			KEY_E: _cast_sub(1)
			KEY_R: _cast_sub(2)
			KEY_G: _party.toggle_formation_priority()  # 전투우선 ↔ 진형우선 (game parity)
			KEY_Z: _on_lay_zone()   # lay selected medium zone @ controlled


func _cast_sub(slot: int) -> void:
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl == null or not ctrl.is_alive() or ctrl.is_stunned():
		return
	if ctrl.has_method("is_provoked") and ctrl.is_provoked():
		return
	_combat.cast_skillbook(ctrl, slot, ctrl.global_position)
