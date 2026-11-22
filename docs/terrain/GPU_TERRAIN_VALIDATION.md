# Terrain generation validation

Use **Godot 4.6.1 .NET** and the **.NET 8 SDK**. The ordinary Godot executable cannot run these C# checks. Build the project before running a check; the runner rejects a missing assembly or C# sources newer than the assembly.

```sh
dotnet build PredatorIsle.csproj
dotnet run --project tools/csharp-runner/PredatorIsle.Checks.csproj -- sampling terrain-performance rings gpu-pipeline collision
dotnet run --project tools/csharp-runner/PredatorIsle.Checks.csproj -- tropical coast network
dotnet run --project tools/csharp-runner/PredatorIsle.Checks.csproj -- gpu-sampler gpu-terrain gpu-queues lifecycle
dotnet run --project tools/csharp-runner/PredatorIsle.Checks.csproj -- authority startup-grid
```

The runner normally selects the bundled Godot 4.6.1 .NET executable under `.tools/` for the current platform. `GODOT_BIN` can select another installed executable. For example, in a Linux shell:

```sh
export GODOT_BIN=/absolute/path/to/Godot_v4.6.1-stable_mono_linux.x86_64
dotnet run --project tools/csharp-runner/PredatorIsle.Checks.csproj -- sampling
```

`gpu-sampler`, `gpu-terrain`, `gpu-queues`, and `lifecycle` require a working graphics display and use the project's Compatibility renderer. Do not add `--headless`: Godot's headless display uses the dummy renderer and cannot validate fragment-shader output or GPU readback. A virtual X server with Mesa software rendering can validate the shader and texture encoding, but its timings do not measure hardware GPU performance.

## Check scopes

| Mode | What it verifies |
| --- | --- |
| `sampling` | Terrain height/water reuse, payload retention, worker reconfiguration, combined cave probes, and deterministic sampling workloads. |
| `sampling-benchmark` | The same six numerical workloads without the new cache assertions, so the fixture can also run against the original implementation. |
| `terrain-performance` | Complete numerical terrain-product generation for three patches, including visual vertices, normals, features, refinement, and collision data. |
| `rings` | Ring ownership, edge stitching, publication, shared grids, sample caches, and queue scheduling. |
| `gpu-pipeline` | Numerical sample planning, exact cache lookups and bounds, source invalidation, visual/collision equality using CPU-sourced numerical fixtures, and headless fallback. This mode does not test shader execution. |
| `collision` | Physics payload equivalence, retained shape identity, activation/deactivation, cave-cut preservation, source invalidation, and release. |
| `tropical`, `coast`, `network` | Existing focused comparisons and cave-network behavior affected by sampling changes. |
| `gpu-sampler` | Actual rendered fragment-shader execution, RGBA8 readback/decoding, CPU/GPU numerical comparisons, and cancellation. |
| `gpu-terrain` | A real accepted GPU bake used by the production terrain builder, exact agreement between visual/collision vertices at the same coordinates, CPU-authority height tolerance, and a Jolt ray cast against the installed shape. |
| `gpu-queues` | Queue capacity, cancellation and shutdown without a draw, and disposal of a terrain stream whose worker is awaiting a GPU request. |

The `all` suite includes the focused sampling, GPU-pipeline, collision, and rendered GPU modes. `startup-reference` explicitly requests both CPU generation and CPU mesh rendering, so an automatic hardware-GPU choice cannot contaminate that reference run.

Every runner invocation manages only its own engine processes, retains logs in `.godot/csharp_checks/`, and writes semantic reports under `data/csharp_check_*_latest.json`. A fresh report and a successful process exit are both required. Runtime errors fail the run; a historical report cannot make a new run pass.

## Performance methodology

The original baseline is commit `50fa05b9304aae9490a23dade0f009c88ba10ae1`, with the existing `TerrainRingChecks` local-variable compilation error renamed so the project can build. New measurement fixtures are copied into that isolated baseline checkout without changing its generation code.

The sampling fixture uses seed `73921` and 4,096 fixed fractional coordinates for each of three presets: saved world settings, grass-only, and tropical-only. It measures height-only queries and paired height/water queries separately. Each case records elapsed time, managed allocations on the executing thread, canonical height evaluations, and a checksum of every returned double. A smaller allocation count is cumulative allocation avoided, not a reduction in the game's resident memory by the same amount.

