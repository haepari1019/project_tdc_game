# Slice-01 runtime data (Phase 1a)

Derived from spec SSOT at `spec_ref.json` pin. **Do not invent IDs.**

## Sync (manual)

1. Edit rules in local spec repo: `../project_tdc_spec/docs/` (or path on your machine).
2. Update JSON here to match encounter / identity / DBP-DEMO-001 tables.
3. Extend `id_registry.json` when adding any new canonical id.
4. Bump `spec_ref.json` when pinning a new spec commit.

## Files

| File | Purpose |
|------|---------|
| `manifest.json` | QA-030 contract, pools → encounter, 4 identities |
| `blueprint.json` | DBP-DEMO-001 run phases, third_faction off |
| `id_registry.json` | Allowed ids for load-time abort (`ENC-000` §8 spirit) |
| `identities.json` | `identity_skill_id` → `ability_id`, `pattern_id`, `class_id` |
| `enemies.json` | Slice-01 enemy subset |
| `encounters/*.json` | Unit composition per `ENC-###` |
| `rooms.json` | `MAP-DEMO-001` stub graph (`DBP-DEMO-001` §6) |

## Loader

`Slice01Data` autoload — validates on startup; unknown id → error + quit.

Spec sources (local):

- `docs/qa/QA-030_Slice01_PlayableContract.md`
- `docs/level-design/blueprints/DBP-DEMO-001.md`
- `docs/combat/encounters/ENC-NORM-001.md`, `ENC-NORM-002.md`
- `docs/combat/abilities/AB-020`, `AB-024`, `AB-025`, `AB-026`
