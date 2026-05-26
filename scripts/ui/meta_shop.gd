extends Control

signal back_requested

const UPGRADE_CATALOG := preload("res://scripts/game/upgrade_catalog.gd")
const COIN_ICON := "res://assets/icons/24px-Sprite-Gold_Coin.png"

## Cost per rank (1..MAX_PASSIVE_RANK).
const RANK_COSTS := [50, 120, 250, 500, 1000]

const ROW_BG_IDLE := Color(0.09, 0.10, 0.18, 0.92)
const ROW_BG_MAXED := Color(0.12, 0.20, 0.13, 0.92)
const BORDER_IDLE := Color(0.45, 0.48, 0.60, 0.9)
const TITLE_COLOR := Color(0.97, 0.92, 0.78, 1.0)
const DESC_COLOR := Color(0.78, 0.82, 0.92, 1.0)
const DOT_FILLED := Color(1.0, 0.85, 0.32, 1.0)
const DOT_EMPTY := Color(0.30, 0.32, 0.40, 0.8)
const PRICE_COLOR := Color(1.0, 0.85, 0.32, 1.0)
const MAXED_COLOR := Color(0.6, 1.0, 0.65, 1.0)

@onready var _gold_label: Label = $Top/GoldRow/GoldLabel
@onready var _cards_box: VBoxContainer = $Center/Scroll/CardsBox
@onready var _gold_icon: TextureRect = $Top/GoldRow/GoldIcon


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tex := _load_icon(COIN_ICON)
	if tex != null:
		_gold_icon.texture = tex
	_refresh()


func _refresh() -> void:
	_gold_label.text = str(MetaSave.gold)
	for child in _cards_box.get_children():
		child.queue_free()
	for pid in UpgradeCatalog.PASSIVES.keys():
		_cards_box.add_child(_build_card(str(pid)))


func _build_card(pid: String) -> Control:
	var p: Dictionary = UpgradeCatalog.PASSIVES[pid]
	var rank: int = MetaSave.passive_rank(pid)
	var maxed: bool = rank >= UpgradeCatalog.MAX_PASSIVE_RANK
	var cost: int = _cost_for_rank(rank + 1)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", _row_style(maxed))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 14)
	margin.add_theme_constant_override(&"margin_top", 10)
	margin.add_theme_constant_override(&"margin_right", 14)
	margin.add_theme_constant_override(&"margin_bottom", 10)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override(&"separation", 14)
	margin.add_child(hbox)

	# Icon
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tex := _load_icon(str(p["icon"]))
	if tex != null:
		icon_rect.texture = tex
	hbox.add_child(icon_rect)

	# Info column
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override(&"separation", 3)
	hbox.add_child(info)

	var title := Label.new()
	title.text = str(p["title"])
	title.add_theme_font_size_override(&"font_size", 22)
	title.add_theme_color_override(&"font_color", TITLE_COLOR)
	info.add_child(title)

	var desc := Label.new()
	desc.text = str(p["description"])
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override(&"font_size", 14)
	desc.add_theme_color_override(&"font_color", DESC_COLOR)
	info.add_child(desc)

	var dots := _build_dots(rank, UpgradeCatalog.MAX_PASSIVE_RANK)
	info.add_child(dots)

	# Action column
	var action := VBoxContainer.new()
	action.alignment = BoxContainer.ALIGNMENT_CENTER
	action.add_theme_constant_override(&"separation", 4)
	hbox.add_child(action)

	if maxed:
		var maxed_label := Label.new()
		maxed_label.text = "MAX"
		maxed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		maxed_label.add_theme_font_size_override(&"font_size", 20)
		maxed_label.add_theme_color_override(&"font_color", MAXED_COLOR)
		action.add_child(maxed_label)
	else:
		var cost_label := Label.new()
		cost_label.text = "%d g" % cost
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.add_theme_font_size_override(&"font_size", 18)
		cost_label.add_theme_color_override(&"font_color", PRICE_COLOR)
		action.add_child(cost_label)

		var btn := Button.new()
		btn.text = "Upgrade"
		btn.custom_minimum_size = Vector2(140, 40)
		btn.add_theme_font_size_override(&"font_size", 18)
		btn.disabled = MetaSave.gold < cost
		btn.pressed.connect(_on_upgrade_pressed.bind(pid))
		action.add_child(btn)

	return panel


func _build_dots(current: int, max_rank: int) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	for i in max_rank:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.color = DOT_FILLED if i < current else DOT_EMPTY
		box.add_child(dot)
	return box


func _row_style(maxed: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = ROW_BG_MAXED if maxed else ROW_BG_IDLE
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = BORDER_IDLE
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


func _on_upgrade_pressed(pid: String) -> void:
	var rank: int = MetaSave.passive_rank(pid)
	if rank >= UpgradeCatalog.MAX_PASSIVE_RANK:
		return
	var cost: int = _cost_for_rank(rank + 1)
	if not MetaSave.spend_gold(cost):
		return
	MetaSave.rank_up_passive(pid)
	Sfx.play("select")
	_refresh()


func _on_back_button_pressed() -> void:
	Sfx.play("select")
	back_requested.emit()


static func _cost_for_rank(rank: int) -> int:
	if rank <= 0:
		return RANK_COSTS[0]
	if rank > RANK_COSTS.size():
		return RANK_COSTS[RANK_COSTS.size() - 1]
	return RANK_COSTS[rank - 1]


static func _load_icon(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)
