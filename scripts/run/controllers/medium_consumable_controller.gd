extends Node
## 매질 플라스크(소모품) 지면 조준 모달 — `effect: spawn_medium` 소모품을 던져 지면에 매질을 잠시
## 소환한다. **매질 생성 스킬 5종(AB-009/036/040/042/043)을 대체**한다(DRIFT-112, 사용자 판정:
## *"스킬 하나가 그냥 셋업으로만 쓰이는 건 별로"* → 셋업 전용 슬롯을 없애고 소모품으로 이관).
##
## ReviveController와 같은 **모달 계약**(is_active / cancel / handle_click)이라 dungeon_run의
## 클릭 라우터가 다른 모달과 동일하게 다룬다. 사거리 밖을 찍으면 **스킬과 동일하게** navmesh로
## 걸어가 사거리를 맞춘 뒤 던진다(`AimController._confirm_cast`와 같은 규약) — 소모품만 규칙이
## 다르면 같은 조작에 다른 결과가 나와 학습이 깨진다(사용자 판정: 일관된 경험 우선).
## ref: F-010 · F-021 · DRIFT-112.

var _party: Node
var _combat: Node3D        # CombatController — spawn_zone 소유
var _aim: Node3D           # AimMarker
var _inv: Node             # InventoryUI — consumable_count / consume_consumable
var _hud: Node
var _active: bool = false
var _cid: String = ""
var _master: Dictionary = {}


func setup(party: Node, combat: Node3D, aim_marker: Node3D, inventory_ui: Node, hud: Node) -> void:
	_party = party
	_combat = combat
	_aim = aim_marker
	_inv = inventory_ui
	_hud = hud


func is_active() -> bool:
	return _active


func try_start(cid: String, master: Dictionary) -> void:
	if _active:
		cancel()
		return
	if _inv.consumable_count(cid) <= 0:
		_toast("보유 없음")
		return
	if _party.get_controlled() == null:
		return
	_active = true
	_cid = cid
	_master = master
	var col: Array = master.get("color", [0.8, 0.8, 0.8])
	var c := Color(float(col[0]), float(col[1]), float(col[2]), 0.35) if col.size() >= 3 else Color(0.8, 0.8, 0.8, 0.35)
	_aim.show_ground(float(master.get("radius_m", 2.0)), c)


func cancel() -> void:
	_active = false
	_cid = ""
	_master = {}
	_aim.hide_marker()


## LMB = 지면 확정 · RMB = 취소. 소비했으면 true(라우터가 이벤트를 흘리지 않게).
func handle_click(event: InputEvent) -> bool:
	if not _active or not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return false
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
		return true
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return false
	_confirm(_aim.ground_pos())
	return true


func _confirm(pos: Vector3) -> void:
	var ctrl: Node3D = _party.get_controlled()
	if ctrl == null:
		cancel()
		return
	var cid := _cid
	var master := _master.duplicate()          # 모달을 닫아도 콜백이 쓸 스냅샷
	var rng := float(master.get("range_m", 9.0))
	var d: Vector3 = pos - ctrl.global_position
	d.y = 0.0
	if d.length() <= rng:
		_throw(ctrl, pos, cid, master)
		cancel()
		return
	# 사거리 밖 — **스킬과 동일하게** navmesh로 걸어가 사거리를 맞춘 뒤 던진다(AimController 규약).
	var pc := ctrl.get_node_or_null("Control")
	if pc != null and pc.has_method("order_move_to"):
		pc.order_move_to(pos, func() -> void: _throw(ctrl, pos, cid, master), rng)
	else:
		_throw(ctrl, pos, cid, master)
	cancel()


## 실제 투척 — **소모는 여기서**(이동 오더 중 취소·소진되면 도착 시 조용히 실패). 조준 시점이 아니라
## 던지는 시점에 차감해야 "걸어가다 취소했는데 소모됨"이 안 생긴다.
func _throw(ctrl: Node3D, pos: Vector3, cid: String, master: Dictionary) -> void:
	if ctrl == null or not is_instance_valid(ctrl):
		return
	if not _inv.consume_consumable(cid):
		return
	_combat.spawn_zone(String(master.get("medium", "Oil")), Vector3(pos.x, 0.0, pos.z),
		float(master.get("radius_m", 2.0)), 0.0, float(master.get("ttl_s", 8.0)), ctrl)
	print("[CON] %s → %s zone r%.1f / %.1fs" % [cid, String(master.get("medium", "?")),
		float(master.get("radius_m", 2.0)), float(master.get("ttl_s", 8.0))])


func _toast(text: String) -> void:
	if _hud != null and _hud.has_method("show_toast"):
		_hud.show_toast(text)
	else:
		print("[CON] %s" % text)
