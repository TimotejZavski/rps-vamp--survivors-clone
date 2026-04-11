extends CanvasLayer

signal acknowledged


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _on_continue_pressed() -> void:
	acknowledged.emit()
	queue_free()
