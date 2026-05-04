extends CanvasLayer

signal acknowledged

var _level: int = 2
var _choices: Array[Dictionary] = []
var selected_upgrade_id := ""

@onready var _title: Label = $Center/Panel/Margin/VBox/Title
@onready var _hint: Label = $Center/Panel/Margin/VBox/Hint
@onready var _choices_box: VBoxContainer = $Center/Panel/Margin/VBox/Choices
@onready var _continue_button: Button = $Center/Panel/Margin/VBox/ContinueButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"upgrade_screen")
	_rebuild()


func set_level(level: int) -> void:
	_level = level
	if is_node_ready():
		_rebuild()


func set_choices(choices: Array[Dictionary]) -> void:
	_choices = []
	for choice in choices:
		_choices.append(choice.duplicate(true))
	if is_node_ready():
		_rebuild()


func get_selected_upgrade_id() -> String:
	return selected_upgrade_id


func _rebuild() -> void:
	_title.text = "Level %d" % _level
	for child in _choices_box.get_children():
		child.queue_free()

	selected_upgrade_id = ""

	if _choices.is_empty():
		_hint.text = "Pick an upgrade next."
		_continue_button.visible = true
		_continue_button.grab_focus()
		return

	_hint.text = "Pick one bonus for this run."
	_continue_button.visible = false

	var first_button: Button = null
	for choice in _choices:
		var button := Button.new()
		button.custom_minimum_size = Vector2(340, 0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s\n%s" % [str(choice["label"]), str(choice["description"])]
		button.pressed.connect(_on_choice_pressed.bind(str(choice["id"])))
		_choices_box.add_child(button)
		if first_button == null:
			first_button = button

	if first_button != null:
		first_button.grab_focus()


func _on_choice_pressed(choice_id: String) -> void:
	selected_upgrade_id = choice_id
	acknowledged.emit()
	call_deferred("queue_free")


func _on_continue_pressed() -> void:
	acknowledged.emit()
	call_deferred("queue_free")
