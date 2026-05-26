extends RefCounted

class_name UpgradeCatalog
## Builds level-up choice triplets. Choice ids:
##   "new_weapon:<id>"
##   "level_weapon:<id>"
##   "passive:<id>"
##
## Each returned choice dict contains rich metadata for the upgrade screen:
##   id, icon, title, description, footer (e.g. "Lv 3 -> 4"), delta (e.g. "+6 DMG").

const MAX_PASSIVE_RANK := 5

const WEAPONS := {
	"magic_wand": {
		"name": "Magic Wand",
		"desc": "Auto-fires at the nearest enemy.",
		"icon": "res://assets/icons/Sprite-Magic_Wand.png",
	},
	"knife": {
		"name": "Knife",
		"desc": "Fires quickly in your facing direction.",
		"icon": "res://assets/icons/Sprite-Knife.png",
	},
	"garlic": {
		"name": "Garlic",
		"desc": "Damages enemies in an aura around you.",
		"icon": "res://assets/icons/Sprite-Garlic.png",
	},
	"axe": {
		"name": "Axe",
		"desc": "Drops from above. High damage.",
		"icon": "res://assets/icons/Sprite-Axe.png",
	},
	"king_bible": {
		"name": "King Bible",
		"desc": "Orbits you, hitting nearby enemies.",
		"icon": "res://assets/icons/Sprite-King_Bible.png",
	},
	"whip": {
		"name": "Whip",
		"desc": "Horizontal slash; pierces enemies in its path.",
		"icon": "res://assets/icons/Sprite-Whip.png",
	},
}

## Each passive ranks 1..MAX_PASSIVE_RANK. "delta" is the human-readable amount
## granted PER rank; "value" is the actual number applied per rank.
const PASSIVES := {
	"might": {
		"title": "Might",
		"description": "Increases damage of all weapons.",
		"icon": "res://assets/icons/Sprite-Might.png",
		"delta": "+5 damage",
		"value": 5,
	},
	"area": {
		"title": "Area",
		"description": "Increases attack range of weapons.",
		"icon": "res://assets/icons/Sprite-Area.png",
		"delta": "+12 range",
		"value": 12.0,
	},
	"speed": {
		"title": "Speed",
		"description": "Reduces weapon cooldowns.",
		"icon": "res://assets/icons/Sprite-Speed.png",
		"delta": "-0.06s cooldown",
		"value": -0.06,
	},
	"max_health": {
		"title": "Max Health",
		"description": "Increases your maximum HP and heals you.",
		"icon": "res://assets/icons/Sprite-Max_Health.png",
		"delta": "+15 max HP",
		"value": 15,
	},
	"move_speed": {
		"title": "Move Speed",
		"description": "Increases movement speed.",
		"icon": "res://assets/icons/Sprite-Move_Speed.png",
		"delta": "+12 speed",
		"value": 12.0,
	},
	"armor": {
		"title": "Armor",
		"description": "Reduces damage taken from enemies.",
		"icon": "res://assets/icons/Sprite-Armor_(stat).png",
		"delta": "+1 armor",
		"value": 1,
	},
	"recovery": {
		"title": "Recovery",
		"description": "Regenerates HP over time.",
		"icon": "res://assets/icons/Sprite-Recovery.png",
		"delta": "+0.4 HP/s",
		"value": 0.4,
	},
}


func get_choices(inventory: WeaponInventory, owned_passives: Dictionary) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []

	if not inventory.is_full():
		for wid in WEAPONS.keys():
			if inventory.has_weapon(wid):
				continue
			var w: Dictionary = WEAPONS[wid]
			pool.append({
				"id": "new_weapon:%s" % wid,
				"icon": str(w["icon"]),
				"title": str(w["name"]),
				"description": str(w["desc"]),
				"footer": "NEW WEAPON",
				"delta": "",
			})

	for w in inventory.weapons:
		if w.is_max_level():
			continue
		pool.append({
			"id": "level_weapon:%s" % w.id,
			"icon": w.icon_path,
			"title": w.display_name,
			"description": _weapon_description(w.id),
			"footer": "Lv %d → %d" % [w.level, w.level + 1],
			"delta": _weapon_level_delta(w),
		})

	for pid in PASSIVES.keys():
		var rank: int = int(owned_passives.get(pid, 0))
		if rank >= MAX_PASSIVE_RANK:
			continue
		var p: Dictionary = PASSIVES[pid]
		pool.append({
			"id": "passive:%s" % pid,
			"icon": str(p["icon"]),
			"title": str(p["title"]),
			"description": str(p["description"]),
			"footer": "Rank %d → %d" % [rank, rank + 1],
			"delta": str(p["delta"]),
		})

	pool.shuffle()
	var result: Array[Dictionary] = []
	while not pool.is_empty() and result.size() < 3:
		result.append(pool.pop_back())
	return result


static func _weapon_description(weapon_id: String) -> String:
	if WEAPONS.has(weapon_id):
		return str(WEAPONS[weapon_id]["desc"])
	return ""


## Computes the stat delta from the weapon's current level to current+1 by
## temporarily bumping the level, querying the getters, then restoring. Avoids
## duplicating per-weapon formulas in the catalog.
static func _weapon_level_delta(w: Weapon) -> String:
	var dmg0: int = w.get_damage()
	var cd0: float = w.get_cooldown()
	var rng0: float = w.get_range()
	w.level += 1
	var dmg1: int = w.get_damage()
	var cd1: float = w.get_cooldown()
	var rng1: float = w.get_range()
	w.level -= 1

	var parts: Array[String] = []
	if dmg1 != dmg0:
		parts.append("%+d DMG" % (dmg1 - dmg0))
	if absf(cd1 - cd0) > 0.001:
		parts.append("%+.2fs CD" % (cd1 - cd0))
	if absf(rng1 - rng0) > 0.5:
		parts.append("%+.0f RNG" % (rng1 - rng0))
	if parts.is_empty():
		parts.append("Stronger %s" % w.display_name.to_lower())
	return "  ".join(parts)


func apply_choice(choice_id: String, game, player) -> void:
	if choice_id.is_empty():
		return
	var sep := choice_id.find(":")
	if sep < 0:
		return
	var kind := choice_id.substr(0, sep)
	var key := choice_id.substr(sep + 1)
	match kind:
		"new_weapon":
			game.grant_weapon(key)
		"level_weapon":
			game.level_up_weapon(key)
		"passive":
			_apply_passive(key, game, player)


func _apply_passive(passive_id: String, game, player) -> void:
	match passive_id:
		"might":
			game.apply_global_damage_bonus(5)
		"area":
			game.apply_global_range_bonus(12.0)
		"speed":
			game.apply_global_cooldown_bonus(-0.06)
		"max_health":
			player.apply_bonus_max_health(15)
			player.heal(15)
		"move_speed":
			player.apply_move_speed_bonus(12.0)
		"armor":
			player.apply_armor_bonus(1)
		"recovery":
			player.apply_recovery_bonus(0.4)
