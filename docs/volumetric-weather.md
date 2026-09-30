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

## Namespace and resource ownership

The entry widget is `gfx_dhubai_volumetric_weather.lua`. Its state and GPU handles
are local to that widget. Its only shared export is `WG.DhubaiWeather`: startup
refuses to overwrite an existing owner, and shutdown clears it only when it still
points to this widget's API. The sky widget reads that API; weather reads the
game's optional wetness and height-bounded fog-lighting APIs.

Module and shader reads explicitly use `VFS.MAP`. Named texture loading via
`gl.Texture` does not accept that archive selector, so the noise lives at the
unique path `LuaUI/Images/Dhubai/Weather/worley_noise_128.dds`, instead of sharing
the game's noise filename. Shader uniform names belong to their linked program;
the render targets are newly allocated handles. The draw call preserves GL
attributes and matrix stacks and unbinds its shader after use.

## Automatic events

The scheduler uses MOSAIC's 28800-frame day and noon starting offset. A seeded
integer generator chooses events by map checksum and day, independently of frame
rate, random-number use elsewhere, or LuaUI reloads. It does not alter simulation
visibility, targeting, wind, or rain.

| Event | Chance per day | Start in map time | Duration at normal speed | Appearance |
| --- | --- | --- | --- | --- |
| Morning fog | 48% | 04:19–04:55 | 125–149 seconds | Cool, low banks strongest toward the northern coast; gone before 08:39 |
| Smog | 28% | 10:05–11:31 | 96–134 seconds | Slow warm gray haze over the central city |
| Sandstorm | 14% | 14:10–15:29 | 101–134 seconds | Amber dust front with shallow drifting sand waves entering from the southern desert |

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
/dhubaiweather light off
/dhubaiweather light on
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
During sandstorms, an additional 24 samples cover only the terrain-height band;
they are merged front-to-back with the existing 24 atmospheric samples. Fog and
smog retain their 24 samples. Resizes recreate both targets; shutdown releases the owned textures and shader.

## Southern sand waves

Sandstorm phases include broken, curling bands of blowing sand entering at the
southern border (`+Z`) and drifting north (`-Z`). They follow the engine's live
`$heightmap`, with density strongest just above the surface and fading completely
within 64 world units. The map borrows this texture without allocating or deleting
it. Water is excluded, and the waves thin toward the coast. Terrain materials
and the sand/asphalt splat mask are unchanged.

The wave layer uses the same event phase, strength, rain suppression, sun and
local-light integration as the storm. Its leading edge advances inward from the
south; noise breaks up the crests rather than creating straight uniform stripes.
Animation uses simulation time, so pausing freezes it. Storm profile speed also
scales drift: the default is about 91 world units per second with roughly 640-unit
crest spacing. These values, the 64-unit height cap and density multiplier live
in `sandWaveDensity` in `Shaders/fogShader.frag`.

Use `/dhubaiweather sandstorm` to inspect persistent waves, and
`/dhubaiweather automatic` to restore the normal schedule. Automated GLSL checks
cover southern entry, northward motion, terrain following, water exclusion,
pause, depth clipping and both depth conventions. These are synthetic GPU scenes;
final appearance and the added storm-only sampling cost need an in-game check.

## Height-bounded radiance

Local radiance lighting is enabled by default. The matching game changes expose
`WG.GetMosaicFogRadiance()` with a versioned, read-only descriptor containing
the existing radiance, occupancy and optional live headlight textures, plus a
new height envelope texture. The map borrows these handles for one draw and
never deletes them. Missing providers or height data leave sun lighting active.
The fog widget draws after radiance and before rain in MOSAIC's widget order.

At each of the 24 ray steps, local light is gated by the source's world-space
base and top. Buildings use imported model bounds, with unit height as a
fallback; headlights use the actual lamp anchors, including elevated vehicles.
Light fades above and below that interval and toward the horizontal reach edge.
An unknown height contributes no local fog lighting. Front-to-back extinction
attenuates distant light through the foreground fog. Fog opacity is unchanged.

This is an approximation using the existing horizontal radiance field. Each
metadata texel selects its nearest source; heights from separate sources are
not averaged. Overlapping lights at different heights still share the 2D light
color, and whole-model bounds can overestimate a building's emitting facade.
The existing horizontal occupancy test is conservative: this is not a full 3D
light or shadow solve.

The game creates a 512-square RGBA16F height atlas and depth attachment on demand
(about 3 MiB of texture storage) and refreshes them at the existing 5 Hz capture
rate. No extra cascade solves or shadow rays are added. The fog shader adds one
height lookup per nonempty ray step and occupancy/light lookups only inside the
envelope. `/dhubaiweather light off` disables these lookups and stops requesting
height refreshes; clear weather likewise makes no requests. The game stops
refreshing the atlas after a 0.6-second grace period and retains its allocation
until shutdown. This cost has not been timed on a GTX 1050 Ti.

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

The tests exercise the production scheduler, widget lifecycle and GLSL, including
finite light height, elevated sources, provider removal, occupancy, headlight
intensity and extinction. Final visual tuning and hardware timing still need a
Recoil run on the map with the three forced presets and lighting on/off.
