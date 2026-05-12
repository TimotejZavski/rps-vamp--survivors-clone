extends CanvasLayer

signal acknowledged

const CHOICE_SIZE := Vector2(520, 88)
const COLOR_IDLE_BG := Color(0.09, 0.10, 0.18, 0.92)
const COLOR_HOVER_BG := Color(0.16, 0.20, 0.34, 0.96)
const COLOR_BORDER_IDLE := Color(0.55, 0.55, 0.65, 0.9)
const COLOR_BORDER_HOVER := Color(0.97, 0.85, 0.45, 1.0)
const COLOR_LABEL := Color(0.97, 0.92, 0.78, 1.0)
const COLOR_DESC := Color(0.78, 0.82, 0.92, 1.0)

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
	_title.text = "Level Up!  ·  Lv %d" % _level
	for child in _choices_box.get_children():
		child.queue_free()

	selected_upgrade_id = ""

	if _choices.is_empty():
		_hint.text = "Pick an upgrade next."
		_continue_button.visible = true
		_continue_button.grab_focus()
		return

	_hint.text = "Choose one bonus for this run."
	_continue_button.visible = false

	var first_button: Button = null
	for choice in _choices:
		var button := _build_choice_button(str(choice["label"]), str(choice["description"]), str(choice["id"]))
		_choices_box.add_child(button)
		if first_button == null:
			first_button = button

	if first_button != null:
		first_button.grab_focus()


func _build_choice_button(label_text: String, desc_text: String, choice_id: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = CHOICE_SIZE
	btn.flat = true
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_stylebox_override("normal",  _make_style(COLOR_IDLE_BG,  COLOR_BORDER_IDLE,  2))
	btn.add_theme_stylebox_override("hover",   _make_style(COLOR_HOVER_BG, COLOR_BORDER_HOVER, 4))
	btn.add_theme_stylebox_override("pressed", _make_style(COLOR_HOVER_BG, COLOR_BORDER_HOVER, 4))
	btn.add_theme_stylebox_override("focus",   _make_style(COLOR_HOVER_BG, COLOR_BORDER_HOVER, 4))

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 18
	vbox.offset_right = -18
	vbox.offset_top = 10
	vbox.offset_bottom = -10
	btn.add_child(vbox)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", COLOR_LABEL)
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = desc_text
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 18)
	desc_label.add_theme_color_override("font_color", COLOR_DESC)
	vbox.add_child(desc_label)

	btn.pressed.connect(_on_choice_pressed.bind(choice_id))
	return btn


func _make_style(bg: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _on_choice_pressed(choice_id: String) -> void:
	Sfx.play("select")
	selected_upgrade_id = choice_id
	acknowledged.emit()
	call_deferred("queue_free")


func _on_continue_pressed() -> void:
	Sfx.play("select")
	acknowledged.emit()
	call_deferred("queue_free")
