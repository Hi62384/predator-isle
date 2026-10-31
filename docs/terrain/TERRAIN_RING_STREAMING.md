# Terrain ring implementation

The main scene now explicitly selects `nested_rings = true`. The retained quadtree
implementation remains available by disabling this property on the Terrain node.
Both paths use the native C# world generators. No Hoogie code or textures are used.

## Configuration

Edit `config/world/terrain_rings.tres`, then restart the scene. The default is
Medium: 16 m patches, 1 m nearby visual spacing, six outer rings, up to four
terrain/cave workers shared with the main controller, 1.5 ms upload budget,
and a 128 MiB numerical LRU cache. The controller's existing `worker_count`
remains an upper limit; a profile cannot silently increase that limit.

Select a profile and click **Apply selected profile** in the resource Inspector.
`TerrainRingSettings.apply_profile(0..3)` also fills Low, Medium, High and Ultra
settings from C#. A launch argument such as `-- terrain-profile=low` applies the selected
profile to a private copy, leaving the saved resource unchanged. Low selects
2 m visual spacing, fewer rings and conservative budgets; Ultra selects 0.5 m
visual spacing. Inner spacing, ring count, shader quality, worker allowance,
upload time and cache memory can also be edited separately. CPU generation is
the supported backend; optional GPU compute has not been implemented.

The frame-time budget controller slowly reduces dispatch/upload allowance under
sustained pressure and restores it after sustained recovery. It does not change
geometry resolution or material quality while moving. Low shader quality reduces
medium cliff-normal work and distant microtexture sampling; the higher profiles
extend material detail distance. Godot shader import has not been exercised for
the latest shader edit.

## Geometry and publication

Every ring uses an independently snapped world grid with a 3:1 size ratio. Partial
coarse patches retain exact masks for finer ownership. Explicit third-boundary
knots and coarse-to-fine edge stitching support this ratio without giant skirts.
Fine boundaries follow coarse polylines and normals. This is spatial stitching;
temporal animation of an entire LOD replacement is not implemented.

The scheduler retains unchanged source patches, reuses worker-local generators,
cancels obsolete work and caches canonical arrays and fixed collision data.
Final stitching, water preparation and fingerprints run on a worker. Uploads are
spread across frames; unchanged meshes are reused. After initial central coverage,
the committed terrain remains until a complete replacement and its cave cut are
ready. Teleport destinations also wait for the existing cave readiness check.
Worker or upload failure retains the committed cut and exposes an error.

Far terrain uses footprint-sized height filtering with continuous protection for
shorelines, peaks, valleys and sharp escarpments. Nearby steep/curved land and
geological footprints can request local refinement. Cave entrance support always
requests fine coverage. Refinement balances shared edges to at most one ternary
level and rejects plans exceeding 4096 patches. Topology, height-filter and source
caches have finite limits. Cache allowance is not a limit on total process memory:
active meshes, wanted source patches, physics, materials and worker caches also
occupy memory.

Local water, material atlases, geological structures, protected portal sites and
terrain ownership use the same patch masks. Existing biome material banks,
structure admission/model guards and cave transaction checks remain in use.

## Canonical ground and world changes

Nearby ground collision is sampled on a one-metre CPU grid independently of
visual spacing and stitching. Distant visual patches do not receive ground
collision. Cave surface snapshots use canonical heights in ring mode, so their
extraction does not depend on the client's terrain quality. Visible stitched
boundaries may differ from this fixed ground grid; the magnitude and playability
of these differences still require runtime checks, especially at steep slopes.

`TerrainConfiguration.terrain_changes` stores an ordered array of
`Vector4(world_x, world_z, radius_metres, height_delta_metres)`. Changes use a
smooth compact radial falloff. Up to 1024 finite changes are accepted, with
radius and absolute delta bounded to 512 m. A spatial index avoids scanning the
whole change list for every height sample. These changes enter canonical height,
normal, collision, structure foundation and cave generation queries. Restart or
reconfigure generation to apply a changed snapshot; this is not a live editing UI.

`ChunkTerrain.get_world_identity()` returns a SHA-256 identity and normalized
snapshot of seed, water, terrain/cave settings, engine version and generator
assembly. Visual ring/profile settings are excluded. Networking code should
compare identities and distribute the same ordered world-change snapshot before
admitting players. This provides terrain integration data, not network transport,
RPCs, authentication or a multiplayer lobby.

## Server residency

The `terrain-server` user argument or the `dedicated_server` export feature opens
`scenes/terrain_server.tscn` and skips visual shader warmup. The scene has no camera
or distant visual rings. Its terrain is hidden; nearby numerical/material arrays
are still produced for compatibility with the existing cave projection pipeline.
It does not require GPU compute or a camera clipmap.

Server-approved actor nodes are registered through
`register_collision_actor(player_id, actor)` and removed through
`unregister_collision_actor(player_id)`. The default radius is 64 m per actor;
overlapping terrain cells are shared. Up to 16 actors and 4096 patches are allowed.
Required cave support can extend the resident footprint. Each actor's cave stream
shares the same total worker allowance, with rotating dispatch order. Joining
another player retains existing streams. Ground subtraction combines committed
cave columns from all streams so one entrance cannot restore ground over another.

Wait for `collision_actor_ready(player_id)` before releasing an actor into newly
requested terrain. The service deliberately generates nothing while no actors
are registered. Actor registration and world replication must be connected by
the game's networking layer; no networking layer existed in the supplied runtime.

## Verification status

The later loading implementation in `data/loading_optimization_current.json`
replaces generic callbacks with direct C# sampling on known native providers,
stops conclusive canonical height-only entrance/chamber probes early, and avoids
rebuilding an unchanged game at every launcher invocation. It compiles with zero
warnings/errors, but has not received a new gameplay or timing run. The completed
15-group suite and its roughly 43-second full-startup measurements describe the
preceding source snapshot; they are not a measured result for these changes.

