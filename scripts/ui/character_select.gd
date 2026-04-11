extends Control

signal run_requested(character_id: String)
signal back_requested

const ROWS := [
	{"id": "wizard", "label": "Imelda — Magic Wand (placeholder)"},
	{"id": "knight", "label": "Knight — sword (placeholder)"},
	{"id": "cleric", "label": "Cleric — aura (placeholder)"},
]

const IMELDA_PORTRAIT := "res://assets/characters/imelda/portrait.png"


func _ready() -> void:
	var list: ItemList = $Center/Panel/Margin/VBox/CharacterList
	list.fixed_icon_size = Vector2i(40, 40)
	var portrait_tex := _load_png_texture(IMELDA_PORTRAIT)
	for row in ROWS:
		var icon: Texture2D = portrait_tex if row.id == "wizard" else null
		list.add_item(row.label, icon)
		list.set_item_metadata(list.item_count - 1, row.id)
	list.select(0)


func _load_png_texture(path: String) -> Texture2D:
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _get_selected_id() -> String:
	var list: ItemList = $Center/Panel/Margin/VBox/CharacterList
	var selected: PackedInt32Array = list.get_selected_items()
	if selected.size() == 0:
		return "wizard"
	return str(list.get_item_metadata(selected[0]))


func _on_begin_pressed() -> void:
	run_requested.emit(_get_selected_id())


func _on_back_pressed() -> void:
	back_requested.emit()
