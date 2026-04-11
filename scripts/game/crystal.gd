extends Area2D

signal collected

const GEM_PATH := "res://assets/pickups/experience_gem.png"
const GEM_DISPLAY_SCALE := Vector2(0.125, 0.125)

static var _shared_gem_texture: Texture2D


func _ready() -> void:
	if _shared_gem_texture == null:
		var img := Image.new()
		if img.load(GEM_PATH) == OK:
			_shared_gem_texture = ImageTexture.create_from_image(img)
	var sprite: Sprite2D = $Sprite2D
	sprite.texture = _shared_gem_texture
	sprite.scale = GEM_DISPLAY_SCALE
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collected.emit()
		queue_free()
