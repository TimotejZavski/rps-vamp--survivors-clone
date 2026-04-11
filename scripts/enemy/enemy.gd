extends CharacterBody2D

signal died(spawn_position: Vector2)

var target: Node2D

@export var move_speed := 95.0
@export var max_health := 32

## Matches Player.tscn rect half-extent + Enemy.tscn rect half-extent (7 + 7).
const _PLAYER_HALF := 7.0
const _SELF_HALF := 7.0

var _health: int


func _ready() -> void:
	add_to_group("enemy")
	_health = max_health


func take_damage(amount: int) -> void:
	if amount <= 0 or _health <= 0:
		return
	_health -= amount
	if _health <= 0:
		died.emit(global_position)
		queue_free()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var min_sep_x := _PLAYER_HALF + _SELF_HALF
	var min_sep_y := _PLAYER_HALF + _SELF_HALF
	var edx := global_position.x - target.global_position.x
	var edy := global_position.y - target.global_position.y
	var to_player := target.global_position - global_position

	if _aabb_overlap(edx, edy, min_sep_x, min_sep_y):
		velocity = Vector2.ZERO
	else:
		if to_player.length_squared() > 0.0001:
			velocity = to_player.normalized() * move_speed
		else:
			velocity = Vector2.ZERO

	move_and_slide()

	edx = global_position.x - target.global_position.x
	edy = global_position.y - target.global_position.y
	if _aabb_overlap(edx, edy, min_sep_x, min_sep_y):
		_separate_from_target(edx, edy, min_sep_x, min_sep_y)


func _aabb_overlap(edx: float, edy: float, min_x: float, min_y: float) -> bool:
	return absf(edx) < min_x and absf(edy) < min_y


func _separate_from_target(edx: float, edy: float, min_x: float, min_y: float) -> void:
	var pen_x := min_x - absf(edx)
	var pen_y := min_y - absf(edy)
	if pen_x <= 0.0 or pen_y <= 0.0:
		return
	if pen_x < pen_y:
		global_position.x += signf(edx) * pen_x
	else:
		global_position.y += signf(edy) * pen_y
