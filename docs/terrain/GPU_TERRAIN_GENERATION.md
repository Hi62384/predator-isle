# GPU-assisted terrain generation

The nested-ring renderer now has a Compatibility-compatible GPU generation path,
a shared grid rendering path, and retained nearby collision shapes. The existing
CPU generator remains available for authority, unsupported requests, and work
that is cheaper than a GPU round trip.

## What runs where

| Work | Implementation |
| --- | --- |
| Seed, world settings, island/biome ownership, province and plateau placement, river/lake descriptors, streaming and publication | CPU |
| Grassland raw landforms, ridges, erosion, detail noise, rivers and lakes | Fragment shader when the GPU generation path accepts the request |
| Deduplicating sample locations and interpolating the existing coarse field | CPU, using the numerical GPU readback |
| Other biome generators, coastline planning and cave network planning | CPU; their existing terrain features remain supported |
| Surface grid vertex/index buffers | Shared reusable topology meshes |
| Rendered grid vertex displacement and material attributes | Vertex shader reads the per-chunk numerical texture |
| Visual LOD filtering, seams, feature/structure assembly and cave mesh extraction | Existing CPU pipeline, consuming accelerated field samples where available |
| Nearby ground and cave collision | CPU physics shapes from the same numerical terrain products |
| Headless/dedicated-server generation | CPU |

This is an integrated GPU backend for the grassland field, not a port of every
biome or arbitrary cave topology to shaders. A normal Compatibility vertex shader
cannot append an arbitrary number of new mesh triangles. The shared grid topology
is created once and reused, while cave and feature topology retains its existing
CPU implementation.

## Generation and readback

`TerrainGpuSamplePlan` forms a bounded, deduplicated union of the positions a
chunk will actually query: visual vertices, derivative probes, distant filter
support, refinement probes, and the nearby one-metre physics grid. It includes
the inserted third-boundary knots used by the ternary ring layout. It does not
allocate a uniformly oversampled rectangle merely to include these knots.

The GPU service further deduplicates the coarse grassland nodes and exact relief
points needed by those queries. Shared river columns and lake sites are planned
once on the CPU and supplied as numerical lookup textures. This preserves the
double-precision placement calculations while moving terrain shaping to the GPU.
Geographic province controls and the initial plateau distance are also planned
on the CPU: very small noise differences at this scale can otherwise become
centimetres of error on steep cliffs.
Fixed affine noise-coordinate transforms also use the canonical CPU rounding
before their float inputs are sent to the shader.
Requests with the same immutable configuration can share a render target and
readback. The heavy raw field is evaluated in a
`canvas_item` shader in a `SubViewport`, with `UpdateMode.Once`; it is not
recalculated as an expensive terrain-generation shader on every display frame.

Each scalar is stored as its four IEEE-754 bytes across an RGBA8 texel. Blending,
HDR conversion, filtering, mipmaps and multisampling are excluded from this data
pass. A scalar height is therefore not restricted to 256 elevation levels.
The readback decoder checks the image layout, byte count and finite values.

The viewport is read after it has drawn, through `GetImage()`. This operation
can synchronize with the GPU; awaiting `FramePostDraw` does not make the readback
asynchronous. The service bounds its queue, in-flight work, sample counts and
readbacks per frame. Requests have cancellation and a finite timeout. Scene
shutdown resolves outstanding requests before the stream waits for its workers.

The returned values enter a worker-owned numerical cache. Existing terrain
assembly and physics generation read those same samples. No per-pixel
`GetPixel()` loop, per-frame terrain readback, or second procedural grassland
calculation is needed for a cached query. The small coarse-field interpolation
stays on the CPU and uses the same operations as the canonical implementation.

## Accuracy and fallback

GPU floating-point evaluation is not assumed to be identical to CPU double
arithmetic. The rendered differential tests compare the shader to the actual
Godot 4.6.1 CPU generator. The service has an explicit coordinate limit;
`TerrainGpuSampler.MaximumCoordinate` is the authoritative value. That limit
applies to grassland generator coordinates after terrain shape scaling.

Each accepted runtime batch also checks representative points against the CPU
reference before installing any data. The final grassland height contribution
must agree within 0.005 metres after the height multiplier; material controls
have a separate tolerance. These checks detect format, driver and precision
failures. They supplement the broader differential fixtures, and do not prove
an error bound at every possible world coordinate and setting.

