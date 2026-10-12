# Stable material layers — September 29, 2026

## Implemented

No height-generation, landform or terrain resolution changes in this pass.
Removed the shader path that enlarged ordinary PBR texture luminance only when
micro detail disappeared. Removed per-fragment procedural joint searches.

Three new 2K mipmapped compressed control textures are generated offline:
cliff fracture/weathering/shelf, directional grass coverage/wear, and meso soil
patches. They are separate assets from the existing nine ambientCG PBR materials.
Bindings are saved in the material and explicitly installed at terrain startup.
See `materials/MACRO_ASSET_MANIFEST.md` for channels, scales and provenance.

Macro layers are evaluated at all distances. Meso masks affect material weights
at fixed 28 m scale. Micro PBR and normal evaluation still fade with projected
footprint/distance, but macro UVs never change scale or depend on the camera.
Grass saturation is reduced. Sparse worn masks increase soil coverage only on
suitable gentle/exposed/drainage surfaces; they are not functional roads.
Cliff maps use two differently sized vertical world projections, retaining
direction while reducing repeated patterns. Repetition is reduced, not eliminated.

Runtime assets total approximately 16 MiB including mip chains. All chunks share
them. No downloads, per-chunk bakes, runtime conversion or generation were added.
PNG mask previews are development diagnostics, not runtime shader inputs.

## Validation and measurements

Godot 4.6.1 Compatibility, RTX 3060 Laptop GPU. Actual main scene rendered.
The first sinusoidal grass map produced obvious contour-like stripes in the
render; it was replaced with an offline seamless elongated noise-based flow map.

`preview_macro_distance.gd` captures the same focus (5600,247.3867,3840), seed
73921, explicit Grass preview, at offsets (d,d/4,0), d=80/300/900/2400 m.
Outputs `erosion_macro_distance_*.png` were inspected. Major surface patterns
remain visible at the far view. Coordinates are camera-independent by code
inspection. These are four sampled views, not an exhaustive continuous-motion
or pixel-correspondence proof. Geometry LOD changes remain visible.

Final static 2.4 km view, 180 frames: measured viewport render CPU mean 0.847 ms,
GPU mean 1.751 ms. These are whole viewport timings, not isolated terrain shader
cost and not a matched before/after GPU comparison.

Streaming run `hierarchy_macro_fixed.json` (before the final grass-map revision):
49.152 km footprint, 117 initial leaves, initial fill 2.357 s, moving p95 6.347 ms,
maximum 27.915 ms. Coverage/ownership/balance assertions passed, including fast
movement and queued teleports. Earlier pass had p95 8.526 ms; this single run
does not prove a GPU speedup. Final grass asset revision received render/GPU
validation, not a repeated complete streaming benchmark.

Shader work: three shared grass/meso mask fetches; cliff pixels add two mask
fetches. Existing top-four material selection remains. Far normal fetches remain
disabled. The removed fallback previously fetched macro PBR once per contributor;
joint-search loops are gone. No claim of universal hardware performance.

## Remaining limitations

The result still does not match the photorealistic plateau reference. Cliff
fractures need more artistic irregularity; some repeated meso patches remain.
Material masks respond to existing terrain data but are not watershed-derived
flow maps. Sand-specific new source materials were not added; existing palette
is reused. GPU baseline comparisons and a recorded continuous fly-away remain
unfinished. No further draw-distance increase was retained: coarse silhouette
artifacts already exist at 49.2 km and increasing coverage alone would worsen
the requested silhouette criterion. Geometry and streaming architecture remain
unchanged except explicit macro-resource binding.

## Changed files

- `shaders/terrain_biomes.gdshader`
- `materials/terrain.tres`
- `scripts/chunk_terrain.gd` (shared bindings only)
- `materials/cliff_macro.res`, `grass_macro.res`, `meso_macro.res`
- `materials/*_mask_preview.png`, `MACRO_ASSET_MANIFEST.md`
- `tools/build_macro_masks.gd`, `preview_macro_distance.gd`

Regenerate assets with `godot --headless --path . --script tools/build_macro_masks.gd`.
Capture distances with `godot --path . --script tools/preview_macro_distance.gd`.
