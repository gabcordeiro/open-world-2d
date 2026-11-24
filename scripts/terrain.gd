extends RefCounted
## STEP 2 of 4: ASK.
## "What is at this cell?" Every cell of the world asks the noise this question.
## The answer only depends on (cell, seed), never on what was generated before.
## That's why we can generate chunks in ANY order and the world still fits together.

# --- Tile ids (column in the atlas row 0, see tiles.gd) ---
enum { DEEP_WATER, WATER, SAND, GRASS, FOREST, DESERT, SNOW, SWAMP, ROCK, TREE, CACTUS, PINE }

var height := FastNoiseLite.new()       # big shapes: oceans, land, mountains
var temperature := FastNoiseLite.new()  # very slow noise: cold north / hot south feeling
var moisture := FastNoiseLite.new()     # very slow noise: dry / wet
var world_seed := 0


func _init(seed_value: int) -> void:
	world_seed = seed_value

	height.seed = seed_value                    # same seed = same world, every time
	height.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	height.frequency = 0.012                     # lower = bigger continents
	height.fractal_octaves = 5                   # 5 layers of detail on top of each other

	temperature.seed = seed_value + 1            # +1: a DIFFERENT noise from the same seed
	temperature.frequency = 0.004                # 3x slower than height: biomes are huge
	temperature.fractal_octaves = 2

	moisture.seed = seed_value + 2
	moisture.frequency = 0.005
	moisture.fractal_octaves = 2


## The ground tile for one cell. Read it top to bottom: the first rule that matches wins.
func ground_at(cell: Vector2i) -> int:
	var h := height.get_noise_2d(cell.x, cell.y)        # a number between about -1 and 1

	if h < -0.35: return DEEP_WATER                    # very low = deep ocean
	if h < -0.12: return WATER                         # low = shallow water
	if h < -0.07: return SAND                          # thin band right above water = beach
	if h >  0.45: return ROCK                          # very high = mountain

	# Land in the middle: now the biome decides
	var t := temperature.get_noise_2d(cell.x, cell.y)    # -1 cold ... 1 hot
	var m := moisture.get_noise_2d(cell.x, cell.y)       # -1 dry  ... 1 wet
	return biome(t, m)


## Two questions, like a tiny Whittaker diagram: "Is it hot?" and "Is it wet?"
func biome(t: float, m: float) -> int:
	if t < -0.2: return SNOW                           # cold: snow, wet or not
	if t > 0.25:
		return DESERT if m < 0 else FOREST             # hot: dry = desert, wet = jungle-ish forest
	if m > 0.3:  return SWAMP                          # mild + very wet
	if m > 0.05: return FOREST                         # mild + a bit wet
	return GRASS                                       # anything left: plains


## Decoration on top of the ground (trees, cactus...). -1 = nothing.
func decor_at(cell: Vector2i, ground: int) -> int:
	var r := rand01(cell)                                # a random number, but always the SAME for this cell
	match ground:
		FOREST:
			return TREE if r < 0.30 else -1              # 30% of forest cells get a tree
		GRASS:
			return TREE if r < 0.03 else -1              # plains: a few lonely trees
		DESERT:
			return CACTUS if r < 0.02 else -1
		SNOW:
			return PINE if r < 0.08 else -1
		SWAMP:
			return TREE if r < 0.10 else -1
	return -1


## "Random" that never changes: hash the cell + seed into a number from 0 to 1.
## Calling randf() here would give a different forest every time a chunk reloads!
func rand01(cell: Vector2i) -> float:
	var h := hash(Vector3i(cell.x, cell.y, world_seed))  # same input -> same output
	return float(h % 100000) / 100000.0


## Raw values for the debug views (keys 2, 3, 4): -1..1 mapped to 0..1
func debug_value(cell: Vector2i, which: String) -> float:
	var v := 0.0
	match which:
		"height":
			v = height.get_noise_2d(cell.x, cell.y)
		"temperature":
			v = temperature.get_noise_2d(cell.x, cell.y)
		"moisture":
			v = moisture.get_noise_2d(cell.x, cell.y)
	return clampf(v * 0.5 + 0.5, 0.0, 1.0)