The complete-product fixture uses the saved world settings, seed `73921`, 16 cells per patch axis, and levels 0, 2, and 4 near the launch location. Each measured patch starts with a freshly configured builder. A separate warm-up patch initializes engine and JIT code. Builder configuration and generation are timed separately. The fixture records stage timings, canonical evaluations, managed allocations, and SHA-256 hashes of the emitted surface and authoritative-ground arrays. Hashing and semantic assertions happen after the timed generation region.

Both baseline and candidate use the identical `TerrainBenchmarkResources` fixture to retain loaded and duplicated resource graphs throughout each workload. This setup is outside the timed generation region. Early exploratory runs that emitted native C# resource-handle errors were excluded; the final comparison consists of 12 clean engine processes, with no runtime errors and matching numerical outputs in every repetition.

These direct generation measurements exclude streaming queues, mesh upload, physics-shape installation, and frame rendering. They cannot establish a game-wide frame-rate improvement. GPU generation needs a separate end-to-end comparison that includes request preparation, render scheduling, shader compilation/warm-up, readback, decoding, and remaining CPU generation. `GetImage()` can wait for GPU completion; awaiting a rendered frame does not turn readback into an asynchronous transfer.

Compare multiple runs on the same machine, alternate baseline/candidate order, and report medians alongside output-equivalence checks. Avoid running shader compilation, other benchmarks, or full game sessions concurrently with a timing comparison. Preserve the machine, engine version, renderer, measured cases, and limitations with the result.

## Environment and acceptance limits

The development validation environment is Debian 13, an Intel Xeon Platinum 8573C host with nine processors visible to .NET, official Godot 4.6.1 .NET, and .NET SDK 8.0.428. Rendered checks use Compatibility/OpenGL 4.5 through Mesa 25.0.7 llvmpipe on a virtual X display. This verifies real shader compilation, rendering, and readback through Godot, but llvmpipe executes graphics work on the CPU. It does not measure the user's RTX 3060 or establish minimum-spec performance. The X-server launch wrapper means runner process-memory samples describe the wrapper rather than the engine child; those samples are excluded from the reported results.

The shipped default uses optimized CPU numerical generation and shared GPU render grids. Explicit GPU and automatic generation modes remain available. Hardware end-to-end bake performance has not been measured, so the numerical GPU mode is not enabled by default solely on the strength of software-renderer correctness checks.

## Measured CPU generation results — 2026-11-21

The compact machine-readable evidence is [`data/terrain_gpu_performance_20261121.json`](../../data/terrain_gpu_performance_20261121.json). Each value below is the median of three runs. Order alternates baseline/candidate, candidate/baseline, then baseline/candidate. Graphics stress and other benchmarks were paused during the comparison.

| Complete terrain product | Baseline | Optimized | Speedup | Baseline allocated bytes | Optimized allocated bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| Level 0, 16 m patch | 20.510 ms | 8.478 ms | 2.42× | 1,145,304 | 858,592 |
| Level 2, 144 m patch | 152.850 ms | 37.590 ms | 4.07× | 6,834,216 | 2,835,744 |
| Level 4, 1,296 m patch | 1,713.667 ms | 283.296 ms | 6.05× | 82,754,688 | 9,965,352 |

All surface and authoritative-ground hashes match the original implementation exactly across all repetitions. Level 4 allocates approximately 88.0% less managed memory during generation. Far patches have no authoritative collision payload; their equal empty-ground hashes are recorded explicitly and are not evidence of far-distance collision generation.

| 4,096-query sampling workload | Baseline | Optimized | Speedup | Allocation reduction |
| --- | ---: | ---: | ---: | ---: |
| Saved-world height | 480.203 ms | 359.443 ms | 1.34× | 73.6% |
| Saved-world height + water | 457.630 ms | 331.887 ms | 1.38× | 80.8% |
| Grass height | 189.411 ms | 120.284 ms | 1.57× | 93.8% |
| Grass height + water | 172.416 ms | 99.096 ms | 1.74× | 96.6% |
| Tropical height | 411.273 ms | 134.284 ms | 3.06× | 67.2% |
| Tropical height + water | 380.147 ms | 153.095 ms | 2.48× | 63.3% |

