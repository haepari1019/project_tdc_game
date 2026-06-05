# AGENTS.md — Game repository

## Overview

Godot **4.5.1** implementation for **Project TDC** (`project.godot` features: 4.5). Design SSOT lives in **`project_tdc`** (GitHub: `haepari1019/project_tdc`, branch `staging`). Do not duplicate `F-###` / `D-###` rule text here.

## Before coding

1. Read `spec_ref.json` for pinned spec commit.
2. Phase scope: `QA-030` in spec repo (`docs/qa/QA-030_Slice01_PlayableContract.md`).
3. ID contract: string 1:1 — `tank_anchor_guard`, `ENC-NORM-001`, `DBP-DEMO-001`, etc. No aliases; unregistered IDs → abort at load.

## This repo owns

- `project.godot`, scenes, scripts
- `data/` runtime manifests (derived from spec)
- `assets/` art/audio

## Do not

- Edit spec markdown in this repo (use spec repo + OPS workflow).
- Copy full feature specs into comments or duplicate SSOT.

## Git

- Default branch: `main`
- Commit messages: `feat:`, `fix:`, `data:`, `scene:` prefixes encouraged.
