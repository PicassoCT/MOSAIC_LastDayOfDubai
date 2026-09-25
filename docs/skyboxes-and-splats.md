# Dhubai skyboxes and terrain detail

The map source is on `master`; `main` contains only the initial license.

## Sky selection

The default lobby option `dhubai_sky=automatic` loads the map widget from
`LuaUI/Widgets_Map`, the directory MOSAIC's widget handler actually scans.
It uses the same 28,800-frame day and noon offset as MOSAIC's rain renderer.

- Day: clear-day, or overcast-day when local rain reaches 0.25.
- Clear weather resumes when rain drops to 0.10 (hysteresis).
- Night (18:00–06:00): rainy-night.

Rain comes from `WG.GetVehicleHeadlightWetness`, including `/weatherman`.
Without that API, daytime defaults to clear. Selection is checked once per
second; textures change only on a state change. At most three compressed
cubemaps are retained, roughly 6 MiB plus the engine's base sky.

Static choices remain: clear-day, overcast-day, sunset-sandstorm, rainy-night,
and original. They disable automatic selection. Other games without MOSAIC's
map-widget loader retain the static clear-day fallback.

Limits: transitions are discrete, not crossfaded. The only night panorama
currently available has rain clouds baked in, including during dry nights.
The sunset image also contains a sandstorm, so it is deliberately manual.
Sky selection does not alter game lighting, weather, or the sun's position.
Baked sun and horizon geography still need checking against the map in engine.

## White-background repair candidate

The four new cubemaps now use BC3/DXT5 instead of raw RGBA8. Recoil's nv_dds
uncompressed upload path uses legacy component-count internal formats, which
are incompatible with core OpenGL; the compressed path uses an explicit format.
This avoids that compatibility hazard but the screenshot alone does not prove
it caused the white exterior on the user's build. Confirm in-game after pulling.

Runtime assets: 512-pixel faces, six faces, ten mip levels, 2,097,440 bytes each
(previously 8,388,728). Rebuild with `python3 tools/build_skyboxes.py`, using NumPy
and Pillow with DXT5 encoding support. Sources remain in `maps/skyboxes/sources`.
The converter preserves the nv_dds vertical flip and Y-face exchange convention.
Generated source seams and poles are not guaranteed seamless by conversion.

## Terrain detail

The default `subtle` option replaces the dune normal layer with the existing
rock normal texture. Its scale is four times broader; the rock layer is ten
times broader. Both weights are 0.12. This removes dune ridges from the layer
that appears near the shore without repainting the distribution or base terrain.
It also affects inland areas using those same distribution channels.

`original` restores the dune texture, all original scales and weights.
`off` disables detail-normal influence for diagnosis.
The explicit neutral diffuse detail texture still fixes the missing
`maps/iwantDNTS.tga` warning. The diffuse-alpha flag remains a Lua boolean.

## Validation

All 240 DDS face/mip images decode, with headers and payload sizes checked.
Lua 5.1 checks cover 21 sky/detail combinations and referenced sky files.
Mocked widget checks cover noon, rain, hysteresis, dusk, dawn and cleanup.
No in-engine rendering or performance result is claimed.

For verification, use the loaded map copy (earlier logs reported two installs),
restart the match, and compare the same view with subtle/original/off terrain
normal detail. Check the horizon at noon, dusk and night and with `/weatherman on`.
