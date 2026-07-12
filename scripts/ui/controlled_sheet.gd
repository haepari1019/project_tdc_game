extends Control
## UI-003 Controlled Character Sheet — bottom center. Portrait + HP bar +
## action bar: Identity(auto) + sub slots Q/E/R with clock cooldown radials.
## (Resource bar omitted — no mana system yet.) Final skin = A4.

const RadialCooldown := preload("res://scripts/ui/radial_cooldown.gd")
const UiColors := preload("res://scripts/core/ui_colors.gd")
const SkillText := preload("res://scripts/ui/skill_text.gd")

const SLOT := 42
const HP_W := 230

## Readable name + blurb per ability kind, for the hover tooltip (data has no prose).
var _party: Node
var _portrait: ColorRect
var _name_lbl: Label
var _hp_fill: ColorRect
var _projected_fill: ColorRect  # HoT 예측 세그먼트(현재 HP → 회복 완료 도달치, 민트)
var _shield_fill: ColorRect  # IDA-020 shield overlay (white, over HP)
var _od_bg: ColorRect        # DPS 「초월」 게이지 — 체력 바로 아래(초월 DPS일 때만 표시)
var _od_fill: ColorRect      # 금색 게이지 채움(0..1)
var _od_label: Label         # "초월" / 발동 시 "초월 준비!"
var _slots: Array = []  # {radial, kind}  kind: "identity" | "sub0" | "empty"


func setup(party: Node) -> void:
	_party = party
	for c in get_children():
		c.queue_free()
	_slots.clear()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 0.62)
	sb.set_content_margin_all(9)
	sb.set_corner_radius_all(5)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	panel.add_child(hb)

	_portrait = ColorRect.new()
	_portrait.custom_minimum_size = Vector2(52, 52)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_portrait)

	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 5)
	hb.add_child(col)
	_name_lbl = Label.new()
	col.add_child(_name_lbl)
	var hp_bg := ColorRect.new()
	hp_bg.custom_minimum_size = Vector2(HP_W, 16)
	hp_bg.color = Color(0.05, 0.05, 0.05, 0.9)
	col.add_child(hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.3, 0.85, 0.35)
	_hp_fill.anchor_right = 1.0
	_hp_fill.anchor_bottom = 1.0
	hp_bg.add_child(_hp_fill)
	_projected_fill = ColorRect.new()  # HoT 예측: 현재 HP ~ 회복 완료 도달치(민트), 앵커는 _process에서
	_projected_fill.color = Color(0.55, 1.0, 0.78, 0.5)
	_projected_fill.anchor_bottom = 1.0
	_projected_fill.visible = false
	hp_bg.add_child(_projected_fill)
	_shield_fill = ColorRect.new()  # white shield overlay, drawn over the HP fill
	_shield_fill.color = Color(0.86, 0.92, 1.0, 0.72)
	_shield_fill.anchor_right = 0.0
	_shield_fill.anchor_bottom = 1.0
	_shield_fill.visible = false
	hp_bg.add_child(_shield_fill)

	# DPS 「초월」 게이지 — 체력 바 바로 아래(읽기 편하게). 초월 DPS 정체성일 때만 _process에서 표시.
	_od_bg = ColorRect.new()
	_od_bg.custom_minimum_size = Vector2(HP_W, 11)
	_od_bg.color = Color(0.06, 0.05, 0.02, 0.9)
	_od_bg.visible = false
	col.add_child(_od_bg)
	_od_fill = ColorRect.new()   # 금색 채움(왼쪽 고정, anchor_right = 게이지 비율)
	_od_fill.color = Color(0.95, 0.72, 0.2)
	_od_fill.anchor_right = 0.0
	_od_fill.anchor_bottom = 1.0
	_od_bg.add_child(_od_fill)
	_od_label = Label.new()      # 바 위 중앙 라벨("초월" / 발동 시 "초월 준비!")
	_od_label.text = "초월"
	_od_label.add_theme_font_size_override("font_size", 9)
	_od_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_od_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_od_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_od_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_od_bg.add_child(_od_label)

	# Action bar: Identity(auto) + sub skillbooks Q/E/R (F-009 §3.1).
	for d in [["auto", "identity"], ["Q", "sub0"], ["E", "sub1"], ["R", "sub2"]]:
		var sv := VBoxContainer.new()
		sv.add_theme_constant_override("separation", 2)
		hb.add_child(sv)
		var r := RadialCooldown.new()
		r.custom_minimum_size = Vector2(SLOT, SLOT)
		sv.add_child(r)
		var kl := Label.new()
		kl.text = String(d[0])
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sv.add_child(kl)
		_slots.append({"radial": r, "kind": String(d[1]), "key": kl})


