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

## Existing reference failures

The original `samplers` suite has a reproducible Linux failure in the quarry FIFO reference comparison at seed `-17`, cell `(840, -840)`: `311.4959699884967` versus `311.4959714153545`. The suite requires a difference no greater than `1e-12`. That failure was reproduced before the optimization; the tolerance is unchanged. Do not describe the entire migration suite as passing while this discrepancy remains.

The original `coast` suite also fails its strict reference comparison on this host: `66.62799627279266` versus `66.62799627279405` (approximately `1.39e-12` apart). The identical failure occurs in the isolated baseline and the candidate. This pre-existing reference discrepancy is recorded separately from the exact baseline/candidate surface and collision hashes.

## Full-world rendering limitation

Both full `startup-grid` attempts used the fixture's actual 1,920×1,080 viewport and the unchanged 170-second movement deadline. Both published all 63 saved-world terrain chunks and the cave bundle, then exceeded the traversal deadline on llvmpipe. The second, warmed run reached first visible terrain and LOD0 collision at 9.801 seconds, cave discovery at 33.280 seconds, and full coverage with the cave bundle at 51.768 seconds. It recorded valid nearby physical ground for the first three movement milestones before timing out on the return.

These runs had no terrain worker, shader, or collision errors. They nevertheless remain failed full traversal checks. The final screenshot and complete movement/return assertions were not reached. The deadline was not relaxed and the viewport was not reduced to obtain a pass. Focused stitching, physical ground, queued-worker disposal, and actual readback checks provide narrower evidence; they do not turn the timed-out full-world test into a passing one.

Hardware end-to-end generation performance, complete saved-world traversal within the deadline, minimum-spec frame rate, and cave entrance continuity remain separate acceptance requirements from these focused numerical checks.
