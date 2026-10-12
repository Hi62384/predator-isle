# Terrain improvement report — September 27, 2026

## Active implementation and HUD

`project.godot` launches `main.tscn`; its Terrain node runs
`scripts/chunk_terrain.gd`, which schedules `scripts/terrain_mesh_builder.gd`.
`materials/terrain.tres` binds `shaders/terrain_biomes.gdshader` and two new shared
texture arrays. This modifies the normal running test, not an alternate generator.

The HUD queried camera X/Z, not the surface under the crosshair. At the screenshot
position (864.7,7959.1), the saved preset gives about 92.75% Desert beneath the
camera. That does not establish that the visible mountain is Desert. Original
texture bindings were present, not missing placeholders. The main material issue
was the narrow grass/rock palette and slope-dominated assignment. The label now
explicitly says **Biome below camera**.

`Terrain.grass_preview` or user argument `grass-preview` forces Grass in a duplicated
runtime snapshot. The HUD identifies this override. Normal biomes and the saved
`terrain_settings.tres` remain unchanged. Grass coverage 100 is a relative weight;
it does not disable the other biomes by itself.

## Materials and geometry

Eight real ambientCG sources are bound; four were downloaded for this change.
See [asset manifest](../assets/textures/ambientcg/PALETTE_MANIFEST.md) for IDs,
URLs, CC0 license, selected maps, processing and normal-decoding checks.
The six Grass-landscape sources provide dense grass, sparse moss/grass/earth,
brown soil, gravel, lighter weathered rock and darker mineral rock. Desert and
Snow retain distinct sources. Damp earth and dry/highland variants reuse suitable
maps; the palette is not eight recolors of Grass001.

Slope, curvature, drainage, mountain exposure, regional conditions, aspect and
medium patches select surfaces. River margins mix gravel, earth and grass, not a
uniform sand outline. Water elevation is carried in UV.x; the existing renderer
still supplies sea level for every water body.

The shader normalizes up to four contributors per fragment, never interpolating
integer IDs or sampling all eight layers. Triplanar world-space mapping skips
insignificant projections. BC5 normal XY is decoded explicitly and oriented into
each world projection. Explicit texture gradients are computed before divergent
selection branches. Near terrain uses restrained rotated secondary sampling;
distant terrain actually skips normals and secondary color reads while retaining
base color/roughness and macro regions. No parallax, extra terrain pass, unique
chunk texture bake or duplicated source collection.

Ridge crests now vary between sharper and rounded sectors. Erosion is concentrated
by coherent catchment fields, leaving comparatively clean faces between them.
The existing backbone, saddles, tributaries, asymmetric flanks, plains, river
floodplains and lake basins remain. Island and relief scales remain independent.
This is an incremental refinement, not a new drainage architecture.

## Generation changes

- Cache exact island power-cell boundary planes and certify cached owners inside
  eroded boundaries. Coasts are not coarsely interpolated.
- Cache river columns and spatially local lake descriptors; never scan all known
  rivers or lakes per vertex.
- Reuse private worker samplers across chunk jobs; retain bounded caches.
- Skip other-biome noise in pure Grass interiors.
- Reuse immutable index templates by resolution. Existing padded height arrays
  also supply biome/drainage fields; normal-grid intersections reuse those heights.
- Four bounded whole-chunk jobs; completion polling followed by required task
  collection. Workers never touch the SceneTree or GPU. Exit still joins tasks.
- Allow up to 16 commits within the existing 1.5 ms soft budget instead of an
  unconditional two-commit cap. Single uploads cannot be preempted.

Per-sampler caps: 513 island candidate cells, 128 plane sets, 512 cached owners,
4,096 river center entries, 2,048 river columns, 256 lake cells, 4,096 biome labels,
16 index templates. Settings are immutable snapshots; reconfiguration clears
settings-dependent caches. Mesh cache remains capped at 64. Old meshes stay visible
during upgrades; stale results are discarded before ArrayMesh creation. Active
tasks are not preemptively cancelled. No new heading priority or LOD hysteresis.

Radius remains 16 × 256 m, 1,089 resident chunks. Resolutions remain 128/64/16/8,
with only the camera chunk at 128. No LOD-specific height layers were removed.
The existing skirts conceal gaps between mixed-resolution mesh edges.

## Reproduction and debug views

Use Godot 4.6.1, GL Compatibility, VSync disabled, without another diagnostic run
active. Substitute the full installed executable path for `godot` if necessary.

