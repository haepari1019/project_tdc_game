#!/usr/bin/env bash
# Headless smoke gate — the manual verification, scripted. Loads each scene headless and FAILS
# (exit 1) on any script/parse/load error, missing-resource (broken preload/uid), or a scene
# that never reached its ready marker. Covers parse errors · broken preload paths · missing IDs
# (Slice01Data aborts) · drop-in skill/object load · scene boot — the reachable script graph.
# Does NOT cover mouse/play behavior (drag/equip/combat cast) — those still need playtest.
#
# Usage:  GODOT=/path/to/godot bash tools/ci_smoke.sh
#   local (win git-bash):  GODOT="/e/Game_design/Godot_v4.5.1-stable_win64.exe/Godot_v4.5.1-stable_win64_console.exe" bash tools/ci_smoke.sh
set -u
GODOT="${GODOT:-godot}"
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
ERRPAT='SCRIPT ERROR|Parse Error|Compile Error|Failed loading|non-existent|Identifier not found|Invalid call|Nonexistent function'
fail=0

echo "== import (uid cache rebuild) =="
"$GODOT" --headless --path "$PROJ" --import >/tmp/ci_import.log 2>&1 || true

check_scene() {
  local scene="$1" frames="$2" want="$3"
  local log="/tmp/ci_$(basename "$scene" .tscn).log"
  echo "== load $scene (quit-after $frames) =="
  "$GODOT" --headless --path "$PROJ" "$scene" --quit-after "$frames" >"$log" 2>&1
  local code=$? sfail=0
  [ "$code" -ne 0 ] && { echo "  FAIL: exit=$code"; sfail=1; }
  if grep -qE "$ERRPAT" "$log"; then echo "  FAIL: errors —"; grep -nE "$ERRPAT" "$log" | head -8; sfail=1; fi
  if [ -n "$want" ] && ! grep -qF "$want" "$log"; then echo "  FAIL: never reached marker '$want'"; sfail=1; fi
  [ "$sfail" -eq 0 ] && echo "  PASS" || fail=1
}

# scene · frames to tick · positive ready-marker (printed by the scene; "" = skip marker check)
check_scene "res://scenes/main.tscn"           8  "Hub ready"
check_scene "res://scenes/run/dungeon_run.tscn" 16 ""

# Hub logic (QA-029): facility upgrade gate + vault + haul drops + run-event quest. Asserts via a
# non-persisting HubProfile instance (does NOT touch user:// saves).
echo "== hub logic smoke (QA-029) =="
hublog="/tmp/ci_hub_smoke.log"
"$GODOT" --headless --path "$PROJ" --script res://tools/hub_smoke.gd >"$hublog" 2>&1
hcode=$?
if [ "$hcode" -ne 0 ] || ! grep -qF "HUB SMOKE PASSED" "$hublog"; then
  echo "  FAIL: hub smoke (exit=$hcode) —"; grep -nE "FAIL|$ERRPAT" "$hublog" | head -8; fail=1
else echo "  PASS"; fi

# Third-faction (Stalker Pack, DEC-20260621-001): outcome logic (Root/Pin lock, Bloodlust buff) +
# data wiring (AB-100~106 kinds, rom_* basics, PT-023/024/025, ENC-3RD-001 units).
echo "== third-faction smoke (DEC-20260621-001) =="
thirdlog="/tmp/ci_third_smoke.log"
"$GODOT" --headless --path "$PROJ" --script res://tools/third_smoke.gd >"$thirdlog" 2>&1
tcode=$?
if [ "$tcode" -ne 0 ] || ! grep -qF "THIRD SMOKE PASSED" "$thirdlog"; then
  echo "  FAIL: third smoke (exit=$tcode) —"; grep -nE "FAIL|$ERRPAT" "$thirdlog" | head -8; fail=1
else echo "  PASS"; fi

# Reaction decision-core (QA-021): primaryMedium priority resolver (EVENT-CORE §3) + RX matrix 4축
# (Fire/Cold/Lightning/Physical, F-027). 연쇄 실거동·VFX는 F5 체크리스트(docs/qa/F5_checklist_p2.md).
echo "== reaction smoke (QA-021) =="
rxlog="/tmp/ci_reaction_smoke.log"
"$GODOT" --headless --path "$PROJ" --script res://tools/reaction_smoke.gd >"$rxlog" 2>&1
rxcode=$?
if [ "$rxcode" -ne 0 ] || ! grep -qF "REACTION SMOKE PASSED" "$rxlog"; then
  echo "  FAIL: reaction smoke (exit=$rxcode) —"; grep -nE "FAIL|$ERRPAT" "$rxlog" | head -8; fail=1
else echo "  PASS"; fi

# Surface-grid substrate (S0, IMPL-DEC-20260721-001): world↔cell 수학 + stamp_circle 커버리지 +
# MultiMesh 렌더 경로 무크래시. dungeon_run 부팅엔 존이 없어 래스터/렌더 경로가 안 도므로 별도 게이트.
echo "== surface-grid smoke (S0 / DRIFT-096) =="
surflog="/tmp/ci_surface_smoke.log"
"$GODOT" --headless --path "$PROJ" --script res://tools/surface_smoke.gd >"$surflog" 2>&1
surfcode=$?
if [ "$surfcode" -ne 0 ] || ! grep -qF "SURFACE SMOKE PASSED" "$surflog"; then
  echo "  FAIL: surface smoke (exit=$surfcode) —"; grep -nE "FAIL|\[SURF\]|$ERRPAT" "$surflog" | head -8; fail=1
