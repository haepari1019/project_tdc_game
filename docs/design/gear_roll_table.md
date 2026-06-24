# Gear Roll-Table 이행 — 설계 (게임측 정본)

> **무엇:** gear `identityRollTable` 이행(F-008 §3.7 / DEC-20260618-002)의 게임측 설계·마이그레이션 계획.
> 1:1 `bundled_identity_skill_id`(레거시 핀) → 아키타입(굴림 테이블) + 인스턴스(굴린 identity + 서브옵션).
> SSOT: spec `F-008 §3.7`·`GEAR-COR-000`·`D-019`. 본 문서는 게임측 실행 계획(규칙 아님).
> **상태:** 결정 확정(2026-06-23) — id 스펙 엄격 정렬 · 롤테이블 권고안(파생) · 인스턴스 스키마. G1 착수.

## 1. 모델 (스펙)

- **아키타입(master, `gear.json`)** = 장비 *종류*: `base_gear_id` + `ba_*`/`gaux_*` 형태 + `rangeBand` + **옵션 풀**(굴림 테이블 + 서브옵션 band). Identity 1:1 폐기.
- **인스턴스** = 아키타입 참조 + **굴린 선택**: `rolled_identity_skill_id` + 서브옵션 roll. 보관/드롭/장착 단위.
- **롤 시점 = 획득 시**(드롭/구매/지급). 한 번 굴리면 인스턴스에 고정(재장착해도 불변). 스타터 = 핀(재굴림 없음, mult 1.0).
- 효과 identity = 인스턴스의 `rolled_identity_skill_id` (`D-011`).

## 2. 결정 (확정)

1. **기어 ID = 스펙 엄격 정렬.** 17 비스타터는 이미 spec 슬러그 일치(kite_shield·weave_staff…). **스타터 4종만 개명**:
   `gear_ward_tank_anchor_set`→`gear_ward_tank_anchor_bulwark` · `…dps_press_set`→`…dps_press_rod` ·
   `…nuker_ruin_set`→`…nuker_ruin_sight` · `…healer_mend_set`→`…healer_mend_lantern` (GEAR-COR-000 §2, 1회 alias 허용).
2. **롤테이블 = 권고안(파생).** 아키타입별 명시 테이블 대신, **클래스 후보에서 파생**: main(현 bundled, weight 50) + 동클래스 나머지 identity(잔여 균등). 명시 per-gear 테이블 override = 향후.
3. **인스턴스 스키마(최소·확장형):** 아키타입이 풀을 정의, 인스턴스는 굴린 것만 저장.
   ```
   { "base_gear_id": <archetype>,            # 옵션 풀(롤테이블·band) 정의
     "rolled_identity_skill_id": <skillId>,   # identityRollTable에서 굴림
     "rolls": { "dmg_mult": x, "cd_mult": y } }  # 서브옵션(band roll); affix 등 확장
   ```
   `rolls`는 확장 슬롯 — 아이템별 가능한 서브옵션이 아키타입에 정의되고, 굴린 값만 여기 저장.

## 3. 마이그레이션 (3단계)

### G1 — 토대 (저위험·가산, 거동 불변)
- 스타터 4 id 개명(gear.json·id_registry·Backpack 시드·loot_service) + **세이브 마이그레이션**(old→new alias, Backpack.apply_dict).
- `Slice01Data.get_gear_identity_roll_table(base_gear_id)` = 파생 권고안.
- `party_member._bind_gear`: `gear.get("rolled_identity_skill_id", bundled)` — master엔 rolled 없음 → bundled(불변). 인스턴스 전달 시 rolled 사용(fwd-prep).
- 인스턴스 스키마 문서화(저장은 G2부터).

### G2 — 획득 롤 + 인스턴스 저장 (위험: 저장 포맷 문자열→딕셔너리)
- 기어 저장을 인스턴스 딕셔너리로 승격: `Backpack.equipped.gear`·`Stash.gear`·loot def·item_factory·equip_panel.
- 롤 시점: loot_service 드롭(넓은 band·full table) / 상점(좁은 band) / 스타터(핀). `apply_to_party`가 인스턴스의 rolled identity로 bind.
- 레거시 세이브 문자열 기어 → `{base, rolled=bundled, mult 1.0}` 1회 변환.

### G3 — 서브옵션 mult + UI (마무리)
- `dmg_mult`/`cd_mult` band(드롭 0.90–1.10 / 상점 0.95–1.05, D-019 §8) → 평타/identity 스탯에 곱.
- 인벤/장착 UI에 굴린 identity + mult 표시. 샌드박스 검증툴.
- 대장간 리롤/교체 = Expansion non-goal(§3.8) — 제외.

## 4. Blast radius
`gear.json`(아키타입) · `party_member._bind_gear` · `Backpack.equipped` · `Stash.gear` · `loot_service`(드롭) ·
`item_factory.gear_item` · `equip_panel` · SaveProfile 영속. G2가 핵심(문자열→인스턴스, 메타세이브 I 패턴 재사용).

## 5. 리스크 & 권고
- G1 = 안전(가산·폴백·바운드 id 개명). G2 = 저장 포맷 변경 → 메타세이브 I 마이그레이션 패턴으로 신중 단독.
- 권고: **G1 → 검증 → G2 별도 진행**. ([[refactor-risk-preference]])

## 6. 미해결/향후
- per-archetype 명시 롤테이블(현 파생) · affix(D-018 §7.3) · D-019 §8 정확 band 수치 · 대장간(Expansion).
