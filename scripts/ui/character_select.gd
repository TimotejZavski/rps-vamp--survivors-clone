extends Control

signal run_requested(character_id: String)
signal back_requested

const ROWS := [
	{"id": "wizard", "label": "Imelda - Magic Wand"},
	{"id": "knight", "label": "Krochi - Sword Slash"},
	{"id": "cleric", "label": "Suor Clerici - Holy Aura"},
]

const PORTRAIT_BY_ID := {
	"wizard": "res://assets/characters/imelda/portrait.png",
	"knight": "res://assets/characters/knight/portrait.png",
	"cleric": "res://assets/characters/cleric/portrait.png",
}


func _ready() -> void:
	var list: ItemList = $Center/Panel/Margin/VBox/CharacterList
	list.fixed_icon_size = Vector2i(40, 40)
	list.item_activated.connect(_on_list_item_activated)
	for row in ROWS:
		var path: String = PORTRAIT_BY_ID.get(row.id, "")
		var icon: Texture2D = _load_png_texture(path) if path != "" else null
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


func _on_list_item_activated(_index: int) -> void:
	_on_begin_pressed()


func _on_begin_pressed() -> void:
	run_requested.emit(_get_selected_id())


func _on_back_pressed() -> void:
	back_requested.emit()
