# Terrain streaming

Current measurements and caveats: [September 28 report](MASTER_TERRAIN_REPORT.md).

ChunkTerrain schedules up to four independent WorkerThreadPool jobs. Each job owns
its FastNoiseLite samplers and produces packed vertex/index arrays without accessing
the scene tree or GPU. The main thread reads results only after task completion.
Mesh creation and uploads are capped at sixteen per frame with a 1.5 ms soft budget
(a single upload cannot be interrupted).

`terrain_partition.gd` selects balanced world-aligned variable-size leaves.
Keys are (x,z,level); each parent doubles width and replaces four children.
Root and leaf hysteresis reduce boundary churn. Adjacent leaves differ by at most
one level. Default 256 m base tiles and level-six roots cover a 49,152 m square.
Latest measurements and limitations: `REGIONAL_SURFACE_REPORT.md`.

Replacements are staged hidden. The entire desired cut swaps atomically only
when ready, retaining the previous complete cut during generation. This prevents
parent/child overlap but delays startup and can delay nearby refinement behind
the rest of the cut. It is not independent per-subtree commit scheduling.
Use request_teleport for camera movement synchronized with new coverage.
Unbounded direct camera teleports cannot be guaranteed safe.

Obsolete results are discarded before GPU upload; completed tasks are joined
before reading their results. All remaining tasks are joined before exit.
Mesh cache is bounded at 64, pooled nodes at 128, and worker-local exact sample
caches at 8,192. Per-level materials share the same texture arrays.

All levels use the same canonical terrain height. Shared default-grid samples
match, but skirts remain: there is no complete edge stitching or geomorphing.
Coarse parents cannot represent every narrow cliff or riverbank.

Distant chunks do not cast shadows. AmbientCG normal and secondary color sampling
fade out by 180 metres, retaining packed albedo/roughness and major material regions. Water is opaque to
avoid the large transparency pass and seabed overdraw.

Run `godot --path . --script tools/benchmark_hierarchy.gd -- run_label`.
It measures initial fill, movement at 1.5/7/1500/5000 m/s, queued teleports,
frame times, plan/swap maxima, memory and partition invariants.
benchmark_generation.gd and benchmark_streaming.gd delegate to this harness.
Historical fixed-grid JSON files retain their different coverage configuration.
