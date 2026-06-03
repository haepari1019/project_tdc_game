# Project TDC — Game (Godot)

탑다운 익스트랙션 레이드 ARPG **구현 레포**. 설계 SSOT는 별도 저장소 [`project_tdc`](https://github.com/haepari1019/project_tdc) (docs-only)입니다.

## Spec pin

| Field | Value |
|-------|--------|
| Repository | `haepari1019/project_tdc` |
| Branch | `staging` |
| Commit | see [`spec_ref.json`](spec_ref.json) |
| Playable contract | `QA-030` (Phase 1a) |

규칙·행동 정의는 spec 레포만 수정합니다. 이 레포는 ID·데이터·씬·스크립트 **소비**만 합니다.

## Layout

```
project_tdc_game/
├── project.godot
├── spec_ref.json          # spec 스냅샷 pin
├── data/                  # spec에서 파생·동기화되는 런타임 데이터
├── scenes/
├── scripts/
└── assets/                # 아트·오디오 (대용량 시 Git LFS)
```

## Phase 1a scope

`QA-030` §1 In-scope: `F-001`~`004`, `F-005`, `F-022` smoke, `DBP-DEMO-001`, `ENC-NORM-001` @ `P-ADV-01`, 4 Identity.

Non-goal: haul·허브·Recovery 풀·서브 auto·`ENC-3RD` — spec `QA-030` §1.

## Git

- Default branch: **`main`**
- Spec 레포는 **`staging`** — 브랜치 정책이 다릅니다.

## Open in Godot

Godot 4.3+ (로컬 4.5.1 tested path: `Game_design/Godot_v4.5.1-stable_win64.exe`). Import `project.godot`.

## Sync spec → data

수동 1차: combat/level ID 변경 시 `data/slice01/` 및 `spec_ref.json` commit 갱신. 자동 export 스크립트는 후속.
