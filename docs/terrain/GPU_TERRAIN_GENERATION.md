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

## Correct specialized biome shader variants after atlas extraction

The compact atlas helper moved one of the terrain shader's two original
inline extension loops into a shared include. The shader-variant compiler had
an old two-loop-only guard and silently returned the unoptimized full shader
for valid packed-atlas sources. Both the native C# variant compiler and the
legacy GDScript reference now accept a one-loop packed shader *only* when the
expected weight-helper call is present, and retain two-loop compatibility for
older sources. Unexpected layouts still fail open without rewriting shader
source. The general migration test asserts actual loop-range pruning for
one-owner and no-owner masks instead of accepting identical unoptimized
shader sources as successful optimization. This preserves configured shader
specialization for all terrain biomes and renderers.

### Cave magma glass shading fast path

The cooled-volcanic cave material now evaluates its expensive 3D grain/weather
and fracture fields only for non-glass surfaces. Glass surfaces never use those
fields in albedo, roughness, specular or normal calculations. The same glass
shader path also skips unused joint calculations. This preserves the original
material expressions for the non-glass families and eliminates zero-contribution
GPU noise work for glass features. The cave renderer still uses canonical CPU
mesh topology and collision; actual hardware speedup remains unmeasured.

### Bounded page-eviction metadata

GPU grid cache order uses one linked FIFO node per resident revision. Replacing
a page under an unchanged (but accidentally reused) product revision now
removes its obsolete order node immediately. Both the native texture budget
and the cache's bookkeeping remain bounded by actual resident entries, even
under repeated invalidation. Native regression explicitly rebuilds multiple
pages under a shared revision and checks that cache/order counts stay equal
and no old GPU image is aliased.

## Zero-control-bank GPU vertex fetch elimination

The shared vertex-displaced terrain shader now skips full RGBA32F texture
fetches for control banks containing only positive IEEE-754 zero. A per-patch
four-bit mask is captured while packing the existing immutable GPU page and
passed to the same shader used by **all 16 surface biome families**. Each
bank's numerical payload remains unchanged; signed zero, geological sentinels,
negative owner encodings, and mixed-biome controls are never discarded.
Terrain that uses only a subset of bank families can eliminate up to four
of the seven per-vertex RGBA32F fetches. The legacy material default enables
all four banks, preserving compatibility. All-biome native regression verifies
the exact byte payload and mask, including completely empty and signed-zero
cases. These are shader fetch savings, not a port of CPU numerical terrain
algorithms, and no device-specific GPU-time gain is asserted without profiling.

## Cave GPU material evaluation fast paths

Cooled volcanic rock now avoids its eight-corner 3D pore field beyond the
existing 160m apparent-normal range and whenever weathering is disabled.
The glass and disabled-weathering paths skip unused rock tint intermediates.
Default rock and frozen cave shaders skip normal-map sampling when their
normal-strength uniform is exactly zero, retaining the original material
colour, roughness and normal result. Crust-free magma skips procedural cracks,
plate-gap cell searches and folds because the final blend is fully molten.
These affect cave materials on all supported renderer backends; CPU cave
SDF/mesh topology and canonical collision are unaffected. Actual GPU timing
improvements require real-device measurement.

### Rendered GPU control-bank parity

The `gpu-extension` renderer test additionally renders the shared terrain
control-bank lookup from the same shader include as production. Eight
combinations of empty and occupied banks compare masked versus unmasked
RGBA32F pages, including actual rendered nonzero controls. Compatibility and
Vulkan Forward+/Mobile execute this fixture. Passing confirms selected control
samples on those software renderers; physical-device FPS remains unmeasured.

## Conservative GPU trail-curve rejection

All terrain materials using the shared curved `ground_trail` function now
reject a candidate path edge before computing its hashes, jittered endpoints,
Bezier tangents and nearest-curve search when the pixel is provably outside
the original straight-segment admission radius. The conservative AABB contains
every possible jittered endpoint and includes a numerical precision margin for
large saved-world coordinates. Edges that could have contributed execute the
original unmodified path code. A native randomized geometric regression checks
that no segment accepted by the former admission test is rejected by the new
bounding gate at multiple sizes, widths and world-coordinate magnitudes. This
reduces GPU work in grassland, forest, savanna, swamp, mountain and tropical
path materials without changing path topology or material-control settings.

