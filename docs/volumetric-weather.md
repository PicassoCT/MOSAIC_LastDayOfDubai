# Dhubai volumetric weather

The atmospheric **Volumetric Clouds** widget and its GLSL renderer have moved
from MOSAIC into this map's `LuaUI/Widgets_Map/` directory. The map widget is
enabled by default under a new name, **Dhubai volumetric weather**, so the old
disabled game-widget setting does not keep it switched off. MOSAIC's existing
map-widget loader discovers it; no game shader framework is needed.

The separate game `gfx_cloud_volumes.lua` renderer still owns pump smoke,
spaceport launch clouds, explosions and aerosol effects. Those are unit effects,
not the atmospheric layer moved here. The game retains its shared noise assets
because other game effects use them; the map already contains its own 3D noise.

## Automatic events

The scheduler uses MOSAIC's 28800-frame day and noon starting offset. A seeded
integer generator chooses events by map checksum and day, independently of frame
rate, random-number use elsewhere, or LuaUI reloads. It does not alter simulation
visibility, targeting, wind, or rain.

| Event | Chance per day | Start in map time | Duration at normal speed | Appearance |
| --- | --- | --- | --- | --- |
| Morning fog | 48% | 04:19–04:55 | 125–149 seconds | Cool, low banks strongest toward the northern coast; gone before 08:39 |
| Smog | 28% | 10:05–11:31 | 96–134 seconds | Slow warm gray haze over the central city |
| Sandstorm | 14% | 14:10–15:29 | 101–134 seconds | Taller amber dust front advancing north from the southern desert |

Smog and sandstorms are mutually exclusive on a given day. Events fade in over
their first 23% and out over their final 32%, leaving most of each day clear.
Wetness from MOSAIC's rain renderer (including `/weatherman`) suppresses dust
and washes out smog. Dawn fog is reduced during heavy rain. Without that optional
rain API, the map can render weather independently.

Automatic sky selection uses the existing sunset/sandstorm panorama during a
daytime dust event, with separate entry/exit thresholds to prevent flicker.
Night and rainy sky selection remain tied to the existing map clock and wetness.
An explicitly selected static sky stays selected.

## Controls and tuning

Lobby option **Dhubai volumetric weather** defaults to **Automatic**. It also
offers **Off** and persistent fog/smog/sandstorm presets for inspection.

With the widget loaded, local visual commands work without cheats:

```
/dhubaiweather fog
/dhubaiweather smog
/dhubaiweather sandstorm
/dhubaiweather off
/dhubaiweather automatic
```

Forced previews ignore rain suppression so each preset can be inspected at any
time. They affect only that player's view. Lobby Off removes the widget entirely;
enable it in the widget selector before using preview commands in that case.

Tune colors, height, extinction, maximum opacity and speed in
`LuaUI/Widgets_Map/Include/dhubai_weather.lua`. The shader samples the map's 3D
noise, shades density lobes with the sun, and clips rays against the rendered
scene depth, including units. It supports both depth conventions and perspective
or orthographic cameras, including a camera inside the fog. The 24-step raymarch
runs at quarter width/height, with no depth copy or raymarch during clear weather.
Resizes recreate both targets; shutdown releases the owned textures and shader.

## Paired migration

Use the matching `map/dhubai-volumetric-weather` branch of `PicassoCT/MOSAIC` to
remove the old disabled atmospheric widget and its two shaders from the game.
The map can be tested first; the old game widget is disabled by default. If it
was manually enabled, disable **Volumetric Clouds** to avoid drawing two layers.

Validation commands (Python dependencies: `lupa`, `moderngl`, `numpy`, `Pillow`):

```
python tests/volumetric_weather.py
MESA_GL_VERSION_OVERRIDE=3.3COMPAT python tests/volumetric_weather_gpu.py
```

The tests exercise the production scheduler, widget lifecycle and GLSL. Final
visual tuning still needs a Recoil run on the map with the three forced presets.
