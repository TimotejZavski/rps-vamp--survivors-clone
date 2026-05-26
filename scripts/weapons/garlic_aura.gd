extends Node2D
## Stacked concentric translucent rings, dark green, slowly pulsing.
## Built from a layered set of disks so the outer edges naturally fade rather
## than ending at a single visible polygon edge.

@export var base_radius: float = 64.0
## External scale (driven by the weapon's get_range()/BASE_VISUAL_RADIUS).
@export var range_scale: float = 1.0
@export var pulse_rate: float = 1.6
@export var pulse_amount: float = 0.07
## Color of the aura; defaults to deep blue. Overridden to red on evolution.
@export var tint: Color = Color(0.18, 0.38, 0.95)
## Each entry: relative radius (0..1) and alpha. Inner layers are denser; the
## outermost layer is nearly transparent so its polygon boundary disappears
## against the ground instead of reading as a hard ring.
const LAYERS := [
	{ "r": 1.00, "a": 0.05 },
	{ "r": 0.90, "a": 0.08 },
	{ "r": 0.78, "a": 0.11 },
	{ "r": 0.65, "a": 0.15 },
	{ "r": 0.50, "a": 0.19 },
	{ "r": 0.34, "a": 0.24 },
	{ "r": 0.18, "a": 0.28 },
]

var _t: float = 0.0


func _ready() -> void:
	_build_rings()


func _process(delta: float) -> void:
	_t += delta
	var pulse: float = 1.0 + sin(_t * pulse_rate) * pulse_amount
	scale = Vector2.ONE * (range_scale * pulse)


func _build_rings() -> void:
	for layer in LAYERS:
		var poly := Polygon2D.new()
		var col := tint
		col.a = float(layer["a"])
		poly.color = col
		poly.polygon = _ring_verts(base_radius * float(layer["r"]), 40)
		add_child(poly)


func set_tint(new_tint: Color) -> void:
	tint = new_tint
	# Rebuild rings if already in-tree.
	for c in get_children():
		c.queue_free()
	if is_inside_tree():
		_build_rings()


func _ring_verts(radius: float, segments: int) -> PackedVector2Array:
	var verts := PackedVector2Array()
	for i in segments:
		var a: float = float(i) / float(segments) * TAU
		verts.append(Vector2(cos(a), sin(a)) * radius)
	return verts