## Extension biome descriptor cache retention

All eight extension numerical generators share the native site's 512-entry
bounded descriptor cache. Instead of clearing **every** descriptor when one
new site arrives, the cache now evicts the oldest one and retains 511 hot
sites. World-seed reconfiguration still clears the cache and its FIFO. The
strict native extension suite also verifies that hot objects remain resident,
old objects are evicted, deterministic recreated descriptors are byte-identical
and reconfiguration invalidates the cache. This is a CPU-authoritative
optimization benefiting every extension biome, not GPU numerical generation.

### Exact rendered curved-path parity on all available GPU backends

The GPU `gpu-extension` test also isolates the production curved-trail shader
and compares the conservative gate enabled and disabled in two real render
targets. Three world-coordinate windows, including negative and distant
positions, compare per-pixel trail masks on Compatibility and software-Vulkan
Forward+ and Mobile. The guard is on by default; the off path is a validation
reference, not an alternative appearance. Passing the test shows rendered
mask equivalence on the tested drivers; it does not prove a hardware FPS gain.

## Per-family extension atlas GPU fetch pruning

The shared extension atlas lookup now examines the chunk's authoritative
active-family mask before sampling its two packed RGBA8 weight strips. A chunk
containing extension families 0–3 only reads the first strip, a chunk
containing families 4–7 only reads the second, and a mask with no extension
families reads neither. Mixed-family chunks still retrieve both. Inactive
family channels are zero in the original numerical atlas, so this is an exact
skip with no biome control changes. Real GPU atlas parity now checks five
sparse and mixed ownership masks with and without the badlands palette, and
renders all eight channels as opaque outputs (including former alpha slots).

## Reuse 2D surface heights across 3D cave lattice columns

Native portal cave meshing now evaluates an X/Z surface-height column only
once for each lattice column in the immutable build, rather than invoking the
surface-height callback for every vertical voxel. A 17³ point lattice needs
at most 17² surface queries, saving up to 4,624 redundant calls before
normal and protected-shore probes. The cached value enters the **identical**
portal SDF expression and generated triangles/collision data are unchanged.
Unsafe points and disabled surface-air portals retain the prior fallback;
pooled temporary arrays are bounded and returned even on exceptions. A native
regression compares full surface payload bytes against the independent
GDScript portal mesher and verifies the exact expected reuse count. This
speeds CPU cave scalar preparation for all four cave biomes; it does not port
cave topology, SDF evaluation or Jolt collision to GPU compute.

## Compact immutable RGBA32F GPU terrain pages

The 16-biome shared terrain uploader now writes the first three exact vertex
banks (normal+height, quantized vertex color, UV+surface) and **only the
occupied four-component material-control banks**. Each page stores a four-bit
presence mask and an explicit band count; the vertex shader addresses a
present control strip using its rank among active banks and returns exact zero
for an absent one. The legacy seven-bank format still decodes with default
mask 15. All stored material floats, signed-zero sentinels, categorical
encodings, height and normals are unmodified.

The page uses `3 + popcount(mask)` RGBA32F strips rather than always seven.
A patch containing only its three mandatory strips uploads 3/7 as much grid
texture data (up to 57% less texture bandwidth/memory); patches using all four
control banks remain identical in size. The immutable texture reuse cache
uses the compact byte count for its actual GPU upload budget. The 16-biome
strict native tests compare every control lane against canonical products,
including missing-bank positive zero and required signed-zero preservation.
Real Compatibility and Vulkan renderer tests compare the compact texture with
an independently reconstructed original seven-strip texture. These are
transfer/vertex-fetch improvements, not numerical generation ports, and
hardware frame-rate gains are not yet measured.

## Compact family-control GPU atlas across all eight extension biomes

The ring terrain worker now scans its exact quantized family ownership mask
before allocating the RGBA8 extension atlas. Instead of transferring all eight
family-control strips plus two packed weight strips, it retains only the
active family-control strips in canonical family order, followed by the same
two four-channel weight banks. The optional badlands palette remains last.
Family slots are computed by a single shared `TerrainExtensionAtlasLayout`
used both by worker packing and main-thread ShaderMaterial binding, with all
256 possible eight-family masks independently checked in native CI. The shader
can decode legacy fixed 8/9-strip GDScript payloads, the older fixed 10/11-strip
C# payloads, and the new explicitly marked compact ring layout. Cave entrance
surfaces inherit the correct source material bindings; canonical collision and
all CPU biome values are unchanged.

