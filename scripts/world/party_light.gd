extends Node3D
## Party Sight Union (F-011 §3.0/§3.1) — squadLight.
## 각 파티원은 동일한 Character Light = **radial 반경(OmniLight)** + **facing 방향
## 가산(전방 콘, SpotLight)** 을 가진다. 4인 각자의 빛의 **합집합**으로 시야를
## 만든다 (단일 centroid 광원이 아님). 광원은 멤버별로 따로 존재하되, ACES 톤맵
## (dungeon_run.tscn Environment) + 절제된 에너지로 겹쳐도 합산 폭주 없이 '하나의
## 라이팅'처럼 읽힌다.
##
## dim/unlit Room에서는 partyLightDimFactor(0.85)/partyLightUnlitFactor(0.65)로
## 반경·가산을 감쇠한다 — 필수 소모품화 방지(F-011 §3.1, F-006 §3.1.5).
## ref: F-011_Vision_InformationWar, scenes/run/dungeon_run.tscn PartyLight

# --- F-011 §6 데모 튜닝값 (후속 D-### Vision SSOT 전까지 하드코딩) ---
@export var party_light_radius_m: float = 7.0       # radial 가시 반경
@export var facing_bonus_range_m: float = 13.0      # 전방 콘(facing 가산) 사거리
@export var facing_bonus_angle_deg: float = 38.0    # 전방 콘 반각
@export var radial_energy: float = 1.5
@export var facing_energy: float = 1.4
@export var light_height_m: float = 1.5             # 발광 높이(가슴/횃불)

const LIGHT_COLOR := Color(1.0, 0.80, 0.54)         # warm party torchlight

## 방 lightingProfile별 파티광 감쇠 계수 (F-011 §3.1).
const ROOM_FACTOR: Dictionary = {
	"lit": 1.0,
	"standard": 1.0,
	"dim": 0.85,       # partyLightDimFactor
	"unlit": 0.65,     # partyLightUnlitFactor
}

var _party: Node3D
var _map: Node3D
var _run: Node
var _rigs: Array = []          # [{member, omni, spot}]
var _facing: Dictionary = {}   # member -> Vector3 (persistent last facing)
var _room_factor: float = 1.0
var _flicker_t: float = 0.0


func _ready() -> void:
	_party = get_node_or_null("../PartyController")
	_map = get_node_or_null("../MapDemoLayout")
	_run = get_node_or_null("../RunController")
	if _party == null:
		push_warning("[TDC] PartyLight: PartyController not found — party light disabled")
		return
	_build_rigs()
	if _run and _run.has_signal("room_changed"):
		_run.room_changed.connect(_on_room_changed)


func _build_rigs() -> void:
	for m in _party.get_members():
		var omni := OmniLight3D.new()
		omni.omni_range = party_light_radius_m
		omni.omni_attenuation = 1.0
		omni.light_color = LIGHT_COLOR
		omni.light_energy = radial_energy
		omni.shadow_enabled = false
		add_child(omni)

		var spot := SpotLight3D.new()
		spot.spot_range = facing_bonus_range_m
		spot.spot_angle = facing_bonus_angle_deg
		spot.spot_attenuation = 1.0
		spot.spot_angle_attenuation = 1.0
		spot.light_color = LIGHT_COLOR
		spot.light_energy = facing_energy
		spot.shadow_enabled = false
		add_child(spot)

		_rigs.append({"member": m, "omni": omni, "spot": spot})
		_facing[m] = Vector3(0, 0, 1)


func _on_room_changed(room_ref: String) -> void:
	if _map == null:
		return
	var profile: String = _map.get_room_profile(room_ref)
	_room_factor = float(ROOM_FACTOR.get(profile, 1.0))


func _process(delta: float) -> void:
	_flicker_t += delta
	var flicker := 1.0 + 0.05 * sin(_flicker_t * 12.0) + 0.03 * sin(_flicker_t * 18.7)

	for rig in _rigs:
		var m: Node3D = rig["member"]
		if not is_instance_valid(m):
			continue
		var alive: bool = not (m.has_method("is_alive") and not m.is_alive())
		var omni: OmniLight3D = rig["omni"]
		var spot: SpotLight3D = rig["spot"]
		omni.visible = alive
		spot.visible = alive
		if not alive:
			continue  # 다운된 멤버는 합집합에서 제외

		# facing — 수평 속도 기준, 정지 시 직전 facing 유지 (F-002 facing 축).
		var vel: Vector3 = m.velocity
		var hv := Vector3(vel.x, 0.0, vel.z)
		if hv.length() > 0.3:
			_facing[m] = hv.normalized()
		var f: Vector3 = _facing.get(m, Vector3(0, 0, 1))

		var pos := m.global_position + Vector3(0, light_height_m, 0)
		omni.global_position = pos
		omni.omni_range = party_light_radius_m * _room_factor
		omni.light_energy = radial_energy * flicker

		# 전방 콘: 멤버 위치에서 facing 방향으로(약간 아래로) 조준.
		spot.global_position = pos
		spot.look_at(pos + f * 4.0 + Vector3(0, -1.0, 0), Vector3.UP)
		spot.spot_range = facing_bonus_range_m * _room_factor
		spot.light_energy = facing_energy * flicker
