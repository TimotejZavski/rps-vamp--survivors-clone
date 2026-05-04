extends RefCounted

class_name UpgradeCatalog

const MAX_RANK := 3

const DEFINITIONS := {
	"power_training": {
		"title": "Power Training",
		"description": "+6 weapon damage",
	},
	"long_reach": {
		"title": "Long Reach",
		"description": "+12 attack range",
	},
	"rapid_casting": {
		"title": "Rapid Casting",
		"description": "-0.10 weapon cooldown",
	},
	"vitality": {
		"title": "Vitality",
		"description": "+20 max HP and heal 20",
	},
	"fleet_footed": {
		"title": "Fleet Footed",
		"description": "+15 move speed",
	},
}


func get_choices(owned_upgrades: Dictionary) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for id in DEFINITIONS.keys():
		var rank := int(owned_upgrades.get(id, 0))
		if rank >= MAX_RANK:
			continue
		var choice: Dictionary = DEFINITIONS[id].duplicate(true)
		choice["id"] = id
		choice["label"] = "%s %d/%d" % [str(choice["title"]), rank + 1, MAX_RANK]
		pool.append(choice)

	pool.shuffle()

	var result: Array[Dictionary] = []
	while not pool.is_empty() and result.size() < 3:
		result.append(pool.pop_back())
	return result


func apply_choice(choice_id: String, game, player) -> void:
	match choice_id:
		"power_training":
			game.apply_weapon_damage_bonus(6)
		"long_reach":
			game.apply_attack_range_bonus(12.0)
		"rapid_casting":
			game.apply_weapon_cooldown_bonus(-0.10)
		"vitality":
			player.apply_bonus_max_health(20)
			player.heal(20)
		"fleet_footed":
			player.apply_move_speed_bonus(15.0)
