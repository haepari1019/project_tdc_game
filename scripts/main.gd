extends Control
## Hub stub → loadout (UI-005) → demo dungeon. Spec: QA-030 §3.1–3.2

const DUNGEON_SCENE := "res://scenes/run/dungeon_run.tscn"

@onready var _status: Label = $Panel/Margin/VBox/Status
@onready var _loadout: VBoxContainer = $Panel/Margin/VBox/LoadoutStub
@onready var _start: Button = $Panel/Margin/VBox/StartButton


func _ready() -> void:
	if not Slice01Data.is_loaded():
		_status.text = "Slice01 data FAILED — see Output"
		_start.disabled = true
		_loadout.visible = false
		push_error("[TDC] Slice01 data not loaded")
		return
	var pin := GameBootstrap.get_spec_pin_summary()
	_status.text = "%s · %s" % [pin, Slice01Data.get_summary()]
	_loadout.populate_from_data()
	_start.disabled = true
	_loadout.loadout_confirmed.connect(_on_loadout_confirmed)
	_start.pressed.connect(_on_start_pressed)
	print("[TDC] Hub ready — ", pin)


func _on_loadout_confirmed() -> void:
	_start.disabled = false


func _on_start_pressed() -> void:
	if not _loadout.is_confirmed():
		return
	get_tree().change_scene_to_file(DUNGEON_SCENE)
