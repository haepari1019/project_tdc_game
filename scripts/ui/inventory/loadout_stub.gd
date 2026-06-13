extends VBoxContainer
## Deployment loadout (UI-005 / F-010) — confirm the 4 Identity loadout (장착 Gear = Safe).
## Gear / skillbooks / consumables are edited via the stash → backpack inventory ("장비·스킬
## 편집", main.gd); brought items are At-Risk (F-007). ref: F-010 §3.2.

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
		lbl.text = "%s · %s · %s   (장착 Identity Gear = Safe)" % [
			row.get("class_id", "?"),
			row.get("identity_skill_id", "?"),
			row.get("ability_id", "?"),
		]
		list.add_child(lbl)


func _on_confirm_pressed() -> void:
	_confirmed = true
	$ConfirmButton.disabled = true
	$StatusLabel.text = "Identity 확정 — 장비·스킬·소모품은 [장비·스킬 편집]에서 스태시로."
	loadout_confirmed.emit()
