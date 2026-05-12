extends Node

var _players: Dictionary = {}


func _ready() -> void:
	_load("select",   "res://assets/music/select.ogg")
	_load("levelup",  "res://assets/music/levelup.ogg")
	_load("gameover", "res://assets/music/gameover.ogg")
	_load("collect",  "res://assets/music/collect.ogg")


func _load(key: String, path: String) -> void:
	var stream: AudioStream = load(path)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	_players[key] = player


func play(key: String) -> void:
	if _players.has(key):
		(_players[key] as AudioStreamPlayer).play()
