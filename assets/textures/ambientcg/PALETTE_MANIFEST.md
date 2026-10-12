# Predator Isle shared terrain palette

License for every listed asset: [CC0 1.0](https://docs.ambientcg.com/license/).
Development downloads only. No game-time HTTP, conversion, per-chunk textures or
per-chunk duplication of the palette.

September 28 repair: no additional assets downloaded. Both existing runtime
arrays were restored to `materials/terrain.tres` and explicitly rebound by
ChunkTerrain at startup. Missing bindings, not missing source files, caused the
white/cyan cliff regression. Startup and `tools/check_material_binding.gd` verify
nine layers in each array. Per-LOD materials share these arrays.

| Layer | Actual ID / source | Landscape role | Acquisition |
| --- | --- | --- | --- |
| 0 | [Grass001](https://ambientcg.com/view?id=Grass001) | Healthy dense grass | Existing project asset |
| 1 | [Ground054](https://ambientcg.com/view?id=Ground054) | Desert sand, not universal shore outlines | Existing project asset |
| 2 | [Snow001](https://ambientcg.com/view?id=Snow001) | Snow biome | Existing project asset |
| 3 | [Rock030](https://ambientcg.com/view?id=Rock030) | Weathered lighter rock | Existing project asset |
| 4 | [Ground037](https://ambientcg.com/view?id=Ground037) | Sparse moss/grass with exposed earth; muted dry ground | Downloaded September 27, 2026 |
| 5 | [Ground048](https://ambientcg.com/view?id=Ground048) | Granular brown earth; damp/muddy variant near water | Downloaded September 27, 2026 |
| 6 | [Gravel020](https://ambientcg.com/view?id=Gravel020) | River gravel and slope debris | Downloaded September 27, 2026 |
| 7 | [Rock035](https://ambientcg.com/view?id=Rock035) | Dark mineral rock faces | Downloaded September 27, 2026 |
| 8 | [Rock028](https://ambientcg.com/view?id=Rock028) | Broad-faced cliff stone, fixed 36 m projection | Existing project asset; packed for the sparse cliff correction |

For each ID, downloaded archive URL is
`https://ambientcg.com/get?file=ID_2K-JPG.zip`.
Retained maps: `ID_2K-JPG_Color.jpg`, `ID_2K-JPG_NormalGL.jpg`, and
`ID_2K-JPG_Roughness.jpg`, all 2048×2048. Unused displacement, AO, NormalDX and
other archive files were not extracted into the project. Website previews are not
used as textures. Full archives remain in a development temporary directory.

## Runtime preparation

`tools/build_terrain_palette.gd` packs each original color's RGB and the linear
roughness in alpha into a mipmapped 2K BC3 Image resource. RGB stays sRGB and the
shader uses `source_color`; alpha remains linear data. OpenGL normals are resized
to 1024×1024 with Lanczos, converted to RG, mipmapped, and BC5/RGTC-compressed.
Compression format is asserted. The shader reads XY from RG and reconstructs Z;
it never reads the missing blue channel or applies a DirectX Y inversion.

Two Texture2DArray resources reference those compressed Image resources directly.
This avoids GL GPU readback silently decompressing saved Texture2DArray files.
All chunks share one material/palette. No texture-height map is required.

Historical September 28 refinement (superseded): Rock034
uses two rotated, differently scaled samples to reduce distinctive repetition.
Independent world-space, interrupted joint families at 43 m and 71 m spacing,
plus restrained 31 m shelf weathering, supply larger cliff structure. These are
procedural shading masks, not extra source textures or geometric cracks. Fine
normal sampling is skipped at distance; the larger rock structure remains.

The actual downloaded color maps were inspected via 512-pixel diagnostic previews.
`tools/check_palette.gd` verifies layer count, format, mipmaps, decoded averages and
renders all nine layers. `tools/palette_swatches.png` is QA output, not a texture.
The palette is deliberately compact: ground structure differs between layers 0,
4, 5 and 6; wetness variants reuse earth rather than adding a redundant mud set.

Rebuild during development with Godot's editor executable and
`--script tools/build_terrain_palette.gd`. Compression is editor-only; runtime only
loads the prepared resources. Source JPGs are preparation inputs, not additional
samplers bound by the terrain shader.

This source directory has `.gdignore` so source JPGs are excluded from normal
Godot resource imports/exports. Development preparation reads them directly from
disk. Runtime resources live under `materials/`, outside the ignored directory.
Existing original source maps are retained, not deleted.

Decoded BC5 verification sampled 1,024 normals per asset against resized source
XY normals. Mean angular errors in layer order: 2.49, 1.22, 0.62, 3.47, 2.87,
2.31, 2.26, 3.24, 3.20 degrees. Compression is lossy; these are measured errors, not
claims of identical normals. The two compressed arrays occupy about 60 MiB
including mipmaps, excluding driver overhead.

Rock034 was selected by inspecting its downloaded color map and then the rendered
cliff. Rock028 was also downloaded and inspected but rejected: its strong diagonal
strata were unsuitable for this wall. Its three source JPGs remain development-only
under the ignored source directory; no Rock028 runtime images or shader bindings
were created. Source: https://ambientcg.com/view?id=Rock028, CC0, 2K-JPG Color,
NormalGL and Roughness, no source processing beyond diagnostic preview resizing.
