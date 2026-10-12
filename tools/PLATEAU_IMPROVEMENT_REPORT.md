# Plateau, cliff-material and streaming revision — September 27, 2026

## Implemented in the active terrain

The running `main.tscn` still uses `scripts/chunk_terrain.gd`, its existing
WorkerThreadPool builders, shared terrain material, square chunks and LOD rings.
No replacement terrain architecture, foliage, props, stronger fog or lighting
changes were introduced. The saved `terrain_settings.tres` was preserved.

The Grass sampler now creates a signed geological plateau footprint, a broad
talus transition, a much narrower cliff transition and a gently varying cap.
The old broad blend often never reached a proper flat top. Plateau walls have
irregular headlands/buttresses and a two-part ledge profile. Mountain backbone
crest smoothing is narrower; plains and hills retain their separate masks.
Plateau caps suppress sea-level channels and lakes continuously instead of being
cut through by the lowland water system. Existing floodplains and basin shaping
are retained, not replaced with a new hydrology system.

Material selection gives slope, convexity, concavity, highland exposure and
drainage priority over random patches. Thin-soil surfaces use sparse ground;
concave slopes below highlands favor gravel/debris. Cliffs get stronger rock
exposure and an additional real fractured-rock surface at structure scale.
There is no universal sand outline around Grass water bodies.

Actual ambientCG **Rock034** Color / NormalGL / Roughness files were downloaded,
inspected and integrated as palette layer 8. Its 78 m horizontal / 128 m vertical
world projections provide visible rock fractures beyond the fine-detail fade.
The macro normal remains active at distance; the underlying fine rock remains
available near the camera. This is a real source texture, not a preview image.
The palette now has nine sources, not nine samples at every pixel: the existing
top-four surface selection remains, with the extra layer restricted to cliffs.
See `assets/textures/ambientcg/PALETTE_MANIFEST.md` for maps, processing and CC0
sources, including the inspected but unused Rock028 development download.

## Striping investigation

The plateau preview renders identical views shaded, unlit and with a flat gray
diagnostic material. Fine repetitive surface patterns were visible in unlit
texture output but absent in the flat diagnostic. Pixel-footprint filtering now
replaces subpixel micro detail with measured material averages and actually
skips its texture fetches. Near-camera source PBR maps remain active.

An enlarged ground-texture coverage experiment reintroduced long repeating
streaks and was removed after inspecting the result. The cliff layer was kept.
This does not establish that every possible striping source is gone: coarse
far-LOD angular cliff edges and some visible texture repetition remain.

## Measured performance

Godot 4.6.1 Compatibility, RTX 3060 Laptop GPU, 2560×1346, seed 73921, saved
mixed-biome preset, 1,089 chunks, radius 16, 256 m chunks, four workers. LOD
resolutions remain 128 / 64 / 16 / 8, with the same ring distances. No draw-distance
or vertex-quality reduction was used to obtain the speedup.

| Measurement | Fresh pre-edit baseline | Final verified warm run |
| --- | ---: | ---: |
| Nearby 3×3 ready | 0.424 s | 0.415 s |
| Visible region filled | 3.090 s | 2.312 s |
| Initial chunks/second | 352.4 | 471.0 |
| LOD 128 worker, one chunk | 348.73 ms | 276.01 ms |
| LOD 64 worker median / p95 | 101.64 / 180.42 ms | 93.02 / 180.66 ms |
| LOD 16 worker median / p95 | 10.50 / 18.80 ms | 9.17 / 16.06 ms |
| LOD 8 worker median / p95 | 4.91 / 8.23 ms | 4.10 / 7.50 ms |
| LOD 8 queue median / p95 | 2110.92 / 2996.25 ms | 1717.52 / 2235.91 ms |
| LOD 8 commit median / p95 | 0.128 / 0.335 ms | 0.073 / 0.240 ms |
| Frame median / p95 / max | 4.89 / 8.97 / 107.23 ms | 6.05 / 6.54 / 118.57 ms |
| Moving-frame p95 / max | 9.53 / 19.66 ms | 6.52 / 12.17 ms |
| Godot static memory | 48.87 MiB | 55.62 MiB |

Visible fill is **25.2% shorter**, throughput **33.7% higher**. Nearby latency is
essentially unchanged. Median whole-frame time is higher and the initial maximum
spike is not improved; these measurements are not an isolated GPU benchmark.
Static memory is not total process memory or VRAM.

Raw results: `generation_plateau_before.json` and
`generation_plateau_final_verified.json`. Intermediate warm eight-chunk batch
runs filled in 2.38–2.50 s. Four-chunk batches took 2.55 s. Six workers took
2.41 s versus 2.38 s with four in that comparison, so four workers remain default.
The cold `plateau_batched` run took 4.02 s and included a 1.53 s first-render stall;
it is retained separately rather than counted as ordinary generation latency.

The measured costs led to these changes:

- Bounded batches of up to eight small distant chunks amortize frame-poll delays.
  Nearby high-detail chunks stay individual jobs. Workers prepare arrays only.
