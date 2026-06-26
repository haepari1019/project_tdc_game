extends SceneTree
## QA-021 reaction decision-core smoke — 헤드리스로 검증 가능한 "어떤 반응이 일어나는가"의 결정 로직:
## primaryMedium 우선순위 resolver(EVENT-CORE §3 / INT-002 §6.1) + RX 매트릭스 4축(F-027).
## 연쇄 실거동·VFX·ENC 클리어는 F5 체크리스트(docs/qa/F5_checklist_p2.md) 소관. 진입 = _initialize().

var _ok := true


func _initialize() -> void:
	var RS = load("res://scripts/combat/abilities/reaction_system.gd")
	var rs = RS.new()

	# 1) primaryMedium = 최고 우선순위 매체(EVENT-CORE §3). RX_PRIORITY: Oil>ToxicGas>Water>Fire>Steam>Smoke>Ice>Veg>Wind.
	_chk(String(rs._primary_medium_of([_z("Water"), _z("Oil")])) == "Oil", "primary: Oil > Water")
	_chk(String(rs._primary_medium_of([_z("Fire"), _z("ToxicGas")])) == "ToxicGas", "primary: ToxicGas > Fire")
	_chk(String(rs._primary_medium_of([_z("Steam"), _z("Water")])) == "Water", "primary: Water > Steam")
	_chk(String(rs._primary_medium_of([_z("Ice"), _z("Fire")])) == "Fire", "primary: Fire > Ice")
	_chk(String(rs._primary_medium_of([_z("Wind"), _z("Vegetation")])) == "Vegetation", "primary: Veg > Wind")
	_chk(String(rs._primary_medium_of([])) == "", "primary: 빈 타일 → ''")
	_chk(String(rs._primary_medium_of([_z("Bogus")])) == "", "primary: 미등록 매체 무시")

	# 2) RX 매트릭스 엔트리(F-027 Hit-RX 4축 합격기준).
	_chk(String(rs.RX_FIRE_MATRIX.get("Oil", "")) == "oil_fire", "RX Fire+Oil = 폭발(oil_fire)")
	_chk(String(rs.RX_FIRE_MATRIX.get("Water", "")) == "fire_water", "RX Fire+Water = Steam(fire_water)")
	_chk(String(rs.RX_FIRE_MATRIX.get("Vegetation", "")) == "fire_vegetation", "RX Fire+Veg = 확산(fire_vegetation)")
	_chk(String(rs.RX_FIRE_MATRIX.get("ToxicGas", "")) == "toxicgas_fire", "RX Fire+ToxicGas = flash")
	_chk(String(rs.RX_COLD_MATRIX.get("Water", "")) == "cold_water", "RX Cold+Water = freeze(cold_water)")
	_chk(String(rs.RX_COLD_MATRIX.get("Vegetation", "")) == "vegetation_cold", "RX Cold+Veg = frostbite")
	_chk(String(rs.RX_LIGHTNING_MATRIX.get("Water", "")) == "lightning_water", "RX Lightning+Water = Shock")
	_chk(String(rs.RX_LIGHTNING_MATRIX.get("Steam", "")) == "steam_lightning", "RX Lightning+Steam = Shock(약)")
	_chk(String(rs.RX_PHYSICAL_MATRIX.get("Oil", "")) == "oil_physical", "RX Physical+Oil = Slippery")

	# 3) 우선순위 리스트 형태(Oil 최상위·Wind 최하위·9 매체).
	_chk(rs.RX_PRIORITY.size() == 9 and String(rs.RX_PRIORITY[0]) == "Oil" and String(rs.RX_PRIORITY[8]) == "Wind", "RX_PRIORITY 9매체 Oil..Wind")

	rs.free()
	if _ok:
		print("REACTION SMOKE PASSED")
		quit(0)
	else:
		print("REACTION SMOKE FAILED")
		quit(1)


func _z(s: String) -> _ZoneStub:
	return _ZoneStub.new(s)


func _chk(cond: bool, label: String) -> void:
	print("  %s   %s" % ["ok " if cond else "FAIL", label])
	if not cond:
		_ok = false


class _ZoneStub:
	var status: String
	func _init(s: String) -> void:
		status = s