Every double-value checksum matches between baseline and candidate in every repetition. Paired saved-world and tropical queries reduce canonical height evaluations from 8,192 to 4,096. These are generation and sampling improvements, not a claim that the full game's frame rate rises by the same factors.

## Rendered heightmap and physics proof

The real `gpu-terrain` check accepted 357 samples from one fragment-shader bake and consumed them in the production terrain builder. Visual and collision vertices at the same coordinates were exactly equal. The maximum difference from an independently generated CPU reference was 0.0003357 m; a Jolt ray against the installed collision shape returned its expected height with zero measured error. The check passed 1,544 assertions.

On the final llvmpipe run, that request transferred 13,572 readback bytes. Synchronous readback took 1.738 ms, while complete request preparation and frame scheduling took 168.098 ms. Shader-cache state was uncontrolled. Earlier same-scope runs included several seconds of first-use compilation. Neither timing is a hardware-GPU performance result, and the shorter readback number must not be presented as the cost of the whole terrain generation request.

The final `gpu-sampler` check compared 3,504 positions and 28,032 scalars across three seeds and two parameter profiles, including dense grids and scattered positions within ±32,768 m. Maximum field-height error was 0.0054932 m and maximum material-control error was 0.0000260, within the unchanged 0.01 m and 0.001 test budgets. It also verified three queued requests sharing one readback with 78 unique raw positions, plus cancellation and fallback for unsupported input. These finite fixtures validate the tested range and profiles; they do not prove a bound for every possible terrain setting or coordinate.

The authority fixture also verified that a resident ground shape keeps its instance identity after 1.25 seconds of stable actor refresh, remains ray-collidable, and unloads after the last registered actor leaves. The collision suite covers activation/deactivation, source changes, retained cave cuts, and conversion from shared GPU rendering to CPU rendering with equivalent geometry.

| Focused check | Result | Assertions |
| --- | --- | ---: |
| Ring ownership, stitching, mixed CPU/GPU seams and ordering | Pass | 2,242,522 |
| Sampling, cache state and hydrology planning | Pass | 842 |
| Numerical GPU planning/cache/visual/collision pipeline | Pass | 1,925 |
| Collision retention and invalidation | Pass | 215 |
| Authority registration, retained shape and physical ground | Pass | 88 |
| GPU queues, cancellation and waiting-worker disposal | Pass | 13 |
| Actual GPU readback through terrain generation to Jolt | Pass | 1,544 |
| Actual shader numerical parity, batching and fallback | Pass | 30 |
| Existing tropical comparisons | Pass | 138,707 |
| Existing cave-network checks | Pass | 1,024 |

Authority assertion counts include readiness polling and can vary with scheduling. The compact evidence retains each check's UTC timestamp, the measured assemblies and relevant source hashes. The final build completed with zero warnings and zero errors. The complete migration suite and the full-world traversal check are not claimed to pass.

## Historical reference failures from the earlier baseline study

These paragraphs preserve findings reported by the earlier study using baseline `50fa05b9304aae9490a23dade0f009c88ba10ae1`. They are not results from the November 22 run below, which passes the `samplers` suite and does not rerun the separate `coast` mode.

The earlier report recorded a Linux failure in the quarry FIFO reference comparison at seed `-17`, cell `(840, -840)`: `311.4959699884967` versus `311.4959714153545`, against the suite's `1e-12` tolerance. It reported reproducing that failure before the optimization. The current passing sampler results supersede that historical status for the tested revision.

The same report recorded a strict `coast` reference discrepancy: `66.62799627279266` versus `66.62799627279405` (approximately `1.39e-12` apart), and reported the identical result in its isolated baseline and candidate. This historical attribution was not independently revalidated in the November 22 work.

## Historical full-world rendering limitation

Both full `startup-grid` attempts used the fixture's actual 1,920×1,080 viewport and the unchanged 170-second movement deadline. Both published all 63 saved-world terrain chunks and the cave bundle, then exceeded the traversal deadline on llvmpipe. The second, warmed run reached first visible terrain and LOD0 collision at 9.801 seconds, cave discovery at 33.280 seconds, and full coverage with the cave bundle at 51.768 seconds. It recorded valid nearby physical ground for the first three movement milestones before timing out on the return.

