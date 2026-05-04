extends Node2D

signal game_over_requested

const ARENA_MIN := Vector2(-1100.0, -700.0)
const ARENA_MAX := Vector2(1100.0, 700.0)
const ENEMY_SCENE := preload("res://scenes/game/Enemy.tscn")
const CRYSTAL_SCENE := preload("res://scenes/game/Crystal.tscn")
const UPGRADE_SCREEN_SCENE := preload("res://scenes/ui/UpgradeScreen.tscn")
const UPGRADE_CATALOG := preload("res://scripts/game/upgrade_catalog.gd")

const CRYSTAL_DROP_CHANCE := 0.75
const BASE_CRYSTALS_PER_LEVEL := 5
const EXTRA_CRYSTALS_PER_LEVEL_TIER := 4

var _attack_range := 88.0
var _melee_damage := 36
var _weapon_cooldown := 1.15
var _weapon_timer := 0.0
var _upgrade_catalog := UPGRADE_CATALOG.new()
var _owned_upgrades: Dictionary = {}

@onready var player: CharacterBody2D = $Player
@onready var enemies: Node2D = $Enemies
@onready var pickups: Node2D = $Pickups
@onready var player_camera: Camera2D = $Player/Camera2D
@onready var health_label: Label = $HUD/TopPanel/HUDMargin/HUDVBox/HealthLabel
@onready var timer_label: Label = $HUD/TopPanel/HUDMargin/HUDVBox/TimeLabel
@onready var crystal_label: Label = $HUD/TopPanel/HUDMargin/HUDVBox/CrystalLabel
@onready var xp_bar: ProgressBar = $HUD/XpBar
@onready var title_label: Label = $HUD/TopPanel/HUDMargin/HUDVBox/TitleLabel
@onready var weapon_label: Label = $HUD/TopPanel/HUDMargin/HUDVBox/WeaponLabel
@onready var bounds_label: Label = $HUD/TopPanel/HUDMargin/HUDVBox/BoundsLabel
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var background_music: AudioStreamPlayer = $BackgroundMusic

var _elapsed_seconds := 0.0
var _spawn_timer := 1.2
var _crystals := 0
var _player_level := 1
var _kill_count := 0
var _pause_open := false


func _process(delta: float) -> void:
	_elapsed_seconds += delta
	timer_label.text = "Time: %s  ·  Kills: %d" % [_format_clock(_elapsed_seconds), _kill_count]

	var spawn_interval := maxf(0.55, 2.0 - _elapsed_seconds * 0.035)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_interval
		_spawn_enemy()

	_weapon_timer -= delta
	if _weapon_timer <= 0.0:
		_weapon_timer = _weapon_cooldown
		_perform_weapon_attack()

	player.position = player.position.clamp(ARENA_MIN, ARENA_MAX)


func _ready() -> void:
	var bgm_stream := background_music.stream
	if bgm_stream is AudioStreamOggVorbis:
		(bgm_stream as AudioStreamOggVorbis).loop = true
	background_music.play()
	_melee_damage = RunConfig.melee_damage
	_attack_range = RunConfig.attack_range
	_weapon_cooldown = RunConfig.weapon_cooldown
	_weapon_timer = _weapon_cooldown * 0.25
	title_label.text = "Run: %s" % RunConfig.display_name
	_refresh_weapon_hud()
	bounds_label.visible = false
	pause_menu.visible = false
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
	var need := _gems_needed_for_next_level()
	crystal_label.text = "Crystals: %d / %d  ·  Lv %d" % [_crystals, need, _player_level]
	xp_bar.max_value = float(need)
	xp_bar.value = float(_crystals)


func _find_closest_enemy_in_attack_range() -> Node2D:
	var best: Node2D = null
	var best_d2 := INF
	var ppos := player.global_position
	var r2 := _attack_range * _attack_range
	for node in enemies.get_children():
		if not node.has_method("take_damage"):
			continue
		var d2 := ppos.distance_squared_to(node.global_position)
		if d2 > r2:
			continue
		if d2 < best_d2:
			best_d2 = d2
			best = node
	return best


