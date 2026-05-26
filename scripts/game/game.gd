extends Node2D

signal game_over_requested

const ARENA_MIN := Vector2(-11000.0, -7000.0)
const ARENA_MAX := Vector2(11000.0, 7000.0)
## Distance from player at which to spawn enemies (just outside the ~522x294 visible area at zoom 2.45).
const SPAWN_RING_RADIUS := 360.0
const SPAWN_RING_JITTER := 90.0
## Enemies farther than this from the player are culled; keeps the active pool bounded.
const ENEMY_DESPAWN_RADIUS := 760.0
const ENEMY_SCENE := preload("res://scenes/game/Enemy.tscn")
const CRYSTAL_SCENE := preload("res://scenes/game/Crystal.tscn")
const UPGRADE_SCREEN_SCENE := preload("res://scenes/ui/UpgradeScreen.tscn")
const UPGRADE_CATALOG := preload("res://scripts/game/upgrade_catalog.gd")
const WEAPON_REGISTRY := preload("res://scripts/weapons/weapon_registry.gd")
const WEAPON_INVENTORY := preload("res://scripts/weapons/weapon_inventory.gd")
const WEAPON_ICON_SIZE := Vector2(36, 36)
const PAUSE_WEAPON_ICON_SIZE := Vector2(64, 64)

const CRYSTAL_DROP_CHANCE := 0.97
const BASE_CRYSTALS_PER_LEVEL := 5
const EXTRA_CRYSTALS_PER_LEVEL_TIER := 4

## Once this many blue crystals are on the ground, neighbors within MERGE_RADIUS
## are fused into a single green crystal carrying the summed value.
const CRYSTAL_MERGE_THRESHOLD := 30
const CRYSTAL_MERGE_RADIUS := 56.0
const CRYSTAL_MERGE_CELL := 64.0
const CRYSTAL_MERGE_CHECK_INTERVAL := 0.4

## Enemy-vs-enemy separation. Each enemy hitbox is ~14x14 (half = 7); cell size needs to
## be >= the desired min separation so a 3x3 neighbor query covers all possible overlaps.
const ENEMY_SEP_HALF := 7.0
const ENEMY_SEP_CELL := 22.0
## Fraction of penetration we resolve per frame. Lower = softer, less jitter under stacking.
const ENEMY_SEP_PUSH := 0.5

var _inventory: WeaponInventory = WEAPON_INVENTORY.new()
var _upgrade_catalog := UPGRADE_CATALOG.new()
var _owned_upgrades: Dictionary = {}

@onready var player: CharacterBody2D = $Player
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var pickups: Node2D = $Pickups
@onready var player_camera: Camera2D = $Player/Camera2D
@onready var xp_bar: ProgressBar = $HUD/XpBar
@onready var big_timer_label: Label = $HUD/BigTimer/BigTimerMargin/BigTimerLabel
@onready var inv_hud_label: Label = $HUD/InvHudPanel/InvHudMargin/InvHudVBox/InvHudLabel
@onready var inv_hud_weapon_row: HBoxContainer = $HUD/InvHudPanel/InvHudMargin/InvHudVBox/InvHudWeaponRow
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var inventory_panel: PanelContainer = $PauseMenu/InventoryPanel
@onready var inventory_body: Label = $PauseMenu/InventoryPanel/InvMargin/InvVBox/InvBody
@onready var pause_inv_weapon_row: HBoxContainer = $PauseMenu/InventoryPanel/InvMargin/InvVBox/InvPauseWeaponRow
@onready var background_music: AudioStreamPlayer = $BackgroundMusic

var _elapsed_seconds := 0.0
var _spawn_timer := 1.2
var _crystals := 0
var _player_level := 1
var _kill_count := 0
var _pause_open := false
var _crystal_merge_timer := 0.0


func _process(delta: float) -> void:
	_elapsed_seconds += delta
	big_timer_label.text = _format_clock(_elapsed_seconds)
	_refresh_inv_hud()

	# +50% baseline spawn rate (interval 2.0 -> 1.33) and a steeper ramp so density
	# climbs noticeably as the run goes on. Floor lowered to 0.30s for late-game swarm.
	var spawn_interval := maxf(0.30, 1.33 - _elapsed_seconds * 0.05)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_interval
		_spawn_enemy()

	_inventory.process(delta, self, player)

	_cull_distant_enemies()
	_crystal_merge_timer -= delta
	if _crystal_merge_timer <= 0.0:
		_crystal_merge_timer = CRYSTAL_MERGE_CHECK_INTERVAL
		_maybe_merge_crystals()
	player.position = player.position.clamp(ARENA_MIN, ARENA_MAX)


