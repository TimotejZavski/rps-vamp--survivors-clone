extends Control
## Draws edge-of-screen arrows pointing toward important off-screen targets:
## treasure chests (gold) and the boss (red). Targets that are already visible
## get no arrow. Lives on the HUD CanvasLayer and reads world positions through
## the viewport canvas transform.

const CHEST_COLOR := Color(1.0, 0.85, 0.32, 0.95)
const BOSS_COLOR := Color(0.96, 0.32, 0.30, 0.98)
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.65)
const EDGE_MARGIN := 40.0
const ARROW_LEN := 22.0
const ARROW_WIDTH := 18.0

var _player: Node2D = null


func _process(_delta: float) -> void:
	queue_redraw()


func _get_player() -> Node2D:
	if is_instance_valid(_player):
		return _player
	_player = get_tree().get_first_node_in_group("player") as Node2D
	return _player


func _draw() -> void:
	if _get_player() == null:
		return
	var xform := get_viewport().get_canvas_transform()
	var rect := Rect2(Vector2(EDGE_MARGIN, EDGE_MARGIN), size - Vector2(EDGE_MARGIN * 2.0, EDGE_MARGIN * 2.0))
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var center := size * 0.5

	for c in get_tree().get_nodes_in_group("chest"):
		if c is Node2D:
			_draw_indicator((c as Node2D).global_position, xform, rect, center, CHEST_COLOR)
	for b in get_tree().get_nodes_in_group("boss"):
		if b is Node2D:
			_draw_indicator((b as Node2D).global_position, xform, rect, center, BOSS_COLOR)


func _draw_indicator(world_pos: Vector2, xform: Transform2D, rect: Rect2, center: Vector2, color: Color) -> void:
	var screen_pos := xform * world_pos
	# Visible on screen already -> no arrow needed.
	if rect.has_point(screen_pos):
		return
	var dir := screen_pos - center
	if dir.length_squared() < 1.0:
		return
	dir = dir.normalized()
	var edge := _ray_to_rect_edge(center, dir, rect)
	_draw_arrow(edge, dir, color)


## Returns the point where the ray from `center` in `dir` first crosses the
## boundary of `rect` (center is assumed inside the rect).
func _ray_to_rect_edge(center: Vector2, dir: Vector2, rect: Rect2) -> Vector2:
	var t := INF
	if dir.x > 0.0001:
		t = minf(t, (rect.position.x + rect.size.x - center.x) / dir.x)
	elif dir.x < -0.0001:
		t = minf(t, (rect.position.x - center.x) / dir.x)
	if dir.y > 0.0001:
		t = minf(t, (rect.position.y + rect.size.y - center.y) / dir.y)
	elif dir.y < -0.0001:
		t = minf(t, (rect.position.y - center.y) / dir.y)
	if t == INF:
		return center
	return center + dir * t


func _draw_arrow(pos: Vector2, dir: Vector2, color: Color) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var tip := pos + dir * ARROW_LEN * 0.6
	var base_a := pos - dir * ARROW_LEN * 0.4 + perp * ARROW_WIDTH * 0.5
	var base_b := pos - dir * ARROW_LEN * 0.4 - perp * ARROW_WIDTH * 0.5
	var tri := PackedVector2Array([tip, base_a, base_b])
	draw_colored_polygon(tri, color)
	draw_polyline(PackedVector2Array([tip, base_a, base_b, tip]), OUTLINE_COLOR, 2.0)
