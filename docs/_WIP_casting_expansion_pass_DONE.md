# _WIP — I-006 캐스팅 확장 패스 · **완료 아카이브(DONE)**

> **완료분 전용 아카이브.** 활성 작업 파일 = [_WIP_casting_expansion_pass.md](_WIP_casting_expansion_pass.md). 방법론·현재 ENC·진행표는 거기에 있다.
> **이 파일의 목적:** 컨펌 끝난 ENC 상세 + 대칭 원장을 활성 파일에서 **잘라 보관**해 활성 파일을 짧게 유지한다(매 세션 읽는 비용↓).
> **이동 규칙:** ENC 하나가 컨펌·완료되면 그 ENC 섹션 + 새 원장 행을 여기로 이동한다(활성 §2.4 참조). 패스 종료 시 활성 파일과 함께 삭제, 정본은 `SPEC_DRIFT.md` DRIFT-078.
> **최신화:** 2026-07-15 (NORM-001·HARD-001 이관).

---

## 4. 대칭 원장 (완료 행 — AB당 1행)

> bulk 없이 일관성을 잡는 장치. 새 컨펌 시 이 표에 행을 추가한다(활성 §2.3→§2.4 경유).
> DRIFT-078(엄브렐러)·DRIFT-082(통합 아키텍처) 메타 노트는 **활성 파일 §4**에 있다.

