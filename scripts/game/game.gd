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
const CHEST_SCENE := preload("res://scenes/game/Chest.tscn")

## Per-type enemy config. Loaded into a generic Enemy.tscn before _ready
## so a single scene + script serves every variant.
const ENEMY_TYPES := {
	"pipeestrello": {
		"frames_root": "res://assets/enemies/pipeestrello_3/",
		"walk_prefix": "fly", "death_prefix": "death",
		"target_height": 14.0,
		"walk_dur": 0.28, "death_dur": 0.16,
		"hp_base": 32, "speed_base": 58.0,
		# Bats stay almost one-shot the whole run; small scaling so they get
		# very slightly chunkier late but never tanky.
		"hp_scale_cap": 0.3,
		# Bat sprite faces right by default in our frames; ground enemies face
		# left by default (their gifs were authored facing left).
		"faces_right": true,
	},
	"skeleton": {
		"frames_root": "res://assets/enemies/skeleton/",
		"walk_prefix": "walk", "death_prefix": "death",
		"target_height": 20.0,
		"walk_dur": 0.20, "death_dur": 0.09,
		"hp_base": 58, "speed_base": 50.0,
		"hp_scale_cap": 2.5,
	},
	"mudman1": {
		"frames_root": "res://assets/enemies/mudman1/",
		"walk_prefix": "walk", "death_prefix": "death",
		"target_height": 22.0,
		"walk_dur": 0.22, "death_dur": 0.10,
		"hp_base": 90, "speed_base": 42.0,
		"hp_scale_cap": 3.5,
	},
	"mudman2": {
		"frames_root": "res://assets/enemies/mudman2/",
		"walk_prefix": "walk", "death_prefix": "death",
		"target_height": 22.0,
		"walk_dur": 0.22, "death_dur": 0.10,
		"hp_base": 105, "speed_base": 40.0,
		"hp_scale_cap": 4.0,
	},
	"batboss": {
		"frames_root": "res://assets/enemies/batboss/",
		"walk_prefix": "walk", "death_prefix": "death",
		"target_height": 44.0,
		"walk_dur": 0.18, "death_dur": 0.10,
		"hp_base": 900, "speed_base": 46.0,
		# Boss HP is already balanced for late-game; no time scaling.
		"hp_scale_cap": 0.0,
		"cullable": false,
		# Boss is already special - never roll elite on top of that.
		"can_be_elite": false,
	},
	"flowerwall": {
		"frames_root": "res://assets/enemies/flowerwall/",
		"walk_prefix": "walk", "death_prefix": "death",
		"target_height": 26.0,
		"walk_dur": 0.22, "death_dur": 0.10,
		"hp_base": 220, "speed_base": 0.0,
		"hp_scale_cap": 1.5,
		"stationary": true,
	},
}
const UPGRADE_SCREEN_SCENE := preload("res://scenes/ui/UpgradeScreen.tscn")
const UPGRADE_CATALOG := preload("res://scripts/game/upgrade_catalog.gd")
const WEAPON_REGISTRY := preload("res://scripts/weapons/weapon_registry.gd")
const WEAPON_INVENTORY := preload("res://scripts/weapons/weapon_inventory.gd")
const WEAPON_ICON_SIZE := Vector2(64, 64)
const PAUSE_WEAPON_ICON_SIZE := Vector2(72, 72)
const PASSIVE_ICON_SIZE := Vector2(48, 48)
const LEVEL_DOT_SIZE := Vector2(6, 6)
const LEVEL_DOT_FILLED := Color(1.0, 0.85, 0.32, 1.0)
const LEVEL_DOT_EMPTY := Color(0.28, 0.30, 0.38, 0.65)

const CRYSTAL_DROP_CHANCE := 0.97
const BASE_CRYSTALS_PER_LEVEL := 5
const EXTRA_CRYSTALS_PER_LEVEL_TIER := 4

## Rare chest drop replaces the normal gem on enemy death. Tune-up: ~1 chest
## per ~80 kills feels reasonable for a normal enemy pool.
const CHEST_DROP_CHANCE := 0.012

