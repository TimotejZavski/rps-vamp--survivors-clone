extends Node

enum FlowState {
	MAIN_MENU,
	CHARACTER_SELECT,
	GAME,
	GAME_OVER,
	LEVEL_COMPLETE,
	META_SHOP,
}

const MAIN_MENU_SCENE := preload("res://scenes/ui/MainMenu.tscn")
const CHARACTER_SELECT_SCENE := preload("res://scenes/ui/CharacterSelect.tscn")
const GAME_SCENE := preload("res://scenes/game/Game.tscn")
const GAME_OVER_SCENE := preload("res://scenes/ui/GameOver.tscn")
const LEVEL_COMPLETE_SCENE := preload("res://scenes/ui/LevelComplete.tscn")
const META_SHOP_SCENE := preload("res://scenes/ui/MetaShop.tscn")

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
			_current_screen.meta_requested.connect(_on_meta_requested)
			_current_screen.quit_requested.connect(_on_quit_requested)
		FlowState.CHARACTER_SELECT:
			_current_screen = CHARACTER_SELECT_SCENE.instantiate()
			_current_screen.run_requested.connect(_on_run_requested)
			_current_screen.back_requested.connect(_on_character_back_requested)
		FlowState.GAME:
			_current_screen = GAME_SCENE.instantiate()
			_current_screen.game_over_requested.connect(_on_game_over_requested)
			_current_screen.level_completed_requested.connect(_on_level_completed_requested)
		FlowState.GAME_OVER:
			_current_screen = GAME_OVER_SCENE.instantiate()
			_current_screen.retry_requested.connect(_on_retry_requested)
			_current_screen.main_menu_requested.connect(_on_main_menu_requested)
		FlowState.META_SHOP:
			_current_screen = META_SHOP_SCENE.instantiate()
			_current_screen.back_requested.connect(_on_main_menu_requested)
		FlowState.LEVEL_COMPLETE:
			_current_screen = LEVEL_COMPLETE_SCENE.instantiate()
			_current_screen.main_menu_requested.connect(_on_main_menu_requested)

	screen_root.add_child(_current_screen)


func _on_start_requested() -> void:
	_change_state(FlowState.CHARACTER_SELECT)


func _on_meta_requested() -> void:
	_change_state(FlowState.META_SHOP)


func _on_run_requested(character_id: String) -> void:
	RunConfig.apply_preset(character_id)
	_change_state(FlowState.GAME)


func _on_character_back_requested() -> void:
	_change_state(FlowState.MAIN_MENU)


func _on_quit_requested() -> void:
	get_tree().quit()


func _on_game_over_requested() -> void:
	_change_state(FlowState.GAME_OVER)


func _on_level_completed_requested() -> void:
	_change_state(FlowState.LEVEL_COMPLETE)


func _on_retry_requested() -> void:
	_change_state(FlowState.GAME)


func _on_main_menu_requested() -> void:
	_change_state(FlowState.MAIN_MENU)
