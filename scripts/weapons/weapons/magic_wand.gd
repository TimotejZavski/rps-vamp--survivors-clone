extends Weapon
## Fires a homing-at-spawn tracer projectile at the nearest enemy in range.

const PROJECTILE_SCENE := preload("res://scenes/game/Projectile.tscn")
const ICON := "res://assets/icons/Sprite-Magic_Wand.png"


func _init() -> void:
	id = "magic_wand"
	display_name = "Magic Wand"
	icon_path = ICON


func get_cooldown() -> float:
	return maxf(0.25, 1.15 - float(level - 1) * 0.07 + cd_bonus)


func get_damage() -> int:
	# Base 36 one-shots a starting bat (32 HP) so they don't pile up before the
	# player can dent the wave. Each level adds 8 to keep pace with HP scaling.
	return 36 + (level - 1) * 8 + dmg_bonus


func get_range() -> float:
	return 280.0 + float(level - 1) * 18.0 + range_bonus


func _fire(game: Node, player: Node2D) -> void:
	if not game.has_method(&"find_closest_enemy"):
		return
	var target: Node2D = game.find_closest_enemy(player.global_position, get_range())
	if target == null:
		return
	var dir := (target.global_position - player.global_position).normalized()
	if dir.length_squared() < 0.0001:
		return
	var proj := PROJECTILE_SCENE.instantiate()
	proj.global_position = player.global_position
	proj.direction = dir
	proj.damage = get_damage()
	proj.max_distance = get_range() * 1.25
	game.projectiles.add_child(proj)
