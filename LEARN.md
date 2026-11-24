# Infinite 2D open world in Godot: learn it, then remember it

Made by Kord GameDev (@kordgamedev). Godot 4.3 or newer. No image files: even the tileset is made in code.

Open the folder in Godot and press F5. Controls:

| Key | What it does |
|---|---|
| WASD / arrows | move (Shift = fast) |
| Tab | show chunk borders (green flash = chunk just created) |
| 1 / 2 / 3 / 4 | normal / height noise / temperature / moisture |
| R | new random seed |

## The whole idea in 4 words

**CUT → ASK → PAINT → FORGET**

1. **CUT** the endless world into square chunks (16 × 16 tiles).
2. **ASK** the noise what is at every cell of a chunk.
3. **PAINT** that answer into a TileMapLayer.
4. **FORGET** the chunks that are far from the player.

A sentence to remember it: *"I CUT a pizza into slices, ASK each slice what topping it wants, PAINT the topping on, and FORGET the slices I already ate."*

If you only remember those four words, you can rebuild the whole system from scratch. Everything below is just the details of each word.

## Where each step lives

| Step | File | Function |
|---|---|---|
| CUT | `scripts/world.gd` | `world_to_chunk()`, `chunks_around()` |
| ASK | `scripts/terrain.gd` | `ground_at()`, `biome()`, `decor_at()` |
| PAINT | `scripts/world.gd` | `generate_chunk()` |
| FORGET | `scripts/world.gd` | `_process()` (the distance check) and `unload_chunk()` |

Read the files in this order: `world.gd` → `terrain.gd` → `tiles.gd` → `player.gd`. Every line has a comment saying what it does and why.

## Line by line: the important parts

### 1. CUT (`world.gd`)

```gdscript
func world_to_chunk(pos: Vector2) -> Vector2i:
	var size := float(TILE * CHUNK)              # 16 px * 16 tiles = 256 px per chunk
	return Vector2i(floori(pos.x / size), floori(pos.y / size))
```

- `pos` is where the player is, in pixels.
- `size` is how many pixels one chunk covers.
- Dividing tells you "how many chunks away from the origin" you are. `floori` rounds **down**. That matters for negative numbers: at x = -10 px you are in chunk -1, but `int(-10 / 256.0)` would give 0 (it rounds toward zero) and two chunks would fight over the same place.

`chunks_around(center)` lists every chunk in a square of radius `LOAD_RADIUS` (2 → 5 × 5 = 25 chunks) and sorts them closest first, so the ground under your feet appears before the horizon.

### 2. ASK (`terrain.gd`)

```gdscript
var h := height.get_noise_2d(cell.x, cell.y)   # a number between about -1 and 1
if h < -0.35: return DEEP_WATER
if h < -0.12: return WATER
if h < -0.07: return SAND
if h >  0.45: return ROCK
```

- `FastNoiseLite` is smooth random: neighbors get similar numbers, so you get blobs (continents) instead of TV static.
- Read the `if`s top to bottom. **The first one that matches wins.** That's why the beach is the thin band between -0.12 and -0.07.
- The answer depends only on (cell, seed). Never on time, never on what was generated before. This is the secret that makes infinite worlds possible: chunks can be created in any order and they still fit together.

Biomes (part 2) use the same trick with two more noises:

```gdscript
temperature.seed = seed_value + 1   # +1 = a DIFFERENT noise from the same world seed
temperature.frequency = 0.004       # 3x slower than height = huge biomes
moisture.seed = seed_value + 2
```

```gdscript
func biome(t, m):
	if t < -0.2: return SNOW                      # cold, wet or not
	if t > 0.25:
		return DESERT if m < 0 else FOREST        # hot: dry = desert, wet = jungle
	if m > 0.3:  return SWAMP                     # mild + very wet
	if m > 0.05: return FOREST                    # mild + a bit wet
	return GRASS                                  # anything left = plains
```

Two questions: **is it hot? is it wet?** Draw a square with "dry → wet" on one side and "cold → hot" on the other, and each `if` is a region of that square. This is a simplified version of the Whittaker biome diagram from ecology.

