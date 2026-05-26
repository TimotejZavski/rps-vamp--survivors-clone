class_name WeaponRegistry
extends RefCounted
## Central map of weapon id -> script. Add new weapons here.

const _DEFS := {
	"magic_wand": preload("res://scripts/weapons/weapons/magic_wand.gd"),
	"knife": preload("res://scripts/weapons/weapons/knife.gd"),
	"garlic": preload("res://scripts/weapons/weapons/garlic.gd"),
	"axe": preload("res://scripts/weapons/weapons/axe.gd"),
	"king_bible": preload("res://scripts/weapons/weapons/king_bible.gd"),
	"whip": preload("res://scripts/weapons/weapons/whip.gd"),
}


static func create(weapon_id: String) -> Weapon:
	if not _DEFS.has(weapon_id):
		return null
	var script: GDScript = _DEFS[weapon_id]
	return script.new()


static func all_ids() -> Array:
	return _DEFS.keys()


static func has(weapon_id: String) -> bool:
	return _DEFS.has(weapon_id)
