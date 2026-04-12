extends Node2D
## In-world auto-weapon feedback. Default textures are wiki inventory sprites (CC BY-NC-SA 3.0) from
## https://vampire.survivors.wiki/ — see assets/characters/*/weapon/wiki_*.png

const DURATION := 0.18

## Wizard: small magic bolt (not the inventory wand icon). Knight/cleric: wiki inventory icons.
const WIKI_WEAPON_TEX := {
	"wizard": "res://assets/characters/imelda/weapon/wiki_magic_missile.png",
	"knight": "res://assets/characters/knight/weapon/wiki_whip.png",
	"cleric": "res://assets/characters/cleric/weapon/wiki_cross.png",
}

var _t := 0.0
var _active := false
var _range_units := 88.0
var _dir := Vector2.RIGHT

@onready var _sprite: Sprite2D = $WikiSprite
@onready var _placeholder: Polygon2D = $Placeholder


func _ready() -> void:
	z_as_relative = false
	z_index = 48
	visible = false
	_setup_visual()


func _setup_visual() -> void:
	var path: String = WIKI_WEAPON_TEX.get(RunConfig.character_id, "")
	var tex: Texture2D = null
	if not path.is_empty() and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex != null:
		_sprite.texture = tex
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.visible = true
		_placeholder.visible = false
	else:
		_sprite.visible = false
		_placeholder.visible = true
		_build_placeholder_polygon()


func _build_placeholder_polygon() -> void:
	match RunConfig.character_id:
		"wizard":
			_placeholder.color = Color(0.42, 0.72, 1.0, 0.9)
			_placeholder.polygon = PackedVector2Array([Vector2(-3, -2), Vector2(10, 0), Vector2(-3, 2)])
		"knight":
			_placeholder.color = Color(0.88, 0.9, 1.0, 0.92)
			_placeholder.polygon = PackedVector2Array([Vector2(-1, -6), Vector2(10, 0), Vector2(-1, 6)])
		"cleric":
			_placeholder.color = Color(1.0, 0.92, 0.55, 0.9)
			_placeholder.polygon = PackedVector2Array([
				Vector2(0, -18), Vector2(14, 0), Vector2(0, 18), Vector2(-14, 0),
			])
		_:
			_placeholder.color = Color(0.9, 0.4, 0.4, 0.85)
			_placeholder.polygon = PackedVector2Array([Vector2(-4, -4), Vector2(8, 0), Vector2(-4, 4)])


func play(range_units: float, facing: Vector2) -> void:
	_range_units = range_units
	_dir = facing if facing.length_squared() > 0.0001 else Vector2.RIGHT
	_t = 0.0
	_active = true
	visible = true
	_sprite.position = Vector2.ZERO
	_sprite.rotation = 0.0
	_sprite.scale = Vector2.ONE
	_placeholder.position = Vector2.ZERO
	_placeholder.rotation = 0.0
	_placeholder.scale = Vector2.ONE
	if _sprite.texture != null:
		_sprite.visible = true
		_placeholder.visible = false
	else:
		_sprite.visible = false
		_placeholder.visible = true


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	var u := clampf(_t / DURATION, 0.0, 1.0)
	if _sprite.visible and _sprite.texture != null:
		_apply_wiki_motion(u)
	elif _placeholder.visible:
		_apply_placeholder_motion(u)
	if _t >= DURATION:
		_active = false
		visible = false


func _apply_wiki_motion(u: float) -> void:
	var id := RunConfig.character_id
	match id:
		"wizard":
			# Magic Missile–style bolt: small sprite, travels toward aim (nearest enemy when in range).
			var dist := lerpf(4.0, mini(_range_units * 0.42, 52.0), ease(u, -1.4))
			_sprite.position = _dir * dist
			_sprite.rotation = _dir.angle()
			var sc := lerpf(1.0, 1.12, sin(u * PI))
			_sprite.scale = Vector2(sc, sc)
			_sprite.modulate = Color(1, 1, 1, 1.0 - u * 0.2)
		"knight":
			# Wiki whip icon is 16×16; keep it smaller than the hero (~18u tall), mostly in front of the player.
			var sweep := lerpf(-0.35, 0.35, u)
			var sc := lerpf(0.62, 0.72, u)
			_sprite.rotation = _dir.angle() + PI * 0.5 + sweep
			_sprite.position = _dir * lerpf(11.0, 20.0, u)
			_sprite.scale = Vector2(sc, sc)
			_sprite.modulate = Color(1, 1, 1, 1.0 - u * 0.2)
		"cleric":
			_sprite.position = Vector2.ZERO
			var pulse := 1.0 + sin(u * PI) * 0.15
			_sprite.rotation = u * PI * 0.35
			_sprite.scale = Vector2(2.1 * pulse, 2.1 * pulse)
			_sprite.modulate = Color(1, 0.96, 0.82, 1.0 - u * 0.35)
		_:
			_sprite.position = _dir * lerpf(6.0, 16.0, u)
			_sprite.rotation = _dir.angle()
			_sprite.scale = Vector2(1.6, 1.6)


func _apply_placeholder_motion(u: float) -> void:
	var id := RunConfig.character_id
	match id:
		"wizard":
			_placeholder.position = _dir * lerpf(4.0, _range_units * 0.48, ease(u, -1.5))
			_placeholder.rotation = _dir.angle()
		"knight":
			_placeholder.rotation = _dir.angle() + PI * 0.5 + lerpf(-0.45, 0.45, u)
			_placeholder.position = _dir * lerpf(10.0, 18.0, u)
		"cleric":
			_placeholder.rotation = u * TAU * 0.25
			_placeholder.scale = Vector2.ONE * lerpf(0.9, 1.25, sin(u * PI))
		_:
			_placeholder.rotation = _dir.angle()