func _perform_weapon_attack() -> void:
	var target := _find_closest_enemy_in_attack_range()
	var aim := Vector2.RIGHT
	if target != null:
		aim = (target.global_position - player.global_position).normalized()
	elif player.has_method(&"get_weapon_aim_direction"):
		aim = player.get_weapon_aim_direction()
	if player.has_method(&"play_weapon_attack"):
		player.play_weapon_attack(_attack_range, aim)
	if target != null:
		target.take_damage(_melee_damage)


func _on_enemy_died(spawn_position: Vector2) -> void:
	_kill_count += 1
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
	var screen = UPGRADE_SCREEN_SCENE.instantiate()
	if screen.has_method(&"set_level"):
		screen.set_level(_player_level)
	if screen.has_method(&"set_choices"):
		screen.set_choices(_upgrade_catalog.get_choices(_owned_upgrades))
	add_child(screen)
	await screen.acknowledged
	if is_instance_valid(screen) and screen.has_method(&"get_selected_upgrade_id"):
		_apply_upgrade(screen.get_selected_upgrade_id())
	get_tree().paused = false


func _apply_upgrade(choice_id: String) -> void:
	if choice_id.is_empty():
		return
	_owned_upgrades[choice_id] = int(_owned_upgrades.get(choice_id, 0)) + 1
	_upgrade_catalog.apply_choice(choice_id, self, player)
	_refresh_weapon_hud()


func _refresh_weapon_hud() -> void:
	weapon_label.text = "Weapon: %s (auto)  ·  %d dmg  ·  %.0f range  ·  %.2fs" % [
		RunConfig.weapon_placeholder_name,
		_melee_damage,
		_attack_range,
		_weapon_cooldown,
	]


func apply_weapon_damage_bonus(amount: int) -> void:
	_melee_damage += amount
	_refresh_weapon_hud()


func apply_attack_range_bonus(amount: float) -> void:
	_attack_range += amount
	_refresh_weapon_hud()


func apply_weapon_cooldown_bonus(delta_amount: float) -> void:
	_weapon_cooldown = maxf(0.30, _weapon_cooldown + delta_amount)
	_weapon_timer = minf(_weapon_timer, _weapon_cooldown)
	_refresh_weapon_hud()


func _finalize_run_summary() -> void:
	RunConfig.last_run_time_seconds = _elapsed_seconds
	RunConfig.last_run_level = _player_level
	RunConfig.last_run_kills = _kill_count


func _on_end_run_button_pressed() -> void:
	_finalize_run_summary()
	game_over_requested.emit()


func on_pause_requested() -> void:
	if get_tree().get_nodes_in_group(&"upgrade_screen").size() > 0:
		return
	if _pause_open:
		_close_pause_menu()
		return
	_open_pause_menu()


func _open_pause_menu() -> void:
	_pause_open = true
	get_tree().paused = true
	pause_menu.visible = true


func _close_pause_menu() -> void:
	_pause_open = false
	get_tree().paused = false
	pause_menu.visible = false


func _on_pause_resume_pressed() -> void:
	_close_pause_menu()


func _on_pause_end_run_pressed() -> void:
	_close_pause_menu()
	_finalize_run_summary()
	game_over_requested.emit()


func _on_player_health_changed(new_health: int, max_health: int) -> void:
	health_label.text = "HP: %d/%d" % [new_health, max_health]


func _on_player_died() -> void:
	_finalize_run_summary()
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


func _format_clock(seconds: float) -> String:
	var s := int(floor(seconds))
	var m := s / 60
	s %= 60
	return "%d:%02d" % [m, s]


func _apply_difficulty_to_enemy(enemy: CharacterBody2D) -> void:
	var t := _elapsed_seconds
	var hp_mult := 1.0 + mini(t / 95.0, 3.25)
	var spd_mult := 1.0 + mini(t / 140.0, 0.55)
	enemy.max_health = int(round(32.0 * hp_mult))
	enemy.move_speed = 58.0 * spd_mult


func _spawn_enemy() -> void:
	_spawn_one_enemy()
	var t := _elapsed_seconds
	if t > 42.0 and randf() < clampf((t - 42.0) / 220.0, 0.0, 0.42):
		_spawn_one_enemy()


func _spawn_one_enemy() -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.target = player
	enemy.global_position = _random_spawn_on_arena_edge()
	_apply_difficulty_to_enemy(enemy)
	enemy.died.connect(_on_enemy_died)
	enemies.add_child(enemy)
