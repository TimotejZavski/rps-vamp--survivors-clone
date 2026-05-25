class_name ProceduralForestChunk
extends Node2D
## Renders one terrain chunk: fast low-res raster + NEAREST upscale (VS-style crunch).
## Image generation runs on WorkerThreadPool so the main thread doesn't hitch.

var chunk_coord: Vector2i = Vector2i.ZERO

var _task_id: int = -1
var _img: Image
var _gen: ForestGroundGen
var _ox: float
var _oy: float
var _cw: float
var _step: float
var _res: int
var _sprite_attached: bool = false


func setup(coord: Vector2i, gen: ForestGroundGen, chunk_world_size: float, tex_resolution: int) -> void:
	chunk_coord = coord
	z_index = -40
	_ox = float(coord.x) * chunk_world_size
	_oy = float(coord.y) * chunk_world_size
	position = Vector2(_ox, _oy)

	_gen = gen
	_cw = chunk_world_size
	_res = tex_resolution
	_step = chunk_world_size / float(tex_resolution)
	_img = Image.create(tex_resolution, tex_resolution, false, Image.FORMAT_RGB8)

	# Schedule heavy pixel work off the main thread; _process polls for completion.
	_task_id = WorkerThreadPool.add_task(_build_image_threaded, true, "forest_chunk_gen")
	set_process(true)


func _build_image_threaded() -> void:
	# Runs on a worker thread. Only touches _img (owned by this chunk) and _gen (pure / read-only).
	for py in _res:
		for px in _res:
			var wx := _ox + (float(px) + 0.5) * _step
			var wy := _oy + (float(py) + 0.5) * _step
			_img.set_pixel(px, py, _gen.ground_color_at(wx, wy))
	_paint_decals(_img, _gen, _ox, _oy, _cw, _step)


func _process(_delta: float) -> void:
	if _sprite_attached or _task_id == -1:
		return
	if not WorkerThreadPool.is_task_completed(_task_id):
		return
	WorkerThreadPool.wait_for_task_completion(_task_id)
	_task_id = -1
	_attach_sprite()
	set_process(false)


func _attach_sprite() -> void:
	if _sprite_attached or not is_inside_tree():
		return
	var tex := ImageTexture.create_from_image(_img)
	# Slight overlap kills 1px seams that show viewport grey between chunks.
	var spr_scale := _cw / float(_res) * 1.018
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = true
	spr.scale = Vector2(spr_scale, spr_scale)
	spr.position = Vector2(_cw * 0.5, _cw * 0.5)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	add_child(spr)
	_sprite_attached = true


func _exit_tree() -> void:
	# Make sure we don't leak the worker if this chunk is culled mid-build.
	if _task_id != -1:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1


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
