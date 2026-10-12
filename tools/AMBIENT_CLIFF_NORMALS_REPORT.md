# ambientCG cliff normal layers — current runtime system

## Current configuration entry point

Use `res://cliff_normals.tres`, not the fixed shader controls described below.
This is now a list of up to 16 editable `CliffNormalLayer` resources with arbitrary
normal textures and per-entry strength, texture size, noise size/cutoff/softness,
breakup, seed, rotation and offset. Add/remove/replace entries in the Inspector.
Saved config changes reload during play; all LOD materials update together.
See `CLIFF_NORMAL_CONTROLS.md` for the current user guide. Add/remove/reorder/
replace, empty-list, live-edit and saved-reload tests pass in
`tools/check_cliff_config.gd`. Later sections document earlier fixed defaults.

## Visibility correction (latest defaults supersede the values below)

Fixed an actual selection bug: ranking already-saturated smoothstep masks made
strong overlaps tie at 1.0, then the exclusion cutoff cancelled both winners.
Selection now ranks raw mask values, applies coverage separately, and uses a
0.065-wide rank-handoff fade instead of the previous 0.35 suppression range.

Macro strength is now 1.2, medium strength .75. Coverage is .72. Region scales
are 95 m macro / 40 m medium (previously 150 / 65), with two layers allowed in
each band. Texture world scales remain unchanged. Per-source strengths, in array
order, are now 1.0, 1.1, 1.0, 1.05, .7, 1.0, .8, 1.0, 1.0.

`cliff_force_layer` (-1 by default; 0–8 selects a source at full coverage) allows
individual inspection. `preview_cliff_sources.gd` captures every source and then
restores natural composition. All nine source captures were visually inspected;
their broad blocks, jointing, strata or finer weathering visibly differ. The
combined near and wide views show much more structure than base-only rendering.
Granular Rock030/050 remain finer texture rather than artificial giant fractures.

`check_cliff_selection.gd` covers strong-overlap retention, zero coverage and
continuous rank handoffs. The denser default can now sample up to twelve normal
projections rather than nine. Latest fixed-camera viewport means at 1280x720:
overlays off CPU 1.076 / GPU 3.459 ms; on CPU 1.150 / GPU 4.788 ms. The measured
GPU delta is about 1.33 ms in this scene. This is more expensive than the sparse
configuration; it has not been presented as a free visual improvement.

This replaces the procedural cliff relief path. All seven old geology/family/
landform maps are unbound from the material and runtime script, and no shader
samples them. Their files and offline builders remain on disk for recovery, not
as active layers. Previous cliff reports describe historical implementations.

## Sources and packing

All nine requested **2K OpenGL normal JPGs** were downloaded. The downloader uses
HTTP byte ranges to retrieve ZIP metadata and the NormalGL entry only; it does
not retrieve albedo, roughness, displacement, AO or preview images. ZIP CRC and
uncompressed lengths are verified. Source URLs, original filenames, resolution,
SHA-256 and CC0 source notes are in
`assets/terrain/cliff_normals/ambientcg/sources.json`.

