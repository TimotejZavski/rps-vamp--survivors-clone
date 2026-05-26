extends Control

signal main_menu_requested

@onready var _time_label: Label = $Center/Panel/Margin/VBox/Stats/TimeLabel
@onready var _kills_label: Label = $Center/Panel/Margin/VBox/Stats/KillsLabel
@onready var _level_label: Label = $Center/Panel/Margin/VBox/Stats/LevelLabel
@onready var _gold_label: Label = $Center/Panel/Margin/VBox/Stats/GoldLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	# RunConfig only carries time/level/kills; gold for this run was already
	# pushed into MetaSave by game.gd._finalize_run_summary().
	_time_label.text = "Time: %s" % _format_clock(RunConfig.last_run_time_seconds)
	_kills_label.text = "Kills: %d" % RunConfig.last_run_kills
	_level_label.text = "Level: %d" % RunConfig.last_run_level
	_gold_label.text = "Total gold: %d" % MetaSave.gold


static func _format_clock(seconds: float) -> String:
	var s := int(floor(seconds))
	var m := s / 60
	s %= 60
	return "%d:%02d" % [m, s]


func _on_main_menu_button_pressed() -> void:
	Sfx.play("select")
	main_menu_requested.emit()