The user has now requested runtime testing. The current C# build passes, and
the checks run with the bundled Godot 4.6.1 .NET executable. Run the full suite:

```powershell
dotnet build PredatorIsle.csproj --no-restore
dotnet run --project tools/csharp-runner/PredatorIsle.Checks.csproj -- all
```

The current aggregate result is `data/csharp_runner_latest.json`; each mode has
its own source-bound `data/csharp_check_<mode>_latest.json`. The runner continues
after failures, rejects engine errors and stale reports, and limits each owned
child to 180 seconds and 2 GiB sampled private memory. Other sessions are untouched.
Ring tests cover negative coordinates, corner ownership, masked triangles,
refinement, 3:1 seams and profile controls. The real saved launch test requires
all initial patches, nearby collision and cave discovery, then moves 115 m and
returns with physical ground queries. It saves `data/startup_verified_render.png`.
Server tests cover overlapping actors, installed ground, the 16-actor cap,
departure of all actors and rejoining. Blob tests build the default draft organism,
check closed topology, and simulate eight movement modes. The remaining modes
compare biome, water, cave and material behavior with preserved references.

Testing exposed and repaired diagonal corner ownership that could stop outer
rings, repeated startup refinement that delayed their publication, excessive
height/filter queries, adaptive startup worker starvation, worker property access
errors, and an unparented blob UI control that leaked a popup viewport on exit.
Editor builds now retain compiler optimization. The inspected saved-launch capture
has no debug overlay. Full cave discovery remains much slower than nearby terrain;
the timings in the current report are uncontrolled-cache observations, not a cold
or isolated benchmark. Original scenic/art gates and long underground traversal
acceptance remain outstanding; historical receipts keep their original scope.

## Original-scope reconciliation

The original requests describe procedural scenic outcomes, not an obligation to
add a separate hand-authored scene or new generator for each named view. Source
coverage for the named scenery families is present:

| Requested family | Current implementation paths |
| --- | --- |
| Surface provinces, eroded landforms and transitions | Native biome samplers, `TerrainRegions`, `TerrainHeightField`, shared hydrology and existing biome material includes |
| Giant insect mounds, vents and clay surfaces | `InsectColonySampler`, `InsectMoundProfiles`, `InsectVentGeometry`, `BiomeStructureGeometry`, existing earth material |
| Alien conduits, biological junctions, struts and membranes | `AlienInfectedSampler`, `AlienCarapaceGeometry`, `AlienJunctionGeometry`, `AlienMembraneGeometry`, existing tissue materials |
| Default and Frozen connected caves | Shared `CaveNetwork`/`CaveField`, regional selection/blending, `CaveFormations`, `FrozenCaveFeatures` and `FrozenCaveGeometry` |
| Crystal scenic A–J and M: quartz, amethyst/geodes, selenite, smoky minerals, tall/dense/sparse chambers, veins, ravines and broken deposits | `CrystalCaveFeatures`, connected chamber profiles, `CrystalCaveGeometry`, `CrystalCorridorFeatures` and `CrystalVeinExposure` |
| Crystal K, L and N: mineral lake, Default transition and rare luminous mineral | `CrystalLakeChambers`, shared graph-aware blending and `CrystalLuminous` |
| Magma A, D, H and J: cooled tubes, hardened-flow passages, fissures and collapsed tubes | `MagmaCaveTubes`, chamber profiles, cooled surface/feature materials and floor deposits |
| Magma B, E–G, K, M and O: basalt halls, rough deposits, columnar rock, obsidian, ash, dormant chambers and connected complexes | `MagmaCaveFeatures`, `MagmaCaveGeometry`, shared connected graph and cooled material |
| Magma C, I, L and N: molten lake, crusted molten chamber, channels and Default transition | `MagmaLakeChambers`, `MagmaCascades`, retained basin/water infrastructure, source heat, dedicated molten material and shared blending |

This is a source mapping, not proof that every combination is reachable at the
requested scale, frequency or visual quality. It does not turn the historical
22 Magma runs/16 contexts into 56 distinct scenic cases. Diagnostic probabilities
are not normal-occurrence evidence. Disabled saved surface coverages remain
disabled; adding their implementations does not silently change world settings.

No additional concrete absent generator/asset was identified in this focused
comparison. The exact open criteria are:

- Convincing surface silhouettes, distinctive materials, natural geological
  transitions and all requested ground/medium/aerial scenic outcomes, including
  the previously recorded Badlands banding and alien join/hierarchy concerns.
- Crystal scenic A–N and Magma scenic A–O occurring in ordinary procedural worlds
  with their requested scale, composition and variety. Rare lake/luminous/molten
  outcomes need normal-setting occurrence evidence, not only forced examples.
- Readable Default/Frozen/Crystal/Magma transitions; rock, ice and minerals that
  resemble their references; restrained transmission/emission; lake-fitting
  banks and genuinely safe connected routes.
- Current moving-ring continuity, nearby detail and preservation of cliffs,
  ridges, shelves, channels, coasts and cave entrances. Ground/profile consistency
  and multi-actor cave ownership must be accepted against the new default mode.
- Comparable startup and streaming improvement, acceptable publication spikes,
  uninterrupted traversal and compliance with the existing RAM/resource limits.
- Godot import and appearance of the latest shader-only Badlands material edit.

These are outstanding acceptance criteria beyond the focused checks above.
The implementation-first test deferral was superseded by the user's explicit
request to test every feature. Further art edits require a specific observed mismatch; generic
unfinished-art labels alone do not identify a justified new implementation.
