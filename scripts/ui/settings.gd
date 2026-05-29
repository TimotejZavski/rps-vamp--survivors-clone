extends Control

signal back_requested

@onready var _music_slider: HSlider = $Center/Panel/Margin/VBox/MusicRow/MusicSlider
@onready var _music_value: Label = $Center/Panel/Margin/VBox/MusicRow/MusicValue
@onready var _sfx_slider: HSlider = $Center/Panel/Margin/VBox/SfxRow/SfxSlider
@onready var _sfx_value: Label = $Center/Panel/Margin/VBox/SfxRow/SfxValue
@onready var _fullscreen_check: CheckButton = $Center/Panel/Margin/VBox/FullscreenRow/FullscreenCheck


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_slider.value = float(MetaSave.get_setting("music_volume"))
	_sfx_slider.value = float(MetaSave.get_setting("sfx_volume"))
	_fullscreen_check.button_pressed = bool(MetaSave.get_setting("fullscreen"))
	_update_value_labels()
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)


func _update_value_labels() -> void:
	_music_value.text = "%d%%" % int(round(_music_slider.value * 100.0))
	_sfx_value.text = "%d%%" % int(round(_sfx_slider.value * 100.0))


func _on_music_changed(value: float) -> void:
	MetaSave.set_setting("music_volume", value)
	_update_value_labels()


func _on_sfx_changed(value: float) -> void:
	MetaSave.set_setting("sfx_volume", value)
	_update_value_labels()
	# Audible preview so the player hears the new SFX level while dragging.
	Sfx.play("select")


func _on_fullscreen_toggled(pressed: bool) -> void:
	MetaSave.set_setting("fullscreen", pressed)


func _on_back_button_pressed() -> void:
	Sfx.play("select")
	back_requested.emit()
