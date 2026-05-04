extends Control

signal retry_requested
signal main_menu_requested

@onready var _stats_label: Label = $CenterContainer/VBoxContainer/StatsLabel
@onready var _retry_button: Button = $CenterContainer/VBoxContainer/RetryButton


func _ready() -> void:
	var t := RunConfig.last_run_time_seconds
	var s := int(floor(t))
	var m := s / 60
	s %= 60
	_stats_label.text = "Time %d:%02d  -  Level %d  -  Enemies %d" % [
		m,
		s,
		RunConfig.last_run_level,
		RunConfig.last_run_kills,
	]
	_retry_button.grab_focus()


func _on_retry_button_pressed() -> void:
	retry_requested.emit()


func _on_main_menu_button_pressed() -> void:
	main_menu_requested.emit()
