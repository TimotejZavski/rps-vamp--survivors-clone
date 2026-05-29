extends Control

signal retry_requested
signal main_menu_requested

@onready var _stats_label: Label = $CenterContainer/VBoxContainer/StatsLabel
@onready var _retry_button: Button = $CenterContainer/VBoxContainer/RetryButton


func _ready() -> void:
	_stats_label.text = _build_stats_text()
	_retry_button.grab_focus()


func _build_stats_text() -> String:
	var t := RunConfig.last_run_time_seconds
	var s := int(floor(t))
	var m := s / 60
	s %= 60

	var lines: Array[String] = []
	lines.append("%s" % RunConfig.display_name)
	lines.append("Survived %d:%02d   ·   Level %d   ·   %d kills" % [m, s, RunConfig.last_run_level, RunConfig.last_run_kills])
	lines.append("Gold earned: %d" % RunConfig.last_run_gold)
	lines.append("")

	if not RunConfig.last_run_weapons.is_empty():
		lines.append("Weapons:  %s" % ", ".join(RunConfig.last_run_weapons))
	if not RunConfig.last_run_passives.is_empty():
		lines.append("Passives:  %s" % ", ".join(RunConfig.last_run_passives))

	return "\n".join(lines)


func _on_retry_button_pressed() -> void:
	Sfx.play("select")
	retry_requested.emit()


func _on_main_menu_button_pressed() -> void:
	Sfx.play("select")
	main_menu_requested.emit()
