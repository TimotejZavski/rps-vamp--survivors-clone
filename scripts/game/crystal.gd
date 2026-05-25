extends Area2D

signal collected(value: int)

const GEM_PATH := "res://assets/pickups/experience_gem.png"
const GEM_DISPLAY_SCALE := Vector2(0.125, 0.125)
## Color/scale presets per tier. 0 = blue (default), 1 = green (merged cluster).
const TIER_VISUALS := {
	0: { "modulate": Color(1, 1, 1, 1), "scale_mult": 1.0 },
	1: { "modulate": Color(0.55, 1.45, 0.6, 1), "scale_mult": 1.45 },
}

static var _shared_gem_texture: Texture2D

var value: int = 1
var tier: int = 0


func _ready() -> void:
	if _shared_gem_texture == null:
		var img := Image.new()
		if img.load(GEM_PATH) == OK:
			_shared_gem_texture = ImageTexture.create_from_image(img)
	var sprite: Sprite2D = $Sprite2D
	sprite.texture = _shared_gem_texture
	_apply_visual()
	body_entered.connect(_on_body_entered)


func set_gem(p_value: int, p_tier: int) -> void:
	value = maxi(1, p_value)
	tier = p_tier
	if is_inside_tree():
		_apply_visual()


func _apply_visual() -> void:
	var sprite: Sprite2D = $Sprite2D
	var preset: Dictionary = TIER_VISUALS.get(tier, TIER_VISUALS[0])
	sprite.modulate = preset["modulate"]
	sprite.scale = GEM_DISPLAY_SCALE * float(preset["scale_mult"])


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collected.emit(value)
		queue_free()