## ~3% of normal spawns roll as elite: blue outline + 2x HP. Boss / stationary
## enemies opt out via the can_be_elite flag in ENEMY_TYPES.
const ELITE_SPAWN_CHANCE := 0.03
const ELITE_HP_MULT := 2.0

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
var _passive_ranks: Dictionary = {}

@onready var player: CharacterBody2D = $Player
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var pickups: Node2D = $Pickups
@onready var player_camera: Camera2D = $Player/Camera2D
@onready var big_timer_label: Label = $HUD/BigTimer/BigTimerMargin/BigTimerLabel
@onready var debug_panel: PanelContainer = $HUD/DebugPanel
@onready var inv_hud_weapon_row: HBoxContainer = $HUD/InvHudPanel/InvHudMargin/InvHudVBox/InvHudWeaponRow
@onready var inv_hud_passive_row: HBoxContainer = $HUD/InvHudPanel/InvHudMargin/InvHudVBox/InvHudPassiveRow
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var inventory_panel: PanelContainer = $PauseMenu/InventoryPanel
@onready var inventory_body: Label = $PauseMenu/InventoryPanel/InvMargin/InvVBox/InvBody
@onready var pause_inv_weapon_row: HBoxContainer = $PauseMenu/InventoryPanel/InvMargin/InvVBox/InvPauseWeaponRow
@onready var inv_recipes_box: VBoxContainer = $PauseMenu/InventoryPanel/InvMargin/InvVBox/InvRecipesBox
@onready var background_music: AudioStreamPlayer = $BackgroundMusic

var _chest_roll_active: bool = false

var _elapsed_seconds := 0.0
var _spawn_timer := 1.2
var _crystals := 0
var _player_level := 1
var _kill_count := 0
var _pause_open := false
var _crystal_merge_timer := 0.0
var _boss_spawned := false
## First flower-wall event triggers at this many seconds; subsequent events
## happen on FLOWER_EVENT_INTERVAL.
var _flower_event_timer: float = 75.0
const FLOWER_EVENT_INTERVAL: float = 95.0


func _process(delta: float) -> void:
	_elapsed_seconds += delta
	big_timer_label.text = _format_clock(_elapsed_seconds)

	# +50% baseline spawn rate (interval 2.0 -> 1.33) and a steeper ramp so density
	# climbs noticeably as the run goes on. Floor lowered to 0.30s for late-game swarm.
	var spawn_interval := maxf(0.30, 1.33 - _elapsed_seconds * 0.05)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_interval
		_spawn_enemy()

	_inventory.process(delta, self, player)

	# Boss event - one-shot, fires at the 3 minute mark.
	if not _boss_spawned and _elapsed_seconds >= 180.0:
		_boss_spawned = true
		_spawn_boss()

	# Flower-wall ring event - periodic cage around the player.
	_flower_event_timer -= delta
	if _flower_event_timer <= 0.0:
		_flower_event_timer = FLOWER_EVENT_INTERVAL
		_spawn_flower_ring()

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
	# XP bar removed from HUD. Progress is now shown only via level/kill text
	# in the top-left inventory panel.
	pass


func _input(event: InputEvent) -> void:
	# Backtick (`) toggles the debug overlay during play.
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_QUOTELEFT:
			debug_panel.visible = not debug_panel.visible


func _on_debug_xp_pressed() -> void:
	_on_crystal_collected(5)


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
	# Rare chest replaces the crystal drop entirely so the chest is easy to spot.
	if randf() < CHEST_DROP_CHANCE:
		var chest = CHEST_SCENE.instantiate()
		chest.global_position = spawn_position
		pickups.add_child(chest)
		chest.opened.connect(_on_chest_opened)
		return
	if randf() > CRYSTAL_DROP_CHANCE:
		return
	var crystal = CRYSTAL_SCENE.instantiate()
	crystal.global_position = spawn_position
	pickups.add_child(crystal)
	crystal.set_gem(1, 0)
	crystal.collected.connect(_on_crystal_collected)


