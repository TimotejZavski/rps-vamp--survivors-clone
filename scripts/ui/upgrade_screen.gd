extends CanvasLayer

signal acknowledged

const CHOICE_SIZE := Vector2(580, 112)
const ICON_SIZE := Vector2(72, 72)
const COLOR_IDLE_BG := Color(0.09, 0.10, 0.18, 0.92)
const COLOR_HOVER_BG := Color(0.16, 0.20, 0.34, 0.96)
const COLOR_BORDER_IDLE := Color(0.55, 0.55, 0.65, 0.9)
const COLOR_BORDER_HOVER := Color(0.97, 0.85, 0.45, 1.0)
const COLOR_LABEL := Color(0.97, 0.92, 0.78, 1.0)
const COLOR_DESC := Color(0.78, 0.82, 0.92, 1.0)
const COLOR_FOOTER := Color(0.65, 0.78, 1.0, 1.0)
const COLOR_DELTA := Color(1.0, 0.85, 0.32, 1.0)

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
		var button := _build_choice_button(choice)
		_choices_box.add_child(button)
		if first_button == null:
			first_button = button

	if first_button != null:
		first_button.grab_focus()


func _build_choice_button(choice: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = CHOICE_SIZE
	btn.flat = true
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_stylebox_override("normal",  _make_style(COLOR_IDLE_BG,  COLOR_BORDER_IDLE,  2))
	btn.add_theme_stylebox_override("hover",   _make_style(COLOR_HOVER_BG, COLOR_BORDER_HOVER, 4))
	btn.add_theme_stylebox_override("pressed", _make_style(COLOR_HOVER_BG, COLOR_BORDER_HOVER, 4))
	btn.add_theme_stylebox_override("focus",   _make_style(COLOR_HOVER_BG, COLOR_BORDER_HOVER, 4))

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override(&"separation", 14)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 16
	hbox.offset_right = -16
	hbox.offset_top = 10
	hbox.offset_bottom = -10
	btn.add_child(hbox)

	# Left: icon
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = ICON_SIZE
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path := str(choice.get("icon", ""))
	if not icon_path.is_empty():
		var tex := Weapon.load_icon(icon_path)
		if tex != null:
			icon_rect.texture = tex
	hbox.add_child(icon_rect)

	# Right column: title row + description + delta
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override(&"separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vbox)

	# Title row: name | footer (level/rank progression)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override(&"separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_row)

	var title_label := Label.new()
	title_label.text = str(choice.get("title", ""))
	title_label.add_theme_font_size_override(&"font_size", 24)
	title_label.add_theme_color_override(&"font_color", COLOR_LABEL)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)

	var footer_text := str(choice.get("footer", ""))
	if not footer_text.is_empty():
		var footer_label := Label.new()
		footer_label.text = footer_text
		footer_label.add_theme_font_size_override(&"font_size", 17)
		footer_label.add_theme_color_override(&"font_color", COLOR_FOOTER)
		footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		title_row.add_child(footer_label)

	# Description
	var desc_text := str(choice.get("description", ""))
	if not desc_text.is_empty():
		var desc_label := Label.new()
		desc_label.text = desc_text
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override(&"font_size", 16)
		desc_label.add_theme_color_override(&"font_color", COLOR_DESC)
		vbox.add_child(desc_label)

	# Delta numbers (gold, prominent)
	var delta_text := str(choice.get("delta", ""))
	if not delta_text.is_empty():
		var delta_label := Label.new()
		delta_label.text = delta_text
		delta_label.add_theme_font_size_override(&"font_size", 18)
		delta_label.add_theme_color_override(&"font_color", COLOR_DELTA)
		vbox.add_child(delta_label)

	btn.pressed.connect(_on_choice_pressed.bind(str(choice.get("id", ""))))
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
