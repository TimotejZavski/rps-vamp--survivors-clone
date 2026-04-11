extends CharacterBody2D

signal health_changed(new_health: int, max_health: int)
signal died

@export var move_speed := 220.0
@export var dash_speed := 420.0
@export var dash_duration := 0.18
@export var max_health := 100

var current_health := max_health
var _dash_time_left := 0.0
var _last_move_dir := Vector2.DOWN
var _is_dead := false


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		_last_move_dir = input_dir.normalized()

	if Input.is_action_just_pressed("dash"):
		_dash_time_left = dash_duration

	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		velocity = _last_move_dir * dash_speed
	else:
		velocity = input_dir * move_speed

	move_and_slide()


func take_damage(amount: int) -> void:
	if _is_dead:
		return

	current_health -= amount
	if current_health < 0:
		current_health = 0

	health_changed.emit(current_health, max_health)

	if current_health == 0:
		_die()


func heal(amount: int) -> void:
	if _is_dead:
		return

	current_health += amount
	if current_health > max_health:
		current_health = max_health

	health_changed.emit(current_health, max_health)


func _die() -> void:
	_is_dead = true
	died.emit()
