extends Area2D
## Gold pickup. Drifts toward the player when nearby (VS-style magnet) and
## adds to the run's gold counter on contact.

signal collected(value: int)

const ICON_PATH := "res://assets/icons/24px-Sprite-Gold_Coin.png"
const TARGET_HEIGHT := 12.0
const MAGNET_RADIUS := 70.0
const MAGNET_SPEED := 320.0

static var _shared_tex: Texture2D = null

var value: int = 1
var _player: Node2D = null


func _ready() -> void:
	if _shared_tex == null:
		var img := Image.new()
		if img.load(ICON_PATH) == OK:
			_shared_tex = ImageTexture.create_from_image(img)
	var s: Sprite2D = $Sprite2D
	if _shared_tex != null:
		s.texture = _shared_tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var h: float = float(_shared_tex.get_height())
		if h > 0.0:
			s.scale = Vector2.ONE * (TARGET_HEIGHT / h)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
		if _player == null:
			return
	var to_player: Vector2 = _player.global_position - global_position
	if to_player.length_squared() < MAGNET_RADIUS * MAGNET_RADIUS:
		global_position += to_player.normalized() * MAGNET_SPEED * delta


func _on_body_entered(body: Node) -> void:
	if body.is_in_group(&"player"):
		collected.emit(value)
		queue_free()
