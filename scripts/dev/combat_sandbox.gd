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
const Torch := preload("res://scripts/world/objects/torch.gd")  # ENT-TORCH — PAT-003 EN-010 bearer test
const AimMarker := preload("res://scripts/ui/aim_marker.gd")              # 지면-타겟 서브 조준(던전 parity)
const AimController := preload("res://scripts/run/controllers/aim_controller.gd")
const SkillVfx := preload("res://scripts/combat/abilities/skill_vfx.gd")  # 평타 archetype 조회(검증 패널)

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
	"EN-007": "• 사거리 hold(standoff)\n• 쿨 4s마다 AB-012 hex 둔화(보라 룬탄)\n• AB-036 Water·AB-040 Ice·AB-043 Vegetation 장판 설치\n• AB-041 Glacial Bolt(cyan, Chilled) → 자기 Water에 맞히면 Ice 결빙, Veg면 frostbite. Ember(불)면 Water→증기·Veg→점화",
	"EN-008": "• 치고-빠지는 측면 암살자(통합 루프)\n• REPOSITION: 파티 spine(탱커↔최후열)에 수직인 '옆구리'로 standoff(6m) 유지·근접하면 burst-kite\n• STRIKE: 측면 각도+쿨 차면 AB-013 백스탭(1.5x+넉백, 크림슨) — 정면에선 안 쏨\n• RESET: 찌른 뒤 다시 빠져 측면 복귀",
	"EN-009": "• 링 포위(surround) — count 여러 개로 띄워야 의미\n• rom_swarm_nip 평타만",
	"EN-010": "• 직진 추격(advance)\n• rom_fodder_melee_tap 평타",
	"EN-011": "• 사거리서 조약돌·안 도망(standoff)\n• AssassinTransform 태그는 ENC 전용 — 단일 스폰엔 없음(NORM-003/HARD-011 ENC로 확인)",
	"EN-012": "• 느린 직진(advance)\n• HP 높은 탱키 fodder",
	"EN-013": "• 빠른 추격(advance +10%) — 다른 advance(EN-010/012)보다 눈에 띄게 빠른지",
	"EN-014": "• 적 근접 시 후퇴 + 무리를 따라 이동(체력 낮은 아군 우선, 없으면 최근접 아군) — 낙오 X\n• 혼자일 때만 hold(부들부들 X)\n• 아군 <90% HP면 AB-098 녹색 힐펄스(쿨 8s)\n• 힐 채널을 Toll Stun으로 끊기",
}

# Identity 검증 — 의도된 효과 + 눈으로 확인할 포인트 (effect kind 기준; identity_params.kind로 조회).
# 의도대로 구현됐는지 우측 패널에서 보고 → 실제 거동과 대조. ref: 각 effects/*.gd · DRIFT-056.
const IDENTITY_VERIFY := {
	"anchor_guard": "주변 잡몹에 위협 펄스 + 자신에 보호막 돔.\n• [파랑] 지면 펄스 + 보호막 돔이 뜸\n• 주변 적 어그로가 이 탱커로 쏠림",
	"beacon_threat": "근접 적에 강한 위협 고정(threat floor) + 보호막(적 수만큼↑).\n• 적이 이 탱커에 붙어 안 떨어짐(엘리트 홀드)\n• 보호막 게이지 + [파랑] 펄스",
	"march_advance": "최근접 적 향해 짧게 전진 + 전방 콘 넉백 + 경뎀.\n• 탱커가 앞으로 훅 이동\n• 정면 부채꼴 적 밀쳐냄(knockback) + [청회색] 텔레그래프",
	"sentinel_form": "거북이 태세 — 받는 피해 감소(DR) + 이동 잠김(Rooted). 6m 내 적 있을 때만 발동.\n• HP가 평소보다 훨씬 천천히 깎임\n• 제자리 고정(이동 X) + [파랑] 펄스\n• (스펙 40% 반사는 미구현 — DRIFT-056)",
	"press_line": "전방 [청록] 콘 플래시 — 직선 범위 딜.\n• 전방 부채꼴로 여러 적 동시 타격",
	"mark_ruin": "타겟에 [보라] 수직 빔 + 임팩트 버스트 — 단일 마킹 누킹.\n• 단일 타겟에 보라 빔/버스트",
	"arc_line": "최근접 적 향해 좁은 관통선 다단히트.\n• [하늘색] 직선이 여러 적 관통(최대 max_hits만큼)",
	"flank_dash": "최근접 적으로 대시 후 다단 버스트.\n• [크림슨] 적에게 순간 접근(대시)\n• hits회 연타 + 카메라 셰이크",
	"mend_circle": "[녹색] 지면 펄스 — 범위 힐(체력 낮은 아군 우선).\n• 녹색 펄스 후 주변 아군 HP 회복",
	"ward_shield": "가장 다친 아군에 보호막 + 디버프 1개 클렌즈. 전투 중(10m 내 적)만.\n• 다친 아군에 보호막 게이지\n• 상태이상 1개 제거(클렌즈)",
}
# 평타 검증 — ba 아키타입 shape별 기대 VFX (skill_vfx _BA_VFX와 1:1).
const BASIC_SHAPE_DESC := {
	"bolt": "둥근 투사체가 타겟으로 날아가 작게 임팩트",
	"lance": "얇은 직선 섬광이 즉시 관통",
	"sweep": "전방에 납작한 부채 스와이프",
	"pulse": "타겟에 작은 지면 링 확산",
	"thrust": "타겟에 짧은 쐐기 찌르기",
	"bash": "타겟에 둔탁한 납작 팝(지면 링 없음)",
	"hook": "타겟→자신으로 수축하는 선(끌어당김)",
	"stomp": "지면 링 + 먼지 튐",
}
const BASIC_TINT_DESC := {
	"physical": "강철/흰", "fire": "주황", "electric": "청색",
	"arcane": "보라", "frost": "하늘", "holy": "녹/금",
}