A one-extension-family chunk transfers three strips instead of ten (70% less
extension-atlas upload/memory); a full eight-family chunk still uses ten.
Mask 0 uploads no extension family atlas, while a badlands-palette-only patch
still uploads exactly its palette strip. The GPU renderer validation compares
actual sampled weights, all material-control channels and the badlands palette
between legacy, fixed packed and compact layouts, across sparse/mixed masks on
Compatibility, Forward+ and Mobile software backends. These are transfer and
material fetch savings, not numerical GPU height generation. Real-device frame
and generation timing still require separate benchmarks.

## Constant ownership and material sampling across every biome

The shared grid uploader now detects when the already quantized UNORM8 vertex
ownership color is identical throughout a patch. It binds that exact value as
one material uniform and omits its repeated RGBA32F texture strip. Mixed
ownership patches retain the original per-vertex color strip. The shader's
logical addressing also preserves the legacy seven-strip and compact
three-base-strip formats, including every signed-zero and categorical control.

This removes one texture fetch per vertex and 16 grid-texture bytes per vertex from
eligible patches in **all sixteen surface biome families**. Relative to the
previous compact layout, the 289-vertex pure-biome regression patches change
as follows. These are exact payload sizes, not measured frame-time reductions.

| Patch families | Previous compact grid | Constant-ownership grid | Additional reduction |
| --- | ---: | ---: | ---: |
| Grass and all eight extension families | 13,872 B | 9,248 B | 33.3% |
| Forest, savanna, swamp, jungle, mountain, badlands | 18,496 B | 13,872 B | 25.0% |
| Tropical | 27,744 B | 23,120 B | 16.7% |

The extension families are quarry, wise mountains, volcanic, spore forest,
radiation wasteland, crystal wastes, insect colony, and alien infected.
Extension-atlas bytes and the small constant-color uniform are separate from
the grid texture sizes in this table.

Shared anti-repetition material projection helpers now skip the unused color
and normal texture sample when the existing blend is exactly zero or one.
Interior blends still sample both endpoints with the original explicit
gradients. The same helpers cover all base and extension biomes, coast,
beach, snow, biological material, and alien tissue projections. Grass skips
its planar color sample only when the existing micro-detail contribution is
exactly one; jungle reuses the cover sample already fetched for moss.
Texture resolutions, material controls, and normal-map strengths are retained.
The `terrain_material_sample_pruning` uniform defaults to true; false exposes
the prior sampling behavior for differential renderer checks.

### Pack interpolated controls within the renderer limit

The complete terrain shader exposed a Vulkan compilation failure that the
isolated sampling tests could not detect. Godot 4.6.1 reserves fifteen varying
locations, leaving seventeen custom locations under the tested 32-location
limit. The original terrain shader declared twenty-three custom varyings.
Its production interface now uses sixteen, leaving one for cave composition.

The shader packs smooth controls into unused W lanes, exports decoded coast
controls through COLOR, and exports decoded terrain-surface values through
UV2 after their vertex inputs have been consumed. It reads the constant model
origin directly, uses the existing UV water value, and omits only the unused
swamp ecology Y component from interpolation; the canonical payload retains
that component. World and local positions keep their original calculations.
The world normal is reconstructed from Godot's existing interpolated normal
instead of passing a duplicate normal vector. This introduces ordinary
floating-point rotation roundoff; Mobile can also store built-in COLOR and
NORMAL interpolators at half precision. Validation therefore compares actual albedo,
geometric normals, and mapped normals with an unchanged one-RGBA8-level gate
under varying normals, camera rotations, scales, and translated origins.

Composed cave entrances pack frozen texture coordinates into the three
remaining W lanes and use one additional vec4 for the three registered
optional-biome weights and entry depth. Redundant per-biome interpolators are
removed only when the independent-target helper ignores their arguments.
The original raw weights still govern the final blend. Native surface
decoding writes packed lanes directly, and XYZ assignments preserve them.
Compatibility compares against an independently restored original interface;
Vulkan uses independently restored original normal and coast-control values
as its terrain reference, which fits the available limit. CPU geometry and collision are
unchanged by this interface adjustment.

## Compact cave entrance uploads and native selections

