extends CharacterBody2D

@export var speed := 120.0
@export var damage := 10
@export var attack_cooldown := 1.0
@export var attack_range := 150.0

## Set by spawner; if unset, resolves the player from the "player" group (same as placing one enemy in-editor).
var target: Node2D

var _attack_timer := 0.0


func _resolve_aim() -> Node2D:
	if is_instance_valid(target):
		return target
	return get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	var aim := _resolve_aim()
	if aim == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction := aim.global_position - global_position
	if direction != Vector2.ZERO:
		velocity = direction.normalized() * speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	_attack_timer -= delta

	var dist := global_position.distance_to(aim.global_position)
	if dist < attack_range and _attack_timer <= 0.0:
		if aim.has_method("take_damage"):
			aim.take_damage(damage)
		_attack_timer = attack_cooldown
