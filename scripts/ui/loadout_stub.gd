extends VBoxContainer
## UI-005 stub — confirm 4 identitySkillIds before dungeon (F-020 §3.2.1).

signal loadout_confirmed

var _confirmed: bool = false


func _ready() -> void:
	$ConfirmButton.pressed.connect(_on_confirm_pressed)


func is_confirmed() -> bool:
	return _confirmed


func populate_from_data() -> void:
	var list: VBoxContainer = $IdentityList
	for child in list.get_children():
		child.queue_free()
	for row in Slice01Data.get_identity_rows():
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var lbl := Label.new()
		lbl.text = "%s · %s · %s" % [
			row.get("class_id", "?"),
			row.get("identity_skill_id", "?"),
			row.get("ability_id", "?"),
		]
		list.add_child(lbl)


func _on_confirm_pressed() -> void:
	_confirmed = true
	$ConfirmButton.disabled = true
	$StatusLabel.text = "Loadout confirmed (4 Identity)."
	loadout_confirmed.emit()