## Chest pickup -> slot-machine roll. Order of precedence for the winner:
##   1. A ready evolution (weapon at >= EVOLUTION_MIN_LEVEL + paired passive)
##   2. A random non-maxed weapon level-up
##   3. A random non-maxed passive rank-up
## The strip of candidates is shuffled and the highlight rolls across them,
## decelerating until it lands on the predetermined winner.
func _on_chest_opened() -> void:
	if _chest_roll_active:
		return
	_chest_roll_active = true
	Sfx.play("levelup")

	var winner_id: String = ""
	var winner_label: String = ""
	var winner_icon: String = ""

	var evo_base: String = UpgradeCatalog.find_ready_evolution(_inventory, _passive_ranks)
	if not evo_base.is_empty():
		var recipe: Dictionary = UpgradeCatalog.EVOLUTIONS[evo_base]
		winner_id = "evolve:%s" % evo_base
		winner_label = "EVOLUTION!  %s" % str(recipe["evo_name"])
		var base_w: Weapon = _inventory.get_weapon(evo_base)
		if base_w != null:
			winner_icon = base_w.icon_path

	if winner_id.is_empty():
		var level_ups: Array = []
		for w in _inventory.weapons:
			if WeaponRegistry.is_evolution(w.id):
				continue
			if not w.is_max_level():
				level_ups.append(w)
		if not level_ups.is_empty():
			var pick: Weapon = level_ups[randi() % level_ups.size()]
			winner_id = "level_weapon:%s" % pick.id
			winner_label = "%s  Lv %d" % [pick.display_name, pick.level + 1]
			winner_icon = pick.icon_path

	if winner_id.is_empty():
		var passive_ids: Array = []
		for pid in UpgradeCatalog.PASSIVES.keys():
			if int(_passive_ranks.get(pid, 0)) < UpgradeCatalog.MAX_PASSIVE_RANK:
				passive_ids.append(pid)
		if not passive_ids.is_empty():
			var ppick: String = passive_ids[randi() % passive_ids.size()]
			winner_id = "passive:%s" % ppick
			var p: Dictionary = UpgradeCatalog.PASSIVES[ppick]
			winner_label = "%s  +1 rank" % str(p["title"])
			winner_icon = str(p["icon"])

	if winner_id.is_empty():
		_chest_roll_active = false
		return

	var candidates: Array = _build_chest_candidates(winner_id, winner_label, winner_icon)
	var winner_idx: int = 0
	for i in candidates.size():
		if candidates[i]["id"] == winner_id:
			winner_idx = i
			break

	var overlay := _build_chest_roll_overlay(candidates)
	add_child(overlay)
	get_tree().paused = true
	await _animate_chest_roll(overlay, winner_idx, winner_label)
	_apply_chest_winner(winner_id)
	get_tree().paused = false
	if is_instance_valid(overlay):
		overlay.queue_free()
	_chest_roll_active = false


func _apply_chest_winner(winner_id: String) -> void:
	if winner_id.begins_with("evolve:"):
		var base_id: String = winner_id.substr("evolve:".length())
		_evolve_weapon(base_id)
	else:
		_apply_upgrade(winner_id)


func _evolve_weapon(base_id: String) -> void:
	if not UpgradeCatalog.EVOLUTIONS.has(base_id):
		return
	var recipe: Dictionary = UpgradeCatalog.EVOLUTIONS[base_id]
	var evo_id: String = str(recipe["evo"])
	# Clean up any aura the base weapon attached as a child of the player
	# (Garlic) so the evolved version can install its own visual cleanly.
	var base_w: Weapon = _inventory.get_weapon(base_id)
	if base_w != null and "_aura" in base_w:
		var aura: Variant = base_w.get("_aura")
		if aura != null and is_instance_valid(aura):
			aura.queue_free()
		base_w.set("_aura", null)
	_inventory.remove_weapon(base_id)
	var evo: Weapon = WeaponRegistry.create(evo_id)
	if evo != null:
		_inventory.add_weapon(evo)
	_refresh_inv_hud_icons()