```powershell
godot --path . --windowed --disable-vsync -- grass-preview
godot --path . --windowed --disable-vsync --script tools/profile_visual_terrain.gd -- after close views
godot --path . --windowed --disable-vsync --script tools/benchmark_generation.gd -- repeat
godot --path . --windowed --disable-vsync --script tools/check_streaming_reload.gd
godot --headless --path . --script tools/check_cache_order.gd
godot --headless --path . --script tools/profile_sampler_stages.gd
godot --headless --path . --script tools/benchmark_job_granularity.gd
godot --path . --windowed --disable-vsync --script tools/check_palette.gd
```

F5 cycles shaded, material weights, dominant IDs, unlit base color, normals and
wireframe. ID legend: green=grass, gold=desert, pale blue=snow, tan=lighter rock,
yellow=sparse ground, brown=earth, cyan=gravel, purple=darker rock.

Fixed visual test: seed 73921, saved settings cloned with Grass-only coverage.
Lighting, fog and geometry resolutions are unchanged between comparisons.

| View | Camera | Target |
| --- | --- | --- |
| Aerial | (3200,1194.558,2900) | (1800,444.558,1200) |
| Hillside | (200,560.3494,1440) | (0,400.3494,1200) |
| Water | (-1490,150,-460) | (-1680,0,-720) |
| Ground | (-1560,12.82235,-600) | (-1530,11.82235,-580) |

Captures: `terrain_reference_before.png`, `terrain_reference_after.png`,
`terrain_reference_close.png`, `terrain_reference_water.png`,
`terrain_reference_ground.png`, and `terrain_debug_1.png` through `_5.png`.
After images are downsampled to 1280 pixels for review; rendering was 2560×1346.
Images and bound-palette swatches were inspected. A shadow on/off diagnostic did
not eliminate remaining fine repetition, so shadows were not disabled as a fix.

## Measured results

Godot 4.6.1; RTX 3060 Laptop GPU, driver 596.21; 2560×1346 GL. Seed 73921; original
saved mixed-biome preset; origin camera (0,45,70); radius 16; resolutions 128/64/16/8.
Wait for 1,089 chunks, then move at 250 m/s for six seconds. No distance or geometry
reductions. Workers changed from three to four; commit cap from two to sixteen.

Raw data: [before](generation_before.json), [final after](generation_after_final.json).
Earlier after runs are preserved in `generation_after.json` and
`generation_workers4.json`; they are not substituted for the final result.

| Metric | Before | Final after |
| --- | ---: | ---: |
| Complete 3×3 neighborhood | 0.852 s | 0.447 s |
| Full 1,089-chunk region | 5.818 s | 3.495 s |
| Initial completed chunks/second | 187.2 | 311.6 |
| Entire-run frame median / p95 | 3.934 / 6.027 ms | 5.045 / 8.349 ms |
| Entire-run longest frame | 41.960 ms | 84.350 ms |
| Engine-tracked static allocation | 44.75 MiB | 48.25 MiB |

Final moving-only frame median/p95/max: 5.466 / 8.171 / 15.495 ms. Moving-only
baseline was not separately recorded. Faster generation does **not** mean all
frame metrics improved: the richer shader costs more, and startup outliers remain.
Individual uploads can exceed the soft commit budget. First imports and conversion
are excluded; these runs used prepared assets and previously rendered shaders.
Scheduling, driver state and thermals still affect wall times. These are local
runs, not statistically controlled claims. Earlier after fills were 3.04–3.09 s;
the table deliberately uses the final run rather than the best run.

| Resolution | Worker median / p95 before | Worker median / p95 after | Queue median before → after | Commit median before → after |
| --- | ---: | ---: | ---: | ---: |
| 128 (one initial chunk) | 643.82 / 643.82 ms | 399.38 / 399.38 ms | 27.54 → 29.45 ms | 2.70 → 4.09 ms |
| 64 | 158.93 / 330.32 ms | 113.24 / 199.25 ms | 942.81 → 466.39 ms | 0.66 → 0.98 ms |
| 16 | 16.46 / 31.76 ms | 11.93 / 20.09 ms | 2263.40 → 1235.45 ms | 0.21 → 0.29 ms |
| 8 | 6.17 / 11.03 ms | 5.21 / 8.39 ms | 4317.84 → 2474.43 ms | 0.14 → 0.15 ms |

Memory above is Godot-tracked allocation, **not** total working set or GPU memory.
Compressed palette storage is separately about 53.3 MiB plus driver overhead.
Whole-frame detailed-versus-flat-material checks on the final shader measured
5.63 / 2.91 ms and 6.27 / 4.55 ms. Water also receives the flat override, so this
is not an isolated GPU-timestamp shader comparison.

