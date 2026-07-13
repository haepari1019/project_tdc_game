extends RefCounted
class_name AbilityRoles
## 능력 role/exec 중앙 레지스트리 — 전투 템포 개편 인프라 (DRIFT-083).
## **DRAFT (2026-07-13) — role 표 핑퐁 대상.** ①/③ 경계(hybrid 3종·AB-099)는 미확정(§7).
##
## 목적: 적 캐스트 페이싱(알파 스트라이크 방지)의 캡을 `kind`(delivery 축, 과부하)가 아니라 **`role`(목적 축)**
## 으로 걸기 위한 SOT. shared·적고유·예외 능력을 **한 곳에 등재**해 관측·조정 가능하게 한다(enemy_ai 흩어짐 0).
##
## 축 정의:
##   role  — 능력의 목적. 캡은 role로 판정.
##     threat     : 파티 겨냥 예고 피해 (캡 O)
##     control    : 파티 겨냥 하드 CC/강제 — 기절/루트/테더/핀/도발 (캡 O)
##     debuff     : 파티 겨냥 소프트 디버프 — 감속/약화(즉시 반응 불요) (캡 X)
##     support    : 아군 힐/버프 (캡 X)
##     buff       : 자가 강화 (캡 X)
##     reposition : 순수 이동, 피해 없음 (캡 X)
##     utility    : 표식/지형/무피해 존 (캡 X)
##   exec  — 실행 라우팅 (거동을 어디서 처리하나). 등재 != 실행.
##     shared      : CastContext 진영flip으로 파티 effect 재사용 (이사 완료/대상)
##     ai_internal : 거동을 enemy_ai에 위임 (AI 공격성/포지셔닝 결합, 진영대칭 불가)
##     hybrid      : 피해 effect=shared, 딜리버리(대시)=ai
##   kind  — 현재 data(abilities.json)의 delivery kind. 해소·VFX 구동(유지). 이사 시 shared kind로 라우팅.
##
## 드리프트: role/exec = 게임 인코딩(spec 미핀) → 로컬 ImplDecision. exec ai_internal→shared 전환 = DRIFT-082.

## 캡 대상 role — 첫 캐스트 난수지연(스태거) + 소프트 동시성 캡 K=1 이 적용됨.
const CAP_ROLES := ["threat", "control"]

