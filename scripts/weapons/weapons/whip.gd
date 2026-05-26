extends Weapon
## Brief horizontal slash to the player's facing side. Pierces enemies in its path.
## At level 3+ also lashes the opposite side simultaneously.

const SWATH_SCRIPT := preload("res://scripts/weapons/projectiles/whip_swath.gd")
const ICON := "res://assets/icons/Sprite-Whip.png"


func _init() -> void:
	id = "whip"
	display_name = "Whip"
	icon_path = ICON


func get_cooldown() -> float:
	return maxf(0.55, 1.45 - float(level - 1) * 0.09 + cd_bonus)


func get_damage() -> int:
	return 22 + (level - 1) * 6 + dmg_bonus


func get_range() -> float:
	return 110.0 + float(level - 1) * 10.0 + range_bonus


func _fire(game: Node, player: Node2D) -> void:
	var dir := Vector2.RIGHT
	if player.has_method(&"get_weapon_aim_direction"):
		dir = player.get_weapon_aim_direction()
	var face_left := false
	if absf(dir.x) > 0.01:
		face_left = dir.x < 0.0
	_spawn_swath(game, player, face_left)
	if level >= 3:
		_spawn_swath(game, player, not face_left)


func _spawn_swath(game: Node, player: Node2D, face_left: bool) -> void:
	var length := get_range()
	var half := length * 0.5

	var area := Area2D.new()
	area.set_script(SWATH_SCRIPT)
	area.set("damage", get_damage())
	area.collision_layer = 0
	area.collision_mask = 2
	area.z_index = 34

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, 22)
	shape.shape = rect
	area.add_child(shape)

	var glow := Polygon2D.new()
	glow.color = Color(1.0, 0.75, 0.5, 0.4)
	glow.polygon = PackedVector2Array([
		Vector2(-half, -13), Vector2(half, -13), Vector2(half, 13), Vector2(-half, 13)
	])
	area.add_child(glow)

	var core := Polygon2D.new()
	core.color = Color(1.0, 0.97, 0.88, 0.85)
	core.polygon = PackedVector2Array([
		Vector2(-half, -6), Vector2(half, -6), Vector2(half, 6), Vector2(-half, 6)
	])
	area.add_child(core)

	var sign_dir := -1.0 if face_left else 1.0
	area.global_position = player.global_position + Vector2(sign_dir * half, 0)
	if face_left:
		area.scale.x = -1.0
	game.projectiles.add_child(area)
