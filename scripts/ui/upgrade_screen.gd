extends CanvasLayer

signal acknowledged

var _level: int = 2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"upgrade_screen")
	_apply_level_title()


func set_level(level: int) -> void:
	_level = level
	if is_node_ready():
		_apply_level_title()


func _apply_level_title() -> void:
	var title: Label = $Center/Panel/Margin/VBox/Title
	title.text = "Level %d" % _level
	var hint: Label = $Center/Panel/Margin/VBox/Hint
	hint.text = "Pick an upgrade next (placeholder — choices hook here)."


func _on_continue_pressed() -> void:
	acknowledged.emit()
	queue_free()
