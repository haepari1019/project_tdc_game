extends RefCounted
## Shared pointer-input feel constants. 좌클릭(선택/스왑)과 우클릭(클릭이동/카메라 orbit)이
## **같은 허용 오차**를 쓰도록 한 곳에서 계산한다 — 버튼마다 값이 다르면 손에 안 익는다.
##
## 임계를 **고정 픽셀로 두지 않는 이유:** 픽셀은 해상도가 올라가면 상대적으로 작아진다.
## 같은 손떨림이 1080p에서 10px이면 4K에서는 20px이라, 고해상도일수록 클릭이 드래그로
## 오판되는 빈도가 올라간다. 그래서 **화면 짧은 변의 비율**로 역산한다(가로가 아니라 짧은 변 —
## 울트라와이드에서 가로 기준을 쓰면 임계가 과도하게 커진다).
##
## **임계가 두 개인 이유 — 겹치는 구간이 필요하다.** 하나로 묶으면 둘 중 하나가 반드시 나쁘다:
## 값이 크면 클릭은 잘 먹지만 카메라 orbit 시작이 굼뜨고, 작으면 orbit은 즉각적이지만 클릭이
## 씹힌다. 그래서 **orbit/마퀴는 일찍 시작**(DRAG_START)하되 **릴리즈 판정은 늦게**(CLICK_MAX)
## 한다. 그 사이 구간에서는 카메라가 돌면서도 손을 떼면 클릭으로 인정된다 —
## "살짝 밀렸지만 클릭할 의도였다"가 정확히 이 구간이다.
##
##   0 ─── DRAG_START ─────── CLICK_MAX ───→  누른 지점으로부터의 거리
##     클릭          클릭 + orbit           드래그(클릭 안 먹음)
##
## NOTE: 거리는 "누른 지점으로부터의 **최대** 직선거리"로 재야 한다. 릴리즈 순간의 거리로 재면
## 멀리 끌었다가 제자리로 돌아와 놓는 동작이 클릭으로 오인된다. 이동량 누적(Σ|dx|+|dy|)은
## 줄어들지 않아 손떨림만으로 부풀므로 쓰지 않는다(이 방식이 원래 버그였다).
##
## NOTE: project.godot 의 stretch mode 가 `canvas_items` 라 마우스 좌표가 이미 기준 해상도
## 공간으로 정규화돼 들어올 수 있다. `get_visible_rect()`에서 역산하면 **정규화되든 아니든**
## 마우스 이벤트와 같은 좌표계를 쓰게 되므로 양쪽 모두에서 옳다(스트레치 설정이 바뀌어도 안전).
## ref: DRIFT-090 후속 — 클릭↔드래그 판별 결함.

## 릴리즈 시 여기 안이면 "클릭"(클릭이동 / 스왑). 1080p ≈ 65px.
## 튜닝 이력: 고정 8px → 2.5%(27px) → 5.0%(54px) → **6.0%**(사용자 체감, 2026-07-19).
const CLICK_MAX_FRACTION := 0.06
const CLICK_MAX_MIN_PX := 28.0

## 카메라 orbit / 선택 마퀴가 시작되는 지점. 1080p ≈ 32px.
## CLICK_MAX 보다 **작아야** 겹치는 구간이 생긴다(위 다이어그램).
const DRAG_START_FRACTION := 0.03
const DRAG_START_MIN_PX := 14.0


## 릴리즈 판정용 — 누른 지점에서 이 거리 안이면 클릭으로 인정.
static func click_max_px(vp: Viewport) -> float:
	return _scaled(vp, CLICK_MAX_FRACTION, CLICK_MAX_MIN_PX)


## 카메라 orbit / 마퀴 시작 임계 — 이걸 넘으면 드래그 동작이 시작된다(클릭 인정은 별개).
static func drag_start_px(vp: Viewport) -> float:
	return _scaled(vp, DRAG_START_FRACTION, DRAG_START_MIN_PX)


static func _scaled(vp: Viewport, fraction: float, min_px: float) -> float:
	if vp == null:
		return min_px
	var s: Vector2 = vp.get_visible_rect().size
	return maxf(min_px, minf(s.x, s.y) * fraction)
