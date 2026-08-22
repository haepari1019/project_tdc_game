extends SceneTree
## **인벤 스택 분리 스모크** — Ctrl+드래그로 나눠 집는 경로가 **개수를 잃지 않는가**.
##
## 이 기능의 유일한 위험은 산수가 아니라 **되돌리기**다. 나눠 집은 조각은 어느 그리드에도
## 속해 있지 않아서, 놓을 곳이 없을 때 「원위치로 되돌린다」가 통하지 않는다 — 그대로 두면
## 덜어 낸 만큼이 조용히 증발한다. 그래서 여기서 묻는 것은 **어느 경로로 끝나도 총합이
## 보존되는가** 하나다.

var _ok := true


func _init() -> void:
	for _i in 3:
		await process_frame
	var sd = root.get_node_or_null("/root/Slice01Data")
	if sd == null or not sd.is_loaded():
		print("INVENTORY SMOKE FAILED — Slice01Data not loaded")
		quit(1)
		return

	# ① 스택 키 — 「합쳐지는 것」과 「개체로 세는 것」이 갈리는가. 참·기어가 스택형으로 새면
	#    같은 참 2개가 한 칸으로 합쳐져 「칸 vs 파워」(F-010 §3.11)가 무너진다.
	var inv = load("res://scripts/ui/inventory/inventory_ui.gd").new()
	root.add_child(inv)
	for _i in 3:
		await process_frame
	for pair in [["consumable", "consumable_id", "con_revive_scroll", true],
			["manastone", "manastone_id", "ms_weak", true],
			["haul", "haul_material_id", "haul_ward_splinter", true],
			["charm", "charm_id", "charm_ward_scale", false],
			["gear", "base_gear_id", "gear_ward_tank_anchor_bulwark", false]]:
		var probe: Dictionary = {"kind": String(pair[0]), String(pair[1]): String(pair[2])}
		var stackable: bool = inv._stack_key(probe) != ""
		_expect(stackable == bool(pair[3]), "_stack_key — %s %s" % [pair[0], "스택형" if pair[3] else "비스택"])

	# ② 소스 게이트 — Ctrl 분기가 `consumable` 하드코딩으로 되돌아가지 않았는가.
	var src := FileAccess.get_file_as_string("res://scripts/ui/inventory/inventory_ui.gd")
	_expect(src.contains("mb.ctrl_pressed and _stack_key(item) != \"\""),
		"Ctrl 분기 — 스택형 전체(consumable 하드코딩 아님)")
	_expect(src.contains("func _begin_split_drag(") and src.contains("func _revert_split("),
		"분리 → 드래그 + 되돌리기 경로 존재")

	# ③ **본론** — 총합 보존. 20개에서 7개를 집으면 13 + 7이어야 한다.
	var grid = inv._backpack
	grid.items.clear()
	for ch in grid.get_children():
		ch.queue_free()
	await process_frame
	grid.clear_all() if grid.has_method("clear_all") else null
	var ok_add: bool = grid.add_item_dict({
		"id": "약한 마석", "kind": "manastone", "manastone_id": "ms_weak",
		"w": 1, "h": 1, "count": 20, "max_stack": 99, "color": Color(0.4, 0.6, 0.9)})
	_expect(ok_add, "테스트 스택 적재")
	var stack: Dictionary = grid.items[0]

	inv._begin_split_drag(grid, stack, 7)
	_expect(int(stack.get("count", 0)) == 13, "분리 후 원본 = 13 (실제 %d)" % int(stack.get("count", 0)))
	_expect(int(inv._drag.get("count", 0)) == 7, "커서에 들린 것 = 7 (실제 %d)" % int(inv._drag.get("count", 0)))
	_expect(String(inv._drag_src.get("kind", "")) == "split", "드래그 출처 = split(되돌리기 분기 진입)")
	_expect(String(inv._drag.get("manastone_id", "")) == "ms_weak", "나눈 조각이 정체를 유지")

	# 놓을 곳이 없어 되돌아가는 경우 — **여기가 증발 지점이었다.**
	inv._revert_drag()
	_expect(int(stack.get("count", 0)) == 20, "되돌리면 원본에 합쳐진다 = 20 (실제 %d)" % int(stack.get("count", 0)))

	# 원본이 사라진 뒤 되돌리기 — 빈 칸으로 떨어져야 한다(그래도 잃지 않는다).
	# ⚠️ `_revert_drag()`는 드래그 상태를 **정리하지 않는다**(실제로는 `_end_drag`가 한다).
	#    여기서 안 비우면 다음 `_begin_split_drag`가 `not _drag.is_empty()`에 걸려 조용히 통과한다.
	_end(inv)
	inv._begin_split_drag(grid, stack, 5)
	grid.lift(stack)
	inv._revert_drag()
	var total := 0
	for it in grid.items:
		if String(it.get("manastone_id", "")) == "ms_weak":
			total += int(it.get("count", 0))
	_expect(total == 5, "원본 소실 시 — 나눈 조각은 빈 칸으로 살아남는다 (합 %d)" % total)
	_end(inv)

	# ④ 경계 — 전부 집기(= 분리가 아님)와 0개는 거부한다.
	grid.items.clear()
	for ch2 in grid.get_children():
		ch2.queue_free()
	await process_frame
	grid.add_item_dict({"id": "성채 파편", "kind": "haul", "haul_material_id": "haul_ward_splinter",
		"w": 1, "h": 1, "count": 3, "max_stack": 99, "color": Color(0.6, 0.5, 0.3)})
	var st2: Dictionary = grid.items[0]
	inv._begin_split_drag(grid, st2, 3)          # 3/3 → clamp되어 2가 되어야 한다(전부는 분리가 아니다)
	_expect(int(st2.get("count", 0)) == 1 and int(inv._drag.get("count", 0)) == 2,
		"전부 집기 요청은 max-1로 clamp (원본 %d · 조각 %d)" % [int(st2.get("count", 0)), int(inv._drag.get("count", 0))])
	inv._revert_drag()
	_end(inv)
	# 1개짜리는 나눌 수 없다 — 원본을 1로 만들어 놓고 시도한다.
	st2.count = 1
	inv._begin_split_drag(grid, st2, 1)
	_expect(inv._drag.is_empty() and int(st2.get("count", 0)) == 1, "1개짜리 스택은 분리 거부")

	inv.queue_free()
	if _ok:
		print("INVENTORY SMOKE PASSED")
		quit(0)
	else:
		print("INVENTORY SMOKE FAILED")
		quit(1)


## 드래그 뒷정리 — 실제로는 `_end_drag`가 한다. 스모크는 그 부분만 흉내 낸다.
func _end(inv) -> void:
	if inv._drag_vis != null:
		inv._drag_vis.queue_free()
		inv._drag_vis = null
	inv._drag = {}
	inv._from = null
	inv._drag_src = {}


func _expect(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_ok = false
