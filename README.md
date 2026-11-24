# Open World 2D (Godot 4)

An infinite, procedural, top-down 2D world in about 400 commented lines. Made for the Kord GameDev shorts.

- Open this folder in Godot 4.3+ and press **F5**.
- Read **LEARN.md**: it explains every step and has a method to memorize it.

The idea in 4 words: **CUT → ASK → PAINT → FORGET**.

```
scripts/world.gd     CUT, PAINT, FORGET (chunks around the player)
scripts/terrain.gd   ASK (height, temperature and moisture noise -> tile)
scripts/tiles.gd     the tileset, generated in code (no image files)
scripts/player.gd    a square that moves
```

Record a clip for social media (vertical, chunk borders on):

```
godot --path . --write-movie clip.avi --fixed-fps 30 --resolution 720x1280 --quit-after 600 -- --demo --seed=1337
```

Add `--view=height`, `--view=temperature` or `--view=moisture` to record the noise itself.

Free to use, learn from and modify. A shout-out to @kordgamedev is appreciated.
