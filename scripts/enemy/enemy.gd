extends CharacterBody2D

signal died(spawn_position: Vector2)

var target: Node2D

@export var move_speed := 58.0
@export var max_health := 32

## Matches Player.tscn rect half-extent + Enemy.tscn rect half-extent (7 + 7).
const _PLAYER_HALF := 7.0
const _SELF_HALF := 7.0

## Frames extracted from wiki GIFs (CC BY-NC-SA 3.0): fly `Animated-Pipeestrello-3.gif`, death `Animated-Pipeestrello-3_(death).gif` — https://vampire.survivors.wiki/w/Pipeestrello
const _BAT_FRAMES_ROOT := "res://assets/enemies/pipeestrello_3/"
const _FLY_FRAME_DURATION := 0.28
const _DEATH_FRAME_DURATION := 0.16
## World-space height (~27px native bat); keep near enemy footprint.
const _BAT_TARGET_HEIGHT_UNITS := 14.0

@onready var _sprite: AnimatedSprite2D = $BatSprite

## Brief whitewash on the sprite when damaged. Real luminance-shift (not just
## modulate), so even already-bright pixels go full white for the flash.
const HIT_FLASH_DURATION := 0.12
const _HIT_SHADER_CODE := "shader_type canvas_item;\nuniform float flash : hint_range(0.0, 1.0) = 0.0;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tc.rgb = mix(c.rgb, vec3(1.0), flash);\n\tCOLOR = c;\n}\n"
static var _hit_shader: Shader

var _health: int
var _dying := false
var _death_spawn_position: Vector2
var _hit_flash_t: float = 0.0


func _ready() -> void:
	add_to_group("enemy")
	_health = max_health
	_sprite.sprite_frames = _build_bat_sprite_frames()
	var tex: Texture2D = _sprite.sprite_frames.get_frame_texture(&"fly", 0)
	if tex != null:
		var h: float = float(tex.get_size().y)
		if h > 0.0:
			_sprite.scale = Vector2(_BAT_TARGET_HEIGHT_UNITS / h, _BAT_TARGET_HEIGHT_UNITS / h)
	_sprite.play(&"fly")
	_sprite.animation_finished.connect(_on_sprite_animation_finished)
	_install_hit_material()


func _install_hit_material() -> void:
	if _hit_shader == null:
		_hit_shader = Shader.new()
		_hit_shader.code = _HIT_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _hit_shader
	mat.set_shader_parameter(&"flash", 0.0)
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

	if not is_instance_valid(target):
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
		_sprite.flip_h = velocity.x < 0.0

	edx = global_position.x - target.global_position.x
	edy = global_position.y - target.global_position.y
	if _aabb_overlap(edx, edy, min_sep_x, min_sep_y):
		_separate_from_target(edx, edy, min_sep_x, min_sep_y)


func _build_bat_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation(&"fly")
	sf.set_animation_loop(&"fly", true)
	var i := 0
	while true:
		var path := _BAT_FRAMES_ROOT + ("fly_%02d.png" % i)
		if not FileAccess.file_exists(path):
			break
		var img := Image.new()
		if img.load(path) != OK:
			break
		sf.add_frame(&"fly", ImageTexture.create_from_image(img), _FLY_FRAME_DURATION)
		i += 1
	sf.add_animation(&"death")
	sf.set_animation_loop(&"death", false)
	i = 0
	while true:
		var path := _BAT_FRAMES_ROOT + ("death_%02d.png" % i)
		if not FileAccess.file_exists(path):
			break
		var img := Image.new()
		if img.load(path) != OK:
			break
		sf.add_frame(&"death", ImageTexture.create_from_image(img), _DEATH_FRAME_DURATION)
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
