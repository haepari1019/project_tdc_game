extends Control
## UI-003 Controlled Character Sheet — bottom center. Portrait + HP bar +
## action bar: Identity(auto) + sub slots Q/E/R with clock cooldown radials.
## (Resource bar omitted — no mana system yet.) Final skin = A4.

const RadialCooldown := preload("res://scripts/ui/radial_cooldown.gd")
const UiColors := preload("res://scripts/core/ui_colors.gd")

const SLOT := 42
const HP_W := 230

## Readable name + blurb per ability kind, for the hover tooltip (data has no prose).
const SKILL_INFO := {
	"shield_pulse":  {"name": "보호 파동", "desc": "자기 보호막 + 주변 적 위협 끌기"},
	"cone_sweep":    {"name": "전방 휩쓸기", "desc": "전방 부채꼴을 연속 타격"},
	"mark_burst":    {"name": "표식·파열", "desc": "대상에 표식 후 큰 폭발 피해"},
	"radius_heal":   {"name": "치유 진영", "desc": "주변 아군 HP를 회복"},
	"sub_taunt":     {"name": "도발 강타", "desc": "넉백 + 도발 + 자기 보호막"},
	"sub_lunge":     {"name": "돌진 베기", "desc": "대상으로 돌진해 강타 (지정)"},
	"sub_nova":      {"name": "노바 폭발", "desc": "지정 지점 광역 폭발 + 둔화"},
	"sub_sanctuary": {"name": "성역", "desc": "주변 아군 회복 + 보호막"},
}

var _party: Node
var _portrait: ColorRect
var _name_lbl: Label
var _hp_fill: ColorRect
var _shield_fill: ColorRect  # AB-020 shield overlay (white, over HP)
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
	_shield_fill = ColorRect.new()  # white shield overlay, drawn over the HP fill
	_shield_fill.color = Color(0.86, 0.92, 1.0, 0.72)
	_shield_fill.anchor_right = 0.0
	_shield_fill.anchor_bottom = 1.0
	_shield_fill.visible = false
	hp_bg.add_child(_shield_fill)

	# Action bar: Identity(auto) + Q + E + R.
	for d in [["auto", "identity"], ["Q", "sub0"], ["E", "empty"], ["R", "empty"]]:
		var sv := VBoxContainer.new()
		sv.add_theme_constant_override("separation", 2)
		hb.add_child(sv)
		var r := RadialCooldown.new()
		r.custom_minimum_size = Vector2(SLOT, SLOT)
		if String(d[1]) == "empty":
			r.set_empty(true)
		sv.add_child(r)
		var kl := Label.new()
		kl.text = String(d[0])
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sv.add_child(kl)
		_slots.append({"radial": r, "kind": String(d[1])})


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
	var sr: float = (clampf(m.shield / maxf(m.max_hp, 1.0), 0.0, 1.0) if alive else 0.0)
	_shield_fill.anchor_right = sr
	_shield_fill.visible = sr > 0.001
	for s in _slots:
		match String(s.kind):
			"identity":
				s.radial.set_icon_color(rc)
				var t: float = float(m.identity_params.get("cooldown_s", 0.0))
				s.radial.set_cd(m.identity_cooldown_s / t if t > 0.0 else 0.0)
				s.radial.tooltip_text = _skill_tip(m.identity_skill_id, m.identity_params, "주 스킬 (자동)")
			"sub0":
				s.radial.set_icon_color(rc.lightened(0.18))
				var t2: float = float(m.sub_params.get("cooldown_s", 0.0))
				s.radial.set_cd(m.sub_cooldown_s / t2 if t2 > 0.0 else 0.0)
				s.radial.tooltip_text = _skill_tip(m.sub_ability_id, m.sub_params, "보조 스킬 (Q)")


func _hp_color(r: float) -> Color:
	return UiColors.hp_color(r)


## Hover tooltip for a skill slot: header + readable name/blurb + cooldown (from data).
func _skill_tip(skill_id: String, params: Dictionary, header: String) -> String:
	if params.is_empty():
		return "%s\n(미장착)" % header
	var kind := String(params.get("kind", ""))
	var info: Dictionary = SKILL_INFO.get(kind, {})
	var name := String(info.get("name", kind))
	var lines: Array = [header, "%s  ·  %s" % [name, skill_id] if not skill_id.is_empty() else name]
	if info.has("desc"):
		lines.append(String(info["desc"]))
	var cd := float(params.get("cooldown_s", 0.0))
	if cd > 0.0:
		lines.append("쿨다운 %ss" % _num(cd))
	return "\n".join(lines)


func _num(v: float) -> String:
	return "%d" % int(v) if is_equal_approx(v, floorf(v)) else "%.1f" % v
