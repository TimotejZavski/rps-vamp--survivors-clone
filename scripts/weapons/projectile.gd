extends Area2D
## Generic straight-line projectile. Hits the first enemy it overlaps and despawns.

const SPEED := 520.0

var direction: Vector2 = Vector2.RIGHT
var damage: int = 1
var max_distance: float = 300.0

var _traveled: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()


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