### Stage profiling

Original independent 10k-sample microbench: island 212.77 ms, biome 21.21 ms,
Grass 213.30 ms, full height 264.31 ms. These overlap and must not be added.
Island ownership work, river-column recalculation and cold per-job caches were
worth optimizing; noise alone was not the explanation.

An uninstrumented final Grass resolution-64 build measured roughly 119.66 ms for
height/fields, 1.00 ms for normal-grid work, 4.78 ms array preparation and 0.43 ms
main-thread mesh submission. Material controls come from that same height loop and
curvature grid, not another pipeline or a texture bake. GPU completion is not timed.

[sampler_stages.json](sampler_stages.json) contains diagnostic-subclass timings:
for resolution 64, island 33.00 ms, biome 16.23 ms, Grass including water 97.23 ms;
nested river-descriptor queries 14.88 ms and lake queries 5.88 ms. Timestamp and
dynamic-dispatch overhead makes this slower than production. Water carving remains
inside Grass; descriptor measurements are not all hydrology work. No collision
generation exists to measure.

[Job-granularity experiment](job_granularity.json): four 128-resolution padded
height grids, at most four concurrent jobs, three trials. Whole-chunk median
303.64 ms versus four row blocks/chunk at 317.31 ms. This tests the sampling
bottleneck, not a second complete mesh builder. Results overlap; blocks did not
consistently win, so chunk-level scheduling was retained.

## Validation

- Deterministic Grass, worker arrays, shared chunk heights/normals/curvature and
  drainage channels: passed. Mixed-LOD shared samples and boundary normals passed.
- 3,000 reverse-order samples with eviction: matching heights/control fields;
  cache-size bounds passed.
- Five unload/reload phases restored all 1,089 chunks. Origin vertex bytes matched
  on both returns; worker and mesh pools stayed bounded.
- Island size left 1,019 shared inland height samples unchanged.
- River-striping regression: mean carving curvature 0.01009, one sharp change in
  2,990 samples.
- Five versus one octave: 7.77× local curvature; water masks/beds unchanged.
- Ocean spacing measured 1, 32, 250 and 600 m. The test now disables inland rivers
  and lakes, which should not count as ocean straits.
- One sampled summit has a 35-degree-or-less route to lowlands with intermediate
  slope checks. Not a player-physics or all-mountains guarantee.
- Aerial, hillside, ground, water and all five debug views rendered and inspected.
  Eight bound array layers, formats, mipmaps and BC5 decoding errors verified.
- Final editor scan/import completed with no reported script parse failures. Godot
  emitted a language-server `!thread.is_started()` warning on editor shutdown;
  this is recorded rather than presented as a completely clean editor log.

## Remaining limits

Surface families and regional patches are distinguishable, but this is **not
photographic parity** with the reference collages. Some faces remain rounded,
some boundaries look painted at aerial distance, and fine texture repetition
remains visible in places. No foliage, stronger fog, blur or changed lighting was
used to hide this.

Water remains one sea-level plane, without elevated lake surfaces or downhill
river water meshes. The explicit surface-height query returns that actual level.
The freecam scene has no terrain collision. Export/mobile/Vulkan/other hardware,
long-duration working-set/VRAM profiling and isolated GPU timings were not tested.
Settings still apply on restart rather than through live revision changes.

## Changed files

Runtime: `scripts/chunk_terrain.gd`, `scripts/terrain_mesh_builder.gd`,
`scripts/free_camera.gd`, `shaders/terrain_biomes.gdshader`, `materials/terrain.tres`,
two `materials/palette_*.tres` arrays and sixteen compressed `palette_*.res` Images.
`main.tscn`, `project.godot` and the saved terrain preset were not retuned.

Assets: four new ambientCG map folders, source-directory `.gdignore`,
`PALETTE_MANIFEST.md`, source index update. Two unused uncompressed intermediates
created during this task were removed; source maps and rebuild tools remain.

Tools: `fetch_terrain_palette.ps1`, `build_terrain_palette.gd`,
`inspect_terrain_assets.gd`, `check_palette.gd`, `profile_sampling.gd`,
`profile_sampler_stages.gd`, `profile_visual_terrain.gd`, `benchmark_generation.gd`,
`benchmark_job_granularity.gd`, `check_cache_order.gd`, `check_streaming_reload.gd`,
and the island-spacing test correction. JSON/PNG results are diagnostic artifacts,
not streamed runtime textures.
