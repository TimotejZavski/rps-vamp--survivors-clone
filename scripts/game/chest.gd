extends Area2D
## Rare ground pickup. Collecting it grants a forced weapon level-up
## (or a passive if every owned weapon is already maxed).

signal opened

const ICON_PATH := "res://assets/icons/32px-Sprite-Treasure_Chest.png"
const TARGET_HEIGHT := 22.0


func _ready() -> void:
	add_to_group("chest")
	collision_layer = 0
	collision_mask = 1  # player layer
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_visual()


func _build_visual() -> void:
	var tex := Weapon.load_icon(ICON_PATH)
	if tex == null:
		return
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var h: float = float(tex.get_height())
	if h > 0.0:
		spr.scale = Vector2.ONE * (TARGET_HEIGHT / h)
	add_child(spr)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	opened.emit()
	queue_free()
