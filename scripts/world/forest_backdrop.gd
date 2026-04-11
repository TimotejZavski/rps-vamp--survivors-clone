extends Node2D
## Solid forest floor colour behind chunks so the viewport never shows empty grey.


func _ready() -> void:
	z_index = -200
	z_as_relative = false
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-160000, -160000, 320000, 320000), Color(0.14, 0.34, 0.2))