| AB · 이름 | 모드 결정 | 효과·방향 변경 | 바인딩 영향 | 적 telegraph ↔ 아군 cast_s (대칭/비대칭+이유) | 편집 파일 | 상태 |
|-----------|-----------|----------------|-------------|-----------------------------------------------|-----------|------|
| **AB-002** Shield Bash | A 유지(반응형 CC) | 반경 4→8·dmg ×2.5→×1.0·cd 4→2(스팸형 광역 저딜) · 발동 telegraph 링 · **헛스윙도 차지/쿨 소모** | Tank 방벽충전(IDA-020) 스팸 소스 궁합 · 표식(IDA-021) 광역 어그로 | 적 EN-001도 근접 CC(A) — 대칭 | `skillbooks.json` · `sb_strike.gd` | ✅ 완료 |
| **AB-003** Arc Bolt Volley | A→**B**(cast_s 3.0·cd 2→6·radius 1.6→4.0) | 볼트 연사→광역 캐스트 볼트 | **DPS 초월 감전폭주**(BIND-026, bolt→`apply_silence` 2.0s) · Nuker 집중/잠행 generic 후보 | 적 EN-011=필러(§3.6.1 A/0.30) ↔ 아군 B — **비대칭**(아군 볼트를 캐스터화, 적은 필러 유지) → **DRIFT-082로 폐기**(단일정의) | `skillbooks.json` · `binding_overlays.gd` · `ability_dispatch.gd` | ✅ 완료 |
| **AB-004** 전격사격(bolt) | A→**B**(cast_s 0.5→4.0) | — | — | (대칭 판정 보류) | `skillbooks.json` | ✅ 완료 |
| **AB-005** Melee Flurry | A→**B 커밋**(cast_s 3.0·cd 1→10·dmg ×1.0→×3.0·range_band Mid→Melee) | 스팸필러→**드문 커밋 근접 버스트** + **방향성: 자기중심 원형→전방 직사각형 레인**(shape rect·length 5·width 3, `sb_strike` rect 모드+`_enemies_in_rect`+`rect_lane` VFX, targeted **플레이어 조준**(show_beam 레인)/AI 최근접) + **단일대상 +50%**(single_target_mult) + **전방 범위밖 넉백 6m** + **sub_bands 제거→Nuker 적성(메인)** | Nuker **집중**(BIND-027 `focus_dump`: 단일→집중소모 처형/광역→유지·빌드) + **잠행**(BIND-028: 이미근접 generic +15% 합연산, `FLANK.band_dmg.Melee` 0→0.15) | 적 EN-010=빠른 필러라 **통합 안 함** → 규칙5 분기(AB-005 제거·기본평타). abilities.json AB-005=orphan | `skillbooks.json`·`sb_strike.gd`·`combat_controller.gd`·`skill_vfx.gd`·`binding_overlays.gd`·`enemies.json` | ✅ 완료 |
| **AB-007** 이탈(Retreat Hop) | 수동 즉발 → **auto-trigger(저HP) 통일** + **ID 분기**: `AB-007a`(액티브·누름·패시브 없음) / `AB-007b`(패시브·저HP 자동·누름 불가) — **스킬트리 택1** 전제 | 순수 6m 도망(페이로드 0 = 아군 메리트 없음) → **마무리딜(평타×1.5) + 6m 후퇴 + 어그로 −60%**. `auto_disengage` flag 하나가 두 모드를 가름(패시브는 `cast_skillbook`에서 누름 차단 + 액션바 **"자동" 라벨·딤·툴팁 "직접 사용 불가"**) | Nuker **집중**(BIND-033/034: 마무리 대상 집중 +1) · **잠행**(BIND-035/036: 이탈 후 은신 유지 · 은신 중 **평타 정지**(`_hold_fire`) · 은신 첫 스킬 **+30%**, 스킬 시전 시 `break_veil`). **결속 `slot_index:-1`(슬롯 무관) 매칭 신설** | 적 EN-005 `enemy_dash`(HP<50 자동) ↔ 아군 auto-trigger(HP<40) — **거동 통일**("해소 공유 + 트리거 2개"). `reduce_threat`만 진영 라우팅(아군=위협↓ / 적=no-op, 후퇴가 곧 이탈) | `skillbooks.json`·`abilities.json`·`id_registry.json`·`sb_blink.gd`·`ability_dispatch.gd`·`cast_context.gd`·`combat_controller.gd`·`enemy_ai.gd`·`enemy_unit.gd`·`party_member.gd`·`binding_overlays.gd`·`controlled_sheet.gd` | ✅ 완료 |
| **AB-009** Spawn Oil Patch | **A 유지**(무피해 utility·RX 셋업씨앗 = 즉발 셋업이 정체성, §0 캐스트상향 비대상; AB-011 선례) + **관성 강화**(SLIP_ACCEL 10→5·3→1.5) | 클래스 **메인 Healer→DPS**(sub_bands Nuker→Healer B3, DRIFT-091) · Oil=**OilSlick**(감속+관성)·Ice=**IceGlide**(부스트+관성) 분리 + `move_mult` 곱연산·양방향 + AB-069 haste `Hastened` 통합(092) · RX **전부 매질 반응**(fire·cold·lightning, 093) · 겹친 존 render 물리 층서(095) | **DPS 초월 「아군 안심 기름」**(BIND-027 `safeslick`): 초월 중 깐 Oil이 아군 무해(미끄럼·피해 전부 면제 + 직후 RX 상속) = **F-021 §3.3.1 피아무구분 예외**(결속이 환경규칙 뒤집는 첫 사례) · 청록 파티클 표기(매질색 통일). 혈풍/Healer=결속 없음 | 적 EN-004도 동일 Oil(Shared·피아무구분) — 대칭. `safeslick`은 아군 초월 전용 payoff | `skillbooks.json`·`hazard_zone.gd`·`reaction_system.gd`·`ability_dispatch.gd`·`binding_overlays.gd`·`outcome_status.gd`·`party_member.gd`·`enemy_ai/unit.gd`·`player_controller.gd`·`float_text.gd`·`binding_smoke.gd`·`combat_sandbox.gd` | ✅ 완료(DRIFT-091~095) |
| **AB-010** Venom Spit | A→**B**(cast_s 2.0 · cd 6→4) + **지면 조준 AoE** | 즉발 도트 → **스택형 독 DoT**(재적용마다 dps 누적 · cap 5 · `outcome_status` Poison · 0.5s 틱 **보라 팝업**) + equip **DPS 전용**(Nuker/Healer·sub_bands 제거) + **AB-039 병합**(독장판 흡수) → 이후 **독장판을 초월 payoff로 이동**(base·적 시전엔 zone 없음) · **poison_dps 8→1.35**(DoT 과다 튜닝) | DPS **초월**(BIND-031 맹독폭주: +3스택 폭증 **+ 독 zone 잔류** — 존 체류 시 3s마다 +1스택·독 지속 리셋) · **혈풍**(BIND-032: 중독 적 수 비례 회복) | 적 EN-005 ↔ 아군 **통합**(unified·CastContext) — 적도 동일 cast_s·스택·거동 | `skillbooks.json`·`abilities.json`·`sb_poison.gd`·`outcome_status.gd`·`enemy_unit.gd`·`party_member.gd`·`ability_dispatch.gd`·`binding_overlays.gd`·`hazard_zone.gd` | ✅ 완료 |
| **AB-011** Toll Stun | **A 유지**(즉발; role=control→어텐션이코노미 "딜=긴캐" 예외) + **타겟팅 단일**(자기중심 AoE→조준 최근접 1체·선택어시스트 UNIT_AIM) | AoE 강타+기절 → **단일 기절+인터럽트**(sb_stun; targeted r2.5·range9) + equip **Tank 전용**(DPS·sub_bands 제거) | Tank **방벽충전**(BIND-029)+**표식**(BIND-030) generic. DPS 초월(stun kind 미구현)/혈풍=DPS 제거로 제외 | 적 EN-006 tele0.5 ↔ 아군 즉발 — **통합(exec=shared) defer**(control 대칭: 적 tell vs 아군 인터럽트; 스턴 subset 배치) | `skillbooks.json`·`sb_stun.gd`·`aim_controller.gd`·`binding_overlays.gd` | ✅ (통합 defer) |
| **AB-039** Vent Spore | — (**AB-010에 병합 → 폐기**) | "AB-010과 느낌 중복"(사용자) → **병합**: 독안개 존을 AB-010이 흡수하고, 존은 **초월 결속 payoff**로만 발현. EN-005 킷·아군 스킬북에서 제거(**ID는 등록만 잔존·미사용** → 정식 제거는 스펙 배치). ToxicGas 존 재설계 = **체류 3s마다 독 스택 +1 + 독 지속 리셋**(옛 연속 dps 폐지) | Nuker/Healer 존 결속 소멸 → **DPS 초월로 일원화** | 적 EN-005가 더는 별도 독안개를 깔지 않음(base엔 zone 없음) | `enemies.json`·`skillbooks.json`·`hazard_zone.gd`·`sb_poison.gd`·`ability_dispatch.gd` | ✅ 병합·폐기 |
| **AB-041** Glacial Bolt(cold) | A→**B**(cast_s 0.8→3.5) | — | 초월 cold→빙결(Rooted) 강화 | 적 EN-007 존/볼트 ↔ 아군 B | `skillbooks.json` | ✅ 완료 |
| **AB-053** 작열(fire) | A→**B**(cast_s 0.6→3.0) | — | 초월 fire→화상(Ignited) 강화(BIND-019) | (DPS 전용) | `skillbooks.json` | ✅ 완료 |
| **AB-059** 공허창(bolt) | A→**B**(cast_s 1.5→5.0) | — | — | (Ally-only) | `skillbooks.json` | ✅ 완료 |
| **AB-064** 치유 캐스트(channel_heal) | 캐스트힐(cast_s 2.0→3.0) | — | Healer 지속치유(dot_heal) | (Ally-only) | `skillbooks.json` | ✅ 완료 |
| **AB-066** 대치유(channel_heal) | **C 궁극**(cast_s 5.0→10.0) | — | Healer 성역/지속치유 | (Ally-only 궁극) | `skillbooks.json` | ✅ 완료 |

