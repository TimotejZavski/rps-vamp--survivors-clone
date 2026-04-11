extends Node2D
## Loads/unloads terrain chunks around the player. Center chunks build first;
## startup frames use a higher budget so the ring fills quickly.

const BACKDROP_SCRIPT := preload("res://scripts/world/forest_backdrop.gd")

const CHUNK_WORLD_SIZE := 384.0
## Lower = faster generation + chunkier pixels (NEAREST upscale). 88–112 is a good band.
const TEXTURE_RESOLUTION := 96

@export var world_seed: int = 0xF007
@export var load_radius: int = 4
@export var max_chunks_built_per_frame: int = 8
@export var startup_build_budget: int = 28
@export var startup_boost_frames: int = 5
@export var player_path: NodePath = ^"../Player"

var _gen: ForestGroundGen
var _chunks: Dictionary = {}
var _build_queue: Array[Vector2i] = []
var _queued: Dictionary = {}
var _player: Node2D
var _center_chunk: Vector2i = Vector2i.ZERO
var _startup_left: int = 0


func _ready() -> void:
	z_index = -120
	var backdrop: Node2D = BACKDROP_SCRIPT.new()
	add_child(backdrop)
	move_child(backdrop, 0)
	_gen = ForestGroundGen.new(world_seed)
	_gen.set_world_seed(world_seed)
	_player = get_node_or_null(player_path)
	_startup_left = startup_boost_frames


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_node_or_null(player_path)
	if _player == null:
		return
	_enqueue_needed_chunks()
	_sort_queue_by_distance()
	_flush_build_queue()
	_cull_distant_chunks()


func _enqueue_needed_chunks() -> void:
	var p: Vector2 = _player.global_position
	var cx := int(floor(p.x / CHUNK_WORLD_SIZE))
	var cy := int(floor(p.y / CHUNK_WORLD_SIZE))
	var center := Vector2i(cx, cy)
	_center_chunk = center

	for x in range(-load_radius, load_radius + 1):
		for y in range(-load_radius, load_radius + 1):
			var cc := Vector2i(center.x + x, center.y + y)
			if _chunks.has(cc):
				continue
			if _queued.has(cc):
				continue
			_queued[cc] = true
			_build_queue.append(cc)


func _chunk_dist_sq(a: Vector2i, center: Vector2i) -> int:
	var dx := a.x - center.x
	var dy := a.y - center.y
	return dx * dx + dy * dy


func _sort_queue_by_distance() -> void:
	if _build_queue.size() <= 1:
		return
	var center := _center_chunk
	_build_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _chunk_dist_sq(a, center) < _chunk_dist_sq(b, center)
	)


func _flush_build_queue() -> void:
	var budget := maxi(1, max_chunks_built_per_frame)
	if _startup_left > 0:
		budget = maxi(budget, startup_build_budget)
		_startup_left -= 1

	var n := mini(budget, _build_queue.size())
	for _i in range(n):
		var cc: Vector2i = _build_queue.pop_front()
		_queued.erase(cc)
		if _chunks.has(cc):
			continue
		var ch := ProceduralForestChunk.new()
		add_child(ch)
		ch.setup(cc, _gen, CHUNK_WORLD_SIZE, TEXTURE_RESOLUTION)
		_chunks[cc] = ch


func _cull_distant_chunks() -> void:
	var p: Vector2 = _player.global_position
	var cx := int(floor(p.x / CHUNK_WORLD_SIZE))
	var cy := int(floor(p.y / CHUNK_WORLD_SIZE))
	var center := Vector2i(cx, cy)

	var to_drop: Array[Vector2i] = []
	for k in _chunks.keys():
		var kk: Vector2i = k
		if _chebyshev(kk, center) > load_radius + 1:
			to_drop.append(kk)
	for k in to_drop:
		var node: Node = _chunks[k]
		if is_instance_valid(node):
			node.queue_free()
		_chunks.erase(k)


func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
