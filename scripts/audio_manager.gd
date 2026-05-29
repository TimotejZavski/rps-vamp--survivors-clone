extends Node

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

var _players: Dictionary = {}


func _ready() -> void:
	# Dedicated buses let the Settings screen control music and SFX volume
	# independently. Created at runtime so no .tres bus layout is required.
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_load("select",   "res://assets/music/select.ogg")
	_load("levelup",  "res://assets/music/levelup.ogg")
	_load("gameover", "res://assets/music/gameover.ogg")
	_load("collect",  "res://assets/music/collect.ogg")


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _load(key: String, path: String) -> void:
	var stream: AudioStream = load(path)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = SFX_BUS
	add_child(player)
	_players[key] = player


func play(key: String) -> void:
	if _players.has(key):
		(_players[key] as AudioStreamPlayer).play()
