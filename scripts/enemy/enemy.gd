extends CharacterBody2D
## Generic enemy. The spawner configures the visual + stat exports before
## the node enters the tree; this script handles walk/chase, contact, hit
## flash, and death animation for every enemy variant.

signal died(spawn_position: Vector2)

var target: Node2D

@export var move_speed := 58.0
@export var max_health := 32

## Where to load the per-frame PNGs from. Each enemy folder contains
## "<walk_frame_prefix>_NN.png" and "<death_frame_prefix>_NN.png" series.
@export var frames_root: String = "res://assets/enemies/pipeestrello_3/"
@export var walk_frame_prefix: String = "fly"
@export var death_frame_prefix: String = "death"
@export var target_height: float = 14.0
@export var walk_frame_duration: float = 0.28
@export var death_frame_duration: float = 0.16
## Stationary enemies (e.g. flower wall) don't chase the player.
@export var stationary: bool = false
## When false, the game's far-from-player despawn pass skips this enemy
## (used for bosses so they can't be lost by walking away).
@export var cullable: bool = true
## True if the source frames already face right (like the bat). For sprites
## that face left by default (skeleton, mudmen, batboss, flowerwall) the flip
## direction is inverted so they don't moonwalk.
@export var sprite_default_faces_right: bool = false
## Elite variant: gets a blue outline + the spawner doubles its HP.
@export var is_elite: bool = false

## Player and self half-extents are shared - keeps contact AABB symmetric.
const _PLAYER_HALF := 7.0
const _SELF_HALF := 7.0

## Brief whitewash on the sprite when damaged + optional outline (used for
## elites). Single shader so both effects share one material per enemy.
const HIT_FLASH_DURATION := 0.12
const ELITE_OUTLINE_COLOR := Color(0.35, 0.7, 1.0, 1.0)
const ELITE_OUTLINE_THICKNESS := 1.5
const _HIT_SHADER_CODE := "shader_type canvas_item;\nuniform float flash : hint_range(0.0, 1.0) = 0.0;\nuniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);\nuniform float outline_thickness : hint_range(0.0, 8.0) = 0.0;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tif (outline_color.a > 0.001 && outline_thickness > 0.001 && c.a < 0.1) {\n\t\tvec2 px = TEXTURE_PIXEL_SIZE * outline_thickness;\n\t\tfloat n = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV + vec2(-px.x, 0.0)).a + texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV + vec2(0.0, -px.y)).a;\n\t\tif (n > 0.0) { COLOR = outline_color; return; }\n\t}\n\tc.rgb = mix(c.rgb, vec3(1.0), flash);\n\tCOLOR = c;\n}\n"
static var _hit_shader: Shader

@onready var _sprite: AnimatedSprite2D = $Sprite

var _health: int
var _dying := false
var _death_spawn_position: Vector2
var _hit_flash_t: float = 0.0


func _ready() -> void:
	add_to_group("enemy")
	_health = max_health
	_sprite.sprite_frames = _build_sprite_frames()
	var tex: Texture2D = _sprite.sprite_frames.get_frame_texture(&"walk", 0)
	if tex != null:
		var h: float = float(tex.get_size().y)
		if h > 0.0:
			_sprite.scale = Vector2(target_height / h, target_height / h)
	_sprite.play(&"walk")
	_sprite.animation_finished.connect(_on_sprite_animation_finished)
	_install_hit_material()


func _install_hit_material() -> void:
	if _hit_shader == null:
		_hit_shader = Shader.new()
		_hit_shader.code = _HIT_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _hit_shader
	mat.set_shader_parameter(&"flash", 0.0)
	if is_elite:
		mat.set_shader_parameter(&"outline_color", ELITE_OUTLINE_COLOR)
		mat.set_shader_parameter(&"outline_thickness", ELITE_OUTLINE_THICKNESS)
	else:
		mat.set_shader_parameter(&"outline_color", Color(0, 0, 0, 0))
		mat.set_shader_parameter(&"outline_thickness", 0.0)
	_sprite.material = mat


func _set_flash(amount: float) -> void:
	var mat: ShaderMaterial = _sprite.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(&"flash", clampf(amount, 0.0, 1.0))


func take_damage(amount: int) -> void:
	if amount <= 0 or _health <= 0 or _dying:
		return
	_health -= amount
	_hit_flash_t = HIT_FLASH_DURATION
	_set_flash(1.0)
	if _health <= 0:
		_begin_death()


func _begin_death() -> void:
	_dying = true
	_death_spawn_position = global_position
	collision_layer = 0
	velocity = Vector2.ZERO
	_sprite.play(&"death")


func _on_sprite_animation_finished() -> void:
	if _sprite.animation == &"death":
		died.emit(_death_spawn_position)
		queue_free()


func _physics_process(_delta: float) -> void:
	if _hit_flash_t > 0.0:
		_hit_flash_t -= _delta
		_set_flash(_hit_flash_t / HIT_FLASH_DURATION)
		if _hit_flash_t <= 0.0:
			_set_flash(0.0)

	if _dying:
		move_and_slide()
		return

	if stationary or not is_instance_valid(target):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var min_sep_x := _PLAYER_HALF + _SELF_HALF
	var min_sep_y := _PLAYER_HALF + _SELF_HALF
	var edx := global_position.x - target.global_position.x
	var edy := global_position.y - target.global_position.y
	var to_player := target.global_position - global_position

	if _aabb_overlap(edx, edy, min_sep_x, min_sep_y):
		velocity = Vector2.ZERO
	else:
		if to_player.length_squared() > 0.0001:
			velocity = to_player.normalized() * move_speed
		else:
			velocity = Vector2.ZERO

	move_and_slide()

	if absf(velocity.x) > 2.0:
		var moving_left: bool = velocity.x < 0.0
		# If the source sprite faces right by default we flip when moving left;
		# if it faces left by default we flip when moving right.
		_sprite.flip_h = moving_left if sprite_default_faces_right else not moving_left

	edx = global_position.x - target.global_position.x
	edy = global_position.y - target.global_position.y
	if _aabb_overlap(edx, edy, min_sep_x, min_sep_y):
		_separate_from_target(edx, edy, min_sep_x, min_sep_y)


func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation(&"walk")
	sf.set_animation_loop(&"walk", true)
	var i := 0
	while true:
		var path: String = frames_root + ("%s_%02d.png" % [walk_frame_prefix, i])
		if not FileAccess.file_exists(path):
			break
		var img := Image.new()
		if img.load(path) != OK:
			break
		sf.add_frame(&"walk", ImageTexture.create_from_image(img), walk_frame_duration)
		i += 1
	sf.add_animation(&"death")
	sf.set_animation_loop(&"death", false)
	i = 0
	while true:
		var path: String = frames_root + ("%s_%02d.png" % [death_frame_prefix, i])
		if not FileAccess.file_exists(path):
			break
		var img := Image.new()
		if img.load(path) != OK:
			break
		sf.add_frame(&"death", ImageTexture.create_from_image(img), death_frame_duration)
		i += 1
	return sf


func _aabb_overlap(edx: float, edy: float, min_x: float, min_y: float) -> bool:
	return absf(edx) < min_x and absf(edy) < min_y


func _separate_from_target(edx: float, edy: float, min_x: float, min_y: float) -> void:
	var pen_x := min_x - absf(edx)
	var pen_y := min_y - absf(edy)
	if pen_x <= 0.0 or pen_y <= 0.0:
		return
	if pen_x < pen_y:
		global_position.x += signf(edx) * pen_x
	else:
		global_position.y += signf(edy) * pen_y