> ⚠️ **원장 재구성 주(2026-07-12):** 위 행 중 일부는 **세션 전 Sonnet 캐스팅 패스 산출물을 미커밋 diff에서 역-복원**한 기록(핑퐁 당시 실시간 기록이 아님). "적↔아군 대칭" 칸은 diff에서 확정 가능한 것만 채움 — 미확정은 잔여 판정 대상.
> **범위 초과 2건(이 패스 밖, 별도 rule DRIFT):** AB-054 절단 광선 채널 개편 = **DRIFT-079**(rootDuringCast 폐지·인터럽트형) · DPS 초월 운영 개편 = **DRIFT-080**(지속→1회소모+OOC초기화). 둘 다 impl/tuning 엄브렐러가 아니라 **rule → OPS_30 전파 후보**.

---

## 6. ENC-NORM-001 — 확인 스킬표 ✅

> 유닛: EN-001 ×1 · EN-010 ×2 · EN-011 ×1 · EN-013 ×1. (EN-013 능력 없음)
> 성격: 대부분 **A(즉발) 유지 확인용** 워밍업 + 적 텔레그래프 1종.

| AB | 이름 | 효과(kind) | 아군 equip | 쓰는 적(1종) | 현재 | 판정 가설 |
|----|------|-----------|-----------|--------------|------|-----------|
| **AB-002** | Shield Bash | 강타+넉백(strike) | Tank | EN-001 Aegis Bearer | 즉발 cd4 | 탱 반응형 근접 CC → **A 유지 후보**. 넉백 감각만 |
| **AB-003** | Arc Bolt Volley | 볼트 연사(bolt·투사체) | DPS·Nuker | EN-011 Back Pester | 즉발 cd2 | 필러(§3.6.1 적=A/0.30) → **A 유지 후보** |
| **AB-005** | Melee Flurry | 근접 연타(strike) | Nuker | EN-010 Front Rush | 즉발 cd1 | 필러 → **A 유지 후보** |
| AB-099 | Iron Mockery | 존 도발(적 telegraph) | (없음·적전용) | EN-001 Aegis Bearer | 적 telegraph | 아군 서브 없음 → **적 캐스트바만 확인**(이미 B/1.0) |

