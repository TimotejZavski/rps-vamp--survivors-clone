extends CharacterBody2D
## Generic enemy. The spawner configures the visual + stat exports before
## the node enters the tree; this script handles walk/chase, contact, hit
## flash, and death animation for every enemy variant.

signal died(spawn_position: Vector2)
## Emitted by bosses on every HP change so the game can drive the boss health bar.
signal health_changed(current: int, maximum: int)

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
## Boss variant: shows a screen health bar (via the game), periodically fires a
## telegraphed projectile volley at the player, and never gets culled.
@export var is_boss: bool = false
@export var boss_name: String = "Boss"

## Boss ranged attack: every BOSS_ATTACK_INTERVAL seconds it briefly telegraphs
## (pulses red), then fires a fan of projectiles toward the player.
const BOSS_ATTACK_INTERVAL := 3.2
const BOSS_TELEGRAPH_TIME := 0.6
const BOSS_VOLLEY_COUNT := 5
const BOSS_VOLLEY_SPREAD_DEG := 42.0
const BOSS_PROJECTILE_DAMAGE := 16
const _BOSS_PROJECTILE := preload("res://scripts/enemy/boss_projectile.gd")

## Set by the spawner for bosses: the Node2D that boss projectiles are added to
## (the game's Projectiles layer, which is never culled).
var projectile_layer: Node2D = null

var _boss_attack_t: float = 2.0
var _boss_telegraphing: bool = false
var _boss_telegraph_t: float = 0.0

## Player and self half-extents are shared - keeps contact AABB symmetric.
const _PLAYER_HALF := 7.0
const _SELF_HALF := 7.0

## Brief whitewash on the sprite when damaged + optional outline (used for
## elites). Single shader so both effects share one material per enemy.
const HIT_FLASH_DURATION := 0.12
const ELITE_OUTLINE_COLOR := Color(0.35, 0.7, 1.0, 1.0)
const ELITE_OUTLINE_THICKNESS := 1.5
## File-based shader so the renderer compiles it at import time. Inline
## Shader.new()+code assignment was hitting "Parameter 'version' is null"
## warnings on AnimatedSprite2D and the flash never appeared.
const _HIT_SHADER := preload("res://shaders/enemy_hit.gdshader")
const _DAMAGE_NUMBER := preload("res://scripts/game/damage_number.gd")

const _DMG_COLOR_NORMAL := Color(1.0, 1.0, 1.0, 1.0)
const _DMG_COLOR_ELITE := Color(0.55, 0.78, 1.0, 1.0)
const _DMG_COLOR_BOSS := Color(1.0, 0.62, 0.32, 1.0)

## Set by the spawner: the world-space Node2D that floating damage numbers are
## parented to (kept out of the enemy so numbers survive the enemy's death).
var floating_text_layer: Node2D = null

@onready var _sprite: AnimatedSprite2D = $Sprite

var _health: int
var _dying := false
var _death_spawn_position: Vector2
var _hit_flash_t: float = 0.0


func _ready() -> void:
	add_to_group("enemy")
	if is_boss:
		add_to_group("boss")
	_health = max_health
	if is_boss:
		health_changed.emit(_health, max_health)
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
	var mat := ShaderMaterial.new()
	mat.shader = _HIT_SHADER
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
	_spawn_damage_number(amount)
	if is_boss:
		health_changed.emit(maxi(_health, 0), max_health)
	if _health <= 0:
		_begin_death()


func _spawn_damage_number(amount: int) -> void:
	if not is_instance_valid(floating_text_layer):
		return
	var color := _DMG_COLOR_NORMAL
	var big := false
	if is_boss:
		color = _DMG_COLOR_BOSS
		big = true
	elif is_elite:
		color = _DMG_COLOR_ELITE
		big = true
	var dn := _DAMAGE_NUMBER.new()
	floating_text_layer.add_child(dn)
	dn.global_position = global_position + Vector2(randf_range(-3.0, 3.0), -target_height * 0.5)
	dn.setup(amount, color, big)


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

	if is_boss:
		_process_boss_attack(_delta)

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


## Boss attack state machine: count down to the next attack, telegraph by
## pulsing the sprite red, then fire a fan of projectiles at the player.
func _process_boss_attack(delta: float) -> void:
	if _boss_telegraphing:
		_boss_telegraph_t -= delta
		var pulse: float = 0.5 + 0.5 * sin(_boss_telegraph_t * 28.0)
		_sprite.modulate = Color(1.0, 1.0 - 0.6 * pulse, 1.0 - 0.6 * pulse, 1.0)
		if _boss_telegraph_t <= 0.0:
			_boss_telegraphing = false
			_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
			_fire_boss_volley()
		return
	_boss_attack_t -= delta
	if _boss_attack_t <= 0.0:
		_boss_attack_t = BOSS_ATTACK_INTERVAL
		_boss_telegraphing = true
		_boss_telegraph_t = BOSS_TELEGRAPH_TIME


func _fire_boss_volley() -> void:
	if not is_instance_valid(target) or not is_instance_valid(projectile_layer):
		return
	var to_player: Vector2 = target.global_position - global_position
	if to_player.length_squared() < 0.0001:
		return
	var base_angle: float = to_player.angle()
	var spread: float = deg_to_rad(BOSS_VOLLEY_SPREAD_DEG)
	for i in BOSS_VOLLEY_COUNT:
		var t: float = 0.0
		if BOSS_VOLLEY_COUNT > 1:
			t = float(i) / float(BOSS_VOLLEY_COUNT - 1) - 0.5
		var ang: float = base_angle + t * spread
		var proj := _BOSS_PROJECTILE.new()
		proj.direction = Vector2(cos(ang), sin(ang))
		proj.damage = BOSS_PROJECTILE_DAMAGE
		proj.global_position = global_position
		projectile_layer.add_child(proj)


func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation(&"walk")
	sf.set_animation_loop(&"walk", true)
	var i := 0
	while true:
		var path: String = frames_root + ("%s_%02d.png" % [walk_frame_prefix, i])
		# load() uses the imported texture (.ctex) and works in exports;
		# Image.load() reads the raw .png and warns "this will not work on export".
		if not ResourceLoader.exists(path):
			break
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			break
		sf.add_frame(&"walk", tex, walk_frame_duration)
		i += 1
	sf.add_animation(&"death")
	sf.set_animation_loop(&"death", false)
	i = 0
	while true:
		var path: String = frames_root + ("%s_%02d.png" % [death_frame_prefix, i])
		if not ResourceLoader.exists(path):
			break
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			break
		sf.add_frame(&"death", tex, death_frame_duration)
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
