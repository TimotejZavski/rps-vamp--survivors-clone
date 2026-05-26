extends Weapon
## Axe + Candelabrador (Area) evolution: 8 axes shoot outward from the player
## in every cardinal + diagonal direction each cast - no gravity, like a star
## of axe projectiles using the wand projectile scene with the axe icon.

const PROJECTILE_SCENE := preload("res://scenes/game/Projectile.tscn")
const ICON := "res://assets/evo/Sprite-Death_Spiral.png"

const _DIRECTIONS: Array = [
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071),
	Vector2(0.7071, -0.7071), Vector2(-0.7071, -0.7071),
]


func _init() -> void:
	id = "death_spiral"
	display_name = "Death Spiral"
	icon_path = ICON


func get_cooldown() -> float:
	return maxf(0.45, 1.5 - float(level - 1) * 0.08 + cd_bonus)


func get_damage() -> int:
	return 38 + (level - 1) * 9 + dmg_bonus


func get_range() -> float:
	return 360.0 + float(level - 1) * 20.0 + range_bonus


func _fire(game: Node, player: Node2D) -> void:
	var icon_tex := Weapon.load_icon(ICON)
	for dir in _DIRECTIONS:
		var p := PROJECTILE_SCENE.instantiate()
		p.sprite_icon = icon_tex
		p.icon_target_height = 22.0
		p.global_position = player.global_position
		p.direction = dir
		p.damage = get_damage()
		p.max_distance = get_range()
		game.projectiles.add_child(p)
