extends Weapon
## Persistent pink aura around the player. Ticks damage to anything inside.

const ICON := "res://assets/icons/Sprite-Garlic.png"
const AURA_SCRIPT := preload("res://scripts/weapons/garlic_aura.gd")
const BASE_VISUAL_RADIUS := 64.0

## Visual + behavior knobs so Soul Eater can reuse this weapon as a red,
## larger, life-stealing aura.
var aura_tint: Color = Color(0.18, 0.38, 0.95)  # base blue
var aura_radius_mult: float = 1.0
var lifesteal_fraction: float = 0.0

var _aura: Node2D = null


func _init() -> void:
	id = "garlic"
	display_name = "Garlic"
	icon_path = ICON


func get_cooldown() -> float:
	# This is the damage-tick interval, not a fire cooldown.
	return maxf(0.25, 0.6 - float(level - 1) * 0.04 + cd_bonus)


func get_damage() -> int:
	return 6 + (level - 1) * 3 + dmg_bonus


func get_range() -> float:
	return 70.0 + float(level - 1) * 8.0 + range_bonus


func describe_stats() -> String:
	return "dmg %d  aura r%.0f" % [get_damage(), get_range()]


func _fire(game: Node, player: Node2D) -> void:
	_ensure_aura(player)
	var r := get_range() * aura_radius_mult
	var r2 := r * r
	var ppos := player.global_position
	var dmg: int = get_damage()
	var hits: int = 0
	for e in game.enemies.get_children():
		if not e.has_method(&"take_damage"):
			continue
		if "collision_layer" in e and int(e.get("collision_layer")) == 0:
			continue
		if ppos.distance_squared_to(e.global_position) > r2:
			continue
		e.take_damage(dmg)
		hits += 1
	if lifesteal_fraction > 0.0 and hits > 0 and player.has_method(&"heal"):
		var amt: int = int(round(float(dmg) * lifesteal_fraction * float(hits)))
		if amt > 0:
			player.heal(amt)


func _ensure_aura(player: Node2D) -> void:
	var target_scale: float = (get_range() * aura_radius_mult) / BASE_VISUAL_RADIUS
	if is_instance_valid(_aura):
		_aura.set("range_scale", target_scale)
		return
	var n := Node2D.new()
	n.set_script(AURA_SCRIPT)
	n.name = "GarlicAura"
	n.z_index = -8
	n.set("base_radius", BASE_VISUAL_RADIUS)
	n.set("range_scale", target_scale)
	n.set("tint", aura_tint)
	player.add_child(n)
	_aura = n
