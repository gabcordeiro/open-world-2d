extends RefCounted
## Makes the TileSet in code, so the project has ZERO image files.
## In your own game you'd draw a tileset in Aseprite and load it instead.
## Row 0 = game tiles (same order as the enum in terrain.gd)
## Rows 1-3 = 8-step color ramps for the debug views (height, temperature, moisture)

const SIZE := 16
const COLUMNS := 12

const GROUND := {
	0: Color("1d3f8f"),  # DEEP_WATER
	1: Color("2f6ad0"),  # WATER
	2: Color("e3cf8a"),  # SAND
	3: Color("6cc04a"),  # GRASS
	4: Color("3e8f3a"),  # FOREST
	5: Color("e8b765"),  # DESERT
	6: Color("eef3fb"),  # SNOW
	7: Color("4f7a4a"),  # SWAMP
	8: Color("7d7890"),  # ROCK
}


static func build() -> TileSet:
	var img := Image.create(SIZE * COLUMNS, SIZE * 4, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	# Ground tiles: flat color + a few darker pixels so it doesn't look like plastic
	for id in GROUND:
		var c: Color = GROUND[id]
		for x in SIZE:
			for y in SIZE:
				var k := rng.randf()
				img.set_pixel(id * SIZE + x, y, c.darkened(0.12) if k < 0.12 else c)

	_tree(img, 9 * SIZE, Color("1f6b2e"), Color("6b4a2b"))
	_cactus(img, 10 * SIZE)
	_tree(img, 11 * SIZE, Color("2d5e4b"), Color("5a3f24"), true)

	# Debug ramps: 8 steps each
	var ramps := [
		[Color.BLACK, Color.WHITE],                          # height
		[Color("3a6df0"), Color("f04a3a")],                  # temperature: blue cold -> red hot
		[Color("c9a26b"), Color("2f8fd0")],                  # moisture: brown dry -> blue wet
	]
	for row in 3:
		for i in 8:
			var c: Color = ramps[row][0].lerp(ramps[row][1], i / 7.0)
			img.fill_rect(Rect2i(i * SIZE, (row + 1) * SIZE, SIZE, SIZE), c)

	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(img)
	source.texture_region_size = Vector2i(SIZE, SIZE)
	for col in COLUMNS:
		source.create_tile(Vector2i(col, 0))
	for row in 3:
		for i in 8:
			source.create_tile(Vector2i(i, row + 1))

	var ts := TileSet.new()
	ts.tile_size = Vector2i(SIZE, SIZE)
	ts.add_source(source, 0)
	return ts


static func _tree(img: Image, ox: int, leaf: Color, trunk: Color, pine := false) -> void:
	img.fill_rect(Rect2i(ox + 7, 10, 2, 5), trunk)
	for y in 11:
		var half := (y / 2 + 1) if pine else int(5 - absf(y - 5) * 0.6)
		for x in range(8 - half, 8 + half):
			img.set_pixel(ox + x, y + 1, leaf.lightened(0.15) if x < 8 and y < 5 else leaf)


static func _cactus(img: Image, ox: int) -> void:
	var g := Color("3f9a45")
	img.fill_rect(Rect2i(ox + 7, 3, 3, 12), g)
	img.fill_rect(Rect2i(ox + 3, 6, 2, 5), g)
	img.fill_rect(Rect2i(ox + 4, 10, 3, 2), g)
	img.fill_rect(Rect2i(ox + 12, 5, 2, 4), g)
	img.fill_rect(Rect2i(ox + 10, 8, 3, 2), g)
