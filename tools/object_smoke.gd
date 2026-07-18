extends SceneTree
## Enemy-usable object protocol smoke (F-021 §3.1.2) — enemy_ai.ENEMY_USABLE_OBJECTS 레지스트리의 각
## 스크립트가 필수 계약(enemy_usable·enemy_use)을 구현하는지 검증한다. GDScript는 ctx처럼 덕타이핑이라
## 부분구현(enemy_usable만 있고 enemy_use 없음)이 컴파일에 안 잡히고 런타임에서 throw → 이 게이트가 선제
## 차단(방금 ctx 파리티 게이트와 동형). held형(집어서 무기화)만 enemy_combat_tick(optional 훅)을 추가.
## Run: GODOT --headless --path . --script res://tools/object_smoke.gd

var _ok := true


func _initialize() -> void:
	var AI = load("res://scripts/combat/enemy_ai.gd")
	var reg: Array = AI.ENEMY_USABLE_OBJECTS
	_chk("레지스트리 비어있지 않음", reg.size() > 0)
	for scr in reg:
		var nm := String(scr.resource_path).get_file()
		var obj = scr.new()
		for m in AI.ENEMY_USABLE_REQUIRED:
			_chk("%s 필수 계약 .%s()" % [nm, m], obj.has_method(m))
		# held형(enemy_combat_tick 有)이면 집어서 무기화, 없으면 즉발형(배럴 부수기). 둘 다 유효.
		var held: bool = obj.has_method(AI.ENEMY_USABLE_HELD_HOOK)
		_chk("%s 모델 판별(%s)" % [nm, "held" if held else "즉발"], true)
		if obj is Node:
			obj.free()
	print("OBJECT SMOKE " + ("PASSED" if _ok else "FAILED"))
	quit(0 if _ok else 1)


func _chk(label: String, cond: bool) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_ok = false