var _map: Node3D
var _party: Node3D
var _combat: Node3D
var _camera: Node3D
var _aim: MeshInstance3D       # AimMarker (지면-타겟 서브 조준 디스크)
var _aim_ctrl: Node            # AimController (조준 모달)
var _enc_dropdown: OptionButton
var _unit_dropdown: OptionButton
var _zone_dropdown: OptionButton
var _count_spin: SpinBox
var _engaged_chk: CheckBox
var _third_chk: CheckBox   # 스폰 유닛을 Third 진영으로 (진영전 테스트)
var _status: Label
var _formation_lbl: Label
var _cohesion_lbl: Label
var _info_label: RichTextLabel
var _identity_dd: OptionButton
var _basic_dd: OptionButton   # 평타(basic) archetype — gear's basic half only (OFF = 평타 끔)
var _sub_dd: Array = []   # [OptionButton ×3] — Q/E/R sub loadout for the controlled member
var _gear_dd: OptionButton   # Identity Gear swap (equips onto the matching-role member — F-008)
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
	# Skillbook ground-target aim (dungeon_run parity) — targeted 서브는 발밑이 아니라 조준 지점에 시전.
	_aim = AimMarker.new()
	add_child(_aim)
	_aim_ctrl = AimController.new()
	add_child(_aim_ctrl)
	_aim_ctrl.setup(_aim, _combat)
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
	spawn_enc.pressed.connect(_on_spawn_enc.bind(false))
	box.add_child(spawn_enc)
	var add_enc := Button.new()
	add_enc.text = "ENC 추가 (+, 진영전 테스트)"   # clear 없이 추가 — 일반 ENC + ENC-3RD 둘 다 스폰
	add_enc.pressed.connect(_on_spawn_enc.bind(true))
	box.add_child(add_enc)

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
	_third_chk = CheckBox.new()
	_third_chk.text = "Third 진영"   # 체크 시 이 유닛을 3세력으로 — 일반 적과 실시간 교전(F-028)
	row_h.add_child(_third_chk)
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
	var torch_btn := Button.new()
	torch_btn.text = "Lay Torch (north) — PAT-003 EN-010 test"
	torch_btn.pressed.connect(_on_lay_torch)
	box.add_child(torch_btn)

	# --- RAMPART (투사체 delivery 흡수 테스트, DRIFT-059) — 앞에 벽 + 북쪽 적 + Q/E 로드아웃 세팅 ---
	box.add_child(_section("RAMPART (투사체 흡수 테스트)"))
	var rampart_btn := Button.new()
	rampart_btn.text = "Rampart 테스트 (Q=벽 / E=Longshot 투사체)"
	rampart_btn.pressed.connect(_on_rampart_test)
	box.add_child(rampart_btn)

	# --- GEAR SWAP (F-008) — pick a gear → equips onto its matching-role member (REAL equip_gear:
	# gear → bundled identity → stats/skill), setting BOTH 평타+identity to the gear defaults. Pick
	# (none) to UNEQUIP the controlled member so 평타/Identity below can be chosen independently.
	box.add_child(_section("GEAR (평타+ID 묶음 / none=분리)"))
	_gear_dd = OptionButton.new()
	_gear_dd.custom_minimum_size = Vector2(240, 0)
	_gear_dd.add_item("(none) — 장착 해제 (평타/ID 따로)")
	_gear_dd.set_item_metadata(0, "")
	for row in Slice01Data.get_gear_rows():
		var cls := String((row.get("equip_classes", ["?"]) as Array)[0])
		_gear_dd.add_item("%s [%s] → %s" % [row.get("display_name", "?"), cls, row.get("bundled_identity_skill_id", "?")])
		_gear_dd.set_item_metadata(_gear_dd.item_count - 1, String(row.get("base_gear_id", "")))
	_gear_dd.item_selected.connect(_on_gear_changed)
	box.add_child(_gear_dd)

	# --- Loadout (controlled member · 1-4) — 평타 / Identity each independently selectable (or OFF),
	# so either channel can be verified alone. Picking a GEAR above sets both; here you split them.
	# (OFF = that channel disabled for THIS member; 전체 buttons below do all members at once.)
	box.add_child(_section("LOADOUT (controlled — 1-4)"))
	# 평타 — pick a gear's basic archetype (damage/CD/range + VFX), or OFF. Basic-only (no identity).
	_basic_dd = OptionButton.new()
	_basic_dd.custom_minimum_size = Vector2(240, 0)
	_basic_dd.add_item("평타: (OFF)")
	_basic_dd.set_item_metadata(0, "")
	for row in Slice01Data.get_gear_rows():
		var lbl := "평타: %s" % row.get("display_name", "?")
		if row.has("basic_damage"):
			lbl += " (%d/%.1fs/%.1fm)" % [int(row.get("basic_damage", 0)), float(row.get("basic_interval_s", 1.0)), float(row.get("basic_range_m", 2.0))]
		_basic_dd.add_item(lbl)
		_basic_dd.set_item_metadata(_basic_dd.item_count - 1, String(row.get("base_gear_id", "")))
	_basic_dd.item_selected.connect(_on_basic_changed)
	box.add_child(_basic_dd)
	# Identity — pick an identity skill, or OFF (basic-only). No role gate (debug).
	_identity_dd = OptionButton.new()
	_identity_dd.custom_minimum_size = Vector2(240, 0)
	_identity_dd.add_item("ID: (OFF)")
	_identity_dd.set_item_metadata(0, "")
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

	# --- 전체 적용 (all members at once) — turn a channel ON/OFF for the WHOLE party in one click.
	# Verify-one workflow: 전체 OFF, swap to the member, turn its channel back ON via the dropdown.
	box.add_child(_section("전체 적용 (검증)"))
	var basic_row := HBoxContainer.new()
	basic_row.add_child(_btn("평타 전체 ON", _set_all_basic.bind(true)))
	basic_row.add_child(_btn("평타 전체 OFF", _set_all_basic.bind(false)))
	box.add_child(basic_row)
	var id_row := HBoxContainer.new()
	id_row.add_child(_btn("ID 전체 ON", _set_all_identity.bind(true)))
	id_row.add_child(_btn("ID 전체 OFF", _set_all_identity.bind(false)))
	box.add_child(id_row)

	var hint := Label.new()
	hint.text = "1-4 swap · WASD · Q/E/R sub · G 진형/전투우선 · U 결속/비결속 · Z zone깔기 · wheel zoom · RMB-drag orbit · [ ] pitch"
	hint.add_theme_font_size_override("font_size", 11)
	box.add_child(hint)
	_formation_lbl = Label.new()
	box.add_child(_formation_lbl)
	_party.formation_priority_changed.connect(_on_formation_priority_changed)
	_on_formation_priority_changed(_party.is_formation_priority())  # initial state
	_cohesion_lbl = Label.new()
	box.add_child(_cohesion_lbl)
	_party.cohesion_changed.connect(_on_cohesion_changed)
	_on_cohesion_changed(0)  # initial state (reads _party.is_unbound(), arg ignored)
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


