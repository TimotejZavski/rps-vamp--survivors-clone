extends CharacterBody2D

@export var speed := 120.0
@export var damage := 10
@export var attack_cooldown := 1.0

var player: CharacterBody2D
var _attack_timer := 0.0


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	print("PLAYER FOUND:", player)


func _physics_process(delta: float) -> void:
	if player == null:
		return

	var direction = player.global_position - global_position
	if direction != Vector2.ZERO:
		velocity = direction.normalized() * speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	_attack_timer -= delta

	var dist := global_position.distance_to(player.global_position)
	print("DIST:", dist)

	if dist < 150:
		print("IN RANGE")
		if _attack_timer <= 0.0:
			print("ATTACK")
			if player.has_method("take_damage"):
				player.take_damage(damage)
				print("DAMAGE APPLIED")
			_attack_timer = attack_cooldown
