extends Area2D
## Projectile fired by bosses. Travels in a straight line and damages the player
## on contact. Built entirely in code so no scene file is required.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 135.0
var damage: int = 16
var max_distance: float = 900.0

var _traveled: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # player physics layer
	monitoring = true
	z_index = 35
	z_as_relative = false
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()
	_build_visual()


func _build_visual() -> void:
	var glow := Polygon2D.new()
	glow.color = Color(1.0, 0.5, 0.6, 0.32)
	glow.polygon = PackedVector2Array([Vector2(0, -9), Vector2(9, 0), Vector2(0, 9), Vector2(-9, 0)])
	add_child(glow)

	var core := Polygon2D.new()
	core.color = Color(0.96, 0.28, 0.5, 0.96)
	core.polygon = PackedVector2Array([Vector2(0, -5), Vector2(5, 0), Vector2(0, 5), Vector2(-5, 0)])
	add_child(core)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float) -> void:
	var step := direction * speed * delta
	global_position += step
	_traveled += step.length()
	if _traveled >= max_distance:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method(&"take_damage"):
		body.take_damage(damage)
		queue_free()
