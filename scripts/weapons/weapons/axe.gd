extends Weapon
## Drops 1+ axes from above the player, falling down through the screen.

const PROJECTILE_SCRIPT := preload("res://scripts/weapons/projectiles/axe_projectile.gd")
const ICON := "res://assets/icons/Sprite-Axe.png"


func _init() -> void:
	id = "axe"
	display_name = "Axe"
	icon_path = ICON


func get_cooldown() -> float:
	return maxf(1.0, 2.6 - float(level - 1) * 0.15 + cd_bonus)


func get_damage() -> int:
	return 30 + (level - 1) * 10 + dmg_bonus


func get_range() -> float:
	return 0.0


func get_count() -> int:
	return 1 + (level - 1) / 2  # 1,1,2,2,3,3,4,4


func describe_stats() -> String:
	return "dmg %d  x%d/cast" % [get_damage(), get_count()]


func _fire(game: Node, player: Node2D) -> void:
	var count := get_count()
	for _i in count:
		var axe := Area2D.new()
		axe.set_script(PROJECTILE_SCRIPT)
		axe.set("damage", get_damage())
		var ox := randf_range(-110.0, 110.0)
		axe.global_position = player.global_position + Vector2(ox, -240.0)
		game.projectiles.add_child(axe)