## Build the candidate strip: the winner plus several random filler icons drawn
## from the weapon + passive catalogs, then shuffled so the winner sits at a
## random index.
func _build_chest_candidates(winner_id: String, winner_label: String, winner_icon: String) -> Array:
	var list: Array = []
	list.append({ "id": winner_id, "label": winner_label, "icon": winner_icon })

	var filler: Array = []
	for wid in UpgradeCatalog.WEAPONS.keys():
		if WeaponRegistry.is_evolution(wid):
			continue
		var wcfg: Dictionary = UpgradeCatalog.WEAPONS[wid]
		filler.append({ "id": "filler:%s" % wid, "label": str(wcfg["name"]), "icon": str(wcfg["icon"]) })
	for pid in UpgradeCatalog.PASSIVES.keys():
		var pcfg: Dictionary = UpgradeCatalog.PASSIVES[pid]
		filler.append({ "id": "filler:%s" % pid, "label": str(pcfg["title"]), "icon": str(pcfg["icon"]) })
	filler.shuffle()
	var want: int = 6
	while not filler.is_empty() and list.size() < want + 1:
		list.append(filler.pop_back())

	list.shuffle()
	return list


func _build_chest_roll_overlay(candidates: Array) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 110
	layer.process_mode = Node.PROCESS_MODE_ALWAYS

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.10, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 24)
	margin.add_theme_constant_override(&"margin_top", 18)
	margin.add_theme_constant_override(&"margin_right", 24)
	margin.add_theme_constant_override(&"margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override(&"separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Treasure Chest"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 32)
	vbox.add_child(title)

	var strip := HBoxContainer.new()
	strip.add_theme_constant_override(&"separation", 8)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(strip)

	var slot_panels: Array = []
	for c in candidates:
		var slot := PanelContainer.new()
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.08, 0.10, 0.18, 1.0)
		slot_style.set_border_width_all(2)
		slot_style.border_color = Color(0.4, 0.42, 0.55, 1.0)
		slot_style.set_corner_radius_all(6)
		slot.add_theme_stylebox_override(&"panel", slot_style)

		var smargin := MarginContainer.new()
		smargin.add_theme_constant_override(&"margin_left", 6)
		smargin.add_theme_constant_override(&"margin_top", 6)
		smargin.add_theme_constant_override(&"margin_right", 6)
		smargin.add_theme_constant_override(&"margin_bottom", 6)
		slot.add_child(smargin)

		var tex_rect := TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(72, 72)
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_tex := Weapon.load_icon(str(c.get("icon", "")))
		if icon_tex != null:
			tex_rect.texture = icon_tex
		smargin.add_child(tex_rect)

		strip.add_child(slot)
		slot_panels.append(slot)

	var result_label := Label.new()
	result_label.name = "ResultLabel"
	result_label.text = ""
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override(&"font_size", 26)
	result_label.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.32))
	vbox.add_child(result_label)

	layer.set_meta("slots", slot_panels)
	return layer


func _animate_chest_roll(overlay: CanvasLayer, winner_idx: int, winner_label: String) -> void:
	var slots: Array = overlay.get_meta("slots", [])
	if slots.is_empty():
		return
	var n: int = slots.size()
	# At least 2 full passes then enough extra to land on winner_idx.
	var base_steps: int = n * 3
	var landing_offset: int = (winner_idx - (base_steps % n) + n) % n
	var total_steps: int = base_steps + landing_offset + 1
	var step_t: float = 0.05
	for i in total_steps:
		var idx: int = i % n
		_highlight_slot(slots, idx)
		# get_tree().create_timer respects pause by default; pass process_always=true.
		await get_tree().create_timer(step_t, true).timeout
		if i > total_steps - 8:
			step_t *= 1.30
		elif i > total_steps / 2:
			step_t *= 1.07
	# Show result text and hold briefly.
	var rl: Node = overlay.find_child("ResultLabel", true, false)
	if rl is Label:
		(rl as Label).text = winner_label
	await get_tree().create_timer(1.1, true).timeout


func _highlight_slot(slots: Array, idx: int) -> void:
	for i in slots.size():
		var slot: PanelContainer = slots[i] as PanelContainer
		if slot == null:
			continue
		var sb: StyleBoxFlat = slot.get_theme_stylebox(&"panel") as StyleBoxFlat
		if sb == null:
			continue
		if i == idx:
			sb.border_color = Color(1.0, 0.85, 0.32, 1.0)
			sb.set_border_width_all(4)
		else:
			sb.border_color = Color(0.4, 0.42, 0.55, 1.0)
			sb.set_border_width_all(2)


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
		screen.set_choices(_upgrade_catalog.get_choices(_inventory, _passive_ranks))
	add_child(screen)
	await screen.acknowledged
	if is_instance_valid(screen) and screen.has_method(&"get_selected_upgrade_id"):
		_apply_upgrade(screen.get_selected_upgrade_id())
	get_tree().paused = false