Source pages: [Rock064](https://ambientcg.com/view?id=Rock064),
[Rock058](https://ambientcg.com/view?id=Rock058),
[Rock051](https://ambientcg.com/view?id=Rock051),
[Rock060](https://ambientcg.com/view?id=Rock060),
[Rock030](https://ambientcg.com/view?id=Rock030),
[Rock061](https://ambientcg.com/view?id=Rock061),
[Rock050](https://ambientcg.com/view?id=Rock050),
[Rocks007](https://ambientcg.com/view?id=Rocks007),
[Rocks011](https://ambientcg.com/view?id=Rocks011).
These are source-authored maps; not all source materials are photogrammetry.

`build_cliff_normal_array.gd` packs linear RG OpenGL XY into 2K BC5 images with
11 mip levels. Z is reconstructed positive. No sRGB conversion is applied.
`materials/cliff_ambient_normals.tres` references the compressed images without
GPU readback/re-encoding. Runtime array payload is 50,331,888 bytes (~48 MiB).
The source JPGs are build inputs, not the runtime sampled textures.

## Initial art assignments

The source contact sheet was inspected before assigning these roles. Tile size
is not feature size; visible rock features occupy a fraction of each tile.

| Index | Source | Role | Tile width at defaults | Strength |
| --- | --- | --- | ---: | ---: |
| 0 | Rock064 | Broad blocks | 90 m | .75 |
| 1 | Rock058 | Weathered cliff mass | 64.8 m | .85 |
| 2 | Rock051 | Diagonal fine fractures | 11.9 m | .65 |
| 3 | Rock060 | Long joints/slabs | 108 m | .80 |
| 4 | Rock030 | Granular rock breakup | 4.9 m | .35 |
| 5 | Rock061 | Layered rock | 79.2 m | .75 |
| 6 | Rock050 | Rough weathering | 8.4 m | .40 |
| 7 | Rocks007 | Irregular stone masses | 16.8 m | .65 |
| 8 | Rocks011 | Smaller layered stones | 12.6 m | .65 |

## Selection and normal combination

Four macro candidates and five medium candidates each receive independent,
world-seeded large/medium noise coverage. Only masks are procedural. No crack,
pit, shelf, block or gash shapes are generated in the runtime shader.

Each band ranks candidates and evaluates up to its configured limit, never all
nine textures. At a selection boundary, the excluded candidate's weight is
subtracted from the selected weights, fading competing layers to zero before
their IDs swap. This avoids hard ID transitions but deliberately creates some
quieter areas around ambiguous selection boundaries. Zero, one and overlapping
layers are possible. Default limits are two macro and one medium layer.

Each selected layer uses signed X/Y/Z triplanar bases, fixed per-layer rotation
and offset, and an independent fixed scale. Rotation is undone on the tangent
slope before projection. Tangent XY/Z slopes are projected into the geometric
tangent plane, added to the existing base normal slope, and normalized once.
This is surface-gradient blending, not RGB averaging. Negative-axis bases are
right-handed. Coordinates and masks contain no camera or chunk-local terms.

Rotation varies by layer, not abruptly across spatial cells. Masking, different
scales and overlapping maps reduce repetition; the source maps still tile.

The existing cliff Rock028 albedo/roughness source and near base-rock normal
remain. Old relief-driven cavity/color modulation is gone with the old maps.
No new downloaded colors or roughness maps influence the material. Geometry,
water, chunk generation and grass textures were not changed.

## Controls

Edit Shader Parameters on `materials/terrain.tres` and restart the scene.
Runtime creates per-LOD copies; scripted live tuning must update all entries
in `Terrain._lod_materials`.

- `enable_ambient_cliff_normals`: global on/off.
- `macro_detail_strength=.75`, `medium_detail_strength=.4`.
- `macro_world_scale=72`, `medium_world_scale=14` metres, multiplied by the
  fixed per-map factors represented in the table.
- `macro_mask_scale=150`, `medium_mask_scale=65` metres.
- `mask_contrast=1`, `coverage_amount=.52`.
- `max_active_macro_layers=2`, `max_active_medium_layers=1`, each adjustable 0–2.
- `distance_fade_start=1800`, `distance_fade_end=4500` metres for macro detail.
- `medium_fade_start=200`, `medium_fade_end=850` metres.
- Nine named source strength controls, e.g. `rock064_strength`.
- `cliff_micro_strength=1` retains the existing fine normal intensity control.

Cliff normal debug modes (`cliff_normal_debug`): 0 combined, 1 base/off,
2 macro-only, 3 medium-only, 4 coverage (red macro, green medium), 5 selected
texture colors, 6 combined world normal. F5 views 21–27 expose these same modes.
The old procedural-relief F5 labels are no longer used. Existing earlier terrain
debug views are retained. Coverage/ID views show actual distance-filtered weights.

## Validation

- All nine bindings, formats, dimensions and mip counts passed the dedicated
  `check_ambient_cliff_normals.gd` test using the graphics renderer.
- Mean BC5 reconstruction errors ranged from 0.90 to 3.61 degrees per map.
- All six signed projection bases passed tangent/right-handedness checks.
- Base-only, macro-only, medium-only, coverage, IDs and combined-normal captures
  completed. The new controls change normals, not the base albedo/roughness.
- Close, oblique, water-adjacent and 80/300/900/2400 m camera-offset captures
  completed. Five geographically separated sites are covered by
  `preview_ambient_sites.gd`. This is not an exhaustive seam or fly-through test.
- At a fixed water-adjacent camera, 1280x720, RTX 3060 Laptop, Compatibility:
  180-frame whole-viewport means were CPU .977 / GPU 2.919 ms with overlays off,
  CPU .982 / GPU 3.480 ms with overlays on. Approximate delta: .56 ms GPU.
  These are viewport timings, not isolated shader or worst-case measurements.
- Default worst-case additional normal fetch count is nine (three layers times
  three projections), normally fewer on steep faces. Maximum configurable count
  is twelve with both bands set to two. Distant/zero-weight layers skip sampling.

## Remaining visual limits

The old procedural scratches/gashes are absent, and source normal structure is
visible in patches next to base-only rock. Large forms remain shading-only:
no silhouette displacement or cast-shadow ledges are created. Some source strata
can still look repetitive where coverage stays strong, and coarse geometry and
the cliff cap remain limitations. Exact 1.8 m marker matching, exhaustive chunk
seam inspection and continuous camera flyback remain unverified. Do not treat
the implementation and checks as proof of photographic target quality.
