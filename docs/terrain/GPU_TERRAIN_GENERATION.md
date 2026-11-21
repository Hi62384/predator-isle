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