else echo "  PASS"; fi

# Party ability pool (P2-S6a, DRIFT-057): every skillbook cast.kind has a drop-in effect, band
# penalty (D-016/D-012 §2.4) resolves, B1 ally-only ABs (034/044/054/062/070/075) + Veiled/Silenced/
# Purge statuses behave.
echo "== party-pool smoke (P2-S6a / DRIFT-057) =="
pplog="/tmp/ci_party_pool_smoke.log"
"$GODOT" --headless --path "$PROJ" --script res://tools/party_pool_smoke.gd >"$pplog" 2>&1
pcode=$?
if [ "$pcode" -ne 0 ] || ! grep -qF "PARTY POOL SMOKE PASSED" "$pplog"; then
  echo "  FAIL: party-pool smoke (exit=$pcode) —"; grep -nE "FAIL|$ERRPAT" "$pplog" | head -8; fail=1
else echo "  PASS"; fi

# P4a Kit Binding pilot (P2-S8a): resolveEffectiveAbility triple-match (gear+identity+slot) + the
# enabled-gate (TANK-P4A-BASE regression, F-020 §3.7 step 5). Pure resolve() logic — overlay feel is
# the QA-005 §2.12 human gate (docs/qa/P4A_BIND_GATE_checklist.md).
echo "== binding pilot smoke (P2-S8a / QA-005 §2.12) =="
bindlog="/tmp/ci_binding_smoke.log"
"$GODOT" --headless --path "$PROJ" --script res://tools/binding_smoke.gd >"$bindlog" 2>&1
bcode=$?
if [ "$bcode" -ne 0 ] || ! grep -qF "BINDING SMOKE PASSED" "$bindlog"; then
  echo "  FAIL: binding smoke (exit=$bcode) —"; grep -nE "FAIL|\[BIND\]|$ERRPAT" "$bindlog" | head -8; fail=1
else echo "  PASS"; fi

# Enemy-usable object protocol (F-021 §3.1.2): the ENEMY_USABLE_OBJECTS registry — every usable
# object implements the required contract (enemy_usable/enemy_use); held-form adds enemy_combat_tick.
# Blocks partial-implementation runtime crashes (ctx parity gate와 동형).
echo "== object protocol smoke (F-021 §3.1.2) =="
objlog="/tmp/ci_object_smoke.log"
"$GODOT" --headless --path "$PROJ" --script res://tools/object_smoke.gd >"$objlog" 2>&1
ocode=$?
if [ "$ocode" -ne 0 ] || ! grep -qF "OBJECT SMOKE PASSED" "$objlog"; then
  echo "  FAIL: object smoke (exit=$ocode) —"; grep -nE "FAIL|$ERRPAT" "$objlog" | head -8; fail=1
else echo "  PASS"; fi

# Move-order state machine (DRIFT-090): RMB 클릭이동 오더의 NONE/MOVING/HOLD 전이 + cb 유무로
# 갈리는 도착 거동(순수 이동=HOLD 배치 / 심부름=NONE 복귀) + MIA·도발 취소 + nav 캐시 무효화.
echo "== move-order smoke (DRIFT-090) =="
molog="/tmp/ci_move_order_smoke.log"
"$GODOT" --headless --path "$PROJ" --script res://tools/move_order_smoke.gd >"$molog" 2>&1
mcode=$?
if [ "$mcode" -ne 0 ] || ! grep -qF "MOVE ORDER SMOKE PASSED" "$molog"; then
  echo "  FAIL: move-order smoke (exit=$mcode) —"; grep -nE "FAIL|$ERRPAT" "$molog" | head -8; fail=1
else echo "  PASS"; fi

# Drag-box selection coverage (DRIFT-090 후속): 아군 화면 사각형을 SELECT_COVER_MIN 이상 덮어야
# 선택 후보. 40° 피치에서 원점(발밑)이 사각형 하단 ~86%에 찍히므로, 옛 "원점 한 점" 판정은
# 발치만 스쳐도 선택됐다 — 카메라 피치를 바꾸면 이 게이트가 먼저 깨진다(의도).
echo "== drag-box selection smoke (DRIFT-090) =="
sellog="/tmp/ci_selection_smoke.log"
"$GODOT" --headless --path "$PROJ" --script res://tools/selection_smoke.gd >"$sellog" 2>&1
scode=$?
if [ "$scode" -ne 0 ] || ! grep -qF "SELECTION SMOKE PASSED" "$sellog"; then
  echo "  FAIL: selection smoke (exit=$scode) —"; grep -nE "FAIL|$ERRPAT" "$sellog" | head -8; fail=1
else echo "  PASS"; fi

echo "------------------------------------"
if [ "$fail" -eq 0 ]; then echo "SMOKE PASSED"; exit 0; else echo "SMOKE FAILED"; exit 1; fi
