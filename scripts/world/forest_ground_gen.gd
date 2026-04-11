class_name ForestGroundGen
extends RefCounted
## VS-like floor: weaving dirt corridors (not ruler-straight), softer intersections.

## Distance between parallel roads — primary control for “how big is each grass island”.
const ROAD_SPACING := 580.0
const ROAD_HALF_WIDTH := 11.0

## Roads are split into segments along their length; some segments are omitted so paths
## dead-end / resume instead of forming a perfect infinite lattice.
const ROAD_SEGMENT_LEN := 300.0
const ROAD_SEGMENT_GAP_CHANCE := 0.32

const GRASS_TILE := 72.0
const FOLIAGE_CELL := 148.0

const GRASS_1 := Color(0.16, 0.42, 0.24)
const GRASS_2 := Color(0.14, 0.38, 0.22)
const GRASS_3 := Color(0.18, 0.44, 0.26)
const GRASS_4 := Color(0.12, 0.34, 0.20)

const DIRT_1 := Color(0.42, 0.30, 0.18)
const DIRT_2 := Color(0.36, 0.26, 0.15)
const DIRT_3 := Color(0.48, 0.34, 0.20)

const CANOPY_A := Color(0.12, 0.36, 0.18)
const CANOPY_B := Color(0.10, 0.32, 0.16)
const TRUNK := Color(0.28, 0.18, 0.10)


func _init(_p_seed: int = 0) -> void:
	pass


func set_world_seed(_p_seed: int) -> void:
	pass


## Gentle weave so roads aren’t perfectly axis-aligned strips.
func _dist_vertical_road(wx: float, wy: float) -> float:
	var weave := sin(wy * 0.014 + wx * 0.0025) * 12.0 + cos(wy * 0.0085 + 1.7) * 7.0
	var adj := wx + weave
	var nearest := roundf(adj / ROAD_SPACING) * ROAD_SPACING
	return absf(adj - nearest)


func _dist_horizontal_road(wx: float, wy: float) -> float:
	var weave := sin(wx * 0.014 + wy * 0.0025) * 12.0 + cos(wx * 0.0085 + 0.9) * 7.0
	var adj := wy + weave
	var nearest := roundf(adj / ROAD_SPACING) * ROAD_SPACING
	return absf(adj - nearest)


func _vertical_road_lane(wx: float, wy: float) -> int:
	var weave := sin(wy * 0.014 + wx * 0.0025) * 12.0 + cos(wy * 0.0085 + 1.7) * 7.0
	var adj := wx + weave
	return int(roundf(adj / ROAD_SPACING))


func _horizontal_road_lane(wx: float, wy: float) -> int:
	var weave := sin(wx * 0.014 + wy * 0.0025) * 12.0 + cos(wx * 0.0085 + 0.9) * 7.0
	var adj := wy + weave
	return int(roundf(adj / ROAD_SPACING))


func _segment_mask_vertical(wx: float, wy: float) -> float:
	var lane := _vertical_road_lane(wx, wy)
	var seg := int(floor(wy / ROAD_SEGMENT_LEN))
	var h: int = abs(int(hash(Vector3i(lane, seg, 0x21)))) % 1000
	if float(h) < ROAD_SEGMENT_GAP_CHANCE * 1000.0:
		return 0.0
	return 1.0


func _segment_mask_horizontal(wx: float, wy: float) -> float:
	var lane := _horizontal_road_lane(wx, wy)
	var seg := int(floor(wx / ROAD_SEGMENT_LEN))
	var h: int = abs(int(hash(Vector3i(lane, seg, 0x75)))) % 1000
	if float(h) < ROAD_SEGMENT_GAP_CHANCE * 1000.0:
		return 0.0
	return 1.0


func path_influence_at(wx: float, wy: float) -> float:
	var dv := _dist_vertical_road(wx, wy)
	var dh := _dist_horizontal_road(wx, wy)
	var pv := _stripe_alpha(dv) * _segment_mask_vertical(wx, wy)
	var ph := _stripe_alpha(dh) * _segment_mask_horizontal(wx, wy)
	# Soft union — rounder crossings than max(pv,ph)
	return 1.0 - (1.0 - pv) * (1.0 - ph)


func _stripe_alpha(dist_from_line: float) -> float:
	return 1.0 - smoothstep(ROAD_HALF_WIDTH - 4.0, ROAD_HALF_WIDTH + 9.0, dist_from_line)


func _grass_from_tile(wx: float, wy: float) -> Color:
	var tx := int(floor(wx / GRASS_TILE))
	var ty := int(floor(wy / GRASS_TILE))
	var h: int = abs(int(hash(Vector2i(tx, ty)))) % 4
	match h:
		0:
			return GRASS_1
		1:
			return GRASS_2
		2:
			return GRASS_3
		_:
			return GRASS_4


func _blade_speck(wx: float, wy: float, tx: int, ty: int) -> float:
	var ix := int(wx) & 15
	var iy := int(wy) & 15
	var h: int = abs(int(hash(Vector2i(tx, ty)))) + ix * 3 + iy * 5
	return float(h % 17) / 17.0 * 0.04


