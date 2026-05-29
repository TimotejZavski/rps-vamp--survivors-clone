extends Node2D
## Floating combat-text number. Spawned by an enemy whenever it takes damage,
## drifts upward while fading, then frees itself. Self-contained: builds its own
## Label so no scene file is needed.

var _lifetime: float = 0.6
var _age: float = 0.0
var _velocity: Vector2 = Vector2(0.0, -34.0)
var _label: Label


## amount: number to show. color: text tint. big: larger/longer-lived (crits,
## elite/boss hits).
func setup(amount: int, color: Color = Color(1, 1, 1, 1), big: bool = false) -> void:
	# Rendered in world space (scales with the 2.82x camera zoom), so keep the
	# node small and the font crisp.
	scale = Vector2(0.5, 0.5)

	_label = Label.new()
	_label.text = str(amount)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override(&"font_size", 30 if big else 22)
	_label.add_theme_color_override(&"font_color", color)
	_label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_label.add_theme_constant_override(&"outline_size", 5)
	_label.size = Vector2(160.0, 32.0)
	_label.position = Vector2(-80.0, -16.0)
	add_child(_label)

	# Small horizontal scatter so stacked hits don't perfectly overlap.
	_velocity.x = randf_range(-16.0, 16.0)
	if big:
		_lifetime = 0.85
		_velocity.y = -48.0


func _process(delta: float) -> void:
	_age += delta
	position += _velocity * delta
	# Gentle deceleration so the number "pops" then settles.
	_velocity.y += 42.0 * delta
	modulate.a = clampf(1.0 - _age / _lifetime, 0.0, 1.0)
	if _age >= _lifetime:
		queue_free()
