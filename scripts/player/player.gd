extends CharacterBody2D

signal health_changed(new_health: int, max_health: int)
signal died

@export var move_speed := 105.0
@export var dash_speed := 200.0
@export var dash_duration := 0.18
@export var max_health := 100

@export var impact_damage_per_enemy := 5
@export var contact_periodic_interval := 0.35
@export var contact_periodic_damage_standing_per_enemy := 3
@export var contact_periodic_damage_pushing_per_enemy := 8
@export var overlap_move_speed_mult := 0.52

@onready var hurtbox: Area2D = $Hurtbox
@onready var _body_visual: Polygon2D = $Body
@onready var _hero: AnimatedSprite2D = $HeroSprite
@onready var _weapon_fx: Node2D = $WeaponFx

var current_health := max_health
var _dash_time_left := 0.0
var _last_move_dir := Vector2.DOWN
var _contact_hurt_cd := 0.0
var _prev_touching_count := 0
var _input_move := Vector2.ZERO

## res:// folder per character_id; contains portrait.png + walk_XX.png from wiki sprites / Animated-*.gif
const CHARACTER_WALK_ROOT := {
	"wizard": "res://assets/characters/imelda/",
	"knight": "res://assets/characters/knight/",
	"cleric": "res://assets/characters/cleric/",
}
const WALK_FRAME_DURATION := 0.34
## World-space height for any walk sheet so visuals match the ~14×14 hitbox (large wiki sprites were huge at a fixed scale).
const HERO_TARGET_HEIGHT_UNITS := 18.0

static var _sprite_frames_cache: Dictionary = {}


func _ready() -> void:
	add_to_group("player")
	_setup_character_visual()
	health_changed.emit(current_health, max_health)


func get_weapon_aim_direction() -> Vector2:
	return _last_move_dir if _last_move_dir.length_squared() > 0.0001 else Vector2.RIGHT


func play_weapon_attack(range_units: float, aim_direction: Vector2) -> void:
	if _weapon_fx != null and _weapon_fx.has_method(&"play"):
		var aim := aim_direction
		if aim.length_squared() < 0.0001:
			aim = get_weapon_aim_direction()
		_weapon_fx.play(range_units, aim.normalized())


func take_damage(amount: int) -> void:
	if current_health <= 0 or amount <= 0:
		return
	current_health = maxi(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		died.emit()


func heal(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return
	current_health = mini(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)


func apply_bonus_max_health(amount: int) -> void:
	if amount <= 0:
		return
	max_health += amount
	current_health += amount
	health_changed.emit(current_health, max_health)


func apply_move_speed_bonus(amount: float) -> void:
	move_speed += amount
	dash_speed += amount * 1.35


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
	_update_hero_visual()


func _setup_character_visual() -> void:
	var id := RunConfig.character_id
	var use_hero := CHARACTER_WALK_ROOT.has(id)
	_body_visual.visible = not use_hero
	_hero.visible = use_hero
	if not use_hero:
		return
	_hero.sprite_frames = _ensure_sprite_frames(id)
	var tex: Texture2D = _hero.sprite_frames.get_frame_texture(&"idle", 0)
	if tex == null and _hero.sprite_frames.has_animation(&"walk") and _hero.sprite_frames.get_frame_count(&"walk") > 0:
		tex = _hero.sprite_frames.get_frame_texture(&"walk", 0)
	if tex != null:
		var h: float = float(tex.get_size().y)
		if h > 0.0:
			var s: float = HERO_TARGET_HEIGHT_UNITS / h
			_hero.scale = Vector2(s, s)
	_hero.play(&"idle")


func _ensure_sprite_frames(character_id: String) -> SpriteFrames:
	var cache_key := "%s:%f" % [character_id, WALK_FRAME_DURATION]
	if _sprite_frames_cache.has(cache_key):
		return _sprite_frames_cache[cache_key]
	var base: String = CHARACTER_WALK_ROOT[character_id]
	var sf := SpriteFrames.new()
	sf.add_animation(&"walk")
	sf.set_animation_loop(&"walk", true)
	var i := 0
	while true:
		var path := base + ("walk_%02d.png" % i)
		if not FileAccess.file_exists(path):
			break
		var img := Image.new()
		if img.load(path) != OK:
			break
		sf.add_frame(&"walk", ImageTexture.create_from_image(img), WALK_FRAME_DURATION)
		i += 1
	sf.add_animation(&"idle")
	sf.set_animation_loop(&"idle", true)
	var idle_path := base + "walk_00.png"
	var idle_img := Image.new()
	if idle_img.load(idle_path) == OK:
		sf.add_frame(&"idle", ImageTexture.create_from_image(idle_img), 1.0)
	_sprite_frames_cache[cache_key] = sf
	return sf


func _update_hero_visual() -> void:
	if not _hero.visible:
		return
	var moving := velocity.length_squared() > 400.0
	if moving:
		if _hero.animation != &"walk":
			_hero.play(&"walk")
	else:
		if _hero.animation != &"idle":
			_hero.play(&"idle")
	var face_left := false
	if absf(velocity.x) > 8.0:
		face_left = velocity.x < 0.0
	elif absf(_last_move_dir.x) > 0.05:
		face_left = _last_move_dir.x < 0.0
	_hero.flip_h = face_left


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