- Completed tasks are collected exactly once with the required completion wait;
  scene/GPU resource creation stays on the main thread under its existing soft
  1.5 ms budget. In-flight coordinates prevent duplicate work. Ready results are
  bounded; stale results are discarded before mesh creation.
- Worker-local immutable settings, samplers and bounded caches are reused.
- Biome cells cache their exact four corner labels. Uniform interiors skip
  repeated blend arithmetic; boundary weights are unchanged.
- Conservative inland certificates skip repeated island half-plane searches only
  when the coastline blend is provably saturated. Public island-mask queries
  remain exact.
- One world-aligned Grass structural lattice serves every LOD. Sharp walls,
  crests and active water/bank regions blend toward exact sampling. This is not
  dropping different height octaves at different LODs.

The lattice is an explicit approximation, not an exact speedup: the retained
4 m default measured 0.0798 m RMS, 0.0498 m p95 and 3.434 m worst height error
against the raw function over 5,000 sampled positions. An 8 m version reached
about 15 m worst error and was rejected. These are sampled errors, not a global
mathematical bound. Set Grass Field Spacing to 1 for finer structural sampling.

`sampler_stages.json` contains instrumented stage timings. In the final origin
128-resolution diagnostic: height/fields 187.43 ms, normal field 0.54 ms and mesh
array preparation 17.76 ms. Biome 20.85 ms, island 64.78 ms and Grass 54.23 ms are
nested inside height/fields, not additional costs. This diagnostic warms caches
with lower resolutions first and adds timing overhead; it is not interchangeable
with threaded streaming numbers. No unique control textures are baked. Material
controls reuse sampled fields; there is no terrain collision in this freecam scene.

## Reproduce and inspect

Run from the project folder with your Godot executable:

```powershell
& $godot --path . --script tools/preview_plateau.gd
& $godot --path . --script tools/benchmark_generation.gd -- comparison
& $godot --path . -- grass-preview
```

The preview clones the saved settings into pure Grass without editing the saved
preset. Seed 73921 finds the cap at **(0, 241.0545, 160)**, outward toward -Z.
Cliff camera **(60, 266.0545, -160)** looks at **(0, 171.0545, 160)**.
Distant camera **(400, 861.0545, -1440)** looks at the cap. Player-height camera
**(0, 242.569, 230)** looks along **(18, -1.1, 12)** from that position.

Inspected render outputs: `plateau_overview.png`, `plateau_face.png`,
`plateau_distant.png`, `plateau_ground.png`, `plateau_unlit.png` and
`plateau_flat_lit.png`. F5 cycles material weights, dominant material, unlit,
normal and wireframe diagnostics. Cliff layer 8 is orange in material diagnostics.
The HUD's biome label is the biome **below the camera**, not a raycast to whatever
terrain the camera is looking at. Normal biome behavior remains outside preview.

New tuning controls: Grass Cliff Width (48 m default), Grass Talus Width (240 m),
Grass Field Spacing (4 m); default Grass Plateau Height is now 240 m. Existing
plateau frequency, escarpment strength and independent terrain-shape scale remain.
ChunkTerrain also exposes Distant Job Batch (8). Settings apply on restart.

## Validation and limits

Passed deterministic worker / shared chunk and mixed-LOD sample tests; 3,000
reverse-order heights and surface controls; cached/original biome-weight
equivalence; cache limits; coastline certificate checks at three island sizes;
island-size independence over 1,019 shared inland samples; river stripe regression;
fractal-detail/water invariance; worker/debug settings parity; sampled 35-degree
summit-to-lowland route; nine-layer bindings/mips/compression/normal decoding.
Rock034 BC5 mean angular normal error: 3.20 degrees over 1,024 samples.

Five full unload/reload visits each reached 1,089 chunks, with bounded jobs, ready
queues, worker pools and mesh cache. Origin vertex bytes were identical on return.
Visits included (18000,400,-7000) and (-14000,400,11000). This is a short streaming
stress test, not a long-duration memory/VRAM soak.

This is a substantial implemented iteration, **not photographic parity or a claim
that all requested visual success criteria are met**. Far 32 m geometry still
shows angular cliff edges. Some mountain regions remain rounded and cap/valley
materials can still appear too uniform from high altitude. Macro fractures are
texture/normal structure, not actual overhangs or deep geometric fissures. Water
still uses the existing sea-level plane; elevated lakes/downhill water meshes were
not implemented. No collision/controller climb test, export/mobile/Vulkan test,
isolated GPU timing or long-duration profiling was performed.

## Changed implementation and assets

- `scripts/terrain_mesh_builder.gd`, `scripts/terrain_settings.gd`,
  `scripts/chunk_terrain.gd`, `shaders/terrain_biomes.gdshader`.
- Both `materials/palette_*.tres` arrays; new
  `palette_color_Rock034.res` and `palette_normal_Rock034.res`.
- Rock034 and inspected Rock028 development map folders; palette manifest.
- Palette fetch/build/inspection/check tools, benchmark harness, cache and reload
  checks, new plateau preview and structural-field accuracy test, JSON/PNG results.

The previous `TERRAIN_IMPROVEMENT_REPORT.md` describes the preceding iteration;
its performance measurements should not be confused with this revision.
