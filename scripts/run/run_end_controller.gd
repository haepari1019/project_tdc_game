extends Node
## Run end flow (F-007) — owns the ExtractionActivate hold-channel + cohesion gate (§3.6.2) +
## party-wipe detection (§3.7.1) + settlement composition (§3.6/§3.7). Drives itself each frame;
## on success/failure it composes the summary and calls run_controller.settle_*. Emits
## party_alert for the HUD banner. setup() then it runs autonomously.

signal party_alert(text: String, level: int)

# Hold at the extraction point this long to complete. Longer while partyInCombat. Channel time
# is "후속 UI/전투 SSOT" in F-007 §3.1.2 → tuning (game SPEC_DRIFT).
const EXTRACT_HOLD_S := 5.0          # 비전투
const EXTRACT_HOLD_COMBAT_S := 30.0  # 전투중(partyInCombat)
const EXTRACT_RADIUS_M := 3.0
## F-007 §3.6.2 extractionCohesionRule — Contract flag (spec default false). The demo enables
## it so a survivor MIA/separated blocks ExtractionActivate completion.
const COHESION_RULE := true

var _run: Node
var _party: Node3D
var _combat: Node3D
var _inv: Node
var _map: Node3D
var _count: Label
var _active: bool = false
var _remaining: float = 0.0
var _combat_sized: bool = false      # combat state the current countdown was sized for
var _blocked: bool = false           # cohesion gate holding the channel at 0


func setup(run: Node, party: Node3D, combat: Node3D, inventory_ui: Node, map: Node3D, count_label: Label) -> void:
	_run = run
	_party = party
	_combat = combat
	_inv = inventory_ui
	_map = map
	_count = count_label


func _process(delta: float) -> void:
	# F-007 §3.7.1 — 전원 ExtractCasualty → PartyWipe → Run Failure (탈출 불가).
	if not _run.run_over and _is_party_wiped():
		_settle_failure("PartyWipe")
		return
	var ctrl: CharacterBody3D = _party.get_controlled()
	if ctrl == null:
		return
	# F-007 ExtractionActivate: hold at POINT-DEMO-01 with the objective done → Run Success.
	# Leaving the zone cancels (no failure — 미완료=런 지속). Big countdown UI ticks down.
	var in_extract: bool = not _run.run_over and _run.objective_complete \
			and ctrl.global_position.distance_to(_map.get_extraction_position()) < EXTRACT_RADIUS_M
	_update_extraction(in_extract, delta)


## ExtractionActivate hold-channel: a countdown that ticks down while in the zone and completes
## at 0. Combat sizes it to 30s; clearing combat SHORTENS the remaining to the 5s safe hold;
## starting combat re-extends to 30s. Leaving the zone cancels (reset). Ticks high→low.
func _update_extraction(in_zone: bool, delta: float) -> void:
	if not in_zone:
		if _active:
			_active = false
			_count.visible = false
		_blocked = false
		return
	var combat: bool = _combat.is_engaged()
	if not _active:
		_active = true
		_combat_sized = combat
		_remaining = EXTRACT_HOLD_COMBAT_S if combat else EXTRACT_HOLD_S
	elif combat != _combat_sized:
		_remaining = EXTRACT_HOLD_COMBAT_S if combat else minf(_remaining, EXTRACT_HOLD_S)
		_combat_sized = combat
	_remaining -= delta
	if _remaining <= 0.0:
		# F-007 §3.6.2 extractionCohesionRule — hold the channel at 0 (not complete, not a
		# failure) while a SURVIVING party member is MIA/separated. Run continues.
		if COHESION_RULE and _has_separated_survivor():
			_remaining = 0.0
			_count.visible = true
			_count.text = "집합 필요"
			if not _blocked:
				_blocked = true
				party_alert.emit("집합 필요 — 생존 파티원이 이탈/MIA 상태입니다", 1)
			return
		_blocked = false
		_active = false
		_count.visible = false
		_settle_extraction()  # F-007 §3.6 Extraction Success (incl. Partial)
		return
	_count.visible = true
	_count.text = "%d" % int(ceil(_remaining))  # 30…/5… → 1


## F-007 §3.6 — compose + finalize Extraction Success (Partial if any ExtractCasualty).
func _settle_extraction() -> void:
	var survivors: Array = []
	var casualties: Array = []
	for m in _party.get_members():
		if not is_instance_valid(m):
			continue
		if m.has_method("is_alive") and not m.is_alive():
			casualties.append(String(m.class_id))   # ExtractCasualty (§3.0)
		else:
			survivors.append(String(m.class_id))
	var safe_items := _collect_at_risk()             # At-Risk → Safe (전량, §3.6.1)
	_inv.mark_run_inventory_safe()
	# haulMaterial: 런 인벤(At-Risk) → hubHaulVault(Safe), 런에서 제거 (F-029 §3.2 / D-029 §4).
	var haul: Dictionary = _inv.collect_haul() if _inv.has_method("collect_haul") else {}
	for hid in haul:
		HubProfile.add_haul(String(hid), int(haul[hid]))
	var partial := not casualties.is_empty()
	_run.settle_extraction({
		"result": "Partial Extraction Success" if partial else "Extraction Success",
		"cause": "",
		"survivors": survivors,
		"casualties": casualties,
		"safe_items": safe_items,
		"haul": haul,
		"lost_items": [],
	})


## F-007 §3.7 — compose + finalize Run Failure. Run-inventory At-Risk → Loss Bundle.
func _settle_failure(cause: String) -> void:
	var casualties: Array = []
	for m in _party.get_members():
		if is_instance_valid(m):
			casualties.append(String(m.class_id))
	_run.settle_failure(cause, {
		"result": "Run Failure",
		"cause": cause,
		"survivors": [],
		"casualties": casualties,
		"safe_items": [],
		"lost_items": _collect_at_risk(),
	})


## At-Risk run inventory = backpack (전체) + 장착 스킬북(F-009 §3.7). 장착 Identity Gear
## 모듈은 Safe(허브 메타)라 제외한다.
func _collect_at_risk() -> Array:
	var out: Array = _inv.collect_run_inventory()
	for m in _party.get_members():
		if not is_instance_valid(m) or not m.has_method("get_skillbook"):
			continue
		for i in 3:
			var sb = m.get_skillbook(i)
			if sb != null:
				out.append({
					"label": "%s (장착)" % String(sb.get("display_name", "Skillbook")),
					"count": 1,
					"kind": "skillbook",
				})
	return out


## F-007 §3.6.2 — any SURVIVING party member MIA or beyond the unbound anchor leash.
func _has_separated_survivor() -> bool:
	for m in _party.get_members():
		if not is_instance_valid(m):
			continue
		if m.has_method("is_alive") and not m.is_alive():
			continue  # casualties don't gate (§3.6.2: 생존 파티원 중)
		if m.has_method("is_mia") and m.is_mia():
			return true
		if m.has_method("is_warn") and m.is_warn():
			return true  # anchorDistance > unbound_anchor_max_m (pre-MIA 경고 구간)
	return false


## F-007 §3.7.1 — every party member is an ExtractCasualty (Dead/RunIncapacitated).
func _is_party_wiped() -> bool:
	var members: Array = _party.get_members()
	if members.is_empty():
		return false
	for m in members:
		if is_instance_valid(m) and (not m.has_method("is_alive") or m.is_alive()):
			return false
	return true