func _apply_upgrade(choice_id: String) -> void:
	if choice_id.is_empty():
		return
	# Only passive choices carry a per-id rank counter; weapon picks are tracked
	# inside the inventory itself.
	if choice_id.begins_with("passive:"):
		var pid := choice_id.substr("passive:".length())
		_passive_ranks[pid] = int(_passive_ranks.get(pid, 0)) + 1
	_upgrade_catalog.apply_choice(choice_id, self, player)
	_refresh_inv_hud_icons()


## Catalog calls this for "new_weapon:<id>" picks.
func grant_weapon(weapon_id: String) -> void:
	if _inventory.has_weapon(weapon_id):
		return
	var w := WeaponRegistry.create(weapon_id)
	if w != null:
		_inventory.add_weapon(w)


## Catalog calls this for "level_weapon:<id>" picks.
func level_up_weapon(weapon_id: String) -> void:
	var w := _inventory.get_weapon(weapon_id)
	if w != null:
		w.level_up()


## Passive-stat bonuses apply to every owned weapon at once.
func apply_global_damage_bonus(amount: int) -> void:
	for w in _inventory.weapons:
		w.dmg_bonus += amount


func apply_global_range_bonus(amount: float) -> void:
	for w in _inventory.weapons:
		w.range_bonus += amount


func apply_global_cooldown_bonus(delta_amount: float) -> void:
	for w in _inventory.weapons:
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
	lines.append("Passives")
	if _passive_ranks.is_empty():
		lines.append("  (none yet)")
	else:
		for id in _passive_ranks.keys():
			var rank := int(_passive_ranks[id])
			var title: String = id
			if UpgradeCatalog.PASSIVES.has(id):
				title = str(UpgradeCatalog.PASSIVES[id]["title"])
			lines.append("  %s  x%d" % [title, rank])
	return "\n".join(lines)


func _refresh_inventory_panel() -> void:
	inventory_body.text = _build_inventory_text(true)
	_populate_weapon_icon_row(pause_inv_weapon_row, PAUSE_WEAPON_ICON_SIZE, false)
	_populate_recipes()


func _populate_recipes() -> void:
	if inv_recipes_box == null:
		return
	for child in inv_recipes_box.get_children():
		child.queue_free()
	for base_id in UpgradeCatalog.EVOLUTIONS.keys():
		var recipe: Dictionary = UpgradeCatalog.EVOLUTIONS[base_id]
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override(&"separation", 6)

		var icon_size := Vector2(36, 36)
		var weapon_icon_path: String = str(UpgradeCatalog.WEAPONS[base_id]["icon"])
		var passive_id: String = str(recipe["passive"])
		var passive_icon_path: String = str(UpgradeCatalog.PASSIVES[passive_id]["icon"])

		row.add_child(_recipe_icon(weapon_icon_path, icon_size))
		row.add_child(_recipe_label("+", 22, Color(0.85, 0.85, 0.95)))
		row.add_child(_recipe_icon(passive_icon_path, icon_size))
		row.add_child(_recipe_label("=", 22, Color(0.85, 0.85, 0.95)))
		row.add_child(_recipe_label(str(recipe["evo_name"]), 20, Color(1.0, 0.85, 0.32)))
		inv_recipes_box.add_child(row)


