# Geological erosion iteration — September 28, 2026

## Scope and active implementation

Modified the existing `main.tscn` terrain path, not an alternative generator.
`scripts/chunk_terrain.gd` dispatches worker-owned
`scripts/terrain_mesh_builder.gd` instances and binds the shared
`shaders/terrain_biomes.gdshader`. No foliage, props, architecture replacement,
global vertex-density increase, draw-distance reduction, lighting change, or fog
increase. Saved biome coverage and island settings are unchanged.

This is an implemented improvement, **not a claim that every photorealistic
success criterion is met**. Final rendered captures still show overly uniform
plateau interiors, some smooth mountain shapes, coarse distant cliff silhouettes,
and visible procedural character. Streaming is slower than this iteration's
fresh baseline; see the measured results below.

## Changes

- Plateau walls now vary between competent cliffs, two-step shelves and wider
  eroded slopes. Broad rock-strength fields vary cap height and apron width.
  Medium boundary displacement is less high-frequency, reducing noisy teeth.
- Localized drainage cuts descend through plateau edges. Their influence is
  explicitly bounded to the rim so they cannot accidentally carve distant plains.
  Wider fan-shaped deposits form below selected exits.
- Plateau tops retain broad height drift and restrained rolling relief.
- Mountain backbones are more elongated, with side-dependent slope exponents,
  peaks and saddles. Small hill contributions are suppressed inside strong ranges.
- Lowland river corridors are wider; floodplain width varies, with shallow
  former-channel depressions. Lake basin extent and outer shore elevation vary.
- Geometry generates three reusable controls: talus, incision and competent
  cliff. They drive gravel, drainage ground and cliff exposure instead of new
  independent material noise stacks. All three are carried in CUSTOM0 RGB_FLOAT.
  A rendered diagnostic found only red survived the attempted byte format;
  the explicit float format passes CPU round-trip and GPU RGB tests.
- Less pale dry ground; richer healthy grass, darker drainage grass, neutral
  gray-brown debris, narrower irregular exposed-rock transitions.
- Rock034 uses two rotated/scaled samples at 24 m horizontal / 28 m vertical
  projection, rather than stretching its original detail across 78 m / 128 m.
  Independent interrupted vertical joint families, shelf weathering and broad
  recess shading remain visible when fine normals stop being sampled. These
  macro joints are shading detail, not physical openings in the mesh.
- Added `grass_plateau_erosion` (0–1, default 0.9) and `grass_talus_relief`
  (0–40 m, default 16). F5 now also cycles to geology controls:
  red = scree, green = incision/drainage, blue = competent cliff.

## Runtime work and profiling

Nested diagnostic timers separate regional fields, ridge/valley shaping,
plateau/cliff/talus, fractal detail and water/banks. They run only with
`profile_build`; no per-stage timestamps in normal gameplay.

Water/bank shaping was the largest measured raw substage. In one instrumented
LOD64 sample it consumed 35.76 ms, versus 16.10 ms regional fields, 13.27 ms
plateau/cliff/talus, 4.95 ms fractal detail and 1.18 ms ridge/valley work.
These nested, instrumented timings are not additive with outer stage timings
and are not interchangeable with concurrent worker wall times.

Optimizations implemented:

- Skip tributary work when its lowland contribution is exactly zero.
- Skip plateau shaping outside its maximum influence and simplify deep interiors
  with the same cap formula.
- Reuse an exact integer-coordinate height/control cache across mesh and normal
  halo queries, bounded to 8,192 entries per worker. Noninteger and very distant
  positions bypass it; no coordinate rounding changes terrain.
- Refine active banks rather than treating the entire broad damp valley as a
  precision-critical water edge.
- Do not generate lattice corners with exactly zero interpolation weight.
- Continue sharing the existing world-space normal lattice, texture arrays,
  topology templates, bounded worker batches and budgeted main-thread commits.

The canonical geometry is still shared across LODs. This iteration does **not**
claim to eliminate every sub-grid geometric octave at far LOD: doing that without
compatible transitions would change banks and borders. Fine shader normal work
is skipped at distance, while macro cliff shading stays active. No unique baked
chunk textures or runtime downloads. Collision cost is absent because the
existing test is a freecam scene without generated terrain collision.

## Reproducible measurements

Godot 4.6.1, Compatibility/OpenGL, RTX 3060 Laptop GPU, 2560×1346.
Seed 73921, saved mixed-biome preset, radius 16 (1,089 chunks), chunk size 256 m,
LOD resolutions 128/64/16/8, four workers, distant batch eight. Initial nearby
readiness means the central 3×3 meshes, **not gameplay collision readiness**.
After initial fill, the benchmark moves east at 250 m/s for six seconds.

Run:

```powershell
& '<Godot console executable>' --path . --script tools/benchmark_generation.gd -- my_run
```

| Measurement | Fresh before | Final run 1 | Final run 2 |
| --- | ---: | ---: | ---: |
| Nearby 3×3 ready | 0.356 s | 0.440 s | 0.460 s |
| All 1,089 chunks | 2.023 s | 2.428 s | 2.478 s |
| Initial chunks/second | 538.3 | 448.5 | 439.5 |
| Moving frame p95 | 6.916 ms | 6.584 ms | 6.594 ms |
| Moving frame maximum | 19.816 ms | 11.442 ms | 10.381 ms |
| Overall frame maximum | 161.499 ms | 127.891 ms | 125.780 ms |
| Godot static memory | 53.49 MiB | 57.86 MiB | 59.98 MiB |

Final run 2 per-chunk timings, milliseconds:

