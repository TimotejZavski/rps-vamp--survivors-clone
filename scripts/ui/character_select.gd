extends Control

signal run_requested(character_id: String)
signal back_requested

const ROWS := [
	{"id": "wizard", "label": "Imelda",   "desc": "Magic Wand"},
	{"id": "knight", "label": "Krochi",   "desc": "Sword Slash"},
	{"id": "cleric", "label": "Clerici",  "desc": "Holy Aura"},
]

const PORTRAIT_BY_ID := {
	"wizard": "res://assets/characters/imelda/portrait.png",
	"knight": "res://assets/characters/knight/portrait.png",
	"cleric": "res://assets/characters/cleric/portrait.png",
}

const CARD_SIZE := Vector2(220, 250)
const COLOR_IDLE := Color(0.08, 0.10, 0.18, 0.85)
const COLOR_HOVER := Color(0.18, 0.22, 0.36, 0.95)
const COLOR_SELECTED := Color(0.95, 0.78, 0.30, 1.0)

var _selected_id: String = ""
var _cards: Dictionary = {}

@onready var _grid: GridContainer = $Center/Panel/Margin/VBox/Grid
@onready var _info: Label = $Center/Panel/Margin/VBox/InfoLabel
@onready var _begin_button: Button = $Center/Panel/Margin/VBox/ButtonRow/BeginButton


func _ready() -> void:
	for row in ROWS:
		var id: String = str(row.id)
		var card := _build_card(id, str(row.label), str(row.desc))
		_grid.add_child(card)
		_cards[id] = card
	_select(ROWS[0].id)
	_begin_button.grab_focus()


func _build_card(id: String, label_text: String, desc_text: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = CARD_SIZE
	btn.focus_mode = Control.FOCUS_ALL
	btn.toggle_mode = false
	btn.flat = true
	btn.clip_text = false

	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_IDLE
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.55, 0.55, 0.6, 0.9)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", _make_style(COLOR_HOVER, Color(0.85, 0.85, 0.95, 1.0)))
	btn.add_theme_stylebox_override("pressed", _make_style(COLOR_HOVER, COLOR_SELECTED))
	btn.add_theme_stylebox_override("focus", _make_style(COLOR_HOVER, COLOR_SELECTED))

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(vbox)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.78))
	vbox.add_child(name_label)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(140, 140)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tex := _load_png_texture(PORTRAIT_BY_ID.get(id, ""))
	if tex != null:
		portrait.texture = tex
	vbox.add_child(portrait)

	var desc_label := Label.new()
	desc_label.text = desc_text
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 18)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	vbox.add_child(desc_label)

	btn.pressed.connect(_on_card_pressed.bind(id))
	btn.gui_input.connect(_on_card_gui_input.bind(id))
	return btn


func _make_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(3)
	sb.border_color = border
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _select(id: String) -> void:
	if not _cards.has(id):
		return
	_selected_id = id
	for cid in _cards.keys():
		var card: Button = _cards[cid]
		var is_sel: bool = str(cid) == id
		_apply_card_styles(card, is_sel)
	var row: Variant = _find_row(id)
	if row != null:
		_info.text = "Selected: %s  -  %s" % [row.label, row.desc]


func _apply_card_styles(card: Button, is_selected: bool) -> void:
	if is_selected:
		var sel_bg := Color(0.32, 0.26, 0.08, 1.0)
		var sel_border := COLOR_SELECTED
		card.add_theme_stylebox_override("normal",  _make_thick_style(sel_bg, sel_border))
		card.add_theme_stylebox_override("hover",   _make_thick_style(sel_bg.lightened(0.08), sel_border))
		card.add_theme_stylebox_override("pressed", _make_thick_style(sel_bg, sel_border))
		card.add_theme_stylebox_override("focus",   _make_thick_style(sel_bg, sel_border))
		card.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		var idle_border := Color(0.55, 0.55, 0.6, 0.9)
		card.add_theme_stylebox_override("normal",  _make_style(COLOR_IDLE, idle_border))
		card.add_theme_stylebox_override("hover",   _make_style(COLOR_HOVER, Color(0.85, 0.85, 0.95, 1.0)))
		card.add_theme_stylebox_override("pressed", _make_style(COLOR_HOVER, idle_border))
		card.add_theme_stylebox_override("focus",   _make_style(COLOR_HOVER, idle_border))
		card.modulate = Color(0.78, 0.78, 0.82, 1.0)


func _make_thick_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(5)
	sb.border_color = border
	sb.shadow_color = Color(border.r, border.g, border.b, 0.55)
	sb.shadow_size = 6
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _find_row(id: String) -> Variant:
	for row in ROWS:
		if str(row.id) == id:
			return row
	return null


func _on_card_pressed(id: String) -> void:
	Sfx.play("select")
	_select(id)


func _on_card_gui_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.double_click:
		_select(id)
		_on_begin_pressed()


func _load_png_texture(path: String) -> Texture2D:
	if path == "":
		return null
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _on_begin_pressed() -> void:
	Sfx.play("select")
	run_requested.emit(_selected_id if _selected_id != "" else str(ROWS[0].id))


func _on_back_pressed() -> void:
	Sfx.play("select")
	back_requested.emit()