func _dirt_color(wx: float, wy: float) -> Color:
	var t := absf(sin(wx * 0.017 + wy * 0.011)) * 0.5 + 0.3
	var h: int = abs(int(hash(Vector2i(int(wx * 0.06), int(wy * 0.06))))) % 3
	var a := DIRT_1.lerp(DIRT_2, t)
	if h == 0:
		return a.lerp(DIRT_3, 0.4)
	return a


func _tree_overlay(wx: float, wy: float) -> Color:
	var cx := int(floor(wx / FOLIAGE_CELL))
	var cy := int(floor(wy / FOLIAGE_CELL))
	var hh: int = abs(int(hash(Vector2i(cx, cy))))
	if hh % 4 != 0:
		return Color(0, 0, 0, 0)

	var ox := fposmod(wx, FOLIAGE_CELL) - FOLIAGE_CELL * 0.5
	var oy := fposmod(wy, FOLIAGE_CELL) - FOLIAGE_CELL * 0.5

	var cy0 := oy + 18.0
	var rx := 34.0
	var ry := 28.0
	var e := (ox * ox) / (rx * rx) + (cy0 * cy0) / (ry * ry)
	if e <= 1.0 and oy < 22.0:
		# Fade rim by darkening RGB, not alpha — depth*alpha made the ellipse edge fully
		# transparent so grass showed between canopy and trunk.
		var depth := clampf(1.0 - e, 0.0, 1.0)
		var c := CANOPY_A.lerp(CANOPY_B, absf(sin(wx * 0.08)))
		var shade := lerpf(0.62, 1.0, depth)
		return Color(c.r * shade, c.g * shade, c.b * shade, 0.9)

	# Trunk starts exactly under the canopy silhouette.
	var oy_canopy_bottom := minf(
		ry * sqrt(maxf(0.0, 1.0 - (ox / rx) * (ox / rx))) - 18.0,
		21.0
	)
	if absf(ox) < 8.0 and oy < 38.0 and oy > oy_canopy_bottom:
		return Color(TRUNK.r, TRUNK.g, TRUNK.b, 1.0)

	return Color(0, 0, 0, 0)


func _quantize_color(c: Color, steps: float) -> Color:
	var s := 1.0 / maxf(steps, 1.0)
	return Color(
		snappedf(c.r, s),
		snappedf(c.g, s),
		snappedf(c.b, s),
		1.0
	)


func ground_color_at(wx: float, wy: float) -> Color:
	var tx := int(floor(wx / GRASS_TILE))
	var ty := int(floor(wy / GRASS_TILE))

	var grass := _grass_from_tile(wx, wy)
	grass = grass.lightened(_blade_speck(wx, wy, tx, ty))

	var path := path_influence_at(wx, wy)
	var edge := smoothstep(0.06, 0.98, path)
	var dith := float((int(wx) >> 3 ^ int(wy) >> 3) & 1) * 0.012
	edge = clampf(edge + dith, 0.0, 1.0)

	var col := grass.lerp(_dirt_color(wx, wy), edge)

	if path < 0.22:
		var fol := foliage_at(wx, wy)
		if fol > 0.01:
			var fcy := int(floor(wy / FOLIAGE_CELL))
			var fcol := CANOPY_A.lerp(GRASS_3, absf(sin(wx * 0.03 + float(fcy) * 0.09)))
			col = col.lerp(fcol, fol * 0.35)

	if path < 0.42:
		var tree := _tree_overlay(wx, wy)
		if tree.a > 0.01:
			col = col.lerp(Color(tree.r, tree.g, tree.b), tree.a)

	return _quantize_color(col, 7.0)


func foliage_at(wx: float, wy: float) -> float:
	var cx := int(floor(wx / FOLIAGE_CELL))
	var cy := int(floor(wy / FOLIAGE_CELL))
	var hh: int = abs(int(hash(Vector2i(cx + 17, cy + 31))))
	if hh % 6 != 0:
		return 0.0
	var ox := fposmod(wx, FOLIAGE_CELL) - FOLIAGE_CELL * 0.5
	var oy := fposmod(wy, FOLIAGE_CELL) - FOLIAGE_CELL * 0.5
	var d := sqrt(ox * ox + oy * oy) / (FOLIAGE_CELL * 0.48)
	return clampf(1.0 - smoothstep(0.0, 1.0, d), 0.0, 1.0)


func decal_type_at(wx: float, wy: float) -> int:
	var path := path_influence_at(wx, wy)
	var h: int = abs(int(hash(Vector2i(int(wx / 10.0), int(wy / 10.0))))) % 1000
	var w: float = h / 1000.0
	if path > 0.35:
		if w < 0.1:
			return 1
		return 0
	if w < 0.05:
		return 3
	if w < 0.09:
		return 2
	return 0


func decal_color(kind: int) -> Color:
	match kind:
		1:
			return _quantize_color(Color(0.42, 0.38, 0.34), 6.0)
		2:
			return _quantize_color(Color(0.45, 0.28, 0.35), 6.0)
		3:
			return _quantize_color(Color(0.18, 0.34, 0.22), 6.0)
		_:
			return Color.BLACK
