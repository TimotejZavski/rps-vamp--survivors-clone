class_name WeaponRegistry
extends RefCounted
## Central map of weapon id -> script. Add new weapons here.

const _DEFS := {
	"magic_wand": preload("res://scripts/weapons/weapons/magic_wand.gd"),
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
