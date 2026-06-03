extends Node2D
## Slice-01 entry stub. Spec: QA-030; pin: spec_ref.json


func _ready() -> void:
	var pin := GameBootstrap.get_spec_pin_summary()
	print("[TDC] Phase 1a bootstrap — spec pin: ", pin)