func _on_spawn_enc(additive: bool = false) -> void:
	if _enc_dropdown.selected < 0:
		return
	var eid := _enc_dropdown.get_item_text(_enc_dropdown.selected)
	# Patrol/AmbushHold only read while DORMANT — engaged "skip perception" would bypass the whole
	# placement behavior. Force dormant for those so the patrol loop / ambush spring is observable.
	var placement := String(Slice01Data.get_encounter(eid).get("placement_behavior", "Fixed"))
	var is_placement := placement == "Patrol" or placement == "AmbushHold"
	var engaged: bool = _engaged_chk.button_pressed and not is_placement
	# additive=true → clear 안 함 (일반 ENC + ENC-3RD 둘 다 스폰해 진영전 관찰, F-028).
	_combat.debug_spawn_only(eid, "SANDBOX", engaged, additive)
	var hint := "  (engaged)" if engaged else "  (dormant — 북쪽으로 걸어가 트리거)"
	if is_placement:
		hint = "  [%s] dormant — 북쪽으로 접근" % placement
	_status.text = "%s%s%s" % ["+ENC: " if additive else "ENC: ", eid, hint]


func _on_spawn_unit() -> void:
	var eid := _selected_unit_id()
	if eid == "":
		return
	var fac := "Third" if _third_chk.button_pressed else "Dungeon"
	_combat.debug_spawn_unit(eid, int(_count_spin.value), "SANDBOX", _engaged_chk.button_pressed, fac)
	_status.text = "+%d × %s [%s]" % [int(_count_spin.value), eid, fac]


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


