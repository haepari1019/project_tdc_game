extends RefCounted
## ItemFactory — pure backpack/stash item-dict builders, extracted from InventoryUI
## (ARCHITECTURE DEBT-INV). Turns a data master (gear / skillbook / consumable) into the
## grid item dict the inventory drag system expects. No state, no UI — stateless statics.
## ref: F-008 (gear) / F-009 (skillbook) / F-010 (consumable·stash).

const UnitVisuals := preload("res://scripts/core/unit_visuals.gd")


## Backpack item dict from a gear master (id=display name, role color, 2×2).
## `g` = a gear master OR an instance dict (equipped_gear / loot def / loose-merged) — F-008 §3.7
## rolled fields (rolled_identity_skill_id / rolls) are carried through if present (non-empty).
static func gear_item(g: Dictionary, at_risk: bool) -> Dictionary:
	var classes: Array = g.get("equip_classes", [])
	var cid := String(classes[0]) if not classes.is_empty() else "Tank"
	var out := {
		"id": String(g.get("display_name", g.get("base_gear_id", "Gear"))),
		"w": 2, "h": 2,
		"color": UnitVisuals.role_color(cid),
		"kind": "gear",
		"base_gear_id": String(g.get("base_gear_id", "")),
		"at_risk": at_risk,
	}
	var rid := String(g.get("rolled_identity_skill_id", ""))
	if rid != "":
		out["rolled_identity_skill_id"] = rid
	if g.has("rolls") and typeof(g["rolls"]) == TYPE_DICTIONARY and not (g["rolls"] as Dictionary).is_empty():
		out["rolls"] = g["rolls"]
	return out


## Backpack item dict from a haul material (1×1, ochre). Run-inventory At-Risk; on Extraction
## Success → hubHaulVault Safe (F-029 §3.2 / D-029 §4). 시설 승급 전용 재화.
const HAUL_MAX_STACK := 99   # 재료는 크게 스택(백팩/스태시/금고). (tuning)

static func haul_item(haul_material_id: String, display: String, at_risk: bool, count: int = 1) -> Dictionary:
	return {
		"id": display if not display.is_empty() else haul_material_id,
		"w": 1, "h": 1,
		"color": Color(0.62, 0.5, 0.32),
		"kind": "haul",
		"haul_material_id": haul_material_id,
		"count": count,
		"max_stack": HAUL_MAX_STACK,
		"at_risk": at_risk,
	}


## Backpack item dict from a charm (1×1) — F-010 §3.11. **스택하지 않는다**: 같은 참을 2개 들면
## 칸도 2개를 먹어야 「칸 vs 파워」 긴장이 성립한다(스택되면 공짜로 두 배가 된다).
static func charm_item(charm_id: String, display: String, at_risk: bool) -> Dictionary:
	return {
		"id": display if not display.is_empty() else charm_id,
		"w": 1, "h": 1,
		"color": Color(0.85, 0.70, 0.35),   # 호박색 — 마석(보라)·재료(황토)·소비(청록)와 구분
		"kind": "charm",
		"charm_id": charm_id,
		"at_risk": at_risk,
	}


## Backpack item dict from a manastone (1×1 스택) — F-009 §3.8. 슬롯 스킬 시전 소모 자원.
## 런 인벤에 있을 때만 At-Risk(F-007 §3.7.3a) → 탈출 성공 시 stash Safe. haul과 같은 스택 타일 모델.
static func manastone_item(manastone_id: String, display: String, at_risk: bool, count: int = 1, max_stack: int = 99) -> Dictionary:
	return {
		"id": display if not display.is_empty() else manastone_id,
		"w": 1, "h": 1,
		"color": Color(0.55, 0.42, 0.85),   # 보라 — 재료(황토)·소비(청록)와 구분
		"kind": "manastone",
		"manastone_id": manastone_id,
		"count": count,
		"max_stack": max_stack,
		"at_risk": at_risk,
	}


## ~~`skillbook_item`~~ — **M5에서 제거**(`D-018` §9 인스턴스 Frozen). 슬롯 AB는 물건이 아니라
## gear에 새겨진 등록이라 가방 타일이 될 수 없다. 만드는 함수가 남아 있으면 언젠가 누가 부른다.


static func consumable_color(master: Dictionary) -> Color:
	var ca: Array = master.get("color", [0.6, 0.85, 0.6])
	return Color(float(ca[0]), float(ca[1]), float(ca[2])) if ca.size() >= 3 else Color(0.6, 0.85, 0.6)


## Backpack item dict from a consumable master (1×1, stackable).
static func consumable_item(master: Dictionary, count: int) -> Dictionary:
	return {
		"id": String(master.get("display_name", master.get("consumable_id", "Item"))),
		"w": 1, "h": 1,
		"color": consumable_color(master),
		"kind": "consumable",
		"consumable_id": String(master.get("consumable_id", "")),
		"count": count,
		"max_stack": int(master.get("max_stack", 1)),
	}
