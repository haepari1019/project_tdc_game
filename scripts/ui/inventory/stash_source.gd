extends Node
## Stash container source for InventoryUI.open_loot() — exposes the same duck-typed surface as
## a world chest (title + items[]) so the deployment hub can present the player's Stash as a
## loot grid to drag gear/skillbooks/consumables out of. ref: F-010 deployment hub.

var title := "STASH (보유)"
var items: Array = []
# Tarkov-style: the stash is a large persistent store, far bigger than the in-raid backpack
# (5x8=40). open_loot() reads these to size its container grid. 10x12 = 120 cells.
var cols := 10
var rows := 12


## Marks this loot source as the player's persistent Stash (vs a world chest) — InventoryUI uses
## it to route Shift+우클릭 버리기 to a permanent owned removal (Stash autoload) instead of a drop.
func is_stash_source() -> bool:
	return true
