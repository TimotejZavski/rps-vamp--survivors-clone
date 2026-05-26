extends Weapon
## Brief horizontal slash to the player's facing side. Pierces enemies in its path.
## At level 3+ also lashes the opposite side simultaneously.

const SWATH_SCRIPT := preload("res://scripts/weapons/projectiles/whip_swath.gd")
const ICON := "res://assets/icons/Sprite-Whip.png"

## Visual + behavior knobs so the Bloody Tear evolution can reuse the firing
## logic with a red palette and lifesteal.
var core_color: Color = Color(1.0, 0.97, 0.88, 0.85)
var glow_color: Color = Color(1.0, 0.75, 0.5, 0.4)
var lifesteal_fraction: float = 0.0


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
	area.set("lifesteal_fraction", lifesteal_fraction)
	area.set("player_ref", player)
	area.collision_layer = 0
	area.collision_mask = 2
	area.z_index = 34

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, 16)
	shape.shape = rect
	area.add_child(shape)

	# Pixel-art whip: a chain of discrete tapered segments from the player
	# outward. The base segments are tall, the tip segments are thin - reads
	# as a cracked whip rather than a soft thunderbolt glow.
	var segments: int = 9
	var gap: float = 2.0
	var seg_len: float = (length - gap * float(segments - 1)) / float(segments)
	for i in segments:
		var t: float = float(i) / float(segments - 1)
		var thick: float = lerpf(6.0, 1.0, t)
		var x0: float = -half + float(i) * (seg_len + gap)
		var x1: float = x0 + seg_len
		var seg := Polygon2D.new()
		# Tip segments lean toward the glow color for a hot-tip look.
		seg.color = core_color.lerp(glow_color, t * 0.55)
		seg.polygon = PackedVector2Array([
			Vector2(x0, -thick), Vector2(x1, -thick),
			Vector2(x1, thick),  Vector2(x0, thick),
		])
		area.add_child(seg)

	var sign_dir: float = -1.0 if face_left else 1.0
	area.global_position = player.global_position + Vector2(sign_dir * half, 0)
	if face_left:
		area.scale.x = -1.0
	game.projectiles.add_child(area)
