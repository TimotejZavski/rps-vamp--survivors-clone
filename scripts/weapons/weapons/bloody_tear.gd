extends "res://scripts/weapons/weapons/whip.gd"
## Whip + Hollow Heart evolution: red slash, lifesteals on every hit.

const _ICON := "res://assets/evo/Sprite-Bloody_Tear.png"


func _init() -> void:
	super._init()
	id = "bloody_tear"
	display_name = "Bloody Tear"
	icon_path = _ICON
	core_color = Color(1.0, 0.25, 0.25, 0.95)
	glow_color = Color(0.85, 0.05, 0.10, 0.55)
	lifesteal_fraction = 0.10


func get_damage() -> int:
	# ~+40% damage on top of the base whip curve
	return int(round(float(super.get_damage()) * 1.4))