## 능력 id → {kind, role, exec}. 근거는 인라인 주석(= 관측용 표).
const ROLES := {
	# ── ① 위협(threat) · shared ──────────────────────────────────────────────
	"AB-002": {"kind": "enemy_melee",   "role": "threat",  "exec": "shared"},      # 방패강타. 즉발(telegraph 없음) → 스태거 시드 O, 동시성캡 N/A
	"AB-003": {"kind": "enemy_charge",  "role": "threat",  "exec": "shared"},      # unified 파일럿(이미 shared, sb_bolt)
	"AB-004": {"kind": "enemy_charge",  "role": "threat",  "exec": "shared"},      # 전격 볼트 + shock(soft CC 부수)
	"AB-005": {"kind": "enemy_melee",   "role": "threat",  "exec": "shared"},      # 근접강타 (현재 어떤 적에도 미배정)
	"AB-008": {"kind": "enemy_splash",  "role": "threat",  "exec": "shared"},      # 슬래그 스플래시
	"AB-010": {"kind": "enemy_poison",  "role": "threat",  "exec": "shared"},      # 독침 + DoT
	"AB-039": {"kind": "spawn_zone",    "role": "threat",  "exec": "shared"},      # 독가스 존 (dps 8 — 유일한 피해 존)
	"AB-041": {"kind": "enemy_cold",    "role": "threat",  "exec": "shared"},      # 빙결 볼트 + chill(부수)
	"AB-106": {"kind": "enemy_execute", "role": "threat",  "exec": "shared"},      # 처형 (저HP x2 + 킬힐)

	# ── ① 위협(threat) · hybrid (대시 딜리버리=ai, 피해=shared strike) ──
	"AB-013": {"kind": "enemy_dash", "role": "threat", "exec": "hybrid"},          # 백스탭(flank dash + strike 1.5)
	"AB-104": {"kind": "enemy_dash", "role": "threat", "exec": "hybrid"},          # 램페이지(line + splash 1.1)

	# ── ① 통제(control) · shared/hybrid — 하드 CC, 캡 O ───────────────────────
	"AB-011": {"kind": "enemy_stun",    "role": "control", "exec": "shared"},      # 종 기절 1.4s
	"AB-102": {"kind": "enemy_root",    "role": "control", "exec": "shared"},      # 올가미 root 2.0s
	"AB-103": {"kind": "enemy_tether",  "role": "control", "exec": "shared"},      # 리쉬 tether 4.0s
	"AB-099": {"kind": "enemy_provoke", "role": "control", "exec": "shared"},      # 도발(강제 접근, cd 14) — 캡 포함(핑퐁 확정)
	"AB-100": {"kind": "enemy_dash",    "role": "control", "exec": "hybrid"},      # 덮치기(pin 0.6 = 하드CC; strike 1.2 부수, 대시=ai)

	# ── 디버프(debuff) · shared — 소프트 디버프(감속/약화), 캡 X ────────────────
	"AB-012": {"kind": "enemy_hex", "role": "debuff", "exec": "shared"},           # 헥스(slow 0.6 + weaken 0.5)

	# ── ② 지원/유틸 · shared (캡 X) ──────────────────────────────────────────
	"AB-098": {"kind": "enemy_heal", "role": "support", "exec": "shared"},         # 아군 힐 8% (진영flip)
	"AB-101": {"kind": "enemy_mark", "role": "utility", "exec": "shared"},         # Scent 표식(무피해)
	"AB-009": {"kind": "spawn_zone", "role": "utility", "exec": "shared"},         # Oil 미끄럼(무피해)
	"AB-036": {"kind": "spawn_zone", "role": "utility", "exec": "shared"},         # Water 전도 셋업(무피해)
	"AB-040": {"kind": "spawn_zone", "role": "utility", "exec": "shared"},         # Ice 빙결 지형(무피해, 감속). §7: control 승격 검토 여지
	"AB-042": {"kind": "spawn_zone", "role": "utility", "exec": "shared"},         # Wind 밀림(무피해)
	"AB-043": {"kind": "spawn_zone", "role": "utility", "exec": "shared"},         # Vegetation 무효과(가연성/RX 전용)

	# ── ③ 적고유 예외 · ai_internal (캡 X, 중앙 등재만) ──────────────────────
	"AB-105": {"kind": "enemy_frenzy", "role": "buff",       "exec": "ai_internal"},   # Bloodlust 자가버프(HP<50% 반응)
	"AB-006": {"kind": "enemy_dash",   "role": "reposition", "exec": "ai_internal"},   # 갭클로즈(무피해)
	"AB-007": {"kind": "enemy_dash",   "role": "reposition", "exec": "ai_internal"},   # 후퇴 도약(무피해, HP<50%)
	# AssassinTransform 처형(백라인 x3): AB id 없음 — enemy_ai 코드 거동. role=threat/exec=ai_internal 로 취급.
}

## role 조회. 미등록이면 "" (호출부에서 abort/기본 처리).
static func role_of(ab_id: String) -> String:
	var e = ROLES.get(ab_id)
	return String(e["role"]) if e else ""

## exec 라우팅 조회.
static func exec_of(ab_id: String) -> String:
	var e = ROLES.get(ab_id)
	return String(e["exec"]) if e else ""

## 캡(스태거+동시성) 대상인가 = role in CAP_ROLES.
## 주의: 즉발(telegraph_s 없음, 예: AB-002)은 스태거 시드만 의미 있고 동시성캡은 N/A —
## 캡 적용부(B-2)에서 텔레그래프 유무를 별도로 가드한다.
static func is_cap_eligible(ab_id: String) -> bool:
	return CAP_ROLES.has(role_of(ab_id))
