extends Node
## Persistent meta-progression save. Holds gold and the player's permanent
## passive upgrade ranks. Stored as JSON under user://meta_save.json so it
## survives between sessions.

const SAVE_PATH := "user://meta_save.json"

var gold: int = 0
## id -> rank (1..MAX_PASSIVE_RANK from UpgradeCatalog).
var passive_upgrades: Dictionary = {}


func _ready() -> void:
	load_data()


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var data: Dictionary = parsed
		gold = int(data.get("gold", 0))
		var pu: Variant = data.get("passive_upgrades", {})
		if pu is Dictionary:
			passive_upgrades = (pu as Dictionary).duplicate(true)


func save_data() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({ "gold": gold, "passive_upgrades": passive_upgrades }))
	f.close()


func add_gold(amount: int) -> void:
	if amount == 0:
		return
	gold = maxi(0, gold + amount)
	save_data()


func spend_gold(amount: int) -> bool:
	if amount <= 0 or gold < amount:
		return false
	gold -= amount
	save_data()
	return true


func passive_rank(id: String) -> int:
	return int(passive_upgrades.get(id, 0))


func rank_up_passive(id: String) -> void:
	passive_upgrades[id] = passive_rank(id) + 1
	save_data()


func reset_all() -> void:
	gold = 0
	passive_upgrades.clear()
	save_data()
