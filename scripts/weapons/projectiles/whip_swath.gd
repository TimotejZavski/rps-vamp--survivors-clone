extends Area2D
## Brief horizontal swath; pierces every enemy it touches once, then fades.

var damage: int = 22
var lifetime: float = 0.18

var _hit_ids: Dictionary = {}
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	z_index = 34
	body_entered.connect(_on_body_entered)
	# body_entered won't fire for bodies already overlapping at spawn -
	# scan them once on the next physics frame.
	call_deferred(&"_initial_overlap_scan")


func _initial_overlap_scan() -> void:
	for b in get_overlapping_bodies():
		_on_body_entered(b)


func _physics_process(delta: float) -> void:
	_t += delta
	modulate.a = clampf(1.0 - (_t / lifetime), 0.0, 1.0)
	if _t >= lifetime:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("enemy") or not body.has_method(&"take_damage"):
		return
	var iid: int = body.get_instance_id()
	if _hit_ids.has(iid):
		return
	_hit_ids[iid] = true
	body.take_damage(damage)
