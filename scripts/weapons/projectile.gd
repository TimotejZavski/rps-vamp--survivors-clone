extends Area2D
## Generic straight-line projectile. Hits the first enemy it overlaps and despawns.

const SPEED := 520.0

var direction: Vector2 = Vector2.RIGHT
var damage: int = 1
var max_distance: float = 300.0
## Optional: if set, the default polygon visuals (Core/Glow/TrailNear/TrailFar)
## are hidden and a Sprite2D with this texture is shown instead.
var sprite_icon: Texture2D = null
var icon_target_height: float = 16.0

var _traveled: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()
	if sprite_icon != null:
		_swap_to_icon()


func _swap_to_icon() -> void:
	for child in get_children():
		if child is Polygon2D:
			child.visible = false
	var spr := Sprite2D.new()
	spr.texture = sprite_icon
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var h := float(sprite_icon.get_height())
	if h > 0.0:
		spr.scale = Vector2.ONE * (icon_target_height / h)
	add_child(spr)


func _physics_process(delta: float) -> void:
	var step := direction * SPEED * delta
	global_position += step
	_traveled += step.length()
	if _traveled >= max_distance:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy") and body.has_method(&"take_damage"):
		body.take_damage(damage)
		queue_free()