func _ready() -> void:
	var bgm_stream := background_music.stream
	if bgm_stream is AudioStreamOggVorbis:
		(bgm_stream as AudioStreamOggVorbis).loop = true
	background_music.play()
	_grant_starting_weapon()
	_refresh_inv_hud_icons()
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
	xp_bar.max_value = float(need)
	xp_bar.value = float(_crystals)


## Public: weapons use this to acquire targets without each one re-implementing the loop.
func find_closest_enemy(from: Vector2, max_range: float) -> Node2D:
	var best: Node2D = null
	var best_d2 := INF
	var r2 := max_range * max_range
	for node in enemies.get_children():
		if not node.has_method(&"take_damage"):
			continue
		if "collision_layer" in node and int(node.get("collision_layer")) == 0:
			continue  # dying corpse
		var d2 := from.distance_squared_to(node.global_position)
		if d2 > r2:
			continue
		if d2 < best_d2:
			best_d2 = d2
			best = node
	return best


func _grant_starting_weapon() -> void:
	var weapon_id: String = RunConfig.starting_weapon_id
	if weapon_id.is_empty():
		weapon_id = "magic_wand"
	var w := WeaponRegistry.create(weapon_id)
	if w != null:
		_inventory.add_weapon(w)


func _on_enemy_died(spawn_position: Vector2) -> void:
	_kill_count += 1
	if randf() > CRYSTAL_DROP_CHANCE:
		return
	var crystal = CRYSTAL_SCENE.instantiate()
	crystal.global_position = spawn_position
	pickups.add_child(crystal)
	crystal.set_gem(1, 0)
	crystal.collected.connect(_on_crystal_collected)


func _on_crystal_collected(value: int) -> void:
	Sfx.play("collect")
	_crystals += maxi(1, value)
	_update_crystal_hud()
	await _process_level_up_overflow()


## Spatial-hash merge: when blue crystals stack up, fuse nearby ones into a single green
## that carries the summed value. Keeps the pickup node count bounded and saves the player
## from chasing dozens of individual gems.
func _maybe_merge_crystals() -> void:
	var blues: Array[Node2D] = []
	for c in pickups.get_children():
		if not (c is Node2D):
			continue
		if not c.has_method(&"set_gem"):
			continue
		if int(c.get("tier")) != 0:
			continue
		blues.append(c)

	if blues.size() < CRYSTAL_MERGE_THRESHOLD:
		return

	var cell := CRYSTAL_MERGE_CELL
	var buckets: Dictionary = {}
	for b in blues:
		var key := Vector2i(int(floor(b.global_position.x / cell)), int(floor(b.global_position.y / cell)))
		if not buckets.has(key):
			buckets[key] = [] as Array[Node2D]
		(buckets[key] as Array[Node2D]).append(b)

	var used: Dictionary = {}
	var r2 := CRYSTAL_MERGE_RADIUS * CRYSTAL_MERGE_RADIUS
	for b in blues:
		if used.has(b):
			continue
		var group: Array[Node2D] = [b]
		used[b] = true
		var cx := int(floor(b.global_position.x / cell))
		var cy := int(floor(b.global_position.y / cell))
		for ox in range(-1, 2):
			for oy in range(-1, 2):
				var k := Vector2i(cx + ox, cy + oy)
				if not buckets.has(k):
					continue
				for o in (buckets[k] as Array[Node2D]):
					if used.has(o):
						continue
					if b.global_position.distance_squared_to(o.global_position) <= r2:
						group.append(o)
						used[o] = true
		if group.size() < 2:
			continue

		var sum_val := 0
		var avg := Vector2.ZERO
		for g in group:
			sum_val += int(g.get("value"))
			avg += g.global_position
			g.queue_free()
		avg /= float(group.size())

		var green = CRYSTAL_SCENE.instantiate()
		green.global_position = avg
		pickups.add_child(green)
		green.set_gem(sum_val, 1)
		green.collected.connect(_on_crystal_collected)


func _process_level_up_overflow() -> void:
	while _crystals >= _gems_needed_for_next_level():
		var need := _gems_needed_for_next_level()
		_crystals -= need
		_player_level += 1
		_update_crystal_hud()
		await _run_upgrade_screen()


func _run_upgrade_screen() -> void:
	Sfx.play("levelup")
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
	_refresh_inv_hud_icons()


