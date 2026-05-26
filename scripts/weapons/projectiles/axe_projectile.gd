extends Area2D
## Falls from above. Pierces enemies, each hit once, until lifetime expires.

const ICON_PATH := "res://assets/icons/Sprite-Axe.png"
const ICON_TARGET_HEIGHT := 32.0

var damage: int = 30
var fall_speed: float = 360.0
var spin_speed: float = 6.0
var lifetime: float = 2.4

var _hit_ids: Dictionary = {}
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	z_index = 35
	_build_visuals()
	body_entered.connect(_on_body_entered)


func _build_visuals() -> void:
	var shape := CollisionShape2D.new()
	var cs := CircleShape2D.new()
	cs.radius = 10.0
	shape.shape = cs
	add_child(shape)

	var tex := Weapon.load_icon(ICON_PATH)
	if tex != null:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var h := float(tex.get_height())
		if h > 0.0:
			spr.scale = Vector2.ONE * (ICON_TARGET_HEIGHT / h)
		add_child(spr)


func _physics_process(delta: float) -> void:
	global_position.y += fall_speed * delta
	rotation += spin_speed * delta
	_t += delta
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
