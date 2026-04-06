extends Node

enum FlowState {
	MAIN_MENU,
	GAME,
	GAME_OVER
}

const MAIN_MENU_SCENE := preload("res://scenes/ui/MainMenu.tscn")
const GAME_SCENE := preload("res://scenes/game/Game.tscn")
const GAME_OVER_SCENE := preload("res://scenes/ui/GameOver.tscn")

@onready var screen_root: Node = $ScreenRoot

var _current_screen: Node


func _ready() -> void:
	_change_state(FlowState.MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _current_screen and _current_screen.has_method("on_pause_requested"):
		_current_screen.call("on_pause_requested")


func _change_state(state: FlowState) -> void:
	if is_instance_valid(_current_screen):
		_current_screen.queue_free()

	match state:
		FlowState.MAIN_MENU:
			_current_screen = MAIN_MENU_SCENE.instantiate()
			_current_screen.start_requested.connect(_on_start_requested)
			_current_screen.quit_requested.connect(_on_quit_requested)
		FlowState.GAME:
			_current_screen = GAME_SCENE.instantiate()
			_current_screen.game_over_requested.connect(_on_game_over_requested)
		FlowState.GAME_OVER:
			_current_screen = GAME_OVER_SCENE.instantiate()
			_current_screen.retry_requested.connect(_on_retry_requested)
			_current_screen.main_menu_requested.connect(_on_main_menu_requested)

	screen_root.add_child(_current_screen)


func _on_start_requested() -> void:
	_change_state(FlowState.GAME)


func _on_quit_requested() -> void:
	get_tree().quit()


func _on_game_over_requested() -> void:
	_change_state(FlowState.GAME_OVER)


func _on_retry_requested() -> void:
	_change_state(FlowState.GAME)


func _on_main_menu_requested() -> void:
	_change_state(FlowState.MAIN_MENU)