## F-003 §3.4 cohesion (U) — 파티결속(BOUND, 슬롯 추종) ↔ 파티비결속(UNBOUND, 자유 산개). game parity.
func _on_cohesion_changed(_mode: int) -> void:
	if _cohesion_lbl != null:
		_cohesion_lbl.text = "[U] %s" % ("파티비결속" if _party.is_unbound() else "파티결속")


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


## Lay a lit, carriable torch in the enemy spawn area (north) so a PAT-003 torch bearer (EN-010,
## interacts_with_objects) seeks + picks it up + throws once engaged. ENT-TORCH (F-021 §3.1.2).
func _on_lay_torch() -> void:
	var t := Torch.new()
	t.position = _map.get_deep_spawn_position("SANDBOX") + Vector3(2.0, 0.0, 0.0)
	_map.add_child(t)
	if t.has_method("setup"):
		t.setup(_combat)  # wires ignite_at so the thrown torch lands as FireDamageHit
	_status.text = "Torch laid @ north — spawn ENC-PAT-003 (dormant) + 접근 → EN-010 픽업/투척"


## Projectile delivery test (DRIFT-059 Phase 1) — faction-correct: an ENEMY-owned Rampart blocks the
## player's shot (your own wall would NOT — RP-02). Q = AB-034 (your own wall: your shots PASS through),
## E = AB-056 Longshot (delivery=projectile). Aim E through the ENEMY wall → absorbed (blue flash);
## summon your wall (Q) and aim E through IT → passes (friendly).
func _on_rampart_test() -> void:
	_on_clear()
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl == null:
		return
	if ctrl.has_method("equip_skillbook_by_id"):
		ctrl.equip_skillbook_by_id(0, "AB-034")   # Q = your own Rampart (friendly — your shots pass)
		ctrl.equip_skillbook_by_id(1, "AB-056")   # E = Longshot Bolt (delivery=projectile)
	_refresh_loadout_ui()
	_combat.debug_spawn_unit("EN-012", 1, "SANDBOX", false, "Dungeon")   # stationary north target
	# Pre-place a persistent ENEMY-OWNED Rampart ~6 m ahead (hostile to the player → absorbs the shot).
	# Owner = a spawned enemy so blocks_projectile_from(player) = true. duration/hp bumped for the test.
	var enemies := get_tree().get_nodes_in_group("enemy")
	var owner: Node = enemies[0] if not enemies.is_empty() else null
	var disp = _combat.get("_ability_dispatch")
	if disp != null and owner != null and disp.has_method("spawn_barrier"):
		var params: Dictionary = Slice01Data.get_skillbook_master("AB-034").get("cast", {}).duplicate()
		params["duration_s"] = 120.0
		params["barrier_hp"] = 9999.0
		var pos: Vector3 = _map.get_spawn_position("SANDBOX") + Vector3(0.0, 0.0, 6.0)
		disp.spawn_barrier(owner, pos, Vector3(0, 0, 1), params)   # facing N/S — blocks the northward shot
	_status.text = "Rampart 테스트 — 앞 6m는 [적] 벽. E(Longshot)를 북/적 조준 → 적 벽에 흡수(파란 플래시). Q로 [내] 벽 소환 후 E → 내 샷은 통과(아군 벽). 벽 옆 조준 → 적 명중."


