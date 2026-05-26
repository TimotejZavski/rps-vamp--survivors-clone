extends Weapon
## Spawns N bibles that orbit the player for a few seconds, then rest, then repeat.

const ICON := "res://assets/icons/Sprite-King_Bible.png"
const RADIUS := 64.0
const ROT_SPEED := 3.0
const ACTIVE_TIME := 3.0
const REST_TIME := 1.8
const HIT_INTERVAL := 0.55
const HIT_RADIUS := 14.0

var _bibles: Array[Node2D] = []
var _active := false
var _phase_offset := 0.0
var _time_in_state := 0.0
var _hit_cd: Dictionary = {}


func _init() -> void:
	id = "king_bible"
	display_name = "King Bible"
	icon_path = ICON


func get_count() -> int:
	return 1 + (level - 1) / 2


func get_damage() -> int:
	return 14 + (level - 1) * 4 + dmg_bonus


func get_range() -> float:
	return RADIUS + range_bonus


func get_cooldown() -> float:
	return maxf(0.4, REST_TIME + cd_bonus)


func describe_stats() -> String:
	return "dmg %d  x%d orbit" % [get_damage(), get_count()]


## Override the base process() loop because this weapon has its own state machine
## (orbiting active phase, then resting). _fire is never called for it.
func process(delta: float, game: Node, player: Node2D) -> void:
	_time_in_state += delta
	if _active:
		_phase_offset += delta * ROT_SPEED
		_update_orbit(player, game, delta)
		if _time_in_state >= ACTIVE_TIME:
			_despawn_bibles()
			_active = false
			_time_in_state = 0.0
	else:
		if _time_in_state >= get_cooldown():
			_spawn_bibles(game, player)
			_active = true
			_time_in_state = 0.0


func _spawn_bibles(game: Node, player: Node2D) -> void:
	var count := get_count()
	_bibles.clear()
	for i in count:
		var b := _build_bible_node()
		var base_phase := float(i) / float(count) * TAU
		b.set_meta("base_phase", base_phase)
		b.global_position = player.global_position + Vector2(cos(base_phase), sin(base_phase)) * RADIUS
		game.projectiles.add_child(b)
		_bibles.append(b)
	_hit_cd.clear()


func _build_bible_node() -> Node2D:
	var n := Node2D.new()
	n.z_index = 32
	var tex := Weapon.load_icon(ICON)
	if tex != null:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var h := float(tex.get_height())
		if h > 0.0:
			spr.scale = Vector2.ONE * (22.0 / h)
		n.add_child(spr)
	return n


func _update_orbit(player: Node2D, game: Node, delta: float) -> void:
	var ppos := player.global_position
	var hit_r2 := HIT_RADIUS * HIT_RADIUS
	for b in _bibles:
		if not is_instance_valid(b):
			continue
		var base := float(b.get_meta("base_phase", 0.0))
		var phase := base + _phase_offset
		b.global_position = ppos + Vector2(cos(phase), sin(phase)) * RADIUS
		for e in game.enemies.get_children():
			if not e.has_method(&"take_damage"):
				continue
			if "collision_layer" in e and int(e.get("collision_layer")) == 0:
				continue
			if b.global_position.distance_squared_to(e.global_position) > hit_r2:
				continue
			var iid: int = e.get_instance_id()
			var cd_left: float = _hit_cd.get(iid, 0.0)
			if cd_left > 0.0:
				continue
			e.take_damage(get_damage())
			_hit_cd[iid] = HIT_INTERVAL
	for iid in _hit_cd.keys():
		_hit_cd[iid] = _hit_cd[iid] - delta


func _despawn_bibles() -> void:
	for b in _bibles:
		if is_instance_valid(b):
			b.queue_free()
	_bibles.clear()
