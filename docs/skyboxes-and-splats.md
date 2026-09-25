# Dhubai skyboxes and terrain detail

The map source is on `master`; `main` contains only the initial license.

## Selection

Lobby map option **Dhubai skybox** (`dhubai_sky`):

| Value | Source | Usage |
| --- | --- | --- |
| clear-day | New generated daylight variant | Default |
| overcast-day | New generated cloudy daylight variant | Rainy daytime |
| sunset-sandstorm | Previously approved panorama | Sunset / dust storm |
| rainy-night | Previously approved panorama | Rainy night |
| original | Existing cleardesert.dds | Comparison |

These select a static background. They do not set rainfall, change the sun,
or follow MOSAIC's day/night cycle. Automatic transitions need coordination
with the game's weather and lighting controller; they are not included here.
The original cubemap remains available.

Sources are in `maps/skyboxes/sources`. Runtime assets are 512-pixel RGBA8
DDS cubemaps, all six faces and ten mip levels (about 8 MiB per variant).
Only the selected cubemap loads. Rebuild with `python3 tools/build_skyboxes.py`
(Pillow and NumPy). The converter handles Recoil's sky Y convention and
nv_dds's vertical flip and Y-face exchange. It does not repaint source art.

New images used the built-in image-generation tool with the sunset panorama
as reference. Prompt: preserve coastline, buildings and horizon; create a
2:1, 360x180 environment with continuous wrap and coherent poles; no text;
change weather/lighting only. Clear variant: pale blue sky, high clouds,
warm sand and turquoise gulf, no sandstorm. Overcast variant: silver-gray
cloud layers, distant rain curtains, diffuse cool daylight, no lightning.

Generated panoramas are artistic environments, not measured HDR captures.
Neither source-edge continuity nor pole quality is guaranteed by conversion.
Inspect all azimuths, zenith, horizon height and ocean direction in engine
before merging. Static sun/city lighting in the art may disagree with game time.

## Confirmed log warning

`CSMFReadMap::CreateSplatDetailTextures` reports:
`Invalid SMF splatDetailTex maps/iwantDNTS.tga. Creating fallback texture`.

That filename is configured but absent. The replacement
`splat_detail_neutral.png` explicitly provides the same neutral RGBA value
(127 in each channel) used by the engine fallback. It removes the missing
resource, without introducing a new diffuse pattern. This warning alone
does not prove the cause of excessive normal detail.

All four normal textures and the distribution texture are present. The
full-map `detailNormalTex` is commented out and therefore is not responsible
in this repository revision. DNTS normal maps are active. Shader inspection
shows `texMults` contributes to the blend from geometric to detail normals.

| Layer | Original weight | Subtle weight |
| --- | ---: | ---: |
| Sand | 0.95 | 0.24 |
| Rock | 0.35 | 0.18 |
| Asphalt | 0.86 | 0.17 |
| Grass | 0.50 | 0.20 |

The **Terrain normal detail** option (`dhubai_splats`) offers `subtle`
(default), `original`, and `off` (diagnostic). Texture scale, texture pixels
and distribution remain unchanged. The diffuse-alpha flag is now a proper
Lua `false` rather than numeric `0.0`. Layer order is not changed: conflicting
old comments are insufficient evidence for swapping distribution channels.

## Validation and next capture

Lua 5.1 checks cover all sky/detail choices, invalid sky fallback, referenced
texture existence and boolean alpha. DDS checks cover headers, faces,
complete mip payload and decoded orientation after the loader transforms.
No in-engine rendering or performance result is claimed.

The supplied log also detects two map installs under `~/.spring/maps` and
`~/MosaicDev/coil_compiled/maps`; the former is ignored in that run. Test the
loaded copy, otherwise map edits may appear ineffective. Capture the same
camera and lighting with terrain detail `off`, `original` and `subtle`, both
dry and in rain. Confirm that the missing texture warning disappears.

An unrelated `gui_betrayal_runners.lua:73` nil comparison is also in this log;
that is a game UI error, not a map splatmapping failure.