func _process(_delta: float) -> void:
	if _party == null:
		return
	var m: CharacterBody3D = _party.get_controlled()
	if m == null or not is_instance_valid(m):
		visible = false
		return
	visible = true
	var alive: bool = m.is_alive()
	var rc: Color = m.get_class_color()
	_portrait.color = rc if alive else Color(0.32, 0.32, 0.34)
	_name_lbl.text = String(m.class_id)
	var hr: float = clampf(m.hp / maxf(m.max_hp, 1.0), 0.0, 1.0) if alive else 0.0
	_hp_fill.anchor_right = hr
	_hp_fill.color = _hp_color(hr)
	# HoT 예측 세그먼트(2안) — 현재 HP ~ 회복 완료 도달치. 오버헤드 HP바와 동일.
	var proj: float = clampf((m.hp + m.hot_pending_hp()) / maxf(m.max_hp, 1.0), 0.0, 1.0) if (alive and m.has_method("hot_pending_hp")) else 0.0
	if proj > hr + 0.003:
		_projected_fill.anchor_left = hr
		_projected_fill.anchor_right = proj
		_projected_fill.visible = true
	else:
		_projected_fill.visible = false
	var sr: float = (clampf(m.shield / maxf(m.max_hp, 1.0), 0.0, 1.0) if alive else 0.0)
	_shield_fill.anchor_right = sr
	_shield_fill.visible = sr > 0.001
	# 「초월」 게이지 — 초월 DPS 정체성일 때만 체력 아래에 표시. 발동 시 밝은 금색 + "초월 준비!".
	var is_od: bool = alive and m.has_method("overdrive_gauge_frac") \
		and BindingFixtures.identity_overdrive(String(m.base_gear_id), String(m.ability_id))
	_od_bg.visible = is_od
	if is_od:
		var oa: bool = m.overdrive_is_active()
		_od_fill.anchor_right = m.overdrive_gauge_frac()
		_od_fill.color = Color(1.0, 0.92, 0.5) if oa else Color(0.95, 0.72, 0.2)
		_od_label.text = "초월 준비!" if oa else "초월"
	for s in _slots:
		var k := String(s.kind)
		if k == "identity":
			s.radial.set_empty(false)
			s.radial.set_icon_color(rc)
			var t: float = float(m.identity_params.get("cooldown_s", 0.0))
			s.radial.set_cd(m.identity_cooldown_s / t if t > 0.0 else 0.0)
			s.radial.tooltip_text = _skill_tip(m, "주 스킬 (자동)")
		elif k.begins_with("sub"):
			var idx := int(k.substr(3))
			var inst = m.get_skillbook(idx)
			var key: String = ["Q", "E", "R"][idx]
			if inst == null:
				s.radial.set_empty(true)
				s.radial.set_cd(0.0)
				s.key.text = key
				s.key.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
				s.radial.tooltip_text = "보조 (%s)\n(빈 슬롯 — 스킬북 장착)" % key
			else:
				s.radial.set_empty(false)
				s.radial.set_icon_color(inst.color)
				var cdmax: float = float(inst.params.get("cooldown_s", 0.0))
				s.radial.set_cd(float(inst.cooldown_s) / cdmax if cdmax > 0.0 else 0.0)
				var _classes: Array = inst.get("equip_classes", [])
				var _pen: bool = not _classes.is_empty() and String(m.class_id) != String(_classes[0])
				s.key.add_theme_color_override("font_color", Color(1.0, 0.5, 0.25) if _pen else Color(0.92, 0.92, 0.92))
				s.key.text = "%s·%d%s" % [key, int(inst.charges), ("▼" if _pen else "")]
				s.radial.tooltip_text = _sub_tip(m, inst, key, cdmax, idx)


func _hp_color(r: float) -> Color:
	return UiColors.hp_color(r)