Unsupported noise settings, coordinates outside the supported range, coordinates
that cannot be represented without changing the requested sample, invalid data,
timed-out requests and rejected comparisons retain CPU generation. No rounding
to a nearby cached position is used for arbitrary authority or cave queries.
World edits and reconfiguration invalidate the affected cached products through
the existing source-revision mechanism.

Adjacent chunks can independently use a GPU bake or its CPU fallback. Before
coarse-to-fine LOD stitching, shared same-level visual boundary vertices take
the height and normal of a deterministic neighboring owner. This closes small
numerical gaps and keeps corners with two coarse neighbors consistent. The
normalized products are cached by their source revisions, so an unchanged cut
does not create new meshes or uploads. Canonical physics grids are not moved by
visual LOD stitching.

## Collision lifetime and caves

Nearby ground still uses the fixed one-metre physics grid, independent of visual
quality. The generator keeps the existing triangle topology and cave-opening
clipping; it does not replace cave-cut terrain with a heightmap shape that would
close the holes. The visual and physics grids share samples wherever their
coordinates coincide.

An installed ground or cavity shape is retained when the same terrain mesh is
temporarily inactive. Its `CollisionShape3D` is disabled as needed instead of
destroying and rebuilding its shape. The retained object can also be an already
clipped cave shape, including a valid empty cut. Mesh replacement, changed span
or resolution, chunk release and pooled-node reuse invalidate the retained
source. Moving between indexed structure cells still updates the needed
structure subset.

Authority interest refreshes also retain an already clipped ground shape while
its terrain source and cave transaction state are unchanged. A new cave commit
invalidates that check and rebuilds the cut when required.

When cave work converts a shared GPU grid to its equivalent CPU surface, an
explicit payload check transfers the collision source identity. This preserves
the installed cave cut through that representation change. Other mesh
replacements cannot reuse the old collision merely because their tile keys match.

The existing nearby/authority residency system decides where physics is needed.
This change does not add a global scan of every physics body in the scene or
automatically expand client render rings around unregistered distant entities.

## Settings and comparison runs

`config/world/terrain_rings.tres` enables shared GPU render grids and selects
the optimized CPU numerical generator by default. GPU numerical baking is
available explicitly while hardware performance is being established. The
settings resource exposes:

| `generation_backend` | Behavior |
| --- | --- |
| `0` — CPU | Existing numerical CPU generator with the new CPU optimizations |
| `1` — GPU assisted | Requests GPU grassland generation when a rendered device is available; unsupported work falls back |
| `2` — Automatic | Uses GPU-assisted generation on hardware renderers for sufficiently large plans; keeps software renderers and cheap nearby plans on CPU |

Automatic selection avoids a render/readback delay for nearby grids whose
coarse field is already cheap to evaluate. It skips plans below 1,024 new sample
locations or with a visual footprint below four metres. These are conservative
selection rules, not a claim that every supported GPU is faster for every world.
Dedicated-server authority and headless sessions always use CPU generation.
The software-rendered numerical checks cannot establish RTX 3060 or integrated
GPU speed. Use the full generation timings below before choosing GPU or
Automatic as a saved project default; readback time alone omits much of its cost.

To compare backends using a Godot 4.6.1 .NET executable, run from the project root
and pass the project arguments after `--`:

```text
Godot --path . -- terrain-generation=cpu terrain-render=cpu
Godot --path . -- terrain-generation=cpu terrain-render=grid
Godot --path . -- terrain-generation=gpu terrain-render=grid
Godot --path . -- terrain-generation=auto terrain-render=grid
```

The first pair isolates shared grid rendering; the next comparison isolates GPU
generation. Use the same seed, world settings, profile, camera path and warmed
shader cache. Restart after changing generation settings.

`get_ring_progress()` reports generated samples, numerical-cache hits, rejected
batches, readback count/bytes/time, and generation-stage timing. CPU worker
allocation counters cover the synchronous numerical build; GPU planning and
waiting are reported separately because thread-local allocation counters cannot
be carried across an `await`.

## CPU performance work

The CPU path has also been improved, including when GPU generation is disabled:

- Managed numerical caches replace repeated native dictionary and Variant
  traffic in grassland and island queries, while diagnostic cache projections
  preserve their supported interfaces.
- Numeric grassland, tropical and badlands settings are captured once instead
  of allocating keys or crossing the resource interface in every inner loop.
- Coastline queries call their native C# host directly, reuse shared shore
  calculations, and build polynomial coefficients with scratch storage.
