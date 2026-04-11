extends CharacterBody2D

signal health_changed(new_health: int, max_health: int)
signal died

@export var move_speed := 168.0
@export var dash_speed := 320.0
@export var dash_duration := 0.18
@export var max_health := 100

@export var impact_damage_per_enemy := 5
@export var contact_periodic_interval := 0.35
@export var contact_periodic_damage_standing_per_enemy := 3
@export var contact_periodic_damage_pushing_per_enemy := 8
@export var overlap_move_speed_mult := 0.52

@onready var hurtbox: Area2D = $Hurtbox
@onready var _body_visual: Polygon2D = $Body
@onready var _imelda: AnimatedSprite2D = $ImeldaSprite

var current_health := max_health
var _dash_time_left := 0.0
var _last_move_dir := Vector2.DOWN
var _contact_hurt_cd := 0.0
var _prev_touching_count := 0
var _input_move := Vector2.ZERO

const IMELDA_WALK_PATH := "res://assets/characters/imelda/walk_%02d.png"
const IMELDA_WALK_FRAMES := 4
const IMELDA_WALK_FRAME_DURATION := 0.34
## Sprites face right; scaled up for readability vs pickups / world (hitbox stays 14×14).
const IMELDA_SPRITE_SCALE := Vector2(0.72, 0.72)

static var _imelda_sprite_frames: SpriteFrames
static var _imelda_walk_frame_duration_built := -1.0


func _ready() -> void:
	add_to_group("player")
	_setup_character_visual()
	health_changed.emit(current_health, max_health)


func take_damage(amount: int) -> void:
	if current_health <= 0 or amount <= 0:
		return
	current_health = maxi(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		died.emit()


func _physics_process(delta: float) -> void:
	_input_move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _input_move != Vector2.ZERO:
		_last_move_dir = _input_move.normalized()

	var overlap_for_speed := _count_enemies_overlapping_hurtbox()
	var speed_scale := overlap_move_speed_mult if overlap_for_speed > 0 else 1.0

	if Input.is_action_just_pressed("dash"):
		_dash_time_left = dash_duration

	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		velocity = _last_move_dir * dash_speed * speed_scale
	else:
		velocity = _input_move * move_speed * speed_scale

	move_and_slide()
	_apply_contact_damage(delta)
	_update_imelda_visual()


func _setup_character_visual() -> void:
	var use_imelda := RunConfig.character_id == "wizard"
	_body_visual.visible = not use_imelda
	_imelda.visible = use_imelda
	if not use_imelda:
		return
	_ensure_imelda_sprite_frames()
	_imelda.sprite_frames = _imelda_sprite_frames
	_imelda.scale = IMELDA_SPRITE_SCALE
	_imelda.play(&"idle")


func _ensure_imelda_sprite_frames() -> void:
	if (
		_imelda_sprite_frames != null
		and is_equal_approx(_imelda_walk_frame_duration_built, IMELDA_WALK_FRAME_DURATION)
	):
		return
	var sf := SpriteFrames.new()
	sf.add_animation(&"walk")
	sf.set_animation_loop(&"walk", true)
	for i in range(IMELDA_WALK_FRAMES):
		var img := Image.new()
		if img.load(IMELDA_WALK_PATH % i) != OK:
			continue
		sf.add_frame(&"walk", ImageTexture.create_from_image(img), IMELDA_WALK_FRAME_DURATION)
	sf.add_animation(&"idle")
	sf.set_animation_loop(&"idle", true)
	var idle_img := Image.new()
	if idle_img.load(IMELDA_WALK_PATH % 0) == OK:
		sf.add_frame(&"idle", ImageTexture.create_from_image(idle_img), 1.0)
	_imelda_sprite_frames = sf
	_imelda_walk_frame_duration_built = IMELDA_WALK_FRAME_DURATION


func _update_imelda_visual() -> void:
	if not _imelda.visible:
		return
	var moving := velocity.length_squared() > 400.0
	if moving:
		if _imelda.animation != &"walk":
			_imelda.play(&"walk")
	else:
		if _imelda.animation != &"idle":
			_imelda.play(&"idle")
	var face_left := false
	if absf(velocity.x) > 8.0:
		face_left = velocity.x < 0.0
	elif absf(_last_move_dir.x) > 0.05:
		face_left = _last_move_dir.x < 0.0
	_imelda.flip_h = face_left


func _is_pushing_through() -> bool:
	return _input_move.length_squared() > 0.0001 or _dash_time_left > 0.0


func _apply_contact_damage(delta: float) -> void:
	var touching := _count_enemies_overlapping_hurtbox()
	if touching == 0:
		_contact_hurt_cd = 0.0
		_prev_touching_count = 0
		return

	var became_touching := touching > 0 and _prev_touching_count == 0
	if became_touching:
		take_damage(touching * impact_damage_per_enemy)
		_contact_hurt_cd = contact_periodic_interval
	else:
		_contact_hurt_cd -= delta

	if _contact_hurt_cd <= 0.0:
		var pushing := _is_pushing_through()
		var per_enemy := contact_periodic_damage_pushing_per_enemy if pushing else contact_periodic_damage_standing_per_enemy
		take_damage(touching * per_enemy)
		_contact_hurt_cd = contact_periodic_interval

	_prev_touching_count = touching


func _count_enemies_overlapping_hurtbox() -> int:
	var n := 0
	for b in hurtbox.get_overlapping_bodies():
		if b.is_in_group("enemy"):
			n += 1
	return n