**들고 갈 ally-only 후보(선택):** 없음/자유(라이트 ENC).

> ✅ **ENC-NORM-001 완료 (2026-07-13) — 가설 대비 실제 결정:** 위 "A 유지 후보" 가설은 **딜 서브에 한해 뒤집힘**(어텐션 이코노미 §0 보강). 실제:
> - **AB-002** Shield Bash — A 유지(cd2), 반경 telegraph 링 + 헛스윙 비용. (Tank 반응형 CC = 즉발 OK.)
> - **AB-003** Arc Bolt Volley — **통합**(단일정의, 적↔아군 동일 cast_s 3.0, CastContext) + DPS 초월 감전폭주 + charge_up 파리티. [[DRIFT-082]].
> - **AB-005** Melee Flurry — **커밋 근접 버스트**(cast_s 3.0·cd 10·dmg ×3·단일 +50%·전방 넉백 6m) + **전방 직사각형 조준**(rect·show_beam) + Nuker 집중(focus_dump: 단일 소모/광역 유지)·잠행(generic melee +15%) 바인딩. range_band Melee 정정.
> - **AB-099** Iron Mockery — 적전용(enemy_provoke), 아군 서브 없음, 텔레그래프 이미 정상 → **무변경**.
> 세부 = §4 원장(이 파일). **다음 ENC = ENC-HARD-001**(§7).

---

## 7. ENC-HARD-001 — 확인 스킬표 ✅

> 유닛: EN-001 ×1 · EN-010 ×2 · EN-006 ×1 · EN-005 ×1 / 증원(13s): EN-005 · EN-013 ×2.
> **AB-002·005·099 = NORM-001에서 판정 완료 → 생략.** 여기서 **첫 진짜 캐스트 결정**.

