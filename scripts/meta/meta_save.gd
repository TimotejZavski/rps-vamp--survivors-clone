extends Node
## Persistent meta-progression save. Holds gold and the player's permanent
## passive upgrade ranks. Stored as JSON under user://meta_save.json so it
## survives between sessions.

const SAVE_PATH := "user://meta_save.json"

var gold: int = 0
## id -> rank (1..MAX_PASSIVE_RANK from UpgradeCatalog).
var passive_upgrades: Dictionary = {}

## Player-facing options, persisted alongside progression.
const DEFAULT_SETTINGS := {
	"music_volume": 0.8,
	"sfx_volume": 0.9,
	"fullscreen": false,
}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)


func _ready() -> void:
	load_data()
	apply_settings()


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
		var st: Variant = data.get("settings", {})
		if st is Dictionary:
			for key in DEFAULT_SETTINGS.keys():
				if (st as Dictionary).has(key):
					settings[key] = (st as Dictionary)[key]


func save_data() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"gold": gold,
		"passive_upgrades": passive_upgrades,
		"settings": settings,
	}))
	f.close()


func get_setting(key: String) -> Variant:
	return settings.get(key, DEFAULT_SETTINGS.get(key))


## Stores a single option, persists, and re-applies all settings immediately.
func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	save_data()
	apply_settings()


## Pushes the stored options into the engine (audio bus volumes + window mode).
func apply_settings() -> void:
	_apply_bus_volume("Music", float(get_setting("music_volume")))
	_apply_bus_volume("SFX", float(get_setting("sfx_volume")))
	_apply_fullscreen(bool(get_setting("fullscreen")))


func _apply_bus_volume(bus_name: String, volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var v := clampf(volume, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(v) if v > 0.001 else -80.0)


func _apply_fullscreen(on: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


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