- Height-only sampling avoids allocating unused controls. Paired cave entrance
  height/water queries reuse the same evaluated terrain sample.
- The stream retains bounded cancellation-aware scheduling, and the earlier
  scheduler check's C# variable-shadowing compile error is fixed.

Measured results, exact-output comparisons, commands, and the limits of the test
hardware are documented in [GPU_TERRAIN_VALIDATION.md](GPU_TERRAIN_VALIDATION.md)
and [the performance evidence](../../data/terrain_gpu_performance_20261121.json).

## Additional GPU workload reuse (November 21, 2026)

The Compatibility GPU generator now caches the **raw, unblended grassland samples** across concurrent/adjacent chunk requests under a bounded 32,768-sample FIFO. It checks the complete seed/noise/grassland parameter snapshot before lookup, and invalidates entries when a different source takes over. When only some samples are absent, canonical hydrology planning, input-texture creation, shader execution and readback run only for the misses; hits are reassembled into the original request order before CPU interpolation. Other biome generators and the CPU canonical path remain unchanged.

GPU generation render targets and materials are also reused, rather than allocating a new SubViewport and shader material for every job. The pool holds at most four idle targets. Per-request input textures remain alive through their draw and are released when replaced or when the service shuts down. Three consecutive GPU/CPU parity rejections disable further GPU submissions on that renderer and preserve CPU generation; both backends retain the same numerical acceptance gate.

Telemetry now includes `gpu_raw_cache_hits`, `gpu_raw_cache_entries`, `gpu_render_targets_created`, `gpu_render_targets_reused`, and `gpu_parity_rejections`. These changes reduce redundant GPU work, scheduling and resource creation. They are **not** a full GPU port of the remaining biome and cave topology generators, and they need fresh Godot shader/physics and hardware timings to quantify speedups on Compatibility, Mobile and Forward+.

Cached grassland raw values are isolated by the **full 64-bit world seed** as well as shader/noise settings. The shaders still use their validated 32-bit numerical seed inputs, but the CPU can use high seed bits for hydrology, so those worlds must never share cache entries. On a reused render target with matching input dimensions, the numerical RGBA32F position texture is updated in place rather than created again.

## Experimental vertex-stage GPU terrain baking

The `terrain-gpu-bake=vertex` command-line switch or `gpu_vertex_bake` setting selects a new **opt-in** shader for larger grassland batches. Reusable two-dimensional quad meshes evaluate the raw grassland field at four vertices per sample and write its nine 32-bit scalars as a 1×9-pixel strip. The original fragment shader evaluates the raw field nine times per sample. Both modes use the same verified numerical inputs and lossless RGBA8 float serialization, but differ in pixel layout. A separate readback decoder handles the vertex layout.

The new path is disabled by default pending renderer compilation, CPU/GPU parity and hardware performance comparisons. Small batches still use the old fragment shader; unsupported devices retain fragment generation or the canonical CPU fallback. The existing GPU sample cache, bounded queues and timeout protections apply to both paths. `get_ring_progress()` now reports `gpu_vertex_bake_flights`. This is a candidate optimization, **not** a measured 2.25× end-to-end speedup or a port of the other biomes and caves.

The GPU service also updates same-size river and lake descriptor textures in place when reusing a render target, avoiding unnecessary GPU resource creation during movement. Readback and texture updates still consume bandwidth; this is resource reuse, not proof of an overall speedup. The diagnostic `gpu_plan_textures_reused` tracks these operations.

### Software Vulkan safety guard

Mesa's software Vulkan driver (llvmpipe/lavapipe) passed the existing fragment-bake and GPU-height-to-physics checks on Forward+, but the experimental vertex-bake fixture exhausted its bounded 5-GiB graphics-process allowance before producing a shader verdict. To avoid risking a graphics process OOM, the vertex-bake optimization is automatically **disabled on known software Vulkan adapters** in Forward+ and Mobile; the existing fragment baker remains available. The `gpu-vertex` native check reports an explicit software-Vulkan skip/fallback on those adapters, not a passing vertex numerical comparison. This restriction does not apply to Compatibility, where the vertex shader has passed native numerical parity, or to hardware Vulkan (which remains opt-in and unbenchmarked).

### Vulkan validation scope (software renderer)

