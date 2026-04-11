class_name ProceduralForestChunk
extends Node2D
## Renders one terrain chunk: fast low-res raster + NEAREST upscale (VS-style crunch).

var chunk_coord: Vector2i = Vector2i.ZERO


func setup(coord: Vector2i, gen: ForestGroundGen, chunk_world_size: float, tex_resolution: int) -> void:
	chunk_coord = coord
	z_index = -40
	var ox := float(coord.x) * chunk_world_size
	var oy := float(coord.y) * chunk_world_size
	position = Vector2(ox, oy)

	var step := chunk_world_size / float(tex_resolution)
	var img := Image.create(tex_resolution, tex_resolution, false, Image.FORMAT_RGB8)

	for py in tex_resolution:
		for px in tex_resolution:
			var wx := ox + (float(px) + 0.5) * step
			var wy := oy + (float(py) + 0.5) * step
			img.set_pixel(px, py, gen.ground_color_at(wx, wy))

	_paint_decals(img, gen, ox, oy, chunk_world_size, step)

	var tex := ImageTexture.create_from_image(img)

	# Slight overlap kills 1px seams that show viewport grey between chunks.
	var spr_scale := chunk_world_size / float(tex_resolution) * 1.018

	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = true
	spr.scale = Vector2(spr_scale, spr_scale)
	spr.position = Vector2(chunk_world_size * 0.5, chunk_world_size * 0.5)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	add_child(spr)


func _paint_decals(img: Image, gen: ForestGroundGen, ox: float, oy: float, cw: float, step: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(int(hash(Vector3i(chunk_coord.x, chunk_coord.y, 0xDECA)))))

	var res := img.get_width()
	var attempts := 28
	for i in attempts:
		var wx := ox + rng.randf() * cw
		var wy := oy + rng.randf() * cw
		var kind := gen.decal_type_at(wx, wy)
		if kind == 0:
			continue
		var px := int((wx - ox) / step)
		var py := int((wy - oy) / step)
		if px < 2 or py < 2 or px >= res - 2 or py >= res - 2:
			continue
		var dcol: Color = gen.decal_color(kind)
		var rad := 2
		if kind == 3:
			rad = 3
		var a := 0.5 if kind != 3 else 0.4
		_blit_blob(img, px, py, dcol, a, rad)


func _blit_blob(img: Image, cx: int, cy: int, col: Color, alpha: float, r: int) -> void:
	var res := img.get_width()
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var q := dx * dx + dy * dy
			if q > r * r:
				continue
			var x := cx + dx
			var y := cy + dy
			if x < 0 or y < 0 or x >= res or y >= res:
				continue
			var falloff := 1.0 - float(q) / float(r * r + 1)
			var base: Color = img.get_pixel(x, y)
			var blend := alpha * falloff
			img.set_pixel(x, y, base.lerp(col, clampf(blend, 0.0, 1.0)))
