# BACKLOG — 잔여·이연 항목 대장 (P2 완료 후)

> **무엇:** P2(S2~S7) 완료 시점에 **아직 열려 있는** 잔여/이연/미구현/부채 항목의 단일 추적 대장. [SPEC_DRIFT.md](SPEC_DRIFT.md)(DRIFT-000~068)·[impl_decisions/ImplDecisionLog.md](impl_decisions/ImplDecisionLog.md)·[ARCHITECTURE.md](ARCHITECTURE.md) §6 부채표·[ROADMAP_P2_FullCoverage.md](ROADMAP_P2_FullCoverage.md) §7 + git log를 **교차검증**해 압축한 것. 게임측 추적 문서(SSOT 아님, 규칙은 각 F-###/spec).
> **기준:** 2026-07-04 · 핀 `f16c262`(staging) · P2 커버리지 목표 사실상 닫힘.
> **제외(노이즈):** 이미 완료된 항목(band·affix/multi-affix·per-AB tier·potencyMult·gear roll-table G1~G3·Stash 인스턴스화·capacity 2축·평타 pierce/cleave/kb·AB-003/005/007 적측·armory/chapel/소모품 hub 실연동·S5b 제너레이터·킬귀속·ENC 비복원·Sentinel 40% 반사·Shadowstep+20%·Beam channel·Bloodlust HP-scale·F-011 fog·역전파 배치 DEC-20260626-001~005) · "F5/F6 체감 검증"(코드 갭 아님) · 순수 튜닝 로깅.

## 범례 — Solvability Tier
- **T1 지금 바로**: 독립 코드·저위험·전파 불필요.
- **T2 전파 필요**: 규칙/ID 변경 → spec repo `OPS_30` + 승인.
- **T3 선행 의존**: 미구축 시스템부터 지어야 함.
- **T4 고위험 리팩터**: 정책상 이연([[refactor-risk-preference]]).
- **T5 Expansion/비목표**: 지금 "해결" 대상 아님.
- 규모: 소 / 중 / 대. 출처 = `DRIFT-###` / `DEBT-###` / ROADMAP.

---

## T1 — 지금 바로 가능 (독립·저위험·전파 불필요)

> **진행 완료 2026-07-04** — 실구현 8건(E3·B4·B5+B6·F2·F3·B7·C3·C2§7.8) + 이미-done 검증 4건(A1a·DEBT-DM1·B10·trivial). 전 헤드리스 스모크 PASS. **F3·B7는 새 룰이라 `PENDING-PROP`(OPS_30 승인 대기).** 이연: C2 §7.5/§7.2·저위험 부채(기능이득 0)·E3 tier-충전수(밸런스 결정). 상세=`ImplDecisionLog` IMPL-DEC-20260704-001·`SPEC_DRIFT` DRIFT-069.

- [x] **B5+B6 적 거리-leash 이탈 + 스폰 원위치 복귀** ✅ 구현: `DISENGAGE_LEASH_M 28` + `returning` 플래그 → `_tick_dormant` 스폰복귀. — 현재 6s no-LOS grace만. 스폰 앵커 거리-leash 병행 + 포기 후 스폰 복귀 배선. `enemy_ai.gd`의 `ENGAGE_LEASH_M 18`은 kite-flee 클램프에만 쓰임, `leash_m 28` 미배선. (중) · `DRIFT-040/048/019` — **전투 무게↑ 직결**
- [x] **B10 threat-on-hit / threat-on-basic** ✅ 이미 done: `combat_controller.gd:443` 배선 + `identities.json` Tank threat_mult 2.0~2.6(코드변경 불요). — `member.threat_mult` 필드 이미 존재, 어그로 생성 배선만. (소) · `DRIFT-059`·`IMPL-DEC-20260626-036` — 탱커 어그로 체감
- [x] **B4 HEX-WEAK 피해감소 절반** ✅ 구현: `party_member.apply_hex_weak/hex_weak_mult` + `_deal_damage` 소비 + AB-012 `hex_weak 0.5`. — AB-012 Hex Bolt가 이동 slow만 적용. outgoing-damage 감소 반쪽은 파티 아웃고잉 데미지 훅 필요(미존재). (소) · `DRIFT-041`, `enemy_ai.gd:932`
- [x] **B7 zone spread 엔진 (S3e)** ✅ 구현·`PENDING-PROP`: Wind 구동 유계 spread(per-gust 2·global cap 6·2s)·spread children 비재확산. room-cap=전역 프록시. F5 튜닝·룰 전파 대기. — WindGust 확산 + room cap(2/gust·6/room·2.0s) 미구축. ~19 RX 매트릭스 일부 이연. (중) · ROADMAP ZONE row·S3e
- [x] **E3 난이도별 스킬북 드롭률** ✅ 구현: `SKILLBOOK_DROP_BY_DIFF` Normal8%/Hard15%. **tier별 충전수=밸런스 결정 보류**(61권 저작값 일괄 덮어쓰기 = 밸런스 변경). — 데이터 미보유(현 flat/clamp 데모값). Normal 8%/Hard 15%, Basic56/Adv60/Master72. (소, 데이터) · `DRIFT-063`
- [x] **F3 잔여 환경 RX** ✅ 구현·`PENDING-PROP`: 3종 추가(Fire+Ice→Water·Cold+Fire→Steam·Cold+Steam→Water). 새 RX 룰이라 OPS_30 승인 대기. — Water/Vegetation 등(Fire/Cold/Lightning/Physical 4축 done). (중, 콘텐츠) · `DRIFT-029`
- [~] **C2 UI-006 PIP 잔여** ◐ §7.8 우선순위 정렬 구현(MIA 최저HP순). **§7.5 파티시트 아이콘/단축키·§7.2 관통가림=이연**(저가치 UI 폴리시, PIP 패스로 묶어 처리 권장). — §7.2 관통가림 없음(단순 팔로우캠)·§7.8 우선순위 정렬(현 MIA진입순)·§7.5 파티시트 PIP 아이콘/단축키. (소, 폴리시) · `DRIFT-030`
- [x] **C3 오프스크린 피격 표시(팔로워) + 적 stun VFX** ✅ 구현: 적 stun 오버헤드 `✦` 마크 + 오프스크린 아군 피격 시 앰버 엣지 글로우(자기피격 red와 구분). — 방향 피격 인디케이터=조작캐 한정, 적 stun=freeze만(VFX 무). (소, 폴리시) · `DRIFT-022/044`
- [x] **F2 fog 동적 occluder** ✅ 구현: 문 `add_box_occluder`(vision_fog+enemy_vision)·닫힘=그림자(기존 버그: 그림자 전무)·열림=제거. **멀티층/perf=이연**(현 단층맵엔 불필요). — 움직이는 벽/문 개방 미반영·UPDATE_ALWAYS 2뷰포트·시야콘 16캡. (중, 폴리시/perf) · `DRIFT-037`
- [x] **A1a AB-S01~04 orphan 정리** ✅ 이미 done: `ImplDecisionLog:649`에서 삭제 완료. abilities.json `_note`도 "removed" 명시 — 백로그가 옛 DRIFT-026 노트 물려받은 stale. — 스킬북으로 실질 대체된 미사용 자작 서브 4종을 `abilities.json`에서 삭제(또는 유지). (소, 정리) · `DRIFT-001/026`
- [x] **DEBT-DM1 abilities.json require_id 가드 복원** ✅ 이미 done: `slice01_data.gd:743-746`에 가드 존재(DRIFT-006). ARCHITECTURE §6 부채표가 stale → 정정함. — abilities 로드가 "미등록 ID→abort" 가드를 건너뜀(코드 가드 버그). (소, 안전성) · `DEBT-DM1`
- [~] **저위험 부채 기회정리** ⏭ 이연: 순수 리팩터(기능이득 0), churn·리스크 회피로 이번 패스 제외. 필요 시 별도 지시. — DEBT-DUP-CD(쿨비율 접근자)·DEBT-DUP-MAT(머티리얼 팩토리)·DEBT-CPL-HUD(HUD 노드경로 하드코딩)·DEBT-EFF-ALLOC/HPBAR. (각 소) · `ARCHITECTURE §6`
- [x] **trivial** ✅ done: combat_sandbox.gd:74 stale 주석 정정 + 발견 버그 수정(`sentinel_form.gd` reflect 키 불일치 `reflect_frac`→`reflect` 폴백; party_member:510 "Reflect deferred" stale 주석).

## T2 — 가능하나 스펙 전파+승인 필요 (다른 레포 · OPS_30)

- [ ] **A2 EN-001 Mockery per-ENC 토글** — 스펙은 en001_mockery를 ENC별 on/off(HARD-004/002 off·006/009 on), 게임은 ENC-레벨 ability 게이팅 없음 → 항상 캐스트. ENC-JSON `ability_overrides` 시스템 신설 or 스펙 단순화(always-on) 결정. · `DRIFT-045`
- [ ] **A3 engage behavior enum 정식화** — 게임 `engage ∈ {advance/standoff/kite/zone/orbit/probe/surround/healer}`가 스펙 대응 없음. D-017/EN-AI-000 편입 vs impl-only 유지 결정. EN-AI-000 §1표 loose ref도 함께. · `DRIFT-040/051`
- [ ] **A4 per-AB tier 12종 abilityTier 스펙 authoring** — AB-028/030/032/033/034/035/044/045/051/062/070/074가 스펙에 `abilityTier` 없음 → 게임 Basic 기본. 스펙 채운 뒤 재싱크(비파괴, 상점 가격/천장만 영향). · `DRIFT-068`
- [ ] **E2 ward_scrap source 값 스펙 정의(선택)** — 통화·가격은 D-018 §7 정의됨, 획득 source 미지정 → 데모값(추출 15+생존자×5, 킬 1). source 모델 자체는 역전파됨(`DRIFT-064`), 값만 잔여. · `DRIFT-060/064`
- [ ] *(minor)* EN-AI-000 §2 `channel_s 0.7` vs AB-011 `telegraph_s 0.50` 수치 reconcile(튜닝, 로깅). · `DRIFT-050`

## T3 — 선행 의존 (미구축 시스템부터)

- [ ] **F1 F-020 passive 풀트리** — 현재 chapel T1 "F-020-lite"(flat 파티 스탯 버프)만 배선(`72fbd6e`). **memory상 지정된 next이며, 논의 중인 스킬 해금/아키타입 재디자인과 직결.** 재디자인 설계 확정이 정렬 축. (대) · ROADMAP Hub row·`IMPL-DEC` 318/282
- [ ] **E1 ally 획득 정식화** — ally-only lootable(usable_by_enemy=false: AB-034/044/054/062/070/075…)이 적 킷서 안 떨어져 현재 ally-cache 상자(RM-ADV-01) 임시. shop 매대·ENC 드롭표(배선 일부 존재)·자동 분배 + NPC 고용(Q-HUB-050 데모 근사) 필요. (중~대) · `DRIFT-057`·`IMPL-DEC-20260623-013`
- [ ] **B9 소모품 D-020 확장 + 전투 중 사용 입력** — 현 `con_revive_scroll` 1종만. 회복/해독 등 + 전투 중 사용 루트(F-010 §3.7.1 2단) + 소모품 At-Risk/추출 정산. (중) · `DRIFT-027`
- [ ] **C1 UI-008 지휘권 전환** — 명시 리더/서브리더 지정·역할↔슬롯 재배정 미구현(현 auto 랠리앵커 stand-in만). Control Lock/지휘권 지정 시스템 필요. `DEBT-DEAD2`(can_swap always-true 스텁)와 종속. (중) · `DRIFT-021/030/034`
- [ ] **B8 Tether(AB-103) leash-DoT** — 현 `Tethered` 태그만. `leash_distance_m`/`dot_on_break_dps`(거리초과 DoT)에 거리추적 틱 노드(beam_channel식) 필요. (중) · `DRIFT-055`·`IMPL-DEC-20260623-017`(BLOCKED)
- [ ] **B1 Recovery 루프 전체** — 실패 후 회수 루프. Recovery Target 슬롯·Anchor 스냅샷·월드 Marker·RecoverActivate/Loot UI·mapId 재방문(2nd 맵)·MainBossRaid·UI-005 리스크 프리뷰. 현재 정산 분기만. Q-HUB-040도 데모 근사(`DRIFT-065`). (대) · `DRIFT-031`

## T4 — 고위험 리팩터 (정책상 이연 권장)

- [ ] **DEBT-GOD** `party_controller.gd`(~1280) — SteeringV1(~21 `_sv1_*`, ~530줄) 추출. config 소유권 재설계 동반 = **고위험, 지금 손대지 말 것.** (high) · `ARCHITECTURE §6`
- [ ] **DEBT-GOD2** `combat_controller.gd`(~494) — EncounterSpawner/SquadManager 추출. (med)
- [ ] **DEBT-EFF-RAY / DEBT-EFF-GRP** — SteeringV1 per-follower 6~15 레이캐스트/프레임·`'enemy'` 그룹 재스캔. DEBT-GOD에 종속. (med)
- [ ] **DEBT-CPL-DUCK / DEBT-CPL-GROUP / DEBT-DM2** — duck-typing 가드 부재·string 그룹 다중화·ENEMY_VISUALS 분리. (med~low)

## T5 — Expansion / 비목표 (지금 대상 아님)

- [ ] **B2 ENC-HARD-007 (Extreme)** — 난이도 티어 채택 시(현 Normal/Hard). 23/24 ENC 완료. · ROADMAP §1
- [ ] **B3 대장간 리롤** — 기어/스킬북 roll·affix 리롤 스테이션. Expansion 못박음(S6b 마지막). · `DRIFT-062`·`IMPL-DEC-20260626-035`
- [ ] **DEBT-DM3** 실제 맵 지오메트리 — ROOM_SPECS placeholder 절차기하 유지, Blender 실맵 미대체(레벨아트 대기).
- [ ] **DEBT-PLAT-FWD** F-011 fog가 Forward+ 강제 → **web export 차단**. impl-only 결정(spec 비대상). web/mobile 타겟 채택 시만 재검토.
- [ ] ~~적 진짜 탄도(회피가능)~~ — locked 설계, **비채택**(갭 아님, 참고용). · `DRIFT-059`·`IMPL-DEC-019`

*(T-tier 미분류 minor 잔여 — 필요 시 조치: ccTenacity Rooted/Pinned 스케일 미적용(`DRIFT-055`) · dash i-frames(`DRIFT-042/056`) · AB-008 `chains_to_status: Slippery`+AB-009 Oil SEED(`DRIFT-041`) · AoE-projectile 벽 폭발 현 fizzle·projectile range-clamp/pierce(`DRIFT-059`).)*

---

## 착수 순서 권장

1. **전투 무게↑ 노선이면** → T1의 **B5+B6+B10**(적 leash/복귀 + 탱커 어그로) 먼저. 싸고 즉효, 컨셉 일관성에도 기여.
2. **재디자인(스킬 해금/아키타입)** → **F1 passive 트리와 같은 자리.** 설계 확정 시 T3의 E1·B9 + T2의 A1·A4 + E3가 그 아래로 정렬됨. → 재디자인이 정렬 축.
3. **T2 전파 배치** → 승인 나면 A2·A3·A4·E2 한 번에 OPS_30.
4. **T4(DEBT-GOD) 계속 이연.** T5 파킹.

> **Stop Line:** 각 항목 착수는 명시 승인 후. 이 문서는 추적용이며, 조치 시 해당 `DRIFT-###` 상태도 함께 갱신할 것.
