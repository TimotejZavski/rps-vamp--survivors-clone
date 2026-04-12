extends Node2D

## Small HP bar drawn under the player (world space).

@export var bar_width := 22.0
@export var bar_height := 3.0
## Vertical offset from player origin (positive = below).
@export var offset_y := 13.0

var _current := 0
var _max_hp := 1


func _ready() -> void:
	z_as_relative = false
	z_index = 50
	position = Vector2(0, offset_y)
	var p := get_parent()
	if p and p.has_signal(&"health_changed"):
		p.health_changed.connect(_on_health_changed)
		_current = int(p.get(&"current_health"))
		_max_hp = int(p.get(&"max_health"))
	queue_redraw()


func _on_health_changed(new_health: int, max_health: int) -> void:
	_current = new_health
	_max_hp = max_health
	queue_redraw()


func _draw() -> void:
	var w := bar_width
	var h := bar_height
	var half_w := w * 0.5
	var outline := Rect2(-half_w, -h * 0.5, w, h)
	draw_rect(outline, Color(0.1, 0.09, 0.14, 0.92))
	var ratio := clampf(float(_current) / float(maxi(_max_hp, 1)), 0.0, 1.0)
	var fill := Color(0.26, 0.82, 0.38) if ratio > 0.28 else Color(0.88, 0.26, 0.24)
	if ratio > 0.001:
		draw_rect(Rect2(-half_w, -h * 0.5, w * ratio, h), fill)
	draw_rect(outline, Color(0.42, 0.38, 0.52, 1.0), false, 1.0)