func _recipe_icon(path: String, size: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	var tex := Weapon.load_icon(path)
	if tex != null:
		tr.texture = tex
	tr.custom_minimum_size = size
	tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tr


func _recipe_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## Rebuild the live HUD strips. Called whenever inventory changes (gain/level
## a weapon, take a passive). Cheap: few children, swapped at most per level-up.
func _refresh_inv_hud_icons() -> void:
	_populate_weapon_icon_row(inv_hud_weapon_row, WEAPON_ICON_SIZE, true)
	_populate_passive_icon_row(inv_hud_passive_row, PASSIVE_ICON_SIZE)


func _populate_passive_icon_row(row: HBoxContainer, icon_size: Vector2) -> void:
	if row == null:
		return
	for child in row.get_children():
		child.queue_free()
	for pid in UpgradeCatalog.PASSIVES.keys():
		var rank: int = int(_passive_ranks.get(pid, 0))
		if rank <= 0:
			continue
		var pcfg: Dictionary = UpgradeCatalog.PASSIVES[pid]
		var tex := Weapon.load_icon(str(pcfg["icon"]))
		if tex == null:
			continue
		var slot := VBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_theme_constant_override(&"separation", 3)

		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = icon_size
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.tooltip_text = "%s  %d/%d" % [str(pcfg["title"]), rank, UpgradeCatalog.MAX_PASSIVE_RANK]
		slot.add_child(rect)
		slot.add_child(_build_level_dots(rank, UpgradeCatalog.MAX_PASSIVE_RANK))
		row.add_child(slot)


func _populate_weapon_icon_row(row: HBoxContainer, icon_size: Vector2, with_dots: bool) -> void:
	if row == null:
		return
	for child in row.get_children():
		child.queue_free()
	for w in _inventory.weapons:
		var tex := Weapon.load_icon(w.icon_path)
		if tex == null:
			continue
		var slot := VBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_theme_constant_override(&"separation", 4)

		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = icon_size
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.tooltip_text = "%s  Lv %d" % [w.display_name, w.level]
		slot.add_child(rect)

		if with_dots:
			slot.add_child(_build_level_dots(w.level, Weapon.MAX_LEVEL))
		row.add_child(slot)


func _build_level_dots(current: int, max_lvl: int) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 3)
	for i in max_lvl:
		var dot := ColorRect.new()
		dot.custom_minimum_size = LEVEL_DOT_SIZE
		dot.color = LEVEL_DOT_FILLED if i < current else LEVEL_DOT_EMPTY
		box.add_child(dot)
	return box


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
		# Stationary enemies (flower wall) act as immovable obstacles - they
		# still appear in the bucket so others get pushed away from them, but
		# they themselves are never displaced by the separation pass.
		if "stationary" in body and bool(body.get("stationary")):
			continue
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
					# If the obstacle (other) is immovable, push body the FULL
					# penetration this frame so it doesn't slowly squeeze through.
					var other_static: bool = "stationary" in other and bool(other.get("stationary"))
					var push: float = (1.0 if other_static else ENEMY_SEP_PUSH)
					var pen_x := min_sep - ax
					var pen_y := min_sep - ay
					# Resolve along the shallower axis (smaller MTV).
					if pen_x < pen_y:
						var sx := 1.0 if d.x >= 0.0 else -1.0
						body.global_position.x += sx * pen_x * push
					else:
						var sy := 1.0 if d.y >= 0.0 else -1.0
						body.global_position.y += sy * pen_y * push


func _cull_distant_enemies() -> void:
	var ppos := player.global_position
	var r2 := ENEMY_DESPAWN_RADIUS * ENEMY_DESPAWN_RADIUS
	for node in enemies.get_children():
		if not (node is Node2D):
			continue
		if "cullable" in node and not bool(node.get("cullable")):
			continue
		if (node as Node2D).global_position.distance_squared_to(ppos) > r2:
			node.queue_free()


func _format_clock(seconds: float) -> String:
	var s := int(floor(seconds))
	var m := s / 60
	s %= 60
	return "%d:%02d" % [m, s]


func _apply_difficulty_to_enemy(enemy: CharacterBody2D, cfg: Dictionary) -> void:
	var t := _elapsed_seconds
	# HP scaling is per-type: each entry has its own hp_scale_cap so weak
	# enemies (bats) stay one-shot all run while tankier ones still grow.
	# Ramp slope itself is gentler than before (t/70 vs t/55).
	var cap: float = float(cfg.get("hp_scale_cap", 3.0))
	var hp_mult: float = 1.0 + minf(t / 70.0, cap)
	var spd_mult: float = 1.0 + minf(t / 140.0, 0.55)
	enemy.max_health = int(round(float(cfg["hp_base"]) * hp_mult))
	enemy.move_speed = float(cfg["speed_base"]) * spd_mult


