extends RefCounted
class_name Elements
## 속성(element) SSOT — AB 단 `cast.element`가 지정하고, **타격 시점에** 여기 규칙이 적용된다. DRIFT-088.
##
## **규약(사용자 결정 2026-07-19):**
##   · **즉시 효과 = element가 직접 부여** (무조건, 대상 상태와 무관).
##   · **조건부 효과 = RX가 담당** — element는 RX 이벤트만 쏘고, 발현 여부는 반응계가 정한다.
##     예) `fire`는 Ignited를 **직접 걸지 않는다**. FireDamageHit만 쏘고, 가연 대상(Oil 장판 · 향후
##         burnable 적)에서 반응이 성립할 때만 RX가 점화로 발현시킨다. 이게 이 규약의 표준 사례다.
##
## 이 표가 생기기 전엔 속성이 6곳에 흩어져 있었다 — `lightning: true` 플래그(sb_bolt·차징VFX·투사체) +
## kind로 암묵 결정(sb_fire/sb_cold) + 하드코딩(beam_channel). 이제 전부 `element` 하나로 수렴한다.
##
## `scope` = RX 이벤트를 쏘는 형태. `area` = 착탄 반경에 1회 / `per_target` = 맞은 대상마다 소반경으로.
##   (전격은 대상별로 쏴야 전도 판정이 개별 대상 발치에서 성립한다 — 기존 거동 보존.)
## `outcome` = 즉시 부여할 상태(빈 문자열이면 없음). `dur_key` = 지속시간을 읽어올 params 키.
## 표에 없는 속성(slag·void·physical 등)은 **무반응** — 즉시 효과도 RX도 없다(의도).
## `poison`은 스택 누적이 즉시 효과라 `sb_poison`이 자체 처리(표 비등재, RX 없음).
const TABLE := {
	"lightning": {
		"rx": "LightningHit", "scope": "per_target", "per_target_radius_m": 1.2,
		"outcome": "Shock", "dur_key": "shock_s", "dur_default": 0.0,
		"color": Color(0.62, 0.84, 1.0),
	},
	"cold": {
		"rx": "ColdDamageHit", "scope": "area",
		"outcome": "Chilled", "dur_key": "chill_dur_s", "dur_default": 3.0,
		"color": Color(0.6, 0.9, 1.0),
	},
	"fire": {
		"rx": "FireDamageHit", "scope": "area",
		"outcome": "", "dur_key": "", "dur_default": 0.0,   # 즉시 효과 없음 — 점화는 RX 조건부(위 규약)
		"color": Color(1.0, 0.5, 0.15),
	},
}


## 이 속성이 표에 있나(= 즉시 효과/RX를 갖나).
static func has(element: String) -> bool:
	return TABLE.has(element)


static func of(element: String) -> Dictionary:
	return TABLE.get(element, {})


## 속성 대표색 — 차징 VFX·투사체 외형이 공유(예전 `lightning` 플래그 분기를 대체).
static func color_of(element: String, fallback: Color = Color(0, 0, 0, 0)) -> Color:
	var e: Dictionary = TABLE.get(element, {})
	return e.get("color", fallback) if not e.is_empty() else fallback