## Stat-bonus shims: catalog still says "+6 damage" etc; for now those all route to
## the Magic Wand (the only weapon in this commit). Once the upgrade screen is
## rewritten in step 3b these will become per-weapon level-ups instead.
func apply_weapon_damage_bonus(amount: int) -> void:
	var w := _inventory.get_weapon("magic_wand")
	if w != null:
		w.dmg_bonus += amount


func apply_attack_range_bonus(amount: float) -> void:
	var w := _inventory.get_weapon("magic_wand")
	if w != null:
		w.range_bonus += amount


func apply_weapon_cooldown_bonus(delta_amount: float) -> void:
	var w := _inventory.get_weapon("magic_wand")
	if w != null:
		w.cd_bonus += delta_amount


func _finalize_run_summary() -> void:
	RunConfig.last_run_time_seconds = _elapsed_seconds
	RunConfig.last_run_level = _player_level
	RunConfig.last_run_kills = _kill_count


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
	inventory_panel.visible = false


func _close_pause_menu() -> void:
	_pause_open = false
	get_tree().paused = false
	pause_menu.visible = false
	inventory_panel.visible = false


func _on_pause_resume_pressed() -> void:
	_close_pause_menu()


func _on_pause_inventory_pressed() -> void:
	inventory_panel.visible = not inventory_panel.visible
	if inventory_panel.visible:
		_refresh_inventory_panel()


func _on_pause_end_run_pressed() -> void:
	_close_pause_menu()
	_finalize_run_summary()
	game_over_requested.emit()


func _build_inventory_text(full: bool) -> String:
	var max_hp := 0
	var cur_hp := 0
	var move_spd := 0.0
	if player != null:
		max_hp = int(player.get("max_health"))
		cur_hp = int(player.get("current_health"))
		move_spd = float(player.get("move_speed"))

	var lines: Array[String] = []
	lines.append("%s  ·  Lv %d" % [RunConfig.display_name, _player_level])
	lines.append("HP: %d / %d" % [cur_hp, max_hp])
	lines.append("Kills: %d" % _kill_count)
	lines.append("")
	lines.append("Weapons (%d/%d)" % [_inventory.weapons.size(), WeaponInventory.MAX_SLOTS])
	if _inventory.weapons.is_empty():
		lines.append("  (none)")
	else:
		for w in _inventory.weapons:
			lines.append("  %s  Lv %d  ·  %s" % [w.display_name, w.level, w.describe_stats()])
	if full:
		lines.append("")
		lines.append("Stats")
		lines.append("  Move speed: %.0f" % move_spd)
	lines.append("")
	lines.append("Upgrades")
	if _owned_upgrades.is_empty():
		lines.append("  (none yet)")
	else:
		for id in _owned_upgrades.keys():
			var rank := int(_owned_upgrades[id])
			var title: String = id
			if UpgradeCatalog.DEFINITIONS.has(id):
				title = str(UpgradeCatalog.DEFINITIONS[id]["title"])
			lines.append("  %s  x%d" % [title, rank])
	return "\n".join(lines)


func _refresh_inv_hud() -> void:
	inv_hud_label.text = _build_inventory_text(false)


func _refresh_inventory_panel() -> void:
	inventory_body.text = _build_inventory_text(true)
	_populate_weapon_icon_row(pause_inv_weapon_row, PAUSE_WEAPON_ICON_SIZE)


## Rebuild the live HUD weapon icon strip. Called whenever inventory changes
## (gain/level a weapon). Cheap: few children, swapped at most every level-up.
func _refresh_inv_hud_icons() -> void:
	_populate_weapon_icon_row(inv_hud_weapon_row, WEAPON_ICON_SIZE)


func _populate_weapon_icon_row(row: HBoxContainer, icon_size: Vector2) -> void:
	if row == null:
		return
	for child in row.get_children():
		child.queue_free()
	for w in _inventory.weapons:
		var tex := Weapon.load_icon(w.icon_path)
		if tex == null:
			continue
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = icon_size
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.tooltip_text = "%s  Lv %d" % [w.display_name, w.level]
		row.add_child(rect)


func _on_player_health_changed(_new_health: int, _max_health: int) -> void:
	# HP is shown in the live inventory HUD (refreshed each frame) + the floating bar under the player.
	pass


func _on_player_died() -> void:
	Sfx.play("gameover")
	_finalize_run_summary()
	game_over_requested.emit()