The native cave worker now stores only RGBA32F texels that contain a nonzero
bit pattern somewhere in an entrance group. A 17-bit mask and packed stride
let the production vertex shader reconstruct all 68 control lanes exactly.
Negative zero and other nonzero IEEE-754 encodings remain occupied. All-zero
groups retain a valid minimal texture, and the original uncompressed
per-group input budget still applies. Materials without compact metadata
continue to decode the original seventeen-texel layout.

This common entrance path covers all surface owners and the default, frozen,
crystal, magma, and hive entrance material combinations. A synthetic
1,025-vertex group with four occupied texels uses 81,920 upload bytes instead
of 294,912, including row padding, and four vertex texture reads instead of
seventeen. The reductions are 72.2% in uploaded bytes and 76.5% in fetch count
for that fixture; dense groups have smaller savings.

Native barycentric selections now use a small value type instead of creating
a Godot dictionary and index array for each query. Indexed cave vertex keys
store the same ten float bit patterns directly instead of allocating an
80-character hexadecimal string. Geometry, normals, indices, interpolation,
and collision remain unchanged. Legacy dictionary APIs remain available for
the independent GDScript reference checks.

## Native configuration and compact-water correctness

`TerrainHeightField.configure` reads managed `TerrainMeshBuilder` fields
directly on the native path, avoiding sixteen `GodotObject.Get` crossings per
configuration. Non-native callers retain the existing property-based path.
The height filter now invalidates its bounded cache when the water context
changes, without adding the repeated water level to every cache key. Its
original floating-point arithmetic and neighborhood query sequence remain
intact; even an apparently equivalent shortcut at a saturated blend can alter
the final rendered float through cancellation.

Ring water now maps extension family IDs through their compact physical atlas
slots. The prior fixed family-index lookup could read another family or pass
the texture boundary for sparse high-numbered families. Pure badlands water
also recognizes its negative material-owner encoding without requiring a
mountain in the same patch. Independent regression covers all 255 nonempty
extension masks with and without a palette, interpolated inserted vertices,
pure badlands, and disabled-water behavior.

## Shared ownership and extraction optimization (November 24, 2026)

Canonical compact extension atlases that contain exactly one family and an exact unit weight at every texel can skip their remaining ownership texture lookup. The uploader checks both packed RGBA8 weight banks; fractional or mixed regions and legacy payloads still use the existing filtered texture path. Family material controls and palette layout are unchanged. The rendered atlas fixture compares the constant branch with the independent legacy and packed paths for all eight extension families.

All cave cross-section styles and portal meshes reconstruct lattice coordinates from three short axes instead of allocating a position for every voxel. The original scalar field, refinement, triangle ordering, normals and frontier capture remain CPU-authoritative; at 1 m spacing the omitted position array contains 3,295,500 bytes before pool rounding. Expanded reference fixtures compare every cross-section style at nonzero chunk coordinates and a two-metre frontier.

Forest, jungle, savanna, swamp, mountain, tropical and badlands use bounded FIFO eviction for the numerical caches that previously cleared their full working set on overflow. Existing per-source invalidation and capacity limits remain. These are GPU shader sampling and CPU workload improvements, not a numerical GPU port of the remaining biome fields or cave topology. New CI results and device timing must be established before claiming performance measurements.

## Experimental shared numerical noise bake (November 24, 2026)

All fifteen specialized surface generators now share a sparse GPU OpenSimplex2S/FBM noise pass. Planning follows the same exact-coordinate ring enumeration as the grassland baker, selecting owned families and the canonical Hermite, cubic or linear raw lattice support. Affine noise coordinates and full signed seeds preserve the canonical float inputs. The GPU result cache is scoped to a synchronous worker build; unsupported points, coordinates, noise settings, queue limits, cancellation and failed parity sentinels use ordinary FastNoiseLite. The extension-family subtype classifier and site-specific misses are deliberately CPU-authoritative.

Explicit `terrain-generation=gpu` enables the specialized pass; `terrain-biome-noise=off` disables it, and `terrain-biome-noise=on` enables it with automatic generation. The saved CPU default and ordinary automatic selection are unchanged pending hardware timings. Separate counters report completed numerical scalars, actual consumed cache hits, and parity rejections. This is a partial numerical GPU port for all 16 active surface families, not a port of all site placement, biome shaping, hydrology, or cave topology. The actual rendered atlas check now also compares every planned noise result and verifies consumption and height tolerance in all 15 specialized samplers. CPU authority is retained; strict world-wide parity and measured hardware speedups are not asserted by the experimental option.