## Identity channel for the controlled member: pick an identity (on) or OFF (identity_enabled=false,
## value kept). Independent of 평타 — lets you watch the Identity skill with basic attacks off.
func _on_identity_changed(index: int) -> void:
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl == null:
		return
	var iid := String(_identity_dd.get_item_metadata(index))
	if iid == "":
		ctrl.identity_enabled = false
	else:
		if ctrl.has_method("debug_set_identity"):
			ctrl.debug_set_identity(iid)
		ctrl.identity_enabled = true
	_status.text = "%s Identity → %s" % [ctrl.get("class_id"), iid if iid != "" else "OFF"]
	_show_loadout_verify(ctrl)


## 평타 channel for the controlled member: apply a gear's basic half (on) or OFF (basic_enabled=false).
## Basic-only — does NOT touch the Identity skill, so 평타 can be verified alone.
func _on_basic_changed(index: int) -> void:
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl == null:
		return
	var gid := String(_basic_dd.get_item_metadata(index))
	if gid == "":
		ctrl.basic_enabled = false
		_status.text = "%s 평타 → OFF" % ctrl.get("class_id")
		_show_loadout_verify(ctrl)
		return
	var master: Dictionary = Slice01Data.get_gear_master(gid)
	if not master.is_empty() and ctrl.has_method("debug_set_basic_from_gear"):
		ctrl.debug_set_basic_from_gear(master)
	_status.text = "%s 평타 → %s (dmg%d/int%.1f/r%.1f)" % [
		ctrl.get("class_id"), master.get("display_name", gid),
		int(ctrl.get("basic_damage")), float(ctrl.get("basic_interval_s")), float(ctrl.get("basic_range_m"))]
	_show_loadout_verify(ctrl)


## GEAR — pick a gear → equip onto its matching-role member (binds 평타+identity to gear defaults,
## both channels re-enabled). (none) → unequip the CONTROLLED member so the two can be split below.
func _on_gear_changed(index: int) -> void:
	var gid := String(_gear_dd.get_item_metadata(index))
	if gid == "":
		var ctrl: CharacterBody3D = _party.get_controlled()
		if ctrl != null and ctrl.has_method("unequip_gear"):
			ctrl.unequip_gear()
			_status.text = "%s gear 해제 — 평타/Identity 따로 선택 가능" % ctrl.get("class_id")
			_refresh_loadout_ui()
			_show_loadout_verify(ctrl)
		return
	var master: Dictionary = Slice01Data.get_gear_master(gid)
	if master.is_empty():
		return
	for m in _party.get_members():
		if m != null and is_instance_valid(m) and m.has_method("can_equip_gear") and m.can_equip_gear(master):
			m.equip_gear(master)
			_status.text = "%s gear → %s | id %s hp%d/dmg%d/r%.1f" % [
				m.get("class_id"), master.get("display_name", gid), m.get("identity_skill_id"),
				int(m.get("max_hp")), int(m.get("basic_damage")), float(m.get("basic_range_m"))]
			_refresh_loadout_ui()
			_show_loadout_verify(m)   # 방금 장착된 멤버의 평타+Identity 검증 표시
			return
	_status.text = "장착 가능한 멤버 없음: %s" % gid


## Small button factory (전체 적용 row).
func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


## Show a member's loadout-verification text in the RIGHT info panel (loadout 선택 시 호출).
func _show_loadout_verify(m: CharacterBody3D) -> void:
	if _info_label != null:
		_info_label.text = _loadout_verify_text(m)


