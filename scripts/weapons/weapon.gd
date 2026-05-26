class_name Weapon
extends RefCounted
## Base class for all weapons. Subclasses override get_* and _fire().

const MAX_LEVEL := 8

var id: String = ""
var display_name: String = ""
var icon_path: String = ""
var level: int = 1
var dmg_bonus: int = 0
var range_bonus: float = 0.0
## Negative = faster.
var cd_bonus: float = 0.0

var _cooldown_timer: float = 0.0

static var _icon_cache: Dictionary = {}


static func load_icon(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _icon_cache.has(path):
		return _icon_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		_icon_cache[path] = tex
	return tex


func get_cooldown() -> float:
	return 1.0


func get_damage() -> int:
	return 1


func get_range() -> float:
	return 100.0


func describe_stats() -> String:
	return "dmg %d  cd %.2fs" % [get_damage(), get_cooldown()]


func process(delta: float, game: Node, player: Node2D) -> void:
	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0:
		_cooldown_timer = maxf(0.05, get_cooldown())
		_fire(game, player)


func _fire(_game: Node, _player: Node2D) -> void:
	pass


func level_up() -> void:
	level = mini(MAX_LEVEL, level + 1)


func is_max_level() -> bool:
	return level >= MAX_LEVEL