## Experimental GPU cave lattice screening

`terrain-cave-gpu=on` enables a bounded numerical viewport pass on rendered clients. It evaluates the ordinary, entrance, chamber, and all eight cross-section SDF styles from the same sparse CPU feature bins, with the original per-column terrain/portal heights. The floor-relief band, protected-shore bisections, every chunk border, all near-zero samples and every mixed-cube corner are recomputed by the canonical CPU field. CPU tetrahedral extraction, normals, collision, and frontier publication are unchanged. Unsupported fields, out-of-range descriptors, parity failures, tiny cells, queue timeout and headless/authority mode retain the CPU path. The rendered fixture requires actual GPU consumption plus byte-identical canonical mesh and frontier arrays for all eight styles.

This is an explicit experimental screening option: sampled parity plus a conservative crossing band are not a formally proven floating-point bound at every possible coordinate. Do not enable by default or claim measured speedups until device-specific checks establish correctness and end-to-end performance. Arbitrary triangle extraction and physics remain CPU-authoritative.

## GPU-resident cave topology classification

On the explicit cave GPU backend, a second numerical viewport consumes the SDF texture directly on the GPU and encodes the six marching-tetrahedron sign cases into one exact 24-bit integer per cube. An exactly representable sentinel requests canonical CPU evaluation for uncertain and boundary cubes. No intermediate SDF readback occurs when this stage is available. The worker reconstructs exact scalar values at all candidate triangle corners, all boundary cubes and deterministic uniform-cube sentinels, rejects any certain case disagreement, and skips uniform cubes without reading uninitialized scalar slots. Existing protected-shore refinement, vertex welding, triangle orientation, normals and collision retain the canonical CPU operations. The original SDF-only path remains a fallback when the topology shader is unavailable; numerical rejection uses the full CPU field. All eight cave-style rendered fixtures now require actual GPU topology consumption and exact mesh/frontier output. Device performance and a formal floating-point sign bound remain separate from these tests.

## Shared numerical landform shaping for every biome

The specialized generation option now batches continuous raw terrain shaping as well as OpenSimplex2S noise. The shared portable shape shader handles all 15 specialized families: forest, savanna and jungle raw height/material fields; swamp base relief; mountain ridge/summit relief; tropical hill/ridge relief; badlands base mass/plateau; and the subtype shaping equations of all eight extension families. The original grassland numerical baker continues to cover grassland. The CPU supplies the exact geographic rotation, subtype ownership, site/lane/network descriptors and hydrology plans. The final hydrology/erosion interactions, terrain feature construction, extension interpolation and collision authority remain canonical CPU operations where the GPU kernels do not cover them.

The second pass uses bounded immutable shape records and exact float-byte output; raw products are installed in a worker-scoped cache only after per-family CPU sentinels agree. Failed or unplanned queries retain the original CPU equations. The rendered suite compares every planned raw shape and explicitly exercises all six subtypes of every extension family, as well as actual per-family sample consumption and final height tolerance. These are regression gates, not a claim that every geographic or gameplay operation has moved to the GPU.

The cave topology pass additionally checks every uniform-cube corner. Sign-only CPU certification uses exact feature projection and depth constraints with conservative wall/style and generalized arch bounds; uncertain points use the canonical SDF. All triangle corners and frontier values remain exact. Thus skipped uniform cubes do not depend solely on GPU sign accuracy. The native fixture includes 12,000 adversarial sign-certificate comparisons.

### Adaptive runtime selection

The saved ring configuration now uses Automatic. The CPU baseline and occasional GPU probes measure the complete worker time, including planning, graphics queue latency, readbacks, validation and final mesh creation. Surface timing groups are separated by revision, LOD, resolution and sampled biome ownership mask; cave timing groups use lattice resolution, portal surface mode and a bounded field-complexity band. The GPU must beat the CPU estimate by at least 5% to be preferred. Small nearby tiles and software or headless renderers retain CPU generation; explicit CPU and GPU launch options remain available. Automatic selection is not a universal hardware speedup claim. Final authoritative physics, site planning, exceptional samples and mesh publication remain on their original canonical paths.