| AB | 이름 | 효과(kind) | 아군 equip | 쓰는 적(1종) | 현재 | 판정 가설 |
|----|------|-----------|-----------|--------------|------|-----------|
| **AB-011** | Toll Stun | 스턴(stun) | Tank·DPS | EN-006 Bell Ringer | 즉발 cd8 | 하드 CC → **캐스트/차지(B~C)?** ⚠️ 아군 AB-011은 **적 채널 인터럽트 도구**로도 쓰임(샌드박스) → 인터럽트 응답성(A) vs 딜-스턴(cast) **역할 충돌 판단 필요**. 적 측은 채널 스턴(DRIFT-050) |
| **AB-010** | Venom Spit | 독 도트(poison) | Nuker·Healer | EN-005 Gutter Spitter | 즉발 cd6 | 지속 도트 → **짧은 캐스트 후보**. 적 poke telegraph(§3.6.1 A/0.30)와 대칭 여부 |
| **AB-039** | Vent Spore | 독안개 존(zone) | Nuker·Healer | EN-005 Gutter Spitter | 즉발 | **캐스트 결정**. 적 = **B/1.2**(§3.6.1) → **대칭 강력 후보**(현 아군 비대칭이 플래그됨) |
| **AB-007** | Retreat Hop | 이탈(blink) | Nuker | EN-005 Gutter Spitter | 즉발 cd6 | 이동 → **A 유지 후보** |

**들고 갈 ally-only 후보(사각 처리):**
- **AB-070 Purge Light** — EN-005 독/디버프 클렌즈 대응 (Healer).
- **AB-030 Voltaic Interrupt** — EN-006 채널 스턴 인터럽트 대응 (AB-011 역할 충돌 판단과 연동).
- **AB-037 등 딜 누킹** — 실전 딜 체감 겸.

> ✅ **ENC-HARD-001 완료 (2026-07-15) — 가설 대비 실제 결정:**
> - **AB-011** Toll Stun — 가설 "캐스트(B~C)?" → **A 유지**. `role=control`이라 어텐션이코노미 "딜=긴캐"의 **예외**(인터럽트 응답성 우선) + 타겟팅 단일(선택 어시스트) + Tank 전용. 통합 = defer(스턴 subset 배치).
> - **AB-010** Venom Spit — 가설 "짧은 캐스트" → **B(cast_s 2.0)** + **스택형 독 DoT 재설계**(누적·cap 5) + **DPS 전용** + **통합**(적↔아군 동일). **AB-039를 여기에 병합**, 이후 독장판은 **초월 payoff로 격리**. poison_dps 8→**1.35**(체감 튜닝 2회).
> - **AB-039** Vent Spore — 가설 "대칭 강력 후보" → **폐기**. AB-010과 중복이라 **병합**(존 = AB-010 초월 결속). EN-005는 더는 독안개를 깔지 않음.
> - **AB-007** Retreat Hop — 가설 "A 유지" → **뒤집힘**. 아군 순수 도망은 **메리트 0**(죽은 슬롯) → **저HP auto-trigger 이탈**(마무리딜+후퇴+어그로↓)로 재설계 + 적↔아군 **거동 통일** + **`AB-007a`(액티브)/`AB-007b`(패시브) ID 분기**(스킬트리 택1) + 집중/잠행 결속.
>
> **전역 파생(이 ENC에서 나옴):** ① 쿨 시작 = 캐스트 **완료** 시점(활성 §0) ② 결속 `slot_index:-1`(슬롯 무관) 매칭 신설 ③ 패시브 서브 UI 규약("자동" 라벨·딤·툴팁 "직접 사용 불가").
> 세부 = §4 원장(이 파일). **다음 ENC = ENC-MID-001**(활성 §8).
