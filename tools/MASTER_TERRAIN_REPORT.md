# Terrain repair and hierarchical streaming — September 28, 2026

## Status

Implemented in the existing running main scene, generator, shader and worker
pipeline. The white/cyan material regression is fixed and variable-size streaming
is operational. This is **not** a claim that the photorealistic target or every
requested landform is complete. Captured aerial views still show overly smooth
ground, coarse distant features and insufficient geological/material richness.

## Root cause and material repair

`materials/terrain.tres` had lost both palette array bindings although the source
assets and array resources still existed. Restoring them fixed the white/cyan
cliffs. The diagnostic deliberately unbinds the arrays to reproduce the failure
at identical geometry and lighting, then captures correctly bound rendering.
ChunkTerrain now explicitly binds and verifies both nine-layer arrays at startup.

BC5 RG normal reconstruction is normalized. Reoriented triplanar normals now
convert tangent XY into surface gradients before projection blending. Mesh
normals were not inverted to compensate for a material failure. The macro crack
overlay was reduced and interrupted by source rock variation; it still needs
better geological patterning. No lighting or fog adjustment was used to hide it.

F5 adds normal-maps-off lighting, mapped normals and quadtree bounds to the
existing material/geology/unlit/wireframe views. Texture arrays are shared by
per-level materials. Instance uniforms were avoided after a staging test exposed
the Compatibility renderer's instance-uniform buffer limit.

No new textures were downloaded. The existing nine ambientCG materials are
listed in [the manifest](../assets/textures/ambientcg/PALETTE_MANIFEST.md).

## Geometry and spatial streaming

- Existing Grass fields now receive broad geographic province controls for calm
  plains, folded highlands, sedimentary plateaus, basin-prone and incised areas.
  Geographic scale is independent of island and biome size.
- Plateau faces retain finite widths (96 m minimum in this pass). Eroded weak
  sections have wider approach slopes, restoring a sampled walkable route.
- River corridor width and lake availability respond to regional conditions.
  This remains the existing sea-level water system, not a new hydrology solver.
- New `terrain_partition.gd` only selects spatial leaves. The same mesh builder
  and canonical terrain function generate every level.
- World-aligned parent tiles double in width; adjacent leaves differ by at most
  one level. Root/leaf hysteresis and bounded caches limit churn.
- Worker jobs prepare numerical mesh arrays. Main-thread uploads stage hidden
  replacements; the complete desired partition is switched atomically. Old
  coverage remains visible while new coverage is being prepared.
- `request_teleport` holds the camera until destination terrain is ready. Direct
  camera position writes bypass this guarantee.
- Sparse distant normal grids use canonical derivative sampling rather than
  allocating a dense 32 m grid across every 8 km parent.

## Measurements

Godot 4.6.1 Compatibility/OpenGL, RTX 3060 Laptop GPU, 2560×1346, seed 73921,
saved mixed-biome preset, four workers. Imports and cold shader compilation are
excluded from the final warm runs. Historical baseline files are preserved;
they were recorded before this pass rather than reconstructed after edits.

| Configuration | Initial full fill | Initial chunks | Square width |
| --- | --- | --- | --- |
| Previous fixed grid, erosion_lattice runs 1–2 | 2.428 / 2.478 s | 1,089 | 8.448 km |
| Hierarchy final_1 | 1.587 s | 99 | 24.576 km |
| Hierarchy final_2 | 1.979 s | 99 | 24.576 km |
| Hierarchy profiled_final | 2.122 s | 99 | 24.576 km |

This is a coverage/LOD architecture comparison, **not identical geometry work**.
The footprint is 2.91 times wider (8.46 times the area). The camera leaf remains
128 segments and surrounding level-zero leaves 64; large parents use 16 segments
(level one uses 32). Initial level-zero coverage is 24 leaves, versus the old
25-chunk near ring. Coarse distant geometry is a real quality tradeoff.

**Startup regression:** the previous central 3×3 terrain became available in
about 0.44–0.46 s. The complete-cut startup now shows terrain only at full fill,
1.59–2.12 s. Independent safe subtree commits would improve this.