These runs had no terrain worker, shader, or collision errors. They nevertheless remain failed full traversal checks. The final screenshot and complete movement/return assertions were not reached. The deadline was not relaxed and the viewport was not reduced to obtain a pass. Focused stitching, physical ground, queued-worker disposal, and actual readback checks provide narrower evidence; they do not turn the timed-out full-world test into a passing one.

Hardware end-to-end generation performance, complete saved-world traversal within the deadline, minimum-spec frame rate, and cave entrance continuity remain separate acceptance requirements from these focused numerical checks.


## Cross-biome generation and renderer regression — November 21, 2026

The [successful native Compatibility CI run](https://github.com/Hi62384/predator-isle/actions/runs/44958026283)
compiled Godot 4.6.1 .NET and ran strict native checks for all sixteen surface
biome families in separate engine processes: grass, forest, savanna, swamp,
jungle, mountain, tropical, badlands, quarry, wise mountains, volcanic,
spore forest, radiation wasteland, crystal wastes, insect colony, and alien
infected. Every fixture compared the full GPU grid displacement payload,
normals, UVs, four categorical material-control banks and authoritative
one-metre physics positions. All sixteen passed. The cave-biome region,
material, shader-source composition, feature and renderer checks passed (the
four registered cave definitions are default, frozen, crystal and magma).

The same run passed the exact GDScript/C# protected-shore cave geometry
comparison and deterministic cave network/discovery checks. The beach
reference passed 54,912 strict assertions after switching the native C#
wind-vector helper to Godot's Vector2.FromAngle. Compatibility graphics tests
also passed actual grassland shader readback, vertex-baking differential tests,
cancellation, and GPU-height-to-Jolt physics integration.

Subsequent common-path optimizations reuse per-cell 3D cave lattice buffers
through System.Buffers.ArrayPool and remove redundant Godot Dictionary/Variant
lookups during mixed-biome region ownership. Those changes are independently
compile-checked; their native revalidation should be reviewed in the matching
latest GitHub Actions run before attributing any performance gain to them.

### What these results do **not** prove

- All-biome GPU grid rendering does not imply every *numerical height generator*
  has been ported into a GPU shader. Grassland is the only validated numerical
  GPU bake; other terrain families still use CPU evaluation and then upload
  canonical visual products for GPU displacement and material rendering.
- Cave materials and procedural visual effects run in GPU shaders, but
  arbitrary tunnel/chamber topology, protected entrance cuts, portal safety,
  and authoritative collision remain CPU/physics operations; Compatibility
  does not support arbitrary geometry-producing compute shaders.
- A native test pass is not evidence of near-optimal framerate, world loading,
  GPU utilization, or low memory use. Comparison requires an RTX 3060, an
  integrated GPU, and low-end compatibility-class hardware with cold/warm
  streaming paths, caves, edits and full-world traversal.
- Mobile Vulkan's large software-renderer sampling fixture has not completed
  within its first-use compilation timeout. Its focused real shader-to-collision
  check passed; the more complete Vulkan hardware matrix remains outstanding.
- An earlier 1080p full-world movement/return fixture timed out under Mesa
  llvmpipe. Focused coverage and collision checks cannot replace that test.

These acceptance limits are intentionally preserved rather than weakened to
claim that optimization is complete.

### Per-biome canonical generation profiling

Every isolated 16-biome GPU visual payload verification now records its cold, one-patch canonical generation time, thread-local managed allocations, canonical terrain evaluation count and vertex count in the existing native-test evidence JSON. The measurements cover CPU heightfields, feature/structure products and collision assembly, not GPU shader runtime, frame rate, or GPU readback. This provides comparable per-biome hotspot evidence on one runner without changing generation quality or benchmark acceptance thresholds. The legacy non-ring water path also skips allocating mesh arrays for provably dry terrain and hoists beach/payload settings out of its per-vertex loop.

## All-biome GPU and native regression — November 22, 2026

The compact evidence is
[`data/terrain_gpu_optimization_20261122.json`](../../data/terrain_gpu_optimization_20261122.json).
The starting revision is `9730ca3a76543f033b4e801da19dd02fc800a50a`.
Validation uses Godot 4.6.1 .NET, .NET 8, and Mesa llvmpipe software graphics.
An accepted result requires a fresh passing semantic report, successful process
exit, and no engine errors. Partial assertion totals from failed runs do not
count as passes.
Checks were run incrementally, with targeted subsequent regressions after
later changes. The evidence preserves each accepted run's source hashes and
the final changed-source hashes; it does not represent one monolithic run of
every mode from the final revision.
The completed record contains 70 accepted mode/renderer combinations and
4,132,418 assertions, with no unresolved later failure for an accepted pair.

### Native geometry, ownership, water, and cache checks

| Check | Verified result |
| --- | --- |
| Sixteen isolated `gpu-biome-*` modes | All passed; 125,051 assertions across canonical products, compact grid bytes, controls, and collision. |
| `rings` | 2,256,308 assertions, including constant ownership, dense extension-water slots for every nonempty family mask, inserted edge vertices, and pure badlands water. |
| `sampling` | 31,737 assertions; independent height-filter reference has zero maximum double difference and the same 88,928 synthetic neighbor queries. |
| `terrain-performance` | 1,017 assertions; final level 0/2/4 surface and authoritative-ground SHA-256 hashes equal the starting revision. |
| `gpu-pipeline` | 4,424 assertions for plans, shared samples, products, source changes, and CPU fallback. |
| `field`, `network`, `discovery` | 100,983, 1,024, and 125 assertions. |
| `samplers`, `tropical`, `beach` | 1,358,580, 138,707, and 54,912 assertions. |
| `quarry`, `placement`, `tissue`, `collision` | 3,856, 160, 20,912, and 215 assertions. |
| `cave-biomes` | 425 assertions for registered cave regions, materials, features, renderer bindings, and the preserved frozen/crystal/magma surface references. |
| `cave-payload`, `worker` | 1,825 and 22,908 assertions; exact expanded compact-atlas bytes, preserved typed containers, source/cut adapters, and complete portal geometry/collision. |

The complete-product comparison verifies equivalence rather than CPU speed:
graphics compilation and other tests were active during some measurements.
Final managed allocations are 912,888, 2,890,480, and 10,022,664 bytes for
levels 0, 2, and 4. Those are unchanged at level 0 and 72 bytes higher at each
distant level, from the filter's delegate/context fields. Water-context
invalidation retains the original small per-entry cache key.

### Rendered grid and numerical GPU checks

`gpu-extension` passes 427 assertions on Compatibility, Forward+, and Mobile.
Its 48 grid cases compare constant/varying ownership, sparse/mixed control
banks, and UV/surface products against independently reconstructed legacy
pages. Maximum RGBA8 channel difference is zero on all three renderers.
Extension-atlas and curved-trail comparisons remain in the same mode.

Compatibility additionally passes `gpu-queues` (14 assertions), `gpu-vertex`
(7), `gpu-sampler` (32), and `gpu-terrain` (1,544). The sampler checks 3,504
points and 28,032 scalar results across three seeds and two profiles. Maximum
value error is 0.005493164 metres, within the unchanged 0.01-metre budget;
maximum material-control error is 0.0000259876, within 0.001. Three batched
requests share one readback. The vertex fixture has identical vertex/fragment
bake results and 0.000320435-metre maximum CPU height error. The accepted GPU
terrain bake retains matching visual/collision vertices and passes the Jolt
ray-cast integration check.

An exploratory sampler run completed its six numerical cases but then failed
in Godot's native C# resource finalizer. It is excluded. The sampler and
pipeline fixtures now retain loaded/default and per-case resource graphs
until their builders and asynchronous requests finish. The strict rerun exits
successfully without engine errors; the production GPU sampler was unchanged.

### Complete material and cave shader results

The complete all-biome material mode passes on each renderer. Every row
includes 46,080 projection-helper pixels and 165,888 full production shader
pixels across albedo, geometric normals, and mapped normals. All sixteen
owners plus coast and beach are drawn under three camera/model scenarios.

| Renderer | Assertions | Maximum helper difference | Maximum full-program difference |
| --- | ---: | ---: | ---: |
| Compatibility | 1,140 | 0 RGBA8 levels | 0 RGBA8 levels |
| Forward+ | 1,140 | 0 RGBA8 levels | 0 RGBA8 levels |
| Mobile | 1,140 | 0 RGBA8 levels | 0 RGBA8 levels |

The full Compatibility reference restores the original 23-varying interface.
The original interface exceeds the tested Vulkan limit, so Forward+ and
Mobile independently restore the old normal computation and full-precision
coast interpolation within a 17-location reference. The production interface
uses 16 locations. These measured fixture results do not establish universal
bit-identical interpolation: Mobile built-in COLOR/NORMAL transport can use
half precision, and world-normal reconstruction includes rotation roundoff.

The cave matrix contains 27 successful processes: the independent compact
fetch check and eight complete entrance scenes on each renderer.

| Renderer | Fetch/adapter assertions | Full scene cases | Total cave GPU assertions |
| --- | ---: | ---: | ---: |
| Compatibility | 885 | 8 | 989 |
| Forward+ | 885 | 8 | 981 |
| Mobile | 885 | 8 | 981 |

All 612 compact/full fetch cases have zero RGBA8 difference and collectively
cover every one of the 68 control lanes. All 24 full scenes draw varied,
visible material and respond to the no-cave-influence negative control.
The eight Compatibility scene comparisons also have zero difference against
the restored original varying layout. Vulkan scenes verify the packed
production programs within the available varying limit; they do not claim
an independent original-layout image comparison.

### Focused modes and CI coverage

- `gpu-materials` executes actual projection helpers with endpoint/interior
  blends, normals enabled/disabled, varying synthetic art, and a deliberate
  UV-offset negative control. It also renders the complete production spatial
  shader for all sixteen owners, coast, and beach.
- `cave-payload` checks sparse atlas reconstruction, all 68 control lanes,
  signed zero and special float bits, unchanged group budgets, native
  selections, source adapters, and exact geometry/collision equivalence.
- `gpu-caves` executes production cave fetches for 204 mask/texel/channel cases.
- `gpu-cave-scene-0` through `gpu-cave-scene-7` each draw one complete
  ordinary/hive spatial entrance shader. Cases 0/1 are default ordinary,
  2/3 default hive, 4/5 frozen/crystal/magma ordinary, and 6/7 the same triple
  blend on hive entrances. Each pair uses standard then shared projection.
  Every case retains its own 180-second/5-GiB limit, visible-output checks,
  and no-cave-influence negative control. Compatibility compares the packed
  shader against an independently restored original varying layout. Vulkan
  repeats the production program to check stable rendering, compilation,
  visibility, and cave influence; the independent `gpu-caves` payload test
  separately compares all 68 control lanes on each renderer.

Full shader references and candidates render sequentially with two llvmpipe
threads, releasing the prior program before the next. Vulkan runs additionally
bound Godot's compilation pool to two workers. Small CPU image buffers
retain the reference pixels. Animation time is frozen during comparison and
restored afterward, so beach swash and cave animation cannot create false
differences between images. These fixture changes retain every output
assertion and the one-RGBA8-level tolerance. Combined full-scene attempts that
hit resource/deadline gates are excluded. The scene split bounds each shader
case separately rather than treating a partial multi-case run as a pass.

Existing Compatibility GPU checks retain their 2-GiB memory gate. The added
complete-program reference fixtures use a separate 5-GiB compiler allowance;
the default runner bound and gameplay acceptance checks are unchanged.
`LP_NUM_THREADS=2` bounds Mesa independently from Godot's worker pool. CI
creates a temporary `override.cfg` with `threading/worker_pool/max_threads=2`
before the complete shader checks and removes it afterward. Production project
settings are unchanged, and semantic evidence records both configured limits.

The native workflow explicitly runs the new CPU and Compatibility modes;
both Vulkan branches explicitly run the rendered material and cave checks.
CI retains every invocation's strict runner receipt alongside semantic reports
and engine logs, so a later invocation cannot overwrite earlier exit/memory
evidence in the single `csharp_runner_latest.json` file.
Software graphics validate behavior and compilation. Physical-device GPU
time, full-world streaming performance, and FPS remain unmeasured here.
The complete legacy suite, including the separate `general` and `coast`
modes, and uninterrupted full-world traversal were not revalidated in this
focused run. The unchanged general CI invocation remains a separate gate.
Numerical GPU height generation remains limited to the existing validated
grassland path; other surface generators and cave topology retain their
canonical CPU implementations.
