extends Control

signal game_over_requested

@onready var timer_label: Label = $CenterContainer/VBoxContainer/TimeLabel

var _elapsed_seconds := 0.0


func _process(delta: float) -> void:
	_elapsed_seconds += delta
	timer_label.text = "Time: %.1f" % _elapsed_seconds


func _on_end_run_button_pressed() -> void:
	game_over_requested.emit()


func _on_pause_requested() -> void:
	game_over_requested.emit()