On the November 21 native Mesa Vulkan runs, **Forward+** passed the full 3,504-point fragment numerical sampler, the software-Vulkan vertex safe-fallback check, and the actual GPU heightmap-to-Jolt collision check. **Mobile** passed the 357-sample GPU heightmap-to-collision and safe-fallback checks, but the larger sampler fixture timed out on the CPU-emulated Vulkan driver's first shader compilation (the renderer returned no numerical verdict within the fixture's 120-second request budget). The comprehensive Mobile sampler is therefore **not verified**. The Mobile CI step intentionally runs the already-passing focused real-GPU-execution and physics checks and reports a notice about the unverified full sampler; it does not silently assert full parity. Real hardware Vulkan, integrated graphics and the RTX 3060 still require separate performance and equivalence testing.

## Shared cave extraction optimization

The canonical marching-tetrahedra cave mesher now caches **only** expensive protected-shore edge refinements, using a bounded per-chunk edge cache. It reads each immutable protected-shore descriptor once instead of repeatedly traversing Godot Dictionaries for every triangle. Repeated edges produce the same welded vertex, avoiding duplicate 12-step SDF bisections and retaining the original geometry, face winding and collision topology. This is used by ordinary, frozen, crystal, magma and other cave biome meshes, including portal openings. The `field` migration check includes a reference-mesh byte-equivalence test against the original GDScript and a repeated-build cache regression. Other cave geometric topology is still generated on the CPU; its GPU materials and overlays were already rendered by shaders.

## End-to-end material and biome coverage fixture

The native check `gpu-all-biomes` builds complete LOD0 terrain products with each of the 16 canonical surface biome families selected, including all eight extension families. It validates GPU grid height and vertex-normal encoding against the CPU surface and authoritative collision grid, every interpolated UV, all four packed categorical control banks, and shared immutable grid topology. The separate `cave-biomes` check exercises cave-biome region selection, shader composition, feature materials and surface rendering adapters. These checks validate all-biome visual payload correctness, **not** the claim that every biome's numerical generator already runs as a GPU shader: only grassland has a numerical shader port. Cave topology remains CPU-authoritative and the GPU handles its rendered material effects.

The `gpu-biome-<biome>` native modes test the 16 surface biome GPU visual/collision payloads in isolated engine processes, with resource graphs retained through generation. This avoids repeated Godot C# object finalization during all-biome fixtures. The historical `gpu-all-biomes` aggregate remains available but is no longer the CI gate. These are GPU rendering payload parity checks, not complete numerical GPU shader implementations for every biome.

## Cross-biome feature sampling optimizations

Canonical terrain surface capture now preserves the published region weights for pure specialized land biomes instead of re-running biome region ownership. Ocean short-circuit paths retain their original explicit lookup. Special-liquid pools cache shared grid-corner heights (up to 25×25 unique positions for a 24×24 quad pool) instead of evaluating the same canonical height up to four times. Terrain features, caves, waterfalls, and liquid clipping call native C# height, river, water and biome planning methods directly when the builder is native. Legacy GDScript worker compatibility is retained for reference fixtures. These improvements affect all participating surface and cave feature families while keeping canonical geometry and physics on their existing accuracy paths.

### Avoid unused numerical shader work

GPU input planning now honors `selective_geometry_refinement`, avoiding costly shader baking and readback of middle-LOD shape-refinement probes when the actual mesh builder has disabled that pass. The reference GPU-planning check verifies that the disabled plan is a strict subset and retains all required height/normal/physics sample positions. A synthetic retained-liquid test compares complete triangle payloads to the uncached algorithm and requires fewer height function evaluations. Native CI additionally runs the broader runtime/scene migration and records direct terrain generation/allocation benchmarks. These checks do not establish hardware GPU framerates.

## Deformable organism GPU/CPU split

The full-project audit also identified unnecessary main-thread physics work in the `BlobOrganism` runtime. Its body and appendage *visual deformation was already shader-driven on the GPU*. The C# step now computes expensive body-contact position arrays only for contractile/peristaltic/undulating/pulse locomotion, which are the only modes that consume them; leg, vine, roll, drag and other modes no longer allocate and map unused contact samples. Optional contact-debug drawing reuses one `ImmediateMesh` and one `StandardMaterial3D` instead of allocating fresh GPU resources each physics frame. Native blob smoke tests check GPU debug resource identity across ticks. GPU physics readback is intentionally not introduced for authoritative gameplay.

### Exact C# and GDScript angular parity for extension biomes

Quarry, volcanic, spore forest, and radiation terrain geometry use Godot's canonical Vector2 angle and rotation APIs to reproduce the source GDScript operations, including at large world coordinates. Native CI now runs the full eight-family numerical extension sampler comparison first, before spending time on the longer world/scene checks. The single-ULP height mismatches this addresses are CPU numerical correctness issues; GPU numerical baking for these families is a separate, still-unported optimization.

