extends Node
## SaveProfile — single-file save wrapper (user://save.json, versioned). The domain autoloads
## (HubProfile / Stash / Backpack) keep their own in-memory data + to_dict()/apply_dict(); this
## node owns ALL file I/O and aggregates them into ONE atomic file:
##   { "version": N, "hub": {...}, "stash": {...}, "backpack": {...} }
## A domain pushes its section via put(key, dict) (rewrites the whole file) and pulls it via
## section(key) on load. One file = atomic save · single reset/backup point · one version line.
## MUST load BEFORE the domain autoloads (project.godot order). ref: 사용자 — 세이브 단일 파일.

const SAVE_PATH := "user://save.json"
const VERSION := 1
# Legacy per-domain files (pre-unification) — imported once if save.json is absent.
const LEGACY := {"user://hub_profile.json": "hub", "user://stash.json": "stash"}

var _data: Dictionary = {}   # {version, hub, stash, backpack}


func _ready() -> void:
	_load()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_migrate_legacy()   # first run after unification → fold old files in (preserve progress)
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) == TYPE_DICTIONARY:
		_data = d


## A domain's saved section (its own dict, {} if never saved → domain seeds).
func section(key: String) -> Dictionary:
	var s = _data.get(key, {})
	return s if typeof(s) == TYPE_DICTIONARY else {}


## A domain pushes its updated section and the whole file is rewritten (atomic, small JSON).
func put(key: String, d: Dictionary) -> void:
	_data[key] = d
	_data["version"] = VERSION
	save()


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_data))
	f.close()


## 저장 전체 초기화 (테스트/디버그) — 파일 삭제 + 인메모리 클리어. 호출 직후 도메인 오토로드가
## reset_to_seed()로 각 섹션을 시드 재저장한다(이 노드는 파일/_data만 비운다).
func wipe() -> void:
	_data = {}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


## One-time import of the legacy per-domain files into the unified store (preserve existing
## progress on upgrade). The old files keep their exact section shape, so it's a direct fold-in.
func _migrate_legacy() -> void:
	var migrated := false
	for path in LEGACY:
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var d = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(d) == TYPE_DICTIONARY:
			_data[String(LEGACY[path])] = d
			migrated = true
	if migrated:
		_data["version"] = VERSION
		save()
		print("[SAVE] migrated legacy save files → %s" % SAVE_PATH)
