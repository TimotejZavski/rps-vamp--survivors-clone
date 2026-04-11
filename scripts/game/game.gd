extends Node2D

signal game_over_requested

const ARENA_MIN := Vector2(-1100.0, -700.0)
const ARENA_MAX := Vector2(1100.0, 700.0)

@onready var player: CharacterBody2D = $Player
@onready var player_camera: Camera2D = $Player/Camera2D
@onready var health_label: Label = $HUD/TopPanel/HUDMargin/HUDVBox/HealthLabel
@onready var timer_label: Label = $HUD/TopPanel/HUDMargin/HUDVBox/TimeLabel
@onready var attack_flash: Label = $HUD/AttackFlash

var _elapsed_seconds := 0.0
var _attack_flash_time_left := 0.0


func _ready() -> void:
	player_camera.make_current()

	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_player_health_changed)
		var current_health := int(player.get("current_health"))
		var max_health := int(player.get("max_health"))
		_on_player_health_changed(current_health, max_health)

	if player.has_signal("died"):
		player.died.connect(_on_player_died)


func _process(delta: float) -> void:
	_elapsed_seconds += delta
	timer_label.text = "Time: %.1f" % _elapsed_seconds

	if Input.is_action_just_pressed("attack"):
		_attack_flash_time_left = 0.12
		attack_flash.visible = true

	if _attack_flash_time_left > 0.0:
		_attack_flash_time_left -= delta
		if _attack_flash_time_left <= 0.0:
			attack_flash.visible = false

	player.position = player.position.clamp(ARENA_MIN, ARENA_MAX)

	# Privremeni test damage-a dok jos nema pravih enemy napada
	if Input.is_action_just_pressed("ui_accept"):
		if player.has_method("take_damage"):
			player.take_damage(10)


func _on_end_run_button_pressed() -> void:
	game_over_requested.emit()


func _on_pause_requested() -> void:
	game_over_requested.emit()


func _on_player_health_changed(new_health: int, max_health: int) -> void:
	health_label.text = "HP: %d/%d" % [new_health, max_health]


func _on_player_died() -> void:
	game_over_requested.emit()
