# ImplDecisionLog — 코드/구현 측 결정 기록

> **무엇:** 게임 레포의 **구현 측** 결정(아키텍처·리팩토링·핀·근사치)을 남긴다. 스펙 규칙 변경은 여기가 아니라 spec repo `DecisionLog.md`(`DEC-`)에 기록한다.
> **기록 대상:** 비자명한 구조/접근 결정, 의도적 근사, 핀 변경, 되돌리기 어려운 선택. **비대상:** 단순 버그픽스·오타·자명한 구현.
> **형식:** `IMPL-DEC-YYYYMMDD-### · 결정 · 이유 · 대안 · 영향 파일`

---

### IMPL-DEC-20260623-021 — 기어 롤테이블 이행 G1 (스타터 id 스펙 정렬 + 파생 롤테이블 토대)
- **결정(사용자 게이트 클리어):** gear 1:1 `bundled_identity_skill_id` → 아키타입(롤테이블)+인스턴스(굴린 identity, F-008 §3.7) 이행. ① **id = 스펙 엄격 정렬** ② **롤테이블 = 권고안(파생)** ③ **인스턴스 스키마 = 아키타입 풀 + 굴린 선택 저장**. G1=저위험 토대만.
- **id 정렬 범위(작음):** 17 비스타터는 이미 GEAR-COR-000 슬러그 일치 → **스타터 4 id만 개명**(`_set`→spec) + 4파일 동기 + Backpack 세이브 마이그레이션(alias). 큰 churn 없음.
- **롤테이블 = 파생(Slice01Data.get_gear_identity_roll_table):** main(bundled w50)+동클래스 나머지. 21행 명시 테이블 안 넣음(권고안; override 향후) — 데이터 verbosity 회피.
- **bind 폴백:** _bind_gear가 rolled>bundled. master엔 rolled 없어 거동 불변(가산 fwd-prep).
- **이유:** G1 토대(개명·파생·폴백)는 안전. G2(획득 롤+저장 포맷 문자열→딕셔너리)가 진짜 위험 → 별도. 설계 doc=docs/design/gear_roll_table.md.
- **검증:** ci_smoke + party_pool_smoke(id 정렬·롤테이블) PASS.
- **영향:** `gear.json`·`id_registry.json`(스타터 4 id) · `backpack.gd`(시드+_migrate_gear_ids) · `loot_service.gd`(GEAR_LOOT) · `slice01_data.gd`(get_gear_identity_roll_table) · `party_member.gd`(_bind_gear) · `docs/design/gear_roll_table.md`.

### IMPL-DEC-20260623-020 — P2-S6b 스킬북 economy 1a (분석→해금→상점, ward_scrap) + 시드 정렬
- **결정:** S6b를 **1a(economy 상태·로직, 헤드리스 검증) → 1b(허브 UI)**로 분할. **gear roll-table·affix는 고위험 게이트라 이연**([[refactor-risk-preference]]·ROADMAP §6). 1a = F-009 §3.5/D-018 §7.1 메타 루프를 HubProfile에 구현: 분석 의뢰(N=3·scriptorium 게이트·해금 후 거부) → `shop_listing_unlocked` → `buy_raw`(scribe_shop Tier ceiling + ward_scrap 차감). 가격 Basic 12/Adv 30/Master 60(스펙). + Backpack 시드를 F-009 §3.1.1 스타터(AB-033/028/030/044/045)로 정렬(구 Ember 대체).
- **데모 결정(SPEC_DRIFT DRIFT-060):** ① ward_scrap source = 추출 `15+생존자×5`(스펙 source 미지정). ② 상점 tier=Basic 기본(per-AB tier 데이터 미보유). 둘 다 tuning.
- **이유:** 로직 먼저(hub_smoke로 검증) + UI 후속 = P2-S4 Hub 패턴 동일. economy 통화/해금/가격은 spec 그대로(드리프트 없음). gear roll-table은 loot/extraction 메타 리팩터라 단독 결정.
- **검증:** hub_smoke 7 assertion(분석·해금·구매·차단) + ci_smoke PASS.
- **영향:** `hub_profile.gd`(economy state+methods) · `run_end_controller.gd`(추출 scrap 그랜트) · `backpack.gd`(스타터 시드) · `tools/hub_smoke.gd`.

### IMPL-DEC-20260623-019 — 투사체 Phase 2 (2a 파티 분류·VFX 승격 / 2b 적 샷 interception)
- **결정:** Phase 1 증명 후 투사체 시스템 확장. **2a(저위험)**: sb_fire/sb_cold도 `cast()`/`resolve_at()` 분리, 파티 데미지 어빌리티 10종에 `delivery:projectile` 부여(bolt 8 + fire 2 + Glacial cold) — 지면 AoE 설치/self/aura/melee/CC는 instant 유지. 투사체 element 틴트(`proj_color`). **2b(적 샷)**: 적 RANGED 히트가 벽/파티 Rampart에 막히면 무효(`_shot_blocked` raycast world layer) → **내 벽이 적 누커 샷을 막음(RP-02 정방향)**.
- **이유:** 2a는 데이터+effect 분리(AI 무관, 저위험). 2b는 **homing-locked 유지 + 기하 차단**만 — 적 샷을 실엔티티(회피가능)로 만들면 파티 AI가 회피 못 해 손해 + locked 가독성 설계 뒤집힘 → raycast interception이 정답(공정성 보존 + 벽 차단 획득).
- **대안(기각):** 적 샷도 진짜 탄도 투사체 → 회피 AI 없는 AI파티엔 손해, locked 설계 반전. 비채택.
- **이연:** range 클램프·pierce·AoE 투사체 벽 폭발(현 fizzle)·차단 시 적 호밍 VFX가 끝까지 날아가는 비주얼(데미지는 정확히 차단). threat-on-hit.
- **검증:** ci_smoke + party_pool_smoke(진영필터·delivery flag) + 샌드박스 부팅. 충돌/차단 실거동 = F5(샌드박스 Rampart 테스트 — 적 벽 흡수·내 벽 통과; 적 ranged는 ENC 스폰 후 내 Rampart로 막기).
- **영향:** `effects/sb_fire.gd`·`sb_cold.gd`(cast/resolve_at) · `projectile.gd`(proj_color) · `skillbooks.json`(10 delivery flag) · `enemy_ai.gd`(_shot_blocked + _apply_enemy_hit 가드).

### IMPL-DEC-20260623-018 — 어빌리티 전달(delivery) 축 + 투사체 시스템 (Phase 1 증명)
- **결정(사용자 설계):** 어빌리티를 모양(범위/단일)이 아니라 **전달 방식**으로 분류 — `delivery ∈ {instant, projectile}` × payload(단일/범위/존…) 직교. `projectile`만 이동·충돌·차단(벽/Rampart 흡수)을 가짐. 통제자(플레이어/AI)는 조준만 다르고 전달 물리는 동일.
- **아키텍처:** ① 범용 `projectile.gd` — segment-raycast(prev→next, 터널링 방지) 이동, 첫 충돌: Rampart(group)→`absorb_projectile`, 벽(world)→불발, 적유닛/도달점→`effect.resolve_at()` 콜백. hit mask=시전자 진영 제외(아군→world|enemy, 적→world|party; Rampart=world layer 1이라 양쪽 차단). ② effect를 `cast()`(분기: instant→즉시 resolve_at / projectile→`ctx.spawn_projectile(self,…)`) + `resolve_at(caster,center,params,ctx)`(공유 판정)로 분리 → 즉발·투사체가 동일 게임플레이 코드. ③ params는 투사체가 `duplicate()` 스냅샷(전이 `_coeff` 포착).
- **Phase 1 스코프(증명):** 아군 볼트 **AB-056 Longshot만** projectile 라우팅 + Rampart 흡수(DMG-BARRIER-HIT-10). 나머지 전 어빌리티 **instant 유지(무변경, 저위험)**. **Rampart 투사체흡수(DRIFT-057 BLOCKED) 부분 해소.**
- **이유:** 한 데이터 플래그 + 엔티티 1 + effect cast/resolve_at 분리로 즉발/투사체 통합. 스펙(ENT-RAMPART projectile-block) 의도 충족(전파 불요).
- **검증:** ci_smoke(컴파일·부팅) + party_pool_smoke(flag·resolve_at·spawn_projectile 배선). **충돌/비행 실거동 = 헤드리스 불가 → F5 플레이테스트.**
- **Phase 2(후속):** 전 어빌리티 instant/projectile 분류(파티+적, 범위폭발 포함)·적 샷 라우팅·VFX 승격·range/pierce.
- **영향:** `projectile.gd`(신규) · `ability_dispatch.gd`(spawn_projectile·_projectile_mask·preload) · `effects/sb_bolt.gd`(cast/resolve_at) · `rampart_barrier.gd`(absorb_projectile) · `skillbooks.json`(AB-056 delivery) · `party_pool_smoke.gd`.

### IMPL-DEC-20260623-017 — 이연 능력 디테일 4종 (Shadowstep+20% · Sentinel 반사 · Beam Channeling · Bloodlust HP-scale)
- **결정:** 능력 근사로 미뤄둔 디테일 중 **아키텍처상 구현 가능한 4종**을 처리. ① **Shadowstep(AB-061) next-hit +20%** — `party_member._next_hit_bonus`(grant/consume 1회) + 중앙 `combat_controller._deal_damage` 훅(basic·sub 모두 이 경로 → 한 곳에서 적용). ② **Sentinel Form(AB-052) 40% 반사** — `take_damage(amount, attacker=null)`로 시그니처 확장(양 take_damage 동일), `_apply_enemy_hit`가 `enemy`를 attacker로 전달 → 스탠스 중 reflect_frac 반사. ③ **Beam(AB-054) Channeling** — `begin_channel`/`is_channeling` busy 플래그(채널 동안 다른 서브 캐스트 차단; dungeon_run·sandbox 게이트), 기존 Rooted move-lock 병행. ④ **Bloodlust(AB-105) HP-scale** — `attack_interval_now`/`contact_damage_mult`가 `_missing_hp_frac`로 rage 램프(저장 mult=0HP 최대). 
- **이유:** 전부 기존 단일 경로/시그니처 확장으로 해결(새 시스템 0). next-hit는 `_deal_damage` 단일 chokepoint, 반사는 attacker 인자 1개 추가(기본 null → 기존 호출 무손).
- **BLOCKED(여전히 이연):** **Rampart(AB-034) 투사체 1회 흡수·threat-on-hit** — 전투가 target-locked/즉발이라 벽에 부딪힐 투사체 엔티티도, 벽으로 라우팅되는 공격도 없음 → **투사체 엔티티 시스템 선행 필요**(노력 아닌 의존성). **Tether(AB-103) leash-DoT** — 거리추적 트래커(beam_channel류 ticking 노드) 필요, 후속. dash i-frame·ccTenacity = 밸런스 후속.
- **검증:** party_pool_smoke §7/§8(next-hit 소모·channel 플래그·Sentinel 40% 반사 end-to-end·Bloodlust missing-HP 램프) + ci_smoke PASS.
- **영향:** `party_member.gd`(_next_hit_bonus·_sentinel_reflect·_channel_timer·take_damage attacker) · `combat_controller.gd`(_deal_damage 훅) · `enemy_ai.gd`(_apply_enemy_hit attacker 전달) · `enemy_unit.gd`(take_damage 시그니처·Bloodlust HP-scale) · `effects/sb_blink.gd`·`sb_beam.gd`·`sentinel_form.gd` · `skillbooks.json`(AB-061 next_hit_bonus) · `dungeon_run.gd`·`combat_sandbox.gd`(채널 게이트).

### IMPL-DEC-20260623-016 — 메타세이브 I5: RunLoadout config-only + 서브 충전수 영속 (B-리팩터 완료)
- **결정:** 메타세이브 B-리팩터 마지막 증분. ① **RunLoadout → config 전용**(formation/difficulty/run_seed) — 죽은 인벤 브리지 필드(`consumables`/`backpack`/`member_subs` + `set_consumables`) 제거(I2b/I3/I4에서 Backpack 오토로드로 이관 완료, `set_consumables` 호출자 0). ② **서브 충전수 영속** — `Backpack.apply_to_party`가 equip 후 저장된 잔여 탄수를 복원(equip은 max 리셋이라 clamp-set으로 덮어씀). 부분소모 스킬북이 런간 풀충전되던 버그(I3 ⚠️) 해소.
- **"완전 Backpack화"는 이미 도달:** 기어/스킬북/소비 stash↔backpack 이동은 `_drop` 가드 허용 + `_sync_stash_from_source` 동기화로 동작. haul=금고(재료 일원화)·generic=제거 → 스태시 입금 대상 아님(의도된 최종 설계). 추가 작업 불필요.
- **이유:** RunLoadout 인벤 잔재 = SoT 이중화 위험. 충전수 영속 = F-009 탄수 의미 보존.
- **검증:** party_pool_smoke에 charge-persist end-to-end(stored 3 복원, max 아님) 추가 + ci_smoke PASS.
- **영향:** `run_loadout.gd`(필드 제거) · `backpack.gd`(apply_to_party 충전 복원) · `inventory_ui.gd`(stale 주석) · `tools/party_pool_smoke.gd`.

### IMPL-DEC-20260623-015 — P2-S6a B2 잔여 bespoke 5종 (taunt/pull/slow/relocate/reveal) — 파티 풀 완료
- **결정:** 이연했던 bespoke 5종을 마저 구현해 파티 lootable 풀을 닫음. 신규 effect kind 5(taunt/pull/slow/relocate_ally/reveal) + ctx `reveal_enemies` 1 + EnemyVisibility reveal 훅 1.
- **타겟팅 회피(시스템 추가 없이):** ① **AB-035 taunt**·**AB-051 pull**·**AB-050 slow**는 기존 `enemy_unit` 공개 메서드(`add_threat`/`set_threat_floor`/`apply_knockback`/`apply_slow`)로 충분 — ctx 신규 API 불요. pull = `apply_knockback(caster−enemy)`(밀치기를 당김 방향으로). ② **AB-045 Lifeline**은 스펙 targetType=Ally지만 조준 시스템에 아군 픽이 없어 → **반경 내 최저 HP 아군 자동선택**(endangered 의미 보존), 새 타겟팅 UI 안 만듦. ③ **AB-032 reveal**만 시스템 훅 필요 → `EnemyVisibility`에 `_reveal_timer` + `reveal(dur)` 추가(활성 동안 LOS 무시 `set_seen(true)`), `ability_dispatch.reveal_enemies`가 group `enemy_visibility`로 호출.
- **근사:** taunt 'floor 50/5s'=영구 floor + 스파이크 감쇠로 시간제한 근사(threat decay); reveal '미니맵 flank 텔레그래프'=3D 포그 리빌(미니맵은 interactable만 그림); slow/pull threat=데모값.
- **대안(기각):** taunt용 ctx threat API 신설·아군 타겟팅 모달·미니맵 적 마커 — 모두 over-engineering, 기존 메서드/자동선택으로 동등 체감 달성.
- **검증:** party_pool_smoke(5 kind→effect 커버) + ci_smoke(EnemyVisibility 컴파일·dungeon_run 부팅) PASS.
- **영향:** `effects/sb_{taunt,pull,slow,relocate_ally,reveal}.gd`(신규) · `enemy_visibility.gd`(reveal 훅+group) · `ability_dispatch.gd`(reveal_enemies + 5 preload) · `id_registry.json`(5 ID)·`skillbooks.json`(5 엔트리)·`dungeon_run.gd`(ALLY_CACHE_POOL).

### IMPL-DEC-20260623-014 — P2-S6a B2 데미지 sub 19종 (신규 skillbook_bolt + 재사용; 5 bespoke 이연)
- **결정:** 남은 lootable 24종 중 **데미지/오펜스+재사용 가능한 19종**을 추가해 파티 풀 오펜스 라인을 닫음. 신규 effect kind는 **`skillbook_bolt` 1개만**(targeted 원거리 데미지, 옵션 `lightning`→LightningHit RX + Shock) — 라이트닝/원거리 너크 8종(AB-003/004/008/055/056/058/059/073)을 1 kind로 흡수. 나머지는 전부 기존 kind 재사용(strike/charge/blink/stun/vulnerable/dr/shield/execute/hot) + `skillbook_blink`에 `away` 플래그(AB-007 후퇴 hop) 추가.
- **이유:** B2 = "기존 kind 재사용·데이터 중심"이 원칙. 라이트닝 너크는 `skillbook_fire`(FireDamageHit→oil 점화)로 매핑하면 RX가 틀려서 1개 전용 kind가 정합적. 멀티히트/포크/차지 shape는 단일 `damage_mult` 합산으로 근사(spec params=design example).
- **대안(기각):** 24종 전부 구현 — AB-032 reveal·AB-035 taunt·AB-045 ally-relocate·AB-050 slow-cone·AB-051 pull은 **신규 시스템(시야 리빌·threat API·아군 타겟팅·슬로우/풀 kind)** 필요라 "데미지 sub" 범위 밖 + clean-first 원칙([[refactor-risk-preference]]) → **5종 이연**(B2 잔여).
- **근사:** AB-030 interrupt=stun 근사(stun이 적 캐스트 취소)·AB-012 HEX-WEAK=vulnerable 근사·AB-048 reflect/AB-074 redirect=dr 근사·AB-033 intercept-soak=shield 근사·AB-066 heal-zone=hot(반경 펄스) 근사. 모두 DRIFT-057 로깅.
- **검증:** party_pool_smoke(전 24 신규 포함 skillbook kind→effect 커버·sub_bands 밴드 검증) + ci_smoke PASS.
- **영향:** `effects/sb_bolt.gd`(신규)·`effects/sb_blink.gd`(away) · `ability_dispatch.gd`(preload) · `id_registry.json`(14 신규 ID)·`skillbooks.json`(19 엔트리)·`dungeon_run.gd`(ALLY_CACHE_POOL 확장).

### IMPL-DEC-20260623-013 — P2-S6a B1 잔여(stealth/buff/channel/barrier/purge/silence) + 밴드 패널티 + ally-cache
- **밴드 패널티 = 가산 `sub_bands`(equip_classes 게이트 유지):** D-016 mainClasses/subClasses 두 필드로 `equip_classes`를 쪼개는 대신, **`equip_classes`는 Role Equip Gate(=main∪sub) 그대로 두고** skillbook 마스터에 `sub_bands {classId: band}`만 가산. `ability_dispatch`가 `Slice01Data.get_skillbook_master(base_ability_id).sub_bands`로 coeff 산출(`BAND_COEFF {B0:1.0,B1:.9,B2:.75,B3:.55}`·`_band_coeff`). **대안(기각):** equip_classes를 main/sub로 전면 분리 — item_factory·equip_panel·loot_service·controlled_sheet·slice01_data 등 ~10 reader 변경 → 고위험. 가산 방식은 reader 0 변경. coeff 수치는 spec TBD(tuning).
- **신규 상태 = 기존 단일 chokepoint에 끼움:** ① **Veiled**(party) — `enemy_ai._is_hostile`가 veiled 멤버 false 반환 한 곳에서 타겟/헌트/스플래시 전부 드롭(중복 필터 없음). ② **Silenced**(enemy) — 6개 `_try_cast_*` 함수 top에서 `is_silenced()` 가드(평타·이동 게이트는 무손). ③ **Purge** — `outcome_status.remove(id)` 재사용 + `enemy_unit.purge_one_buff()`.
- **채널/배리어 = 노드 스폰(effect는 RefCounted):** Beam은 `beam_channel.gd`(Node3D) 자가틱, Rampart는 `rampart_barrier.gd`(StaticBody3D, world layer 1) — 둘 다 `ctx.add_child`로 디스패치 노드 밑에 붙고 self-free. 캐스트 effect는 스폰만.
- **의도적 근사:** Beam=cone 근사+Rooted move-lock(별도 Channeling 상태 없음); Rampart 투사체흡수·threat-on-hit 미구현(전투가 target-locked라 월드 투사체 라우팅 없음)·navmesh 미리베이크(물리차단만); Purge가 Bloodlust도 제거([[DRIFT-058]] 전파후보). AB-075=`skillbook_shield` 데이터 재사용.
- **ally 획득(사용자 선택=ally-cache 상자만):** ally-only lootable은 적 kit 롤로 안 떨어짐 → `dungeon_run`에 RM-ADV-01 ally-cache 상자(`ALLY_CACHE_POOL` 2종 랜덤, At-Risk). shop/드롭표는 S6b 본격.
- **검증:** `ci_smoke` + 신규 `tools/party_pool_smoke.gd`(전 skillbook kind→effect 커버·밴드 coeff·Veiled/Silenced/Purge 거동, ci_smoke 편입) PASS. 동작 체감은 플레이테스트.
- **영향:** `ability_dispatch.gd`(BAND_COEFF·_band_coeff·lightning_hit·spawn_barrier·5 preload) · `skillbooks.json`(sub_bands+6 마스터) · `id_registry.json`(6 AB) · `party_member.gd`(veil) · `enemy_unit.gd`(silence·purge) · `enemy_ai.gd`(_is_hostile veil·6 cast 가드·tick_silence) · `effects/sb_{stealth,beam,purge,silence,barrier}.gd`·`beam_channel.gd`·`rampart_barrier.gd` · `skill_vfx.gd`(smoke_puff) · `dungeon_run.gd`(ally-cache) · `tools/party_pool_smoke.gd`·`ci_smoke.sh`.

### IMPL-DEC-20260622-012 — 메타 세이브 단일 파일 통합 (SaveProfile) [Increment 1/4]
- **결정(사용자):** 진행상황 저장이 도메인별 파일(hub_profile.json·stash.json·신규 backpack)로 분산 → **단일 래핑 파일이 낫다**. `SaveProfile` 오토로드가 `user://save.json`(버전드) 1개를 소유, 도메인은 인메모리 + `to_dict()/apply_dict()`만. 이점: 원자적 저장·단일 리셋/백업 지점·버전 일원화·부분저장 불일치 제거.
- **구조:** `{version, hub:{}, stash:{}, backpack:{}}`. 도메인이 `SaveProfile.put(section, dict)`로 푸시(전체 1회 기록), `SaveProfile.section(key)`로 로드. autoload 순서: SaveProfile를 Stash/HubProfile **앞**에(먼저 로드). HubProfile `persist=false`(테스트)는 SaveProfile 미사용 → 인메모리 격리 유지.
- **마이그레이션:** save.json 부재 시 레거시 hub_profile.json/stash.json 1회 import(섹션 형태 동일 → 직접 fold) → 진행상황 보존. 검증: 부팅 후 save.json=keys[hub,stash,version] + 구 hub 진행(stash T1·enc_cleared·vault) 보존 확인.
- **이연:** Increment 2(Backpack 오토로드)·3(런 배선)·4(허브 편집) = Tarkov식 영속 백팩(추출=유지/사망=비우기). 별도 커밋.
- **검증:** ci_smoke + hub_smoke(persist=false 격리) PASS + save.json 라운드트립.
- **영향:** `save_profile.gd`(신규) · `hub_profile.gd`·`stash.gd`(파일I/O→SaveProfile) · `project.godot`(autoload).

