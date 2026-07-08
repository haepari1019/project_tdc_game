extends Node3D
## 수호-흡수 힐 노드 — target에 수호 보호막을 걸고, 종료(ward_active=false)를 폴링해 그동안 흡수한 피해량만큼
## 치유한다. 치유는 ctx.deal_heal 경유 → 지속치유=도트 전환 / 성역=증폭 자동. 흡수 0이면 치유 없음("맞은량만큼").

var _caster: CharacterBody3D
var _target: CharacterBody3D
var _ctx
var _applied: bool = false


func setup(caster: CharacterBody3D, target: CharacterBody3D, amount: float, dur: float, ctx) -> void:
	_caster = caster
	_target = target
	_ctx = ctx
	if target != null and is_instance_valid(target) and target.has_method("apply_ward_shield"):
		target.apply_ward_shield(amount, dur)
		_applied = true


func _process(_delta: float) -> void:
	if not _applied or _target == null or not is_instance_valid(_target):
		queue_free()
		return
	if not _target.ward_active():                 # 종료 → 흡수분만큼 치유
		var absorbed: float = _target.ward_take_absorbed()
		if absorbed >= 1.0:
			var healed: float = _ctx.deal_heal(_target, _caster, absorbed)
			if _target.has_method("popup_status"):
				_target.popup_status("수호 +%d" % int(round(healed)), Color(0.55, 0.85, 1.0))
		queue_free()
