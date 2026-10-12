# Grass landform/material iteration

**Historical report from the preceding iteration.** Current materials, downloads,
measurements and validation are in [TERRAIN_IMPROVEMENT_REPORT.md](TERRAIN_IMPROVEMENT_REPORT.md).

The user's saved terrain preset is unchanged. Runtime changes are in the mesh
sampler and terrain shader; streaming, worker ownership and biome/island scales
remain intact. No foliage, new dependencies or texture downloads were added.

## Visual inspection

`terrain_reference_before.png` is the old overview. `terrain_reference_after.png`
uses the same camera and target. The new field has more relief divisions, lower
saddles, eroded flanks and varying grass/soil exposure rather than the old saturated
ridge plateau. `terrain_reference_close.png` checks rock projection and slopes.
The references remain substantially richer: this is not photographic parity,
physical erosion, or a guarantee that every mountain has an accessible summit.

UV2 shares the geometry's mountain and drainage masks with the shader. Signed
curvature comes from existing normal-grid heights. Normals stay on a shared 32 m
world grid: the attempted 16 m field tripled far-chunk sampling time and was not
retained. The new hierarchy, rather than a global vertex-count increase, supplies
the terrain structure. Fine height octaves remain deterministic at all LODs; they
are not culled per LOD because that would change shared vertex heights.

## Checks

- Deterministic Grass profiles and worker-built arrays: passed.
- Shared chunk heights/normals, curvature and drainage/material channels: passed.
- Shared LOD heights and material channels: passed.
- Island dimensions leave inland relief unchanged: 1,019 samples passed.
- River-striping regression: mean carving curvature 0.0101, one sharp change
  over 2,990 samples (the original faulty implementation had 245).
- Five-octave versus one-octave relief: 7.77x local curvature, water masks unchanged.
- Default sampled summit: a path to lowlands stayed within 35 degrees, checking
  eight subsegments per grid edge. This is not a collision/player-controller test.

## Representative local timings

Hardware reported by Godot: RTX 3060 Laptop GPU, OpenGL Compatibility.
Timings fluctuate with concurrent diagnostics, driver compilation and warm caches.

| Stage | Representative result |
| --- | --- |
| Far 8-resolution chunk: height/noise | 6.49 ms |
| Far chunk: normal field / array assembly | 0.095 / 0.266 ms |
| Near 64-resolution chunk: height/noise | 242.96 ms |
| Near chunk: normal field / array assembly | 1.78 / 3.97 ms |
| Main-thread mesh submission, warm runs | 0.1–0.6 ms (cold outliers observed) |
| Noise microbenchmark, 100k five-octave calls | 33–46 ms |
| Static close view, material / simple-material frames | 3.65 / 3.12 ms |
| Full 1,089-chunk initial load | 6.43 s |
| Moving camera, mean / p95 / max frame | 6.14 / 11.28 / 21.03 ms |

Noise microbenchmark is separate, not an exact attribution of the complete
sampler's noise cost. The static A/B replaces materials on terrain child meshes
(including water), so it is a scene-material comparison, not isolated GPU shader
timestamps. ArrayMesh submission is not GPU completion latency. Collision cost
is absent: the existing freecam terrain does not create collision meshes.

Reproduce with `tools/profile_visual_terrain.gd -- after close` and
`tools/benchmark_streaming.gd` using a graphical Godot run with VSync disabled.
