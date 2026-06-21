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

echo "------------------------------------"
if [ "$fail" -eq 0 ]; then echo "SMOKE PASSED"; exit 0; else echo "SMOKE FAILED"; exit 1; fi