### IMPL-DEC-20260622-011 — P2-S6a Phase 1: 제3세력 lootable 아군 효과 6종 (loot 루프 완성)
- **결정:** S6a(파티 능력 풀, L)를 가치 순 단계화 — **Phase 1 = 3세력 lootable의 아군 sb_* 효과**부터(루팅 루프 완성 + B1 effect kind 다수 납품). Phase 2=B1 잔여(heal/shield/HoT/silence/cleanse/relocate/pull/beam), Phase 3=B2 데미지 sub ~24.
- **구현(6종 drop-in effect):** `sb_root`(AB-102 Snare→Rooted)·`sb_pin`(AB-100 Pounce→타격+Pinned)·`sb_tether`(AB-103→Tethered)·`sb_charge`(AB-104 Rampage→cone 라인+KB)·`sb_execute`(AB-106 Devour→저HP×2+처치 시 시전자 회복)·`sb_scent`(AB-101→Scented). `ability_dispatch._SKILL_SCRIPTS`에 6 preload + `skillbooks.json` 6 마스터(equip_classes=스펙 mainClasses). 적용은 `enemy.apply_outcome` + 기존 ctx(deal_damage/cone/sub_shake) 재사용 — 신규 시스템 0.
- **의도적 근사/결정:** ① 파티 Pounce/Rampage는 *플레이어 대시 없이* 조준 타격(파티 이동은 컨트롤러 소관) — 핵심(Pin·라인뎀+KB)만. ② `sb_scent`는 Scented 마크만(리빌/추적) — 솔로 파티 효용 modest, "파티 포커스" 풀 페이오프는 튜닝 이연. ③ `sb_execute` 자가회복은 `m.has_method("heal")` 가드(파티 heal 경로 미확인 시 데미지만).
- **이연:** `sb_bloodlust`(AB-105 Tank 자가 rage) — 파티 평타 공속/뎀 훅(combat_controller `_tick_party_attacks` + party_member 상태)이 필요해 별도. + B1 잔여·B2.
- **검증:** ci_smoke(부팅·dispatch kind 등록·Slice01Data 마스터 검증) + third_smoke(6 마스터 kind 정합) PASS. 동작 체감은 플레이테스트.
- **영향:** `scripts/combat/abilities/effects/sb_{root,pin,tether,charge,execute,scent}.gd`(신규) · `ability_dispatch.gd` · `data/slice01/skillbooks.json` · `tools/third_smoke.gd`.

### IMPL-DEC-20260622-010 — P2-S5a-3: 제3세력 전용 적 3종(Stalker Pack) + 전용 능력 7종 구현
- **결정(사용자):** ENC-3RD-001 placeholder(EN-001/EN-010) → **전용 무리**로 교체. 핵심: 기존 파티 풀(AB-020~099)과 **메커니즘 중복 회피** — execute/vulnerable/cone/slow/blink/haste는 이미 존재하므로 단순 복제 대신 **distinct 변주**로 재설계.
- **스펙 선행(전파됨, `bc22c38` 재핀):** EN-3RD-01 추적자/02 포획꾼/03 학살자 + AB-100 Pounce·101 Scent·102 Snare Net·103 Tether·104 Rampage·105 Bloodlust·106 Devour + PT-023/024/025 + 신규 status(Rooted·Pinned·Scented·Tethered·Bloodlust) + effect 7토큰. DEC-20260621-001.
- **차별화 = 거동 + 신규 메커니즘**(능력 팔레트가 아니라): movement은 기존 orbit/kite/advance 재사용. 신규는 **predatory targeting**(`target_pref` weakest=Stalker·scented=Snarer/Reaver, threat-blind) + 6 effect kind.
- **effect kind 6종(enemy_ai):** `enemy_mark`(Scent→Scented+팩 공유)·`enemy_root`(Snare→Rooted 이동봉쇄)·`enemy_tether`(Tethered)·`enemy_frenzy`(Bloodlust 자가 rage, HP<50% 자동, 공속·뎀↑)·`enemy_execute`(Devour 저HP 처형+**처치 시 회복·쿨 환급** 연쇄). Pounce/Rampage는 `enemy_dash` 확장(`pin_s`→Pinned·`line`→관통 overshoot+splash). 캐스트 패스 `_try_cast_frenzy`/`_try_cast_third` 추가.
- **outcome(outcome_status):** Rooted·Pinned = `MOVE_MULT 0.0`(이동봉쇄·행동가능, `is_stunned`과 구별). Bloodlust = `BUFF`. enemy_unit `attack_interval_now()`/`contact_damage_mult()` + party_member/enemy_unit `has_outcome()`.
- **코드-버그 픽스(진영전 노출):** `_apply_enemy_hit`이 `target.identity_skill_id` 직접 참조 → 적-vs-적 시전 시 enemy_unit엔 없어 **크래시 위험** → `_tname(target)`(파티=identity / 적=enemy_id)로 교체. `enemy_execute` assassin-reveal 블록도 `and enemy.assassin` 가드(Reaver Devour 오발동 방지). hit-run-flank/flank-게이트는 `flank:true`로 한정(Pounce/Rampage가 EN-008 flank 로직 안 탐).
- **이연(S6a 파티 풀):** lootable 6종의 **아군 skillbook 효과(sb_mark/root/tether/execute/bloodlust/lunge 신규)**는 미구현 — 스펙에 lootable/equipClasses만 정의(Pounce/Tether/Devour=Nuker·Snare/Rampage/Bloodlust=Tank·Scent=Healer; DPS=원거리광역이라 0). 적 측만 S5.
- **검증:** `ci_smoke.sh`(부팅·hub·**third_smoke 신설**) PASS — Root/Pin move-lock·Bloodlust buff·AB kind·rom·패턴 target_pref·ENC 3유닛·faction 정합.
- **영향:** `enemy_ai.gd`·`enemy_unit.gd`·`outcome_status.gd`·`party_member.gd` · data(abilities/enemy_basics/enemies/patterns/ENC-3RD-001/id_registry) · `tools/third_smoke.gd`·`ci_smoke.sh`.

### IMPL-DEC-20260621-009 — 진영 견고화: N개 진영 + 혼합-진영 분대 (단일 진영 가정 제거)
- **결정(사용자):** 3세력이 "무조건 단일 진영은 아닐 수 있음" → IMPL-DEC-008의 "각 ENC=단일 진영 → 위험 자동 회피" 가정 폐기. faction(String)은 이미 N개 지원; 분대-결합 동작을 진영-aware로 만들어 견고화.
- **힐/지원 = 같은 진영만:** `_enemies_in_radius(pos, r, faction:="")` 진영 필터 추가. enemy_ai 힐 3곳(`_heal_follow_target`·`_try_cast_signature` heal 조건·`_apply_enemy_heal`)이 `enemy.faction` 전달 → 라이벌 진영 힐 안 함.
- **경보 전파 = 같은 진영만:** `_engage_enemy` 분대 wake에 `o.faction == e.faction` 가드 → 혼합-진영 분대여도 적끼리 안 깨움.
- **유닛별 faction override:** `_spawn_at`이 `u.get("faction", enc_faction)` → 한 ENC에 혼합 진영 가능(단일 진영 강제 해제).
- **이미 일반적이던 것:** `_is_hostile`(다른 진영=적대)은 N개 진영·상호 적대 그대로 지원(여러 라이벌 정예 무리 OK).
- **검증:** 던전 부팅·ci_smoke PASS.
- **영향:** `combat_controller.gd`(_enemies_in_radius 필터·wake 가드·per-unit faction)·`enemy_ai.gd`(힐 3곳).

### IMPL-DEC-20260621-008 — P2-S5a-1: 실시간 진영전 코어 (F-028 faction warfare)
- **결정(사용자):** 3세력도 ENC로 배정 + **3세력 분대 ↔ 일반 적 분대가 실시간 교전**(+ 양쪽 파티 적대). 풀 온스크린 진영전 — 파티-중심 전투 코어를 교차진영으로 확장. (저위험 오프스크린안 대신 사용자가 명시 선택.)
- **faction 필드:** `enemy_unit.faction`(기본 Dungeon). ENC `faction`(예: ENC-3RD-001=Third) → `_spawn_at`/`_spawn_squad`/`debug_spawn_unit`로 유닛에 설정. **각 ENC=단일 진영** → 혼합 분대 wake/heal 위험(에이전트 HIGH) 자동 회피.
- **교차진영 타겟팅:** combat_controller가 적 AI에 **전 전투원(파티+모든 적)** 전달; `enemy_ai._hostiles`/`_is_hostile`가 각 적의 적대 대상만 필터(파티 항상 + 다른 진영 적; 자기/같은진영 제외). tick의 perceive/pick_target/_nearest_visible/backline 모두 hostiles 사용. 파티 오토어택 루프는 **파티원만**(_tick_party_attacks 분리 — targets 오염 버그 픽스).
- **적-vs-적 데미지:** `_apply_enemy_hit`이 target.take_damage(양쪽 동일). **파티 전용 피드백**(party_damaged·party_hit·camera_shake)은 표적 파티원일 때만. enemy_poison은 has_method 가드(enemy_unit엔 없음).
- **partyInCombat 게이트:** '교전중'이라도 파티원에 대한 threat가 있어야 partyInCombat=true → 진영끼리만 싸우면 HUD/follower 미반응.
- **loot:** F-028 clearsRoomLoot:false → 누가 죽이든 드롭(플레이어 파밍 비차단) — 크레딧 게이트 없음.
- **테스트:** 샌드박스 "Third 진영" 체크박스(debug_spawn_unit faction) → Dungeon+Third 스폰해 진영전 관찰.
- **검증:** 던전 부팅(단일진영 무회귀)·샌드박스·ci_smoke PASS. **잔여(S5a-2):** ENC-3RD-001 + 3세력 EN(placeholder) + 런 배치 + 단서(소리/흔적) + cross-faction splash.
- **영향:** `enemy_unit.gd`·`enemy_ai.gd`·`combat_controller.gd`·`combat_sandbox.gd`.

### IMPL-DEC-20260621-007 — P2-S4 Hub 마무리: B4 ENC-clear 퀘스트 + B8 QA-029 스모크 + 문서
- **B4(런 이벤트 퀘스트, tractable 부분):** `HubProfile.enc_cleared`{} + `record_enc_cleared` — `combat.squad_cleared`(B7 신호)를 dungeon_run이 받아 기록. `evaluate_quests`에 `Q-HUB-020`(armory T1 = ENC-HARD-001 클리어) 추가 → 실제 플레이로 무기고 퀘스트 충족. enc_cleared도 영속(save/load).
- **B8(QA-029 스모크):** `tools/hub_smoke.gd` — T-HUB-003(부족 거부)·T-HUB-004(퀘+재료→승급·차감·Tier·capacity)·prereq·B4 Q-HUB-020·haul 드롭표 assert. **`HubProfile.persist` 플래그**로 fresh 인스턴스(persist=false)에서 검증 → user:// 실 save 미오염. `ci_smoke.sh`에 편입(`--script` exit + "HUB SMOKE PASSED").
- **이연(의존성, S4 아님):** B5 효과 실연동(armory B/C=GEAR-COR-000·분석/상점=F-009·passive=F-020·capacity friction) · B4 잔여(Q-HUB-003 맵1개·010 GIMMICK·040 recovery D6·050 NPC 미존재). 승급 메커니즘 동작, 효과/잔여는 해당 피처 소관.
- **스펙:** F-029/D-029/HUB-COR-000 구현 + draft 데모 데이터 확장. 규칙 변경 없음 → **전파 불필요**(핀 ef9c0c7 유지).
- **문서:** ROADMAP(P2-S4 ✅·Hub 커버리지·다음=S6a)·IMPL_COVERAGE(핀 ef9c0c7·last_sprint S4).
- **검증:** ci_smoke(main+dungeon+hub QA-029) PASS.
- **영향:** `hub_profile.gd`·`dungeon_run.gd`·`tools/hub_smoke.gd`(신)·`tools/ci_smoke.sh`·`ROADMAP`·`IMPL_COVERAGE`. **P2-S4 종료.**

### IMPL-DEC-20260621-006 — P2-S4 Hub B7: ENC별 haul 드롭표 (HUB-COR-000) + 분대 클리어 롤
- **무엇:** haulMaterial 드롭을 per-kill 임시 → **ENC(분대) 클리어 시 HUB-COR-000 §3 표로 롤**(스펙 정합). 클리어 지점에 재획득 가능 At-Risk ItemDrop.
- **데이터(`haul_drops.json`):** ENC별 [{haul,qty,chance}]. **ENC-NORM-001/002·HARD-001 = 스펙 정확값.** 그 외(NORM-003·PAT/AMB·HARD-00x·MID·DEEP·BOSS) = 데모 haul 커버리지용 **게임 확장**(레이어 적정 — HUB-COR-000 draft+Phase1b, spawn_table 확장과 동일 관례). 9 재료 모두 소스 보유. Slice01Data 로드+검증(ENC·haul id)+`get_haul_drops`.
- **분대 클리어 감지:** `_spawn_squad` squad dict에 `encounter_id`·`cleared` 추가, `_on_enemy_died`에서 `_squad_alive_count==0`이면 1회 `squad_cleared(enc, pos)` emit. `loot_service.on_squad_cleared`가 표 롤 → 드롭(격자 오프셋). per-kill haul 제거(per-kill loot=skillbook/gear/generic 유지).
- **결정:** per-kill가 아닌 per-ENC-clear(스펙 "동일 ENC 클리어 시 1회"). 정식 수치는 playtest 후(HUB-COR-000 Fixed 전 draft). §4 static haul node(상자)는 Phase1b/미구현(스텁).
- **검증:** get_haul_drops·던전 부팅(로드+검증)·ci_smoke PASS.
- **영향:** `data/slice01/haul_drops.json`(신)·`slice01_data.gd`·`combat_controller.gd`(squad_cleared)·`loot_service.gd`·`dungeon_run.gd`. P2-S4 핵심 루프(런 ENC클리어→haul→탈출→vault→승급→영속) 데이터 구동 완성.

