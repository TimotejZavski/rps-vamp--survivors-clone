extends "res://scripts/weapons/weapons/knife.gd"
## Knife + Bracer (Speed) evolution: very fast continuous fire.

const _ICON := "res://assets/evo/Sprite-Thousand_Edge.png"


func _init() -> void:
	super._init()
	id = "thousand_edge"
	display_name = "Thousand Edge"
	icon_path = _ICON


func get_cooldown() -> float:
	# Near-constant fire: ~10 knives/sec at L1, capped by floor.
	return maxf(0.05, 0.10 - float(level - 1) * 0.008 + cd_bonus)


func get_damage() -> int:
	# Slightly higher per-knife damage on top of the very fast rate.
	return 20 + (level - 1) * 5 + dmg_bonus
