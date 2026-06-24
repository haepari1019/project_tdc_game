# Skillbook Affix — 구현 설계 (D-018 §7.3/§7.6)

> 게임측 구현 노트. 규칙 SSOT = `F-009`/`D-018`(스펙 레포). 여기서 spec md 편집 금지.
> 관련: [SPEC_DRIFT DRIFT-062], [ImplDecisionLog IMPL-DEC-026], `scripts/run/affix_roller.gd`.

## 1. 무엇
루팅된 스킬북 **인스턴스**에 확률적으로 붙는 굴림 옵션. 기어 롤(F-008 §3.7)의 스킬북 판본.
- coeffMult → 스킬 효과 위력(밴드 패널티와 **독립**으로 곱, §7.3 note).
- chargesMax 가산 → 탄약.
- cd_trade → 쿨다운 가산(eff_minus_trade).

## 2. 인스턴스 스키마 (게임)
스킬북 instance/item/descriptor에 `affix: Dictionary` 필드. `{}` = 무affix(상점 생본·스타터·82% 루팅).
```
affix = { ids:[String], tier:"T1|T2|T3", coeff:float, charges:int, cd_trade:float }
```

## 3. Roll (`affix_roller.gd`, §7.6)
- **루팅만 18%**(상점 Raw=0% — 구매 경로는 roll 안 함).
- affixTier: T1 85% / T2 12% / T3 3%.
- 종류(가중): eff_plus(50, coeff 8–10%) · eff_minus_trade(25, coeff 10–12% + cd +5%) · charges_small(30, 탄 +4~6).
- coeff band 균일 추첨 × **tier scale**(T1 1.0/T2 1.06/T3 1.12) → **단일 ≤12% 클램프**(§7.3).
- **Slice-01 결정: 인스턴스당 단일 affix** — §7.3 합산 ≤15% cap을 자명히 만족. multi-affix=후속.

### 게임측 파생 (스펙 외, 튜닝)
- `TIER_SCALE`(희귀 tier일수록 coeff 소폭↑)는 스펙에 없는 게임측 파생 — cap으로 클램프. 절대 수치=데모, 런타임 SSOT는 F-025 §11(후속).

## 4. 적용 지점
- **coeff**: `ability_dispatch.cast_skillbook` — `p["_coeff"] = band_coeff × (1 + clamp(affix.coeff, ±15%))`. 효과는 `_coeff`를 곱(기존 밴드 경로 재사용).
- **cd_trade**: `inst.cooldown_s = cooldown_s × (1 + affix.cd_trade)`.
- **charges**: instance 빌드 시 `charges_max = master.charges_max + affix.charges`(equip_skillbook_by_id·equip_panel._skillbook_inst).

## 5. 보존 경로 (gear 롤과 동형)
`loot_service._make_skillbook_drop_def`(roll) → 픽업 디스크립터 → `Backpack._strip`(affix 키 유지) → 장착(`equip_panel._skillbook_inst`(item.affix) / `equip_skillbook_by_id(…, affix)`) → member inst.affix → `capture_from_party` subs(affix) → `apply_to_party`(affix 복원). 해제 시 `_skillbook_item_from_inst`가 affix 캐리.

## 6. UI
인벤 그리드 스킬북 툴팁에 affix 라인(`✦ <표시명> [tier] — 효과 +N% / 탄 +N / 쿨 +N%`). 표시명 = `display_names.json` `affixes`.

## 7. 검증
`party_pool_smoke` §16 — roll cap(coeff≤12%·탄0..6·ids/tier)·charges_max 가산·capture/apply 영속. ci_smoke PASS. 전투 적용·툴팁 표시 = F5.

## 8. 잔여
- multi-affix(§7.3 합산 ≤15%) · §7.5 중복 sink(분해 8/매각 4) · `affixTier` 5단·런타임 tuning(F-025 §11) · 대장간 리롤(Expansion).
