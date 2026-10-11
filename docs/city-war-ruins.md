# Initial city ruins

The map's city placer selects either the authored civilian house or a war ruin
before calling `Spring.CreateUnit`. A selected ruin owns the original plot; no
intact building is created underneath it. Initial placement never destroys a
house to substitute a ruin after its unit script has started.

The ruin percentage comes from the game's shared `lib_mosaic` configuration
and `lib_city_ruins` policy. The map provides its location through
`mosaic/location.lua`: United Arab Emirates, Dubai latitude 25.2 degrees north.
This keeps the city's location explicit if the archive is renamed. Latitude is
geographical input to MOSAIC's fictional war-damage model, not a measure of
present-day damage.

## Authored content and compatibility

- All 199 distinct civilian house plots retain their original coordinates.
- The three explicitly authored war-ruin plots remain ruins.
- The first three successfully created arcology plots are protected by the
  game's `protectedMinimums` configuration. Failed creates and duplicate plots
  do not consume that minimum.
- Civilian plots are deduplicated across both `unitlist` and `buildinglist`.
  The accidental repeated arcology at `(5910, 2181)` has also been removed
  from the source data, fixing that overlap with older game versions.
- Non-house units can still share coordinates, preserving authored decoration,
  objectives and other deliberately stacked objects. Feature placement and
  existing unit rotation, team, neutral and visibility settings are retained.
- Older game versions that lack the shared helpers use the authored placements
  without applying the new latitude policy. No map-local substitute rates or
  duplicate category definitions are maintained.

Both the map and the updated game are needed to apply the latitude policy to
this authored city. Updating only MOSAIC's automatic city generator cannot alter
these LuaGaia placement choices.

## Verification

From the map repository root, run:

```sh
lua tests/city_ruin_placement_test.lua
MOSAIC_GAME_ROOT=/path/to/MOSAIC lua tests/city_ruin_placement_test.lua
```

The first command runs the real map gadget against mocked engine calls and
checks creation counts, duplicate plots, protected minima, source metadata,
compatibility and the complete authored map data. The second additionally runs
the paired game's actual geography and ruin policy, checks repeatability, and
exercises both explicit map metadata and the known-map fallback.

Visual verification still requires a new match with both updated archives.