## Right-panel verification text — 평타(VFX shape/tint/수치) + Identity(의도 효과·검증 포인트·라이브
## params). "의도대로 구현됐나"를 우측에서 보고 실제 거동과 대조하기 위함. ref: effects/*.gd · DRIFT-056.
func _loadout_verify_text(m: CharacterBody3D) -> String:
	if m == null or not is_instance_valid(m):
		return "[i]조작 멤버 없음[/i]"
	var t := "[b]LOADOUT 검증 — %s (%s)[/b]\n" % [m.get("identity_skill_id"), m.get("class_id")]
	# 평타
	t += "\n[color=#9fd][b]평타[/b][/color]  "
	if not bool(m.get("basic_enabled")):
		t += "[color=#f99]OFF[/color] (identity 검증용)\n"
	else:
		var prof := String(m.get("basic_attack_profile_id"))
		t += "%s\n  dmg %d · 간격 %.2fs · 사거리 %.1fm\n" % [
			prof, int(m.get("basic_damage")), float(m.get("basic_interval_s")), float(m.get("basic_range_m"))]
		var arc: Array = SkillVfx.basic_archetype(prof)
		if arc.is_empty():
			t += "  [color=#aaa]VFX 미매핑(폴백)[/color]\n"
		else:
			t += "  VFX: [b]%s[/b](%s색) — %s\n" % [
				arc[0], BASIC_TINT_DESC.get(String(arc[1]), "?"), BASIC_SHAPE_DESC.get(String(arc[0]), "?")]
	# Identity
	t += "\n[color=#fd9][b]Identity[/b][/color]  "
	if not bool(m.get("identity_enabled")):
		t += "[color=#f99]OFF[/color] (평타 검증용)\n"
	else:
		var p: Dictionary = m.get("identity_params")
		var kind := String(p.get("kind", ""))
		if kind == "":
			t += "(없음)\n"
		else:
			t += "%s · kind %s\n%s\n" % [m.get("ability_id"), kind, IDENTITY_VERIFY.get(kind, "(설명 없음)")]
			var parts: Array = []
			for k in p.keys():
				if String(k) != "kind":
					parts.append("%s=%s" % [k, p[k]])
			t += "[color=#888]params: %s[/color]" % (", ".join(parts) if not parts.is_empty() else "(없음)")
	return t


## 전체 — set basic_enabled for ALL members (verify-one: OFF all, then re-enable one via the dropdown).
func _set_all_basic(on: bool) -> void:
	for m in _party.get_members():
		if m != null and is_instance_valid(m):
			m.basic_enabled = on
	_refresh_loadout_ui()
	_status.text = "전체 평타 %s" % ("ON" if on else "OFF")


## 전체 — set identity_enabled for ALL members.
func _set_all_identity(on: bool) -> void:
	for m in _party.get_members():
		if m != null and is_instance_valid(m):
			m.identity_enabled = on
	_refresh_loadout_ui()
	_status.text = "전체 Identity %s" % ("ON" if on else "OFF")


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
	# Identity dd: OFF (index 0) when disabled, else the item matching the member's identity.
	var id_sel := 0
	if bool(ctrl.get("identity_enabled")):
		var cur_id := String(ctrl.get("identity_skill_id"))
		for i in range(1, _identity_dd.item_count):
			if String(_identity_dd.get_item_metadata(i)) == cur_id:
				id_sel = i
				break
	_identity_dd.select(id_sel)
	# 평타 dd: OFF when disabled, else the gear whose basic profile matches the member's.
	if _basic_dd != null:
		var b_sel := 0
		if bool(ctrl.get("basic_enabled")):
			var prof := String(ctrl.get("basic_attack_profile_id"))
			for i in range(1, _basic_dd.item_count):
				var gid := String(_basic_dd.get_item_metadata(i))
				if String(Slice01Data.get_gear_master(gid).get("basic_attack_profile_id", "")) == prof:
					b_sel = i
					break
		_basic_dd.select(b_sel)
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
	# 조준 모달이 켜져 있으면 좌클릭=지면 시전, Esc=취소 (RMB는 카메라 orbit 유지).
	if _aim_ctrl != null and _aim_ctrl.is_active():
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).pressed:
			_aim_ctrl.handle_click(event)
			return
		if event.is_action_pressed("ui_cancel"):
			_aim_ctrl.cancel()
			return
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
			KEY_U: _party.toggle_cohesion_mode()       # 파티결속 ↔ 비결속 (F-003 §3.4, game parity)
			KEY_Z: _on_lay_zone()   # lay selected medium zone @ controlled


func _cast_sub(slot: int) -> void:
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl == null or not ctrl.is_alive() or ctrl.is_stunned():
		return
	if ctrl.has_method("is_provoked") and ctrl.is_provoked():
		return
	if ctrl.has_method("is_channeling") and ctrl.is_channeling():
		return  # Channeling (AB-054 Rending Beam) — busy until the channel finishes
	var inst = ctrl.get_skillbook(slot)
	if inst == null:
		return
	if int(inst.charges) <= 0 or float(inst.cooldown_s) > 0.0:
		return
	# Targeted 서브(DPS lunge / Nuker nova 등) → 조준 모달(좌클릭=지면 시전, Esc=취소). 그 외 = 발밑 즉발.
	if bool(inst.params.get("targeted", false)):
		_aim_ctrl.start_aim(ctrl, slot, inst)
	else:
		_combat.cast_skillbook(ctrl, slot, ctrl.global_position)
