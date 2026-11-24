extends Node2D
## Infinite procedural 2D top-down world, in 4 steps. Remember them as:
##
##     CUT  ->  ASK  ->  PAINT  ->  FORGET
##
##   1. CUT     the endless world into square chunks (16 x 16 tiles)
##   2. ASK     the noise what is at every cell        (terrain.gd)
##   3. PAINT   that answer into a TileMapLayer        (set_cell)
##   4. FORGET  chunks that are far from the player     (erase_cell)
##
## Controls: WASD / arrows move, Shift = fast, Tab = chunk borders,
## 1 = normal, 2 = height noise, 3 = temperature, 4 = moisture, R = new seed.

const TerrainScript := preload("res://scripts/terrain.gd")
const TilesScript := preload("res://scripts/tiles.gd")
const PlayerScript := preload("res://scripts/player.gd")

const TILE := 16              # pixels per tile
const CHUNK := 16             # tiles per chunk side (one chunk = 256 x 256 px)
const LOAD_RADIUS := 2        # chunks around the player that must exist (5 x 5 = 25 chunks)
const CHUNKS_PER_FRAME := 1   # generate slowly so the game never freezes

@export var world_seed := 1234

var terrain: RefCounted       # answers "what is at this cell?"
var ground: TileMapLayer      # water, grass, sand...
var objects: TileMapLayer     # trees, cactus... (drawn on top of ground)
var player: Node2D
var camera: Camera2D
var view := "normal"          # or "height", "temperature", "moisture"

var _loaded := {}             # Dictionary used as a Set: chunk coords -> true
var _born := {}               # chunk coords -> time it was generated (for the green flash)
var _show_borders := false
var _hud: Label
var _overlay: Node2D        # draws chunk borders ON TOP of the tiles
var _time := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--view="):
			view = a.trim_prefix("--view=")
		if a.begins_with("--seed="):
			world_seed = int(a.trim_prefix("--seed="))
	var demo := "--demo" in args

	terrain = TerrainScript.new(world_seed)

	# Two layers that share one TileSet
	var tileset: TileSet = TilesScript.build()
	ground = TileMapLayer.new()
	ground.tile_set = tileset
	add_child(ground)
	objects = TileMapLayer.new()
	objects.tile_set = tileset
	add_child(objects)

	_overlay = Node2D.new()
	_overlay.z_index = 10
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	player = PlayerScript.new()
	player.set("demo", demo)
	add_child(player)

	camera = Camera2D.new()
	camera.zoom = Vector2(0.7, 0.7) if demo else Vector2(2, 2)   # demo: zoom out to SEE chunks appear
	camera.position_smoothing_enabled = true
	player.add_child(camera)

	_show_borders = demo
	_build_hud()


func _process(delta: float) -> void:
	_time += delta
	var center := world_to_chunk(player.position)    # STEP 1 - CUT: which chunk is the player in?

	# STEP 2 + 3: create the missing chunks around the player, closest first
	var made := 0
	for c in chunks_around(center):
		if made >= CHUNKS_PER_FRAME:
			break                                    # the rest waits for the next frame
		if not _loaded.has(c):
			generate_chunk(c)
			made += 1

	# STEP 4 - FORGET: drop chunks that are too far (+1 so we don't flicker at the edge)
	for c in _loaded.keys():
		if absi(c.x - center.x) > LOAD_RADIUS + 1 or absi(c.y - center.y) > LOAD_RADIUS + 1:
			unload_chunk(c)

	_hud.text = "seed %d   view: %s\nplayer chunk (%d, %d)   chunks in memory: %d" % [
		world_seed, view, center.x, center.y, _loaded.size()]
	_overlay.queue_redraw()


## STEP 1 - CUT: pixel position -> chunk coordinates.
## floor() matters: -0.5 must go to chunk -1, not 0 (int() would round toward zero).
func world_to_chunk(pos: Vector2) -> Vector2i:
	var size := float(TILE * CHUNK)
	return Vector2i(floori(pos.x / size), floori(pos.y / size))


## All chunks in a square around `center`, sorted closest first.
func chunks_around(center: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			out.append(center + Vector2i(dx, dy))
	out.sort_custom(func(a, b): return (a - center).length_squared() < (b - center).length_squared())
	return out


## STEP 2 + 3: ASK the terrain about every cell of the chunk, then PAINT it.
func generate_chunk(c: Vector2i) -> void:
	var first_cell := c * CHUNK                        # chunk (1, 0) starts at cell (16, 0)
	for y in CHUNK:
		for x in CHUNK:
			var cell := first_cell + Vector2i(x, y)    # global cell coordinates
			if view != "normal":
				_paint_debug(cell)
				continue
			var g: int = terrain.ground_at(cell)        # ASK: "what ground is here?"
			ground.set_cell(cell, 0, Vector2i(g, 0))    # PAINT: source 0, atlas column g, row 0
			var d: int = terrain.decor_at(cell, g)      # ASK: "anything on top?"
			if d >= 0:
				objects.set_cell(cell, 0, Vector2i(d, 0))
	_loaded[c] = true
	_born[c] = _time


## STEP 4 - FORGET: erase every cell of the chunk. Memory stays small forever.
## Nothing is lost: if the player comes back, ASK gives the exact same answers.
func unload_chunk(c: Vector2i) -> void:
	var first_cell := c * CHUNK
	for y in CHUNK:
		for x in CHUNK:
			ground.erase_cell(first_cell + Vector2i(x, y))
			objects.erase_cell(first_cell + Vector2i(x, y))
	_loaded.erase(c)
	_born.erase(c)


func _paint_debug(cell: Vector2i) -> void:
	var row := {"height": 1, "temperature": 2, "moisture": 3}.get(view, 1) as int
	var v: float = terrain.debug_value(cell, view)
	ground.set_cell(cell, 0, Vector2i(clampi(int(v * 8.0), 0, 7), row))


func regenerate() -> void:
	for c in _loaded.keys():
		unload_chunk(c)
	terrain = TerrainScript.new(world_seed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				_show_borders = not _show_borders
			KEY_1:
				view = "normal"; regenerate()
			KEY_2:
				view = "height"; regenerate()
			KEY_3:
				view = "temperature"; regenerate()
			KEY_4:
				view = "moisture"; regenerate()
			KEY_R:
				world_seed = randi() % 100000; regenerate()


## Debug drawing: chunk borders + a green flash on chunks that were just generated.
func _draw_overlay() -> void:
	if not _show_borders:
		return
	var size := float(TILE * CHUNK)
	for c in _loaded.keys():
		var r := Rect2(Vector2(c) * size, Vector2(size, size))
		var age: float = _time - float(_born.get(c, 0.0))
		if age < 0.6:
			_overlay.draw_rect(r, Color(0.3, 1.0, 0.4, 0.45 * (1.0 - age / 0.6)))
		_overlay.draw_rect(r, Color(1, 1, 1, 0.35), false, 3.0)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	_hud.add_theme_font_size_override("font_size", 22)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(_hud)
