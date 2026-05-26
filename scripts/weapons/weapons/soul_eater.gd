extends "res://scripts/weapons/weapons/garlic.gd"
## Garlic + Pummarola (Recovery) evolution: bigger red aura, lifesteals from
## every enemy it ticks.

const _ICON := "res://assets/evo/Sprite-Soul_Eater.png"


func _init() -> void:
	super._init()
	id = "soul_eater"
	display_name = "Soul Eater"
	icon_path = _ICON
	aura_tint = Color(0.95, 0.18, 0.22)
	aura_radius_mult = 1.7
	lifesteal_fraction = 0.06


func get_damage() -> int:
	# Stronger per-tick damage than base garlic.
	return int(round(float(super.get_damage()) * 1.5))