## Identity(주 스킬) 슬롯 툴팁 — 표시명 + 설명문 + 쿨. BBCode(RadialCooldown custom tooltip가 렌더).
func _skill_tip(m, header: String) -> String:
	var params: Dictionary = m.identity_params
	if params.is_empty():
		return "[color=#9aa4b2]%s[/color]\n(미장착)" % header
	var kind := String(params.get("kind", ""))
	# 이름·설명 SSOT = display_names.json (정체성 표시명 + kind별 skill_desc). 파티 시트와 일관.
	var nm := Slice01Data.get_identity_display(String(m.identity_skill_id))
	var lines: Array = ["[color=#9aa4b2]%s[/color]" % header, "[b]%s[/b]" % nm]
	var desc := Slice01Data.get_skill_desc(kind)
	if not desc.is_empty():
		lines.append(desc)
	var cd := float(params.get("cooldown_s", 0.0))
	if cd > 0.0:
		lines.append("[color=#9aa4b2]쿨다운 %ss[/color]" % _num(cd))
	# 결속 규약 — 이 정체성이 결속 킷이면 시그니처 규약을 자기완결적으로 표기(라벨 회색 · 규약 금색).
	# 상태 생성·의미·활용을 한 문단으로. 서브는 이 규약이 base를 조건부로 버프하는 것으로 읽힌다.
	var sig: Dictionary = BindingFixtures.signature_for(String(m.base_gear_id), String(m.ability_id))
	if not sig.is_empty():
		lines.append("[color=#9aa4b2]✦ 결속 · %s[/color]" % String(sig.get("name", "")))
		lines.append("[color=#f0b64a]%s[/color]" % String(sig.get("covenant", "")))
	return "\n".join(lines)


## 보조(Q/E/R) 스킬북 슬롯 툴팁 — 표시명 + 설명문 + 탄/쿨 + affix(색) + 비주력 패널티(색) +
## 결속 오버레이(다른 색: identity 연동으로 추가된 효과). BBCode. ref: F-020 §3.7 · binding_fixtures.gd.
func _sub_tip(m: Node, inst: Dictionary, key: String, cdmax: float, idx: int) -> String:
	var kind := String(inst.params.get("kind", ""))
	var lines: Array = [
		"[b]%s[/b]  [color=#9aa4b2]· 보조 %s[/color]" % [String(inst.display_name), key],
		SkillText.describe(kind, inst.params),
		"[color=#9aa4b2]탄 %d/%d  ·  쿨 %ss[/color]" % [int(inst.charges), int(inst.charges_max), _num(cdmax)],
	]
	lines.append_array(SkillText.affix_lines(inst.get("affix", {})))
	var bp := SkillText.band_pct(String(inst.get("base_ability_id", "")), String(m.class_id))
	if bp > 0:
		lines.append(SkillText.band_line(bp))
	# 결속(Kit Binding) — 장착 gear + identity + 이 슬롯 AB가 triple-match면 identity 연동으로 추가되는
	# 효과(오버레이)를 base와 구분되는 색으로 표기. 이 슬롯이 triple-match 아니면 resolve()={} → 표시 없음(base only).
	var ov: Dictionary = BindingFixtures.resolve(
		String(m.base_gear_id), String(m.ability_id), String(inst.get("base_ability_id", "")), idx)
	if not ov.is_empty():
		var idnm := Slice01Data.get_identity_display(String(m.identity_skill_id))
		var sig: Dictionary = BindingFixtures.SIGNATURE.get(String(m.ability_id), {})
		var signm := String(sig.get("name", "결속"))
		# 라벨(정체성 · 시그니처)은 base와 같은 회색으로 일관되게, 결속으로 추가되는 효과만 황금색.
		# 한 정체성의 모든 슬롯 스킬이 같은 시그니처(방벽 충전 / 표식)로 읽힌다.
		lines.append("[color=#9aa4b2]✦ %s 결속 · %s[/color]" % [idnm, signm])
		lines.append("[color=#f0b64a]%s[/color]" % String(ov.get("desc_ko", ov.get("payoff", ""))))
	elif BindingFixtures.identity_focuses(String(m.base_gear_id), String(m.ability_id)) and BindingFixtures.is_focus_spender(kind):
		# 소모 아키타입 — 슬롯 오버레이가 아니라 카테고리 규칙(is_focus_spender)으로 집중을 소모. 특정 처형 스킬에 묶지 않음.
		var idnm := Slice01Data.get_identity_display(String(m.identity_skill_id))
		var signm := String(BindingFixtures.SIGNATURE.get(String(m.ability_id), {}).get("name", "결속"))
		lines.append("[color=#9aa4b2]✦ %s 결속 · %s (소모 계열)[/color]" % [idnm, signm])
		lines.append("[color=#f0b64a]쌓인 집중을 모두 소모해 집중 수에 비례한 추가 피해를 준다.[/color]")
	return "\n".join(lines)


func _num(v: float) -> String:
	return "%d" % int(v) if is_equal_approx(v, floorf(v)) else "%.1f" % v
