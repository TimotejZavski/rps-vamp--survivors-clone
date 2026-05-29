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

## Per-character stat modifiers. Read by game.gd at run start so each hero
## actually plays differently instead of being a pure reskin.
var bonus_max_health: int = 0
var move_speed_mult: float = 1.0
var global_damage_bonus: int = 0
var bonus_armor: int = 0
var bonus_recovery: float = 0.0

## Filled when a run ends (game over, end run, or death) for the Game Over screen.
var last_run_time_seconds: float = 0.0
var last_run_level: int = 1
var last_run_kills: int = 0
## Extra end-of-run stats for the death/summary screens.
var last_run_gold: int = 0
var last_run_weapons: Array[String] = []
var last_run_passives: Array[String] = []

## Each hero now has a distinct starting weapon and a stat profile:
##   Imelda  - glass cannon: ranged wand, extra damage, fragile.
##   Krochi  - bruiser: melee whip, lots of HP + armor, slower.
##   Clerici - support: holy aura, fast, self-healing.
const PRESETS := {
	"wizard": {
		"display_name": "Imelda Belpaese",
		"weapon_placeholder_name": "Magic Wand",
		"starting_weapon_id": "magic_wand",
		"bonus_max_health": 0,
		"move_speed_mult": 1.0,
		"global_damage_bonus": 8,
		"bonus_armor": 0,
		"bonus_recovery": 0.0,
	},
	"knight": {
		"display_name": "Krochi Freetto",
		"weapon_placeholder_name": "Whip",
		"starting_weapon_id": "whip",
		"bonus_max_health": 80,
		"move_speed_mult": 0.92,
		"global_damage_bonus": 0,
		"bonus_armor": 3,
		"bonus_recovery": 0.0,
	},
	"cleric": {
		"display_name": "Suor Clerici",
		"weapon_placeholder_name": "Garlic",
		"starting_weapon_id": "garlic",
		"bonus_max_health": 25,
		"move_speed_mult": 1.12,
		"global_damage_bonus": 0,
		"bonus_armor": 0,
		"bonus_recovery": 0.7,
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
	bonus_max_health = int(p.get("bonus_max_health", 0))
	move_speed_mult = float(p.get("move_speed_mult", 1.0))
	global_damage_bonus = int(p.get("global_damage_bonus", 0))
	bonus_armor = int(p.get("bonus_armor", 0))
	bonus_recovery = float(p.get("bonus_recovery", 0.0))
