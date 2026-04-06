extends Control

signal start_requested
signal quit_requested


func _on_start_button_pressed() -> void:
	start_requested.emit()


func _on_quit_button_pressed() -> void:
	quit_requested.emit()
