class_name WeaponInventory
extends RefCounted
## Holds the player's active weapons (max 6) and ticks each per frame.

const MAX_SLOTS := 6

var weapons: Array[Weapon] = []


func add_weapon(w: Weapon) -> bool:
	if w == null:
		return false
	if is_full():
		return false
	if has_weapon(w.id):
		return false
	weapons.append(w)
	return true


func has_weapon(weapon_id: String) -> bool:
	for w in weapons:
		if w.id == weapon_id:
			return true
	return false


func get_weapon(weapon_id: String) -> Weapon:
	for w in weapons:
		if w.id == weapon_id:
			return w
	return null


func is_full() -> bool:
	return weapons.size() >= MAX_SLOTS


## Remove a weapon by id. Returns the removed weapon (or null) so callers
## can clean up any visual nodes the weapon attached to the scene.
func remove_weapon(weapon_id: String) -> Weapon:
	for i in weapons.size():
		if weapons[i].id == weapon_id:
			var removed: Weapon = weapons[i]
			weapons.remove_at(i)
			return removed
	return null


func process(delta: float, game: Node, player: Node2D) -> void:
	for w in weapons:
		w.process(delta, game, player)
