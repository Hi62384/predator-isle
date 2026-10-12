# Surface correction — September 30

## Implemented

- Removed the baked product-of-sines exposed-ground field responsible for the
  regular brown checker pattern. Rebuilt shared grass and meso masks.
- Fixed world-space macro and meso projections with restrained coordinate
  distortion and a second independently scaled sample. No camera-based scaling.
- Rebalanced exposure-driven dirt, moisture coloration, sparse grass, variable
  debris and selective low-slope bank sediment. Retained existing nine-source
  ambientCG palette; no new PBR downloads or additional grass source families.
- Enlarged the three offline hierarchical fracture networks. Added bounded
  recess normal response alongside existing albedo and roughness modulation.
- F5 views now include grass macro, soil, drainage, dryness, cliffs, fractures,
  scree, meso controls, micro disabled, region classifier fields and macro-only
  ground. Region fields are highland/drainage/exposure, not discrete region IDs.
- Added `tools/preview_surface_masks.gd` for repeatable shader diagnostics.

Terrain geometry, generator, chunk architecture, saved settings, lighting and
foliage were not changed. Only debug-view cycling changed in chunk_terrain.gd.

## Checks

Godot 4.6.1 Compatibility, RTX 3060 Laptop GPU.

- Final shader rendered all 12 requested diagnostic captures without errors.
- Material binding test passed for both saved/live nine-layer arrays.
- Ground, aerial, hillside, cliff and regional captures inspected during tuning.
- Same cliff captured at offsets 80, 300, 900 and 2400 m. Texture coordinates
  contain no camera-dependent scale. These discrete captures do not replace a
  continuous flight test or prove zero apparent change at every mesh LOD boundary.
- Final 180-frame static far-view viewport means: CPU 0.989 ms, GPU 1.921 ms.
  This measures the whole viewport, not an isolated terrain shader benchmark.
- Streaming benchmark `hierarchy_surface_overhaul.json`: initial 2.418 s;
  moving p95 6.411 ms, max 31.338 ms; 49.152 km span, 117 initial leaves.
  Previous run: initial 2.357 s, moving p95 6.347 ms. Run-to-run timing varies.
  Benchmark preceded the final small sediment and debug-view additions.

## Remaining visual gaps

The observed checker defect is gone in tested views, but the full requested
art direction is NOT achieved. Ground-level grass is still too uniform, broad
soil/rock transitions can look painted, and cliffs still lack the reference's
massive slab-like visual breakup. Far terrain remains relatively pale. Three
reusable fracture maps reduce repetition but cannot guarantee its absence.
Occasional wear masks exist; they are not a terrain-routed branching trail
network. Distinct lush/wet/highland grass source structures remain limited by
the current two grass/sparse-ground sources. These limitations should not be
represented as meeting all eighteen user success criteria.

Preview files: `erosion_surface_mask_0.png`, `erosion_ground.png`,
`erosion_aerial.png`, and `erosion_macro_distance_{80,300,900,2400}.png`.
