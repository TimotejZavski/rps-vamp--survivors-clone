class_name WeaponRegistry
extends RefCounted
## Central map of weapon id -> script. Add new weapons (including evolutions) here.

const _DEFS := {
	# Base weapons - directly pickable from the upgrade pool.
	"magic_wand": preload("res://scripts/weapons/weapons/magic_wand.gd"),
	"knife": preload("res://scripts/weapons/weapons/knife.gd"),
	"garlic": preload("res://scripts/weapons/weapons/garlic.gd"),
	"axe": preload("res://scripts/weapons/weapons/axe.gd"),
	"king_bible": preload("res://scripts/weapons/weapons/king_bible.gd"),
	"whip": preload("res://scripts/weapons/weapons/whip.gd"),
	# Evolutions - only granted by evolving via a chest, never offered directly.
	"bloody_tear": preload("res://scripts/weapons/weapons/bloody_tear.gd"),
	"thousand_edge": preload("res://scripts/weapons/weapons/thousand_edge.gd"),
	"death_spiral": preload("res://scripts/weapons/weapons/death_spiral.gd"),
	"soul_eater": preload("res://scripts/weapons/weapons/soul_eater.gd"),
}

## Evolved weapons are not pickable as ordinary upgrades; the catalog filters
## them out of the new-weapon pool.
const EVOLUTION_IDS := ["bloody_tear", "thousand_edge", "death_spiral", "soul_eater"]


static func create(weapon_id: String) -> Weapon:
	if not _DEFS.has(weapon_id):
		return null
	var script: GDScript = _DEFS[weapon_id]
	return script.new()


static func all_ids() -> Array:
	return _DEFS.keys()


static func has(weapon_id: String) -> bool:
	return _DEFS.has(weapon_id)


static func is_evolution(weapon_id: String) -> bool:
	return weapon_id in EVOLUTION_IDS