func _random_spawn_on_arena_edge() -> Vector2:
	## Spawn just outside the player's view on a jittered ring, then clamp inside world bounds.
	var angle := randf() * TAU
	var radius := SPAWN_RING_RADIUS + randf_range(0.0, SPAWN_RING_JITTER)
	var offset := Vector2(cos(angle), sin(angle)) * radius
	var pos := player.global_position + offset
	return pos.clamp(ARENA_MIN, ARENA_MAX)


func _physics_process(_delta: float) -> void:
	_resolve_enemy_separation()


## Spatial-hash separation: bucket all live enemies by integer cell, then each enemy
## only inspects the 9 cells around it. Cost is O(n) average with a small constant.
func _resolve_enemy_separation() -> void:
	var min_sep := ENEMY_SEP_HALF * 2.0
	var cell := ENEMY_SEP_CELL
	var buckets: Dictionary = {}
	var live: Array[Node2D] = []

	for n in enemies.get_children():
		if not (n is Node2D):
			continue
		var body := n as Node2D
		# Dying enemies zero their collision_layer in enemy.gd; skip them so corpses don't push.
		if "collision_layer" in body and int(body.get("collision_layer")) == 0:
			continue
		live.append(body)
		var key := Vector2i(int(floor(body.global_position.x / cell)), int(floor(body.global_position.y / cell)))
		if not buckets.has(key):
			buckets[key] = [] as Array[Node2D]
		(buckets[key] as Array[Node2D]).append(body)

	for body in live:
		var cx := int(floor(body.global_position.x / cell))
		var cy := int(floor(body.global_position.y / cell))
		for ox in range(-1, 2):
			for oy in range(-1, 2):
				var k := Vector2i(cx + ox, cy + oy)
				if not buckets.has(k):
					continue
				for other in (buckets[k] as Array[Node2D]):
					if other == body:
						continue
					var d := body.global_position - other.global_position
					var ax := absf(d.x)
					var ay := absf(d.y)
					if ax >= min_sep or ay >= min_sep:
						continue
					# Perfect overlap: nudge in a deterministic-but-distinct direction so
					# stacked spawns don't oscillate around a shared point.
					if ax < 0.001 and ay < 0.001:
						var jitter := float(body.get_instance_id() & 7) * 0.001 + 0.05
						body.global_position.x += jitter
						continue
					var pen_x := min_sep - ax
					var pen_y := min_sep - ay
					# Resolve along the shallower axis (smaller MTV); split push between the two.
					if pen_x < pen_y:
						var sx := 1.0 if d.x >= 0.0 else -1.0
						body.global_position.x += sx * pen_x * ENEMY_SEP_PUSH
					else:
						var sy := 1.0 if d.y >= 0.0 else -1.0
						body.global_position.y += sy * pen_y * ENEMY_SEP_PUSH


func _cull_distant_enemies() -> void:
	var ppos := player.global_position
	var r2 := ENEMY_DESPAWN_RADIUS * ENEMY_DESPAWN_RADIUS
	for node in enemies.get_children():
		if not (node is Node2D):
			continue
		if (node as Node2D).global_position.distance_squared_to(ppos) > r2:
			node.queue_free()


func _format_clock(seconds: float) -> String:
	var s := int(floor(seconds))
	var m := s / 60
	s %= 60
	return "%d:%02d" % [m, s]


func _apply_difficulty_to_enemy(enemy: CharacterBody2D) -> void:
	var t := _elapsed_seconds
	# Steeper HP ramp than before so the wand stops one-shotting around the
	# 30-60s mark and the player has to actually invest in upgrades. Cap raised
	# from 4.25x to 6.0x for a meaner late game.
	var hp_mult := 1.0 + minf(t / 55.0, 5.0)
	var spd_mult := 1.0 + minf(t / 140.0, 0.55)
	enemy.max_health = int(round(32.0 * hp_mult))
	enemy.move_speed = 58.0 * spd_mult


func _spawn_enemy() -> void:
	_spawn_one_enemy()
	var t := _elapsed_seconds
	# Extra spawns kick in earlier (30s) and ramp higher (up to ~65% chance) for
	# a thicker mid/late game.
	if t > 30.0 and randf() < clampf((t - 30.0) / 150.0, 0.0, 0.65):
		_spawn_one_enemy()
	# Second extra spawn past 90s for true swarm pressure.
	if t > 90.0 and randf() < clampf((t - 90.0) / 240.0, 0.0, 0.5):
		_spawn_one_enemy()


func _spawn_one_enemy() -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.target = player
	enemy.global_position = _random_spawn_on_arena_edge()
	_apply_difficulty_to_enemy(enemy)
	enemy.died.connect(_on_enemy_died)
	enemies.add_child(enemy)