### IMPL-DEC-20260621-005 — P2-S4 Hub B6: 메타 진행 디스크 영속 (HubProfile·Stash)
- **무엇:** 허브 메타(시설 Tier·vault·퀘스트)와 소유 아이템(Stash)이 세션 간 유지되도록 user:// JSON 저장/로드. 그전엔 autoload 메모리뿐이라 게임 재시작 시 전부 초기화 — 메타 진행의 핵심 갭.
- **HubProfile:** `save_profile`/`load_profile`(user://hub_profile.json) — `_ready`에서 로드(없으면 기본 Tier). 변경마다 저장: `add_haul`·`remove_haul`·`attempt_upgrade`·`evaluate_quests`(신규 완료 시 _q_dirty).
- **Stash:** `save_stash`/`load_stash`(user://stash.json) — `_ready` 파일 있으면 로드, 없으면 `_seed`+저장. 변경마다 저장: take/return_consumable·remove_gear·remove_skillbook.
- **선택:** B5(시설 효과 실연동)보다 B6 우선 — B5는 capacity 강제(friction)·armory gear(GEAR-COR-000 미존재)·F-009/F-020 미구현 의존이라 stub/대형. B6는 무friction·무의존·메타 완성. JSON 숫자=float이나 모든 read가 int() 캐스트라 무해.
- **검증:** 2-프로세스 라운드트립(run1 stash 승급 T1 저장 → run2 로드 T1)·테스트 save 정리·ci_smoke PASS.
- **영향:** `scripts/autoload/hub_profile.gd`·`stash.gd`. 다음 B7(haul ENC 드롭표)·B4 full(런 이벤트 퀘스트)·B5(효과, 의존 충족 후).

### IMPL-DEC-20260621-004 — P2-S4 Hub B2/B3: UI-029 시설 패널 + 승급 + B4-lite 퀘스트
- **무엇:** 허브에서 시설을 클릭해 다음 Tier 요구(Quest+Haul)를 보고 승급하는 UI. 승급 로직은 B0(HubProfile).
- **패널(`hub_facilities_panel.gd`, UI-029):** 풀스크린 오버레이. 8시설 리스트(이름·Tier·상태색 MAX/승급가능/잠김) → 선택 시 상세(현재/다음 effect·prereq·퀘스트 ✓✗·재료 have/need 색상) + [승급] 버튼(`attempt_upgrade`, 게이트 미충족 시 disabled). Vault 표시. HubProfile.facilities_changed/vault_changed 구독 자동 갱신. 허브 `main.gd`에 "허브 시설(승급)" 버튼.
- **B4-lite 퀘스트(`HubProfile.evaluate_quests`):** 충족 가능 stub(vault 수량·시설 Tier 기반) 자동완료 — Q-HUB-002/011/012/013/021/030/031/051. **런 이벤트형(010 GIMMICK·020 ENC clear·040 wipe·050 NPC·003 map success)은 B4 full**(런 훅)에서. 그 시설은 "quest"로 잠김 표시.
- **데모 편의(dev):** 재료 편집을 **선택 시설 상세 패널에 인라인**(별도 창 제거 — 창 겹침 해소). 선택 시설의 필요 재료마다 ±(`HubProfile.remove_haul` 신설)·"이 시설 재료 채우기"(그 시설 요구분만, 다른 재료 안 건드림). + 는 **이 시설 요구량 캡**에서 비활성(초과 방지). dim 0.85로 뒤 허브 UI 가림.
- **검증:** 부팅·ci_smoke PASS + 흐름(재료→Q-002 자동완료→stash T1 cap28 / scribe_shop prereq 차단 / smithy ok).
- **영향:** `scripts/ui/hub_facilities_panel.gd`(신)·`hub_profile.gd`(evaluate_quests)·`main.gd`(패널·버튼). 다음 B4 full(런 이벤트 퀘스트)·B5(시설 효과 게이트 — armory/quartermaster 실연동)·B7(haul ENC 드롭표).

### IMPL-DEC-20260621-003 — 인벤토리 버리기(Shift+우클릭): 런=바닥 드롭 / 스태시=영구 제거
- **무엇(사용자 갭):** 런 인벤·스태시에서 아이템 제거 수단이 없었음(B1 haul로 백팩 포화 시 정리 불가). 추가.
- **제스처:** `Shift+우클릭` **또는 인벤 창 밖으로 드래그** = 버리기. 둘 다 `_request_discard`로 모임 → **확인창(ConfirmationDialog)** → 확인 시에만 `_do_discard`. (드래그-아웃은 `_drop()` no-target에서 창 밖이면 일단 revert 후 deferred 확인 요청 — 취소 시 원위치.) 창 안 빈칸 드롭은 그냥 revert.
- **런 백팩:** 삭제가 아니라 **바닥에 재획득 가능 드롭**(사용자 지정). `inventory_ui.item_dropped` → `dungeon_run._on_item_dropped` → `loot_service.drop_item`(ItemDrop 발치 생성, 픽업 라우팅으로 복원). gear/skillbook/haul/generic 모두 재획득 OK.
- **허브 스태시:** 월드 없음 → **소유 영구 제거**. `inventory_ui.stash_item_discarded` → `main._on_stash_item_discarded` → `Stash.remove_gear/remove_skillbook`(신설)·consumable=take. 그리드는 lift, Stash 갱신 → 재진입 반영.
- **소스 구분:** `stash_source.is_stash_source()` 플래그로 스태시 loot vs 월드 상자 구분(상자 아이템은 버리기 없음, stow만).
- **범위:** 런 소모품 바(ConsumableController)는 별도 그리드라 미포함(소모품은 보통 사용; 필요 시 후속). 스펙 규칙 아님(F-010 인벤 UX 어포던스) → 전파 없음.
- **검증:** Stash 제거(4→3·missing=false)·허브/던전 부팅·ci_smoke PASS.
- **영향:** `inventory_ui.gd`·`stash_source.gd`·`stash.gd`·`loot_service.gd`·`dungeon_run.gd`·`main.gd`.

### IMPL-DEC-20260621-002 — P2-S4 Hub B1: haul vault 파이프 (At-Risk → 탈출 → vault)
- **무엇:** haulMaterial이 런 인벤(At-Risk)에 쌓여 → ExtractionSuccess 시 `HubProfile.hubHaulVault`(Safe)로 이관 → 시설 승급 소모. F-029 §3.2 / D-029 §4.
- **haul = 인벤 아이템 종류:** `ItemFactory.haul_item`(kind "haul" + haul_material_id, 1×1 ochre). `inventory_ui.add_haul_to_backpack`/`collect_haul`(backpack kind=="haul" → {id:count}). `item_drop` 픽업 라우팅에 haul 분기. → 스펙대로 haul은 run-inventory At-Risk 아이템(실패 시 lost_items, 캡 포함).
- **드롭(PH):** `loot_service`에 haul 드롭(흔한 Upper 재료 5종·30%) — **정식 ENC 드롭표 = HUB-COR-000(B7)** 전 placeholder. vault 파이프 체감용.
- **이관:** `run_end_controller._settle_extraction` = `collect_haul` → `HubProfile.add_haul`(런에서 제거). 실패 경로는 자동 lost(collect_run_inventory에 kind=="haul" 포함, vault 미적재). settlement_panel = "재료 N · → Vault" 표기.
- **런→허브 복귀:** 기존 Esc→main.tscn 재사용(별도 추가 X). 복귀 시 HubProfile(autoload)에 vault 반영됨.
- **검증:** haul_item 빌드·vault 누적·**전체 루프(vault+quest→stash 승급 tier1)**·던전 부팅·ci_smoke PASS.
- **영향:** `item_factory.gd`·`inventory_ui.gd`·`item_drop.gd`·`loot_service.gd`·`run_end_controller.gd`·`settlement_panel.gd`. 다음 B2/B3(업그레이드 게이트 UI = UI-029 허브 맵).

### IMPL-DEC-20260621-001 — P2-S4 Hub B0: HubProfile + 시설/퀘스트/haul 데이터 (F-029/D-029)
- **무엇:** P2-S4 Hub 1단계 — 데이터·인프라. F-029/D-029 스펙 그대로 게임 데이터화 + HubProfile 오토로드.
- **데이터(신규):** `facilities_tiers.json`(8시설 Tier 표: effect·value·quest·haul·prereq·armory catalog) · `quests.json`(13 Q-HUB-### + completion stub) · `haul_materials.json`(9 haul). id_registry에 `facility_ids`/`quest_ids`/`haul_material_ids` 등록.
- **HubProfile 오토로드:** facilities{}·hub_haul_vault{}·quest_completed{}. `upgrade_check`(D-029 §5: max/prereq/quest/haul reason)·`attempt_upgrade`(haul 소모·Tier+1)·`add_haul`(탈출 시 vault 이관)·파생(stash_capacity·run_inventory_capacity·armory_catalog_tier·can_analyze·shop_tier_ceiling). 세션 영속(디스크 저장=B6 후속).
- **Slice01Data:** 3 JSON 로드+검증(facility/quest/haul ID + tier 행의 quest/haul 참조 등록 확인) + getter(get_facility_tier/value/def·get_quest(s)·get_haul_material(s)).
- **결정:** armory catalog gear(gear_ward_*_iron 등)는 GEAR-COR-000 후속이라 미등록·미검증 → 카탈로그 비어있어도 승급은 동작(효과 stub). scriptorium/scribe_shop/chapel 효과는 F-009/F-020 미구현이라 Tier만 오름(pass-through).
- **검증:** 8시설·13퀘·9haul 로드, 승급 게이팅(quest→haul→ok→Tier+cap), prereq(scribe_shop), max(barracks) 전부 정상. 부팅·ci_smoke PASS.
- **영향:** `project.godot`(HubProfile 오토로드), `scripts/autoload/hub_profile.gd`(신), `slice01_data.gd`(hub 로드/getter), `data/slice01/{facilities_tiers,quests,haul_materials}.json`(신)·`id_registry.json`. 다음 B1(haul vault 파이프).

### IMPL-DEC-20260620-014 — Encounter Variety 목표 아키텍처 확정 + 빌드 S5 시퀀싱 (스펙 전파 예약)
- **결정(사용자 설계 토론):** 반복 탐험 변주의 **목표 구조를 미리 확정**하되 **빌드는 P2-S5(제3세력)와 함께**. 상세 = [docs/design/encounter_variety_architecture.md](../design/encounter_variety_architecture.md).
- **핵심 통찰(사용자):** ENC는 원자 콘텐츠가 아니라 **EN-* + 구성규칙(ENC-000 mechanicAxes/역할)의 조합 결과** → EN-* 추가 = ENC 공간 곱연산. "작은 ENC 로스터" 전제가 약해짐. 사례조사 결론(콘텐츠 아닌 *레이어*로 반복 해결)과 합치.
- **아키텍처:** Site→Group(레시피)→Scale(mechanicAxes 예산)→[generate|set-piece]→Modifiers(authored affix + **창발 런타임 주입**)→Pick(seed+비복원). 그룹=ENC ID 리스트가 아니라 **레시피**(ENC-000 역할 패밀리=proto-그룹) → 로스터 비의존 확장.
- **제3세력=창발 모디파이어:** F-028이 자기 전투로 ENC를 런타임 변조(교전중/정리/약화/증원) → authored affix에 과투자 불필요, Modifiers에 주입 훅만. 그래서 **제너레이터 + 3세력 모디파이어를 S5에 동시 빌드**(둘이 같이 값을 함).
- **하이브리드(중요):** 생성기는 ENC-000 가드레일(mechanicAxes≤2·역할캡·F-024) 필수 — 보스·QA핀은 authored set-piece 유지, "랜덤 슬롯"만 생성. full-gen 아님(손맛 리스크).
- **인터림 유지:** 가중+시드 resolve(DEC-20260620-002)+placement 변주+큐레이션 24 ENC = S5까지 충분. 지금 추가 빌드 없음.
- **스펙 전파 예약:** 빌드 시 ENC-000(group=recipe·예산 생성)/F-006(placement·modifier 주입)/F-028(3세력 훅) SSOT 편집 → OPS_30 → 재핀. **지금은 스펙 미편집**(설계 target 기록만).
- **영향:** `docs/design/encounter_variety_architecture.md`(신규). 코드 변경 없음.

### IMPL-DEC-20260620-013 — 확률적 ENC resolve(가중+런시드) + 스폰 위치 시드 산포
- **결정(사용자):** 방마다 ENC를 확률적으로 배치, 런 시작 시 결정 → 반복 변주 + 방보다 많은 ENC 소화. **스펙 전파 후** 게임 구현 (DEC-20260620-002, spec `ef9c0c7` 재핀).
- **resolver:** `Slice01Data.get_encounter_for_pool(... run_seed)` = `(pool, difficulty, layer)` 후보집합 수집 → `_weighted_pick`(weight·run_seed 결정론). forceEncounter override 우선(P-ADV-01=NORM-001 QA 핀 유지). run_seed=0(샌드박스)=첫 후보(결정론). placement는 기존대로 ENC `placement_behavior`에서 흐름.
- **run_seed:** `RunLoadout.roll_run_seed()`(randi) — dungeon_run 시작 시 1회 롤, ENC resolve + 스폰 산포 공용. 런 내 안정·재현.
- **스폰 위치 산포:** `_squad_spawn_center`가 run_seed로 deep point ±SPAWN_SCATTER_M(4.5m) 산포 + `NavigationServer3D.map_get_closest_point` 스냅(벽 안 방지). seed 0 → 산포 없음.
- **spawn_table.json:** `weight` 컬럼 + 전체 후보표(Normal PAT/AMB 편입·Hard 풀링·P-ADV-06~09). 임시 P-PAT/AMB pool_slot 제거(후보가 ADV/ENTRY/ROUTE 행에 편입돼 ENC 로드 유지 — 22 ENC 검증).
- **선택(중요):** picker는 `hash(run_seed|salt)` placeholder — 가중 순서는 맞으나 통계적 균등성은 근사(40 시드 테스트서 등가중 후보 15:4 편차; 실제 randi 시드는 더 고름). 정식 RNG는 필요 시. F-006 미편집(§3.1.2가 이미 허용).
- **검증:** resolver 변주·결정론·override·seed0·22 ENC 로드·샌드박스·ci_smoke PASS.
- **영향:** `scripts/autoload/slice01_data.gd`(resolver+_weighted_pick), `run_loadout.gd`(run_seed), `combat/combat_controller.gd`(resolve seed·스폰 산포·SPAWN_SCATTER_M), `run/dungeon_run.gd`(roll), `data/slice01/spawn_table.json`·`id_registry.json`. DRIFT-054.

### IMPL-DEC-20260620-012 — P2-S2-place 배치2: AMB-002 듀얼 앵커 순차 기상 + 스프링 reveal VFX
- **무엇:** ENC-AMB-002 `ambushAnchorCount:2` / `wakePolicy:sequential` 이행 + AmbushHold 발동 연출.
- **순차 기상(emergent, 타이머 아님):** 한 인카운터를 2개 앵커로 분할 스폰(라운드로빈 `index % anchor_count`), 앵커를 접근축 직교로 **ANCHOR_SEP_M 14m** 이격(> SQUAD_PROP_RADIUS_M 9m, > reveal 8m). 각 앵커는 **자기 근접(reveal)으로 독립 발동**. `_engage_enemy` 분대 기상 루프에 게이트 추가 — `wake_policy=="sequential"`이면 **다른 anchor_id는 깨우지 않음**(같은 앵커 동료만 동반 기상). → 파티가 앵커A 발동 후 이동해 앵커B reveal 진입 시 B 발동 = 자연스러운 순차.
- **결정:** 타이머 캐스케이드 대신 **앵커 이격+근접 발동**(공간적). 위치 기반이라 파티 동선에 반응 — 스펙 "2 anchors, sequential wake"와 합치 + 저위험(기존 reveal 재사용).
- **스프링 reveal VFX(별도 커밋 1111821):** AmbushHold dormant→engaged 전환 시 `SkillVfx.ambush_spring`(먼지 충격파+차인 먼지+모션 플래시) 1회. `_engage_enemy`에서 감지자(was=false)+동반 기상 동료 각각, placement 게이트. AMB telegraphTier=none → 전조 아닌 '당한 직후' 반응 피드백(placeholder).
- **enemy_unit 필드:** `anchor_id`·`wake_policy`. **검증:** JSON·샌드박스·ci_smoke PASS.
- **영향:** `combat_controller.gd`(_spawn_at anchor 분배·_anchor_center·ANCHOR_SEP_M·_engage_enemy 게이트+spring), `enemy_unit.gd`(anchor/wake 필드), `skill_vfx.gd`(ambush_spring), `data/slice01/encounters/ENC-AMB-002.json`.
- **잔여(배치2):** PAT-003 토치 배치(테스트 수단)·던전 spawn_table 실제 런 prespawn 배선.

### IMPL-DEC-20260620-011 — P2-S2-place 배치1: 배치 거동(Patrol/AmbushHold) + PAT/AMB 5 ENC
- **무엇:** 다음 스프린트 P2-S2-place 1단계 — 인카운터별 placement 거동 + patrol/ambush AI + PAT/AMB 인카운터 5종.
- **placement_behavior(인카운터 레벨, F-006):** Fixed(기본 roam)·Patrol·AmbushHold. `_spawn_squad`가 enc에서 읽어 `_spawn_at(... placement)`로 전달 → 각 유닛 `placement_mode` 설정. per-unit `interacts_with_objects`(torch bearer) 오버라이드도 spawn에서.
- **Patrol(`_tick_patrol`):** spawn home 둘레 자동 생성 루프(PATROL_POINTS 6·radius 6m) 연속 순찰. 지각은 `_tick_dormant` 그대로 → 발견 시 교전. (웨이포인트 수기작성 없이 맵-무관.)
- **AmbushHold:** `_tick_dormant`에서 **근접 reveal**(ambush_reveal_radius 8m, **facing cone 무시** — 매복) + 미발각 시 **제자리 hold**(roam 안 함). 스프링 시 정상 교전.
- **ENC 5종:** ENC-PAT-001/002/003·ENC-AMB-001/002 (data/slice01/encounters, id_registry 등록). PAT-003 EN-010 = torch bearer(interacts_with_objects, 토치 있으면 자동 픽업·투척 — 코드 0).
- **결정(스펙 정합):** placement는 인카운터 레벨(per-unit 아님). patrol 웨이포인트 = 자동 루프(수기 미작성). AMB-002 sequential wake + 던전 spawn_table 배선 + 토치 배치 = **배치2**.
- **검증:** JSON·id_registry·샌드박스(ENC 드롭다운에 PAT/AMB 노출, dormant 스폰 시 순찰/매복)·ci_smoke PASS.
- **영향:** `scripts/combat/enemy_unit.gd`(placement 필드), `combat_controller.gd`(_spawn_at/_spawn_squad placement 전달), `enemy_ai.gd`(_tick_dormant 분기·_tick_patrol), `data/slice01/encounters/ENC-PAT/AMB*.json`(신), `id_registry.json`.

### IMPL-DEC-20260620-010 — RX 연쇄 per-reaction VFX (절차적 placeholder)
- **결정(사용자):** 공용 버스트가 아니라 **반응별 고유 연출**(물+전기=물에 전기, 물+불=증기 등). 정식 아트는 후속 교체 — 지금은 **교체 가능한 절차적 기본값**.
- **skill_vfx 추가:** `rx_explosion`(주황 blast+glow+flame licks)·`rx_steam`(흰 wisp 상승)·`rx_burn`(녹색 tinge 화염)·`rx_toxic_flash`(녹황 ignition+puff)·`rx_freeze`(cyan crystal pop)·`rx_electrify`(cyan 아크 lightning_bolt ×6 across)·`rx_slick`(검은 oil 더블 ripple). 헬퍼 `_rising_wisp`(기체 상승)·`_pop_spike`(ice/flame 콘)·`_disc_off`.
- **reaction_system 배선:** 각 `_rx_*`/Hit 핸들러가 해당 연출 호출. 생성형(steam/burn/ice)은 spawn pos에 인라인, 결과형(electrify/slick/freeze)은 `_rx_burst`(zone 위치 dispatch). 폭발은 평면 telegraph → `rx_explosion`로 교체.
- **체감:** 7개 연쇄가 각각 다르게 보임 — "방금 무슨 연쇄가 터졌는지" 즉시 읽힘.
- **잔여:** 정식 아트/파티클·사운드는 후속. 존 원반 알파↑·상태 가독성(B/C)은 별도 옵션.
- **검증:** 컴파일·샌드박스·ci_smoke PASS.
- **영향:** `scripts/combat/abilities/skill_vfx.gd`(rx_* + 헬퍼), `scripts/combat/abilities/reaction_system.gd`(핸들러 배선·_zone_of/_rx_burst).

### IMPL-DEC-20260620-009 — P2-S3 Hit-RX 매트릭스 완성 (Lightning/Physical 축 추가)
- **무엇:** Hit-RX 매트릭스를 4축(Fire/Cold/**Lightning/Physical**)으로 완성 — S3d 매트릭스 마감.
- **Lightning(`RX_LIGHTNING_MATRIX`):** AB-004 enemy_charge 명중 시 `LightningHit` emit → Water→**Shock**(RX-LIGHTNING-WATER, 전도)·Steam→Shock weak(RX-STEAM-LIGHTNING). 매체 내 전 유닛 감전.
- **Physical(`RX_PHYSICAL_MATRIX`):** knockback(넉백 AB/평타) 명중 시 `PhysicalImpact` emit → Oil→**Slippery**(RX-OIL-PHYSICAL, 슬릭에 넘어짐).
- **공용 헬퍼 `_rx_outcome_in`**: 해당 매체 존 안의 전 유닛에 outcome 부여(피아무구분). cold/veg도 이걸로 통일.
- **체감:** EN-007 Water 깔고 EN-002 AB-004 감전 → 물 안 전원 Shock. 넉백으로 Oil에 밀면 Slippery.
- **잔여:** EnterZone aura = per-tick(별도)·WindGust spread = S3e(보류). 파티 Lightning/Physical emitter는 P2-S6a(파티 풀).
- **검증:** 컴파일·샌드박스·ci_smoke PASS.
- **영향:** `scripts/combat/abilities/reaction_system.gd`, `scripts/combat/enemy_ai.gd`. → **P2-S3 키스톤 사실상 완료.**

### IMPL-DEC-20260620-008 — P2-S3f 배치3: zone/cold AB 파티 lootable (skillbook)
- **무엇:** S3f "enemy+**lootable**"의 lootable 절반 — 파티가 looted 스킬북으로 zone/cold AB 직접 시전.
- **구현:** `skillbooks.json`에 7행 추가 — AB-009/036/039/040/042/043(cast.kind `skillbook_zone`)·AB-041(`skillbook_cold`). 이펙트 `effects/sb_zone.gd`(타겟 지점에 매체 zone 생성 → `ctx.spawn_zone`)·`sb_cold.gd`(AoE dmg + Chilled + `ctx.cold_hit`→ColdDamageHit). ability_dispatch에 등록 + ctx 파사드 `spawn_zone`/`cold_hit`.
- **체감:** 샌드박스 로드아웃(스킬북 카탈로그 자동 반영)에서 Nuker/Healer에 Oil/Water/… , DPS/Nuker에 Glacial Bolt 장착 → Q/E/R로 시전. 파티가 직접 존 깔고 Ember로 점화/Glacial로 결빙 등 콤보.
- **참고:** ability kind(spawn_zone/enemy_cold = 적 경로)와 skillbook cast.kind(skillbook_zone/skillbook_cold = 파티 경로) 분리 — 기존 AB-010(enemy_poison/skillbook_poison) 패턴과 동일.
- **검증:** JSON·컴파일·샌드박스·ci_smoke PASS.
- **영향:** `data/slice01/{skillbooks,id_registry}.json`, `scripts/combat/abilities/effects/{sb_zone,sb_cold}.gd`(신), `scripts/combat/abilities/ability_dispatch.gd`.

### IMPL-DEC-20260620-007 — P2-S3f 배치2: AB-041 GlacialBolt + Cold RX 매트릭스
- **무엇:** 7번째 zone AB(AB-041, cold attack) + ColdDamageHit 콤보 — Hit-RX 매트릭스를 Fire+Cold로 확장.
- **AB-041(kind `enemy_cold`):** telegraph 0.4·cd 5.5·dmg×1.2·Chilled 3s·range 10·vfx `shot_frost`(cyan cone 호밍). 공격 게이트(gate_kinds += enemy_cold)로 발동, 명중 시 Chilled + `ColdDamageHit` emit(타겟 위치). _PROJECTILE_VFX 추가(락온·도달 시 적용). EN-007 배선 + id_registry.
- **Cold RX(`RX_COLD_MATRIX`):** Water→**RX-COLD-WATER**(Water 소비→Ice 결빙) · Vegetation→**RX-VEGETATION-COLD**(Veg 내 유닛 Chilled/frostbite). reaction_system emit_event에 ColdDamageHit 디스패치.
- **체감:** EN-007이 Water 깔고 GlacialBolt → Ice. Veg면 frostbite. (불 Ember면 Water→증기·Veg→점화 — primaryMedium 우선순위로 분기.)
- **스코프:** Lightning/Physical RX·파티 로드아웃(skillbook)·spread(S3e) 잔여.
- **검증:** JSON·id_registry·샌드박스·ci_smoke PASS.
- **영향:** `data/slice01/{abilities,enemies,id_registry}.json`, `scripts/combat/enemy_ai.gd`, `scripts/combat/abilities/{reaction_system,skill_vfx}.gd`, `scripts/dev/combat_sandbox.gd`.

### IMPL-DEC-20260620-006 — P2-S3f 배치1: zone-spawn AB(6종) + 적 시전 (EN-004/005/007)
- **무엇:** 매체 존을 생성하는 공유 AB 6종 + 적 시전 경로. EN-004/007 "완성"(로드맵)의 콘텐츠.
- **AB(kind `spawn_zone`, abilities.json):** AB-009 Oil·AB-036 Water·AB-039 ToxicGas(dps 8)·AB-040 Ice·AB-042 Wind·AB-043 Vegetation. radius/ttl/cooldown = spec design-example PH. id_registry 등록.
- **적 시전(`_try_cast_zone`):** spawn_zone kind 보유 적이 쿨 차면 타겟 발밑에 **지면 마커 전조**(매체색, leave-the-spot 어포던스 = 진짜 회피 가능 AoE) → `_resolve_enemy_attack`의 `spawn_zone` 케이스가 `windup_pos`(전조 시점 위치)에 존 생성. `CombatController.spawn_zone` → `ReactionSystem.spawn_zone`(공개화).
- **EN 배선:** EN-004 += AB-009/042(Oil+Slippery·인화 / Wind) · EN-005 += AB-039(독안개) · EN-007 += AB-036/040/043(Water/Ice/Veg). per-ability cd로 스태거.
- **RX 연동:** 적이 깐 Oil/Water/Veg/ToxicGas에 AB-037 Ember(FireDamageHit) → S3d 매트릭스로 연쇄(Steam·점화·toxic flash·폭발). 샌드박스에서 적 스폰 + Ember로 관찰.
- **스코프:** AB-041 GlacialBolt(ColdDamageHit) + 파티 로드아웃(skillbook 카탈로그)·spread(S3e) = 배치2/후속.
- **검증:** JSON·id_registry·샌드박스·ci_smoke PASS.
- **영향:** `data/slice01/{abilities,enemies,id_registry}.json`, `scripts/combat/enemy_ai.gd`(_try_cast_zone·resolve·_zone_telegraph_color), `scripts/combat/enemy_unit.gd`(windup_pos), `scripts/combat/combat_controller.gd`·`reaction_system.gd`(spawn_zone facade), `scripts/dev/combat_sandbox.gd`(검증문구).

### IMPL-DEC-20260620-005 — P2-S3d primaryMedium resolver + FireDamageHit RX 매트릭스
- **무엇:** 이벤트→RX 파이프라인 가동 — Hit 타일의 primaryMedium을 resolver로 뽑아 **combo RX 1종** 발동(EVENT-CORE §3 / INT-002 §6.1).
- **resolver:** `_zones_overlapping(pt)` = 그 점에 겹친 ground_zone들(= 그 타일의 **activeMedia**) → `_primary_medium_of` = `RX_PRIORITY`(Oil>ToxicGas>Water>Fire>Steam>Smoke>Ice>Veg>Wind) 최상위 1개. (다중 매체 = 존 겹침으로 표현; 단일 존은 여전히 1매체.)
- **FireDamageHit 매트릭스(`RX_FIRE_MATRIX`, live 4종):** Oil→`_ignite_oil`(폭발+Ignited+Fire+Smoke·체인) · Water→**RX-FIRE-WATER**(Water 소비→Steam) · Vegetation→**RX-FIRE-VEGETATION**(소비→Fire/Ignited) · ToxicGas→**RX-TOXICGAS-FIRE**(가스 내 flash 데미지+Poisoned, 소비). Fire/Smoke/Ice/Wind primary → combo 없음(스킬뎀만).
- **테스트 경로:** AB-037 Ember(`ctx.fire_hit`)가 FireDamageHit emit → 샌드박스에서 매체 zone 깔고(Z) Ember 시전 → 매체별 다른 연쇄 관찰.
- **스코프:** Lightning/Cold/PhysicalImpact RX는 **emitter AB(S3f)** 도착 시 활성(현재 미emit). EnterZone RX(매체 진입 상태)는 per-tick aura가 이미 수행(중복 안 함). spread(S3e)·full ~19 RX는 후속.
- **검증:** 컴파일·샌드박스·ci_smoke PASS.
- **영향:** `scripts/combat/abilities/reaction_system.gd`(resolver·매트릭스·_rx_* 핸들러). 수치 PH(DRIFT-053 계열).

### IMPL-DEC-20260620-004 — P2-S3c 이벤트 버스 + EnterZone/ExitZone 엣지 (EVENT-CORE 토대)
- **무엇:** 상호작용을 **이벤트 모델**(EVENT-CORE)로 전환하는 인프라. 동작 변화 0 — S3d(RX 매트릭스)의 토대.
- **이벤트 버스:** `ReactionSystem.emit_event(event_id, payload)` 중앙 디스패치 + group `"event_bus"` 등록(존/스킬이 `call_group`으로 emit). 현재 핸들러 = `FireDamageHit`→oil 점화(`_on_fire_damage_hit`). EnterZone/ExitZone/Explosion/Lightning/Cold/Physical = 토대(소비자 S3d).
- **FireDamageHit 라우팅:** `fire_hit()`가 직접 oil 탐색하던 것 → `emit_event("FireDamageHit", {...})` → 버스가 RX-OIL-FIRE 핸들러로. 횃불/RX 체인 호출부 동일.
- **EnterZone/ExitZone 엣지:** `hazard_zone`이 `_inside` 멤버십 추적 — 진입/이탈 전이에서 이벤트 emit(무해 Smoke/Veg 존도 추적). per-tick aura 적용은 유지(이벤트는 RX 트리거용).
- **스코프:** resolver(primaryMedium)·activeMedia 다중·데이터주도 RX 매트릭스 = S3d. 버스는 그때 dispatch 확장.
- **검증:** 컴파일·샌드박스·ci_smoke PASS(동작 무변).
- **영향:** `scripts/combat/abilities/reaction_system.gd`(버스·fire_hit 라우팅), `scripts/world/hazards/hazard_zone.gd`(멤버십·엣지 emit).

### IMPL-DEC-20260620-003 — P2-S3b zone 매체 모델 (medium→outcome 디스패치) + RX-OIL-FIRE Smoke 정정
- **무엇:** zone을 환경 **매체(STATUS-ENV-CORE)** 모델로 — `hazard_zone.status` = 매체(9종 프리셋), 매체가 내부 유닛에 적용할 **OUTCOME을 디스패치**.
- **medium→effect 디스패치(`_apply_medium`):** Fire→**Ignited**(S3a 결과, dps 운반)·ToxicGas→Poisoned(party)/raw(enemy)·Water→Sodden·Ice→Chilled·Oil→Slippery·Steam→SteamHaze·Wind→WindBuffeted·**Smoke/Vegetation→무해**(Smoke=시야[deferred], Veg=가연만)·Fatal→raw. `MOVEMENT_MEDIA`는 dps 0이어도 tick(결과 적용). `STATUS_COLORS` 9매체 프리셋.
- **RX-OIL-FIRE 정정(드리프트 ①, game→spec):** 폭발 후 **ToxicGas(데미지 gas)** → **Smoke(무해·시야)** 로 교체 + 폭발 유닛에 **Ignited**(`APPLY-IGNITED-…-5S`) 적용 + Fire 잔류(Ignited applier). 스펙 `RX-OIL-FIRE-001`이 이미 "Smoke; 독·ToxicGas 아님" 명시 → **전파 아님, 게임 버그 수정**. (DRIFT-029의 "기존 spec 구현" 주장이 ToxicGas로 부정확했던 것 교정.)
- **스코프:** 단일 매체(`status`=primaryMedium). activeMedia[] 다중 스택 + primaryMedium resolver(Oil>ToxicGas>…)는 **S3d**. event bus(EnterZone/ExitZone)도 S3d.
- **수치 PH:** FIRE_DPS 8·IGNITE 5s·SMOKE_TTL 5s(spec SMOKE-5S). 실제 RX 매트릭스 수치=S3d.
- **검증:** hazard_zone/reaction_system 컴파일·샌드박스·ci_smoke PASS.
- **영향:** `scripts/world/hazards/hazard_zone.gd`, `scripts/combat/abilities/reaction_system.gd`. → DRIFT-053.

### IMPL-DEC-20260620-002 — P2-S3a 유닛 OUTCOME 상태셋 (공용 컨테이너 + Slippery 관성)
- **무엇:** P2-S3 Interaction(keystone) 착수 1단계 — STATUS-OUTCOME-CORE 원소 결과상태를 party+enemy 양쪽에 도입.
- **구현:** `scripts/combat/outcome_status.gd`(RefCounted) **공용 컨테이너** — party_member·enemy_unit가 각자 `_outcome` 인스턴스 보유.
  - 이동 결과(Sodden×0.7·Chilled×0.6·SteamHaze×0.85·Shock×0.55·Slippery×0.85)는 **하나의 move 배수로 합산**(최강 슬로우 우선) → `move_speed_mult`(party)/`current_move_speed`(enemy)에 fold.
  - **Slippery 완전구현**(사용자 선택): move 배수 + **관성** — player_controller는 `is_slippery()`면 저(低)가속(`SLIP_ACCEL_MPS2 10`), enemy_ai는 velocity를 `lerp(SLIP_ACCEL 3)` → 미끄러져 정지·방향전환 어려움.
  - **Ignited** = DoT(컨테이너가 whole-HP 틱 반환 → 유닛이 적용; party는 _apply_dot, enemy는 take_damage). **WindBuffeted** = 1회 impulse(소스가 knockback) + 표시 태그.
  - 상태 오브/오버레이 색 + get_status_list 통합. debug_reset에 `_outcome.clear()`.
- **드리프트 정리:** AB-004 `shock_slow`(ad-hoc apply_slow) → 정식 **Shock** outcome로 이관. (data shock_slow 0.5 미사용 → 컨테이너 const 0.55.) → DRIFT-052.
- **수치:** 전부 DEMO PH(SPEC_DRIFT). 실제 RX→status 매핑·수치는 P2-S3d.
- **검증:** outcome_status 컴파일·샌드박스·ci_smoke PASS.
- **영향:** `scripts/combat/outcome_status.gd`(신), `scripts/party/party_member.gd`, `scripts/combat/enemy_unit.gd`, `scripts/combat/enemy_ai.gd`, `scripts/run/controllers/player_controller.gd`.

### IMPL-DEC-20260620-001 — EN-008 Corner Knife 통합 거동 모델 (증상별 패치 → 단일 hit-run 루프)
- **배경(사용자):** EN-008에 후퇴·속도·leash·겹침 수정이 예외처리처럼 쌓여 "큰 원칙"이 없었음. 단일 원칙으로 통합 요청.
- **원칙:** *치고-빠지는 측면 암살자.* 두 질문(측면인가? 대시 준비됐나?)으로 결정되는 단일 루프:
  `REPOSITION → STRIKE(측면 백스탭) → RESET(kite out) → REPOSITION`. 정면 접근·근접 브롤 안 함.
- **FLANK 정의(사용자):** 파티 **spine = Tank(class_id "Tank") → 최후열(탱커에서 가장 먼 파티원)** 선에 **수직인 축**(`_party_flank_axis`, perpendicular). 파티의 노출된 옆구리.
- **구현:**
  - REPOSITION `_move_hit_run_flank`: 근접(<FLANK_KITE_TRIGGER 4m) 파티원 있으면 burst-kite(×1.7·leash해제), 아니면 `_flank_standoff`(타겟 + flank축×FLANK_KEEP 6m, L/R side + spine 스태거로 다중 분산)로 이동.
  - STRIKE `_try_cast_dash`(hit_on_arrival만): 현재 위치가 **flank 축 ±53°(FLANK_STRIKE_COS 0.6)** 안일 때만 백스탭 발동 → **정면 발사 제거**("직선적" 문제 해결). 아니면 hold(REPOSITION이 측면으로 돌게 둠).
  - RESET: 백스탭 후 타겟이 kite 트리거 안 → 자동 burst-kite로 standoff 복귀.
- **흡수된 기존 노브:** target_pref backline(타겟), FLANK_KEEP/KITE_TRIGGER/KITE_SPEED_MULT, leashed=false, 다중분산 — 전부 이 루프의 파라미터로 정렬. 폐기: 고정 backstep·월드각 링슬롯·tangent 서클(EN-008 한정).
- **분리 유지:** EN-003(AB-006 비데미지 갭클로즈)은 `_is_hit_run_flanker`=false → 기존 spiral-in으로 붙어 flurry(지속 딜러). flank 게이트는 hit_on_arrival 대시에만.
- **폴백:** Tank 없음/스파인 퇴화 → flank축 ZERO → standoff는 현재 베어링 유지(거리만 keep), 대시 게이트는 통과(정면 제한 없음).
- **검증:** 샌드박스·ci_smoke PASS. 체감 F6.
- **영향:** `scripts/combat/enemy_ai.gd`(_move_hit_run_flank·_party_flank_axis·_flank_standoff·_try_cast_dash 게이트·FLANK_* consts), `scripts/dev/combat_sandbox.gd`(검증문구). 관련 DRIFT-050/051·IMPL-DEC-014/016.

### IMPL-DEC-20260619-016 — 락온 유도 투사체 + 도달 시 데미지 (피할 수 없는 hit 모델)
- **결정(사용자: "피할 수 없는 기술(평타 포함)은 발현되면 타겟에 락온·유도되어 날아가고, 도달했을 때 데미지가 발생"):** 타겟-락(회피 불가) 원거리 공격의 VFX/데미지 타이밍을 일치시킴.
  - **유도(homing):** `_enemy_shot`에 옵션 `target: Node3D` 추가 — 주면 매 프레임 타겟의 **현재 위치**로 lerp(락온 추적), 없으면 고정 `to`로 직진(파티 `sub_lunge` 등 위치형 유지). 움직이는 타겟이 투사체를 시각적으로 "피한 것처럼" 뒤에 떨어지던 문제 해결.
  - **도달 시 데미지:** 데미지/상태/넉백/카메라쉐이크/히트인디케이터를 **resolve가 아니라 투사체 도달(`SHOT_FLIGHT_S`=0.4s) 시점**에 적용. `_resolve_enemy_attack`→`_deliver_enemy_hit`(VFX 발사 + 도달 타이머)→`_on_shot_arrived`(타겟 생존 시 `_apply_enemy_hit`). 비-투사체(근접 bash·번개)는 즉시(이동 없음).
  - **대상 vfx(`_PROJECTILE_VFX`):** projectile/shot_venom/shot_slag/shot_hex. 번개(shot_lightning ~0.14s)·strike·shield_bash는 즉시(체감 무이동).
- **부수 변경:** 스플래시(AB-008)도 락온 대상 → 전조를 지면 마커가 아니라 **시전자 큐**로(IMPL-DEC-013의 splash=지면마커 정정; primary는 락이고 splash는 도달 지점 주변 부수피해). 독 구름(`_poison_puff`)은 타겟에 **부모로 붙여 따라다님**.
- **인터럽트 경계:** 윈드업 중 stun = 취소(기존), **비행 중**엔 이미 발사돼 락온이므로 취소 안 됨(= "발현되면 락온"). 타겟 사망 시 무피해.
- **검증:** skill_vfx check·샌드박스·ci_smoke PASS. 체감 F6.
- **영향:** `scripts/combat/abilities/skill_vfx.gd`(SHOT_FLIGHT_S·_aim_basis·_enemy_shot homing·_poison_puff), `scripts/combat/enemy_ai.gd`(_deliver_enemy_hit·_on_shot_arrived·_PROJECTILE_VFX·splash 전조).

### IMPL-DEC-20260619-015 — 적 시그니처 발동 모델: every-N-평타 → AB별 개별 cooldown
- **결정(사용자: "AB를 쓰는거니까 평타 N번마다보다 AB 명시 쿨마다가 맞다 — 전체 EN 적용"):** 시그니처 발동을 평타 카운트(`attack_count % n`)가 아니라 **각 AB의 `cooldown_s`** 로 구동. 스펙 AB 카탈로그가 이미 `cooldown_s`를 정의(every_n은 데모 단축)하므로 **스펙 정합 방향**.
- **모델:**
  - `enemy_unit.ability_cd: Dictionary {ref -> 남은초}` (단일 `sig_cooldown_s` 폐기) — EN-001처럼 AB 2개(AB-099+AB-002)여도 **개별 타이머**.
  - 데이터: `enemies.json abilities[]`에서 `trigger`/`n` 제거(전부 `{ref}`). `abilities.json` AB-002/004/008/010/011/012에 스펙 `cooldown_s` 추가(3/5/2.5/2/5/4).
  - 디스패치 = AB **kind**별: 사거리 데미지(charge/splash/hex/melee/stun/poison)는 공격 게이트(`_select_enemy_ability`, 쿨 경과 시 평타보다 우선)에서, heal/provoke/dash는 각자 패스에서. 발동 시 `ability_cd[ref]=cooldown_s` 리셋.
- **체감:** 시그니처가 "쿨 경과 후 첫 공격"에 평타를 대체(평타 cadence로 약간 coarsen되나 의도대로 ~쿨마다).
- **검증:** JSON 로드·ci_smoke·샌드박스 부트 PASS.
- **영향:** `data/slice01/{abilities,enemies}.json`, `scripts/combat/{enemy_ai,enemy_unit}.gd`, `scripts/dev/combat_sandbox.gd`. 관련: DRIFT-049.

### IMPL-DEC-20260619-014 — 플랭커 타겟 우선순위 = backline (AB 특수처리 대신 디폴트 타겟 변경)
- **결정(사용자: "AB를 바꾸기보다 EN-003 디폴트 공격대상을 비-탱커로"):** 플랭커가 후열을 노리는 건 대시뿐 아니라 **유닛 전체 거동의 전제**여야 함 → 타겟 선정 자체를 backline-우선으로.
  - **patterns.json `target_pref`**: PT-003(EN-003)·PT-008(EN-008)에 `"target_pref": "backline"`. enemy_ai의 tick 타겟 선정에서 이 패턴이면 threat 타겟 대신 `_pick_backline_target`(비-Tank 최저HP) 우선(없으면 threat fallback). → 평타·오빗·대시 **전부** 후열(딜러/힐러)을 노림. EN-AI-000 §1 "정면 Tank 무시 시도" 정합.
  - **대시(AB-006/013) 백라인-특수처리 되돌림**(91c251d): `_try_cast_dash`는 다시 유닛의 현재 타겟 사용 — 그 타겟이 이미 backline이라 자연히 후열로 대시. SSOT 일원화(타겟=backline 한 곳).
- **설계 근거:** AB만 고치면 평타/오빗은 여전히 탱커 향함(불일치). 디폴트 타겟을 바꾸는 게 일관됨. threat(F-022) 무시 = 의도(플랭커 카운터는 탱이 아니라 피킹/인터셉트/Provoked).
- **검증:** patterns 로드·ci_smoke PASS. 실제 다이브는 F6(탱+딜 혼합 스폰).
- **영향:** `data/slice01/patterns.json`, `scripts/combat/enemy_ai.gd`.

### IMPL-DEC-20260619-013 — 전조 배치 컨벤션: placement = 회피 어포던스
- **결정(사용자 통찰):** 전조 VFX의 **위치**가 플레이어에게 회피 방법을 암시한다 → 배치를 회피 모델과 일치시킴.
  - **지면-임팩트 마커**(특정 장소에 디스크) = "이 자리를 벗어나라"(위치 회피). **벗어나면 실제로 회피/경감되는** 공격에만 사용.
  - **시전자 큐**(적 몸에 모션/오브) = "이 적이 [대상을] 친다 — 엄폐/인터럽트/스왑으로 대응, 사이드스텝 불가". **타겟-락**(위치 회피 불가) 공격에 사용.
- **현 적용(`_begin_enemy_attack` + 시그니처 함수)**:
  | 공격 | 전조 | 근거 |
  |------|------|------|
  | 평타(rom_*)·hex(AB-012) | `windup_cue`(시전자, amber/element) | 타겟-락 → 시전자 큐 |
  | 차지(AB-004) | `charge_up`(시전자 충전) | 타겟-락 → 시전자 |
  | 스플래시(AB-008) | `telegraph`(타겟 지면, splash_radius) | **위치형** — 흩어져 회피 |
  | 도발(AB-099) | `fan_telegraph`(시전자 전방 부채꼴) | **존** — 부채꼴 이탈로 회피 |
  | 힐(AB-098) | `telegraph`(시전자 중심, heal_radius) | 시전자 효과범위 정보(인터럽트 대상) |
  | 대시(AB-006/013) | `telegraph`(시전자, 크라우치) | 시전자 동작 |
- **배경 한계(미해결):** 단일대상 공격은 **타겟-락**이라 위치 회피가 *불가능*(LOS 끊기·인터럽트·stun거리·존이탈만 회피). "전조 보고 무빙 회피"는 미구현 — positional-dodge를 정책화하려면 spec(F-024/F-011 회피 모델) 확인 후 결정 필요(별도).
- **영향:** `scripts/combat/abilities/skill_vfx.gd`(windup_cue/charge_up/lightning_bolt/fan_telegraph), `scripts/combat/enemy_ai.gd`. (코드는 45bb269 등에서 반영.)

### IMPL-DEC-20260619-012 — AB-004 차지 VFX 재작 (차징 모션 + 즉발 번개 + 셰이크 타이밍)
- **결정(사용자: "차지 후 강력한 전기 볼트" — 현재 느린 파란 구 + 셰이크 타이밍 어긋남):**
  - **차징 모션:** `SkillVfx.charge_up(caster, dur, color)` 신설 — 시전자에 발광 오브가 채널(`telegraph_s`) 동안 커지며 강해지다 release 시 snap. `_begin_enemy_attack`의 `enemy_charge` 분기가 타겟 지면 디스크 대신 이걸 시전자에 띄움 + 타겟 조준(face_toward).
  - **즉발 번개:** `SkillVfx.lightning_bolt(from, to, color)` 신설 — perpendicular jitter 7-세그먼트 지그재그 아크가 **거의 즉시 플래시 후 0.14s 페이드**(`_bolt_seg` 얇은 emissive 박스). `shot_lightning`을 느린 `_enemy_shot`(0.55s 이동 구) → 이걸로 교체.
  - **셰이크 타이밍:** 셰이크는 resolve(피해 적용 프레임)에 발생하는데 기존 구는 0.55s 뒤 도착 → 어긋남. **볼트가 즉발이라 임팩트=resolve=셰이크 동시** → 정합(셰이크 코드 변경 없이 해결).
- **검증:** ci_smoke PASS · 샌드박스 부트 무오류. 차징·번개·셰이크 동시성은 F6.
- **잔여(동일 패턴 후보):** AB-012 hex·AB-008 slag도 `_enemy_shot`(0.55s 구)이라 셰이크-임팩트 약한 lag — hex는 fast bolt화 후보, slag(투척)은 도착 시 셰이크로 옮기는 게 정석. 사용자 요청은 AB-004 한정이라 보류.
- **영향:** `scripts/combat/abilities/skill_vfx.gd`, `scripts/combat/enemy_ai.gd`.

### IMPL-DEC-20260619-011 — S2c 적 스킬 VFX 정합 (원소색·찌르기·힐 이중/반경)
- **결정(샌드박스 발견 — "vfx 전반 불일치"):** S2c 시그니처들의 히트/텔레그래프 VFX가 원소·형태와 안 맞던 것 정리.
  - **발사체 색 하드코딩(주황) → 원소별**: `enemy_vfx`가 `projectile`/`shield_bash` 2키뿐 + `_enemy_shot` 색 고정(주황)이라 AB-004(전기)·AB-012(헥스)가 주황으로 발사됨. **키 추가**: `shot_lightning`(파랑)·`shot_hex`(보라)·`shot_slag`(주황)·`strike`(크림슨). abilities.json vfx 재지정(AB-004→shot_lightning·AB-008→shot_slag·AB-012→shot_hex·AB-013→strike).
  - **AB-013 Backstab `shield_bash`(파란 넉백 링) → `strike`**(`_enemy_strike` 신설 — 방향 쐐기 + 타이트 임팩트, 큰 지면 링 없음). 찌르기 느낌. shield_bash(넉백 충격파)는 AB-002 전용 유지.
  - **AB-098 Heal 이중 텔레그래프 제거**(cast+resolve→cast만; provoke와 동일 패턴) + **텔레그래프 반경 = 실제 반경**(`telegraph`에 radius 인자; heal 1.9→3.0, splash→splash_radius 1.5).
- **검증:** ci_smoke PASS. 시각 확인 F6/샌드박스.
- **영향:** `scripts/combat/abilities/skill_vfx.gd`, `data/slice01/abilities.json`, `scripts/combat/enemy_ai.gd`.

### IMPL-DEC-20260619-010 — AB-099 Provoke 버그 3종 수정 (샌드박스 검증발)
- **결정(샌드박스에서 사용자 발견):** EN-001 도발이 ① 자기중심 원형으로 보이고 ② 파티가 전방 fan에 없는데도 시전 ③ 두 번 쓰는 듯 보임 — 셋 다 수정.
  - **① 원형 VFX → 부채꼴:** 기존 `SkillVfx.telegraph`(반경 1.9m 원형 디스크, 자기중심) → **`SkillVfx.fan_telegraph`**(전방 `deg`°/`radius` 평면 sector 메시) 신설. 방향성이 보임.
  - **② false-cast:** provoke 트리거가 **early target-less 패스**(`_try_cast_signature`)에 있어 **stale `enemy.facing`**로 fan 판정 → 엉뚱. **late 패스 `_try_cast_provoke(enemy, target)`로 이동** — 교전 타겟을 `face_toward`로 조준(cast-start facing) 후 fan 판정. 전방 4m fan에 파티 있을 때만 시전.
  - **③ 두번:** `_apply_enemy_provoke`(resolve)가 텔레그래프를 **재차** 그려 두 번 시전처럼 보임 → resolve의 telegraph 호출 제거(시전 시작 fan_telegraph 하나만).
- **부수:** `_try_cast_signature`는 이제 heal(target-less)만 담당. provoke=`_try_cast_provoke`(타겟 필요)·dash=`_try_cast_dash`로 3분리.
- **검증:** ci_smoke PASS · 샌드박스 부트 무오류. 실제 도발 거동(전방 조준·빈존 미시전·단발)은 F6/샌드박스.
- **잔여:** 채널 중 attack-gate가 타겟 재조준 → 존이 cast-start에 완전 고정은 아님(근사, DRIFT-043 기존 항목).
- **영향:** `scripts/combat/enemy_ai.gd`, `scripts/combat/abilities/skill_vfx.gd`.

### IMPL-DEC-20260619-009 — Combat Sandbox (dev) — 단일 룸 + ENC 드롭다운
- **결정(사용자 디버깅 편의 요청):** 인카운터별 전투 거동을 격리 검증하는 **dev 전용 샌드박스 씬**. 던전 순회·fog·run-loop 없이 ENC 하나만 스폰.
  - `scenes/dev/combat_sandbox.tscn`(루트만) + `scripts/dev/combat_sandbox.gd`(오케스트레이터, 코드로 전부 빌드 — .tscn 취약성 회피) + `scripts/dev/sandbox_map.gd`(48×48 단일 룸: 바닥·벽 layer1 + navmesh bake + 조명 + `get_spawn_position`/`get_deep_spawn_position`).
  - **실 시스템 재사용**: PartyController·CombatController·CameraRig 그대로 → 거동이 게임과 동일. (Members 자식 선생성 + Camera3D 선부착 후 스크립트 set 순서로 _ready 의존 충족.)
  - **UI**: ENC 드롭다운(`Slice01Data.get_encounter_ids` 신설)·"spawn engaged" 체크(perception 스킵)·Spawn/Clear. 입력: 1-4 스왑·WASD·Q/E/R sub·휠 줌·RMB 오빗·`[ ]` 피치. Q/E/R 테스트용 스킬북 자동장착(AB-011 Toll Stun 포함 → 채널 interrupt 검증).
  - **CombatController.debug_spawn_only(enc, room, engaged)**(전 wipe→_spawn_squad) + **debug_spawn_unit(eid, count, room, engaged)**(단일 유닛 additive) 신설. `Slice01Data.get_encounter_ids()`/`get_enemy_ids()` 신설.
  - **UI 확장**: ENCOUNTER 드롭다운(replace)·SINGLE UNIT 드롭다운+count(additive)·spawn engaged·Clear. **우상단 info 패널**(RichTextLabel) — 단일 유닛 선택 시 그 유닛의 라이브 데이터(role/pattern→engage/기본타/시그니처/stats) + per-engage 거동 설명 + per-EN **검증 체크리스트**(UNIT_VERIFY); 유닛 (none)이면 선택 ENC 구성(유닛별 engage·assassin/boss 태그·증원) 표시.
  - **게임 HUD 동반**: 실 shipping UI-002 PartySheet(파티 HP + Q/E/R sub 쿨 radial) + UI-003 ControlledSheet(Identity 쿨 + Q/E/R 충전/쿨, 하단 중앙) 그대로 인스턴스 — 두 시트 모두 setup()에서 자가 빌드 + 자체 `_process`로 자가 갱신이라 추가 배선 불필요. 아군 스킬 쿨/충전이 게임과 동일하게 보임. (consumable_bar는 inventory_ui 의존이라 제외.)
  - **LOADOUT 패널**(어빌리티/아이덴티티 교체 — P2-S6 ability 풀 검증 대비): 컨트롤 멤버의 Identity 스킬(identities.json 드롭다운) + Q/E/R 서브(skillbooks.json 드롭다운)를 런타임 교체. **데이터 주도**라 향후 AB/identity 추가 시 드롭다운 자동 반영. `party_member.debug_set_identity(id)`(class/stats 불변, identity_params만 재지정 — 포메이션 안정) + `equip_skillbook_by_id`/`set_skillbook(null)`. 스왑(1-4) 시 그 멤버 로드아웃으로 dropdown 자동 갱신.
  - **Reset party 버튼**(재실험용): `party_member.debug_reset()` — 전원 alive·풀 HP·stun/poison/slow/shield/provoke 클리어·쿨(identity/sub/skillbook charges) 리필·다운 부활. 실험 후 파티 상태 망가져도 즉시 초기화.
- **격리:** shipping 플로우 미참조(직접 실행). 헤드리스 로드 PASS(party 스폰·navmesh bake·UI 인스턴스·무오류).
- **영향:** `scenes/dev/combat_sandbox.tscn`·`scripts/dev/{combat_sandbox,sandbox_map}.gd`(신), `scripts/{autoload/slice01_data·combat/combat_controller}.gd`(getter+debug 메서드).

### IMPL-DEC-20260619-008 — P2-S2-fin A4: Boss phase (ENC-BOSS-001 EN-002 MiniBoss) — Track A 완료
- **결정(사용자 "진행해"):** BOSS-001의 EN-002를 **per-ENC MiniBoss 오버레이**로 승격 + 50%HP 페이즈. Track A(P2-S2 combat-pool 마감) 마지막.
  - **MiniBoss 태그(assassin과 동형):** ENC unit 행 `"boss":true` + cc_tenacity/phase2_hp_frac/phase2_telegraph_delta. `_spawn_at`가 unit에 세팅 + `set_attention(true)`(attentionTier High).
  - **ccTenacity 1.2(enemy_unit.apply_stun):** 들어오는 stun을 `/cc_tenacity`로 단축(보스가 CC에 강함).
  - **50%HP 페이즈(take_damage):** hp ≤ max×0.5 교차 시 `boss_phased=true`(1회). `_begin_enemy_attack`이 phased면 텔레그래프 `+delta`(−0.15s, min 0.3) → AB-004 차지 1.0→0.85s, 페이즈2 위협 상승.
  - **ENC 정합:** EN-002(boss) + EN-010×2(스펙 Units). 기존 오기 EN-011 제거. group_size 3.
- **검증:** ci_smoke PASS · **Hard 헤드리스: BOSS-001@RM-BOSS-01 prespawn, 무오류**(복구). 페이즈·ccTenacity는 교전+피해 필요(F5).
- **미배선(정직):** **leash_m 28**(EN-AI-000 §3 거리-leash) — 현 disengage는 grace-timer라 미배선(S2 전반 공통, DRIFT-048). MainBoss/약화스택(F-006)은 스코프 밖.
- **Track A(P2-S2-fin) 완료:** A1 조합 ENC·A2 phase 증원·A3 assassin·A4 boss. ENC 12→17/24(고정 ENC + behaviors 완비). 잔여 ENC = PAT/AMB(placement 레인)·3RD(faction)·적 zone AB(F-027/P2-S3).
- **영향:** `scripts/combat/{enemy_unit·enemy_ai·combat_controller}`, `data/slice01/encounters/ENC-BOSS-001.json`.

### IMPL-DEC-20260619-007 — P2-S2-fin A3: AssassinTransform (NORM-003 신 + HARD-011 정합)
- **결정(사용자 "진행해"):** 위장 암살자 — fodder 무리 중 1기가 변장→reveal 전조→후열 처형. **per-ENCOUNTER 태그**(D-013 tags[], 유닛 카탈로그 아님).
  - **태그 배선:** ENC unit 행에 `"assassin": true` + `"assassin_telegraph_s"`. `combat_controller._spawn_at`가 그 행의 스폰에만 `unit.assassin`/`assassin_telegraph_s` 세팅(같은 enemy_id라도 비태그 행은 정상). enemy_unit에 `assassin`/`assassin_telegraph_s`/`assassin_revealed`.
  - **AI(enemy_ai):** 미리빌 시 ① 타겟을 **backline 재지정**(`_pick_backline_target` — 비-Tank 최저 HP) ② 공격 게이트에서 `_begin_assassin_execute` — 텔레그래프(`assassin_telegraph_s`, 크림슨 조준선) → `enemy_execute`(dmg ×3.0 + kb) → `_apply_enemy_hit`가 `assassin_revealed=true`. 이후 정상 EN-011(standoff) 거동.
  - **ENC:** NORM-003 신(fodder 5: EN-010×2·EN-011×2[1 assassin 0.6s]·EN-012). HARD-011 정합(기존 JSON 오기 EN-008/EN-010×3 → 스펙대로 EN-011 assassin 0.4s + EN-010×2·EN-011·EN-012). reachability: HARD-011 기존 P-ADV-05, NORM-003 = **P-ADV-03 Normal 행**(RM-ADV-03 기존, ENTRY→ADV-03 — 신규 룸 불필요).
- **검증:** assassin 태그 1기/ENC·텔레그래프(Python) · `ci_smoke` PASS · **Normal 헤드리스: NORM-003@RM-ADV-03 prespawn, 무오류**. 변장→reveal→execute 체감은 교전 필요(F5).
- **드리프트:** DRIFT-047 — 변장 모델(backline 재지정·execute·reveal 후 정상복귀)은 게임 인코딩(스펙은 tag+전조 수치만). 시각 변장 연출은 reveal 텔레그래프로 근사(박스 데모).
- **잔여 → A4:** Boss phase(BOSS-001 MiniBoss+50%HP) = Track A 마지막.
- **영향:** `scripts/combat/{enemy_ai·enemy_unit·combat_controller}`, `data/slice01/{encounters/ENC-NORM-003(신)·ENC-HARD-011·id_registry·spawn_table}`.

### IMPL-DEC-20260619-006 — P2-S2-fin A2: phase 증원 rear/flank (HARD-005 신 + HARD-010 수정)
- **결정(사용자 "A2"):** 기존 증원 시스템(`reinforcement{delay_s,units}` + `_tick_reinforcement`, HARD-001 활용)에 **방향(rear/flank)** 추가 + 2 ENC를 스펙 phase-2로 정합.
  - **방향 enrichment(`combat_controller`):** `_reinforce_center`(rear 고정) → `_reinforce_point(room_ref, direction)`: `rear`=spawn−z8(입구쪽, 기본)·`flank`=spawn+x9(측면 arc). `_reinforce_direction(squad)`로 squad.reinforce.direction 조회, telegraph·spawn 양쪽 적용.
  - **HARD-010 정합(수정):** 기존 JSON이 flatten(EN-008 opening·EN-001 누락·EN-011 오기) → 스펙대로 **phase-1**(EN-001·EN-010×2·EN-013) + **phase-2 flank 증원**(EN-008, delay 10s, direction flank).
  - **HARD-005 신규:** phase-1(EN-001·EN-010×2·EN-013×2) + **phase-2 rear 증원**(EN-005, delay 12s) → reachability용 RM-ADV-09(체인 남쪽 1칸 연장, P-ADV-09). HARD-010(flank)과 대칭.
  - 배선: rooms.json(+RM-ADV-09·ADV-08 connects)·spawn_table(+P-ADV-09 Hard)·id_registry(+ENC-HARD-005·RM-ADV-09·P-ADV-09).
- **검증:** 데이터 정합·RM-ADV-09 인접·HARD-010 opening에 EN-008 없음(Python) · `ci_smoke` PASS · navmesh 274→**284** · **Hard 헤드리스: HARD-010@ADV-03·HARD-005@ADV-09 prespawn, 12분대, 무오류**. 증원 wave 발동은 교전 필요(F5).
- **스펙 관계(DRIFT-046):** 스펙은 phase-2 런타임 spawn을 "F-006 Population 후속, ENC는 문서 훅만"(HARD-005 non-goal)이라 했으나 게임은 이미 reinforcement 런타임 구현 — **게임이 앞섬**(역전파 후보).
- **잔여 → A3/A4:** Assassin transform(NORM-003/HARD-011)·Boss phase(BOSS-001).
- **영향:** `scripts/combat/combat_controller.gd`, `data/slice01/{encounters/ENC-HARD-005(신)·ENC-HARD-010·id_registry·rooms·spawn_table}`, `scripts/world/map_demo_layout.gd`.

### IMPL-DEC-20260619-005 — P2-S2-fin A1: 조합 Hard ENC (HARD-002/003/004) + Upper 맵 확장
- **결정(사용자 "조합 ENC 먼저, 맵확장 포함"):** Full Coverage 잔여 ENC 중 **고정 조합 Hard 3종**을 구현 enemy kit로 채움. reachability가 데모맵 Upper Hard 풀 만석에 묶여 있어(P-ADV-01~05·EXT-ROUTE 6개 full) **Upper 룸 3개 확장** 동반.
  - **ENC JSON 3종**(기존 schema): HARD-002(RP-03 미끼+flank: EN-001·008·010×2·011·012)·HARD-003(RP-09 split: EN-003·006·010×2·012)·HARD-004(RP-04 mark: EN-001·007·010×2·012). 전부 구현 enemy(EN-001/003/006/007/008/010/011/012) — kit 완비(EN-007 zone은 F-027 잔여, hex만).
  - **맵 확장**(`map_demo_layout` ROOM_SPECS+CONNECTIONS): RM-ADV-06/07/08 — RM-ADV-03 남쪽 **선형 체인**(center z −45/−67.5/−90, all x∈[-13.5,13.5], 각자 직전 룸과 north/south 에지 공유 → navmesh 연결, 겹침 0). 임계경로(ENTRY→ADV-01→OBJ→ROUTE→EXT) 불변. 신규 풀 P-ADV-06/07/08.
  - **배선**: `rooms.json`(+3룸·ADV-03 connects)·`spawn_table`(+3 Hard·Upper·Advance 행)·`id_registry`(encounter_ids/room_refs/pool_slots +3씩).
- **스코프 결정:** **ENC-HARD-007 = Extreme 프로필 → deferred**(ENC Extreme=Expansion, FullSpecCoverage §7; 난이도 셀렉터 Normal/Hard만). 4종이 아니라 3종.
- **검증:** AABB 겹침 0·인접 3쌍 OK(Python) · `ci_smoke.sh` PASS · navmesh **244→274 폴리**(연결 bake) · **Hard 헤드리스(manifest 임시 Hard): HARD-002@ADV-06·003@ADV-07·004@ADV-08 prespawn 확인, 11분대, 무오류**(manifest·project.godot 복구). 실제 교전 F5 잔여.
- **드리프트:** EN-001 AB-099 Mockery = 유닛 상시 시그니처 vs 스펙 per-ENC `en001_mockery` 토글(HARD-004/002 off·006/009 on) → DRIFT-045(경미, per-ENC ability 게이팅 미모델).
- **잔여 → A2~A4:** HARD-005 phase 증원·HARD-010 flank 수정·Assassin transform(NORM-003/HARD-011)·Boss phase(BOSS-001). PAT/AMB=placement 레인.
- **영향:** `data/slice01/{encounters/ENC-HARD-002/003/004(신)·id_registry·rooms·spawn_table}`, `scripts/world/map_demo_layout.gd`.

### IMPL-DEC-20260619-004 — P2-S2c(4): 채널 interrupt + 적 stun primitive (EN-AI-000 §2)
- **결정(사용자 "interrupt-on-channel 마무리"):** S2c-1~3 전반에 누적됐던 §2 갭 종결 — 적 채널/캐스트를 **stun으로 끊으면 시전 실패 + 쿨 소모**. 선행 조건이던 **적 stun primitive 자체가 없어서**(적은 slow만 가능, Toll Stun이 `apply_slow(0.05)` 프록시였음) 같이 신설.
  - **적 stun(`enemy_unit`)**: `stun_timer_s`·`apply_stun`·`is_stunned`·`tick_stun`(party_member API 대칭). HP 0 no-op.
  - **interrupt(`enemy_ai.tick`)**: 매 틱 `tick_stun` 후 `is_stunned()`면 **winding/dashing 취소(=cast 실패, resolve 안 함) + velocity 0 + return**. winding-countdown **앞**에 배치 → stun이 resolve보다 먼저 이김. 시그니처 쿨(`sig_cooldown_s`)은 cast 시작 시 설정돼 **그대로 소모 유지**(AB-099/098 "쿨 전액 소모" 정합). every_n 캐스트(AB-004/008/012)는 쿨 없어 그 스윙만 취소(AB-004 "50% 환급"=N/A).
  - **Toll Stun 실화(`sb_stun`)**: 적에게 `apply_slow(0.05)` 프록시 → **`apply_stun(stun_s)` 실제 스턴**(freeze + interrupt). 플레이어 카운터플레이 성립: "EN-001 Mockery 채널 중 Toll Stun으로 끊기". apply_stun 없는 대상은 slow 폴백.
  - **interrupt 범위**: channel:true뿐 아니라 **모든 winding + dashing** 취소(stun은 진행 중 모든 행동 차단; §2 표가 AB-011 telegraph도 interruptible로 명시한 것과 정합).
- **1:1 근거:** §2 interrupt 정책·"쿨 전액 소모"는 spec 그대로. 적 stun primitive·"모든 winding 취소"·Toll Stun=실제 stun 전환은 게임 인코딩(스펙은 stun을 전제) → DRIFT-044.
- **검증:** `ci_smoke.sh` PASS(enemy_unit/enemy_ai/sb_stun 컴파일·부트 무오류). **채널 중 stun→취소 체감은 F5 잔여**.
- **해소:** DRIFT-041/042/043의 "interrupt-on-channel 미구현" 공통 잔여 종결(→ DRIFT-044).
- **미구현(정직):** AB-004 "쿨 50% 환급"(every_n이라 N/A)·적 stun 시각 피드백(VFX 없음, freeze만)·dormant 적이 stun되면 engage 전까지 미틱(희소, Toll Stun은 교전용).
- **영향:** `scripts/combat/{enemy_unit·enemy_ai·abilities/effects/sb_stun}`.

### IMPL-DEC-20260619-003 — P2-S2c(3): AB-099 Iron Mockery / Provoked (EN-001 존 도발 + party-side 상태)
- **결정(사용자 "진행"):** P2-S2 마지막 — 신규 **party-side `Provoked` 상태** + 입력 게이트. EN-001이 전방 부채꼴 존으로 파티를 도발해 **이동·스킬 잠금 + 시전자 강제 평타**.
  - **Provoked 상태(`party_member`)**: `provoked_timer_s`·`provoke_source`·`apply_provoke`·`is_provoked`(**stunned 시 false** = Stunned이 효과 억제, 타이머는 지속)·`get_provoke_source`(시전자 사망 시 무효화). `_tick_status` 감소 + 시전자 사망 조기종료. status orb/리스트에 red-orange 항목.
  - **AB-099 캐스트(EN-001 signature)**: `enemy_provoke` kind — telegraph 0.85s **channel**(channel-freeze 제자리), 쿨 14s, 전방 **60°/4m 부채꼴**. 타겟리스 zone → `_try_cast_signature`(조건=부채꼴 내 파티 1+, heal과 같은 조기 패스)·`_resolve`가 target 검증 **전** `_apply_enemy_provoke` 분기. `_party_in_fan`(facing 기준)로 조건·판정 공유. AB-002(every_n 3)와 자연 배타(채널 중 평타 게이트 `not winding`).
  - **효과 게이트(4곳)**: ① `combat_controller._tick_party_attacks` — provoked면 Identity/일반타겟 **스킵**, 시전자 대상 강제 평타(사거리 내). ② `player_controller` — 조작 멤버 입력 무시, 시전자로 **강제 접근**(nav, 사거리서 정지). ③ `party_controller` — NC provoked는 슬롯 대신 시전자 seek(`_provoked_seek_vel`, Pass1+Pass3 앵커). ④ `dungeon_run._on_sub_key` — Q/E/R 서브 캐스트 차단.
  - **스왑 허용(F-001)**: provoke는 **멤버 귀속** — 스왑해도 해제 X. 도발된 캐릭은 NC 경로로 시전자 강제 평타 지속, 플레이어는 다른 슬롯으로 계속 플레이. try_swap_to는 상태 비게이트라 자동 충족.
- **1:1 근거:** AB-099·telegraph 0.85·쿨 14·존 60°/4m·dur 2.0·스왑허용·Stunned우선 = spec `AB-099` Draft 그대로. `enemy_provoke` kind·강제이동 구현·존 facing(cast-start 대신 resolve, 채널 freeze라 ≈동일) = 게임 인코딩 → DRIFT-043.
- **검증:** `ci_smoke.sh` PASS(AB-099 등록·catalog·EN-001 ref 정합; party_member/party_controller/player_controller/combat_controller/enemy_ai 전부 컴파일·부트 무오류). **존 도발→조작상실→강제평타→스왑 회피는 F5 잔여**(교전+입력 필요).
- **미구현(정직):** ① **interrupt-on-channel**(채널 중 stun→시전 실패+쿨 전액 소모, AB-099/§2) — 현재 채널이 stun 무관 완주. ② **AB-031 Ward Pulse 클렌즈** 미구현(데모 무). ③ aim 모달 활성 중 provoke 진입 시 confirm 캐스트가 게이트 우회(희소 엣지).
- **P2-S2 완료:** S2a(ID 1:1)·S2b(포지셔닝)·S2c-1(캐스트)·S2c-2(대시)·S2c-3(Provoked). EN-001~014 전원 spec kit 반영(시그니처 AB + 패턴 + 기본타).
- **영향:** `data/slice01/{id_registry·abilities·enemies}`, `scripts/{party/party_member·party/party_controller·run/controllers/player_controller·combat/combat_controller·combat/enemy_ai·run/dungeon_run}`.

### IMPL-DEC-20260619-002 — P2-S2c(2): 대시 mobility primitive (AB-006 갭클로즈 · AB-013 백스탭)
- **결정(사용자 "C-2 진행"):** EN-003/008 플랭커의 시그니처 **대시**를 신규 mobility primitive로 추가. S2c-1 캐스트(데미지/상태/힐)와 분리한 이유 = 돌진은 **이동 takeover**라 라이브 이동 회귀면이 다름.
  - **Dash 모델 = knockback 미러**: 텔레그래프(crouch, `channel:true` → channel-freeze로 제자리) → `_begin_dash`가 dest·clamped 속도 산출 → `tick()`의 dash takeover 블록이 `DASH_TIME`(0.2s) 동안 `dash_vel`로 `move_and_slide`(벽 충돌 정지) → `_resolve_dash_hit`. enemy_unit에 dash 상태 6필드.
  - **AB-006 Gap-Close**(EN-003, telegraph 0.35, cd 4s): `hit_on_arrival:false` — 근접 직전까지 갭클로즈만(데미지 無), 이후 flurry/orbit 재개. dest = 타겟 방향 melee 직전.
  - **AB-013 Backstab**(EN-008, telegraph 0.30, cd 5s): `flank:true` + `hit_on_arrival:true` dmg ×1.5 + kb 1.0 — 타겟 **측면 점**으로 대시 후 도착 시 1타. side=instance_id%2(orbit과 동일 측).
  - **트리거 = cooldown+condition**(S2c-1 `sig_cooldown_s` 재사용): 대시는 **타겟 필요** → heal용 `_try_cast_signature`(타겟리스, 조기)와 달리 **target/dist/has_los 산출 후** `_try_cast_dash`로 트리거. 조건=LOS + 갭 존재(dist > range+0.5) + dash_range_m 내. `_resolve_enemy_attack`가 `enemy_dash` → `_begin_dash` 분기.
- **1:1 근거:** AB-006/013·telegraph_s·cooldown_s·×1.5 백스탭 = spec `abilities/AB-006·013.md` Draft. `enemy_dash` kind·DASH_TIME/MAX/FLANK 수치·knockback-미러 구현 = 게임 인코딩/PH → DRIFT-042.
- **검증:** `ci_smoke.sh` PASS(AB-006/013 등록·catalog·EN-003/008 ref 정합, EnemyAI 무오류). 실제 돌진(크라우치→런지→백스탭)은 F5 잔여.
- **잔여 → S2c(3):** **AB-099 Provoked**(EN-001 party-side 상태 + 입력 게이트) = 마지막. dash 벽-라우팅(현 straight lunge + 충돌정지)·AB-005 후속 flurry 연계·AB-007 HP≤50% 후퇴 hop = 후속 폴리시.
- **영향:** `data/slice01/{id_registry·abilities·enemies}`, `scripts/combat/{enemy_ai·enemy_unit}`.

### IMPL-DEC-20260619-001 — P2-S2c(1): 시그니처 캐스트 — 차지/스플래시/헥스/힐 (AB-004/008/012/098)
- **결정(사용자 "S2c 진행"):** 적 시그니처 능력 중 **데미지/상태/힐 캐스트**를 먼저 구현. 기존 텔레그래프 윈드업 + `every_n` 경로 재사용(신규 mechanic 최소화).
  - **AB-004 Charged Voltaic**(EN-002, `every_n 4`): `enemy_charge` — telegraph 1.0s **channel**, dmg ×2.0 단발 + **Shock**(party `apply_slow` 0.5/2s). 전기 블루 텔레그래프.
  - **AB-008 Slag Spit**(EN-004, `every_n 3`): `enemy_splash` — telegraph 0.4s, dmg ×0.8 + 착탄 `splash_radius_m` 1.5 내 파티원 splash(`_allies_in_radius`, `splash_frac` 0.6). 슬래그 오렌지.
  - **AB-012 Hex Bolt**(EN-007, `every_n 3`): `enemy_hex` — telegraph 0.45s **channel**, dmg ×0.4 + **HEX-WEAK**(`apply_slow` 0.6/4s = 이동감소). 보라 룬탄.
  - **AB-098 Mire Mend Pulse**(EN-014, `signature`): `enemy_heal` — telegraph 0.55s **channel**, 쿨 8s, **반경 3m 적 분대(자신 포함) 각 max HP 8% 회복**, 조건=반경 내 아군 <90%. EN-014는 kite라 평타가 드물어 `every_n` 불가 → **신규 cooldown+condition 패스**(`enemy.sig_cooldown_s` + `_try_cast_signature`). 타겟리스라 `_resolve_enemy_attack`가 party-target 검증 **전에** `_apply_enemy_heal` 분기. enemy_unit `heal()`(녹색 플래시) 신설.
  - **Channel-freeze**: `winding && windup_eff.channel`이면 `_engage_move`가 ZERO 반환 → 채널 중 제자리(EN-AI-000 §2; EN-007 이동금지·EN-002 charge·EN-014 pulse 제자리). **비-channel 텔레그래프(AB-010/011)는 기존대로 이동 유지**(회귀 0).
- **1:1 근거:** AB-### · telegraph_s · cooldown_s · heal 8%/r3 · Shock/Hex 상태는 spec `abilities/AB-*.md` Draft "design examples". `enemy_*` kind·이동 freeze·splash_frac은 게임 측 인코딩/PH → DRIFT-041.
- **부분 구현(정직):** HEX-WEAK "**피해 감소**" 절반은 미구현(이동감소만) — 파티 공격 데미지 경로 훅 필요, 후속. Shock/Hex 둘 다 slow로 표현(텔레그래프 색·지속·소스로 구분).
- **검증:** `ci_smoke.sh` PASS(hub+던전 부트, parse/load/validate 무오류 — AB-004/008/012/098 등록·catalog·enemies ref 정합). 실제 교전 체감(차지 한 방·헥스 둔화·**EN-014 힐 펄스로 분대 장기화**)은 F5 잔여(헤드리스는 입력 없어 교전 미발생).
- **잔여 → S2c(2/3):** **AB-006 Gap-Close·AB-013 Backstab 대시**(EN-003/008, 신규 mobility primitive) · **AB-099 Iron Mockery / Provoked**(EN-001, 신규 party-side 상태 + 입력 게이트) · HEX 피해감소 half · interrupt-on-channel(채널 중 stun → 쿨 소모).
- **영향:** `data/slice01/{id_registry·abilities·enemies}`, `scripts/combat/{enemy_ai·enemy_unit}`.

### IMPL-DEC-20260618-004 — P2-S2b: Per-enemy 교전 포지셔닝 (EN-AI-000 / PT-### → engage 프로필)
- **결정(사용자 "잘된 s2b ㄱㄱ"):** F-013 Engaged 위에 **유닛별 이동 차별**을 데이터 주도로 얹음. 적이 전원 "최고위협 추격→사거리서 평타"하던 균일 행동 → 아키타입별 포지셔닝.
  - **`data/slice01/patterns.json`(신규)** — D-017/`PT-###` 카탈로그 미러(`formation_role`/`band`/`anchor`/`spacing`/`retreat` verbatim) + 게임 파생 키 **`engage`**. SSOT=spec `patterns/PT-*.md`@`4422e50`. 14패턴(PT-001~009/012~016). `id_registry.pattern_ids`에 적 PT 13종 추가(기존 PT-010/020/021/022 = 플레이어 역할 패턴 유지). `enemies.json` 각 행 **`pattern_ref: PT-###`**(EN 유닛문서 `patternRef` 정본 — EN-010~013→**PT-012~015**, EN-AI-000 §1표의 "PT-010~013"은 loose).
  - **`engage` 7종 디스패치**(enemy_ai `_engage_move` + 헬퍼): `advance`(EN-001/010/012 근접추격→평타, EN-013 `chase_speed_mult` 1.1)·`standoff`(EN-002/007/011 사거리 hold·도주無, "후퇴 bias 없음")·`kite`(EN-005/014 적 `MELEE_THREAT_M` 4m 진입 시 leash 클램프 후퇴)·`zone`(EN-004 앵커 `zone_radius_m` 내만 교전·이탈 시 복귀)·`orbit`(EN-003/008 측면 arc 접근, side=instance_id%2)·`probe`(EN-006 타격 후 `PROBE_BACKSTEP_S` 백스텝)·`surround`(EN-009 instance_id%8 링 포위).
  - **이동만 분기, 공격 게이트는 공통** — `tick()`이 `_engage_move`로 velocity 결정(ZERO=plant) 후 `dist<=attack_range && LOS && off-cd`면 동일하게 strike(kiter는 후퇴하며 사격). 앵커=`home_pos`(스폰), leash 18m 클램프로 맵 밖 도주 방지.
- **1:1 근거:** `PT-###`·카탈로그 필드는 spec verbatim(등록 ID). `engage` enum·이동 수치(`MELEE_THREAT_M`/`ENGAGE_LEASH_M`/`ZONE_RADIUS_DEFAULT`/`ORBIT_ARC_M`/`PROBE_BACKSTEP_S`)는 **게임 측 파생/PH 튜닝**(EN-AI-000 "Engaged 우선" + §3 leash default) → `SPEC_DRIFT` DRIFT-040.
- **검증:** Godot 4.5.1 헤드리스 — `ci_smoke.sh`(hub+던전 부트, parse/load/validate 무오류) PASS; 던전 300프레임 4분대 prespawn·dormant/roam 무오류. **교전 포지셔닝 체감(백라인 카이팅·플랭크·서스테인 후퇴)은 F5 수동 검증 잔여**(라이브 입력 필요).
- **잔여 → S2c:** 시그니처 AB 캐스트/채널(AB-004/006/008/012/013)·AB-098 Mire Mend Pulse(EN-014 후열 힐)·AB-099 Iron Mockery(EN-001 Provoked 신규 party-side 상태)·AB-007 HP≤50% 후퇴 점프(EN-003)·**거리 기반 leash 이탈**(현 grace-timer 유지) + interrupt/channel 정책(EN-AI-000 §2).
- **영향:** `data/slice01/{patterns.json(신)·id_registry·enemies}`, `scripts/{autoload/slice01_data·combat/enemy_unit·combat/enemy_ai}`. (S2a 잔재 orphan `.uid` 4종 정리 동반.)

### IMPL-DEC-20260618-003 — P2-S2a: Combat ID 1:1 정합 (rom_* basics + 비-spec AB 제거)
- **결정(사용자 지시 "최종형은 spec과 1:1, 비-spec combat 객체 제거"):**
  - **적 기본타 → `rom_*`** — 신규 `data/slice01/enemy_basics.json`(12 archetype, EN-COR-000 §rom_* 표) + `id_registry.enemy_basic_attack_ids`. **AB-### 카탈로그와 분리**(spec: rom_*는 D-016 미등록, DEC-20260618-004). `slice01_data.get_enemy_basic()`; `enemy_unit.basic_attack`; `enemy_ai`가 `rom_` 접두 ref는 enemy_basics에서, 그 외는 AB 카탈로그에서 해석. multi-hit는 1회 total로 fold(true 순차 = S2b).
  - **삭제(비-spec):** `AB-001/014/015/016`(spec에서 rom_*로 통합·삭제됨) + `AB-S01~04`(비-spec 데모 플레이어 서브). abilities.json·id_registry·skillbooks.json(데모 starter 4종)·identities.json(`sub_ability_id` 필드)·effects/{taunt,lunge,nova,sanctuary}.gd(4) 삭제·ability_dispatch `cast_sub`·combat_controller `cast_sub`·party_member `_init_starter_skillbook` 제거. 서브는 이제 **루팅 스킬북만**(F-009, Q/E/R 빈 상태 시작).
  - **EN-014 → Gutter Chanter (SustainTrash)** — 게임 데모의 "Torch Bearer"(비-spec, DRIFT-033) 폐기. **횃불 carry는 ENC-bound `worldInteractProfile`**(EN-AI-000 §6), 유닛/별도-EN 아님; 데모 바인딩 EN-010@`ENC-PAT-003`=Patrol=**P2-S3**. 현재 미바인딩(휴면) — 오브젝트 프로토콜 코드·ENT-TORCH·파티 carry(F-021)는 유지.
  - **ENC-NORM-001 정합** — EN-014(이제 specialist) 제거 → Elite1+Fodder4(variant 3종)+Specialist0.
  - **검증 강화:** `_parse_enemies`가 `basic_attack`(∈enemy_basic_attack_ids)·`abilities[].ref`(∈ability_ids) 검증 → 적 기본타·시그니처 1:1 강제.
- **검증:** Godot 4.5.1 헤드리스 — hub/던전 Normal·Hard 로드·prespawn·부트 무오류. 실제 교전(rom_* 기본타 체감)은 F5.
- **해소:** `SPEC_DRIFT` DRIFT-001(AB-S0x 제거로 종결)·DRIFT-033(EN-014→Gutter Chanter)·DRIFT-026(서브=스킬북 전환 완료).
- **잔여:** 시그니처 AB-004/006/008/012/013(EN-002/003/004/007/008)·AB-098(EN-014)·AB-099(EN-001) = **S2c**; per-enemy 행동 훅 = **S2b**; `pattern_ids`(PT-010/020/021/022) 1:1 점검; party_member 잔여 `sub_params`/`sub_ability_id`/`sub_cooldown_s` inert 필드 = 후속 dead-code 정리.
- **영향:** `data/slice01/{enemy_basics.json(신)·id_registry·enemies·abilities·identities·skillbooks·encounters/ENC-NORM-001}`, `scripts/{autoload/slice01_data·combat/enemy_unit·combat/enemy_ai·combat/combat_controller·combat/abilities/ability_dispatch·party/party_member}`, effects/{taunt,lunge,nova,sanctuary}.gd 삭제.

### IMPL-DEC-20260618-002 — Vision fog 미탐지 프롭 가림 + 천장 패스 계획(이연)
- **결정(구현):** 미방문(never-reached) 방에서 **발광 프롭이 fog를 뚫고 보이던** 문제 수정. ① fog 미탐지 색을 휘도비례(`vec3(g)*dark_dim`) → **평면 검정**(`vec3(dark_dim)`, `dark_dim` 기본 0)으로 — 오브젝트 밝기 무관 완전 가림. ② `occluded_lum_cap`(0.3) 신설 — **explored 기억** 영역의 밝은 프롭이 비콘처럼 튀지 않게 휘도 클램프(미탐지=평면, 가시=discard라 둘은 영향 없음). ③ `vision_fog.fog_object()` 공개 — `dungeon_run`이 setup **이후** 스폰하는 `door/trap/chest/lever/barrel/torch`에 fog `next_pass`를 명시 적용(`$Rooms` 밖이라 초기 `_apply_fog_to_world` sweep이 못 잡음).
- **결정(이연 = 천장 패스, 천장 지오메트리 도입 시):** ① 벽/천장 높이↑(현 `WALL_HEIGHT 3.5`), **천장=벽높이 커플**(full-height 벽이라야 옆방 차단). ② **카메라를 천장 아래 유지**(천장 ≳ `max_zoom·sin(85°)` + 여유) → 전 피치에서 천장 미차폐. ③ **폴백:** 카메라가 천장선 초과 시 **룸단위 천장 페이드-투-0**(메시만, 광원 유지). 벽 see-through=반투명(0.16) vs **천장=완전투명(0)**. ④ **광원 `shadow_enabled` ON**(현 `lantern.gd` false → 빛이 벽 투과; 개구부로만 새려면 필요). ⑤ **fog dim 복원**(`dark_dim` 0→~0.07 + `dark_col` 휘도반영 복귀, **1줄 플립**) → 미탐지역에 *빛/그림자 샘*만 보이고 구조는 천장이 차단. ⑥ 대안: 고피치서 줌 강제축소로 천장 높이 절감.
- **이유:** 현재 천장이 없는 개방 구조라 원거리/고각에서 미탐지 방 구조가 읽힘 → 임시로 전부 검정 처리. 천장이 생기면 **구조 차단은 지오메트리·카메라가** 맡고 fog는 기억 무채색 + 개구부 빛샘만 담당하는 게 옳음(브루트포스 검정 탈피).
- **영향(구현):** `assets/shaders/vision_fog.gdshader`, `scripts/run/controllers/vision_fog.gd`, `scripts/run/dungeon_run.gd`. (이연 영향: `lantern.gd`·`run/controllers/camera_rig.gd`·`world/map_demo_layout.gd`·`vision_fog.gdshader` — 천장 패스 때.)

### IMPL-DEC-20260618-001 — P2-S1 던전 스케일 (spawn resolver + 다층맵 + ENC/EN 스텁)
- **결정:** Phase 2 Full Spec Coverage(`4422e50`) 첫 스프린트 — slice01을 spec `LDG-SPAWN-DEMO-001`에 맞춰 확장(신규 빌드 아닌 기존 자산 리팩터). ① `spawn_table.json` + `Slice01Data.get_encounter_for_pool(pool, difficulty, world_layer)`(force override > 정확 > (pool,diff) any-layer). `_load_encounters`가 spawn 참조 ENC까지 로드. `combat_controller.prespawn_encounters`·`run_controller` 호출부 신 API로. ② `rooms.json` `world_layer` + 신규 6룸(Upper/Mid/Deep), `map_demo_layout` ROOM_SPECS/CONNECTIONS **6→12룸**. ③ `run_controller` 룸 하드코딩 → `run_phase_on_enter` 단조 `SEQUENCE`. ④ ENC 9 + EN 6 스텁.
- **이유:** 데모 스코프 캡 해제(Phase 2). spec이 이미 정의한 resolver/world_layer/pool·room 구조의 구현.
- **대안:** ROOM_SPECS를 rooms.json geometry로 완전 이전(DEBT-DM3) — 범위·회귀위험 커서 **이연**(절차 placeholder 기하 유지). EN 실제 kit 즉시 구현 — **P2-S2로 분리**(스텁=placeholder 스탯+재사용 AB).
- **검증:** Godot 4.5.1 헤드리스 — Normal(NORM-002/001·MID-001·DEEP-001)·Hard(BOSS-001 등 8분대) prespawn resolve·navmesh 244폴리·5단계 전환 OK. **인터랙티브 키-게이트→Extract 회귀 + Hard 플레이 스모크는 F5 잔여.**
- **영향:** `data/slice01/{spawn_table.json·encounters/*(9 신규)·id_registry·enemies·rooms}`, `scripts/{autoload/slice01_data·combat/combat_controller·run/run_controller·world/map_demo_layout}`, `IMPL_COVERAGE.md`, `docs/SPEC_DRIFT.md`(DRIFT-039).

### IMPL-DEC-20260613-003 — Loot/RunEnd/Aim 분리 (dungeon_run 갓코드 3라운드, 동작 보존)
- **결정:** dungeon_run 잔여 3덩어리 추출 — `run/loot_service.gd`(77, 처치 루트 롤·드랍, `enemy_defeated` 구동)·`run/run_end_controller.gd`(173, 탈출 홀드채널+결속게이트+전멸감지+정산조합, 자기 `_process`로 `run.settle_*` 호출·`party_alert` emit)·`run/aim_controller.gd`(52, 스킬북 지면조준 모달 → revive/torch와 **진짜 균일** is_active/cancel/handle_click). dungeon_run **686→455**.
- **이유:** 갓코드 3라운드(사용자: C→재평가→플랜→진행). 추출채널+정산조합은 `_settle_extraction`/`_has_separated_survivor`/전멸로 **결합** → 한 `RunEndController`로 묶음(런 종료 흐름 응집). AimController로 3모달이 균일해져 라우터의 인라인 aim 특례 제거(B+→A 인터페이스 조건).
- **동작 보존:** _process의 전멸체크·추출트리거 → RunEndController._process로 이동(동일 매프레임). 루트 연결 `enemy_defeated→on_enemy_defeated`. aim 클릭/Esc/스왑/인벤 위임. 헤드리스 로드 검증 통과. **회귀=라이브 입력·런종료 흐름**(플레이검증 필요).
- **결과:** dungeon_run = 씬부트 + 입력라우터 + 월드오브젝트 스폰 + HUD콜백으로 수렴. **1115→455(-660, -59%)**. 컨트롤러 8종.
- **잔여(DEBT-GOD3, 저위험):** 입력 라우터 ModalStack 정식화·_ready 월드스폰 빌더 분리(선택).
- **영향:** `scripts/run/loot_service.gd`·`run_end_controller.gd`·`aim_controller.gd`(신규), `scripts/run/dungeon_run.gd`, `docs/ARCHITECTURE.md`(DEBT-GOD3).


### IMPL-DEC-20260613-002 — 모달 입력 패밀리 분리 (dungeon_run 갓코드 2라운드, 동작 보존)
- **결정:** dungeon_run의 "모달 타게팅 패밀리"를 4개로 추출 — **표현 헬퍼** `ui/aim_marker.gd`(51, 가시 시 마우스 자동추종)·`ui/controlled_indicator.gd`(60, setup 후 자기추종) + **기능 컨트롤러** `run/revive_controller.gd`(131)·`run/torch_carry_controller.gd`(145). dungeon_run은 **얇은 라우터**로 잔존 — `_unhandled_input`이 Esc/클릭/키를 우선순위대로 `is_active()/cancel()/handle_click()/handle_consumable_key()`로 위임. dungeon_run 960→686.
- **이유:** 갓코드 점검 후속(사용자: C 전체 진행). 셋(횃불/부활/조준)이 **독립 3섬이 아니라** 공유 마커·프롬프트·단일활성모달·우선순위 라우터를 쓰는 패밀리 → "완전 독립 3모듈"은 결합을 교차참조로 되살림. **얇은 코디네이터(라우터) 잔존 + 응집 컨트롤러 + 표현 헬퍼**가 정답.
- **설계 결정:** ① AimMarker가 visible일 때 자기 `_process`로 마우스 추종 → 라우터에서 추종 제거, 스킬북조준·횃불투척 공유. ② 상호배제는 라우터가 `handle_consumable_key(slot, blocked)`의 `blocked=_aiming or _revive.is_active()`로 주입(정직한 코디네이터 한계 — 균일 인터페이스의 기능별 혹). ③ 프롬프트는 컨트롤러별 자체 소유(공유 `_revive_prompt` 폐기).
- **동작 보존:** 클릭 우선순위(revive→aim→throw→inspect/camera)·Esc 우선순위·슬롯 자동/선택·throw 가드 그대로. 헤드리스 로드 검증 통과. **회귀리스크=라이브 입력**(모달 전환)이라 플레이검증 필요.
- **잔여(DEBT-GOD3):** 추출채널(~40)·루트롤(~70)·정산조합(~80) 추출 + 라우터 `ModalStack` 정식화 → 3라운드.
- **영향:** `scripts/ui/aim_marker.gd`·`controlled_indicator.gd`(신규), `scripts/run/revive_controller.gd`·`torch_carry_controller.gd`(신규), `scripts/run/dungeon_run.gd`, `docs/ARCHITECTURE.md`(DEBT-GOD3).


### IMPL-DEC-20260613-001 — SettlementPanel 분리 (dungeon_run 갓코드 정리, 동작 보존)
- **결정:** F-007 런 정산 UI(중앙 패널 빌드/표시/카테고리요약/항목목록, 6함수 ~157줄)를 `dungeon_run.gd`에서 **`scripts/ui/settlement_panel.gd`(163)** Control로 추출. dungeon_run은 패널 생성 + `_run.run_settled(summary) → panel.show_settlement` 연결만 남김. **정산 조합**(`_settle_extraction`/`_failure`/`_collect_at_risk`/`_has_separated_survivor`/`_is_party_wiped`)은 _party/_inventory 의존이라 dungeon_run에 잔존.
- **이유:** 갓코드 점검(사용자 요청)에서 dungeon_run이 CameraRig 분리(256줄) 후 F-007 정산·횃불 carry/투척·부활 타게팅·루트롤 누적으로 **1115줄 재증식**. 정산 UI는 `summary` dict만 받는 **순수 표현**이라 가장 고립·저위험 추출 단위 → 첫 정리 대상(사용자 승인). dungeon_run 1115→961.
- **동작 보존:** 순수 이동 — 패널 레이아웃·색·카테고리/스크롤 로직 그대로, `run_settled` 시그널 구동 동일. 헤드리스 로드 검증 통과.
- **잔여(DEBT-GOD3, 중위험·입력결합):** 횃불 carry/투척(~90)·부활 타게팅(~73)·조준마커/조작표시(~88) — 후속 보류.
- **영향:** `scripts/ui/settlement_panel.gd`(신규), `scripts/run/dungeon_run.gd`, `docs/ARCHITECTURE.md`(DEBT-GOD3).


### IMPL-DEC-20260608-001 — 코드 구조 지도 + 드리프트 거버넌스 도입
- **결정:** [docs/ARCHITECTURE.md](../ARCHITECTURE.md)(모듈 책임 + 기술부채 레지스터)와 [docs/SPEC_DRIFT.md](../SPEC_DRIFT.md)(드리프트 대장) 신설, [AGENTS.md](../../AGENTS.md)/[CLAUDE.md](../../CLAUDE.md)에 spec 역전파 규칙 고정.
- **이유:** 코드가 덧붙이기로 누적되며 스파게티/스펙 이격 위험. 단일 지도 + 강제 트래킹으로 방지.
- **대안:** 폴더별 README만 유지(분산·드리프트 탐지 불가) — 기각.
- **영향:** `docs/ARCHITECTURE.md`, `docs/SPEC_DRIFT.md`, `AGENTS.md`, `CLAUDE.md`.

### IMPL-DEC-20260608-002 — 스펙 핀 재정렬 cd6009e → 262d8bb
- **결정:** `spec_ref.json`·`id_registry.json` 핀을 staging HEAD `262d8bb`로 bump.
- **이유:** 게임은 이미 HEAD 상태(Identity 전원 자동, 스왑 1~4)를 구현. diff는 인런 키바인딩+Identity 자동 1건뿐(전투/어빌리티/ENC/QA-030 수치 동일). 재핀으로 "팬텀 드리프트"(DRIFT-002/003)를 정합으로 전환.
- **대안:** cd6009e 유지(코드를 Q수동/F1~F4로 되돌리기) — 스펙 진행방향과 역행, 기각.
- **영향:** `spec_ref.json`, `data/slice01/id_registry.json`.

### IMPL-DEC-20260608-003 — 리팩토링 순서: 기준선 확보 후 전체 리팩토링
- **결정:** 전체 리팩토링(party_controller 갓오브젝트 분해·v0 삭제·전투상태 단일소유)을 수행하되, **게이트차단 수정 → 반복가능 검증 기준선 확보 → 리팩토링 → 검증 재확인** 순서로.
- **이유:** 라이브 전투/스티어링 흐름은 한 번도 공식 검증되지 않음. 기준선 없이 1623줄을 분해하면 회귀와 기존버그 구분 불가.
- **대안:** 리팩토링 선행 — 회귀 판별 불가로 기각. 게이트 후로 무기한 연기 — 1b 확장이 부채 위에 쌓이므로 기각.
- **영향:** (예정) `scripts/party/*`, `scripts/combat/*`, `scripts/core/unit_visuals.gd`(신규).

### IMPL-DEC-20260608-004 — 인카운터 재바인딩 + 어빌리티 id 검증 (P3)
- **결정:** ① `manifest` `P-ADV-01 → ENC-NORM-001`(스펙 필수·게이트 복원), `RM-ADV-02`에 `pool_slot: P-ADV-02` + `P-ADV-02 → ENC-HARD-001`(선택 전투로 보존) — DRIFT-004 "둘 다 살림". ② `id_registry.ability_ids`에 사용중 14개 AB 등록 + `slice01_data._parse_abilities`에 `require_id` + identities `sub_ability_id` 검증 — DRIFT-006.
- **이유:** ENC-NORM-001(스펙 필수)이 빌드에서 도달 불가였고, "미등록 ID→abort" 가드가 어빌리티에만 비활성이었음.
- **검증:** Godot 4.5.1 헤드리스 로드 통과(`[TDC] Hub ready — staging@262d8bb`), 검증 abort/parse 에러 없음. ENC-NORM-001 실제 전투 스폰은 F5 기준선 검증 대기.
- **영향:** `data/slice01/manifest.json`, `rooms.json`, `id_registry.json`, `scripts/core/slice01_data.gd`.

### IMPL-DEC-20260608-006 — Phase 1b 스펙 공식화 전파 + 재핀 d70ed48
- **결정:** spec 레포에 `QA-031`(Phase 1b Playable Contract) 신설 + QA-030 §7 전환 절 + DecisionLog `DEC-20260608-001` + SpecScopeTracker/TODO 갱신을 `staging`에 머지(`d70ed48`). 게임 `spec_ref.json`/`id_registry`/`manifest`를 `262d8bb`→`d70ed48`로 재핀하고 `implementation_phase: 1b` · `contract/playable_contract_id: QA-031`로 전환.
- **이유:** 사용자(2026-06-08) 결정으로 Slice-01 선언적 완료 + 1b 확장을 spec SSOT에 공식 반영(DRIFT-000/001/005). 매퍼는 QA 계약 문서 선례로 미변경.
- **검증:** Godot 헤드리스 로드 `[TDC] Hub ready — staging@d70ed48 (QA-031)` 통과.
- **영향:** (spec) QA-031/QA-030/DecisionLog/SpecScopeTracker/TODO · (game) spec_ref.json/id_registry.json/manifest.json/docs/SPEC_DRIFT.md.

### IMPL-DEC-20260608-005 — HP색 단일화 (P4, DEBT-DUP-HP)
- **결정:** `scripts/core/ui_colors.gd` 신설(static `hp_color`), party_sheet·controlled_sheet·health_bar가 공유 호출.
- **이유:** 동일 HP비율 색 램프가 3파일에 복붙되며 빌보드바와 HUD바의 노랑/빨강이 실제로 달라진 시각 버그.
- **영향:** `scripts/core/ui_colors.gd`(신규), `scripts/ui/party_sheet.gd`, `scripts/ui/controlled_sheet.gd`, `scripts/combat/health_bar.gd`.

### IMPL-DEC-20260609-001 — 전투 진입/슬롯-이탈 분리 + 안전우선 폴로워 (F-004·D-010 구현)
- **결정:** ① partyInCombat(전투중/휴식중)을 D-010 §4.1(파티 피해·공격·인지) 진입 / §4.2(grace 6s) 종료로 구현, HUD 표시. ② **폴로워 슬롯-이탈(진형 깨기)을 partyInCombat과 분리**: 피격 또는 적이 아군 기본사거리 진입 시에만(인지/스폰만으론 안 깸) → 선전진 돌진 방지(F-004 §3.1 안전우선/§3.3 leash 취지). ③ 힐러는 적이 아닌 **부상 아군을 힐 사거리에 두도록 이동**(F-005 롤).
- **이유:** "비조작 파티원 안전우선"(F-004) + "전투 판정"(D-010)의 구현. 사용자 요구(배치 우선, 돌진 금지)와 spec 정합.
- **대안:** 인카운터 스폰=즉시 돌격(기존) — F-004 위반, 기각.
- **영향:** `scripts/combat/combat_controller.gd`, `scripts/party/party_controller.gd`, `scripts/run/dungeon_run.gd`, `scenes/run/dungeon_run.tscn`.

### IMPL-DEC-20260609-002 — 적 전투AI 재설계: 분대 + 미리스폰 + 시야콘 인지 (F-011 부분/신규 enemy-AI)
- **결정:** 전역 engaged 제거 → **적 분대(squad) 단위 engage**(분대원 근접 9m 전파, stray 예외). 인카운터 **미리 스폰(휴면)**, 시작방 인카운터→메인전투방 이전, 방 먼쪽 배치. **하이브리드 시야콘 인지**(FOV+LOS+근접버블, 2존 경계/전투, ?/! 텔, last_seen 조사, 도망 시 grace+감속 추격→포기). 적 **navmesh 추격**, 공격 LOS 게이트, **threat/시야기반 타겟**(미인지 먼 멤버 비타겟).
- **이유:** 인지 기반 전투 개시 + 분대 독립 + 도주/은신 성립(스텔스성). DRIFT-018/019에 트래킹, F-011 deferred 스코프를 1b로 선구현.
- **대안:** 풀 F-011(perceptionProfile/Patrol/Threat Memory)까지 — 범위 과대, 데모엔 과함. 부분 구현 + PENDING-PROP.
- **영향:** `scripts/combat/combat_controller.gd`, `scripts/combat/enemy_unit.gd`, `scripts/run/map_demo_layout.gd`(deep spawn), `scripts/party/party_controller.gd`(앵커 전투 합류).

### IMPL-DEC-20260610-008 — 비결속 지휘권: 리더 정본 앵커 + 임시 위임/복귀 환원 (F-003 §3.4 확장)
- **결정:** `_update_command_holder(avoid_scout)`를 **per-frame**(+스왑/진입) 갱신으로. **리더=정본 앵커**(이동핑 명령 대상). 리더가 정찰(컨트롤)/복귀 중에만 stand-in 임시 위임, **리더가 대열 복귀(`_leader_returned`: stand-in 5m 내)하면 앵커를 리더로 환원**. stand-in 선정(`_pick_command_holder`, 후보 leader/sub→전 멤버)에서 **방금 떨어진 정찰자(avoid_scout) 제외**.
- **이유(2단계):** ① 1차(IMPL-DEC 초안): §3.4 "비리더 컨트롤→앵커=리더"가 정찰 나간 리더를 앵커로 만들어 파티가 끌려감 → persistence+정찰자제외로 "떨어진 1명만 이탈"화. ② **사용자 재지적:** 앵커가 stand-in(Healer 등)으로 **영구 drift**하면 이동핑(F-003 §3.5)의 명령 대상으로서 의미가 깨짐 → "탱커 복귀 시 앵커를 탱커로 환원"이 옳다. → per-frame 리더-환원으로 재설계.
- **대안:** (a)가상 포메이션 앵커(좌표 기반) — 더 큰 구조변경, 보류. (b)stand-in 영구화 — 이동핑 역할 훼손이라 사용자 기각.
- **트레이드오프:** 리더 환원 순간 포메이션 중심이 stand-in→리더로 ~slot offset만큼 1회 부드럽게 이동(스티어링 흡수). RETURN_RADIUS 5m=tuning.
- **전파(✅ 완료):** spec staging **f7739a1** · **DEC-20260610-002** — F-003 **§3.0.4** 신설로 **지휘권 보유자(리더 고정·핑/MIA 대상)↔포메이션 랠리 앵커(자동 stand-in/환원) 분리** SSOT화. 전파 중 §3.0/§3.10 "앵커 고정+UI-008 수동" 모델과의 충돌을 발견→사용자 결정으로 분리 모델 채택. 게임 코드는 랠리 앵커만(핑/MIA 미구현). `spec_ref.json` 재핀 6f0e534→f7739a1. DRIFT-021 MERGED.
- **영향:** `scripts/party/party_controller.gd`(`_update_command_holder`/`_leader_returned`/`_pick_command_holder`/`_set_controlled_index`/`_get_anchor`/`_physics_process`), `spec_ref.json`, `docs/SPEC_DRIFT.md`. spec: `F-003`/`DecisionLog`/`SpecScopeTracker`/`TODO`.

### IMPL-DEC-20260611-021 — 적 인스펙트 패널 (좌클릭 → 12시 적 정보)
- **결정:** 적 **좌클릭** → 상단중앙 패널에 **초상화(적 색)+이름+HP(+상태 pip)** 표시(스킬/쿨 제외, 사용자 요청). `enemy_info.gd`(Control, top-center, 파티시트 슬롯 스타일 차용, mouse IGNORE로 클릭 비차단). dungeon_run이 비에임 시 LMB → `_select_enemy_under_mouse`(카메라 레이캐스트 mask=4 `LAYER_ENEMY`)로 적 피킹 → `set_enemy`, 빈 공간 클릭=clear. 적 사망(`hp<=0`/freed) 시 자동 clear. `enemy_unit.get_body_color()` 게터 추가.
- **이유:** 사용자 요청(적 정보 노출). 파티시트(UI-002) 스타일 재사용.
- **잔여:** 적은 **상태(버프/디버프) 시스템이 없어** 그 pip 영역은 현재 비어있음 — `get_status_list` 있으면 표시하도록 future-proof. LOS 무시(벽 뒤 적도 클릭되면 선택; 필요 시 world 마스크+first-hit 검증). 적 마커=`has_method("get_body_color")` 덕타이핑.
- **영향:** `enemy_info.gd`(신규), `enemy_unit.gd`(`get_body_color`), `dungeon_run.gd`(EnemyInfo 생성·LMB 피킹).
- **F5:** 적 좌클릭 → 상단중앙에 초상화/이름/체력, 다른 적 클릭=전환, 빈 곳 클릭=해제, 처치 시 사라짐.

### IMPL-DEC-20260611-020 — 미니맵 (우상단)
- **결정:** `minimap.gd`(Control, 우상단 286×160 @ top=12, 퀘스트 트래커 바로 위) — **고정 world-aligned**(+X 우, +Z 상) `_draw`: 룸 footprint(rect) + 탈출 마커(녹) + interactable 마커(상자/문/드롭, group `interactable`) + 플레이어 점(흰 링+시안)+속도 방향선. 맵의 **decoupled 인터페이스** `get_room_rects()`(신규, `_room_points`에서) 사용 → Blender 맵 교체 시 그대로. `_w2m`이 월드 AABB를 패널에 fit+센터. dungeon_run이 생성·`$HUD` 부착·setup.
- **이유:** 사용자 요청(우상단 미니맵). 적은 미표시(정보전 컨셉 — 무료 적 정보 X).
- **잔여/튜닝:** 고정 방향(카메라 회전 비추종); 회전추종·줌·룸 라벨·발견된 영역만 표시(fog)는 후속. 크기/색 tuning.
- **영향:** `minimap.gd`(신규), `map_demo_layout.gd`(`get_room_rects` 게터), `dungeon_run.gd`(생성).
- **F5:** 우상단 미니맵에 던전 룸 배치 + 탈출(녹)·상자/문(노랑) 마커 + 플레이어 점이 이동에 따라 움직임.

### IMPL-DEC-20260611-019 — 보호막(AB-020) HP바 시각화 (흰색 오버레이)
- **결정:** 보호막은 데미지 흡수·시간제로 **이미 동작**했으나 HP바엔 미표시(party_sheet 버프 pip만)였음 → **흰색 오버레이** 추가: ① **게임 내 머리 위 HP바**(`health_bar.gd` — fill 위 z=0.02 흰색 quad, 좌측정렬, 너비=shield/maxHP, `set_shield_ratio`) ② **컨트롤 시트 HP바**(`controlled_sheet.gd` — HP fill 위 흰색 ColorRect, anchor_right=shield/maxHP). `party_member._physics_process`가 매 프레임 `set_shield_ratio` 전달(적은 보호막 없어 미표시). 사용자 지적으로 발견: 툴팁에 보호막을 적었는데 바엔 안 보였음.
- **이유:** "보호막이 HP 위에 흰색으로 오버레이되는" 표준 표기 요청.
- **잔여:** party_sheet 로스터 HP바는 기존 버프 pip 유지(오버레이 미추가). 색/스타일·shield>maxHP 처리(현재 clamp 1.0)는 tuning. ref: AB-020 / UI-003.
- **영향:** `health_bar.gd`(shield quad), `party_member.gd`(set_shield_ratio 호출), `controlled_sheet.gd`(shield ColorRect).
- **F5:** 탱커 조작 + 전투/Q → HP바(머리 위 + 하단)에 흰색 보호막, 피격/만료 시 흰색 감소.

### IMPL-DEC-20260611-018 — 호버 툴팁 (6시 스킬 슬롯 + 인벤 아이템)
- **결정:** 내장 `tooltip_text`(호버 시 엔진 기본 오버레이)로 ① **스킬 슬롯**(`controlled_sheet.gd` UI-003 6시 — Identity/Q RadialCooldown): `_skill_tip`이 헤더(주/보조) + 읽기쉬운 이름·설명(`SKILL_INFO` kind→KR 매핑, 데이터엔 prose 없음) + 쿨다운을 매 프레임 조작캐 params에서 구성. ② **인벤 아이템**(`inventory_grid.gd` item Panel): `_item_tip`이 이름 + 설명(`ITEM_DESC`) + 크기 W×H를 `_make_node`에서 설정.
- **이유:** 사용자 요청(스킬/아이템 호버 정보). 내장 툴팁 채택 = 저위험·일관(커스텀 오버레이는 위치/타이밍 리스크). 데이터에 표시명/설명이 없어 kind/id→KR 텍스트는 UI에 하드코딩(프레젠테이션).
- **잔여/튜닝:** 기본 호버 지연(~0.5s); 더 즉각/리치하게 원하면 `gui/timers/tooltip_delay_sec` 축소 또는 `_make_custom_tooltip` 커스텀 패널. 스킬/아이템 명·설명의 데이터화는 후속(스펙 표시명 도입 시).
- **영향:** `controlled_sheet.gd`(SKILL_INFO·_skill_tip·tooltip_text), `inventory_grid.gd`(ITEM_DESC·_item_tip·tooltip_text).
- **F5:** 6시 스킬 슬롯 호버 → 이름/설명/쿨다운 툴팁 / 인벤 아이템 호버 → 이름/설명/크기 툴팁.

### IMPL-DEC-20260611-017 — 퀘스트 트래커 UI (우상단, 실시간 진행)
- **결정:** `quest_tracker.gd`(Control, 우상단 미니맵 공간 아래 고정 패널 286×156 @ top=178) — RichTextLabel BBCode로 **주 임무 — 탈출**(열쇠 획득→봉인문 개방→탈출 3목표) + **보조 — 보급 회수**(Cell n/6) 표시. 매 프레임 게임상태 폴링: 열쇠=`inventory_ui.backpack_has_key()`(래치), 문=`run.objective_complete`, 탈출=`run.run_over`, Cell=`inventory_ui.count_item("Cell")`. **완료 목표는 `[s]취소선[/s]`+✔**, 미완료는 •+카운트. dungeon_run이 생성·`$HUD` 부착·setup.
- **이유:** 사용자 요청 — 데모 목표를 진행도에 맞춰 표기(카운트/취소선). 미니맵 자리는 비워둠.
- **잔여/튜닝:** 미니맵 미구현(공간만 확보). 퀘스트는 코드 하드코딩(데이터화·다중 퀘스트·완료 알림은 후속). Cell 목표 6 = tuning. ref: F-006/F-010.
- **영향:** `quest_tracker.gd`(신규), `inventory_ui.gd`(`count_item`), `dungeon_run.gd`(생성).
- **F5:** 우상단 패널에 주/보조 임무 표시 → 열쇠 루팅 시 "열쇠 획득" 취소선, 문 개방 시 "봉인문 개방" 취소선, Cell 주울수록 (n/6) 증가, 6개면 취소선, 탈출 시 "탈출" 취소선.

### IMPL-DEC-20260611-016 — 적 처치 아이템 드롭 + 줍기
- **결정:** 적 사망 시 월드 아이템 드롭 — `combat_controller`에 `signal enemy_defeated(world_pos)`(`_on_enemy_died`에서 emit), `dungeon_run`이 받아 `LOOT_TABLE`(PH: Ammo/Medkit/Scrap/Cell)에서 1개 랜덤 → `item_drop.gd`(Node3D, 발광·회전 큐브, group `interactable`, **interact 레이어만**=이동 비차단) 스폰. 호버 라벨("이름\n[우클릭] 줍기")·우클릭 자동이동은 기존 시스템 재사용. 도착 시 `interact()`→`inventory_ui.add_to_backpack()`(백팩 첫 빈칸 배치) 성공이면 `queue_free`, 가득이면 드롭 유지.
- **이유:** 사용자 요청(몬스터 처치 루팅). A 인벤 엔진 + 우클릭 자동이동 위에 얹음.
- **튜닝/잔여:** 드롭률 현재 **100%**(처치마다), 로트 테이블/확률·아이템 데이터화·줍기 이펙트·백팩 가득 시 피드백은 후속. ref: F-010 loot.
- **영향:** `item_drop.gd`(신규), `combat_controller.gd`(signal), `inventory_ui.gd`(`add_to_backpack`), `dungeon_run.gd`(LOOT_TABLE·연결·스폰).
- **F5:** 적 처치 → 사망 위치에 발광 큐브 → 호버 라벨 → 우클릭 → 조작캐 걸어가 줍기 → `i`로 백팩에 추가 확인.

### IMPL-DEC-20260610-015 — 월드 루프 B2: 키 게이트 문 + 탈출 objective 패치 + 우클릭 상호작용
- **결정:** ① **문**(`door.gd` Node3D, group `interactable`) — `RM-ROUTE-01→RM-EXT-01` 개구부(27,0,77.25)에 박스 배리어(collision layer1, 6.4×3.2×0.9). interact: `_inv.backpack_has_key()`면 개방(콜리전·메시 제거 + group 이탈 + `_run.complete_objective()`), 아니면 "열쇠 필요" 프롬프트. ② **탈출 objective 패치** — `run_controller`의 RM-OBJ-01 진입 자동 `complete_objective()` **제거** → objective는 **문 개방 시**에만. extraction(`try_extract`)는 objective_complete 요구 그대로. ③ **상호작용 키 E→우클릭** — E는 서브스킬2 예약이라 충돌 회피. dungeon_run이 RMB **클릭(이동<8px) vs 드래그(카메라 회전)** 구분, 클릭이면 `_interaction.try_interact()`. `interact`(E) 입력액션 제거, 상자/문 프롬프트 `[우클릭]`.
- **이유:** 사용자 요청 루프 완성 — 상자에서 키 → 문 개방 → 탈출방 진입 가능. 키 인식은 A의 컨테이너간 드래그(상자→백팩)로.
- **흐름:** RM-OBJ-01 상자 우클릭 → 루트뷰 → Key를 백팩으로 → RM-ROUTE-01↔EXT 문 우클릭(키 보유) → 개방+objective → RM-EXT-01 진입 → 홀드 탈출.
- **잔여:** 문 navmesh 미반영(베이크는 빌드 시 1회 — 적/팔로워 경로는 문 무시, 조작캐는 물리 차단으로 충분). 키 소모 안 함. 회전/스택/무게/저장은 후속.
- **영향:** `door.gd`(신규), `run_controller.gd`(objective), `dungeon_run.gd`(문 생성·RMB 상호작용), `chest.gd`(프롬프트), `project.godot`(interact 제거).
- **F5:** 상자 우클릭→키 루팅 / 문 우클릭(키 없으면 "열쇠 필요", 있으면 개방) / 문 개방 후 RM-EXT-01 진입→탈출 / RMB 드래그=카메라 회전 유지.

### IMPL-DEC-20260610-014 — 월드 루프 B1: 상호작용 + 상자 + 키 + 루트뷰 (chest→key)
- **결정:** ① **인벤 backpack/loot 모드** — `inventory_ui`가 영구 BACKPACK + 상자 열 때만 보이는 loot 그리드. `open_loot(chest)`(상자 items로 채움)·`_close`(남은 것 상자에 되쓰기)·`backpack_has_key()`(B2 문 게이트용). 숨은 grid는 드래그 라우팅 제외. grid에 `clear`/`export_items` 추가. ② **상자**(`chest.gd` Node3D, group `interactable`, 박스 메시+발광, items 보유) ③ **상호작용**(`interaction_controller.gd` — **마우스 호버 레이캐스트**(interact 콜리전 레이어 5; 상자/문은 world+interact 양쪽), **사거리 무관 항상** 오브젝트 **머리 위 라벨**(이름+키, `interact_anchor` 카메라 투영)로 "뭐가 열리는지" 먼저 보이게; **우클릭 = 호버 오브젝트로 조작캐 자동이동→도착 시 interact**(`player_controller.order_move_to`: 직선 seek+벽슬라이드, WASD로 취소, 막히면 0.5s 후 포기). 인벤 열리면 비활성) ④ `interact` 입력액션(E=69) ⑤ 상자를 RM-OBJ-01에 배치, **Key 1×1** 시드. ⑥ dungeon_run: 생성·E 라우팅·하단 프롬프트 라벨.
- **이유:** 사용자 요청 루프(상자→키→문→탈출)의 전반부. A 청크(컨테이너간 드래그)로 키를 상자→백팩 이동.
- **잔여(B2):** 문(Door) 3D 엔티티(탈출 경로 차단·키 게이트 `backpack_has_key`) + 탈출 objective 패치(RM-OBJ-01 자동완료 제거 → 문 개방 시 `complete_objective`).
- **영향:** `inventory_ui.gd`·`inventory_grid.gd`(리팩토링/헬퍼), `chest.gd`·`interaction_controller.gd`(신규), `dungeon_run.gd`(배선), `project.godot`(interact). 전파: DRIFT-023(인벤)+신규 월드루프 → F-007/F-010/F-026 후보, B2 완료 후 묶어 정리.
- **F5:** RM-OBJ-01의 상자 근처 → 하단 `[E] 유물함 열기` → E → 루트뷰(백팩+상자, Key) → Key를 백팩으로 드래그 → Esc/i 닫기 → 재오픈 시 상자 비어있음.

### IMPL-DEC-20260610-013 — 백팩 아이템 메커닉 (가변 W×H + 드래그&드롭)
- **결정:** 격자 로직을 `scripts/ui/inventory_grid.gd`(Control)로 분리 — **occupancy 맵**(rows×cols) + **가변 W×H 아이템**(PH 컬러 패널, id/크기 라벨) + **드래그&드롭**: 아이템 LMB로 픽업(자기 셀 free→자기차단 방지·앞으로·반투명), `_input`이 모션 추적하며 **셀 스냅 미리보기**(can_place: 경계+겹침 → 녹색/빨강 `_draw`), 드롭 시 유효하면 배치·무효면 원위치 복귀. inventory_ui는 창 chrome + 시드 아이템(Medkit 1×1·Pistol 2×1·Rifle 4×1·Armor 2×2·Cell 1×2·Ammo 1×1)만 담당.
- **이유:** 사용자 요청(백팩식). IMPL-DEC-012의 빈 격자 토대 위에 아이템/드래그 메커닉 구현. 격자=고정 CELL 격자, 아이템=자식 노드 (col,row)×stride 배치 → 회전/스택/무게/아이콘 확장 용이.
- **좌표:** 아이템은 grid Control 로컬좌표 자식, `get_local_mouse_position`로 드래그(창 이동해도 정합). occupancy init은 `setup()`(트리 진입 전 호출 가능하게 `_ready` 타이밍 무관).
- **튜닝:** CELL 56·GAP 4 (격자), 아이템 정의는 데이터(현재 inventory_ui 시드).
- **영향:** `scripts/ui/inventory_grid.gd`(신규), `scripts/ui/inventory_ui.gd`(격자 교체·시드). DRIFT-023 갱신.
- **2차 확장(같은 날):** **코디네이터 모델**로 리팩토링 — grid는 occupancy/셀·비주얼만, `inventory_ui`(코디네이터)가 드래그·**회전(R, W↔H 스왑)**·**컨테이너 간 이동**(드래그 비주얼 + 커서 아래 grid 라우팅 + occupancy 이전, 무효 드롭 시 원래 방향·자리 복귀)을 소유. UI에 BACKPACK 5×8 + CONTAINER 5×5 두 컨테이너 표시(엔진 검증). grid item 비주얼의 `gui_input`이 `_coord._on_item_pressed`로 라우팅.
- **잔여(후속):** 스택, 무게/용량, 아이템 아이콘·툴팁, 탈출 loss bundle(F-007) 연동, 저장/로드. **(B 청크: 키 아이템·상자·문·탈출 objective 패치.)**
- **F5 검증:** `i`로 인벤 → 시드 아이템 6종 배치, 아이템 **드래그→스냅 미리보기(녹/빨)→유효시 배치/무효시 복귀**, 겹침·경계 막힘.

### IMPL-DEC-20260610-012 — 인벤토리 UI 프로토타입 (5×8 그리드, `i` 토글)
- **결정:** `scripts/ui/inventory_ui.gd`(Control) 신설 — COLS×ROWS(=5×8) **고정 셀 격자** 모달 오버레이, `i`(신규 input 액션 `toggle_inventory`=physical 73) 토글, Esc로 닫기. dim 배경 + **수동 중앙정렬**(CanvasLayer 자식은 size 0이라 CenterContainer가 좌상단행 → 루트=뷰포트 수동 사이즈 + `_center_window`) + **제목바 드래그 이동**(`_on_bar_input` 시작, `_input`이 모션/릴리스 추적, 화면 clamp) PanelContainer + GridContainer(40셀). dungeon_run이 생성·$HUD 부착·입력 배선, HUD 힌트에 `I 인벤` 추가.
- **이유:** 사용자 요청. **백팩/테트리스식 가변 사이즈 아이템** 인벤(아이템이 여러 셀 차지)을 모방할 토대. 지금은 빈 격자(display-only).
- **확장 대비:** 격자를 **고정 CELL 격자**로 두고, 후속 아이템 레이어가 (col,row)×CELL로 다중 셀 footprint를 위에 얹는 구조(주석 명시). 회전/스택/무게 등은 후속.
- **튜닝:** COLS 5·ROWS 8·CELL 56·GAP 4(inventory_ui).
- **영향:** `scripts/ui/inventory_ui.gd`(신규), `scripts/run/dungeon_run.gd`(생성·토글·Esc·힌트), `project.godot`([input] toggle_inventory).
- **전파:** 신규 인벤토리 시스템 → **SPEC_DRIFT DRIFT-023**(F-010 Loadout / 신규 인벤 spec 후보). 가변사이즈 메커닉 확정 시 OPS_30.
- **F5 검증:** `i`로 5×8 격자 열림/닫힘, Esc 닫힘, 모달(뒤 클릭 차단).

### IMPL-DEC-20260610-011 — 방향 피격 인디케이터 (화면 가장자리 데미지 UX)
- **결정:** 조작 캐릭이 피격 시, **공격자 방향으로 화면 가장자리 빨간 글로우**를 띄워 "맞음 + 방향"을 직접 인지. 신규 신호 `CombatController.party_hit(from_dir_world, severity, is_controlled)` — `enemy_ai._apply_enemy_hit`에서 **모든 피격(평타 포함) 칩뎀컷 위**로 emit(severity=dmg/maxHP*gain). dungeon_run이 **is_controlled만 필터** + 카메라 `unproject_position`으로 정확한 스크린 방향 산출 → 신규 `scripts/ui/damage_indicator.gd`(Control, 절차 draw 글로우, 동방향 debounce·페이드).
- **이유:** 사용자 제안. 원거리 탑다운 + 회전카메라에서 오프스크린/주변시 위협·피격 사실 인지 강화(인포워). 기존 카메라 방향킥(AB 전용)을 보강하는 별도 레이어.
- **설계 선택(권장안 채택):** ①표시 대상=조작 캐릭만(팔로워 오프스크린은 2단계, F-003 §3.9 정합 여지) ②트리거=모든 피격 severity 스케일+칩뎀컷(평타 누락 방지; camera_shake는 AB 전용이라 별도 신호) ③방향=카메라 unproject(yaw/pitch 무관 정확). 가독성 위해 동방향 debounce·강도 스케일·빠른 페이드.
- **튜닝:** `HIT_INDICATOR_MIN_FRAC` 0.012·`HIT_INDICATOR_GAIN` 4.0(enemy_ai), 글로우 `SPREAD_DEG` 38·`DEPTH_FRAC` 0.16·`FADE_S` 0.7(damage_indicator).
- **영향:** `combat_controller.gd`(신호), `enemy_ai.gd`(emit), `scripts/ui/damage_indicator.gd`(신규), `dungeon_run.gd`(생성·연결·스크린변환).
- **전파:** 신규 인포워 HUD UX → **SPEC_DRIFT DRIFT-022**(F-011/UI 스펙 후보). F5 확인·튜닝 후 정합.
- **F5 검증:** 피격 시 **공격자 방향**으로 가장자리 글로우(방향 정확한지 — 어긋나면 스크린벡터 부호), 큰 피해=진함/칩뎀=흐림or없음, 비조작 멤버 피격엔 안 뜸, 평타·스킬 모두 반응.

### IMPL-DEC-20260610-010 — CombatPositioning 분리 + 데드 v0 config 정리 (갓코드 정리 4단계, party_controller)
- **결정:** ① party_controller의 전투우선 goal-point 로직(`_has_live_enemies`/`_enemy_in_party_basic_range`/`_combat_engage_target`/`_healer_support_target`/`_lowest_hp_ally_below_threshold`, ~104줄)을 **`scripts/party/combat_positioning.gd`(111줄)** 자식 노드로 추출(`_members`만 `_party` 백레퍼). ② **데드 v0 config 17종 제거**(DEBT-V0 잔재): tank_follow 보정/리버설 6 + v0 separation 7 + preferred_anchor/lateral_approach/slot_arrive/path_clearance 4 — 선언 + `_load_formation_config`의 tank_follow 로더 블록.
- **이유:** 사용자 선택(party 갓코드 "깨끗한 것부터"). SteeringV1(~530줄)은 config 소유권·per-member 상태·라이브무빙에 **깊게 결합**돼 통째 추출 시 백레퍼 대량 + 최고위험이라, 저결합·저위험 단위부터. party_controller **1623→1014줄**(이번 -128: CombatPositioning -104, 데드config -24).
- **결합 처리:** CombatPositioning은 goal-point만 계산(enemy/ally 그룹 + 멤버 메서드), `_members`만 `_party` 콜백. `_update_formation_follow`/`_sv1_update_follow`(Pass3)가 `_combat_pos.*` 위임. Node 자식이라 `get_tree()` 보유.
- **동작 보존:** 순수 리팩토링 — 슬롯이탈 트리거(F-004)·근접 attack-range 포지션·힐러 wounded 추종(F-005) 로직 그대로. 데드 config는 sv1 미사용(grep 0 검증) 확인 후 제거.
- **잔여:** **SteeringV1**(~530줄)은 전용 세션(config 소유권 재설계 동반). DEBT-GOD 잔여 최대 덩어리.
- **영향:** `scripts/party/combat_positioning.gd`(신규), `scripts/party/party_controller.gd`, `docs/ARCHITECTURE.md`(DEBT-GOD/DEBT-V0).
- **F5 검증:** 전투우선 follower 교전(근접 attack-range)·힐러 wounded 추종·진형우선 hold·슬롯이탈 트리거가 이전과 동일한지.

### IMPL-DEC-20260610-009 — AbilityDispatch 분리 (갓코드 정리 3단계, combat_controller 분해)
- **결정:** combat_controller의 파티 스킬 디스패치(`_build_ability_handlers` + `try_identity` + Identity 4 `_cast_*` + `cast_sub` + Sub 4 `_sub_*` + `_sub_hit_shake`, ~185줄)를 **`scripts/combat/ability_dispatch.gd`(197줄)** 자식 노드로 추출. 전용 상수(TANK_PULSE_FLOOR·SUB_SHAKE_MULT_REF·HIT_SHAKE_CAP) 동반 이동. `_tick_party_attacks`는 `_ability_dispatch.try_identity(m)` 위임, `cast_sub`는 얇은 래퍼로 유지(dungeon_run 무수정).
- **이유:** DEBT-GOD2 분해 계속(EnemyAI 다음, 사용자 추천 승인). combat_controller **581→408줄**(854에서 -446 누적). "스킬이 무엇을 하는가"를 전투 루프/스폰/threat에서 분리.
- **결합 처리:** 공유 시스템(공간쿼리 `_enemies_in_*`/`_nearest_*`, `_deal_damage`/`_heal_threat`, `camera_shake` 시그널)은 컨트롤러 단일소유 유지 → AbilityDispatch가 `_combat.*` 콜백. AbilityDispatch는 Node3D 자식이라 VFX 부모(`self`) 자체 보유. EnemyAI와 동일 패턴(순환 preload 회피 위해 `_combat`=Node3D).
- **동작 보존:** 순수 리팩토링 — Identity 자동(AB-020/024/025/026)·Sub 4(taunt/lunge/nova/sanctuary)·SUB 캐스트당 1회 셰이크 로직/상수 그대로.
- **영향:** `scripts/combat/ability_dispatch.gd`(신규), `scripts/combat/combat_controller.gd`, `docs/ARCHITECTURE.md`(DEBT-GOD2).
- **F5 검증:** Identity 자동 발동(역할별)·Sub 4종(Q+지면조준)·SUB 타격감 셰이크가 이전과 동일한지.

### IMPL-DEC-20260610-007 — EnemyAI 분리 (갓코드 정리 2단계, combat_controller 분해)
- **결정:** combat_controller의 적 AI(perception `_tick_dormant` + 전투행동 `_tick_enemy`→`tick` + 공격 `_begin/_resolve/_apply_enemy_hit` + `_telegraph_color`/`_select_enemy_ability`/`_nearest_visible`/`_alive_members` + 인프라 `_has_los`/`_nav_move`, ~273줄)를 **`scripts/combat/enemy_ai.gd`(301줄)** 자식 노드로 추출. AI-only 상수(LOS/시야콘/투사/DMG셰이크/SWITCH_RATIO)도 동반 이동. `_physics_process`는 `_enemy_ai.tick(enemy, targets, delta)`로 위임, 비전콘은 `_enemy_ai.attach_vision_cone(unit)`.
- **이유:** DEBT-GOD2(combat_controller 854줄, 5 하위시스템). 사용자 승인 추출순서 EnemyAI 우선. combat_controller **854→581줄**, 적 의사결정이 스폰/threat/어빌리티에서 분리.
- **결합 처리:** 전투 상태(engaged/grace)·시그널(camera_shake/party_damaged)은 **컨트롤러 단일소유** 유지 → AI가 `_combat._engage_enemy()`/`_combat.refresh_engage_grace()`(신규)/`_combat.party_damaged.emit()`/`_combat.camera_shake.emit()`로 콜백. AI는 Node3D 자식이라 `get_world_3d()`(LOS 레이캐스트)·VFX 부모(`self`) 자체 보유. 양방향 ref는 Godot 컴포넌트 패턴(허용).
- **동작 보존:** 순수 리팩토링 — perception 2존·investigate·engage/disengage grace·텔레그래프 윈드업·LOS 게이트 공격·시야상실 추격·피격 방향셰이크 로직/상수 그대로.
- **영향:** `scripts/combat/enemy_ai.gd`(신규), `scripts/combat/combat_controller.gd`, `docs/ARCHITECTURE.md`(DEBT-GOD2).
- **F5 검증:** 적 perception(?/!·investigate)·전투 교전/추격·텔레그래프·증원·피격 셰이크·탈출이 이전과 동일한지.

### IMPL-DEC-20260610-006 — CameraRig 분리 (갓코드 정리 1단계, 동작 보존 리팩토링)
- **결정:** dungeon_run의 카메라 로직(추종/스왑글라이드/RMB 오르빗/trauma 셰이크, ~70줄 + consts/vars)을 **`scripts/run/camera_rig.gd`(87줄)** 로 추출, `CameraPivot` 노드에 부착. dungeon_run은 `set_follow_target`/`glide_to_current`/`orbit_yaw`/`add_shake` API로 위임. 카메라셰이크 시그널은 `_combat.camera_shake → _camera_rig.add_shake`로 직결.
- **이유:** 갓코드 점검(사용자 요청)에서 dungeon_run이 씬오케스트레이션 + 카메라 + UI를 혼재. 카메라는 CameraPivot에 응집돼 **가장 고립·저위험** 추출 단위 → 첫 정리 대상으로 선정(사용자 승인). dungeon_run 326→256줄, 책임 분리.
- **동작 보존:** 순수 리팩토링 — follow/glide/shake/orbit 로직·상수(SWAP 60/320/6, SHAKE 1.8/3.5°/7.0) 그대로 이동. 부트 글라이드(원점→스폰)·스왑 글라이드·피격 방향킥·회전셰이크 동일. no-op `_sync_tank_follow_collision` 제거(DEBT-DEAD1)도 동반.
- **영향:** `scripts/run/camera_rig.gd`(신규), `scripts/run/dungeon_run.gd`, `scenes/run/dungeon_run.tscn`(CameraPivot에 스크립트), `docs/ARCHITECTURE.md`.
- **F5 검증:** 부트 카메라·1~4 스왑 글라이드·RMB 드래그 회전·전투 피격/타격 셰이크가 이전과 동일한지.

### IMPL-DEC-20260610-005 — 맵 인터페이스 데이터 주도화 (Blender 실맵 교체 대비)
- **결정:** `map_demo_layout`의 인터페이스 getter(`get_spawn_position`/`get_deep_spawn_position`/`get_extraction_position`)를 ROOM_SPECS 직접참조 → **런타임 테이블 `_room_points`**(room_ref→{spawn,size}) + `_extraction_point` 기반으로 분리(`_resolve_room_points`로 채움, placeholder는 ROOM_SPECS에서 파생). `lighting_profile`은 **`rooms.json`(SSOT)** 우선(`_room_profile`), ROOM_SPECS.profile은 빌드 폴백. 맵 계약 주석 블록 추가.
- **이유:** 나중에 spec 기반 **Blender 실맵**으로 교체 시, 절차 생성 placeholder를 버리고 새 맵 노드가 **같은 계약**(getter 5종 + `room_entered` + 벽 콜리전 layer1 + navmesh)만 제공하면 perception/LOS·스폰·탈출·룸 트리거가 **콜러 무수정**으로 동작하게. 옵션 C(placeholder를 씬으로 굽기)는 버려질 작업이라 불채택. DEBT-DM3 부분 해소(profile 이중소유 제거).
- **잔여:** 룸 **기하**(center/size)는 ROOM_SPECS 상수 유지(placeholder geometry; Blender 메시가 대체). Blender 맵은 `_resolve_room_points` 오버라이드 또는 Marker3D 권장.
- **영향:** `scripts/run/map_demo_layout.gd`, `docs/ARCHITECTURE.md`(DEBT-DM3).

### IMPL-DEC-20260610-004 — 카메라 셰이크 (타격감 + 피격 방향킥, trauma 모델)
- **결정:** 카메라 흔들림을 **trauma 모델**(trauma 누적·clamp 1.0·trauma² 진폭·초당 감쇠, 비누적)로 도입. **2케이스만**: ① 타격감 = 파티의 **플레이어 발동 SUB 스킬**만 — **평타 + Identity 자동딜 제외**. **캐스트당 1회**(`_sub_hit_shake`, 타깃 수 무관 — AOE 누적 방지) `damage_mult` 비례(lunge 5.0>nova 3.0). ② 피격 = **AB로 정의된 스킬**(`chosen.ref` 있음 + `trigger!="basic"`) 피해만(평타 ability·접촉뎀·잔뎀 제외), **맞은 방향 킥**(위협 방향 정보) + 셰이크. **파티 전체** 적용하되 **비조작 멤버 이벤트는 감쇄**(`SHAKE_NONCTRL_MULT` 0.4). 진폭은 가독성 위해 낮게(`SHAKE_MAX_POS` 0.45·`DMG_KICK_M` 0.6·caps 0.4/0.6).
- **이유:** 정보전/택티컬 게임이라 흔들림=가독성 해치지 않는 "신호". trauma²가 작은 건 미세·큰 건 펀치로 자동 차등 + clamp로 연타 블러 방지. 방향 킥은 "어느 쪽에서 맞았나" 정보 제공. (사용자 설계 결정)
- **적용:** 피벗(추종/글라이드)은 불간섭, Camera3D 로컬에만 적용. **흔들림=회전(rotational)** — 탑다운 원거리라 위치 흔들림은 거의 안 보여 회전 jitter로 체감 확보(진폭 `trauma^1.5` × `SHAKE_MAX_ROT_DEG` 3.5°, roll 0.5배). **방향 킥만 위치 오프셋**(화면기준 -pivot.yaw 회전). 서브 타격감이 안 느껴지던 문제 → `HIT_SHAKE_REF` 90→50·`CAP` 0.4→0.6로 상향.
- **분류:** F-012(Camera) 범위의 UX 피드백; 수치(REF/GAIN/CAP/KICK/DECAY/MAX_POS·NONCTRL 0.4)는 **tuning**. 전파 불요(안정화되면 F-012 카메라-피드백 규칙으로 승격 후보).
- **영향:** `scripts/combat/combat_controller.gd`(camera_shake 시그널·trauma 산출·평타 게이트), `scripts/run/dungeon_run.gd`(`_on_camera_shake`/`_apply_camera_shake`).

### IMPL-DEC-20260610-003 — 스왑 카메라 글라이드 (텔레포트 → 가속/감속)
- **결정:** 1~4 스왑 시 카메라 피벗이 순간이동하던 것을 **가속+arrive 감속 글라이드**(`_glide_camera`: desired=min(dist·gain, max), 속도 move_toward로 ramp)로 전환. 평소 추종은 **타이트 유지**(글라이드는 스왑 전환 중에만). 모든 스왑(수동/자동) 커버(`_on_controlled_changed`).
- **이유:** 스왑 카메라 텔레포트가 방향감 상실 → 빠르되 부드러운 전환으로 가독/유저 친화성↑. F-012(Camera) 범위의 **UX 폴리시**; 속도/가속/arrive_gain은 **tuning**(전파 불요).
- **영향:** `scripts/run/dungeon_run.gd`(_glide_camera·_focus_camera 재정의·per-frame 분기).
- **결정:** 익스트랙션을 **즉시 성공 스텁**에서 **POINT-DEMO-01 홀드 채널**로 전환. 조작 캐릭이 존(3m) 안에 머무는 동안 누적, 완료 시 `try_extract()`(Extraction Success). **비전투 5s / 전투중(`_combat.is_engaged()`) 30s** — 매 프레임 현재 상태로 임계 판정(전투가 붙으면 탈출이 길어짐). 존 이탈 시 **취소·리셋**(실패 정산 없음). 큰 카운트다운 라벨이 높은 수→1로 표시.
- **이유:** F-007 §3.1.2 `ExtractionActivate`는 "채널·홀드 등 상호작용 **완료** 시 성공"으로 이미 정의됨 — 즉시 스텁을 정합 구현으로 교체(사용자 요청). 채널 시간(5/30s)은 F-007이 "후속 UI/전투 SSOT"로 둔 **tuning**(SPEC_DRIFT DRIFT-020) → 전파 불요.
- **영향:** `scripts/run/dungeon_run.gd`(채널 타이머 `_update_extraction` + 카운트다운), `scenes/run/dungeon_run.tscn`(`HUD/ExtractCount` 라벨). `run_controller.try_extract()`는 완료 핸들러로 유지.

### IMPL-DEC-20260610-001 — 스펙 핀 재정렬 19f2af0 → 6f0e534 (F-013 전파)
- **결정:** DRIFT-018/019(적 시야 인지·분대 전투AI)를 spec staging에 전파 후 `spec_ref.json` 핀을 `19f2af0`→`6f0e534`로 bump.
- **전파 내용(spec repo, DEC-20260610-001):** `F-013`(Enemy Combat AI) 신설 — 휴면→경계→교전→이탈 상태머신·인지 게이트 진입·분대 교전 전파·타겟 공정성·lastSeenPos 수색→grace 이탈. `F-011`에 적 인지 데모 부분집합 노트, `QA-031` 1b In-scope 승격, 매퍼(FeatureMap/DependencyMap/DataMap)·SpecScopeTracker·TODO·I-000.
- **비전파:** 수치(DRIFT-020 tuning), 기존 spec 구현분(D-010/F-004/F-005/F-003 §3.4 — IMPL-DEC-20260609-001/003).
- **잔여(spec 후속):** F-013 포스트복귀/리쉬·perceptionProfile 차등·전용 QA-013·OPS_20 양방향 related/RelationGraph 동기화.
- **영향:** (game) `spec_ref.json`, `docs/SPEC_DRIFT.md` · (spec) F-013/F-011/F-022/F-024/QA-031/DataMap/FeatureMap/DependencyMap/DecisionLog/SpecScopeTracker/TODO/I-000.

### IMPL-DEC-20260609-003 — 비결속 지휘권 보유자(Active Anchor) 구현 (F-003 §3.4)
- **결정:** 파티비결속 앵커를 항상-리더에서 **지휘권 보유자**로 변경 — 진입 시 §3.4 규칙으로 결정(리더 조작 중+서브리더 유효 → 서브리더가 앵커 → 리더 독립 이동), 스왑으로 불변, 보유자 무효 시 자동 전환. 서브리더 기본값 = 첫 비-리더 멤버.
- **이유:** "리더(앵커)를 따로 이동시키고 서브앵커가 대체" 요구 = F-003 §3.4 그대로.
- **보류(spec 존재, 미구현):** 서브리더 지정 UI(UI-005)·지휘권 전환 UX(UI-008)·Leader Move Ping(F-003 §3.5) → 기본값/미구현. 전파 불필요(기존 spec 구현).
- **영향:** `scripts/party/party_controller.gd`.
