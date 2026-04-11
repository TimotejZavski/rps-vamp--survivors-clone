extends Node

## Carries the chosen character / weapon stub from CharacterSelect into Game (placeholder data).

var character_id: String = "wizard"
var display_name: String = "Imelda Belpaese"
var weapon_placeholder_name: String = "Staff Bolt"

var weapon_cooldown: float = 1.15
var attack_range: float = 88.0
var melee_damage: int = 36

const PRESETS := {
	"wizard": {
		"display_name": "Imelda Belpaese",
		"weapon_placeholder_name": "Staff Bolt",
		"weapon_cooldown": 1.2,
		"attack_range": 88.0,
		"melee_damage": 36,
	},
	"knight": {
		"display_name": "Placeholder Knight",
		"weapon_placeholder_name": "Sword Slash",
		"weapon_cooldown": 0.85,
		"attack_range": 64.0,
		"melee_damage": 28,
	},
	"cleric": {
		"display_name": "Placeholder Cleric",
		"weapon_placeholder_name": "Holy Aura",
		"weapon_cooldown": 1.5,
		"attack_range": 108.0,
		"melee_damage": 22,
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
	weapon_cooldown = p.weapon_cooldown
	attack_range = p.attack_range
	melee_damage = p.melee_damage