| Resolution | Worker median / p95 | Queue median / p95 | Commit median / p95 |
| --- | ---: | ---: | ---: |
| 8 | 4.216 / 7.867 | 1866.771 / 2401.686 | 0.075 / 0.232 |
| 16 | 10.460 / 18.336 | 1067.477 / 1319.338 | 0.108 / 0.312 |
| 64 | 105.335 / 195.584 | 452.664 / 773.759 | 0.981 / 1.442 |
| 128 (one chunk) | 271.894 / 271.894 | 23.869 / 23.869 | 2.203 / 2.203 |

Raw results: `generation_erosion_before.json`,
`generation_erosion_lattice_1.json`, `generation_erosion_lattice_2.json`.
Intermediate experiments remain separately named. The initial cold-shader run
(`generation_erosion_first.json`, 4.103 s, including a 1.7 s stall) is excluded
from the warm comparison. There was no concurrent benchmark process. Thermal
and system-load variation were not controlled; the data does not establish a
speedup. Final fill is roughly 20–22% slower than the single fresh baseline.
Steady FPS alone is not evidence of faster generation. Static memory excludes
driver/GPU allocation and is not total process working set.

## Visual reproduction

`tools/preview_erosion.gd` loads the actual main scene and clones a Grass-only
preview preset. Normal biome behavior outside this preview is unchanged. The
ordinary HUD biome label describes the camera XZ location, not the terrain the
camera is looking at. The preview avoids that ambiguity.

Run `--path . --script tools/preview_erosion.gd` with the Godot console executable.
It waits for streaming, uses normal scene lighting and captures:

| Capture | Camera XYZ | Target XYZ |
| --- | --- | --- |
| `erosion_inland_cliff.png` | -4545, 380.54, 2110 | -4160, 235.54, 2080 |
| `erosion_cut.png` | 600, 891.9155, -280 | 1120, 141.9155, 320 |
| `erosion_ridges.png` | 3760, 1158.444, 6540 | 2560, 478.444, 5440 |
| `erosion_aerial.png` | 3300, 1480, 2900 | 1800, 180, 1200 |
| `erosion_ground.png` | 0, 279.9848, 230 | 18, 278.8848, 242 |

`erosion_geology.png` uses the inland cliff viewpoint in control-debug mode.
Rendered cliff, cut, ridge, ground and geology images were inspected. The final
lattice optimization only removes zero-weight evaluations; seam/determinism
tests were rerun afterward. Images were captured before that identical-output
optimization. These are not rigorously matched before/after visual captures:
the supplied user screenshots do not include recoverable camera orientations.

## Validation

Passed:

- `check_geological_edges.gd`: cliff cuts, scree, strong walls, gentle aprons and
  finite geology controls; 118 cut samples, 226 scree samples in its scan.
- `check_plateau_fields.gd`: canonical structural interpolation error RMS
  0.0528 m, p95 0.0454 m, maximum 1.589 m; coast checks at three island scales.
- `check_grass_terrain.gd`: deterministic worker output, matching shared chunk
  vertices/normals/control data and mixed-LOD samples. Rerun after final change.
- `check_cache_order.gd`: 3,000 reverse-order samples, integer-cache/raw parity,
  noninteger bypass and bounded caches. Rerun after final change.
- `check_terrain_shape_scale.gd`: island size leaves 1,019 inland samples unchanged.
- `check_river_striping.gd`: river-cut curvature 0.02151, two sharp changes.
- `check_grass_fractal.gd`: five-octave/one-octave curvature ratio 7.766,
  2,432 changed samples, unchanged water masks/beds.
- `check_mountain_access.gd`: a sampled route below 35 degrees from a 440.21 m
  summit; not a physics-controller test or universal climbability guarantee.
- `check_terrain_settings.gd`: settings, normalized blends and worker/debug parity.
- `check_geology_binding.gd`: GPU all-channel coverage and CPU mesh round-trip.
- `check_streaming_reload.gd`: five complete 1,089-chunk loads at origin and
  distant positions, byte-identical origin reload and bounded pools/caches.

## Assets and remaining limitations

No new textures downloaded this iteration. Existing nine-source ambientCG palette
is reused; actual IDs, maps, CC0 license and processing are in
`assets/textures/ambientcg/PALETTE_MANIFEST.md` (updated cliff scale).

Still incomplete relative to the target: very broad tops remain visually too
uniform; some far cliffs retain angular LOD silhouettes; fracture shading is
still recognizable as procedural in places; some terrain/material transitions
remain soft. This is not photorealistic terrain yet. Elevated plateau ponds and
descending stream surfaces are not implemented: the current water renderer is
one sea-level plane, and pretending it supplied local-height water would be
incorrect. No overhangs, true fractured blocks, hydraulic erosion, or collision
controller were introduced. The measured streaming regression also remains a
follow-up issue rather than being concealed by a quality reduction.

## Changed implementation and diagnostics

Runtime: `scripts/terrain_mesh_builder.gd`, `scripts/terrain_settings.gd`,
`scripts/chunk_terrain.gd`, `shaders/terrain_biomes.gdshader`.
Diagnostics: `tools/profile_sampler_stages.gd`, `tools/profile_visual_terrain.gd`,
`tools/check_grass_terrain.gd`, `tools/check_cache_order.gd`,
`tools/check_streaming_reload.gd`, `tools/check_geological_edges.gd`,
`tools/check_geology_binding.gd`, `tools/preview_erosion.gd`.
Supporting outputs: captures, benchmark JSON, this report and asset manifest.
