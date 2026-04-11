extends Node2D

signal game_over_requested

const ARENA_MIN := Vector2(-1100.0, -700.0)
const ARENA_MAX := Vector2(1100.0, 700.0)
const ENEMY_SCENE := preload("res://scenes/game/Enemy.tscn")
const CRYSTAL_SCENE := preload("res://scenes/game/Crystal.tscn")
const UPGRADE_SCREEN_SCENE := preload("res://scenes/ui/UpgradeScreen.tscn")

const CRYSTAL_DROP_CHANCE := 0.75
const BASE_CRYSTALS_PER_LEVEL := 5
const EXTRA_CRYSTALS_PER_LEVEL_TIER := 4

var _attack_range := 88.0
var _melee_damage := 36
var _weapon_cooldown := 1.15
var _weapon_timer := 0.0

@onready var player: CharacterBody2D = $Player
@onready var enemies: Node2D = $Enemies
@onready var pickups: Node2D = $Pickups
@onready var player_camera: Camera2D = $Player/Camera2D
@onready var health_bar: ProgressBar = $HUD/TopPanel/HUDMargin/HUDVBox/HealthBar
@onready var health_label: Label = $HUD/TopPanel/HUDMargin/HUDVBox/HealthLabel
@onready var timer_label: Label = $HUD/TopPanel/HUDMargin/HUDVBox/TimeLabel
@onready var crystal_label: Label = $HUD/TopPanel/HUDMargin/HUDVBox/CrystalLabel
@onready var attack_flash: Label = $HUD/AttackFlash
@onready var title_label: Label = $HUD/TopPanel/HUDMargin/HUDVBox/TitleLabel
@onready var weapon_label: Label = $HUD/TopPanel/HUDMargin/HUDVBox/WeaponLabel

var _elapsed_seconds := 0.0
var _attack_flash_time_left := 0.0
var _spawn_timer := 1.2
var _crystals := 0
var _player_level := 1


func _process(delta: float) -> void:
	_elapsed_seconds += delta
	timer_label.text = "Time: %.1f" % _elapsed_seconds

	var spawn_interval := maxf(0.55, 2.0 - _elapsed_seconds * 0.035)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_interval
		_spawn_enemy()

	_weapon_timer -= delta
	if _weapon_timer <= 0.0:
		_weapon_timer = _weapon_cooldown
		_attack_flash_time_left = 0.12
		attack_flash.visible = true
		_damage_enemies_in_attack_range()

	if _attack_flash_time_left > 0.0:
		_attack_flash_time_left -= delta
		if _attack_flash_time_left <= 0.0:
			attack_flash.visible = false

	player.position = player.position.clamp(ARENA_MIN, ARENA_MAX)


func _ready() -> void:
	_melee_damage = RunConfig.melee_damage
	_attack_range = RunConfig.attack_range
	_weapon_cooldown = RunConfig.weapon_cooldown
	_weapon_timer = _weapon_cooldown * 0.25
	title_label.text = "Run: %s" % RunConfig.display_name
	weapon_label.text = "Weapon: %s (auto, placeholder)" % RunConfig.weapon_placeholder_name
	player_camera.make_current()
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_player_health_changed)
		var current_health := int(player.get("current_health"))
		var max_health := int(player.get("max_health"))
		_on_player_health_changed(current_health, max_health)
	if player.has_signal("died"):
		player.died.connect(_on_player_died)
	_update_crystal_hud()


func _gems_needed_for_next_level() -> int:
	return BASE_CRYSTALS_PER_LEVEL + (_player_level - 1) * EXTRA_CRYSTALS_PER_LEVEL_TIER


func _update_crystal_hud() -> void:
	crystal_label.text = "Crystals: %d / %d  ·  Lv %d" % [_crystals, _gems_needed_for_next_level(), _player_level]


func _damage_enemies_in_attack_range() -> void:
	for node in enemies.get_children():
		if not node.has_method("take_damage"):
			continue
		if node.global_position.distance_to(player.global_position) > _attack_range:
			continue
		node.take_damage(_melee_damage)


func _on_enemy_died(spawn_position: Vector2) -> void:
	if randf() > CRYSTAL_DROP_CHANCE:
		return
	var crystal = CRYSTAL_SCENE.instantiate()
	crystal.global_position = spawn_position
	pickups.add_child(crystal)
	crystal.collected.connect(_on_crystal_collected)


func _on_crystal_collected() -> void:
	_crystals += 1
	_update_crystal_hud()
	await _process_level_up_overflow()


func _process_level_up_overflow() -> void:
	while _crystals >= _gems_needed_for_next_level():
		var need := _gems_needed_for_next_level()
		_crystals -= need
		_player_level += 1
		_update_crystal_hud()
		await _run_upgrade_screen()


func _run_upgrade_screen() -> void:
	get_tree().paused = true
	var screen: CanvasLayer = UPGRADE_SCREEN_SCENE.instantiate()
	add_child(screen)
	await screen.acknowledged
	get_tree().paused = false


func _on_end_run_button_pressed() -> void:
	game_over_requested.emit()


func _on_pause_requested() -> void:
	game_over_requested.emit()


func _on_player_health_changed(new_health: int, max_health: int) -> void:
	health_bar.max_value = float(max_health)
	health_bar.value = float(new_health)
	health_label.text = "HP: %d/%d" % [new_health, max_health]


func _on_player_died() -> void:
	game_over_requested.emit()


func _random_spawn_on_arena_edge() -> Vector2:
	match randi() % 4:
		0:
			return Vector2(randf_range(ARENA_MIN.x, ARENA_MAX.x), ARENA_MIN.y)
		1:
			return Vector2(randf_range(ARENA_MIN.x, ARENA_MAX.x), ARENA_MAX.y)
		2:
			return Vector2(ARENA_MIN.x, randf_range(ARENA_MIN.y, ARENA_MAX.y))
		_:
			return Vector2(ARENA_MAX.x, randf_range(ARENA_MIN.y, ARENA_MAX.y))


func _spawn_enemy() -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.target = player
	enemy.global_position = _random_spawn_on_arena_edge()
	enemy.died.connect(_on_enemy_died)
	enemies.add_child(enemy)
