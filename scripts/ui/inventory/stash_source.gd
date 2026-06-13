extends Node
## Stash container source for InventoryUI.open_loot() — exposes the same duck-typed surface as
## a world chest (title + items[]) so the deployment hub can present the player's Stash as a
## loot grid to drag gear/skillbooks/consumables out of. ref: F-010 deployment hub.

var title := "STASH (보유)"
var items: Array = []
