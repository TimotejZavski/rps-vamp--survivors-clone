extends RefCounted

class_name UpgradeCatalog
## Builds level-up choice triplets. Choices come in three flavors:
##   "new_weapon:<id>"   - add an unowned weapon (only if inventory has room)
##   "level_weapon:<id>" - bump an owned weapon by one level (cap MAX_LEVEL)
##   "passive:<id>"      - bump a passive stat upgrade by one rank (cap MAX_PASSIVE_RANK)

const MAX_PASSIVE_RANK := 5

const WEAPONS := {
	"magic_wand": { "name": "Magic Wand", "desc": "Auto-fires at the nearest enemy." },
	"knife": { "name": "Knife", "desc": "Fires quickly in your facing direction." },
	"garlic": { "name": "Garlic", "desc": "Damages enemies in an aura around you." },
	"axe": { "name": "Axe", "desc": "Drops from above. High damage." },
	"king_bible": { "name": "King Bible", "desc": "Orbits you, hitting nearby enemies." },
	"whip": { "name": "Whip", "desc": "Horizontal slash; pierces enemies in its path." },
}

const PASSIVES := {
	"power_training": { "title": "Power Training", "description": "+6 damage to all weapons" },
	"long_reach": { "title": "Long Reach", "description": "+15 range to ranged weapons" },
	"rapid_casting": { "title": "Rapid Casting", "description": "-0.08s weapon cooldown" },
	"vitality": { "title": "Vitality", "description": "+20 max HP and heal 20" },
	"fleet_footed": { "title": "Fleet Footed", "description": "+15 move speed" },
}


func get_choices(inventory: WeaponInventory, owned_passives: Dictionary) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []

	if not inventory.is_full():
		for wid in WEAPONS.keys():
			if inventory.has_weapon(wid):
				continue
			pool.append({
				"id": "new_weapon:%s" % wid,
				"label": "New: %s" % str(WEAPONS[wid]["name"]),
				"description": str(WEAPONS[wid]["desc"]),
			})

	for w in inventory.weapons:
		if w.is_max_level():
			continue
		pool.append({
			"id": "level_weapon:%s" % w.id,
			"label": "%s  Lv %d -> %d" % [w.display_name, w.level, w.level + 1],
			"description": "Stronger %s." % w.display_name.to_lower(),
		})

	for pid in PASSIVES.keys():
		var rank := int(owned_passives.get(pid, 0))
		if rank >= MAX_PASSIVE_RANK:
			continue
		var p: Dictionary = PASSIVES[pid]
		pool.append({
			"id": "passive:%s" % pid,
			"label": "%s  %d/%d" % [str(p["title"]), rank + 1, MAX_PASSIVE_RANK],
			"description": str(p["description"]),
		})

	pool.shuffle()

	var result: Array[Dictionary] = []
	while not pool.is_empty() and result.size() < 3:
		result.append(pool.pop_back())
	return result


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
		"power_training":
			game.apply_global_damage_bonus(6)
		"long_reach":
			game.apply_global_range_bonus(15.0)
		"rapid_casting":
			game.apply_global_cooldown_bonus(-0.08)
		"vitality":
			player.apply_bonus_max_health(20)
			player.heal(20)
		"fleet_footed":
			player.apply_move_speed_bonus(15.0)