## Cave and liquid generation hot paths (November 22, 2026)

All cave biome fields now evict the oldest cached surface-height column when the
8,192-column memo fills, rather than invalidating every cached column. This
keeps repeated height requests from 3D lattice and normal probes warm during a
large cave build. Clearing or rebinding the source still resets the memo.

Finite pool and waterfall clipping now use stack-based temporary triangle
storage, preserving the original 12-step height refinement and triangle order.
The 25×25 shared-corner pool mesh uses dense indexing instead of a dictionary.
The native regression tests compare generated pool vertices with the uncached
reference, compare clipping against the former algorithm across crossing cases,
and check cave height-memo rollover and invalidation.

These changes avoid CPU allocations and repeated numerical work across cave and
special-liquid biome features. They do **not** move cave topology or the other
15 surface biome numerical generators to the GPU. No hardware FPS or latency
improvement is claimed without a controlled device-specific measurement.

### Additional cave collision and liquid fast paths

The surface entrance collision cutter now keeps untouched triangles in-place
without first constructing temporary polygon lists; for boundary-spanning
triangles it allocates clipping polygons only when an actual 64m cut column is
encountered. Degenerate triangle handling, clipping order, and rejected-bounds
behavior remain unchanged. The independent GDScript comparison covers 600
randomized cave cuts and targeted no-hit, boundary and degenerate inputs.

Special-liquid pool meshing now sends clipped triangle vertices straight from
stack storage to the mesh emitter instead of materializing a per-triangle array.
The original public array-returning API remains available for legacy users and
is separately compared with the new allocation-free path in regression tests.
These are all-biome CPU/graphics-preparation optimizations; numerical shader
coverage and device-specific performance limitations remain as stated above.

## Extension-atlas and cave GPU shading pass (November 22, 2026)

Eight extension biome ownership weights are now packed into two additional
RGBA8 atlas strips. The native C# terrain renderer uses two filtered texture
fetches to recover all eight weights, rather than up to eight independent
fetches. Each original family control strip remains unchanged, and the badlands
palette moves to strip 10 when extensions are present (still strip 0 when alone).
The shader detects the 10/11-strip format and retains the original 8/9-strip
legacy GDScript lookup for compatibility with reference fixtures.

The common extension material shader avoids ground/rock triplanar fetches when
that material has exactly zero blend contribution. Frozen cave shaders avoid
snow-map reads for frost-free fragments; magma cave shaders avoid pore-noise
octaves when the rough-flow blend is zero. These shader changes affect all
eight extension surfaces and the applicable frozen/magma cave variants; cave
SDF topology, authoritative physics, and non-grassland numerical terrain
sampling remain CPU-based. Packed weight strips increase atlas size by 8 RGBA8
bytes per atlas position in return for fewer fragment samples. Device-specific
speedup, shader-clock time, and visual equivalence are not inferred from the
static change; hardware profiling and rendered regression tests remain necessary.

### Rendered parity fixture for packed extension weights

The native `gpu-extension` check uses the production atlas lookup include in a
real GPU canvas shader, comparing 8-strip legacy against 10-strip packed and
9-strip legacy/badlands against 11-strip packed/badlands layouts across filtered
atlas sample locations. It tests both sets of four biome weights and rejects
blank readbacks. Compatibility and both software-Vulkan renderer jobs exercise
this mode. Passing verifies numerical atlas decoding on those drivers, not the
full game's FPS or complete 3D shader parity.

## Immutable GPU grid page reuse (November 22, 2026)

The shared all-biome GPU grid uploader now caches immutable numerical RGBA32F
pages by **source product revision and page object identity**. Republished
unchanged patches reuse their uploaded image instead of creating a new texture,
reducing transfers when streaming returns to recently generated terrain.
Changes to geometry, materials, seams, or cave source revisions produce new
pages; page cache misses always upload the new data. The bounded cache retains
at most 128 pages or 16 MiB of page data, and releases its retained native
references on eviction and scene shutdown. Active materials retain their own
references, including during cave-cut transitions. `get_ring_progress()` now
reports cache hit count, page count and cached bytes; the native ring regression
checks shared resource identity, revision invalidation and shutdown cleanup.
This is resource reuse, not additional procedural GPU generation, and device-
specific streaming gains still require profiling.