Trees use `rand01(cell)`, which hashes (x, y, seed) into a number from 0 to 1. It looks random but it is **always the same for the same cell**. If you used `randf()` instead, the forest would reshuffle every time a chunk is unloaded and loaded again.

### 3. PAINT (`world.gd`)

```gdscript
for y in CHUNK:
	for x in CHUNK:
		var cell := c * CHUNK + Vector2i(x, y)    # chunk (1, 0) starts at cell (16, 0)
		var g: int = terrain.ground_at(cell)       # ASK
		ground.set_cell(cell, 0, Vector2i(g, 0))   # PAINT: source 0, atlas column g, row 0
```

- `set_cell(where, source_id, atlas_coords)`: "at this cell, use tile (g, 0) from tileset source 0".
- Decorations go on a second `TileMapLayer` (`objects`) so a tree can sit on top of grass.
- `CHUNKS_PER_FRAME = 1`: only one chunk is generated per frame. Generating all 25 at once would freeze the game for a moment every time you cross a border.

### 4. FORGET (`world.gd`)

```gdscript
for c in _loaded.keys():
	if absi(c.x - center.x) > LOAD_RADIUS + 1 or absi(c.y - center.y) > LOAD_RADIUS + 1:
		unload_chunk(c)                            # erase_cell on all 256 cells
```

- The `+ 1` is a safety margin. Without it, walking back and forth on a chunk border would create and erase the same chunk every frame.
- Nothing is saved. Coming back works because ASK always gives the same answer for the same seed. (If the player can change the world, like chopping trees, you save only the **changes** per chunk. That's the next step if you want it.)

## How to memorize it (do this, not just read it)

**1. Say the 4 words out loud** before you open the project: CUT, ASK, PAINT, FORGET. Then try to say one sentence for each without looking.

**2. Predict, then run.** Change one number, guess what will happen, press F5, check. Being wrong is where you learn.

| Change | Try to guess first |
|---|---|
| `height.frequency` 0.012 → 0.05 | bigger or smaller continents? |
| `fractal_octaves` 5 → 1 | what happens to the coastlines? |
| `LOAD_RADIUS` 2 → 1 | what do you see at the screen edges? |
| `CHUNKS_PER_FRAME` 1 → 25 | is it faster? does it stutter? |
| `rand01` → `randf()` in `decor_at` | walk away and come back. What changed? |
| `floori` → `int` in `world_to_chunk` | walk to negative x. What breaks? |

**3. Flashcards** (cover the answer, answer out loud):

| Question | Answer |
|---|---|
| What are the 4 steps? | CUT, ASK, PAINT, FORGET |
| Why `floori` and not `int`? | negative positions must round down, or chunk -1 and 0 overlap |
| What does a chunk's content depend on? | only the cell coordinates and the seed |
| Why can we erase far chunks without saving them? | same seed → same noise → same world when you come back |
| How do you get 3 different noises from 1 seed? | seed, seed + 1, seed + 2 |
| Why is temperature noise slower (lower frequency)? | so biomes are huge compared to lakes and hills |
| Why `hash()` and not `randf()` for trees? | hash is repeatable per cell, randf reshuffles |
| Why only 1 chunk per frame? | spread the work so the game never freezes |
| Why `LOAD_RADIUS + 1` when unloading? | margin so chunks don't flicker on the border |

**4. Rebuild it from memory (the real test).** Make a new empty Godot project and rebuild the system with the 4 words as your only notes. Use a plain colored square per tile at first, no tileset art. When stuck, peek at one function, close it, and continue.

Repeat the rebuild after **1 day, 3 days and 7 days**. Each time it gets faster. By the third time it's yours.

**5. Extend it** (each one reuses the same 4 steps):

- A river noise: cells where `abs(river_noise) < 0.03` become water.
- Villages: a very rare `rand01` per chunk spawns a house in the chunk center.
- Saving changes: a `Dictionary` per chunk with `cell → new tile`; apply it after PAINT.
- Collisions: add a physics layer to the water and rock tiles in the TileSet.

## Credits and further reading

- `FastNoiseLite`, `TileMapLayer`: built into Godot 4.
- Amit Patel (Red Blob Games), *Making maps with noise functions*: the best free article on this topic.
- Robert Whittaker's biome diagram (temperature × precipitation) inspired `biome()`.
