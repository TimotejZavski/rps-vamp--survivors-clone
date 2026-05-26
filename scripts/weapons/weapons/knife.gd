extends Weapon
## Fires fast in the player's facing direction. Single straight projectile.

const PROJECTILE_SCENE := preload("res://scenes/game/Projectile.tscn")
const ICON := "res://assets/icons/Sprite-Knife.png"


func _init() -> void:
	id = "knife"
	display_name = "Knife"
	icon_path = ICON


func get_cooldown() -> float:
	return maxf(0.16, 0.55 - float(level - 1) * 0.045 + cd_bonus)


func get_damage() -> int:
	return 14 + (level - 1) * 4 + dmg_bonus


func get_range() -> float:
	return 380.0 + float(level - 1) * 14.0 + range_bonus


func _fire(game: Node, player: Node2D) -> void:
	var dir := Vector2.RIGHT
	if player.has_method(&"get_weapon_aim_direction"):
		dir = player.get_weapon_aim_direction()
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	var proj := PROJECTILE_SCENE.instantiate()
	proj.sprite_icon = Weapon.load_icon(ICON)
	proj.icon_target_height = 14.0
	proj.global_position = player.global_position
	proj.direction = dir.normalized()
	proj.damage = get_damage()
	proj.max_distance = get_range()
	game.projectiles.add_child(proj)