Final three runs: moving p95 frame time 6.48–6.60 ms; maximum 17.09–38.35 ms.
The instrumented final run measured maximum planning 11.929 ms and atomic swap
10.105 ms. The upload budget does not cap these operations. Route assertions
also contribute CPU cost; these are not isolated GPU shader measurements.
Queued teleports took approximately 1.54–3.18 s. Godot static memory was about
53 MiB, **not** total process or GPU memory. Raw results:

- `hierarchy_final_1.json`
- `hierarchy_final_2.json`
- `hierarchy_profiled_final.json`

Run `godot --path . --script tools/benchmark_hierarchy.gd -- label` to repeat.
The harness exercises 1.5, 7, 1500 and 5000 m/s, three queued teleports, active
coverage, non-overlap, balancing, hidden staging and bounded cache invariants.

## Reproducible visual checks

Use seed 73921 and `-- grass-preview` for Grass-only screenshots without changing
the saved preset. Normal biome HUD information describes the camera's horizontal
position, not the terrain at the center of its view.

| View | Camera XYZ | Focus XYZ |
| --- | --- | --- |
| Near cliff repair | 5670, 260, 3840 | 5600, 247.39, 3840 |
| Broad plain | 39600, 608.98, 8900 | 38500, 8.98, 7700 |
| Ridge province | -17800, 1183.14, 18000 | -18900, 583.14, 16800 |
| Drainage province | 41000, 609.98, 28500 | 39900, 9.98, 27300 |

`preview_normal_repair.gd` captures bound/unbound, unlit, geometric and mapped
normal comparisons. `preview_provinces.gd` captures three regional sites. Images
were actually rendered and inspected. The file named `erosion_province_basin.png`
shows an incised drainage valley; it does not prove a convincing lake basin.
`hierarchy_view_0.png` and `hierarchy_view_9.png` show shaded and LOD-bound views.

## Tests run

Passed: saved/live material bindings; nine-layer BC3/BC5 palette decoding;
partition coverage/overlap/balance; canonical parent/child shared heights,
normals and surface values through levels 1–5; Grass determinism/thread/edge
checks; repeated unload/reload with byte-identical origin data and bounded caches;
geological edges; plateau fields; cache-order independence; island/shape scale
independence; river striping regression; Grass fractal test; settings validation.
After broadening eroded approaches, the mountain access test found a sampled
route below 35 degrees (1,137 nodes). This is not a player-controller/collision
test or a guarantee that every peak is walkable.

Final Grass and parent/child tests were repeated after the last geometry edit.
Default 256 m base tiles were tested; arbitrary non-power-of-two base sizes and
every exported quality setting were not exhaustively validated.

## Remaining limitations / unfinished requirements

- Visuals are still short of the reference: flat-looking distant grass, overly
  simple cliff patterns, and coarse sawtooth silhouettes remain in some views.
- Skirts cover boundaries; full stitched transition meshes and geomorphing are
  not implemented. Shared sample equality does not eliminate LOD popping or
  guarantee identical slopes between vertices. Narrow far features can disappear.
- The entire cut commits as one transaction, not independent subtree commits.
  Startup latency and main-thread plan/swap spikes need further optimization.
- Terrain collision remains absent in this free-camera test. Collision timing
  and walkable physical gameplay were not measured.
- Water remains one sea-level plane. Elevated lakes, downhill water surfaces,
  connected lake routing and all requested geographic archetypes are unfinished.
  Distant water repetition is still visible.
- No claim of total memory, long-duration exploration soak, all settings/seed
  coverage, or complete per-stage GPU/material profiling.

## Changed implementation files

- `materials/terrain.tres`
- `shaders/terrain_biomes.gdshader`
- `scripts/chunk_terrain.gd`
- `scripts/terrain_partition.gd` (new spatial selector)
- `scripts/terrain_mesh_builder.gd`
- `scripts/terrain_settings.gd`
- `scripts/free_camera.gd`
- Benchmark/preview/regression scripts under `tools/`, this report,
  `tools/STREAMING.md`, `TERRAIN_TUNING.md`, and palette manifest notes.

The saved `terrain_settings.tres` was not retuned or overwritten.
