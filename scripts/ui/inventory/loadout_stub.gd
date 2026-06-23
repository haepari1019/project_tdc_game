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
	# 장비 텍스트 나열 제거 (UX) — 장착/로드아웃 확인은 [스태시/금고] 편집창에서 한다. 제목+목록 숨김.
	var list: VBoxContainer = $IdentityList
	for child in list.get_children():
		child.queue_free()
	list.visible = false
	$LoadoutTitle.visible = false


func _on_confirm_pressed() -> void:
	_confirmed = true
	$ConfirmButton.disabled = true
	$StatusLabel.text = "Identity 확정 — 장비·스킬·소모품·로드아웃 확인은 [스태시/금고]에서."
	loadout_confirmed.emit()
