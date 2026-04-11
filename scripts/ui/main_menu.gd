extends Control

signal start_requested
signal quit_requested


func _ready() -> void:
	var column: VBoxContainer = $BottomMargin/MainColumn/ButtonRow/ButtonColumn
	var base_font: FontFile = column.get_theme_font("font", "Button") as FontFile
	if base_font == null:
		base_font = load("res://fonts/Silkscreen-Bold.ttf") as FontFile
	if base_font == null:
		return
	var f: FontFile = base_font.duplicate(true) as FontFile
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	for child in column.get_children():
		if child is Button:
			(child as Button).add_theme_font_override("font", f)


func _on_start_button_pressed() -> void:
	start_requested.emit()


func _on_quit_button_pressed() -> void:
	quit_requested.emit()
