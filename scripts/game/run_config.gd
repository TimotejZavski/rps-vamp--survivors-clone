extends Node

## Carries the chosen character and weapon data from CharacterSelect into Game.

var character_id: String = "wizard"
var display_name: String = "Imelda Belpaese"
var weapon_placeholder_name: String = "Magic Wand"
var starting_weapon_id: String = "magic_wand"

## Legacy stat fields. Now unused at runtime (weapons own their own stats),
## kept so older save data / UI strings don't crash if they read them.
var weapon_cooldown: float = 1.15
var attack_range: float = 88.0
var melee_damage: int = 36

## Filled when a run ends (game over, end run, or death) for the Game Over screen.
var last_run_time_seconds: float = 0.0
var last_run_level: int = 1
var last_run_kills: int = 0

const PRESETS := {
	"wizard": {
		"display_name": "Imelda Belpaese",
		"weapon_placeholder_name": "Magic Wand",
		"starting_weapon_id": "magic_wand",
	},
	"knight": {
		"display_name": "Krochi Freetto",
		"weapon_placeholder_name": "Magic Wand",
		"starting_weapon_id": "magic_wand",
	},
	"cleric": {
		"display_name": "Suor Clerici",
		"weapon_placeholder_name": "Magic Wand",
		"starting_weapon_id": "magic_wand",
	},
}


func apply_preset(id: String) -> void:
	var key := id
	if not PRESETS.has(key):
		key = "wizard"
	character_id = key
	var p: Dictionary = PRESETS[key]
	display_name = p.display_name
	weapon_placeholder_name = p.weapon_placeholder_name
	starting_weapon_id = p.starting_weapon_id