## Picks a normal enemy type based on elapsed time:
##   t <  60s -> pipeestrello only
##   t >= 60s -> + skeleton
##   t >= 120s -> + mudman1, mudman2
func _pick_normal_enemy_type() -> String:
	var t := _elapsed_seconds
	var pool: Array[String] = ["pipeestrello"]
	if t >= 60.0:
		# Once skeletons unlock, weight them a bit higher than bats so the
		# population visibly shifts as the run progresses.
		pool.append("skeleton")
		pool.append("skeleton")
	if t >= 120.0:
		pool.append("mudman1")
		pool.append("mudman2")
		pool.append("mudman2")
	return pool[randi() % pool.size()]


func _spawn_enemy() -> void:
	_spawn_one_enemy(_pick_normal_enemy_type(), _random_spawn_on_arena_edge())
	var t := _elapsed_seconds
	# Extra spawns kick in earlier (30s) and ramp higher (up to ~65% chance) for
	# a thicker mid/late game.
	if t > 30.0 and randf() < clampf((t - 30.0) / 150.0, 0.0, 0.65):
		_spawn_one_enemy(_pick_normal_enemy_type(), _random_spawn_on_arena_edge())
	# Second extra spawn past 90s for true swarm pressure.
	if t > 90.0 and randf() < clampf((t - 90.0) / 240.0, 0.0, 0.5):
		_spawn_one_enemy(_pick_normal_enemy_type(), _random_spawn_on_arena_edge())


func _spawn_one_enemy(type_id: String, spawn_pos: Vector2) -> CharacterBody2D:
	var cfg: Dictionary = ENEMY_TYPES.get(type_id, ENEMY_TYPES["pipeestrello"])
	var enemy: CharacterBody2D = ENEMY_SCENE.instantiate()
	enemy.frames_root = str(cfg["frames_root"])
	enemy.walk_frame_prefix = str(cfg["walk_prefix"])
	enemy.death_frame_prefix = str(cfg["death_prefix"])
	enemy.target_height = float(cfg["target_height"])
	enemy.walk_frame_duration = float(cfg["walk_dur"])
	enemy.death_frame_duration = float(cfg["death_dur"])
	enemy.stationary = bool(cfg.get("stationary", false))
	enemy.cullable = bool(cfg.get("cullable", true))
	enemy.sprite_default_faces_right = bool(cfg.get("faces_right", false))
	enemy.target = player
	enemy.global_position = spawn_pos
	_apply_difficulty_to_enemy(enemy, cfg)
	# Elite roll - applies AFTER difficulty so it doubles the already-scaled HP.
	if bool(cfg.get("can_be_elite", true)) and not enemy.stationary and randf() < ELITE_SPAWN_CHANCE:
		enemy.is_elite = true
		enemy.max_health = int(round(float(enemy.max_health) * ELITE_HP_MULT))
	enemy.died.connect(_on_enemy_died)
	enemies.add_child(enemy)
	return enemy


func _spawn_boss() -> void:
	_spawn_one_enemy("batboss", _random_spawn_on_arena_edge())


## Spawns flowerwall enemies in a densely packed ring around the player.
## They're stationary, so they form a temporary cage the player must shoot
## through; the inner/outer ring offset gives the wall visible thickness.
func _spawn_flower_ring() -> void:
	var inner_count := 56
	var outer_count := 64
	var inner_radius := 286.0
	var outer_radius := 318.0
	var center := player.global_position
	for i in inner_count:
		var a: float = float(i) / float(inner_count) * TAU
		_spawn_one_enemy("flowerwall", center + Vector2(cos(a), sin(a)) * inner_radius)
	# Outer ring offset by half a step so the two layers interleave.
	var half_step: float = TAU / float(outer_count) * 0.5
	for i in outer_count:
		var a: float = float(i) / float(outer_count) * TAU + half_step
		_spawn_one_enemy("flowerwall", center + Vector2(cos(a), sin(a)) * outer_radius)
