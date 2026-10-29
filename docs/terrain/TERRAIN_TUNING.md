# Current terrain fixes — 2026-10-28

The saved world now uses `config/world/terrain_settings.tres` with
`height_blend = 3`, previously 12. This broadens the shared height-ownership
lattice so mountain borders rise through foothills. Three fixed-seed land
transects widened from 392/104/152 m to 984/424/1,424 m. These are measured
examples, not a guaranteed width for every border. Restart the game to rebuild
existing chunks after changing this setting. Matching native before/after
previews are under `tools/biome_extensions/artifacts/biome_transition_*.png`.

The default debug panel is hidden; backtick toggles it. Mouse look captures on
entry and on clicking the game after Escape. The project root is organized
into `config/`, `scenes/`, and `docs/`; the relocation manifest and original
copies remain under `tools/maintenance/artifacts/`.

Nearby terrain uses 2 m grids in the camera's 3-by-3 chunk neighborhood,
with 8 m LOD1 and 32 m LOD2 grids. Ready startup leaves display before the
entire distant cut finishes. During movement, complete local replacement
groups publish atomically when their geometry, shared edges and cave/collision
transaction are ready. Recorded actual edge grids or emitted skirt coverage
are required for any temporary logical LOD gap. Distant large transactions
retain the old complete cut until the final replacement is ready. Background
cave replenishment reserves three of the four workers for queued terrain.

The current local-cut policy verifies actual skirt coverage at every fine
edge segment, including aligned density ratios above four. Complete local
transactions allow up to 128 new leaves. In the fixed native movement test,
nearby detail published after 2.948/2.180 seconds for the two local moves and
9.803 seconds for the 20 km jump; the complete distant cuts took
22.831/19.429/31.428 seconds. The largest measured publication cost was
11.854 ms. These are source-bound measurements, not cold-cache guarantees.
The separate edge oracle covers positive and negative cases in all four
directions, negative coordinates, and density ratios from two to 64.

A fresh rendered Spore return with private upload timing probes completed
822.8 m at 5 m/s with no preload pauses or unsupported drop. Across 10,136
process intervals, the 95th percentile was 17.35 ms and one frame exceeded
100 ms (113.021 ms maximum). Native cave shape creation stayed below
0.251 ms; the largest cave upload collection, 69.426 ms, occurred during
preload. This diagnostic does not establish hitch-free performance.

Current scoped results and remaining work are recorded in
`data/runtime_fix_status_20261028.json`. The older release numbers below
describe their archived sources; they do not certify subsequent changes.

# Enabled cave integration release — 2026-10-28 (archived source)

The saved game now enables the shared cave runtime with Default, Frozen,
Crystal and Magma definitions. `world_startup.tscn` prepares the configured
terrain shader before loading the large texture banks, then opens the original
`main.tscn`, including the existing Blob workshop. This section supersedes the
older root-disabled and queued-Magma status notes below; their experiments and
source hashes remain historical.

Current results are collected in
`tools/biome_extensions/artifacts/cave_enabled_release_20261028.json`.

| Final check | Actual result |
| --- | --- |
| Saved application startup | 46.759 s; 117 surface chunks, full LOD6, 50 km camera, all four cave definitions and actual runtime streamer |
| Startup process memory | 1,363.1 MiB sampled against the unchanged 2,048 MiB limit; engine shader cache disabled, separate driver cache uncontrolled |
| Full Magma surface-to-depth-to-same-exit return | 17,212.960 m; all 3,146 waypoints; 263.694 m canonical depth; 67 committed cuts and two entrance exchanges |
| Return limits | 244.015 s motion against 650 s; maximum unsupported drop 0.038109 m; four total terrain/cave jobs; 1,641.6 MiB sampled memory |
| Shared regressions | All 31 surface scripts passed with unchanged guarded production sources |
| Cave release checks | All 17 checks passed: surface transactions, worker allowance, registration, distribution, heat, thermal field, cooled geometry, tubes, deposits, provinces, lakes, roof drips, cascades, controls, field bounds, depth exclusion and fluid-specific material binding |
| Native material composition | 64 checks passed; Frozen/Crystal/Magma independent target oracle and reversed order differ by at most one RGB byte |
| Earlier normal Magma scenery | 22 native runs, 16 distinct physical contexts, 154 retained images, 660 stationary renderer samples; source-bound archive `magma_native_breadth_96a728b268c4` |

Magma retains the requested 22% spawn chance, 300–1,100 m region extent,
depth weights `[0,5,30,80,100]`, and surface affinities Volcanic100,
Mountain35, Badlands20, Quarry15, Radiation15, Desert10 and RockyCoast5.
Zero-weight shallow bands are excluded throughout the band. Volcanic regions
include five chamber provinces, four short-tube profiles, physical cooled
deposits, measured columns/blocks/obsidian, dikes, sills, solidified cascades
and roof drips. Ten reusable templates and the existing per-cell geometry
bounds remain in place. Rare source-backed molten pools, lake chambers and
supported-film/short-freefall cascades use actual retained source identifiers;
they do not turn ordinary groundwater into lava. One bounded source light is
selected from actual uploaded molten geometry.

The final integration also filters molten pools out of rock-water wetness and
Frozen moisture **before** applying their source limits. All water-only material
parameters retain their previous values. Basalt feature shading now uses darker
linear albedo, iron weathering, irregular joints and near-view vesicle relief,
with periodic noise across the common 3,840 m material wrap. The existing CC0
Rock051 photograph/normal resources supply appearance detail; they are not
represented as a verified basalt scan. Existing material provenance is in
`data/cave_material_sources.json`; no new texture download was introduced.

Terrain startup no longer evaluates each legacy material separately in both
the fast and blended shading paths. The same target is evaluated once and
reused. Seven actual single-owner worlds and a normal Forest/Badlands mixture
were compared in five display modes with original-image returns. The original
strict Savanna equality test failed by one byte and remains archived. A mixed
two-byte test also remains failed: sparse pixels differ by up to three bytes.
The separately recorded visual budget accepts at most four bytes and 0.00001
mean normalized RGBA error; the measured mixed mean is below 0.00000005.
Original-image returns were exact. These are bounded visual comparisons,
not a claim that every optimized pixel is byte-identical.

Reproducible locations include Volcanic seed17/site(-73,138) for the full
normal molten return; Volcanic1001/site(6,-2)/room `6:-2:2:0` for the collapsed
tube chamber; and Volcanic1001/site(8,-4)/room `8:-4:3:3` for the full short
fissure walk. The normal transition catalogue retains all 108 cases, including
15 Default–Magma and seven Crystal–Magma joins. Native returns passed for both
first selected joins (136.033 m and 141.134 m). The 720-case scenery catalogue
retains all negative cases and contains 14 contexts with Magma rooms on more
than one graph level. Targeted floor-area sampling estimates a 0.165578 Magma
weighted fraction of sampled clear dry floor; this is a Volcanic study, not
global world coverage.

Limits remain explicit: the other project's Godot sessions were left running,
so no measurement is isolated. The full return uses fixed60Hz accelerated
physics, loading pauses and rendering disabled during movement; it does not
establish uninterrupted gameplay FPS. The existing Jolt job-capacity warning
recurred and is preserved in the logs. Rare large-lake/cascade positive scenes
use labelled diagnostic probabilities, with ordinary saved probabilities
unchanged. The scenic inventory is not 56 distinct native scenic tests, and
visual inspection does not establish photographic equivalence to the supplied
references. This release completes the enabled-game functional integration;
it does not certify every reference-quality artistic criterion in the briefs.


## Registered Magma geology and current limits (2026-10-27, later continuation)

The saved cave registry now contains Default, Frozen, Crystal and Magma.
Native four-definition save/reload, exact prior Spore/Crystal geography and
whole-cell parity, and positive actual molten geometry pass 85 checks
(`64ba40d01849`). The root cave switch remains false while shared startup,
traversal and global visual/performance work continues.

Enabled Magma additions include five coherent province chamber shapes, four
existing-graph passage profiles including tall fissures, bounded 0.45 m physical
cooled deposits, periodic ropy/rough/ash/dike/sill surface detail, and measured
wall-attached opaque dikes, sills and solidified cascades. Ordinary routes and
retained lake rims exclude the complete physical forms. Nine reusable templates
and the existing 64-form/24,000-vertex cell budget remain bounded. Separate
province, intrusion and deposit archives are `fc092d8a1645`, `caa252c8d103` and
`3b36ca52603d`. These are functional geometry proofs, not photographic art approval.

The enabled full normal Magma return passes 167 checks, all 3146 waypoints,
17,213.137 m and 263.694 m canonical depth. Preload is 19.306 s, motion 248.017 s,
maximum unsupported drop 0.038109 m, four total jobs and sampled private memory
1616.9 MiB under 2048 MiB (`9dd2aa09d8d6`). One source-bound light was observed
13 times. Other Godot sessions remained running; accelerated movement and
loading pauses are not uninterrupted FPS or isolated timing measurements.

The original fixed diagnostic large lake passes 300 native checks with 75
formations and its complete 267.758 m two-way dry-rim/parent return plus the
56.852 m passage return (`850c0c303492`). Only large-profile chance is diagnostic
100%; normal chance remains 8%. Current revalidation retains all eight original
normal molten identities and all 16 normal/diagnostic lake outcomes
(`02ebcdff7ce3`); all eight normal large-profile outcomes remain negative.
This is not a rerun or rebinding of the old 2592-site historical survey.

Rare exposed molten cascades, the complete requested scenic/test breadth,
reference art, shared steep approach/startup and global performance acceptance
remain open. A private dynamic extension-loop startup candidate failed the
unchanged 2048 MiB ceiling at 2082.7 sampled MiB and was not adopted. Compiling
the unchanged shader before loading texture banks also failed at 2261.3 MiB.

## Earlier verified Magma work and gates (2026-10-27)

The first full normal source-backed Magma return passed **162 checks**, all
**3146 waypoints / 17,213.126 m**, reaching **263.694 m** below canonical terrain.
Preload was **72.822 s** under 180 s; motion **225.124 s** under 650 s; maximum
unsupported drop **0.038109 m**. Four total jobs, 128 peak cells and **1640.4 MiB**
sampled private memory stayed under the original 2048 MiB gate. Archive
`69109f0a8bb4` freezes that functional phase; later scenic/lighting changes still
require a current full integration return. The failed original 180 s preparation
is retained (`5e578a9d055a`), not relabelled as a pass.

That preparation failure exposed far-origin centroid rounding at original
terrain-parent boundaries. Whole-triangle parent selection fixes the rejected
payload without clamping vertices, clipping/removing geometry or changing
collision. All four exact captured portal parts now succeed. The independent
813-check proof (`f8b1789868d4`) retains 400 already-valid indexed/nonindexed
triangle comparisons byte-for-byte and keeps true unsupported crossings rejected.

The six predeclared source seeds retain all **2592** cave locations, **288**
eligible sources and **8** molten pools (`bf2afea71be6`, historical source maps).
Retained surface-lava witnesses remain distinct from explicitly modelled
intrusions below normally active volcanic centres. These normalized suitability
models are not measured temperatures or a normal geothermal gradient. Current
fixed-location validation keeps all eight original positive identities and all
16 normal/diagnostic lake outcomes; it does not rebind the old full catalogues.

Large lake geometry now has a 14 m molten basin, a 36 m low dry bank and two
unequal 38/46 m vaults. A controlled adoption return covers 258.248 m with 74
formations. The fixed actual source-backed large-profile diagnostic passes its
253.483 m two-way full dry rim plus original passage return (`72f033d88aab`).
The large-profile probability alone is diagnostic 100%; the saved probability
is 8%, and all eight normal fixed cases remained negative. No normal-frequency
large-lake appearance is claimed. Wall-following, varied fractured columns have
also passed the same native shore/parent returns (`300` checks) and are adopted.

A single nearest-uploaded-molten-source light is being verified. It is a
main-thread renderer controller, not extra workers or per-basin light nodes.
The saved world registry is still Default/Frozen/Crystal and root caves remain
disabled pending the remaining Magma/current integration and global gates.
Reference-quality art, steep Wise approach, cold startup memory and global
performance remain open. Other Godot sessions remain running at the user's
request, so timing is nonisolated. All-user completion remains false.

## Current implementation state: Magma integration (2026-10-27)

Crystal's functional phase is registered in the saved Default/Frozen/Crystal
registry. The immutable registered checkpoint passes 1333 checks (archive
`3c7ec7dc5c1e`), including actual registration and shared regressions. All twenty
selected normal native scenes passed their returns; 600 stationary renderer
samples are retained. These do not certify reference-quality art or global FPS.
The reflection-probe experiment was tested, rejected and left unadopted.

Magma now has its requested independent 22% / 300–1100 m definition, cooled
basalt columns, volcanic blocks, opaque obsidian wedges, full-foot fitting,
protected-route exclusions, matching collision and complete-form LODs. Its
controlled native geology proof passes 853 checks with 60 formations and a
complete ordinary return. Integration passes 84 checks: the fixed original
region is byte-exact with Magma absent/disabled/zero-spawn, three cold Frozen
payloads match the immutable prior provider, and actual retained surface lava
supplies localized heat through the existing worker. Whole hot ice formations
are rejected. Source-backed retained basins use a dedicated dark-crust lava
shader and cannot leak into freshwater rendering. Normal world molten geometry
and full Magma traversal are still being verified; Magma is not yet saved into
the registry. Root caves remain disabled.

The earlier dated observations below retain their historical scope. Global art,
steep Wise surface approach, cold startup memory, full current integration and
performance remain open. Other project sessions stay running at the user's
request; timing observations are nonisolated. All-user completion is false.

# Completion work in progress (2026-10-20)

## Current verified Crystal continuation (2026-10-27)

The latest full integrated return **with production floor ridges** passes **158
checks, all 5006 waypoints and 27,394.580 m**, reaching 396.008 m below canonical
terrain. Motion takes 464.567 s under the original 650 s limit; preload is 42.644 s
under 180 s. The ordinary capsule's maximum unsupported drop is 0.038109 m.
There are 48 committed cuts, two entrance exchanges, four total terrain/cave
jobs, 185 peak cells and 1692.2 MiB sampled private memory under 2048 MiB.
Archive `3a5ba4ff981c` retains 139 verified copies. It includes normal rare
emission, production shallow branches, ambient shelter and floor ridges.
The earlier 157-check archive `cc29752d7dc4` remains historical under its original
pre-shelter/floor source; none of its hashes are rebound. The repeated accelerated
Jolt job-capacity warning is retained and is not declared fixed.

The complete 2070-case shallow Crystal survey has two normal positives. Both
retain their exact original proposals after stricter checks of all original
route floors and lake banks. The first is Quarry seed 1002, site (6,-2), ordinal
336, physical depth 38.010 m. Production adoption passes 103 independent checks,
and its actual native branch and original access returns pass 293 checks
(`626ce83e1c2b`). The saved normal chance/depth/affinity/extent controls remain
unchanged. Shallow branches are now adopted, superseding older private notes.

The first normally rare luminous scene is Crystal Wastes seed 19, site (9,-3),
room `9:-3:2:3`. It has 12 tagged prisms among 130 crystals with unchanged normal
0.005 region and 0.12 form chances. Its original solved edge and same-way return
pass 493 checks / 478.558 m / 81 waypoints (`3df99bc1e9a0`). This is actual normal
occurrence. The six original mineral-family locations and that same rare site
also pass native images and walks after ambient shelter was adopted. Shelter
0.08 reduces unoccluded sky response; direct-only images stay pixel-identical
and the exact original image restores (253 checks). No extra lights were added.

Room floor ridges now use the existing scalar, mesh and rock collision. The
independent switch defaults ON at a bounded 0.65 m height; passage footprints,
lake banks and biological ownership remain protected. The private controlled
floor reaches 0.640 m / 12.494 degrees, passes its complete shared-cell boundary
and actual ordinary return. Production single-pass scalar/normals and all three
mesh payloads match the frozen private candidate exactly over 4810 probes; OFF
matches the complete frozen original. Additional rejected-cover/unassigned
region cases pass (73 adoption checks). The original actual Crystal Wastes
73921/(6,-2) room passes 251 native checks, its 51.530 m passage return and a
22.469 m raised-floor return (0.095276 m maximum drop), archive `12bc31c4f89a`.
A later guard restricts the modifier to admitted geography; its new regression
is passing. Current full integration is passing above; native scene breadth and
registration checks continue.

The complete **420-case** normal Mountain/Wise transition inventory preserves
the original 36-case negative prefix and every later negative. It passes 566
checks with exact original controls and zero optimized/raw weight differences.
Its first natural Frozen/Crystal edge is Mountain seed 19, site (8,-4), original
ordinal 95: 440 native checks, 207 crystals, six veins, actual Frozen and Crystal
rock adapters, 478.467 m / 81-waypoint ordinary return, 0.038109 m drop and
938.9 MiB sampled memory (`7fe890b2dfb5`). This dry overlap has zero ice mesh
nodes; no groundwater was invented. The Default/Crystal edge remains the first
original Mountain 1001/(8,-4) edge. Its entire producer edge is 3988 m long, so
an unsuitable short-fixture run was cancelled and its incomplete logs retained.
A pre-physics window around the same half-strength transition passes 412 native
checks, 182.349 m / 47-waypoint return, 0.038111 m drop and 870.6 MiB sampled
memory (`dac944c97eef`), including positive host-material-off/exact-return images.
The full 27.4 km return separately covers complete Default/Crystal transitions.

Twenty fixed original unique normal scene locations now undergo actual native
LOD/renderer profiling and ordinary connected returns. Eighteen currently pass.
The first normal quartz scene submits 67,936 full-index and 64,588 forced-far
triangles, restoring exact original pixels; 30 stationary viewport samples
average 0.939 ms CPU / 2.827 ms GPU. These are nonisolated component observations,
not whole-world FPS. The original 1422.162 m region's selected logical lobe has
three attached vein segments but zero own prisms. Its twelve canonically
dominated connected nodes include fourteen actual same-theme parent/sibling
prisms in the inspected volume. The earlier per-lobe-prism assertion stays
failed; a region-extent-specific native check retains the exact original
host/seed/site/room/theme and verifies this real ownership instead (428 checks,
`e6ab9ef48956`). No geometry, density or chance was changed to satisfy that test.
A private one-probe reflection study is prepared to address flat interior
mineral reflections; it is not adopted or visually accepted yet.

The saved registry is still Default + Frozen and root activation is false.
Crystal remains the active ordered phase; Magma is next. Reference-art breadth,
remaining transition/profile/streaming checks and global startup/performance
work are not declared complete. Other Godot sessions remain running at the
user's explicit request, so timing is nonisolated. Historical failures stay
failed and immutable; the notes below describe earlier stages.

## Earlier Crystal continuation (2026-10-27, historical)

Rare **fictional** luminous minerals are now integrated with normal region chance
0.005, form chance 0.12, a hard 10% per-cell cap and faint 0.025 emission strength.
Ordinary minerals and all host rock remain non-emissive. Only selected existing
opaque prisms receive a lossless sign flag in their thickness UV; no new geometry,
collision, LOD, texture, particles or light nodes are introduced. The 170-check
private payload test preserves exact decoded original batches, full OFF/zero and
input equality, and finds 519/100,000 admitted synthetic region IDs. Forced
selection tags 8 of 89 actual-world prisms (`dcaa2ef307da`). Private native low-light
controls pass 247 checks (`22a7611a1fde`). Production adoption passes 73 independent
frozen-provider/helper comparisons (`6e87c4e95375`), and the actual production
shader passes 242 native checks with visible emission-off/exact-return images and
the unchanged 51.530 m ordinary return (`99c189e5a4c2`, 880.1 MiB sampled). These
forced-selection mechanism tests are not normal rare occurrence. The current
normal scene lookup is being extended from pockets to existing main chambers.

A private shallow shared-volume proposal preserves original main nodes and
routes and rechecks every original access floor at 2 m stations across its full
width. It finds three safe additions in 36 original cases (222 checks). Its first
31.845 m chamber passes a 103.828 m branch return and the original access-junction
return with native collisions (310 checks, 788.2 MiB, `fa36a3addb0d`). The first
attempt's shutdown resource leak is preserved as a failed overall run; freeing
the fixture's unparented Streamer fixes only that test cleanup. A Crystal-only
private continuation requires an **already admitted** Crystal region to cover
the shallow branch, without new anchors or probability/extent/depth overrides.
The fixed 2070-case survey has found its first normal positive at ordinal 336:
Quarry seed 1002, site (6,-2), physical depth 38.010 m. All cases continue in nine
fixed bounded batches; no missing/replaced negatives. This remains unadopted
pending actual Crystal geometry/traversal and the complete aggregate.

Latest complete runtime checkpoint **before rare emission**: `experiment_check_cave_live_crystal_return_1cf0cd7dc176`
preserves 134 verified copies after localized veins, corridor growth, bank chambers
and bounded shore-mesh refinement. All 153 checks pass: 27,394.567 m, all 5,006
waypoints, 396.008 m canonical depth, 0.038109 m maximum unsupported drop,
429.870 seconds motion under 650, 42.728 seconds preload under 180, 48 committed
cuts, two entrance exchanges, four TOTAL jobs, 185 peak cells, 1689.4 MiB sampled
private memory under 2048. The accelerated-run Jolt capacity warning remains
recorded, not fixed. Rendering is paused during movement; this is not uninterrupted
FPS or an isolated performance result.

Shore refinement uses the same canonical signed edges, twelve bounded bisections
only near opted-in bank lakes, and the original weld lattice. The 74-check adoption
(`experiment_check_cave_crystal_shore_adoption_3951d1d4d0ef`) is byte-exact to the
frozen private candidate, exact to the complete old mesher when disabled, and
matches all 244 internal cell-face segments with zero unmatched, open interior or
nonmanifold edges. Maximum checked scalar residual drops from 0.592496 m to
0.000930 m without changing the scalar primitives. Two failed diagnostic
comparisons are preserved; the final complete-pipeline private study passes 459
checks (`experiment_render_cave_crystal_shore_crossing_candidate_7788b21bc54d`).
The refined native lake then passes 434 checks and both original return walks
(`experiment_render_cave_crystal_lake_chamber_native_b0ea3b679aa7`, 827.7 MiB).
The old coarse shoreline screenshots below remain historical. Polygonal shore
silhouettes still need art review; numeric root accuracy is not art acceptance.

The actual-world scene index now covers 918 fixed cases, retaining every negative,
and identifies all six mineral families and all seven eligible host types. Six
native family inspections and the first amethyst geode have completed ordinary
connected return walks. These are generated scenes, not reference-art acceptance.
The index still has no actual depth-band-one Crystal chamber; graph tier numbers
must not be presented as physical depth bands.

Localized world-space exposure now breaks up the formerly continuous mineral
rings. The 70-check independent comparison retains every original crystal while
reducing 51 vein segments to 13 across the original geode/ravine samples
(`experiment_check_cave_crystal_vein_localization_a6ff32a3323e`). Bounded corridor
growth adds at most 24 forms within the existing total budget and leaves the
original passage volume intact. Its 69-check adoption and 446-check native
inspection include the actual mineral-bearing passage and same-way capsule return
(`experiment_check_cave_crystal_corridor_candidate_d5a2c07d7f76`,
`experiment_render_cave_crystal_corridor_native_971a60f6fca3`).

A low bank chamber now uses the existing cave field and retained water source.
The five original pool cases produce two positive complete-generator lakes under
the explicitly diagnostic lake frequency of one; saved normal frequency remains
0.12. The independent adoption comparison passes 89 checks, including exact
reference field/rock/water output and protected dry access
(`experiment_check_cave_crystal_lake_chamber_candidate_b0ce0d7df84a`). Its first
actual native lake completes the full dry perimeter and exact return: 131
waypoints, 146.113 m, maximum unsupported drop 0.038111 m, sampled private memory
832.1 MiB under the unchanged 2048 MiB cap
(`experiment_render_cave_crystal_lake_chamber_native_f36aa8726588`). Native images
still show angular shore strips; their geometry/material cause is under diagnosis.
The earlier unsuccessful lake-annex experiment remains unadopted and historical.

The latest full 27.4 km return archive `b956d48bda40` predates localization,
corridor growth and the bank chamber. It is not evidence for those later changes.
Current shared compatibility checks pass 299 compiled-field comparisons and 66
Frozen upload checks. All 31 shared surface regressions pass with guarded sources
unchanged. Crystal remains
active and unregistered; saved registry is Default+Frozen and root caves remain
disabled. Magma follows Crystal. Global art, cold-start/performance, shallow cave
coverage and outstanding surface approach work remain open. Other Godot sessions
are left running as requested; no isolated performance claim is made.

The subsequent request to finish the remaining work is being implemented directly in the existing checkout. **The full reference-quality acceptance criteria are not yet met.** The previous dated reports below are historical evidence, not a current completion claim.

## Live cave integration in progress (2026-10-25)

### Crystal Caverns active (2026-10-26)

Current continuation (2026-10-27): the latest31-script shared regression
passes again with every runtime/source guard unchanged,including the user's
concurrent character work. Other Godot sessions remain running as requested;
none of these observations establish isolated performance.

Latest floor-detail continuation: independently editable sediment strength(.38)
adds filtered mineral grain and broad depositional shading only to suitably dry,
upward-facing rock. Broken short clasts use measured floor fitting,whole buried
feet and existing mineral batches;at most16/cell INSIDE the original160-form
budget,AFTER major forms. They create no extra colliders/transmission.160 checks
over the fixed36seed/two-cell breadth retain8 positive clasts,0invalid attachments/
routes,exact existing major placement records and complete frozen independent
OFF/zero payload equality. Archive`experiment_check_cave_crystal_debris_3b27c088031e`
preserves12 copies. The original failed zero-fragment attempt is preserved in
`failed_diagnostic_check_cave_crystal_debris_0fb0c936fe40`;the tall-form airspace
rule was unsuitable for short partly embedded debris and has not been weakened
for ordinary crystals. Current six-family native suite passes77238checks/1382forms,
31.884m largest habit/58 clear forms/3 native batches and ordinary protected return,
archive`experiment_check_cave_crystal_features_dbbb50766e63`.

Actual first normal geode floor inspection passes426checks/15images,visible dust
ON/OFF and exact image restoration,232 crystals/29 veins,54.474m native return,
.038116m drop and889.8 sampled MiB under2048. Archive
`experiment_render_cave_crystal_first_normal_geode_sediment_e8743ddc3e72` preserves
196 copies. Its488-check original126-case occurrence certificate is
`experiment_check_cave_crystal_profile_occurrence_3414234f9567` (176 copies).
The inspection harness now ALSO guards all root terrain scripts and editable
root resources;the previous narrower archived source lists remain historical.
Its explicit scope/poisoned dependency/never-ready workshop checks pass,
archive`experiment_check_cave_inspection_scope_c689b754314e`.
All31shared tests pass again after floor detail. The full original live return
NOW PASSES149checks:27394.610m/all5006waypoints/396.007m depth/.038109m drop,
441.331s motion under650,49.475s preload under180,48committed cuts/two entrance
exchanges/four TOTAL jobs/184peak cells/1695.7sampled MiB under2048. Archive
`experiment_check_cave_live_crystal_return_b956d48bda40` preserves130 copies,
including the unchanged-source gates,all5 native images and the recurring Jolt
accelerated-run warning. It is not isolated/uninterrupted FPS or an engine-warning
fix;the other Godot sessions remain untouched. A fixed522-case normal scene descriptor index is being prepared
for actual family/level/profile/host/extent native inspections,not manual scenes.
Descriptors alone will not count as positive native geometry or artistic sign-off.

The private lake annex remains UNADOPTED:522 fixed normal cases(original126,
then396predeclared Crystal/Quarry cases,seeds1000..1032) retain ZERO large lakes
and all negatives,input immutability and bounds;archive
`experiment_check_cave_crystal_lake_annex_candidate_7b426a2b5a53` preserves52 copies.
The five original full-weight pools all miss the unchanged.12 large-lake channel
(actual values.781/.494/.311/.325/.475). This normal negative is distinct from
the controlled broad-host large-basin positive. No lake geometry policy was
changed merely to obtain a desired normal outcome.

Crystal transmission now selects a stable minority of eligible thin forms:
the first normal geode changes64/84 clear forms to22/84;281 checks establish
exact unchanged per-form geometry/contact/collider/UV/LOD data. Archive
`experiment_check_cave_crystal_profile_optics_a5a5850472b0` retains that phase.
Veins now reject surfaces belonging to neighboring chambers and project only
8cm from their measured wall;63 checks preserve all non-vein batches exactly
at that phase,archive`experiment_check_cave_crystal_vein_domains_ab86cb4d4e9a`.
Later dense geode growth deliberately changes the mineral population.

Dense inward growth adds232 crystals versus84 in the first normal geode,
with52 independently bounded,irregular attached mineral bases. The latest
68-check54-cell comparison retains32 bases/cell,160 original forms/cell and
the60000 total vertex gate (actual maximum14412);all roots,protected routes,
native collider accounting and cold repeats pass. Both lining AND spanning
off restore the frozen pre-lining payload exactly. Archive
`experiment_check_cave_crystal_geode_lining_4d52c1d38373` preserves53 copies.
The native geode return still completes54.474m with.038116m unsupported drop,
247checks/12images/836.6 sampled MiB under2048;archive
`experiment_render_cave_crystal_first_normal_geode_07b1a9904ab5`.
Images improve the repeated round bases,but are not reference-art acceptance.

True two-ended crystals reuse the existing four elongated habits/prototypes,
measure and bury EVERY near/far contact,check exposed long edges and the
complete protected-route bounds,and retain native colliders and far silhouettes.
Independent editable spanning switch/chance(.15) fall back to the exact original
ordinary form when unsuitable.132 checks include four17.817–20.352m attached
columns,38 generated spans in twelve explicitly forced breadth cases,complete
frozen off/zero controls and an ordinary206m same-route capsule return.
Archive`experiment_check_cave_crystal_spanning_27dd35fb2aae`;the controlled
native geometry-off/exact-image-return inspection passes108checks at791.1MiB.
Forced breadth is not a normal-world occurrence measurement.

The original126-case normal cohort remains52 admitted regions/40 candidates,
5geode lobes/25ravine lobes and ZERO large basins;archive
`experiment_check_cave_crystal_profile_occurrence_38781dffd28d` preserves92
copies. A private broad low lake-chamber candidate is being tested because
the retained small basin's steep surrounding host is usually unsuitable for
a larger dry perimeter. No rejected site is replaced or chance increased.
Pure surveys/preloaded mineral inspections explicitly exclude unrelated
blob_* character shader dependencies,record their hashes as observations and
detach BlobWorkshop only in the inspection instance before ready. All cave/
terrain dependencies stay guarded. Full production return/global31 guards
remain unchanged. Prior concurrent-source failures stay failed and archived.
Root caves remain false;the saved registry remains Default+Frozen. Crystal
is active,not fully accepted/registered;Magma remains next in the requested order.

HISTORICAL PRE-GROWTH FULL PRODUCTION RETURN PASSES all147checks,including every unchanged
source-stability guard:27394.573m/all5006waypoints,396.008m depth,
.038109m maximum unsupported drop,427.663s motion under650,48committed cuts
and two entrance exchanges. Four TOTAL terrain/cave jobs and the original
ordinary capsule/LOD6/main-scene/180spreload gates remain in place.
Sampled private memory1670.9MiB under2048. Archive
`experiment_check_cave_live_crystal_return_5319dfe2a489` preserves128verified
copies. It is accelerated/render-off movement with explicit loading pauses,
NOT uninterrupted FPS,isolated performance,reference art or all-user completion.
This pass supersedes the earlier failed source-stability attempt below;
that failed report remains untouched. A subsequent defensive dry-bank
water-level predicate has its own1664check regression,including36new
submerged-bank negatives;no physical floor/collider geometry changed.
Archive`experiment_check_cave_crystal_bank_admission_499a1a0d7896` retains
that pass and58faf5e487d3 retains the original failed freeboard negatives.
Current shared-field comparison passes296checks/28800scalar-normal-weight
probes/all80styles-signed-far-cap cases with0mismatches and full three-cell
native payload exactness;archiveb7b4a5a17c11. Frozen atomic upload/release/off
passes63checks;archived4a3b94691a1. No full-source proof is silently rebound
when a later optical-only refinement changes its guarded source text.

The production full route physically completed27394.611m/all5006waypoints,
396.007m depth/.038109m maximum drop in513.051s,48cuts/two entrance exchanges.
Its OVERALL source-stability gate nevertheless FAILED because the unrelated
`shaders/blob_organism.gdshader` changed during the run. No failure was
removed/reclassified. `unbound_failed_check_cave_live_crystal_return_8d4ff6c36b31`
retains130verified available files,original report/pixels/logs,and an
explicit unavailable-original-source entry for that shader;NO substitute
bytes or rebound hashes. The unchanged complete test is rerunning. No Blob
files were edited by this cave work. Current main scene hash is
`d7c91c247d644a31cfe347102fabea62c1611923bf6a633405b2fa9b83e45252`.

First actual normal-profile native checks now pass234and235checks/eight
images each:geode84crystals/41vein segments/54.474m return,and ravine
66crystals/14veins/42.463m return,both with.038116m maximum drop. Sampled
private memory826.1/821.4MiB under2048. The original126case cohort was
refreshed after unrelated shader edits with exactly the same403checks,
52admitted/40candidates/five geode lobes/25ravine lobes/no large basins;
archive2e19f9262609. Native images still show sparse forms and overly regular
joint bands;these physical/image-toggle tests are NOT reference-art sign-off.

The Jolt warning is a separate engine pool,not evidence that the four-job
terrain/cave limit was exceeded. The exact4.6.1-stable implementation has
fixed-size allocation,reclaim-on-exhaustion and post-step reclamation in
[JoltJobSystem](https://raw.githubusercontent.com/godotengine/godot/4.6.1-stable/modules/jolt_physics/spaces/jolt_job_system.cpp).
[Upstream issue110724](https://github.com/godotengine/godot/issues/110724)
now includes maintainer-confirmed accelerated/headless CPU-starvation
reproduction. Similarity to these accelerated runs is an inference,NOT a
local root-cause or fix claim. No engine swap,physics limit increase or
warning suppression was applied. Ordinary real-clock comparison remains
to be checked separately.

Connected-profile continuation:358checks and44native images now include
345.082m geode,300.248m ravine and212.810m enlarged-basin perimeter returns,
all under the ORIGINAL ordinary capsule gates with.038111m maximum drop.
Archive`experiment_check_cave_crystal_profiles_native_23bf4bd95049` preserves
137verified copies;807.1sampledMiB under2048. The basin uses a controlled
40m-radius/28m-low host within the unchanged128-bin primitive limit. Its
report's34m prose label is stale;the archived executable source uses40m.
The earlier40m/46m host failed compilation;the separate34m/28m ring climbed
the host wall and failed. Mineral-collider-off reproduced that failure
exactly,so no disabled collider was adopted. Those negative diagnostics
remain separate. Shore waypoints now measure actual native rock height.

Production large-basin admission consequently checks192dry-bank stations
against the existing actual SDF,headroom and a conservative.8normal-Y slope
margin BEFORE accepting enlargement. It never edits a floor to pass. A
finite walking annulus in the same compiled field excludes complete ordinary
formations and mineral bounds,not their colliders after upload. The
1628check/36seed test rejects all72old narrow/steep positives and retains
all36valid broad-host basins;archive1a97195a7231. Original controls-off and
cached inputs remain exact. The retained Jolt job-capacity warning is still
an outstanding shared-engine issue,not fixed by these returns.

The SAME original126normal host/seed/site cohort now passes403checks with
52admitted regions/40Crystal candidates unchanged,and five actual geode
lobes/25ravine lobes. Firsts are CrystalWastes73921/(6,-2),geode
`6:-2:2:0:crystal:geode:1` at263.814m depth,and CrystalWastes73921/(8,-4),
ravine`8:-4:2:2:crystal:ravine:0` at259.366m. Their complete27cell mineral
workers contain84and72real crystals respectively,within original cache
and numeric bounds. Archivee4c7f01ecf82 preserves92copies. No large basin
occurred in these126normal cases;controlled positives are not a normal-world
occurrence proof. Production full return and first normal-profile native
inspections are in progress. A concurrent unrelated BlobWorkshop addition
to main.tscn is retained untouched;the full run uses the actual current main
scene rather than restoring an older scene to hide it.

Current continuation supersedes the scheduler status in the historical notes
below. The exact private deep-cover scheduling experiment now PASSES the
original full return:27394.605m,all5006waypoints,396.007m canonical depth,
.038109m maximum unsupported drop and415.488s motion under the unchanged
650s limit. It retains the full six-level outdoor cut,48committed cuts,
two entrance exchanges and at most four TOTAL jobs. Sampled private memory
was1656.3MiB under2048. Archive
`experiment_check_cave_live_crystal_occluded_surface_c50478a29247` preserves
125verified copies. Fixed-fps/render-off movement and explicit loading
pauses are NOT uninterrupted FPS or an isolated benchmark. The four unrelated
Godot sessions were expressly left running at the user's request.

That exact finite-cover policy is now in normal production scheduling behind
the independent `retain_deep_surface_cut` switch. It only retains an already
committed outdoor cut when canonical cover exceeds96m and no required mouth
is nearby;explicit destination/teleport plans and near-surface travel bypass
it. No terrain meshes are hidden and no collider/LOD/player gate changes.
195checks cover180finite/boundary/enabled/required-mouth cases and actual
Streamer integration;archive78a962163619. A new production full-route run
is still required after this adoption and the connected geological profiles.

The production Crystal decorator now includes the independently tested
connected profile generator:two unequal geode lobes or three aligned tall
ravine lobes,each with real eight-metre-wide flat necks in the SAME graph.
Original routes/floors and Default/Frozen distances remain unchanged;new
Crystal distances follow the actual added edges. Each region adds at most
four rooms within the original pocket/numeric/cache limits. Covered-route,
retained-water,roof/depth and whole-footprint constraints reject unsafe
growth. Independent geode/ravine/large-retained-basin controls default to
.15/.08/.12. The exact private source passed3396checks over36fixed seeds,
72geode lobes/108ravine lobes/36controlled8–12m basins,plus normal and rare
actual-world bounded discovery. The latter two worlds contained zero large
basins;controlled positives are not being misrepresented as normal occurrence.
Production feature refresh passes65620checks/all six families/1363forms and
the ordinary protected-route return;archive7df6edffb6c6. Native connected
neck/basin/rendered and normal occurrence checks are in progress. Crystal
is still NOT registered;the root cave switch remains off. Magma follows
Crystal in the requested order;reference art and global acceptance remain open.

Earlier attempts (retained history): the full original Crystal return had not passed its
unchanged650s gate. After the physical cap-floor repair,attempt2 reached
18783.743m;the exact height-memo retry reached19885.529m/3641of5006waypoints,
396.007m canonical depth and.038109m maximum unsupported drop before650s.
Both are preserved FAILED diagnostics,not full returns. The latter is
`failed_diagnostic_check_cave_live_crystal_return_51225c0e066d`.

A separate streaming bug staged portals from XY proximity even when the
EXISTING traversal-readiness envelope said a walker deep below the exposed
mouth did not need them. Extraction and readiness now share that original
exposed-floor-minus-two-headrooms/3D256m predicate.180signed/boundary cases
retain all original readiness decisions and remove90unnecessary XY-only
staging positives. The unchanged27.4km original route is rerunning;terrain is
not hidden,player speed/physics and four TOTAL workers are unchanged.

That exact rerun improved to26048.059m/4751of5006waypoints,396.007mdepth,
.038109mdrop and only ONE entrance exchange instead of eleven,but still
timed out at650.001s. It remains FAILED,
`failed_diagnostic_check_cave_live_crystal_return_091af6c93c3f`.
A PRIVATE deep-only outdoor-plan deferral subsequently hit a physical block
at4787.895m/waypoint870 despite low unsupported drop;it is NOT adopted.
Original production overlying terrain scheduling remains unchanged. The
machine also has unrelated Godot test processes in another project;they are
left untouched and no timings here are isolated benchmark claims.

The original FIRST wet Crystal pool now has an actual native inspection:
86crystals/15veins and51.530m parent/neck/room return pass. A separately
declared full33station shore ring completes106.064m but crosses the real
retained feeder trench and drops1.603m,so that diagnostic FAILS the.75mgate.
Crystal-collider-off and Default-formation-density0 controls reproduce the
same route/drop exactly;the recorded location is the feeder crossing.
Those failures remain preserved;no site/route/physics were rerolled. The
user-required dry entrance connection is distinct from a360degree circuit
across an optional wet feeder. Both actual dry shore arms are being checked
against the full generated water-triangle footprint before any native walk,
not by deleting failed physics points. Native water-mesh positivity for the
EXACT selected pool is now an explicit check,not inferred from descriptors.
Earlier local debug rays could hit the test capsule itself;future diagnostic
profiles explicitly exclude it. Actual movement/return/drop metrics were
independent of those debug rays and are not changed/rebound.

The distinct true-dry inspection now passes215checks/eight native images at
the SAME first wet pool:51.530m original parent/room,82.439m one dry shore arm
and117.602m the other,with.038116/.038116/.178070m unsupported drops and exact
same-parent returns. All33original ring stations remain in the wet/dry mask;
indices6–8 intersect the ACTUAL generated feeder water,with.65m capsule
clearance and seven probes per segment. Native water positivity for the exact
pool passes. `experiment_render_cave_crystal_dry_shores_97de620ef765` preserves
98verified copies;827.3sampledMiB under2048. This is not the failed full wet
crossing reclassified as passed,not large-lake/scenic art or full streaming.
Actual local-axis growth transport also passes126checks over2578crystals,
222624vertices/1592angled-or-wall forms with0mismatches;UV2 carries physical
axis distance/patch phase rather than painting world-horizontal stripes.

The unadopted outdoor-plan study exposed a REAL shared loading bug,not a
changed cave floor:its captured contact is the upper-cell `CaveFrontiers`
body atX9600/Y-128 while all six face neighbours were already resident.
The capsule head reaches a diagonal cell before its centre crosses either
face. Production readiness now checks every requested cell in the COMPLETE
original2m margin (at most eight corner combinations),instead of only six
individual face neighbours. Cave geometry,colliders,player and margin remain
unchanged. A229check native reproduction includes192signed missing-cell
cases/96positive old false-readies;the original gate lets the real capsule
head hit the upper-forward frontier atZ64. Uploading the exact missing
diagonal releases it and the SAME route returns with.038111m drop. The fixed
original surface-entrance return and full private scheduler journey are
being rerun;the outdoor-plan policy itself remains private/unadopted.

Actual full-provider partial material overlap is now composed from each
provider's independent complete target and the original host remainder.
The earlier conditional-only pipeline failed partial frost/mineral coverage
by up to15RGB bytes. The45check/20image actual Crystal+Frozen GPU control,
including reversed provider order,now has1byte worst error. The earlier
37check pure-color fixture below remains scoped historical evidence.

Generated fluorite now retains cubic proportions and calcite broad skewed
cleavage proportions;transitions scale all dimensions uniformly. The editable
maximum height caps ordinary,giant AND secondary growth (old2m setting
incorrectly allowed7.976m). Same36seed/full-and-half-weight habit test now
passes2302checks/1238cubic/255calcite forms/max2.0m,
`experiment_check_cave_crystal_habits_c183a0f90e3a`. Corrected geometry passes
226850checks/3390forms/all6families/31.884mgiant and the ordinary206.501m
protected return,`experiment_check_cave_crystal_features_e758d6a2ad49`.
Subsequent material work adds modest filtered mineral inclusions,rare small
fluorite near transmission and crystal-axis-relative growth coordinates;
these are authored approximations,not photographed/scanned mineral data.
Native views still need artistic refinement;the2713check pre-fix habit failure
and earlier flat/blocky views remain preserved,not retroactively accepted.

Mesh phase diagnosis identifies unchanged six-sample normals as the largest
measured cell cost. A private case-table extractor was slower and was NOT
adopted. Immutable compiled primitive expressions retain exact Float64
arithmetic and add48numeric bytes/feature;source-frozen adoption control
`experiment_check_cave_compiled_field_adoption_043cddd6df6a` has80all-style,
signed/far/old-new-cap cases,28800scalar/normal/weight probes with0mismatches
and complete actual three-cell payload byte equality. Single-order timings
are noisy/modest,not a full-live or FPS improvement claim. Current31surface
regressions and full Crystal stage/registration remain to be refreshed.

Crystal's private definition now has the requested18percent chance,350–1500m
extent,5/20/50/80/100 depth preferences and exact surface-affinity table.
Desert remains dormant;Rocky Coast is sampled as its actual overlay,minus
beach coverage,not a new owner. Independent suitability admission implements
the requested product without a second Default lottery. Source-frozen
foundation experiment `dbce64aeee02` has113095 checks:9308/100000 eligible
anchors versus9360 expected;the actual rare2percent/1000–2000m5x5 worker has
25 regions/44253 field features within unchanged65536/32 feature/cache bounds.
Default/Frozen-only candidate geography remains exact against its accepted
pre-Crystal source. Normal definitions retain the original3x3 halo.

Per-fragment conditional composition retains raw interpolated UV/UV2 weights;
the37-check/15-image GPU test matches2/3/4-way reference blends within1RGB byte.
Both old raw sequential mixing and premature vertex division are live wrong
controls. Registered providers opt into this contract;single-biome source is
unchanged. Actual96-probe coastal suitability/cache-poison/off controls pass.

Worker features reuse the original surface prism library,with cave-only
measured complete feet,hard facets,region-coherent six-mineral families,
compatible secondary growth,giants,finite real joint beds,shared native
batches,selective large colliders,near-only thin optics/opaque far proxies and
native index LODs. Existing host PBR/procedural mineral optics provenance is
in `data/cave_crystal_material_sources.json`;no bitmap source was invented.
Initial native LOD rejection and pre-refinement sparse/plain art remain
preserved failures/development evidence,not final reference art.

The normal126-case cohort retains52 admitted graphs/40 Crystal candidates/five
Crystal retained pools. Its FIRST site is CrystalWastes73921/(6,-2),anchor
`6:-2:1:2:lobe:1` at134.274m depth;the initial current-density neighborhood has
17 actual crystal prisms and17 finite vein segments. Its actual136-check/eight
image inspection passes the original parent/neck/chamber45.647m ordinary
return. Controlled six-family277-check native inspection confirms actual index
LOD primitive reductions and selected thin/opaque counterfactual returns.
These preloaded scenes are not full streaming/FPS or photographic art proof.

The first full live journey failed at1872.873m BEFORE its Crystal destination.
All same-site feature-off/growth-off/Crystal-off controls reproduced the same
floor profile. A descending route segment extrapolated its old floor plane
past a valley into the next ascent,creating a native steep lip despite solved
20percent grades. This shared-core failure is preserved,not rerolled. Adjacent
solved grades now govern rounded caps,with an independent exact old mode.
The original failed nine-point stretch now passes105.556m ordinary returns
in all four modes (.005444m drop),while the old cap mode reproduces the exact
trap. A288-case/23621-check eight-geology/signed-world/rotation/peak/valley
ensemble has maximum.153mm scalar floor error under a predeclared2mm bound;
the original cap control has1.500m error in144 cases. Full original27.4km
134/260/360m Crystal journey is being rerun before the stage is accepted.

Biological ownership is now explicitly locked in local surface scalars,with a
32m generic-side fade and no geodesic propagation through a biological hub.
Both Insect/Hive boundary controls retain byte-identical physical rock meshes
and exact original biological shader/UV identity;ordinary connector returns
pass. Broader actual mixed-world/art/performance validation remains open.

Saved registry remains Default+Frozen;root cave activation is false. Crystal
registration,remaining scenic/material work,full current-source integration
and global performance/art acceptance are not complete. Magma follows Crystal
and is not yet implemented;its supplied3123-line brief has been fully read.

### Frozen Caverns implementation active (2026-10-26)

Latest registered checkpoint (supersedes the private/pending-registration states
below): `experiment_cave_frozen_components_checkpoint_7023bc5d9e40` preserves
305 verified copies,12 current component reports,96 images,208 source guards
and all31 shared regressions (2026-10-26T21:50:50Z). The saved registry now
contains Default and Frozen. The post-scalar-tie full live return is separately
preserved as `experiment_check_cave_live_frozen_return_8f633ac7684d`:
9.413km/all1702 waypoints,103 cuts/six entrance exchanges,.038111m maximum
drop,34.077s preload,290.502s accelerated/render-off/paused motion and1383.9
sampledMiB under2048. That full return predates only render-normal smoothing;
the65055-check/48-seed form ensemble proves unchanged complete collision
vertices with smoothing on/off. Current98-check/eight-image column/thin-ice
inspection and atomic upload checks are included in the component checkpoint.
Root cave activation remains false. Crystal Caverns is now the active next
phase;Magma follows it. Global reference-art/cold-start/performance acceptance
and all-user completion remain open. Later shared/Crystal edits do not rebind
these frozen source snapshots to changed code.

Latest continuation,which supersedes the early component states below:

- Frozen now enlarges only existing eligible retained basins to8–12m radii,
  subject to real protected-route/neighbor/roof/depth admission. Independent
  off/unassigned/unsafe controls preserve original complete region data. No
  random new water or second cave volume is created. Physical lake ice is.55m
  thick with.06m freeboard;the broad solid ice-shore deposit connects the dry
  chamber floor gradually instead of raising a floating platform to floor level.
- The original failed world shore return is repaired at the SAME fixed site.
  Current short actual-world inspection119checks/eight images passes84.727m
  parent/neck/stream-lake/shore return,maximum drop.038109m. The controlled9m
  radius lake/wallfall test passes9806checks/26436vertices/876buried samples,
  158.500m protected route and34.479m shore/lake returns. Waterfall outlines now
  taper irregularly,have measured curved ribbed surfaces and smooth normals;
  the initial rectangular panel is retained as development evidence,not final art.
- `experiment_check_cave_live_frozen_return_748c814e1e3b` freezes116copies of
  the first full live surface→Default→Frozen8m-radius stream/lake→same surface
  return:128checks,9413.126m,all1702waypoints,136.509m canonical local depth,
  .038111m maximum drop,103terrain cuts/six entrance exchanges,50.455s preload
  under180s,293.901s motion under420s,four TOTAL workers/four parallel portal
  jobs,146peak resident cells,and1484.3sampledMiB under2048. Fixed-fps60,
  render-off movement and93370explicit loading-pause frames are recorded,not
  uninterrupted/FPS proof. This full return PRECEDES the scalar tie repair below;
  it is not rebound to later source. Short current-source return above is separate.
- A dedicated intersecting-room test caught146material/formation scalar order
  mismatches,although its original physical field/mesh were exact. The initial
  first-feature tie choice is preserved in failed diagnosticd845d1867f64. Equal
  implicit minima now union specialized weights component-wise and normalize
  overlapping types;strictly closer geometry replaces them.310checks now have
  zero order mismatches,exact full original mesh and identical GPU control data.
  `experiment_check_cave_frozen_field_order_7e7e21b94d93` freezes that repair.
- Native phase90checks/60images,positive and negative3840/7680m wraps and6m,
  7.25m,.5m texture scales pass a predeclared2/255RGB bound (observed worst1).
  All12private old-macro controls visibly fail. Macro frequencies now divide the
  common3840m period;texture phase independently uses its editable repeat length.
  Both original ice and photographed frost OpenGL normal layers are sampled.
  `experiment_check_cave_frozen_phase_gpu_2a95a88434b9` freezes67copies;
  427.9sampledMiB under1536,not a GPU speed claim.
- Actual native parent/Frozen transport100checks/12images has ZERO observed
  depth0original byte error in both views,exact original/transported returns and
  positive depth12incoming-UV controls after original material decoding.
  `experiment_check_cave_frozen_entry_material_7ea83631ba47` freezes91copies;
  1190.5sampledMiB under2048. It is a controlled material injection,not a
  fabricated Snow surface or claim of a frozen mouth at those test coordinates.

The72case normal-settings cohort is refreshed on this source (25admitted,
threeFrozen,onewet;all negative sites retained). Full31surface regression refresh
is running. Provider contracts/finite controls and source-sensitive material cache
are tested. Rare column/thin-form breadth,post-repair full live confirmation,
saved-registry registration and remaining Frozen visual/performance acceptance
are still active. Root caves stay disabled;Crystal Caverns/Magma remain queued.

Frozen is now a private, provider-backed extension of the existing graph/field,
not a new terrain owner or cave engine. Its resource keeps45percent chance,
150–700m extent,100/80/40/5/0 depth preferences and Snow100/Mountain50/Wise25/
Forest5/Grass5 surface preferences. Snow remains dormant. The saved world
registry still contains only Default and root caves remain disabled.

Local four-channel surface controls preserve the original extracted positions,
normals and mineral colors. Existing CC0 Ice004(procedural PBR,not a photograph)
and Snow005(photogrammetry) are reused with cave-only native2K BC5 normals;
the compact two-layer banks total22,369,728compressed bytes. The first92check
material/three-image component is frozen in
`experiment_check_cave_frozen_surface_71d24dcb667c` (78copies,915sampledMiB under
1536). It was intentionally not accepted as finished art:its ice was too uniform.
Current coverage retains more original rock away from real retained water.

Numeric ice providers now generate measured,fully attached icicles/columns,
curved wall-following frozen waterfalls fed by existing basin geography,and
thick physical ice on actual retained water/streams. Features share the same
atomic cave-cell body/collision-off/disposal path. No extra worker pool,props,
ice-breaking,slippery movement,cold damage,particles or glowing ice were added.
The passing controlled2662check native component has three actual icicles,
one frozen waterfall,one thick lake,7056vertices/195buried contact samples and
ordinary158.500m protected-route plus20.427m shore/ice returns,maximum drop
.038111m. It is saved in
`experiment_check_cave_frozen_features_2587988c8f56` (77copies). Its runner uses
explicit--fixed-fps60 acceleration;109.6sampledMiB under1536 is not FPS proof.
Earlier failed overextended-basin fixtures remain preserved failures.

A fixed72case cohort (four current pure owners × three seeds × six original
geographic sites,normal regional activity.85) passes155checks:25admitted regions,
three normal-settings Frozen candidates and one frozen stream/basin. All
rejections remain recorded;these are not world-volume coverage percentages.
The first wet positive,Grass/seed17/region(9,-3),has a621.343m Frozen candidate
and real pool`9:-3:1:3:lobe:1:seepage`. Its first actual native render/walk
inspection produced real ice and eight images but FAILED at a small physical
shore lip. That119check failure and all pixels are retained in
`failed_diagnostic_render_cave_frozen_world_40c6aeed0128` (88copies).
The same original site/route is now being retested with a broad,solid,gently
sloped ice-shore deposit;no favorable replacement site or movement assistance.

Frozen world placement/rendering/clearance,all feature kinds at normal settings,
large lake/chamber variety,selective transmission,transition/entry streaming and
cost/regression checks are still in progress. Crystal Caverns and Magma remain
queued in that order. Full reference art/performance/all-user completion is not
claimed. Projection/deep-return reports below are historical hash-bound evidence,
not rerun or rebound to these new Frozen field/provider sources.

### GPU chunk-join projection correction in progress (2026-10-26)

The correction is now saved in
`experiment_cave_projection_checkpoint_a60f4e82ee3a`:307verified copies,six
current reports/125images and31refreshed shared regressions. Production/private
projection images match exactly in12original views;off restores every old
pixel/defect. The original actual Hive972.429m/154waypoint return passes115checks
with.038109m maximum drop,124.759s preload under180s,58.038s accelerated motion
under420s and1876.3sampledMiB under2048. Native roof/sun-off15controls,18atomic
transaction controls,71index/18image equality controls and40entry material
controls pass. Projection changes no native geometry or common numeric kernel;
the full24.736km physical dependency remains its explicitly historical frozen
source,not rebound to changed shaders. Root caves stay disabled for later phases.
Frozen Caverns implementation is the next ordered part of the Default/Frozen
brief;Crystal Caverns and Magma follow. Global art/performance acceptance remains
open. The following paragraphs retain the correction's development history.

The Default tour now retains four original geological room sites PLUS the
original first joined lobe and first pool,with positive3024/2016mineral-colored
vertices and1512actual water vertices. The initial12pose opaque geometry-mask
audit found nine views with1–25uncovered sky pixels despite the accepted native
closed topology/walks. That153check failure is preserved;not waved away as light
sparkles. A private shared camera-grid-relative projection removes every one
of those pixels in all12views without changing vertices,collision,camera,far
plane,resolution,lighting or sky.166checks/60images passed that private source.
The same projection is now being integrated into cave rock,Hive,temporary
frontiers,water,entry replacements and actively cut parent shader COPIES only.
The original global terrain shader remains untouched. The independent off path
retains original projection arithmetic. Native compile preflight passes;
full production/private/off pixel controls and entrance integration are active.
Earlier31terrain/deep-return passes below refer to their exact PRE-projection
source snapshots;not silently relabelled current shader acceptance.

The118check deep-return artifact's original engine-mode boolean was incorrect:
Godot removes recognized engine arguments from OS.get_cmdline_args(). The
unchanged authoritative runner receipt records--fixed-fps60. Audit
`experiment_cave_engine_mode_metadata_audit_60f00f579eec` preserves the mismatch
and correction without rewriting the old report. Future fixtures read a
child-only marker derived from exact runner arguments;both normal/60fps marker
controls pass. That deep return remains explicitly accelerated,not FPS proof.

### Ordered biological continuation (2026-10-26)

`experiment_insect_construction_profile_adoption_834dd3309956` preserves173
verified copies for the default-on independent mound construction profile.
It keeps every old elevation,foot,summit,vent opening and dome shape,with no
additional triangles/textures/materials. Unequal long ribs soften the old
regular horizontal rippling. False restores complete frozen old geometry.
Eighteen fixed morphology controls,36registered primitive pairs/whole-root
triplets,nine cold actual numeric worker pairs/main-thread native shape checks,
15same-scene images and31shared terrain checks pass. An initial parent/child
world-space identity failure is preserved;world-space interpolation now passes
that648587-check integration suite. Added generation cost,not a speedup. The
image study freezes visible waterTIME only in private material copies,not the
game. Broad final reference art/uninterrupted performance acceptance is open.

Alien interiors are now being connected in the same graph/field:the original
fixed(-31,-31)region has19nodes,two narrower nerve branches and six joined
unequal core lobes. Both150.4m/150.5m branch returns and a68.2m core-lobe return
pass actual native collision,.03812m maximum drop. Organic folds enlarge walls
by at most.65m inside the existing crossing reserve;dry floors never move.
Original29704component checks pass after a Hive-only2m extra planning reserve;
the initial three lateral depth-margin failures remain preserved. The actual
solved core point replaces any assumption of a worldY-900 underground organ.
Surface-only descriptors do not claim loaded traversable geometry. Organic
materials reuse the existing generated biological color bank;they are not new
measured PBR scans. The original full live breach return now passes85checks:
972.432m/all154waypoints,11terrain cuts,two entrance exchanges,zero initial
overlaps and.038109m maximum drop;237.635s motion under the original420s gate.
`experiment_check_cave_live_hive_return_a4c4de3ac7e6` preserves77copies. Initial
shader-scope,missing stored style-value and startup-memory failures remain
preserved. The memory repair reuses the existing biological sample rather than
compiling a second tissue evaluation in the entry shader;no resolution,view
distance,route gate or2048MiB cap was lowered. The old console peak observation
was not retained,so no exact sampled peak is asserted for that live run.
The original core also passes99native render checks/15images/12cells/63534
triangles. Actual original fine-parent entry shading passes the unchanged
2/255 maximum full-image rounding bound,with exact counterfactual returns;
sampled862.2MiB under2048MiB. These remain scoped,paused/accelerated and preloaded
controls,not uninterrupted real-time performance or final art sign-off.
The unloaded-end sky leak now has default-on temporary rock frontiers inside
the opt-in cave system. Original canonical meshes/graph stay byte-identical;
all6faces use the original tetrahedral diagonals,Float32 samples and1/4096m
crossings. Matching collision opens reciprocally only after neighbour upload
and restores before eviction. Outdoor portal air is excluded. The two-cell
closed-manifold/native return test passes342checks/14304paired edges/190.5m.
Three actual Spore/Insect/Alien worker controls pass43checks,with exact full
geometry/cap/off-mode outputs and zero extra6534face-sample calls after reusing
the existing mesh lattice. Actual original core119checks/24images include
768native escape rays and unsealed/sealed/repeat image controls.
An engine-fast-forward live run initially hit a queued-neighbour closure;
that failed run is retained. Two-metre approaching-seam readiness fixes this
without changing the capsule or route. Accelerated fixed-fps return now passes
972.429m;the separate WITHOUT-engine-fast-forward original-route repeat passes
972.432m/all154waypoints/.038109m drop/216.643s under420s,with1534.1MiB sampled
private memory under2048MiB. Both still use render-off motion/explicit preload
pauses,not uninterrupted rendering/FPS acceptance. Insect compatibility is
being refreshed separately. Root caves remain disabled pending later phases.
No whole-Alien/later-biome or all-requested completion is claimed.

### Default graph-biome framework continuation (2026-10-26)

The native editable `default_cave_definition.tres` and `cave_biome_regions.tres`
now supply independent spawn chance,extent,five depth preferences,blended
surface preferences,geological preferences,optional environment channels,
priority,transition and future material/geometry/feature configuration fields.
Only Default is registered:100percent,200–1200m,100/85/65/40/15depth preferences.
No Frozen/Crystal Caverns/Magma implementation is implied by this schema.
Depth anchors come from editable0/40/100/180/280/400m local-surface bands and
interpolate smoothly. Unknown surface names stay dormant;Snow is not activated
or assigned a fabricated owner ID. Existing biological interiors stay locked.
Separate deterministic SHA256 chance/extent/competition channels prevent rare
regions shrinking or chunk/LOD scheduling changing random geography. Growth
uses actual bounded graph distances,including partial long edges,not spheres
or per-triangle lotteries. The current3x3discovery supports configured extent
through1536m;larger definitions fail validation until the halo is expanded.
Original node/edge input order initially changed serialized distance-map order;
the failed report is preserved and canonical sorting repairs it.
10742checks now pass,including10000independent rare1500m proposals(194accepted,
not a world-volume percentage),200seed competition/order controls,native
ResourceSaver roundtrip and actual original Spore graph/mesh bytes unchanged
apart from positive32candidate metadata. The in-game debug label now exposes
cave loading and accepted region counts/extents. All31current-source shared
terrain checks pass. The original full deepest return now PASSES118checks:
24736.150m/all4558waypoints,378.410m canonical local depth,268terrain cuts,
14entrance exchanges,zero initial overlaps and zero unsupported drop. Motion
627.465s stays under the unchanged650s gate;sampled private1707.4MiB stays under
2048MiB. Four TOTAL workers and the original180s preload gate remain unchanged.
This includes the registered Default metadata and temporary frontier closures.
Engine fixed-fps acceleration,render-off movement and explicit loading pauses
are recorded,not relabelled uninterrupted real-time/FPS acceptance. Real Default
room visual inspection is in progress before later biome implementation.

The original Insect main return has now PASSED after the exact-payload memory
repair:79checks,1,300.022m/all210waypoints,15terrain cuts,twoentrance changes,
zero initial overlaps,.038109m maximum unsupported drop. Motion283.779s stays
inside the unchanged420s gate;initial preload stays inside180s. Sampled private
memory1582.8MiB under the unchanged2048MiB cap. Both satellite native returns
also pass on this source. `experiment_cave_insect_excavation_checkpoint_843f87fdba58`
preserves190verified copies,eight passed reports and31shared terrain checks.
This is a scoped excavation checkpoint with explicit loading pauses/render-off
accelerated motion,not full art,uninterrupted FPS or all-requested completion.
The following failure/prototype descriptions retain the repair's history.

Insect interiors now use the same constrained graph/SDF,with wider compacted
earth main routes,enlarged excavation chambers and narrower satellite branches.
The original fixed region(7,-2) retains a real19-node/22-edge exit-rooted graph;
both satellite native return walks pass about142.5m each with.0382m maximum
drop. This does not yet certify the complete main entrance return or full art.

Three complete-main-route attempts were interrupted at the unchanged2048MiB
watchdog cap,including a normally rendered diagnostic. Their incomplete logs,
images and exact source are preserved as failures,not passed returns. The
rendered diagnostic exposed a CPU result-staging spike during mouth rebuilding.
Render-only exact indexing now shares bit-identical position/normal/color
records without changing collision triangles. Production controls pass71checks
and18pixel-identical images;actual original Insect/Spore aperture extraction
passes53checks with every expanded vertex/normal/color/68-float material value,
collision face,water record and parent cut exact. Insect aperture atlas bytes
fall6,684,672→1,163,264;Spore7,143,424→1,245,184. These payload counts are not
process-memory savings or full-route acceptance. Uploaded CPU staging data is
released after native resources own it. The original interrupted route is now
being rerun with the same route/capsule/time/resource gates.

The later geological revision now also passes the ORIGINAL full live deep
return:82checks,24,736.266m/4,558waypoints,378.409m maximum canonical local
depth,268terrain cuts,14entrance transaction changes,zero unsupported drop.
Initial preload79.780s;motion642.749s under unchanged180s/650s gates. Sampled
private memory2038.5MiB under2048MiB (500ms samples):very small time/resource
margins,NOT broad performance acceptance. Peak resident cells135 includes
complete/protected safety cells beyond the128selected-target bound.
Current source-specific `experiment_cave_default_geology_checkpoint_e5ba36ce27a1`
preserves230verified copies,ninepassed reports and31shared terrain regressions.
It supersedes the foundation-only checkpoint below for these geological
features,not for all-world art/LOD or full user-task completion. Caves remain
disabled by default. Work continues with Insect integration before Alien and
the later requested cave biomes;no later cave phase has been skipped ahead.

Default geology has subsequently been connected (still opt-in). Canonical
unequal chamber lobes have explicit flat8m-wide necks;conservative room/bed/
channel guards protect neighboring links. Actual original3x3Spore field has
61lobes and4retained pools;the native new-chamber return passes. Geological
cross-sections now change real geometry rather than only tint:1,365control
checks and six ordinary-capsule returns pass,while original style0 arrays
remain exact. Complete mineral feet are measured and buried in real rock;
joined columns,broad flowstone and supported breakdown deposits are collidable.
Current fixed ensemble has57forms/fourcolumns,854native foot contacts and
zero floating feet (minimum embedding.300m). These are component controls,
not all-world or reference-art sign-off.

Retained water uses measured beds and one bounded clipped surface per pool,
including occasional shallow feeder channels. Three predeclared dense soluble
controls pass59,714checks:12pools,fivechannels,17,913water vertices,4,979flow
vertices,native bed rays and independent protected dry-route clearance. The
actual original-world feeder GPU view passes184checks,with natural/separately
labelled temporary debug lighting and a water-hidden negative. A nonlinear
shoreline interpolation failure is retained in failed diagnostic321090db1632;
the corrected extractor bisects the real field at the original35mm margin.

The cave palette reuses eight different existing photographed color/roughness
sources and packs cave-only2Knormal maps from their verified original files.
Seven raw normals are2048square;Rock055is2048x1024,resampled to match its
existing square color packing without claiming new source detail. Existing
1Ksurface normals remain untouched. Combined compressed cave arrays89,478,912
bytes;GPU base-level color/roughness/normal readback errors stay below.02.
No new scans or runtime downloads. Full deep-return/shared compatibility
acceptance subsequently passed for this geological revision above;the older
foundation return below predates these additions. Default full phase,Insect/
Alien full interiors,remaining surface art and later cave biomes remain open.

The current dependency checkpoint is preserved as
`experiment_cave_live_foundation_checkpoint_71407b32d033` (183 verified copies).
The original full main-scene surface/deepest-chamber/same-surface return now
PASSES: 24,736.16m,4,558waypoints,268terrain cuts,378.410m maximum canonical
local depth,zero initial overlaps and zero unsupported drop. Motion wall time
597.765s stays inside the unchanged650s gate;initial preload52.398s stays
inside180s. Terrain and cave jobs share four TOTAL slots;parallel portal jobs
actually reach four. Sampled private memory1844.3MiB under2048MiB. Movement
uses accelerated physics with explicit loading pauses and rendering disabled
only during motion: NOT uninterrupted real-time/FPS or whole-world acceptance.
Natural chamber and separately labelled temporary debug-light captures are
preserved. The latest approach/return captures are NOT byte-identical.
All16checkpoint component reports and the31shared terrain tests pass for
that saved source. Later changes below require their own acceptance.

The shared dependency now exists in `scripts/caves/` and is connected to actual
`ChunkTerrain` jobs, terrain materials, tile selection and native collision.
It remains opt-in (`cave_settings.tres` is disabled), not a completed cave phase.
Complete bounded entrance patches reserve sufficient neighboring terrain detail;
old ground stays intact until a hidden replacement is complete. The cave and
terrain workloads share four TOTAL worker slots, not four slots each.

The original Spore seed73921/cell(9,-3) live-main-scene entrance test completed
822.754m/130waypoints,11 terrain cuts,zero initial capsule overlaps and zero
unsupported drop. Approach and return images were byte-identical. That specific
source is preserved in the `experiment_check_cave_live_portal` revision; it is
not a current all-world or deepest-cave certificate. A separate occupied-mouth
5km/-3km pending-teleport/return test retains old support until arrival,releases
the old patch,and rebuilds the open destination before moving the target.
Its64checks pass in `experiment_check_cave_live_lifecycle_c9be9d055d4a`.
Both tests keep the original180s preload gates,1.8m/.4m capsule,5m/s speed,
45degree floor limit and.75m drop limit. A disabled-mode typed-array startup
failure was corrected;all31shared terrain checks passed at that compatibility
revision. Later cave-only changes require their own complete source refresh.

Default calcite growth is now worker-generated and collidable,rooted in measured
solid/air boundaries,limited to soluble rock and excluded from protected graph
passages.12,902geometry/ownership checks pass;the original actual first chamber
adds one336-triangle formation in the nine-cell worker study,with40checks and
exact complete zero-density restoration. This is a first geological layer,
not full Default cave art,large-chamber variety,water or a completed biome.
The much longer live surface/deepest-chamber/return test subsequently passed above;
Jolt's pre-existing maximum-job warning still occurs. No general performance
gain or uninterrupted-streaming claim is made. Insect/Alien full interiors and
remaining surface scope are unfinished;Frozen,Crystal Caverns and Magma Caverns
have not been implemented and retain their strict order.

The first complete live deepest-return attempt exceeded its650s motion gate
after10,473m/114cuts without an unsupported drop. Avoiding unrelated surface
extraction for buried cells and uniform-cube temporary allocations preserves
the compared complete buried-cell arrays. The next same-route attempt reached
24,692.9m/271cuts but FAILED at the final mouth reload with11.899m unsupported
drop. That failure remains preserved;it is not a successful deep return.
Ordinary cells now retain a real6m temporary rock seal until the full portal
transaction is ready,and `traversal_ready` exposes that loading requirement.
An actual native sealed/open same-route test passes11checks. The original
full return subsequently passed the same650s motion/.75m drop gates above.

Inward cave faces now cast double-sided roof shadows. Actual native closed-room
GPU controls pass15checks:mean luminance no-shadow negative.54925,roof.06102,
sun-off.05927. The Compatibility ambient shelter term is an approximation,
not GI or a substitute for geometry. The main sun/sky/fog are unchanged.
Deep-test debug illumination is separately labelled and not installed as a
gameplay lighting/inventory system. Canonical joined chamber-profile growth
passes2,793component checks/46lobes but is NOT yet connected to production
generation. No later cave biome is started by these dependency changes.

## Registered Insect earth material (2026-10-24 UTC)

Independent default-on `nest_earth_material` uses the existing photographed
warm red-soil bank for Insect supplemental mounds. It adds filtered authored
6 mm / 35 mm apparent clay relief, subdued broad coloration and roughness,
with a tangent surface-gradient guard and signed common 3840 m phase.
False selects the complete original structure shader. No new texture, geometry,
vent, foundation, water, atlas or collider data is introduced or changed.
This is an existing photographed soil analogue, not a measured termite-clay scan.

16 saved-control/frozen-shader checks, 49,158 actual production GPU phase checks,
133 checks over nine alternating cold worker pairs at three original dry roots,
all 31 shared tests, 18 actual configured full-LOD6/four-worker native images
and ten actual-root normal-control images pass. Every whole numeric cut payload
is exact across the Resource setting. Normal-zero/geometric and physical
normal-off/zero errors are both zero in the two close controls. The private
predecessor separately preserves six strict same-scene original-image returns.
Actual cold-scene pixel differences are reported, not certified exact.

All three original geographic views remain, along with the original shadowed
close view, a separate sun-facing view (still shadowed), and a separate native
2000 m sun-ray-clear view. That ray is not a photometric/GPU shadow guarantee.
The sun, sky and fog are unchanged; visible water uses TIME0 only in private
comparison duplicates. The first canvas-only GPU harness failed due to a
missing spatial shader constant and is preserved as failed diagnostic
`91c3801348f9`; the corrected noise-only harness supplies that constant explicitly.
Worker median on/off ratio is 0.99615; native GPU block medians are in
`data/insect_earth_material_adoption.json`. All timings are non-isolated,
single native phase order, not a repeatable speedup or whole-world guarantee.
Production checkpoint `experiment_insect_earth_material_adoption_0108d0613e04`
preserves 164 verified copies / 29 images. Private accepted trial
`experiment_insect_earth_trial_6eec1813dcd5` preserves
152 copies / 29 images. Broader silhouettes/ground/scenic art remain under
review; no cave system is installed by this material change.

The shared underground dependency now has production-namespace core modules
under `scripts/caves/`, but `cave_settings.tres` remains disabled and the live
terrain loader is not yet connected. This is not an installed cave system.
The original actual Spore entrance now passes its 823 m surface/cave/surface
native capsule return with no unsupported drop. Its earlier 7.32 m drop was
caused by overlapping access/descent air removing the ramp floor, not a missing
collider. Flat chamber joins, bounded canonical descent alternatives and
continued segment floor planes repair it without moving the entrance.

The original 11.8 km underground return passes with 0.03811 m maximum unsupported
drop. Over 227 selected cells, 397,830 triangles and 597,137 exact global edges
have zero interior open edges, zero nonmanifold edges and zero inconsistent
winding. The 784 single edges lie only on the declared preload-set exterior.
An intermediate welded-gradient orientation still had six inconsistent edges;
the final pre-weld tetrahedral sign-case orientation repairs them. Failed exact
equivalence and intermediate topology reports remain preserved; this is an
intentional winding repair, not an exact-output optimization claim. The native
Jolt job-capacity warning still occurs. These tests preload cells; they are not
uninterrupted live streaming or every-world traversal certificates.

Surface replacement now has decoded-before-interpolation material transport:
67 semantic values in 17 RGBAF texels per vertex, including native RGBA8 upload
truncation, signed nested controls, water and curvature. 75,191 CPU checks and
six native GPU panels pass, including 128 deliberately corrupted controls. The
full original material fragment code is retained. Surface subtraction/commit
primitives pass real native rays, unaligned-grid clipping, preparation without
mutation, stale-parent rejection, successive cuts and exact original collider
RID/transform restoration. Worker discovery independently compiles nine regions
and their connections with 29,711 features. These components still need actual
ChunkTerrain scheduling, complete live entrance transactions and sparse loading.
No Frozen, Crystal or Magma cave implementation has started; their order remains
Default/shared foundation, Frozen, Crystal, then Magma.

## Registered spatial structure collision (2026-10-24 UTC)

Independent default-on `ChunkTerrain.spatial_structure_collision` builds an
immutable worker-side index over contiguous original 64-triangle blocks.
Conservative cell coverage includes a complete 256 m cell plus a 600 m guard;
six original extremal blocks retain native whole-mesh quantization bounds.
No artificial triangles, visible geometry, terrain, water or materials change.
The original full faces remain in the payload. Missing/stale metadata, invalid
query coordinates or the disabled switch use the complete original collider.
Refreshes run independently of pending terrain cuts. They replace only the
structure shape, retain active ground/cavity collision, and leave hidden staged
replacements inactive until commit. Pending teleports protect the actual player.

73 lifecycle/registration checks, 11,808 dense numeric/native checks, all 31
shared terrain tests, the unchanged 480 m streamed fibre return and all three
240 m junction returns pass. The fibre route crosses five cuts and four subset
cells with maximum unsupported drop 0.01361 m. The dense original 363,736
triangles become 13,120, with 166 exact matching native contact positions and
normals. Numeric metadata is 174,828 bytes, excluding object overhead. One
non-isolated observation: index build 170.732 ms, selection 0.695 ms, original/
subset native setup including three fixed physics frames 688.345/20.814 ms.
These are not repeated end-to-end speedup or universal frame/resource promises.
Routes use the existing preload pauses and accelerated fixed 60 Hz simulation.
The unchanged capsule is 1.8 m tall, radius 0.4 m, speed 5 m/s, slope limit 45°.
Historical unsafe approaches and the Jolt job-capacity warning are not repaired
by this optimization. A private first version shifted native normals; only the
bounds-preserving version was adopted. The corrected synthetic fixture exits
without the initial self-referenced test-mesh resource leak.

`data/structure_collision_index_adoption.json` and checkpoint
`experiment_structure_collision_index_adoption_91222f974382` preserve 134
verified copies. Private predecessor: `experiment_collision_index_trial_6220158c347a`.
Surface reference art and all ordered cave phases remain unfinished.

## Registered thickness-aware Crystal material

Independent default-on `crystal_bulk_material` carries actual minimum prism
cross-section, mineral habit and growth position to a six-family material.
Massive crystals are mostly opaque; thinner blades and smaller mineral sections
retain limited filtered transmission. Mineral IOR/Fresnel, restrained growth
zoning and depth writes replace universal glass-like giant formations. This is
an authored Beer-Lambert/screen-refraction approximation, not measured PBR scans
or ray-traced internal thickness. No new texture, atlas, triangles, displacement,
collision, terrain/water field or lighting change. False restores both the old
complete UV arrays and the original shader; grounded roots stay independent.

Acceptance includes140 registration checks,101035 GPU/metadata checks including
49152 independent absorption samples, all31 shared tests, and36 actual configured
four-worker cuts/54 images. There are18 labelled view cases/17 distinct poses:
twelve original geographic views plus six separately pre-admitted positive
mineral-root cases (the mineral-basin positive overlaps its geographic pose).
All six actual positive GPU habits and live shader bindings are checked. Physical
arrays and complete worker collision bytes are exact. Original cold-scene cut
arrays return exactly; cross-cold-scene pixels are reported, not called exact.
The frozen private accepted shader additionally has18 strict same-scene returns.

Non-isolated GPU mean block medians are ground3.764→4.136ms and medium4.312→4.618ms;
presentation remains about16.67ms. Nine non-isolated cold worker pairs have
median on/off1.00074, not an isolated gain. Sampled native peak1055.4MiB under
4096MiB, GPU reference313.5MiB under1536MiB and worker84.8MiB under1024MiB.
Checkpoint `experiment_crystal_bulk_adoption_414d38770f8d` preserves188copies/
55images. The private image studies freeze visible animated water atTIME0 in
duplicates only; production time/animation is unchanged. The original live-time
image-return failure and bounded9x9 smoky-root admission failure are retained;
the separate33x33 positive search was fixed before viewing the material.
Whole-surface reference art, streaming/cold-start work and ordered caves remain
unfinished. The other open Godot session was left untouched.

## Registered Crystal Wastes foundations (2026-10-23 UTC)

`crystal_grounded_roots` independently extends only existing crystal bottom
rings beneath the supported terrain-LOD chords. No extra triangles or changed
crown/footprint/terrain/water fields. False restores complete frozen original
arrays. Six-habit broken/intact checks, three actual complete-root off/on/off
triplets, unrelated Insect/Alien controls, actual runtime-selected contact cuts,
nine native fullLOD6 four-worker images and all31 shared tests pass. At the
original seed73921 crystal root, four feet were above actual selected terrain:
up to4.47m at the4096m camera offset and17.26m at8192/16384m. All12 observations
now have buried feet. The private Insect extension was NOT adopted because its
frozen sites did not show gaps on the terrain actually selected by the runtime.

Checkpoint `experiment_crystal_root_adoption_b8fe49037726` preserves142copies/
nine images. Native peak1022.8MiB under4096MiB; nine cold actual worker pipeline
pairs have median on/off1.0194, not a speedup. This timing is NON-ISOLATED: an
open Godot session caused the isolation gate to refuse; it was left untouched.
Initial non-admitted fixture and scoped-variable parse failures are retained,
not passing results. Cross-cold-scene image bytes are not certified exact.
Whole-biome material/art acceptance and ordered cave work remain unfinished.

The older seven-point context ray audit is also corrected and preserved at
`experiment_diagnose_tissue_flow_contacts_scaled_f38b18c0b106`: all seven original
pixels now agree with independent GPU terrain/shell IDs, with later shoulder
and variation settings disabled to isolate the original study. This closes the
coordinate-attribution audit, not the separate four-pixel depth-intersection
equivalence limitation or overall artistic acceptance.

## Registered ground-guided conduit shoulders (2026-10-23 UTC)

Independent `hive_grounded_shoulders` follows canonical support across near and
retained-contact far profiles, with compact ground lips. Small branches and
protected cavity approaches retain their prior shape. No new vertices, textures,
atlases, terrain or water fields. False restores complete frozen prior arrays;
true matches the preserved accepted trial. Both bounded memo classes propagate
and namespace the setting.

Current-source checks cover complete geometry, memo invalidation, six actual
worker payload/reference pairs, 48 native images, original fibre/junction
streamed returns and all 31 shared surface regressions. Two original positive
320m routes and an explicitly additional local 120m route pass unchanged capsule
limits. The original weak-intervention site and the additional site's longer
baseline-unsafe approach remain failures, not replaced passing cases. Four
same-scene one-root image returns are exact; cross-cold-scene pixels are not
certified exact. Actual full-worker median on/off ratio1.030 is added work.
Checkpoint `experiment_grounded_conduit_adoption_01a831638aa7` preserves
215verified copies/48images. This is not CSG union, whole-world artistic or
traversal acceptance, a cold-start performance fix, or completion of cave work.

## Registered nerve-material variation (2026-10-23 UTC)

`nerve_material_variation` is independently default-on in configured worlds.
It retains actual hive-path alignment while blending mirrored source offsets
and a small continuous growth strain. Its analytic Jacobian never folds in the
8192-probe study; maximum longitudinal deflection is5.662degrees. No new source
image,atlas,physical displacement,lighting change or global projection period
is introduced. The first mirror-only trial failed the original repeat threshold
and is preserved as failed. The accepted strain trial passes the SAME threshold
at1.5/3/6/12m offsets across positive/negative coordinate domains.

Current acceptance:31 saved-control/complete-payload checks across nine actual
pure/overlay/unrelated-owner pairs,32774 strain checks,5466 refreshed path-map
checks,nine enabled child/rectangular-parent GPU panels,twelve original frozen
native views with60 original/off/on/off/original images,two actual configured
nine-root controller cuts,and all31 shared terrain tests. Original variation-off
sampling still matches the frozen four-sample helper exactly in nine GPU panels;
all24 original four-layer projection cases pass. Checkpoint
`experiment_tissue_variation_adoption_8ceb1fbfe9a3` preserves218guards/121images/
341verified copies. Earlier failed fixture assumptions and clean replacements
are explicitly retained;they are not silently counted as passing tests.

Matched production-uniform GPU block medians at one cut are near4.847→4.973ms,
context5.928→6.573ms and ground5.045→5.675ms. This is added material work,not a
speedup or universal frame guarantee;wall presentation remains about16.67ms.
Sampled native peaks1068.1MiB pure/1047.1MiB overlay and980.6MiB profile are under
separately declared4096MiB caps,not passes of old2GiB cold-compilation gates.
This improves repeated motifs;it does not close broad ground/organic contact
appearance,reference-quality whole-surface art or the queued cave phases.

### Screen-ray diagnostic audit

The remaining ground-boundary investigation exposed a test-coordinate defect:
the project's960x540 raster still uses1280x720 logical camera coordinates under
the unchanged `canvas_items` stretch setting. Passing image pixels directly to
camera rays misattributes surfaces. Three known GPU quad centroids independently
validate the scale conversion (zero centroid error;unscaled controls miss123–240
pixels). Corrected rays at the unchanged seed17 ground view agree with independent
red/green actual terrain/shell GPU IDs at all nine sampled points,with at most0.83
pixel reprojection error from distant world-coordinate rounding. Checkpoint
`experiment_ground_boundary_projection_25cb24b5ed7b` preserves144 verified copies.
The first unscaled report is separately FAILED (`495c45fcdfc3`,133 copies),not
causal evidence of a void. This is a diagnostic correction,not a terrain fix.

Older960x540 `diagnose_tissue_flow_contacts.gd` ray attributions likewise are not
certified until refreshed with conversion. Its image-only seven-point derivative
counterfactual does not use those rays and remains separate evidence. The older
1280x720 `probe_conduit_join.gd` fixture has equal logical/raster dimensions and
is not affected by this particular mismatch;its separate contact limitations
are not repaired by this audit. See `data/raster_diagnostic_audit.json`.

## Registered hive-directed tissue coordinates (2026-10-23 UTC)

Alien nerve tissue now has independently switchable finite-path coordinates
from the actual seeded hive graph,with junction/competing-path/bend fades.
Terrain and entire root-owned shells have separate numeric RGBA32F rectangles
over the same field;each is capped at129x129 records. An owned shell can extend
kilometres beyond its root tile:the initial shared-tile assumption was rejected,
not called a valid shell-domain proof. All actual geometry/water/ownership and
collision arrays remain unchanged. Structure-material debug updates now reach
active,staged and cached per-tile clones,without mixing them into terrain-only
uniform reloads.

Native review exposed single-pixel streaks from taking GPU derivatives of
piecewise reconstructed UV groups. The analytic normalized-bilinear Jacobian
uses the caller's small local-position derivatives instead. At the unchanged
seed17/context camera,all seven original dark points have zero measured local
dip;holding only the old derivative method restores0.13477–0.19529 dips at all
seven. The original failed negative control did not retain its include Resource
through scene loading;that failure is preserved separately. The corrected held
control and all captures are preserved in
`experiment_check_tissue_derivative_control_5e68df65f0b2` (41 copies),before
default enablement/current-source refresh.

The prior full-bounds revision passed31 shared tests,5466 transport checks,
28 lifecycle checks,rectangular child/parent GPU tests and27 actual native
off/on/off views,including ground views,with complete-cut geometry equality and
worker-map GPU readback. Its source/images are preserved in
`experiment_render_alien_tissue_flow_fc1f200ac1af` (138 copies). Frozen map
construction versus the lower-allocation implementation passes27 byte-exact
comparisons across three seeds,min/default/max scales and square/rectangular
domains;the latest median map-only time ratio is0.733,not an overall frame gain.
Skipping empty sampler groups also passes all bytes in nine actual GPU panel
comparisons against the frozen unconditional loop. Twelve complete actual-scene
views (three pure-Alien seeds plus one zero-coverage Grass overlay) match that
reference and restored current shader exactly;two wrong-UV controls prove the
interventions actually take effect. Thirty-six primary off/on/off images,
24 additional sampler-reference/return images and two wrong-UV images preserve
the scoped scenery. All31 shared regressions,5466 transport checks,28 lifecycle
checks,the27 map pairs,seven-point derivative control and24 existing tissue
projection cases pass. `experiment_tissue_flow_adoption_1e396f3b7915` preserves
203 guards/125 images/330 verified copies. This is component acceptance,not
whole-biome artistic sign-off or cave completion. Repeated albedo motifs and
broader terrain/organic material contact appearance remain separate work.

Before those two optimizations,nine bounded full-worker pairs measured a median
on/off ratio1.422 (roughly0.44–0.78s off and0.62–1.33s on),not a performance win.
One settled actual cut had measured GPU block medians4.68–5.66ms off versus
5.17–6.18ms on across three fixed views;wall intervals remained presentation-paced
atabout16.67ms despite requesting VSync/maxFPS off. These are bounded timer
observations,not guaranteed uncapped operation or all-world performance. The
current optimized full-worker pairs have median on/off ratio1.334;the feature
still adds work. A separate matched sampler-only test,flow enabled in BOTH
modes,reduces the mean GPU block medians from5.15/6.90/5.71ms to4.95/6.48/5.13ms
atnear/context/ground respectively. It holds one committed cut and alternates
the frozen four-sample/current/current/frozen shaders;it is not a universal
frame-time gain. Current feature-off/on GPU observations are separately bounded
and should not be mixed with the sampler-only test. Sampled native peaks are
1485.4MiB pure and1076.2MiB overlay under4096MiB caps,not old2GiB cold-gate passes.
The four albedo source images remain native1254-square/resampled2048 production
assets;this feature creates no new PBR images or measured normal/roughness scans.

## Active continuation — exact river query identity and graded fans (2026-10-22)

The shared river caches now memoize exact integer-X queries with an active
spacing namespace; fractional queries evaluate the original continuous function
instead of colliding through float32 or rounded coordinates. Mountain's carrier
memo follows the same rule. Numerical formulas remain byte-identical to the
frozen preceding production source, and cache capacities are unchanged.
486 query/order checks,36 complete cached/uncached payload pairs,9 actual
cached/oracle/cached four-worker cuts across three seeds,31 shared regressions,
the existing2.74km streamed wash return and three static apron returns pass.
Checkpoint `experiment_river_query_cache_adoption_0369ad162c01` preserves this
revision before the subsequent fan change. Its18 native images are retained,
but some cross-scene image bytes differ: exact geometry is not a claim of exact
cross-scene pixels. A fixture discovery failure is preserved separately; the
revised search discovers a required real boundary before freezing its views.
The native run sampled1441.1MiB under4096MiB; this is not a universal memory or
timing improvement. A Jolt job-capacity warning recurred during the wash test.

Badlands now exposes `fan_gradient` (default.025m/m;zero restores the prior
apron heights). Deposits rise toward the actual feeder throat with bounded
weighted overlap and existing wash-floor protection. The registered formula
matches the preserved private prototype exactly in19965 checks across five
gradients,three seeds and nine fixed logical fans,including canonical
interpolation and full payloads. Private physical returns passed unchanged;
registered native/physical/full-regression acceptance passes. The private
pre-adoption source/evidence is `experiment_fan_gradient_trial_2305e1381e5c`.
The registered checkpoint is
`experiment_badlands_fan_gradient_adoption_f127dc8d2de1` (168 verified copies,
18 native images). A separately designed UNPAUSED real-time2.74km return passes
in549.945s across27 cuts,32995 movement frames and0.07350m maximum unsupported
drop,with535 physics frames occurring while replacement cuts were pending.
Four workers/fullLOD6/60Hz/5m/s remain. Only initial/departure loading waits;
the old180s accelerated test is separately unchanged and still passes.
Real-time initial fill34.076s,physics-interval p50/p95/p99/max
16.666/16.708/16.854/62.076ms,engine private543.2MiB under1024MiB. These are
headless physical intervals,not GPU frame times or all-world performance.
Nine cold-builder gradient/zero pairs have median ratio0.9740;ordered noise
does not establish a speedup. Native fan review sampled1183.5MiB under2048MiB.
This does not declare the remaining surface art/performance or cave phases done.

## Active continuation — registered legacy/coastal shader pruning (2026-10-22)

The bounded global configured-owner policy now also admits legacy/coastal worlds
without extensions. It still keeps original branch bodies,Grass fallback,
ordering,one extension loop and fail-open source guards. Mixed legacy+extension
and multi-extension worlds retain the original shader. Existing opt-out and
eight-entry bound remain.264 configurations are supported;the complete65536-mask
classifier,all256 legacy/coastal subsets over2304 actual meshes/three seeds
(1339507 checks),150238 other packed-channel checks and67362 source/policy
checks pass. Nineteen actual scene configurations pass285 complete byte-exact
original/variant/original images. All31 shared regressions are refreshed.
Checkpoint `experiment_legacy_shader_policy_adoption_d95afe4b7828` preserves313
guards/285 current images/600 verified copies. Geometry,fields and presets were
unchanged by that policy revision.

The nineteen sampled runtime peaks are954.4–1722.9MiB. Default/legacy-mix/mixed/
Spore/Alien used a2048MiB ceiling;the other fourteen explicitly used4096MiB for
possible first compilation,although every observed sample stayed below2GiB.
Separate private first-preparation peaks were2928.1MiB default,2323.8MiB mixed
and2367.7MiB legacy-mix. A matched arithmetic-identical freshly named original
default control exceeded4096MiB at4171.7MiB before captures;its failure/source
are immutable. These observations are not isolated timing gains,passes of old
cold2GiB gates,cache-cleared startup guarantees or full performance/art/cave
completion. Earlier unroll/body-pruning failures remain failed.

A new query-identity diagnostic has exposed pre-existing shared river-cache
coordinate/spacing aliasing and Mountain fractional-X aliasing. Work is now
focused on preserving the uncached river function while repairing those keys;
the graded-fan prototype remains private until its controls are coherent.

## Registered mirrored-tissue seam repair (2026-10-22)

The original mycelium odd-mirror-quotient defect is now repaired in the actual
shared terrain/shell sampler: a sign-safe common30m period covers the current
fixed2.5m mirrored,2m and1.5m repeating scales and integer chunk origins. No new
varying,texture bank,geometry,lighting or renderer change. The earlier private
phase failures below remain historical failures,not overwritten results.

4572 CPU/source-contract checks,131072 actual GPU remainder cases including
signed far coordinates,4520 detected injected errors,24 four-layer native
texture cases (including three extra distant sites),four region transitions,
and all31 refreshed shared regressions pass. Existing2/255 texture tolerance is
unchanged; observed maximum is about1/255. Restoring only the original arithmetic
reproduces4788 changed pixels/maxRGB0.435294. Four actual runtime scenes pass60
exact original/optimized/original comparison images: Spore1428.1MiB,
Alien1527.9MiB,mixed1191.1MiB,default1473.7MiB,all under2048MiB after compiler
preparation. Checkpoint `experiment_common_tissue_period_adoption_15a2bad4e4f7`
binds277 guards/87 current images/366 verified copies,including failed candidates
and corrected-fixture history. No all-world arbitrary transform/scale or
whole-scene join/art/performance certificate is inferred.

The compilation diagnosis changed the evidence,not the old results: even an
arithmetic-identical function-renamed ORIGINAL shader fails the old2048MiB
fresh-compilation gate (2054.1MiB sampled). A separately predeclared4096MiB
characterization completes both original/corrected shaders at3841.7/3851.3MiB.
Those are not passes of the old gate or memory gains. Engine shader cache was
disabled; the separate driver cache was not cleared. Ordered,non-isolated fills
117.83/136.25s are not a timing win. Broad first-launch preparation/frame spikes
remain open. An earlier signed-negative-remainder candidate failed both GPU
ranges and was replaced,not relabelled. The enlarged projection fixture's world
derivatives did not match either real caller's local derivatives; its failed
sources/images remain archived before the corrected explicit production mode.
All old and additional distant cases remain,without relaxing the tolerance.

## Badlands fan aprons (2026-10-22)

Badlands fan aprons now follow their actual finite feeder trunk rather than a
world-axis oval: narrow throats widen toward the wash outlet, with finite toes
and the existing conservative catchment support. Independent
`fan_shape_strength=0` reproduces the complete frozen original sampler,
mesh/water/palette outputs. The primary wash core is protected from apron fill.
7398 numeric checks, eighteen actual original/shaped/original native views,
three roughly1.09km static apron/capsule returns (maximum unsupported drops
0.09528/0.05444/0.07350m), and all31 shared regressions pass. The separate
existing2.74km full-LOD6 wash return also passes27 committed cuts, with0.07350m
maximum unsupported drop. The native fixture sampled1272.6MiB under2048MiB.
Checkpoint `experiment_badlands_fan_apron_adoption_505e5ee259a6` preserves164
verified source/evidence copies, including the raw Jolt warning-bearing log.

One Jolt job-capacity warning occurred during the static movement test; all
three routes completed. The exact4.6.1 engine allocation loop waits100us and
reclaims completed jobs, but this does not identify the trigger or establish a
project fix. [Engine source](https://raw.githubusercontent.com/godotengine/godot/4.6.1-stable/modules/jolt_physics/spaces/jolt_job_system.cpp).
The apron geometry improvement is visually modest: lowland materials and
distant relief remain soft/broad/repetitive. Neither these views nor successful
movement mark reference-quality surfaces, general performance or caves done.

## Material preparation and Tropical river detail (2026-10-22)

The terrain now has an independently switchable, eight-entry shader-variant
cache for Grass fallback plus at most one configured extension. Coverage-zero
Alien overlays are included in the mask. Mixed legacy/coastal/multiple-extension
configurations retain the exact original shader: broader specialization exceeded
the 2048MiB gate, and a body-pruning trial changed two lit-image bytes. Neither
was adopted. The shipped conservative dispatch passed 66322 policy checks,
150238 actual packed-channel checks, eleven original/variant/original native
comparisons (165 images, exact within each comparison), and all31 shared tests.
Its source-bound historical checkpoint is
`experiment_terrain_shader_variant_adoption_e32e70a10df7` (120 guards,
287 verified copies). These are correctness/resource observations, not an
isolated frame-time gain or whole-surface completion.

A new vertex-origin parity correction also passed all-four-layer texture checks,
but remains **private and unadopted**. Removing only that correction reproduced
4788 changed pixels and maximum RGB error0.435294 at the old failing point.
Cold mixed preparation exceeded2048MiB at2061.8MiB; tiny-bank full-shader
preparation exceeded2048MiB at2210.9MiB; a separately declared2560MiB
characterization also failed at2649.6MiB. No raised cap is called a pass. The
failed sources/logs/thirteen texture images are recoverable in
`failed_diagnostic_origin_phase_resource_failure_4acd7f12d2d7` (42 copies).
The three production shader files were then restored byte-for-byte; mycelium's
old mirrored-origin defect remains open. The newer private helper is not
included by production shaders.

Tropical now refines selected pure main-river corridors at LOD2/3 to32m spacing
and LOD4 to64m spacing,
with an independent zero opt-out and bounded planning work. Other levels and
non-Tropical owners keep their previous policy. This changes mesh density, not
canonical land, water, river positions or ownership. The nine-site/three-seed
13110-check study measured average bank interpolation error8.0167m to1.00765m
and wet/dry interpolation mismatches781 to101 over1414 probes. Shared vertices
and water are exact; the existing float64-sparse/float32-dense normal-probe
storage transition differs by at most5.4531e-7 in this study (declared2e-5 bound),
not bit-exact normals. Main-carrier selection is a bounded heuristic, not a
guarantee for every tributary or lake. Denser tiles cost more work; ordered
old/new build observations are not a fair performance benchmark. All31 shared
tests and eighteen actual streamed river views pass. A separate fixed spectator
camera inspects unchanged rivers while the production target keeps them atLOD3;
the actual workers also refine15/17/25LOD4 leaves in the three enabled cuts.
Complete terrain/water arrays return exactly when disabled again. An early
fixture was rejected because preview startup relocated its target; the accepted
fixture uses equivalent explicit world settings, not preview relocation.
The original uniform32m outer revision is preserved in
`experiment_tropical_river_detail_adoption_8fca77023d2e`. The preferred lighter
outer level still improves mean outer-tile interpolation error18.1916m to2.81559m
over the same probes. Its cuts use227233→323521,229412→364580 and227233→404993
terrain vertices; ordered fill observations are5.50→8.53s,4.38→8.24s and
5.13→12.10s. These are not isolated timing comparisons or performance gains.
Sampled native private memory1218.4MiB remains below2048MiB. Current checkpoint
`experiment_tropical_river_detail_adoption_a8501c4a606b` binds109 guards/eighteen
images/129 verified copies. A larger sampler-node cache was rejected: the three
cold dense builds performed51483 raw evaluations with either budget, while the
larger memo retained more data. Its eight-file failed record is
`failed_diagnostic_dense_river_cache_trial_4ee1a2d0a44b`; the original sampler
and mesh-builder cache implementations were restored exactly. Extending shader
specialization to legacy-only configurations also exceeded2048MiB at2274.3MiB;
the narrower proven policy remains in production. This improves nearby/mid
main channels, not every distant river or tributary. Distant relief, scenic
acceptance, remaining surface quality/performance and every cave phase are
still unfinished.

## Latest scoped continuation — clear finite Insect burrow approaches (2026-10-22)

The structure-aware audit exposed an actual defect hidden by the original
finite-cavity fixture: that fixture omitted supplemental mound collision. Its
three first-admitted sites still pass with solids enabled, but all three happen
to contain no supplemental mounds. A separate bounded default-rarity search
over 1977 admitted portals found two potential near-overlaps. At seed17 portal
`6:22:25` (184096, 206976), the unchanged 776-waypoint return passes without
mound solids but fails at waypoint0 when the actual 37,044-vertex cathedral/
satellite complex is included. Original and current unsafe-mode failures are
preserved, alongside the successful no-mound control. The wider search is
explicit discovery, not a replacement or claimed repair of the original sites.

`nest_protect_burrows=true` now reserves the complete finite access footprint
before emitting an Insect primary/satellite complex. It excludes the obstructing
complex at its original root rather than flattening terrain, moving a portal,
changing the route or weakening capsule motion. Conservative bounds cover the
whole complex and broad dome profile. The provider is queried lazily once per
nonempty relevant tile; empty tiles still do no new work. Independent false is
an **unsafe placement reference**, not a traversal guarantee. The narrower-dome
fallback documented in the previous checkpoint still exists with whole-complex
protection disabled, but the normal path clears the entire reserved approach.

Twenty-two dedicated checks cover both frozen overlap candidates, exact unsafe
arrays, actual provider queries, clearance boundaries and parent/child ownership.
The two same-coordinate near-physics returns now finish without route/capsule
changes. Actual production streaming returns additionally complete 49,973 and
26,255 movement frames through 31 and 17 committed cuts, with maximum unsupported
drops 0.1470m and 0.05444m. The complete 50km/LOD6 hierarchy, four workers, 180s
preload/walk budgets, 1ms headless preload polling and explicit preload pauses
are retained. Actual close-worker payloads exclude the offending complexes;
independent unsafe-mode rebuilds recover all 37,044 original vertices at each
root. These are finite-feature access tests, not an infinite cave foundation.

All 31 shared surface regressions, current dome/vent/query checks and 24 native
dome/vent/burrow views pass. The six new entry/aerial/gallery views retain default
0.18 finite-cave rarity and original lighting; gallery cameras are explicitly
inside the existing finite gallery. Native sampled private peaks are
1335.1/1383.3/1740.0MiB under the unchanged 2048MiB bound. The streamed headless
tests separately sample 518.3/525.9MiB under their 1024MiB bound. Twelve isolated
original/current generation pairs measure combined added cost of 2.2635ms
(median ratio1.09133), including all three Insect controls and actual provider
callbacks. This is not a frame-time gain or pure protection-only overhead.

One Jolt job-capacity warning occurred in the first accelerated headless stream;
the second recorded none. Raw engine/output/error logs are preserved. Completion
does not establish the warning's cause or certify stable uninterrupted play.
No physics job settings or validation limits were changed to hide it. The native
images were inspected: the older spiral/rectangular finite-gallery prototype is
still visibly artificial, not the realistic cave system requested later.

Current evidence: `data/insect_burrow_continuation.json` and
`tools/biome_extensions/artifacts/revisions/experiment_insect_burrow_continuation_276585eab0f8/`
(476 source/evidence guards, 24 images, 502 verified copies, including immutable
historical controls/failures). The source audit permits only the Insect admission
block and its setting; samplers, terrain, collision implementation, shaders and
saved preset stay unchanged. Broader surface scenery/material/performance work,
the separate original Alien navigation/phase diagnostics and all ordered cave
phases remain unfinished. This is not a complete-project certificate.

## Previous scoped continuation — broad Insect dome architecture (2026-10-22)

`nest_broad_domes=true` replaces the upright dome proportions with a broad,
low, asymmetric primary nest: radius parameter 0.84 of the original maturity
scale, height 0.42, an elliptical footprint and two restrained outline harmonics.
Young crowns retain at least their original supported height up to 18m so the
8m buried foundation cannot swallow a small nest. No triangles or textures are
added by this profile. `nest_broad_domes=false` independently restores the prior
primary proportions/profile. Turning off both this control and vents preserves
the complete pre-vent structure arrays. Vent frequency zero alone restores the
sealed cap under whichever dome profile is selected.

Existing reserved finite entrances conservatively prevent footprint expansion;
these sites retain their prior narrower profile, not a moved entrance. Empty,
cathedral-only and disabled tiles issue no new portal query. Multiple dome
roots in a coarse tile share one lazy query. This does not claim that every
older mound/entrance overlap is repaired; structure-aware traversal is a
separate continuation.

The profile passes 354,197 checks over thirty primitive variants and three real
seeded complexes: broad mature proportions, visible young crowns, topology,
normals, bounds, actual vent depth, exact legacy mode, protected-site fallback
and parent/four-child ownership. The 331,294 vent checks and 21 controlled Jolt
floor/lining rays pass again. Twenty-one additional query-policy checks verify
the actual zero/one-query cases. Eighteen current native dome/vent views compare
complete committed worker positions and six real streamed cap/floor rays; dome
and vent sampled private memory were 1324.9/1419.4MiB, each below 2048MiB. Native
views were inspected: the upright-egg silhouette is corrected, while broader
scenic variety and surface materials are still not accepted as complete.

All 31 shared regressions pass for current sources. Twelve isolated alternating
original/new generation pairs, including the real protected-entrance callback
after the terrain/feature prepass, measured median added cost of 1.2145ms and
median ratio 1.05051. This is combined dome/vent CPU addition, not a universal
speedup or frame-time result. Every pair remains recorded. The shared-emitter
and settings text audit permits only these declared changes; builder, collision,
shaders and saved preset are byte-identical to the previous continuation.

Evidence: `data/insect_dome_continuation.json` and
`tools/biome_extensions/artifacts/revisions/experiment_insect_dome_continuation_65670eaa290e/`
(122 source guards, eighteen images, 142 verified copies). Previous checkpoints
below remain historical by their hashes. Remaining surface requirements and all
ordered cave phases are unfinished.

## Previous scoped continuation — physical Insect summit vents (2026-10-21)

Selected mature cathedral, dome and rocky primary nests now have a real open
summit recess. `nest_vent_frequency` defaults to 0.25; independent zero frequency
restores every original mound array. This is a thick annular earthen rim,
inward-facing lining and visible blind floor, not a black hole texture or a
traversable chimney. Depth is 18% of the actual mound height, capped at 24m;
small mounds and unsupported archetypes remain sealed. Nine conservative
ground/water probes reject recesses that would intersect the canonical surface.
Satellite geometry, root descriptors, terrain fields, materials and texture
resources are unchanged. Each admitted primary adds 504 vertices (168 triangles).

Current physical checks pass 331,294 assertions over 27 mound variants:
exact original zero arrays, finite normals, no degenerate triangles, no open
boundary except the original buried base, actual measured depth and original
sealed-cap negative controls. Twenty-one native Jolt floor/lining rays agree
with independent triangles. Three actual default-rarity sites verify complete
zero-frequency equality, parent/four-child ownership and that satellites do
not obstruct the aperture. Nine native production views additionally match
complete actual committed worker positions (37,548 / 37,548 / 6678 vertices),
with actual streamed floor errors below 0.084mm. Sampled native private memory
was 1510.1MiB under the unchanged 2048MiB bound. The opening and complex views
were inspected; broader mound proportions, scenic variety and material quality
still need work, and these captures do not confer reference-quality sign-off.

All 31 shared surface regressions pass for current sources. Twelve isolated
alternating original/new near-mound generation pairs measured median added
CPU cost of 0.844ms (median ratio 1.02094), not a frame-time gain. The original
is the frozen complete pre-vent emitter, not a current emitter paying the new
admission overhead. Numeric serialized arrays and every pair are recorded;
this does not certify distant/custom-density generation or uninterrupted play.
The independent shared-emitter/settings text comparison verifies only the
declared vent integration changed; complete file hashes are separately bound.
The previously adopted coastal cache builder stays byte-identical.

Evidence: `data/insect_vent_continuation.json` and
`tools/biome_extensions/artifacts/revisions/experiment_insect_vent_continuation_8ddeb9cbb953/`
(114 source guards, nine images, 125 verified copies). These are surface mound
features, not the queued cave foundation. Remaining surface requirements and
all Default/Frozen/Crystal/Magma cave phases remain incomplete.

## Previous scoped continuation — bounded coastal structure height memo (2026-10-21)

The production worker now selects a 65,536-entry height-only memo for coastal
Alien tiles spanning at least 8192m. Near tiles, unrelated owners and the
independent `coastal_structure_height_cache_enabled=false` path retain the
original 8192-entry budget. Reconfiguration clears it; a coarse-to-fine budget
shrink immediately clears oversized retained data. This does not alter the
8192-entry full vertex-payload cache, 16,384-entry structure support memo, four
workers, terrain fields, geometry, materials, view distance or collision policy.

The complete isolated three-pair benchmark is frozen at
`experiment_profile_coastal_height_cache_41712d017913/`. Every pair retains the
same complete arrays and 2,068,590 structure vertices on the declared coastal
16km seed92881/scale0.2 tile. Ratios are 0.884563, 0.916211 and 0.726245
(median 11.54% faster); the third baseline was noticeably slower, so these are
not a universal speedup or a shader/streaming benchmark. Actual recorded times
are 68.376/60.483s, 68.388/62.658s and 87.805/63.768s. Retained serialized numeric
dictionary data rises from 175,348 to 1,524,724 bytes in this workload; these
figures are not total heap usage. The runner observed no other Godot process at
500ms samples, which cannot exclude shorter overlaps. Sampled private memory
was 303.3MiB under its separately declared 768MiB numeric-test bound.

The registered policy passes 280,135 assertions: exact eviction and bypass,
full-payload precedence, 32 policy combinations, reconfiguration/shrink and
eighteen complete real coastal/mixed/overlay-only near/coarse output comparisons
over three seeds. Nine current native shore views additionally verify actual
committed topology and twelve idle-worker budget observations. Sampled native
private memory is 1413.3MiB under the unchanged 2048MiB bound. All 31 shared
surface regressions pass. The adoption assembler verifies that only the
declared capacity policy differs from the timed original builder, normalizing
line endings for that text comparison while binding both complete file hashes.

Scoped evidence for that earlier source revision: `data/coastal_height_cache_adoption.json` and
`tools/biome_extensions/artifacts/revisions/experiment_coastal_height_cache_adoption_60547d2bad62/`
(133 source guards, nine images, 144 verified copies). The earlier complete
62-report surface checkpoint and tissue-material adoption remain historical by
their hashes; this is not a replacement whole-surface art/traversal certificate.

A new PRIVATE vertex-stage tissue-phase candidate passes 4459 integer checks
and twelve native projection cases, but its unspecialized full scene exceeded
2048MiB at a sampled 2062.8MiB before acceptance. Its bound failure is preserved
at `failed_diagnostic_vertex_tissue_phase_bound_failure_efeb522c644c/`. It is not
shipped: the production sampler remains SHA256
`471d766b176f7690c956a37b1b315fbabcfae9b660462d15813ab97c8a1e9d20`.
The known mirrored-mycelium phase issue, original failed navigation approach,
debug intersection differences, remaining scenic/performance work and every
queued cave phase remain open. No complete-project claim is made.

## Active continuation — Alien attachment and material continuity

Latest material-control checkpoint: `tools/biome_extensions/artifacts/revisions/alien_20261019_1e59777e2f07/` preserves 191 verified source/evidence copies and eighteen guarded reports. It includes twelve actual junction views, three actual supplemental-mesh normal-control cases (fifteen images), eight terrain normal-control cases, the original scene-sun check and the shared 31-script regression. Supplemental Insect/Alien normals now obey their actual configured strength and global debug controls; Crystal remains geometric facets without an invented fine normal map. Normal-off and zero-strength physical renders agree in the tested cases. This checkpoint predates the carapace addition below and is historical by its recorded source hashes.

A later squared-distance/AABB network experiment preserved exact fields but did not improve the measured workload: its paired median ratio was 1.064 (slower). It was rejected and the exact cached sampler restored. Fourteen source/evidence copies are retained at `tools/biome_extensions/artifacts/revisions/rejected_distance_bounds_20261019_ac5c8d55acc6/`. Reduced arithmetic counts alone are not treated as a performance win.

## Active continuation — network-rooted carapace plates

Hardened and dormant Alien regions now admit rare overlapping dorsal plate complexes at existing hive-network nodes. Defaults are 0.18 candidate frequency, 240 m reference width and 100 m reference height, with existing maturity/relief scaling. A junction takes priority at a shared candidate. Nine dry/full-owner support probes fit a local plane to separate ordinary grade from abrupt relief; this is not whole-footprint hydrological certification. Existing finite-cavity approaches remain reserved. Each complete complex adds 6000 closed triangles, with keels and growth ribs, outward geometric normals, stable half-open ownership and 120 deeply buried perimeter feet. Hardened/dormant material identity uses existing tissue controls and authored tint rather than new texture channels.

Focused checks pass 1,587,658 geometry assertions, seven placement-policy assertions and 43 admission/disabled/reference/protected-site/parent-child assertions over six real seeded hardened/dormant sites. Native staged/activated/released collision passes 1050 checks (726 rays) against independent triangle top envelopes, with maximum observed error about 2.90 mm. Twenty-four production-streamed views verify the complete 18,000-vertex addition at all six sites; every site's 120 feet are below the actual committed ground triangles. Uploaded colour-tag comparisons allow one UNORM8 code value; worker-array comparisons retain exact source colours.

The first complete plate checkpoint is preserved at `tools/biome_extensions/artifacts/revisions/alien_20261019_8f3d41872cef/`: 230 verified copies, twenty-four guarded reports including the shared 31-script regression, twelve junction and twenty-four plate views. Its first eighteen-pair cold numeric-generation benchmark measured 123.172 ms median added plate cost, with substantial noise; this is not a runtime frame-time measurement. Five-case supplemental normal controls now additionally exercise actual hardened/dormant plate meshes, yielding twenty-five images and zero normal-off/zero-strength physical differences in these cases.

The corrected-material checkpoint is now preserved at `tools/biome_extensions/artifacts/revisions/alien_20261019_4741de574b0b/`: 240 verified copies, twenty-four guarded reports, twelve junction views, twenty-four plate views and twenty-five supplemental-control images, with all 31 shared surface regressions passing. In this second eighteen-pair numeric run, median added plate generation was 85.603 ms (mean 80.966 ms), further illustrating timing variation rather than an algorithm change. It is a scoped validated continuation, not completion of the full queue.

These remain scoped implementation checks, not final art acceptance. Close views show physical ribs and surface detail, while distant terrain remains overly smooth. A ten-view same-scene current/private-material comparison found the first dormant reflectance too bright. Production now uses the tested lower opaque-shell reflectance without changing lighting, geometry or collision. The `4741de574b0b` checkpoint includes this correction and its complete current-source refresh. The four-view unintegrated morphology prototype is explicitly separate and must never substitute for production-streaming evidence. All cave phases remain queued in the user's required order.

An exact integral-world footing-cache experiment is not adopted: it reduced redundant requests but gave only small/inconsistent numeric timing changes. Real full-array comparisons cover default/fractional custom grids; extreme cache keys use a finite varying synthetic fixture rather than treating unsupported far-noise NaNs as a valid terrain acceptance case. The report and eight verified copies are preserved under `tools/biome_extensions/artifacts/revisions/experiment_profile_world_footing_cache_3d9b387bb9a6/`. The separate conduit-geometry reuse prototype was subsequently integrated and evaluated below; its earlier reports remain specific to their declared pre-integration sources.

## Active continuation — bounded conduit-geometry reuse

The separate reuse prototype passed 159 checks and nine alternating cold-builder numeric split/rejoin pairs (three seeds), with exact terrain/control/water/structure hashes. Its paired median combined ratio was 0.688; this is a declared warm-reuse workload, not cold startup. The prototype reports and pre-integration source were preserved before adoption. Production now has the same bounded worker-owned conduit mesh memo, with the frozen `reference_pre_conduit_memo_structures.gd` retained for exact comparisons. The `conduit_cache_mib` control defaults to 8 MiB of numeric mesh arrays per worker, is clamped to 0–16 MiB, and separately caps metadata at 32 entries. Zero releases the memo. Non-Alien builders do not allocate one. Settings/seed/water changes invalidate it; support grids, original shape switches and relevant protected approaches are part of primitive identity. Original world float32 vertices reproduce each new leaf's original local transform; no SceneTree/GPU objects or collision simplification are cached.

The integrated producer passes 256 checks, including actual signed LOD origins, default/fractional support grids, cache reuse, reconfiguration, reserved approaches, partial infection over Forest, exact zero-budget/reference bypass and forced bounded eviction. Its production off/on numeric run passed full terrain/atlas/water/structure hashes, with median combined ratio 0.709 and structure-only ratio 0.569. The prior `4741de574b0b` checkpoint predates this producer change; full current-source native/regression refresh is still pending.

Actual streaming has not yet shown a general benefit. Three alternating off/on pairs on the existing nearby-teleport route recorded zero memo hits in every enabled run. Initial fill was 12.01/12.15/11.90 s off versus 12.14/12.10/12.29 s on, excluding process launch/scene instantiation; approximately 10.8–11.0 MB numeric cache data was retained across workers. These are not startup improvements. All six reports, twenty-four native views and their declared sources were preserved before extending the fixture to longer root-focused LOD transitions. Cache admission/default retention is under evaluation, not performance sign-off.

The first longer root-focused three-pair study exercised 24–42 actual worker hits but produced only a 2.3% median replacement-cut wait reduction, a 2.7% initial-fill penalty and effectively unchanged summed per-worker elapsed time. Its thirty native views and declared sources were preserved before correction. Inspection found full settings fingerprints being computed on empty leaves. Production now validates lazily, once per leaf that actually emits conduits, while zero/shrunk budgets are honoured even on empty leaves. Completed builds disarm their local memo before returning; only the worker builder retains data. The expanded producer test passes 268 checks, including empty-leaf allocation/validation/release and unchanged other-family arrays.

The corrected three-pair native study (`profile_conduit_memo_streaming_lazy_root.json`) uses one actual root site, the same five teleports and 50 km far plane, and thirty hash-checked images. Its median replacement-cut wait ratio is 0.931 (6.9% lower), initial-fill ratio 1.011 (1.1% slower) and summed worker-elapsed ratio 0.982. Enabled runs recorded 24–42 hits, retaining at most 10,958,976 numeric bytes across four workers. The maximum observed wait-frame was still 77.986 ms. These are scoped route results, not solved cold start, hardware CPU utilisation or uninterrupted frame-time acceptance.

The full current-source render/collision/shared-regression checkpoint has completed and is preserved at `tools/biome_extensions/artifacts/revisions/alien_20261020_17375e47d8d1/`: 286 verified copies and twenty-seven guarded reports, including all 31 shared tests. A headless preload timeout was investigated rather than hidden by increasing the timeout: four bounded diagnostics compared cache off/on with a busy process-frame poll versus a 1ms paused poll. Evidence is preserved in `preload_poll_diagnostic_20261020_859a09644ec2/` (29 verified copies). Only paused headless preload/streaming waits now yield 1ms; the same 180s timeout, capsule dimensions, gravity, speed, slope and drop limits remain. All three 240m junction return walks pass 70 checks, with no unsupported frames. This is not an uninterrupted runtime performance certificate. No later cave phase has started.

## Active continuation — nerve-lowland physical fibres

The tapered-fibre relief is now integrated in production, with an independent `nerve_fibre_height` control (default 24m, range 0–40m). Its first 6m trial passed 43,819 numerical checks and produced six same-camera native original/candidate views, but inspection found only a subtle silhouette change against the still overly smooth landscape. That evidence was preserved before revision. The final isolated trial passed 45,115 checks including closest-segment bend continuity; its reports, sources and six images were preserved before integration. Three asymmetric compact ridges taper/merge along actual trunk paths, with irregular widths and finite support, not periodic cross-distance sine stripes. The finite-polyline signed-distance metric avoids a step around path bends. Only full-biome Nerve-lowland regional height changes; partial infection applies the same raw relief through its existing compact influence. Public network dictionaries and control channels are unchanged. Only one private projection frame is retained per worker, cleared on reconfiguration.

Production passes 19,429 checks against the preserved trial over three seeds and three feature scales, including exact frozen zero fields, full near/far terrain/normal/atlas/water comparisons at zero/default/maximum strength, partial infection over Forest, shared signed adjacent/LOD vertices, reverse query order and used-sampler reconfiguration. The original edge-cache comparison now explicitly disables fibres when certifying equality to its older field. Six new actual production-streamed zero/default images use unchanged camera/light and the full 50km hierarchy, with no private sampler replacement. A 480m native capsule return walk passes: 5,804 movement frames, five committed cuts, all 24 outbound probes bearing fibre relief and no unsupported drop. The unchanged test capsule is 1.8m tall, radius 0.4m, 5m/s, gravity 9.8m/s² and 45-degree slope limit; it pauses for replacement-cut preloads. These are scoped successes, not all-world navigation, artistic sign-off or uninterrupted performance. The complete current-source checkpoint and added CPU profile are running.

The new nine-pair serial cold-builder CPU profile passes with a median numeric terrain ratio of 1.105 (about 10.5% added CPU cost), not a speed improvement. No extra vertices/triangles are introduced. This measures actual 2048m/64-resolution terrain and atlas generation across three seeds; it is not a frame-time, GPU or process-start measurement. Its first attempt failed on a float/integer Dictionary-key mismatch in the profile harness. The failed source/log are preserved under `profile_nerve_fibres_float_keys_20261020/`; explicit integer keys fix the harness, without any production change. The checkpoint resume validates every completed report and every declared source hash before skipping stages. Shared regressions and new serial native cache profiles remain in progress.

The complete current-source checkpoint is now preserved at `tools/biome_extensions/artifacts/revisions/alien_20261020_5390b345d252/`: 302 verified copies and thirty-one guarded reports, including all 31 shared regressions, six new production fibre views, the 480m fibre return walk and all prior junction/plate/material checks. The new three-pair native cache study (`profile_conduit_memo_streaming_fibre_root.json`) gives median initial-fill ratio 1.021, replacement-cut wait ratio 0.990 and summed worker-elapsed ratio 0.995, retaining at most 10,942,848 numeric bytes across four workers. Its maximum wait-frame is 64.834ms. These results do not reproduce a broad streaming benefit: the earlier 0.931 wait ratio is historical, not a current performance claim. The separate controlled warm-reuse numeric profile remains faster (combined ratio 0.680, structure ratio 0.553). None of this establishes completed cold-start or uninterrupted-frame targets. The next grown-carapace terrain candidate is private and not part of production.

Three private grown-carapace heightfield studies have now been evaluated and preserved separately, with numeric/source/native-image snapshots. The first raised crusts passed 108,052 checks but still looked like rounded hills. A planed-crust revision and a version with compact tapered keels passed 118,852 checks and eight paired native views each. Exact raw deformation bounds are checked independently; published `(base+delta)-base` permits only 1nm cancellation tolerance and records observed roundoff (about 5e-15–3e-14m), not relaxed physical geometry limits. Neither later version gives a sufficiently distinctive biological armor silhouette: local deformation caps and broad existing relief leave generic mounds/mesas. **None is adopted in production.** The last render study is preserved at `experiment_render_grown_plate_terrain_candidate_0bf54e51cc17/` (25 verified copies). The current validated production checkpoint remains `5390b345d252`. Further surface work should focus on actual thick biological membrane/buttress geometry rather than claiming these small heightfield changes satisfy the required giant organic structures. No cave phase has begun.

## Active continuation — fluted junctions and thick membranes

The production junction emitter now uses longitudinal growth flutes rather than stacked cross-height bands by default. `hive_longitudinal_ribs=false` retains the old morphology. `hive_membrane_frequency` defaults to 0.4, independently conditional on an already admitted rare, dry, fully owned junction. Zero leaves the open strut. The new `alien_membrane_geometry.gd` adds a closed, bilaterally thick, billowing membrane with three asymmetric physical folds. Its upper edge is inside the actual curved root strut, its left edge is inside the blade, and its far cross-section is buried below all supported terrain chords. It uses the existing membrane tissue role (semantic UV region 3), not a new texture/channel, alpha card or cave engine. Existing root ownership and the junction's reserved-cavity footprint still govern the entire complex. No scene lighting, saved coverage, new surface owner, view range or collision-policy changes were made.

The private references were preserved before adoption. The combined morphology passes 500,911 geometry checks; complete-edge containment passes 1,388 independent triangle-parity checks using real root identities and three actual feature scales/heights. Native Jolt reference meshes pass 490 checks (243 vertical rays and 63 face-normal rays) against independent triangles. An initial nominal-lateral ray was nearly tangent to a folded face (dot about 4e-5), so 1.3mm of world rounding made both numerical/native rays miss; its diagnostic is preserved under `membrane_ray_tangent_diagnostic_20261020/`. Face-normal probes fix the fixture. The unchanged structure shapes are one-sided: a two-sided reference was also correctly rejected at a component overlap (about 18.97m discrepancy); the proper front-face reference agrees within about 0.206mm. This remains an explicit negative control, not a relaxed collision tolerance.

Production passes 61 checks covering default/zero/forced membrane rarity, unchanged complete prefixes, exact preserved-trial tails, complete pinned pre-integration arrays when both controls are disabled and stable parent/four-child ownership at three seeded roots. The current uncached memo reference now follows current morphology while preserving the caller's memo metadata; the original pre-cache snapshot remains historical. All three actual 240m native return walks pass with the integrated geometry and no unsupported drops. The membrane-bearing case has an 8m canonical-to-ceiling native ray clearance; an additional native floor-to-ceiling check is part of the refresh. Twelve real production views verify all 5,136 membrane vertices in the actual worker/staged mesh, not a private substitute. The actual membrane material passes normal-control diagnostics (10,196 changed mapped-normal pixels, exact zero/geometric and physical-off/zero equality), alongside the five existing supplemental cases. Complete current-source regression, CPU cost and six serial streaming profiles are running; `5390b345d252` is now the last complete pre-membrane checkpoint, not a current-source certificate. All cave phases remain queued.

## Current continuation — membrane headroom and adaptive network queries

The first integrated membrane's 8m guard measured height above canonical ground,
not above existing solid conduits. A new independent flat-field triangle test
found six obstructed midpoint fixtures: a maximum-age conduit could leave only
0.231m beneath the old guard. That original source/report is preserved as an
experiment and `reference_8m_membrane_geometry.gd` remains a required negative
control. The production guard is now canonical+12m, still capped inside the
existing strut and with the complete far root buried. Across three widths,
three heights and 24 conduit phases, the smallest corrected triangle-to-triangle
gap is 4.231m. Closed topology, complete blade/strut attachment and native Jolt
collision pass again. This is not a guarantee over arbitrary natural slopes or
all custom settings; actual streamed capsule returns are refreshed separately.

Alien now has an independent `network_query_cache_enabled` performance control
(default true). It retains at most 512 small query tiles and 512 admission
counters per worker; four distinct uncached queries admit a tile. Conservative
segment bounds preserve original public network values and all paths capable of
affecting nearest/second-nearest fibre isolation. Sparse queries use the original
projection path. Disabling releases retained spatial metadata; reconfiguration
resets it. No other biome allocates this cache, and no terrain/normal/material
channel, geometry resolution, view distance or saved coverage was changed.

The integrated path passes 53,893 exact/lifecycle checks against the frozen
pre-cache sampler, including full near/far terrain, normals, atlas, water and
structures, partial Forest infection, three seeds/scales, signed boundaries,
query-order eviction and zero/default/maximum fibre relief. Thirty-six serial
paired cold-builder workloads measured median numeric ratios of 0.889 near,
0.722 regional, 1.035 sparse far and 1.040 random queries. Those are local CPU
measurements, not a general streaming gain. The unconditional prototype was
rejected for its large sparse/random penalty; both experiments are preserved.
The last complete checkpoint, before the debug-lighting correction below, is preserved at
`tools/biome_extensions/artifacts/revisions/alien_20261020_9990e79e6885/`:
41 guarded reports and 373 verified source/evidence copies, all 31 shared
regressions, three 240m junction returns, the 480m fibre return and the complete
production render/material review. The membrane-bearing native route now has
8.94m actual floor-to-ceiling clearance, with no unsupported drop. Eighteen
cold-builder membrane pairs measured median added CPU cost 11.331ms (mean
17.233ms, noisy range -18.375 to 61.084ms), with 1,712 triangles and 246,528
numeric-array bytes added per membrane. A negative paired difference is timing
noise, not a claim that generating a membrane saves CPU.

The final serial numeric query-cache ratios were 0.812 near, 0.715 regional,
1.024 sparse far and 1.037 random queries. The separate three-pair native query
study, with conduit memo fixed at 8MiB in both modes, measured median ratios
0.800 initial fill, 0.797 replacement-cut wait and 0.785 summed worker elapsed.
Enabled workers recorded 785,422–807,283 tile hits and at most 657,548 serialized
metadata bytes across the observed workers; disabled workers retained no query
tiles or admission counters. Maximum wait-frame remained 46.072ms. The separate
conduit-memo study was essentially unchanged (fill 0.996, wait 0.999, worker
elapsed 0.991), with at most 10,886,400 retained numeric mesh bytes. These are
isolated seeded teleport workloads, not process-launch, uninterrupted walking or
whole-world performance certificates.

A separate 27,017-check production rollover test admits 600 dense tiles in each
of three seeds/scales, actually fills and rolls over the 512-entry geometry
cache, and preserves exact original network/fibre values throughout. Maximum
serialized retained metadata in those fixtures was 287,880 bytes per worker.
The historical original-versus-standalone-web viewer now explicitly disables
production membranes and selects legacy blades in its baseline, preventing a
duplicate membrane after adoption; its six views pass and are preserved
separately. Smooth distant landforms, thin joins and broader scenic targets
remain open. All cave phases remain queued in the user's required order.

### Debug-lighting investigation (scoped refresh completed)

Two private join trials are not adopted. A terrain-only tissue-response change
rendered eight paired views but did not resolve the visible join. An
existing-alpha-only conduit-edge transition passed 44,872 exact geometry/RGB/
normal/UV/disabled-array checks and eight views, but the troublesome patch
remained. Both sources/pixels are preserved; numeric success is not art approval.

Actual front-triangle/native Jolt rays agreed within 0.077mm at four initial
selected pixels and showed valid semantic UVs. Inspection then found a separate
diagnostic defect: the final extension/coast blends restored physical specular
lighting after the original debug branch. Sun rotation changed supposedly pure
albedo/geometric-normal/mapped-normal views by up to 0.310 RGB. The tested final
debug guard produces zero light-dependent difference in those modes and in a
terrain-only feature-mask fixture. It is integrated only for debug 3/4/8 and
260–264; normal physical rendering and normal-off 7/18 do not select it. Exact
shader-source identity against the frozen original, excluding that guard, is
required by the new native test. Production scene lighting is unchanged.

The first feature-mask trial failed because it included normally lit shells
that do not implement the feature-mask diagnostic. Its failed source/report/
sixteen captures are preserved; isolating the terrain equally in both cases
fixed that fixture without relaxing its two-code tolerance. A later whole-scene
physical comparison found four differing pixels, so physical equivalence is not
yet accepted. Those failed reports and 28 captures are also preserved, and exact
pixel/triangle overlap tracing is in progress. The old complete checkpoint is
historical for its shader hash until the current-source refresh completes.

The corrected pixel-centre rays place those four samples at terrain/shell
intersections separated vertically by 2.29–3.87mm (10.60–21.07mm along the
viewing rays); native contacts agree within 0.061mm. The earlier integer-corner
trace is preserved separately and is not substituted for raster-centre evidence.
This is consistent with depth-ownership sensitivity but is not a completed
whole-scene equivalence proof. A fully layer-isolated comparison, with all other
render layers hidden equally in both shader cases, now gives exact zero RGB
difference over all 242,688 ground pixels for physical modes 0/7/18 under both
lights. No individual pixels were excluded or tolerance enlarged. The current
28-view production proof explicitly retains `whole_scene_physical_equivalence=false`
and the four-pixel mixed-layer limitation. The complete pre-surface-guide
checkpoint is preserved at
`tools/biome_extensions/artifacts/revisions/alien_20261020_69c0f0137a29/`:
43 guarded reports and 406 verified source/evidence copies, all 31 shared
regressions, the 28-view scoped lighting proof and twelve serial native cache
profiles. Final conduit-memo ratios were 0.985 fill / 0.939 replacement wait /
0.963 worker elapsed, with a 46.963ms maximum wait frame and 10,805,760 retained
numeric mesh bytes. The separate query-cache study (conduit memo fixed at 8MiB
in both modes) measured 0.843 / 0.780 / 0.792, a 54.443ms maximum wait frame and
at most 600,100 serialized query-metadata bytes. These seeded teleport workloads
do not establish uninterrupted or process-launch performance. The four-pixel
mixed-layer limitation remains explicit. This checkpoint is historical for the
later visible-arch guide change below.

### Last complete guide/pure-path LOD checkpoint (2026-10-21)

`tools/biome_extensions/artifacts/revisions/alien_20261021_cd48ab11a900/`
preserves 55 current-source guarded reports and 461 verified copies, including
the original rejected approach's actual archived source/evidence bytes. All 31
shared regressions pass. This checkpoint adds independent guide/LOD controls,
three default-scale returns, six navigation-admitted minimum/maximum-scale
returns, the 480m fibre return, production renders/normal/debug controls and
twelve serial native cache profiles. It does not certify all user tasks.

Current conduit-memo paired median ratios are 0.984 initial fill / 0.963
replacement wait / 0.967 summed worker elapsed, with a 67.366ms maximum observed
wait frame and 8,850,240 retained numeric mesh bytes across observed workers.
The separate query-cache study, conduit memo fixed at 8MiB per worker in both
modes, gives 0.883 / 0.810 / 0.827, a 77.459ms maximum wait frame and at most
949,088 serialized query-metadata bytes. These are three alternating pairs on
one seeded five-teleport route, not a comparison against the prior checkpoint,
process launch or uninterrupted traversal. Absolute spikes remain open work.
The four-pixel mixed-layer physical limitation, broader surface art and
unsupported mixed/coastal structure LOD remain explicit. All cave phases are
still unimplemented and queued in user order. Later private material/height
publication trials do not change this production checkpoint.

The later retained-contact extension below changes production controller
sources. Checkpoint cd48ab11a900 is therefore historical for that new revision;
its original reports/copies are not silently relabelled as current.

### Mixed/coastal retained-contact LOD (validated scoped checkpoint)

`alien_conduit_contact_lod.gd` adds worker-only adaptive upper-surface topology
where the fast pure-Alien analytic foundation bound is unavailable. Every
original full-resolution apron/contact cell and endpoint remains. Wide bands
require upward projected winding; invalid bends choose smaller bands or a valid
narrow stitch, otherwise their exact original triangles. No new global lower
bound is assumed for mixed owners, coasts or alternate noise. Near geometry and
the independent disabled flag retain complete original arrays. The existing
8MiB/32-entry memo has a distinct retained-contact key and unchanged bounds.

The independent private prototype passes 620,472 checks across 108
seed/scale/host/phase cases and separate 27-layout protected-approach controls.
All original margin positions/normals/colours/UVs and multiplicities, buried
boundaries, unit normals, original retained positions and near/zero arrays are
checked. Four complete tile pairs preserve all canonical terrain/metadata,
finite features, landmarks and conduit identities. The dense coast-enabled
16km tile retains all 1,344 conduits and reduces 2,441,064 vertices to 2,068,590
(about 15%). Times were 56.055s original versus 56.841s trial: **no CPU speed win
is claimed**. Smaller mixed-tile timings also vary; this is geometry/upload
reduction, not startup optimization.

The integrated producer matches independent complete cold/warm arrays in 608
cache/control checks. Six complete mixed/actual-shore node cases pass 68 checks:
original disabled arrays, all landmark attributes and parent/four-child root
identities/world-landmark vertices. Three normal-rarity dry roots have actual
coastal overlays 1.0 / 0.9012 / 0.1339 and exact original near arrays. Native shore
rendering passes all nine medium/aerial/ground views, including complete actual
committed-worker position comparisons against the independent prototype. The
guarded renderer sampled 1410MiB engine private memory against its unchanged
2048MiB limit (500ms samples, not a certified instantaneous peak).

Checkpoint `tools/biome_extensions/artifacts/revisions/alien_20261021_70fe4c011778/`
preserves 62 guarded reports and 488 verified source/evidence copies. All 31
shared regressions, three default and six navigation-admitted custom-scale
junction returns, the 480m fibre return, declared native render/material/debug
controls, and twelve serial cache profiles passed. A report-order defect was
corrected: custom admission must precede the guide test that hashes its manifest.
Only that dependent test and aggregation needed rerunning; current source guards
still validate every preserved report. The dense geometry pair reran at 74.690s
original versus 73.726s candidate; this does not establish a repeatable CPU gain.
Conduit memo paired median fill/wait/worker ratios were 0.966/0.972/0.972, with
141.420ms maximum observed wait frame and 9,007,488 retained numeric mesh bytes
across observed workers. Separate query-cache ratios were 0.856/0.790/0.807,
maximum wait frame 54.474ms and 796,868 serialized query-metadata bytes. These
are declared isolated seeded workloads, not cross-checkpoint, cold-start or
uninterrupted-streaming guarantees. Surface art/performance and all later cave
completion flags remain false; four mixed-layer physical-response pixels and
the original rejected steep approach remain unresolved.

### Tissue V3 adoption; phase/compiler work remains private

The production sampler is restored byte-for-byte to its validated SHA256
`471d766b176f7690c956a37b1b315fbabcfae9b660462d15813ab97c8a1e9d20`.
Only the two terrain/shell array paths now select `biological_colors_v3.tres`.
The older checkpoint 70fe4c011778 remains historical for these newer binding
paths, not a relabelled current full surface/traversal/performance certificate.

Scoped material adoption is recorded in `data/nerve_film_v3_adoption.json` and
`tools/biome_extensions/artifacts/revisions/experiment_nerve_film_v3_adoption_cae0db5bce62/`:
202 source guards, 69 native images bound and 273 verified source/evidence
copies. The new charcoal folded-tissue layer reduces the conspicuous pale
repeated motif. Original nerve source/packed image and v2 array are retained;
their full original prompt is in `data/biological_nerve_v1_provenance.json`.

The compressed A/B/reference-return/normal trial passes 15 views over three
seeds (1310.1MiB sampled engine private memory under the 2048MiB cap). Actual
runtime binding then passes nine ground/medium/aerial views, 2,022 material
checks and three exact SAME-COMMIT runtime/manual controls (six additional
native images), sampled 1348.5MiB under 2048MiB. The latter use main-thread
zero-step `RenderingServer.force_draw` and GPU synchronization between the
unchanged committed scene and an explicit rebind of the same array; no pixels
are excluded and no RGB tolerance is relaxed. This is not cross-run identity:
the earlier strict full-image comparison failed at seed17 with five differing
pixels, maximum two codes. Its failed source/log/pixel snapshot remains
preserved. The cause of those five pixels is not claimed repaired or conflated
with the separate four-pixel debug-light intersection issue.

Four actual GPU layer readbacks, the unchanged three-layer production
projection control, eight terrain and six shell normal-control cases pass.
The shared 31-script surface regression passes for the current source. Terrain
and shell normal-off/zero controls report exact equality in their declared
probes, sampled private-memory peaks 1281.3/1392.3MiB under 2048MiB. The 24
terrain-control PNG hashes are bound at adoption time (the older fixture itself
records numeric GPU outcomes, not run-time PNG-hash guards). No geometric,
lighting, cache-size, worker-count, startup or full-reference-quality success
is inferred from this material-only adoption.

The expanded PRIVATE four-layer fixture still detects the original mycelium
mirrored-origin phase error: 111 RGB codes at the third signed-origin site.
The correction uses a two-unit period; ordinary repeats remain equivalent
modulo integer UV shifts, not byte-identical arithmetic. Private native
12-case controls pass the unchanged two-code tolerance with the actual v3
array. Exact integer proof adds 8,736 assertions across signed 256–16384m
origins and .25–8m scales, including 942 original odd-parity negatives. These
are private candidate proofs, NOT an adopted/fixed production sampler. The
passing three-layer control does not certify mycelium; the original four-layer
failure is explicitly retained as open work.

Full-scene acceptance is NOT established by those small controls. The packed
texture trial sampled 2086.7MiB against its predeclared 2048MiB cap before its
first capture. Original-material controls containing conditional and then
branch-free phase corrections also exceeded the cap (2069.1MiB samples).
Private mask-bounded loop trials sampled 2051.4/2051.2MiB against 2048MiB;
a tiny-mesh shader prewarm sampled 2188.9MiB against 2048MiB before drawing.
A private pure-owner late-override trial sampled 1992.2MiB against a LOWER
1536MiB cap. Each stopped only its own engine, with exact source/log snapshots
preserved. These observations do not isolate a compiler/driver root cause.
None of these failed variants passes its declared cap or is an adopted shader
optimization. An even earlier full-shader-only warmup failed at 1662.5MiB under
a LOWER 1536MiB cap, then 2173.7MiB under the original 2048MiB cap. A separately
named characterization, explicitly not a pass of the 2048MiB gate, required at
least 3500MiB available RAM and used a predeclared 2560MiB bound; it too failed
at 2635.6MiB before drawing. Its failure is preserved, not relabelled a render
success. No further bound increase followed. A private early-registered
Alien-plus-original-Grass-fallback specialization rendered one actual view
under 1536MiB (1436.3MiB sampled), but lacks full-master pixel-equivalence proof
and is not adopted. The separate all-full-Alien specialization remains rejected
on actual partial/empty tile coverage; that predicate was not loosened.

The generated nerve-film PNG passes its predeclared ingress edge criterion;
15 decoded-array A/B/reference-return/normal views passed before the later
sampler changes. Private RGB BC1 packing passes 466,489 sampled loss checks
(maximum channel error .0863, mean maximum .0165) and retains 2,796,216 bytes per
layer; native source remains 1254-square, not native 2K. The production v3 array
retains the same total 11,184,864 BC1/mipmap bytes as v2 and changes only layer1.
Original resources remain untouched. The complete prompt and built-in
image-generation mode are preserved in
`tools/biome_extensions/experiments/nerve_film_v3_provenance.json`; its private
creation-time adoption flag is historical, while the separate adoption record
above describes current binding. Generated albedo/derived apparent microrelief
is not a measured normal, height or roughness scan.

The separate coastal 8192/65536 height-cache benchmark was interrupted when
another Godot process appeared. Its new exclusive-runner guard stopped only
our own child; partial logs are preserved, but the required three alternating
pairs did NOT complete and no isolated timing claim or cache adoption follows.
The original cache sizes, four workers, headless polling and traversal limits
remain unchanged.

The separate partitioned support-FIFO candidate is NOT adopted. It passes
40,103 equivalence/bound/eviction assertions and six complete output-equal timing
pairs, but dense ratios were about 1.055 / 0.979 / 1.120 and mixed ratios about
1.037 / 1.082 / 0.910. Dense canonical calls fell only 900,158 to 895,960. The
original 16,384 dictionary-entry bound was retained, including policy state,
but FIFO rings add serialized storage and do not yield a repeatable speed win.
All reports and exact candidate sources are preserved as private experiments.

The isolated height-only extension-publication trial is not adopted. One
preserved serial cold pair on the same dense 16km seed92881/scale0.2 tile kept
all terrain/normal/metadata/features and 2,441,064 structure vertices exactly,
but structure time was 58.963s original versus 60.909s trial (sampled engine
private memory 354.9MiB, 500ms polling). Earlier 6,433 owner/mix checks establish
only output equivalence. A slightly faster terrain/feature stage does not
justify claiming faster dense first cuts or changing the production sampler.
Six private material-trial variants exceeded the unchanged 2048MiB engine bound
before their first capture; their observed samples were 2180.7, 2162.1, 2195.5,
2201.4, 2209.6 and 2050.5MiB. Failed source/log snapshots are preserved. They
include simpler arithmetic, staged preparation, branch-free numeric controls
and a single process-local cached-resource override; none is adopted or a
successful render. Milestones place the later failures after native material
binding, not source expansion. An unmodified same-site production render passes
the same bound (1177.7MiB sampled), but this does not isolate shader-only memory
or establish the underlying driver/compiler cause. Production shader files and
the test cap are unchanged. The separately developed retained-contact geometry
extension is the scoped production revision described above.

### Custom-scale visible arch guide (scoped integration verified)

Six default-rarity, normal-cavity-guard membrane sites were found over three
seeds at feature scales 0.2 and 2.0. A native maximum-scale return exposed a real
defect: the conservative deep LOD footing was also used as the visible curve's
endpoint, pulling its midpoint wall into walking space on sloping terrain.
At seed 17 the deep endpoint is 107m below the canonical endpoint surface.
The failed native diagnostics and full exact worker payloads are preserved.

A private trial separates canonical-minus-8m visible curve guidance from the
unchanged explicitly buried final ring/cross-section. It passes 85,853 six-site
array/normal/triangle checks plus independent closed topology, complete
blade/strut attachment and native collision tests. The historical overlap-based
backface fixture ceased to exercise a negative control; its failure is preserved
and deliberate inside-to-outside native rays now exercise that policy directly.
No collision tolerance was relaxed.

The correction is integrated behind independent `hive_surface_guided_roots`
(default true); false retains the old curve independently of ribs/membranes.
All three maximum-scale actual 240m capsule returns pass with complete streamed
14,304-vertex junction/membrane matches, unchanged capsule/speed/gravity, no
unsupported drop and 8.14–15.07m canonical-to-overhead clearance. Sampled private
engine memory was 382.8MiB at 500ms intervals, not a certified peak.
Those pre-LOD maximum-scale reports remain historical. All six current
navigation-admitted minimum/maximum-scale returns now pass with complete worker
payloads and unchanged physical limits; the full post-guide/LOD checkpoint is
being refreshed. See the explicit rejected-site distinction below.
All cave phases remain unimplemented and queued in the user's requested order.

### Distant conduit LOD (registered, scoped refresh verified)

The minimum-scale seed 92881 cut exceeded the unchanged 180s preload budget
both in the three-seed fixture and in a fresh engine. Preserved progress showed
the bottleneck in numerical coarse structure tiles, not a backed-up upload
queue. One unfinished 16km tile contained 2,441,064 structure vertices and
1,344 conduits. Increasing the height-only cache from 8,192 to 65,536 entries
saved only about 2.2% while increasing retained serialized metadata from 175,348
to 1,524,724 bytes; it is not adopted. An exact repeated-sample reuse trial also
showed no meaningful dense-tile timing gain. Six-worker and slower-headless-poll
trials still timed out and are not adopted. Production keeps four workers and
the original 1ms headless preload yield; no timeout or view range was raised.

The Alien brief explicitly requires distant organic mesh simplification.
`lod_biome_extension_structures.gd` now wraps the existing numerical producer.
Every conduit path and complete blade/membrane/carapace landmark remains.
Full near arrays are unchanged. A conservative distance bound includes all
geometry extending outside its owner and uses the minimum supported split
ratio, not an optimistic camera location. Distant conduits retain every second
or fourth original longitudinal sample; exposed positions and material controls
are not moved. Constant buried far footers use an analytic lower bound on the
supported pure-Alien terrain, so their entire edges remain below all terrain
chords. Unsupported mixed-owner/coastal/noise configurations retain exact full
detail rather than assuming the same bound. `hive_structure_lod_enabled=false`
restores complete original full-detail arrays independently of other controls.

One preserved private cold pair reduced the actual unfinished tile from
64.206s / 2,441,064 vertices to 21.844s / 1,111,032 vertices. It kept all 1,344
conduits and all 528,768 non-conduit landmark vertices/normals/colors/UVs exactly.
This is a single numerical pair, not a general speed claim. The private real
streaming prototype completed all 159 leaves in 173.076s; refined tiers completed
them in 121.538s, with sampled private memory 945MiB (500ms polling, not a true
peak). Both used four workers, the original 1ms yield and full 50km hierarchy.

The registered controller additionally keeps the existing 8MiB/32-entry memo,
qualifying entries by detail/foundation profile. Cold/warm near/far/near arrays
match the independent prototype, real memo hits occur and no far-footer state
leaks into later landmarks. Three actual 4km seeded tiles pass complete disabled
mode equality, exact landmark attributes and parent/four-child conduit identity
and landmark-world-vertex retention. The controller is registered in actual
worker dispatch, not a visible-only substitute. Broader mixed/coastal LOD,
broader performance and artistic sign-off remain open. The declared current
native views and cache workloads are refreshed in checkpoint cd48ab11a900 above.

Production minimum-scale streaming now reaches the formerly timing-out site,
and the membrane there has 37.34m native floor-to-ceiling clearance. Its original
fixed approach nevertheless fails before the first waypoint: an embedded
initial capsule, 4.249m unsupported drop and a 47.862-degree native starting
triangle exceed the unchanged 45-degree floor limit. A curved native-probe path
also failed actual capsule motion. Neither attempt is counted as successful;
the failure/source copies remain immutable. Initial drops now count even before
waypoint zero. The current canonical triangle is still too steep: terrain was
not flattened to make the test pass.

Separate navigation discovery retains the original geometric manifest and
records every rejected candidate. It keeps five original sites, selecting a
different seed92881 minimum-scale root with a sampled low-grade approach.
All six separately navigation-admitted current production 240m capsule returns
pass at feature scales 0.2 and 2.0, with all 14,304 landmark vertices matched.
The serial minimum-scale process sampled 962.2MiB private memory and the maximum
396.9MiB (500ms polling, not true peaks). Admission also passes independent flat,
blocked-centre, steep-slope and missing-floor controls without moving the actor
during planning. This is six declared navigation-admitted routes, NOT a repair
of the original rejected site, uninterrupted streaming, arbitrary-settings or
whole-world navigation acceptance. The declared full source-guarded regression,
render and native cache-profile refresh passed in checkpoint cd48ab11a900.

## Attachment and material continuity — detailed evidence

An actual committed Alien preview cut exposed a canonical-height-only attachment defect: 352 of 663 old conduit-margin samples floated above sparse visible ground, by up to 41.95 m. Worker-generated lateral foundations now end below the minimum triangle chord across the configured near/far mesh lattices, with 32 m burial. Their new geometry is kept outside reserved finite-cavity/spiral/gallery approaches; original conduit crests and the canonical terrain field are unchanged. The focused test passes 45,206 checks over three real networks and default/custom grid spacings, including independent triangle planes, 392 feet, 2352 protected-volume triangle checks, exact disabled-mode geometry and unchanged Crystal/Insect arrays. A refreshed native cut samples 397 new explicit feet across LOD1–3, with zero exposed and a maximum clearance of -31.999998 m. This is a different topology/sample set, not a point-for-point 663-sample comparison or a whole-world certificate.

The first ground-derivative apron normals failed the outward-face integration check. They were replaced with smoothing of the actual attached shell, retaining hard folds where smoothing would leave the outward hemisphere. Every vertex now gets a finite/unit/outward check; crystals keep exact hard facets. The integration result before adding source guards was 609,553 passing checks. Terrain and shells now share `biological_sampling.gdshaderinc`, including signed local-origin phase, antitiling and distance filtering. Alien tissue layers and roughness blend with the same .25–.75 regional interpolation as the CPU landforms instead of switching abruptly at rounded region IDs. The native medium view visibly loses its former sharp kilometre-scale colour bands, but smooth distant geology, thin mesh joins and the broader scenic targets remain unfinished. Nine real projection comparisons pass at signed near/far chunk origins, as do four tissue-boundary continuity comparisons with detected legacy hard-switch controls. A discarded zero-origin/global-coordinate fixture introduced out-of-chunk float interpolation error; the valid test uses actual 256 m / 4096 m chunk-local coordinates and explicitly indexed panels.

The foundation CPU cost is real. The first three-seed/three-rotation cold-builder measurement was attached/cached median 113.505 ms, attached/original-path median 121.141 ms and legacy-unattached median 4.266 ms for the same individual conduit endpoints. These exclude resource creation, protected-site enumeration, workers, streaming, GPU and physics, and are not a startup benchmark. A bounded 512-cell cache now reuses immutable network path geometry; 26,240 checks establish exact original field/network/control and near/far mesh/water/atlas outputs over three seeds and three feature scales, eviction/order invariance and used-sampler reconfiguration. The cache is a modest local improvement, not a resolution of the added foundation cost. Native material controls and the shared 31-script suite passed on that shader/geometry revision. Subsequent benchmark/report revisions retain their own hashes and raw timings. The existing regression-report filename is retained for consumers, but its date and completion UTC now reflect the actual run.

## Active continuation — rooted hive junctions and walking shoulders

Rare hive-junction landmarks now grow at actual admitted nerve-network intersections, not random scenery points. `hive_junction_frequency` defaults to 0.12, with 120 m reference height and 75 m width controls; actual height varies with the existing deterministic maturity descriptor. Two bowed structural blades and a closed curved root strut follow the existing network's directions. The strut's shoulder is inside the primary blade and its far root ends below all configured terrain lattices. One half-open root owner emits the whole structure, independent of LOD. The reserved finite-cavity exclusion now includes the full four-width root-strut reach. No cave entrance or new underground engine is implied by the open exterior ground passage beneath it.

The current closed-mesh test passes 321,376 checks over three seeds and minimum/default/maximum feature scales, including 56 buried root vertices per junction, exact configured height, tissue controls, outward/unit normals and two-face edge incidence. Admission/zero-rarity/reference-switch/protected-site/parent-child comparisons pass 27 checks at three actual default-rarity dry sites. Native Jolt ray tests compare the highest visible triangles independently and stage/activate/release the exact worker mesh. The first physics fixture compared ideal local x/z to a rounded float32 world query, causing a spurious 0.156 m discrepancy on steep faces; using the actual query coordinates reduced the observed maximum to about 1.46 mm without relaxing the 3 cm tolerance. The recorded shape version and ray results remain source-specific.

The original two-blade revision is preserved in `tools/biome_extensions/artifacts/revisions/alien_20261019_b55c457d1bc6/` (163 verified source/evidence copies, nine native views, full shared regression). Its isolated paired junction overhead had median 11.03 ms and mean 15.64 ms, with noisy negative and positive samples; grouped medians alone incorrectly suggested no added cost. The profiler now reports actual per-seed/repetition deltas. Later strut/shoulder revisions have separate geometry, timings and captures and must not borrow that checkpoint's completion status.

Actual production walks found a real old conduit obstacle: a roughly 67-degree exposed shoulder just above nearly flat canonical terrain. Two early failures were waypoint-height errors (targets inside the solid conduit); those targets now use measured physical support without moving the walker. The remaining failure was a real `Structures` collision, normal y approximately 0.397 versus canonical normal y 0.987. The attached conduit cross-section now uses squared-sine rise and a consistent buried shoulder level. It retains exact ridge crests and deep outer footings while removing the half-ellipse's vertical tangent at exposed margins. The original shape remains available only through reference switches. The isolated twelve-profile test passes 3476 checks, detects 374 legacy steep faces and compares 1300 exact crest vertices. The three unchanged 240 m return routes now pass with the same 1.8 m / 0.4 m capsule, 5 m/s speed, gravity, 45-degree floor limit and 0.75 m drop threshold. Ground-to-strut overhead clearances were approximately 55.8–85.7 m; observed unsupported drop was zero. Preload pauses and only one to three committed cuts per route mean this is not uninterrupted streaming or arbitrary-world navigation certification.

A suspected lighting issue was rejected after reading the instantiated scene basis: saved sun emission is approximately `(0.289, -0.788, -0.544)`, already downward, with an upward-plane light dot of 0.788. The scalar serialized transform had been misread; **the main scene, sun, sky and fog were not changed**. Godot emits directional light along [negative local Z](https://docs.godotengine.org/en/4.6/classes/class_directionallight3d.html). Junction review retains its original three views and adds the opposite sun-facing view per seed, rather than relighting the scene. The final twelve-view/corrected-shoulder performance, regression and source/pixel-guarded follow-up refresh is running. Full surface reference-quality acceptance and all later infinite-cave phases remain unfinished.

## Active continuation — linked Tropical cascades and surface materials

Tropical now has rare rocky tributary steps controlled by `waterfall_frequency` (default 0.12) and `waterfall_drop` (30 m reference). These use the existing finite tributaries, canonical bed/water field and `terrain_features` foam material. They are **stepped cascades, not detached free-falling waterfalls**. Retained pools on those branches move below the lip. The initial 32 m step failed the water-profile test through cubic overshoot; its replacement is a 128 m geological step, and mesh admission rejects any dry or reversed profile. The 971-check three-seed suite admits nine real cascades, checks canonical wet beds, strict monotonic sampled water profiles, half-open ownership, identical cross-LOD profiles, no solid-water collision, bounded caches and six exact disabled-mode terrain/water/atlas comparisons against the pre-cascade sampler. Existing Wise waterfall and Tropical invariant tests pass, and settings isolation now passes 707 checks.

Nine native medium/aerial/ground views across three seeds verify actual production-worker/staging foam batches. The regular Tropical preview workflow additionally has `rocky_cascade` and `volcanic_tropical_transition`; its twelve-view audit checks source/pixel hashes, complete cuts, real owner weights, staged foam and the common mapped-normal diagnostic. The old dry `waterfall_ledge` remains explicitly unrouted and unrendered. Preview generation clears all other owners in its private fixture, leaves the user's saved preset intact, and no longer calls the live Volcanic biome a queued dependency. Contact sheets size themselves to the actual feature count. Ground review cameras point toward their target and record/assert their actual committed position. The shared 31-script suite passed after these preview changes and again after the Alien geometry/cache changes; subsequent shaders retain their own revision checks. These scoped results do not confer full Tropical artistic, traversal or performance acceptance.

The surface-addition colour/normal follow-up is preserved under `tools/biome_extensions/artifacts/revisions/material_controls_20261018/`: five guarded native reports, 36 audited full-scene captures and declared source snapshots. Both renderer swatch tests have zero measured authored-colour error and detect eight wrong-space controls. Eight real dry near-ground scenes show zero normal-off/zero-strength pixel error; the first radiation-crater fixture was rejected because it floated over submerged distant ground, then replaced by a genuine dry rim. A later eight-biome 32-view sweep also passed. The common extension material no longer uses 96 m enlarged PBR normal relief or a 5 m procedural bump amplitude on soils. The visual change in the mixed Tropical/Volcanic view was smaller than expected, so compound shading/water and remaining geometric simplification are still under review. Subsequent Tropical/worker changes retain their own source versions; the material checkpoint is not relabelled as current whole-project completion.

## Active continuation — Badlands geology

Current validated Badlands checkpoint: `tools/badlands/artifacts/revisions/f87632d9c49f-41b8e123/` preserves **79,846 assertions, 186 source/pixel-checked captures at 31 locations**, the 31-script shared regression, current GPU checks, paired numerical builds, native benchmarks and the complete 2.74 km / 27-cut return walk. The first attempt at that walk was incorrectly launched with rendering: it exhausted the three-minute harness limit at waypoint 56/201. The corrected headless fixed-step run completed all 201 waypoints using unchanged capsule, speed and gravity, with a maximum unsupported drop of 0.0735 m and declared preload pauses. Native Badlands scene/first-cut time was 30.216 s, settled static GPU median 11.686 ms and fast-travel maximum frame 49.359 ms; this is not cold-cache startup or uninterrupted streaming certification. Full reference-quality acceptance is still false.

Subsequent surface-addition correction: a native swatch fixture reproduced unconditional-gamma errors in all eight authored extension tints and actual mesh vertex-colour inputs. Extension terrain now uses the existing renderer-aware colour helper, and opaque structures use the same exact transfer rule. Both Compatibility and Forward+ swatch tests pass, detecting all eight deliberately wrong-working-space controls. The full Forward+ terrain is not certified. Volcanic microrelief now respects its normal-strength setting; all extension outcrop/meso relief also respects explicit normal-off diagnostics. Eight actual production-scene normal-control checks and a Tropical/Volcanic native transition review are running. These later shader changes supersede the older extension captures; the archived Badlands checkpoint remains tied to its own full source hashes, including its shared-regression snapshot.

Fine sediment bedding now uses the continuous geological coordinate, with unequal subordinate laminae and derivative filtering before subpixel scale. It adds no texture, varying or mesh allocation. The native normal comparison caught a real control defect: procedural bedding/weathering relief ignored the common normal-off/detail factor even though sampled and ambient normals respected it. The production gradient now respects that factor. With the original tolerance unchanged, all four native region comparisons pass with **zero measured pixel difference** between normal-off and zero Badlands normal strength. The current complete 186-view sweep, benchmarks and route refresh are still running; they are not yet completion evidence.

The work-count diagnostic (`profile_cache_reuse.gd`) sampled nine actual inland near/middle/far builds. It observed no drainage-tree cache flushes: cold tree builds ranged from five to 169 per fixture. Far fixtures did flush the regional cache twice. These instrumented elapsed times are not benchmark results, and the evidence does not support a speculative tree-cache rewrite as the startup remedy. The new Tropical/Volcanic transition fixture separately passes 2204 numerical checks over three actual inland overlaps, preserving both owners' numeric payloads and adjacent height/normal/water seams. Its native mixed-scene review is still pending; the user's saved coverage is untouched.

Active regional-hill follow-up: `rounded_hill_strength` adds province-specific physical undulation to painted, gray/bentonite and selected pale/stratified clay uplands, before the same connected valley envelopes cut them. It does not add surface noise to every province. Zero strength reproduces the previously validated complete mesh/water/atlas output in six near/far comparisons across three seeds; 620 focused checks pass. Current partial native review covers actual regenerated painted/clay sites. This new geometry is **not yet** covered by the preceding full render/benchmark package. The validated 79,224-check / 186-capture revision is preserved with its declared source snapshots and PNGs under `tools/badlands/artifacts/revisions/c5a47df51a52/`; its main report remains historical by its recorded source hashes. The core invariant and full current-revision follow-up still need refreshing.

Native collision precision: the first new landmark check incorrectly assumed neighbouring tiles all used the camera tile's 2 m grid. After checking actual committed mesh vertices instead, it found a real maximum 0.166 m mesh/physics discrepancy on steep terrain. [Godot 4.6 requests zero-error Jolt heightfields](https://github.com/godotengine/godot/blob/4.6/modules/jolt_physics/shapes/jolt_height_map_shape_3d.cpp), but its [bundled Jolt 5.4 implementation caps samples at eight bits](https://github.com/jrouwe/JoltPhysics/blob/v5.4.0/Jolt/Physics/Collision/Shape/HeightFieldShape.cpp). Worker collision preparation now estimates the block/global quantization bound: flat near tiles retain heightfields, while steep near tiles use exact visible surface triangles, excluding skirts. Distant terrain does not gain collision. Shapes remain inactive until cut commit and clear on release.

The precision regression passes 112 assertions, including 98 positive fixture rays and 49 deliberate old-heightfield control rays; the latter reproduce approximately 0.20 m error. The production landmark test passes 250 canonical/mesh/physics checks over 125 rays at five actual hill/ridge/caprock/basin sites. Maximum observed mesh/physics error in the pre-hill checkpoint was 0.001408 m; the same 250-check suite has also passed on the current hill geometry. This is not an arbitrary off-grid or all-world seam certificate. The checkpoint's 2.74 km wash return walk passed through 27 committed cuts, with a maximum unsupported drop of 0.074 m and declared fixed-step acceleration/preload pauses; its current-geometry refresh is pending. The shared 31-script regression passed on the hill revision before the normal-off shader correction, so its recorded source hashes remain specific to that revision. An interim follow-up file was explicitly invalidated after its stale-source guard fired; the report writer now refuses to write after any nested source-validation failure.

Newest geometry revision: second-, third- and fourth-order tributaries now fan from their actual parent direction with unequal spacing, angles and reaches, rather than sharing world-axis-aligned twig vectors. Catchment admission uses precomputed supported valley/fan bounds and a conservative neighbour radius instead of the fixed root-distance cutoff. A separate unbounded eleven-tree reference passes 3375 exact all-channel comparisons over three seeds, three relief scales and minimum/default/maximum drainage spacing. Earlier numeric/render/flow counts below are historical where their source hashes differ from this revision. Full current-revision acceptance is still running, not complete.

An interrupted 186-view sweep was deliberately stopped after its ground-camera framing proved misleading; its partial checkpoint is not completion evidence. Only the identified test PowerShell and its two native Godot children were stopped; no editor was targeted. Preview hill selection now requires actual relief and surviving elevation, rather than accepting a province's flat wash floor. Ground-camera search measures intervening terrain, prefers usable foot slopes and records/asserts the actual committed camera position. The revised locator and cameras change the evidence, not the generated landforms. A controlled ledges-on/off ridge profile found at most 1.77 m displacement in that earlier revision and did not identify thin-bed displacement as the primary repeated-silhouette cause.

Latest continuation (supersedes the older counts below): caprock now has narrower surviving tops and unequal joint-guided bays, rather than broad cylindrical mesa profiles. The current caprock test has 194 assertions; counts vary with the actual wall/LOD samples admitted after morphology changes. Local remnant skirts extend by the actual added feature height, without adding collision walls. Compact-edge and mixed-owner sparse-normal checks are part of the standard Badlands runner. The local mesh selector now also refines LOD1 caprock to 8 m, with nine selection checks; disabling remnants restores the old density.

Sparse Badlands normal probes are scheduled beside their centre samples to retain hot raw nodes. Complete terrain, numeric-atlas and water-array hashes are compared against the original scheduling; a separate test includes actual nine-slot Badlands/Quarry mixtures and a Quarry-only control. A conservative endpoint-grade bound rejects cuts that cannot change the current terrain before projection/power evaluation. Indexed/bounded and full-scan/unbounded raw fields remain exactly equal in 2070 comparisons. The paired benchmarks show only a modest distant-build improvement (about four percent in the first three-seed runs), not a general startup-performance solution or a measured near-build improvement.

The drainage diagnostic now follows the actual canonical downhill field, rather than interpreting a descriptor's direction as water flow. Of seven fully incised net-reversal cases in the sampled 240 descriptor profiles, five traced into a primary wash or retained basin. Two encountered shallow local depressions: sampled escape-ring elevations were roughly 0.2–0.3 m above the local low before reaching lower surrounding terrain. These are not blocked deep ravines, but depression-free hydrology is **not** claimed. This diagnostic deliberately is not an acceptance test or hydraulic simulation.

The full shared 31-script regression has passed again on this continuation's frozen production revision. A fresh native GPU/render/benchmark/streamed-route run is in progress; earlier full sweeps and performance numbers below retain their historical source hashes. The capture harness now records the actual bound shader debug mode and asserts the UI-to-shader Badlands mapping. Caprock ground cameras use an existing sunward foot-slope point, without changing scene lighting or the generated landform. Resistant caps now retain their geological colour on horizontal tops instead of inheriting the source soil/lichen tint solely because slope is zero.

An ownership defect was found in the controlled drainage comparison: `duplicate(true)` retained externally saved biome resources, so changing one test configuration also changed its comparison. Production scene/worker snapshots and active test fixtures now use `duplicate_deep(Resource.DEEP_DUPLICATE_ALL)`. These configurations contain scalar settings, not the shared texture arrays. The ownership test passed 702 assertions, observing four actual production builders and all sixteen nested resources, without changing the saved preset. This behavior and the explicit external-resource mode are documented in [Godot 4.6 Resource](https://docs.godotengine.org/en/4.6/classes/class_resource.html#class-resource-method-duplicate-deep). Earlier controlled A/B comparisons are not treated as fresh evidence without rerunning them with isolated fixtures.

Native colour testing found that the unconditional `pow(band, 2.2)` was wrong for this project's Compatibility renderer. The production helper now keeps authored sRGB there and uses the exact transfer function in linear-working renderers. Eight geological swatches match `source_color` textures with zero measured RGB error in each of actual Compatibility and Forward+ tests; both detect eight renderer-aware wrong-space controls. The first Forward+ test incorrectly demanded that the old approximate gamma be a large error in a linear renderer; that negative-control assumption was corrected, not counted as a production failure. The full terrain is still tested in Compatibility, not claimed Forward+-certified. See the [spatial built-ins](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html) and the [4.6 Compatibility shader's post-fragment conversion](https://github.com/godotengine/godot/blob/4.6/drivers/gles3/shaders/scene.glsl#L2025).

The isolated clay test now finds six actual inland secondary incisions per seed across three seeds. Low-relief clay uses scaled drainage grades instead of a threshold that excluded pure clay. Hillslope tributaries are denser and remain rooted on their parent trunks; erosion strength controls valley width rather than repeatedly blending shallow dents into an otherwise uncut plateau. Rugged regions get local 64 m distant-mesh targets; calm regions and disabled/other owners keep their existing density. Soil texture shadows are no longer magnified sixteen times across clay hills, and ambient cliff weathering is restricted to steep exposed non-clay rock. The current 24,744-check invariant result includes the denser drainage graph; current native review and profiling are still underway, so these changes are not a completion claim.

Compact caprock is now composed continuously after the 16 m background erosion lattice, avoiding the earlier rounded/overshooting cubic remnant profile. It has unequal joint ribs, steep upper walls and a separate low apron, with caps still solved onto resistant beds. Only actual remnant vertices use local two-metre normal probes; the background and disabled presets retain their previous normal construction. The 254-check caprock test includes sixteen actual placements, 65 wall normals compared to canonical derivatives, and 120 shared 4 m / 8 m LOD normals. A separate seven-check selection test verifies local 16 m LOD2 caprock sampling and that disabling remnants removes that refinement. No detached caps, true undercuts or separate rock props were added; those are not claimed as part of the supported heightfield approximation.

The complete 31-script shared surface regression now passes with current source hashes. Its older settings test was modernized from retired Desert/Snow/Stone ownership properties to all sixteen actual owners. The island-scale test explicitly isolates inland landforms from the later shore-distance overlay. Long capsule routes use declared fixed-60-Hz acceleration, preserving speed/gravity; their output is physical-route evidence, not wall-clock performance. A whole 186-view review previously reached its 900-second harness limit, not a successful audit. The rerun now saves source/pixel-checked checkpoints and has a suitable total sweep allowance while retaining per-streaming-cut timeouts.

The next continuation revises the unfinished Badlands, before advancing to later cave phases. Its geological coordinate now has broad varying dip/folds and unequal hard beds instead of one identical band per 84 m. The same production shader functions passed 63 native CPU/GPU comparison cases and detected an intentional negative control. Connected fourth-order source gullies and region-dependent convex valley walls are being evaluated in native renders; these are not a visual completion claim.

Badlands exact-node publication now duplicates cached arrays; a 16,384-node FIFO retains recent samples during eviction. A separate bounded 1024-cell cache stores the existing cubic stencil's polynomial coefficients and four control corners. The independent direct-stencil test confirms exact height/water equality, alongside cache ownership, ordered beds, settings controls and connected sources: **3042 focused assertions** across three seeds. The updated Badlands invariant suite passed **17,544 checks**, including pre-Badlands disabled-preset full-array hashes, adjacent/LOD seams, drainage graph connections, mixed payloads and retained water. These counts are separate from the earlier 220,308-check snapshot.

Additional continuation changes now include smooth fine-gully eligibility instead of regional thresholds, conservative indexed drainage lookup (2070 exact full-scan comparisons across three seeds and three relief scales), and varied terrain-supported remnant profiles whose caps are solved onto resistant beds. Sixteen actual inland caprock placements passed after a narrower-shoulder test exposed interpolation overshoot; these remain heightfield-scale remnants, not true undercut hoodoos.

The existing numeric control atlas now carries continuous clay/plain/red/pale geological weights, avoiding color selection by a blended numeric region ID. Pure Badlands tiles allocate one RGBA8 slot (four bytes per vertex), while affected extension/Badlands mixtures use nine slots (36 bytes per vertex); extension-only tiles retain eight. No new texture sampler or varying is added. The liquid consumer uses the actual atlas row width and active extension mask. The failed first native test caught its former fixed-eight-slot assumption; that defect was corrected, not counted as a pass. CPU transport/preservation tests passed 43,568 checks and GPU bilinear checks passed 126 positives plus two detected negative controls. The production geological functions also pass at height multiplier 2.25 and sea level 17.

A real production-streamed wash walk has passed 201 waypoints, 2.74 km out and back, through 27 committed cuts using the declared 1.8 m capsule. The first three-minute real-time harness timed out on a roughly nine-minute simulated route; fixed 60 Hz acceleration completes it without changing 5 m/s speed or gravity. Preload pauses and a Jolt job-capacity warning mean this is collision/route evidence, not uninterrupted runtime performance certification. Fresh native captures and benchmarks are being regenerated after the final palette/caprock revisions.

The previous whole-queue report and its 143 captures describe the source hashes saved in that report, not the new Badlands/mesh-builder revision. Current native visual review and repeated profiling are still in progress. The strict implementation order and all later cave gates remain unchanged.

## Further continuation — routes, ramps and fungal ecology

The current follow-up report is `data/biome_completion_followup_20261018.json`; the earlier report below retains its own historical source hashes. **Surface reference-quality completion and both requested underground systems remain unfinished.** No cave-biome inspector definitions are being presented as completed caves.

- Full native capsule walks exposed blocked entrances/returns that gallery-only rays had missed. `terrain_feature_meshes.gd` now uses a conforming approach apron, a lowered lip only at that crossing, and a finer 192-segment rim with vertical shell overlap elsewhere. Twelve complete surface → spiral → gallery → spiral → surface walks passed across seeds 73921, 17041 and 98123, covering four cavity families. They use a declared 1.8 m capsule with 0.4 m radius, 5 m/s walking, gravity and floor snap, without jumping or route teleports. Initial spawn settling is separate; measured unsupported route drop was zero in these fixtures. The accelerated fixed-step harness sometimes emitted a Jolt job-capacity warning. These remain constructed finite shafts/galleries, not natural deep caves.
- `check_streamed_roundtrip.gd` repeats a complete Wise fixture journey through **actual production worker jobs, staging, caches and collision cut swaps** with the full LOD6 hierarchy. It passed 776 waypoints through 25 committed cuts without an unsupported drop. The test walker waits for replacement cuts to preload; this is collision-continuity evidence, not uninterrupted frame-time or all-world traversal certification.
- Quarry access had a real integer-topology defect: locally warped radius changed the ramp turn count midway around an excavation. Its replacement is descriptor-stable, reserves a world-space graded corridor after canonical field interpolation, and joins an endpoint outside the excavation blend. A conservative ownership-clearance test excludes routes that would cross another excavation's cell. Eight admitted inland routes passed canonical and exact triangle-interpolated 2 m / 4 m centreline grade tests under the default 10% setting. This is not exhaustive capsule, mixed-owner, custom-scale or all-quarry acceptance; other quarries may have no admitted access ramp.
- Collision staging now consumes worker-retained numeric heights and faces. It no longer requests terrain/structure/cavity arrays back from uploaded render meshes; the duplicate cavity-only render upload was removed. Workers still do numerical work only, not SceneTree mutation. Three ordered Alien diagnostics measured commit p95 values of 5.299 ms before versus 4.144 / 3.584 ms after, but a **51.874 ms collision-staging outlier** occurred in one later run. Those runs preceded the latest fungal/rim revisions and are not a randomized benchmark or proof that stalls are solved. The new per-phase profiling distinguishes surface upload, extra resources and node/collision staging.
- Spore ecology now unions overlapping irregular colonies and stable owned connecting corridors rather than selecting one nearest blob. Colony structure contributes to physical mound relief and continuous fungal coverage. Rare luminous potential is tied to those descriptors and the actual `luminous_frequency` control, instead of an unrelated shader hash. Three-seed tests verify deterministic overlaps, bounded fields, no luminous signal at frequency zero, and unchanged geometry when glow is disabled. No mushrooms, vegetation, spore particles, weather or gameplay were added.
- An original, sparse branching fungal albedo was generated with the built-in image tool and saved non-destructively as `assets/textures/biological/mycelium_albedo_v2.png`. The previous texture/array remain available. The production array is `materials/biological_colors_v2.tres`, with the same 11,184,864-byte four-layer BC1 mipmapped budget. Native source resolution is **1254×1254**, resampled offline to 2048×2048; this is not a photographed PBR scan or native 2K generation. Exact prompt, source hash, method and previous revision are in `data/biological_material_sources.json`. Mirrored/rotated sampling makes fungal border colors continuous without claiming that the generated source's opposite pixels are identical. Native GPU readback checks compare decoded source colors, allowing small driver BC1 decoding differences.
- Regional tint now follows the sampler's continuous regional blend instead of quantizing whole landscapes into hard color stripes. Active material-bank/roughness details still use selected material families; complete material/reference fidelity remains open.

The latest numerical/physics suites total **220,308 assertions with no failures**, including 160,701 integration checks, 1221 spore-ecology checks, 25 quarry-grade checks, 48 static round-trip checks and six actual-streaming route checks. Counts are test scope, not percent complete. The final sequential audit verified 143 current-source native captures; this is integrity evidence, not artistic sign-off. Across those views, GPU frame medians were 4.136–13.203 ms, initial fill 5.181–123.903 s, maximum recorded streaming wait-frame 163.333 ms, and reported video memory 380,901,285–547,217,713 bytes. Startup and streaming stalls remain unresolved. Full scope and limitations are in `data/biome_completion_followup_20261018.json`.

## Earlier continuation evidence

- Added `scripts/terrain_feature_meshes.gd`: finite worker-generated dry-site cavities, independent lava/organic pool surfaces and waterfall sheets, owned by the existing complete-cut transaction. Surface openings use the same irregular radial boundary in the terrain shader and clipped near-ground collision. Near portal collision faces are generated in the worker; normal unaffected tiles retain HeightMapShape3D. Floors, walls, ceilings and the short gallery have actual concave collision. The bounded regional query and half-open owner rules preserve stable placement.
- Cavities currently occur in Wise Mountains, Volcanic, Insect Colony and Alien-Infected when dry sites have sufficient cover. They contain a broad shaft, sloped spiral access and a closed short underground gallery. **These are finite prototype cavities, not an infinite interconnected cave system or completed deep brain chambers.** Gallery ray/capsule tests do not certify a complete surface-entry-and-return journey. Their natural appearance, roof/rim matching across all LODs and full entrance traversal still need acceptance work.
- Dedicated `shaders/terrain_features.gdshader` renders clipped retained crater lava, separate organic pools and a connected Wise tributary waterfall. Actual basin profiles, rim checks and shoreline bisection determine the liquid meshes; freshwater is not repainted. Active craters exclude retained freshwater. These are static basin surfaces with animated shading, not a flow simulation; lava coloration/shoreline fidelity and waterfall presentation remain visual-quality gates.
- `shaders/crystal_transmission.gdshader` adds facet-dependent **screen-space** refraction, Fresnel response and absorption. This is not physically complete internal ray tracing; off-screen/transparent-object limitations remain.
- Wise pillars have steeper joint boundaries and physical ledges. Insect mounds have more rings/sides, weathering and constrained smooth normals. Alien surface conduits now follow side-ground elevations with lower arches instead of exposed deep sidewalls. Terrain and Badlands shading add metre-scale geological relief beyond fine normal maps; fungal coverage is patchier. Dedicated volcanic procedural surface variation is added, not misrepresented as newly acquired scans.
- Radiation fallout now follows a coherent configurable downwind direction, separate from physical event damage and age. Outlet-connected drainage cuts and local alluvium are separate from fallout deposition. These remain bounded analytic approximations, not erosion/transport simulations.
- Quarry ramp construction reserves wider paths and a conservative grade margin; final interpolated-mesh grades are not yet comprehensively certified. Mixed far leaves now consider sampled extension influence for refinement, rather than requiring one pure owner.
- Exact-lattice samples now return their canonical node directly; bounded FIFO node eviction replaces whole-cache clears. Visual review caught a new shared-array aliasing bug in that fast path: fractional publishing could mutate a cached node. The published state now duplicates the node, and `check_sample_alias.gd` checks canonical immutability plus independent dense fractional height/normal seams. Earlier captures/timings from the faulty fast path are not current acceptance evidence. The corrected 16384 m / 64-resolution probe measured Alien 1366.392 ms and Insect 1148.013 ms, versus pre-fast-path probes of 2973.247 / 1874.634 ms. Each far number is one cold build, not a repeat distribution. Current near builds did not consistently improve; all figures exclude feature meshing and collision upload.

New native probes live in `tools/biome_extensions/`: `check_features.gd`, `capsule_probe.gd`, `check_liquids.gd`, `check_waterfalls.gd`, `render_features.gd` and `render_regions.gd`. Four-second capsule traversals in four finite gallery fixtures passed after correcting inward-facing collision walls. Default-frequency liquid checks and connected tributary profile checks passed.

The corrected-source sequence now passed **210,288 assertions**: 48,392 terrain checks, 151,981 integration checks, 1056 alias/dense-seam checks, 36 finite cavity physics assertions, 8312 liquid checks and 511 connected-waterfall checks. The increased counts partly reflect denser actual geometry; they are not a percentage-complete measure. Native GPU transport passed 24 cases and detected the deliberate corruption. Existing Jungle, Forest, Savanna, Swamp, Mountain, Rocky Coast, Beach, Tropical and Badlands numerical/resource regressions and biological asset checks passed again.

**143 native captures were audited**: 32 representative extension views, two mixed-world views, 13 finite feature views including real gallery interiors and liquids by day/night, and 96 regional views (all six current major families in eight additions, by day/night). The audit checks core hashes, PNG hashes/dimensions and complete committed cuts; it explicitly does not grant artistic sign-off or infinite-cave acceptance. The normal source game passed both the all-additions Beach start (30.87 s, 117 leaves) and Alien preview (11.65 s, 153 leaves), including all five HUD/debug modes.

Across those views, per-view median GPU time was **3.95–12.81 ms**, VSync-limited median frame time 16.652–16.675 ms, and engine-reported total video memory 379–545 MB on the RTX 3060 Laptop GPU at 1280×720. Scene/first-cut fill ranged **4.90–110.77 s**, including cold shader compilation in the slowest scene; process launch is excluded. Measured streaming-wait frame maxima reached **129.70 ms**. Those startup and frame spikes, near-generation costs, visual simplification/repetition and full surface-entry/return validation remain open work. See `data/biome_completion_validation_20261018.json` for current-source hashes, exact test scopes and measurements. The 2026-10-17 validation JSON is historical, not current acceptance evidence.

Implementation references: Godot documents packed-array sharing and explicit copies in [the packed-array API](https://docs.godotengine.org/en/4.6/classes/class_packedfloat32array.html). Its [HeightMapShape3D API](https://docs.godotengine.org/en/4.6/classes/class_heightmapshape3d.html) describes the ordinary heightfield backend. Portal tiles instead use clipped triangle collision to match their visible openings more closely.

## Next request, explicitly ordered by the user

The Infinite Default Cave brief at `C:/Users/User1/.codex/attachments/7458d124-72ab-46a6-a2ae-7948bc3bfe6a/Pasted text.txt` was read in full and queued **after the current completion work**, not in place of it. It requires one default underground classification, finite configurable depth relative to canonical terrain, connected sparse 3D networks, geological formations, protected two-way player clearance and a real surface-to-deep-to-surface traversal acceptance test. The finite biome-feature cavities do not satisfy that brief. No special cave biomes, creatures or gameplay systems are authorized by that new brief.

The subsequent 3600-line cave-biome brief at `C:/Users/User1/.codex/attachments/70e7f071-07d8-4cdd-81bb-1a6211abed76/Pasted text.txt` was also read in full. It is queued **after that connected cave foundation**, extending the same network. It requests a generic resource registry with four independent controls (candidate spawn chance, region extent, five smooth relative depth weights and blended surface affinities), bounded environmental suitability, deterministic graph-aware overlap and Default fallback. Only Default Cave and Frozen Caverns are authorized for visual implementation. Initial Frozen settings are 45%, 150–700 m, depth weights 100/80/40/5/0; rarity must not shrink size, including the explicit 2% / 1000–2000 m test. Its full Snow → Default → Frozen → surface traversal, actual ice geology, frozen water, seams and performance gates remain future work. Snow is not a live owner in the current sixteen-owner enum; its actual climate/Snow integration must be inspected rather than inventing an ID or silently changing saved coverage.

The user then explicitly required every additional cave-biome brief to wait for all preceding work and be implemented **one by one in arrival order**. Crystal Caverns is additional biome **#1**, queued after Default/Frozen completion, from `C:/Users/User1/.codex/attachments/2695affe-9e18-4e55-8938-cddbc9c3333d/Pasted text.txt`. Its complete 3245-line source was read. Initial settings are 18% spawn, 350–1500 m extent and depth preferences 5/20/50/80/100. The source and all six reference-image paths are preserved in the project queue. This later authorization does not start Crystal ahead of the earlier gates or change the earlier two-biome phase into simultaneous specialized-biome development.

Magma Caverns is additional biome **#2**, queued only after Crystal completion, from `C:/Users/User1/.codex/attachments/a753d663-6646-4991-8a27-e9b50a41933d/Pasted text.txt`. Its complete 3123-line brief was read and its six reference paths preserved. Initial settings are 22% spawn, 300–1100 m extent, depth preferences 0/5/30/80/100, and surface affinities Volcanic 100 / Mountain Range 35 / Badlands 20 / Quarry 15 / Radiation Wasteland 15 / Desert 10 / Rocky Coast 5 / others 0. Identity must come from volcanic geometry and mostly cooled geology, with separate heat eligibility for rare molten basins and protected dry return routes. It has not been implemented or registered in the runtime; its full staged tests and visual/performance gates remain future work.

---

# Additional biomes — runnable first passes, not final visual sign-off (2026-10-17)

The user's later “make everything now” request prioritized implementing the whole remaining queue. Quarry, Wise Chinese Mountains, Volcanic, Spore Forest, Radiation Wasteland, Crystal Wastes, Insect Colony and Alien-Infected are now real integrated generators, not queued placeholders. **This is not a claim that the enormous photorealistic briefs or every listed scenic target are complete.** Badlands' earlier visual-quality gate remains open.

## Run and inspect

Run `powershell -File tools/biome_extensions/launch.ps1 -Biome all` to enable all eight additions alongside the saved existing-biome coverage, or select one of `quarry`, `wise_mountains`, `volcanic`, `spore_forest`, `radiation_wasteland`, `crystal_wastes`, `insect_colony`, `alien_infected`. Equivalent Godot arguments: `-- all-biomes`, or `-- biome=crystal_wastes biome-position=13061.21,-5790.354`. This launcher does not enable previously disabled old owners such as Badlands; the separate mixed-world test explicitly enables all sixteen. Inspector **Extension Preview** offers the same isolated biome previews. **Shift+F10** finds the next enabled extension; **Ctrl+Shift+F10** cycles ownership, regional identity, feature intensity, wetness and geometric-normal views. Existing shortcuts remain unchanged.

New coverage defaults to zero, preserving the saved world's layout. The all-biomes launch is an explicit runtime opt-in, not a saved-world overwrite. Eight dedicated settings resources expose their terrain controls through TerrainSettings. There is no ZIP, export, automatic commit, new weather, creature, foliage, particle or gameplay system.

`data/biome_extension_previews.json` records seed **73921**, an actual primary feature and all six located regional families for each generator. These are sampled procedural locations, not manually sculpted maps.

| Biome | Actual first-pass regional/structural support | Primary X, Z (metres) |
| --- | --- | --- |
| Quarry | Granite-like bedrock, limestone benches, slate highlands, sandstone excavation, basalt bedrock, gravel basins; irregular pits, unequal benches, selected winding ramps and rare retained pools | 10575.513, -2312.150 |
| Wise Chinese Mountains | Joint-separated sandstone pillars, granite-style peaks, limestone tower karst, weathered highlands, labyrinth regions and open carrier-river valleys | 13411.120, -5410.764 |
| Volcanic | Shield profiles, stratovolcanoes, collapse calderas, cinder fields, hardened-flow plains and ancient rift highlands; age/flow fields and rare crater water | -84496.656, -81424.148 |
| Spore Forest | Mycelium lowlands, colony mounds, pale crustlands, decomposition basins, rocky fungal uplands and dry residue; colony descriptors, moisture, retained ponds and selected emission | 15122.883, -4210.760 |
| Radiation Wasteland | Barren plains, blast scars, event-associated vitrification, mineralized highlands, wind-directed deposition lobes and dry mineral basins; contamination is separate from physical damage | 24950.973, 5780.648 |
| Crystal Wastes | Quartz plains, amethyst uplands, selenite-like blades, smoky ridges, fluorite-like blocks and mineral basins; real hard-faceted prism/blade/block clusters, tilt and broken tips | 13061.210, -5790.354 |
| Insect Colony | Cathedral territories, ant earthworks, magnetic-style clay blades, dome nests, abandoned colonies and rocky highlands; real fluted structures, supporting spires, satellites, shallow routes and spoil | 11406.625, -3068.074 |
| Alien-Infected | Assimilation fringe, nerve lowlands, carapace uplands, membrane sinklands, rupture regions and ancient tissue; connected hive-center/conduit/branch descriptors, actual surface conduits and independent partial-infection overlay | -47392.563, -46434.547 |

These geological names describe procedural appearance families, not verified mineral composition or simulation results.

## Integration and files

- `scripts/biome_extension_sampler.gd`: common fixed 16 m C1 field, worker-private 8192-node and 512-descriptor bounds. Each of the eight `scripts/*_sampler.gd` files supplies different actual terrain mathematics; each corresponding root `*_settings.tres` selects its controls.
- `scripts/terrain_mesh_builder.gd`, `scripts/terrain_settings.gd`: sixteen-owner hierarchy, canonical sampling, local-water integration and numeric mesh metadata. Existing four custom banks and UV encodings remain intact. Zero extension coverage retains the old complete mesh arrays exactly.
- `shaders/biome_extensions.gdshaderinc`, `shaders/terrain_biomes.gdshader`: sparse active-family material evaluation using shared PBR roles and a **numeric control atlas**, not unique PBR textures per tile. Atlas cost is 32 bytes per original grid vertex, no mipmaps, no allocation for unaffected meshes. Two added interpolators exceeded native GL limits during development; the corrected implementation adds **no interpolators**, sampling active numeric data directly in the fragment shader.
- `scripts/biome_extension_structures.gd`, `shaders/biome_structures.gdshader`: bounded combined crystal, earthwork and conduit meshes. Half-open root ownership is independent of leaf size. The existing complete-cut transaction swaps ground and structures together. No per-crystal SceneTree node or unbounded feature registry is created.
- `scripts/terrain_collision.gd`: actual near-leaf HeightMapShape3D collision, staged inactive and activated with the committed cut. Major nearby structure batches use concave collision; crossing structure bounds are considered independently of root-leaf LOD. Pooled nodes release shapes and mesh references. There is no cave collision or true underground space.
- `scripts/chunk_terrain.gd`, `scripts/free_camera.gd`: resource bindings, previews, locators, diagnostics, collision lifecycle and shared-material handling. Certified pure-extension rectangles can request local far refinement, capped at 128 resolution. The 50 km camera far plane and LOD 6 are preserved; mixed-region far leaves can still undersample narrow features.
- Reproduction and profiling scripts live in `tools/biome_extensions/`. Generated local evidence is ignored under `artifacts/`; production source textures and packed material resources are project files.

## Materials and provenance

Natural ground/cliff roles reuse **six distinct photographed ambientCG CC0 PBR sources** already installed: Ground026, Ground105, Rock055, Ground031, Gravel020 and Ground108, via the Savanna/Jungle/Mountain arrays. No external download was made. These are appearance analogues, **not dedicated certified granite/limestone, pāhoehoe, a‘ā, ash or obsidian scans**. Specialized volcanic and mineral material fidelity remains unfinished.

The image-generation skill was used to replace visibly repetitive shader-only fungal fibers and add a genuinely separate alien surface library. Four original generated albedos are saved in `assets/textures/biological/`: `mycelium_albedo_v1.png`, `nerve_albedo_v1.png`, `carapace_albedo_v1.png`, `membrane_albedo_v1.png`. The **built-in image_gen tool**, not a CLI/API fallback, was used. Full final prompts, SHA-256 hashes, methods and paths are recorded in `data/biological_material_sources.json`.

Generated sources are **1254×1254**, resampled offline to 2048-square production images, mipmapped and BC1-packed into `materials/biological_color_*.res`. One shared `materials/biological_colors.tres` array costs **11,184,864 GPU bytes**. Source PNGs remain unchanged. This is generated artwork, not photogrammetry and not falsely labeled third-party CC0. Roughness is material-specific; restrained apparent microrelief derives from albedo derivatives, **not a measured normal/height scan**. Texture-edge perfection and photorealism are not certified by the packing check.

## Measured validation

- **15,632 numerical checks passed**: finite values, height-only/full agreement, cache/order repeatability, C1 lattice behavior, adjacent height/normal/water/metadata agreement, canonical parent-child heights, cache bounds, sixteen-owner normalization and ten previous complete-array hash fixtures.
- **88,281 integration checks passed**: premultiplied atlas bounds, native physics rays at visible canonical vertices, inactive staged/released collision, exact world-space parent-versus-four-child structure multisets, clockwise facet normals, nonempty major geometry and partial infection independent of full-biome coverage. This is not a complete character-controller traversal test.
- Native GPU numeric transport: **24 positive cases passed**, and an intentionally corrupted bound atlas was detected. The test executes the actual atlas function extracted from the production shader. Maximum observed raw numeric RGB error was one 8-bit step.
- Final native review passed **34 current-revision captures**: eight biomes at ground/medium/aerial/regional views, plus two views of an actual old/new transition with all sixteen inland owners enabled. Audit verifies core source hashes, PNG hashes/dimensions, committed cuts and nonempty structure batches where required. These are integrity checks, not artistic acceptance. Inspection still shows smooth distant relief, repetitious fungal coverage, simplified insect towers and wall-like surface conduits.
- Two actual source-game launches passed with the normal FreeCamera/HUD active: saved Beach start with all eight additions enabled (40.10 s to smoke result, 117 committed leaves), and isolated Alien-Infected (26.59 s, 153 leaves). Each exercised all five extension debug modes, verified their HUD names and shader indices, restored shaded rendering and saved a native capture. This caught and fixed the new HUD-name indexing bug. No exported build was produced.
- Final regression rerun passed Jungle invariants/materials/active owners, Forest invariants/materials, Savanna invariants/materials, Swamp/Mountain/Rocky Coast/Beach invariants, and Tropical/Badlands invariants/assets. The four generated source hashes, compression/mipmaps and shared biological array byte count also passed again. These do not replace each older biome's full visual review.
- The physics/ownership tests are numerical/native physics checks, not proof that every authored visual target has been achieved. Prior Badlands/Tropical capture and benchmark sections below describe earlier source revisions, not freshly repeated current combined-source GPU sweeps.

Isolated CPU work (Godot 4.6.1, fresh numerical builder per repeat; no concurrent render). Near values are medians of three cold mesh builds at fixed chunk coordinate (2,2); far values are **one** cold build, not a multi-repeat percentile. No structure meshing, collision upload, shader compile or scene startup is included:

| Biome | 256 m / 64 resolution, ms | 256 m / 128 resolution, ms | 16384 m / 64 resolution, ms |
| --- | ---: | ---: | ---: |
| Grass control | 163.876 | 404.506 | 537.774 |
| Quarry | 107.695 | 328.815 | 1583.918 |
| Wise Chinese Mountains | 100.937 | 385.994 | 927.245 |
| Volcanic | 105.679 | 387.236 | 1592.160 |
| Spore Forest | 118.932 | 425.511 | 1420.508 |
| Radiation Wasteland | 124.305 | 409.723 | 1610.734 |
| Crystal Wastes | 115.846 | 392.358 | 1399.921 |
| Insect Colony | 124.259 | 376.409 | 1684.778 |
| Alien-Infected | 129.064 | 386.972 | 2708.316 |

Different formulas/detail content make these **not equal-quality terrain comparisons**. Far canonical normal probes and alien-network queries remain substantial CPU costs. Caches are bounded, not proof of universally excellent performance. See ignored `benchmark_cpu.json` and the final native capture report for detailed measured evidence.

Native settled-view measurements: Godot 4.6.1 Compatibility, RTX 3060 Laptop GPU, 1280×720, 50 km far plane / LOD 6. Across 32 isolated-biome views, per-view median GPU time was **2.99–6.33 ms**; median frame time **16.661–16.672 ms** was VSync-limited. Draw calls ranged 69–167, numeric-atlas storage 1.14–8.63 MB, and engine-reported total video memory 391–421 MB (decimal units; not extension-only allocation). Eight first stream fills measured **8.95–18.81 s**, including synchronous scene insertion/material setup but not process startup or guaranteed uncached shader compilation. The mixed-world two views measured 6.23/7.52 ms GPU, 16.666/16.670 ms frame, 98/102 draws and 442/449 MB total video memory; initial fill was 9.27 s. These are scene measurements, not isolated shader benchmarks or equal-quality comparisons. `data/biome_extension_validation.json` preserves the result summary and current core hashes.

## Open quality gates and unsupported features

**Not finished against the supplied reference briefs.** Remaining work includes richer regional silhouettes and geology, less rounded distant pillars, more convincing macro/meso rock structure, stronger construction/weathering detail, separate volcanic surface PBR families, better fungal crust/powder diversity, clearer natural-to-biological assimilation, more geographically complete drainage/deposition models and comprehensive all-region/nighttime/fast-travel sweeps. The six first-pass families per biome do not amount to implementation of every conceptual region or requested scenic target.

Quarry ramps are selected winding rock-cut paths, not a complete switchback system; all traversable grades have not been proven on the final interpolated mesh. Major features share canonical coordinates, but undersampling can still alter far silhouettes. Regional blending and material contrast need artistic refinement.

True caves, open burrows, traversable hive breaches, underground brain chambers, lava tubes and waterfalls are **not installed**. Closed depressions/solid silhouettes are used without fake black-hole entrances. Active molten lava and organic liquids currently have deterministic eligibility/integration descriptors, **not liquid renderers**. Ordinary freshwater is not recolored and presented as lava. Crystal rendering intentionally uses an opaque, faceted low-cost approximation; refraction/true internal transmission are not implemented. Physics coverage is tested at canonical vertices, not exhaustively over every steep wall or major crystal/conduit.

No animals, insects, AI, vegetation, eggs, spores, particles, damage, dynamic growth, new audio, weather or fog systems were added.

---

# Badlands — integrated, visual-quality work still in progress (2026-10-17)

Historical pass below: statements about absent collision describe that earlier implementation. The later shared near-terrain collision system is documented above; this does not retrospectively certify exhaustive Badlands or Tropical traversal.

**Not complete against the full visual brief.** The numerical implementation, renderer integration and validation tooling exist, but native inspection still shows overly smooth interfluves, coarse distant gullies and broad/repetitive-looking sediment bands. No claim of a photorealistic Badlands reference match is made. Badlands remains opt-in (`badlands_coverage` defaults to zero, and the saved world is unchanged). This earlier quality gate remains open; the user's later whole-queue priority is documented above.

## Implemented in this pass

`scripts/badlands_sampler.gd`, `scripts/badlands_settings.gd` and `badlands_settings.tres` add sixteen sedimentary provinces through the existing builder: painted hills, red mudstone, gray clay, bentonite-like hills, eroded ridge country, hoodoo country, canyon country, dissected plateau, sediment basin, dry washes, stratified clay, pale badlands, rocky highlands, stratified escarpments, sediment fans and barren plains. Names describe intended geological appearances, not certified mineral composition.

The sampler evaluates one fixed 16 m C1 world-space terrain/water definition. Cached finite drainage trees join the inherited river carriers: primary wash, tributary junctions, secondary branches and third-order source gullies. Children start on parent edges and descriptor grades rise toward their sources. Drainage-distance envelopes shape the surviving interfluves instead of merely painting channel masks. This is a static erosion approximation, **not a downhill flow solver or hydraulic/sediment simulation**. Actual bed profiles are not proven globally monotonic.

Continuous world-height/dip/fold strata have unequal band widths; their harder upper interval also creates small geometric shelves. Regional relief, clay smoothing, dissected uplands, sparse capped heightfield remnants, outlet-connected fan deposition, coarse debris appearance and rare retained drainage-root pools are supported. Remnants have no detached caps or overhangs. No rock-prop system, vegetation, animals, dynamic floods, cave engine or terrain collision was added. Nearby physical collision therefore remains unsupported, not tested or implied by height queries.

Bounded private worker caches: 16,384 terrain nodes, 2048 region nodes, 2048 broad carrier nodes and 512 drainage-tree descriptors. No SceneTree access from the numerical sampler. Badlands refinement is local to certified pure-Badlands tiles, with a 64-resolution cap and default 256 m distant spacing; global view distance stays 50 km / maximum LOD 6. Narrow gullies/remnants simplify at distance. Main Sun, sky, fog, ocean renderer and existing biome material settings are unchanged.

## Transport and materials

A signed CUSTOM0.w wrapper preserves Jungle's complete 24-bit wetness/drainage/ownership payload. Only Badlands-influenced chunks use it. UV.y carries Badlands ownership and regional appearance plus an 8-bit bounded Grass curvature value; curvature is restored **before interpolation**, with exact zero and saturation outside +/- .5 (Grass masks already saturate at +/- .35). The sampled curvature-mask error is below .01. Tropical's existing three-byte extension, Mountain geology and Forest/Savanna/Swamp banks coexist with this wrapper. Disabled Badlands keeps the prior mesh layout and complete array values. This is a Badlands-specific extension, not a claim that unlimited future-biome payload space is available.

`shaders/badlands_material.gdshaderinc` uses six distinct existing photographed ambientCG CC0 PBR sources: Ground026 clay hardpan, Ground105 red-earth analogue, Rock055 layered resistant rock, Ground031 cracked basin earth, Gravel020 wash gravel and Ground108 coarse talus. These share existing Savanna/Jungle/Mountain color/roughness and normal arrays. No new bitmap, download, duplicated texture array or runtime texture conversion was introduced. `data/badlands_material_sources.json` records the exact source maps, hashes, licenses and layer routing. Mudstone/shale/bentonite labels are visual analogues; no dedicated mineral-certified scans were sourced in this pass.

At most three active roles are sampled per pixel. The material retains signed triplanar normal orientation, quarter-metre wrapped origin precision, fixed physical scales, existing macro/meso cliff normals, geological banding, broad PBR surface detail and distance-faded micro normals. Geological colours are converted from authored sRGB before lighting. Initial native review exposed over-bright bands and excessive plateau-like ground; both were revised, but the remaining visual issues above still need work.

## Preview and repeatable checks

Use Inspector **Badlands Preview / Badlands Preview Feature**, or `-- badlands-preview badlands-feature=painted_hills`. **Shift+F9** finds Badlands when coverage is enabled; **Ctrl+F9** cycles eight diagnostics. Plain F9 still finds Forest. `data/badlands_previews.json` records 31 actual generated locations at seed 73921, including all seven live inland transitions, a rare pool, remnants, fans, ravines and deposition. Examples (X, Z metres): painted hills (-69120, -87552), hoodoo cluster (18377.512, 960.872), eroded ridges (98304, -95232), rare pool (8763.652, 15321.894), Grass transition (-71800, -61400).

Desert and Mesa are **not live owners in the inspected project**. Their requested transition tests remain unsupported/pending; retired Desert/Snow assets were preserved rather than reactivated. This historical Badlands-only pass did not implement later entries; their subsequent integrated first passes are documented above.

- 16,104 numerical checks passed: three seeds/order consistency, C1 sampling, adjacent height/water/payload/normal seams, six parent-child LOD levels, eight-owner normalization, seven live pairwise transition payloads, actual rare-pool water without Swamp flood displacement, connected/increasing-grade drainage descriptors, forced cache eviction, bounded curvature-mask error and a synthetic eight-simultaneous-owner payload stressor. The synthetic case is a test, not a world preset; real ownership cells have at most four active owners.
- Ten pre-change mesh fixtures across saved-world, Tropical, mixed Forest/Tropical, Mountain and coastal presets retain exact SHA-256 hashes for **every array** with Badlands disabled. The fixture capture tool refuses to overwrite the pre-change evidence. Tropical's 49,826 invariants passed again after integration.
- Six source materials passed 18 map hashes, packed compression/mips, shared-layer bindings and shader uniform checks. Native GPU transport passed 63 positive cases, including the largest signed Jungle payload, and detected one intentional corruption. Native texture phase passed 63 positive cases and one intentional negative control.
- Four final native mapped-normal comparisons passed (rocky highlands, painted hills, bentonite hills, escarpment): mean RGB difference .00276–.01184, zero-strength versus maps-off maximum error 0.0. These prove normal-map contribution, not artistic realism.
- **186 final native captures at 31 locations** passed the source-revision, manifest-focus, committed-cut, dimensions and PNG-hash audit. Ground/medium/aerial contact sheets plus representative individual views were inspected. The audit checks capture integrity, not visual success. First-use review runs following shader edits hit a 90 s settle timeout; warmed retries and the corrected 180 s normal-review settle check passed. No clean uncached-driver-compilation startup bound was measured.
- Eleven actual source-game launches passed: painted hills, hoodoo cluster, rare pool, seven live transitions and saved world. All produced empty failure reports. Feature launches reached the smoke condition in 5.96–9.89 s; the unchanged saved Beach start took 30.95 s. No export was performed.
- Final existing-biome regression run passed Jungle invariants/materials/placement/active-owner checks, Forest (9583)/materials, Savanna (11,349)/materials, Swamp (6754), Mountain (6260), Rocky Coast (18,164), Beach (4078), and Tropical assets. `git diff --check` passed. These do not include a new native visual sweep of every older biome after Badlands; disabled-Badlands full-array fixtures and source-game launches provide the narrower preservation evidence described above.

## Measurements and remaining work

Isolated native Godot 4.6.1 Compatibility / RTX 3060 Laptop GPU, 1280×720, same XZ/controller/terrain-following clearance, original 50 km far plane / max LOD 6: Badlands versus Grass cold **stream fill** 10.85 / 4.85 s; teleport fill 5.31 / 2.74 s; 1000 scattered height queries 327.85 / 131.00 ms; static GPU 7.51 / 10.90 ms; static frame 16.67 / 16.67 ms (vsync limited); reported static CPU bytes 79,196,291 / 87,883,563; reported video bytes 386,745,943 / 238,120,843; visible draw calls 102 / 102. Different terrain/material composition makes this **not a pixel-identical GPU comparison** or proof that Badlands is intrinsically cheaper. CPU figures are total tracked static memory, not mesh-only allocation. Fill timers exclude synchronous scene-ready/material setup and must not be described as full application startup.

Badlands cold worker medians at resolution 16/64/128: 38.09 / 182.16 / 583.12 ms. Measured maximum planning/swap cost 4.05 / 9.92 ms; 1500 m/s travel maximum frame 18.33 ms, then .783 s to settle. A separate headless one-shot cost breakdown measured a 256 m / 128-resolution chunk at 609.81 ms (579.30 height/noise, .56 normal field, 29.92 array construction). A 16,384 m / 64-resolution tile took 2.18 s, dominated by canonical normal probes (1.61 s). A deliberately denser 128-resolution far stress case took 7.39 s; that density is not requested by the new Badlands far-refinement cap. Cold generation and distant normal work still need optimization; these measurements are not hardware/seed guarantees.

Reproduction scripts: `tools/badlands/verify_project.ps1` with optional `-Review`, `-Benchmark`, `-Smoke`; individual runners and ignored local evidence in `tools/badlands/artifacts/`. Current quality gates: improve fine erosion-shaped silhouettes, reduce broad/repetitive-looking strata, strengthen distinct gray/pale/painted regional identity, retain more distant drainage structure without unacceptable cold-generation cost, and visually revalidate. **Badlands remains in progress and disabled in the saved world.**

# Tropical (2026-10-17)

Implemented through the existing terrain builder, streaming cut, shared water grid and terrain shader. No vegetation, props, animals, collision system, cave engine or global lighting changes were added. The saved world enables `tropical_coverage = 20`; Resource-class default remains zero for historical isolated presets. The saved Beach start is unchanged. **Shift+F8** finds actual Tropical ownership; **Ctrl+F8** cycles ten Tropical diagnostics. Inspector Tropical Preview / Tropical Preview Feature, or `-- tropical-preview tropical-feature=mountain_belt`, uses seed/coordinates from `data/tropical_previews.json` (35 actual procedural locations, including six live inland transitions and both coastal overlays).

## Geography, water and representation

Sixteen regional identities: coastal lowland, lush plain, rolling/rugged hills, rocky highland, mountain belt, river valley, humid basin, lake country, ancient volcanic highland, limestone highland, plateau country, ravine country, coastal bluff, uplifted terrace and weathered escarpment. These combine calm open ground, broad irregular relief, regional ridges and saddles, weathering, finite tributaries, retained pools, lake basins, coastal mouths and rock/soil exposure. Ancient volcanic and limestone surfaces are visual geological analogues, not active lava or mineral-certified rock.

One fixed 16 m C1 interpolation field defines height and water at every mesh LOD. Broad relief uses a fixed 2048 m smoothed carrier of the existing river network; only narrow channel beds use its fine meanders. This avoids corrugating entire mountains with channel-scale bends. High-relief tributaries use broader valley shoulders rather than creating stretched narrow walls. Coastal region selection follows the actual warped island margin. Bounded per-worker caches: 16,384 terrain nodes, 2048 region nodes, 2048 exact river samples and 2048 structural nodes. Numerical samplers do not access SceneTree nodes.

Freshwater uses the existing shared local-water mesh/material and negative freshwater classification, without Swamp flood-stage displacement or duplicate ocean surfaces. Whole river carriers are selected by river frequency. Lakes/pools have actual depressed beds, bounded irregular support and level centres; tributaries belong to the inherited drainage graph. Water potential describes finite catchments, not a global hydraulic flow solver. The `waterfall_ledge` preview is a **dry future attachment candidate**, with measured lip/foot/drop descriptors and `renderer_supported=false`, `flow_connected=false`. No rendered waterfall, traversable cave, overhang, full sediment simulation or collision was implemented. A transition to the separately queued Volcanic biome remains pending that biome's implementation.

The seventh owner reuses three redundant ownership bytes in CUSTOM1.x / CUSTOM2.x / CUSTOM3.x. Their low 16-bit Forest/Savanna/Swamp ecological fields are retained; original weights are restored from COLOR.g/b/a. Negative sentinels select the extension; decoding occurs before interpolation. Tropical region, ownership and moisture occupy the reclaimed bytes. Existing custom banks were not discarded. With Tropical coverage zero, complete archived six-biome mesh arrays remain identical. This consumes the presently available redundant bytes; additional biome work needs a tested transport extension, not assumed free channels.

## Materials

Eight roles share existing mipmapped BC3 color/roughness and BC5 normal arrays, with no duplicate bitmap arrays or runtime downloads: Grass003 lush grass (**procedural PBR**, not photographed), Ground030 sparse soil, Ground105 red weathered earth, Ground048 organic soil, Ground083 river silt, Rock051 massive weathered rock, Rock064 humid rock and Ground108 talus. Seven sources are photographed scans; all are existing ambientCG CC0 materials. `data/tropical_material_sources.json` records exact existing source hashes, licenses and role routing. Geological labels are appearance roles, not verified mineral identities.

At most three active material roles are sampled per pixel. The material retains signed triplanar projection, immutable physical scale, quarter-metre integer-wrapped origins (including negative coordinates), coarse/fine source detail, distance-faded micro normals and the existing macro/meso cliff normal architecture. Regional moisture, rock exposure, slope, drainage and weathering control distribution. Pale silt is favoured in alluvial provinces, not a universal bright shore band. Subtle dry-ground wear uses the existing curved trail graph; `data/tropical_path_preview.json` records an actual native rendered on/off comparison and source hashes.

## Validation and measured performance

- 49,826 invariants passed: three seeds, order/cache eviction, exact height-only/full queries, C1 lattice and broad-carrier continuity, adjacent height/water/normal/payload seams, six parent-child LOD levels, seven-owner normalization, real local-water meshes and all six live inland ecological-payload preservation cases. The disabled-Tropical archived six-owner complete mesh comparison passed.
- Source assets passed 24 hashes, compression/mipmap and actual shared-layer bindings. Native GPU transport passed 95 positive cases plus an intentional corruption; texture-phase precision passed 63 positive cases plus an intentional negative control. Both negative controls were detected with zero positive errors.
- Four final native normal-map comparisons passed (rocky highland, lush plain, red soil and limestone highland), mean RGB difference .0059–.0141; zero-strength versus maps-off error was exactly zero. Main scene lighting was unchanged.
- Final source-revision native sweep: **210 captures at 35 locations**, ground/medium/aerial plus material/normal/wetness views. Audit checks manifest focus, committed streaming cut, core source hashes, dimensions and PNG hashes. Contact sheets and representative individual captures were inspected. Main lighting/fog remains pastel; far terrain softens and narrow rivers remain angular at coarse LOD. These checks do **not** establish a photorealistic reference match or eliminate every visual defect.
- Twelve actual source-game launches passed: mountain belt, lake, pool, six live inland transitions, Beach/Coast transitions and saved world. Saved world retained Beach start, 117 committed leaves, no shader/runtime failure; measured ready-to-smoke elapsed 28.87 s. No export was performed. Jungle, Forest, Savanna, Swamp (6754), Mountain (6260), Rocky Coast (18,164) and Beach (4078) regression suites passed with historical isolated test presets explicitly opting out of Tropical.

Isolated native benchmark: Godot 4.6.1 Compatibility, RTX 3060 Laptop GPU, 1280×720, original 50 km far plane / max LOD 6, same XZ and terrain-following height. Tropical versus Grass: cold **stream fill** 7.94 / 4.53 s; teleport fill 4.63 / 2.58 s; static GPU 9.17 / 8.48 ms; static frame 16.66 / 16.66 ms (vsync limited); reported static CPU bytes 107,570,207 / 52,657,831; reported video bytes 404,022,993 / 235,990,651; draw calls 138 / 102. CPU figures are total tracked static memory, not mesh-only allocation. Fill timers exclude synchronous scene ready/initial material setup, so they are not full process-startup times. Different relief means the GPU scenes are not pixel-identical workloads. Tropical max measured planning/swap cost 3.32 / 15.01 ms. Fast travel at 1500 m/s settled in .149 s with measured maximum frame 16.83 ms; not a guarantee for all hardware or seeds.

Cold worker chunk medians at resolutions 16/64/128 were 33.35 / 163.16 / 530.13 ms. A separate isolated headless CPU probe at three locations found 128-resolution builds 540–593 ms, dominated by height/noise evaluation (503–560 ms); normal-field work .44–.93 ms, mesh arrays 32.7–36.3 ms, separate water pass 35.2–55.1 ms. These are one-shot cost breakdowns, not statistical tail measurements. Full local reports and images live under ignored `tools/tropical/artifacts/`; runners are in `tools/tropical/`. Cold generation and memory are materially higher than Grass and remain optimization limitations.

Tropical implementation and validation pass is recorded with these limitations; remaining biome briefs are tracked sequentially in `data/biome_implementation_queue.json`. No later biome is complete merely because it is listed there.

# Coastal Dunes and Beaches (2026-10-17)

Terrain and water only. **F12** finds an actual sandy shore; **Ctrl+F12** cycles twelve sand diagnostics. The saved world now enables Beaches and starts near one by default (`start_in_beach`); F1 still finds rocky coast, and all inland shortcuts retain their previous roles. Inspector Beach Preview / Beach Preview Feature, or `-- beach-preview beach-feature=high_foredunes`, selects a reproducible generated feature. `data/beach_previews.json` records sixteen actual sandy regions plus all six live inland transitions at seed 73921. No Desert/Snow/Stone reactivation, invented Tropical/Volcano biome, foliage, grass meshes, shells-as-props, trees, animals or decorative rocks.

## Geometry and integration

`beach_settings.tres` controls coverage, variable beach width/slope, berms, foredune size/asymmetry/crest variation, secondary ridges, backdune relief, wind, blowouts, storm cuts, barrier/spit/lagoon/flat/bar frequency, and sand materials. The Resource-class default is disabled for previous unsaved presets; `terrain_settings.tres` explicitly enables it in the saved world. Disable **Beaches Enabled** for the pre-sand coast path. Disable both coastal overlays for the previous six-inland-biome mesh and original ocean shader. Existing island size/spacing, world seed, quadtree ownership/swap logic, worker system, 50 km far plane, maximum LOD 6, and lighting are unchanged.

This is a geographic overlay, not an inland biome competitor. It extends the existing coastal target and uses its canonical 8 m C1 interpolation, normalized blend and shared water lifecycle. A separate fixed 256 m bicubic carrier samples the **same warped island boundary**; it is neither a circular coast nor a new island generator. Smoothing the shoreline carrier avoids turning small distance-gradient changes into lumpy dune profiles or sharp inland blend spikes. Geometry and sandy influence use that same carrier. Small existing shoreline detail can be deposited over/smoothed by sand; this is not exact Euclidean shoreline-distance reconstruction.

Sixteen regional identities: broad/narrow beach, dune field, high foredunes, backdunes, parabolic dunes, sheltered cove, barrier, spit, lagoon, tidal flat, sandy estuary, low sandy island, storm-scarp coast, mixed rock/sand, and shoal country. Their continuous fields combine backshore, variable foreshore, berm, asymmetric foredune, irregular secondary ridges, broad interdune lows, wind-aligned arms, elongated blowout gaps, finite-width storm cuts, broad damp slacks, offshore bars, inherited river mouths and shallow channels. Mixed shores partially bury the original rocky target. Carriers follow the existing shore and shared rivers; no chunk-local stamps or separate decorative meshes.

River banks broaden through tall dunes instead of applying the narrow Grass incision to a 100 m sand ridge. Parabolic phase uses bounded regional perturbations around the prevailing wind, rather than multiplying a varying angle by unbounded world coordinates. CPU wind variation changes dune asymmetry; the photographed ripple overlay follows the prevailing direction (not a fully advected spatial wind simulation).

Connected lagoon and barrier-backwater depressions are sea-level heightfield forms covered by the existing ocean. Spits are finite sediment extensions attached to that shoreline, not arbitrary deep-ocean lines. These are supported local barrier/lagoon approximations, not complete barrier-island chains or a global sediment-connectivity solver. Dune slacks are broad low, damp terrain; no additional inland pool system was introduced. Tides, storm deformation, sediment transport and groundwater are static geometric/material approximations, not physical simulations.

Only coastal tiles receive the existing 64–128 m far refinement with a 128-resolution cap. Major dunes retain one world-space shape across LODs; narrow berms/channels still simplify at distance. New bounded per-worker caches: 4096 shoreline nodes and 2048 polynomial patches; existing coastal caches remain bounded. Pure sand skips hidden rock material/landform work. Conservative canonical-node early-outs are checked against an unpruned sampler. No SceneTree work is performed by numerical samplers/workers.

## Sand and water rendering

Four new **photographed** [ambientCG](https://ambientcg.com/) CC0-1.0 PBR packages: [Ground055S](https://ambientcg.com/a/Ground055S), [Ground059](https://ambientcg.com/a/Ground059), [Ground060](https://ambientcg.com/a/Ground060), and [Ground080](https://ambientcg.com/a/Ground080). Actual 2K Color/NormalGL/Roughness maps were downloaded and hash-checked, not previews. `data/beach_material_sources.json` records source URLs, image hashes, appearance roles and packed resources. Source physical scale is known for 055S/059; other role scales are tuning choices, not certified capture dimensions. Offline BC3 albedo/roughness + BC5 normals with mipmaps cost 27,962,240 GPU bytes total. No generated sand bitmap, runtime download, unique per-chunk texture, or material synthesis at runtime.

The dedicated sand material samples at most three source roles per pixel: dry/coarse, photographed compact wet sand, and a bounded dry ripple overlay. Wetness affects source structure, albedo, roughness and normal amplitude; it is not brown paint or black polished stone. A coherent height-relative-to-sea band plus bounded animated swash affects appearance only, never physical terrain. Warm mineral variation, macro source variation and slope exposure remain world-space. Base grains use stable local-plus-quarter-metre-wrapped-origin phase; the rotated metre-scale ripple overlay uses continuous world UV to avoid rotated-modulo chunk seams. That overlay retains ordinary GPU float precision limitations at extreme world coordinates. Detail fades without changing physical UV scale. Normal gradients use signed projection and inverse rotation before world/view conversion.

No custom mesh bank was removed. A negative **CUSTOM1.w** sentinel extends the existing coastal **CUSTOM1.z** layout: Forest water, sand fraction and sandy region occupy three byte channels. Decode happens in the vertex stage before interpolation. Sandy vertices approximate legacy coastal exposure as .5 and relinquish the rocky sediment appearance field; unchanged rocky vertices retain their original payload. Forest rock/water bytes are retained. Geometry uses full numeric fields, never quantized appearance bytes.

The original `ocean.gdshader` is untouched. The opt-in coastal variant retains its wave model and depth-based color/foam; its post-opaque scheduling now explicitly reads **terrain** depth, not the ocean prepass. Alpha stays one. No global transparent/refraction renderer was added, and opaque ocean still does not display the literal seabed texture through water. Shallow color and foam respond to the actual sandy bathymetry. Screen-depth-derived exposure was removed because finite depth precision amplified it into checker-shaped foam; wash energy instead varies smoothly in world space. Marine/lagoon water is exclusively ocean-owned. Coastal retained-pool triangles cannot bridge into sea-level sandy water, avoiding duplicate surfaces. Swamp flood stage does not raise the ocean or sandy lagoon.

## Validation status

- 4078 Beach invariants passed: three seeds/order/cache checks, canonical C1 probes, 500 optimized/unpruned mixed-boundary comparisons, adjacent payload/normal/height seams, six parent-child LOD levels, actual onshore dunes/flooded lagoon, real signed mesh payloads, bounded cache eviction, ocean-only marine water, and complete archived inland mesh equality with both overlays disabled.
- Sampled regional sand slopes passed. High foredune maximum about 37.6°, parabolic maximum 36.5°; storm-region maximum about 19.9° and backdune maximum 21.4° after removing artificial distance-field and narrow-channel spikes. This is a reproducible sample check, not a proof of every slope for every setting/seed.
- Four photographed PBR sources passed hashes, compression/mips, bounded GPU memory, uniform wiring and normal-basis checks. GPU payload transport passed 47 positive cases and one intentional corruption. Four native normal comparisons passed with zero-strength versus maps-off maximum pixel error 0.0.
- Rocky Coast's 18,164 and Mountain's 6260 invariant suites passed again. Existing Jungle, Forest, Savanna, Swamp deterministic/material suites and shared cache-order/partition checks passed. Old biome test/benchmark presets explicitly disable the new overlay to retain their intended isolation.
- Native source-revision render sweep: 78 captures across 22 generated locations (ground/medium/aerial everywhere, plus material/normal/wetness diagnostics in four representative regions). The auditor checks source hashes, manifest coordinates, committed leaves, native 1280×720 dimensions, view coverage and image hashes. Two locator-focused locations were refreshed to ensure low-island ground is on land and mixed coast actually contains both sand and exposed rock. This validates the sixteen regional identities and six live-biome transitions, not thirty-two individually discovered subfeature sites from the conceptual brief.
- Native texture-origin precision passed 63 positive cases plus one intentional corruption. The final ocean foam check changed 852 sampled ocean pixels, maximum difference .467, with zero non-water changes. The retained original two-axis wave model can still show regular interference/stripe patterns on broad water; removing the screen-depth exposure artifact does not make that legacy wave model non-repeating.
- Ten normal source-project game launches passed: high dunes, lagoon, parabolic country, six live inland transitions, and the saved mixed world. The saved-world HUD identifies Coastal Dunes / Beaches. Its cold launch settled in 29.2 s with 117 terrain leaves. The approved downward Sun was checked in Godot and remains unchanged.

## Isolated performance

Godot 4.6.1 Compatibility, RTX 3060 Laptop, 1280×720, far 50,000 m, maximum LOD 6, same seed/XZ/source controller, camera terrain-following at 80 m. No simultaneous capture processes during these measurements. Different relief still changes visible composition; these are reproducible scene measurements, not universal GPU rankings.

| Mode | Initial fill | Teleport settle | Static GPU p50 | Static frame p50 |
| --- | ---: | ---: | ---: | ---: |
| Current Grass, both overlays off | 3.18 s | 1.65 s | 7.64 ms | 16.66 ms |
| Current Rocky Coast, sand off | 15.82 s | 8.11 s | 6.55 ms | 16.67 ms |
| Beaches and coastal dunes | 23.44 s | 12.73 s | 3.66 ms | 16.67 ms |

Beach cold 16/64/128-resolution worker chunk medians: 45.9/337.4/776.5 ms. A thousand height/water queries took 37.2/25.9 ms. Static reported CPU memory 76.5 MB, VRAM 409.0 MB, 101 draw calls; regional VRAM reached 424.4 MB. Maximum recorded plan/commit times 3.91/17.54 ms. Fast-travel frame maximum 19.45 ms, with 7.97 s of subsequent partition settling. Regional static GPU median 4.65 ms.

**Generation is not instant:** steady-state results are vsync-limited around 60 FPS, while cold loading and large teleports remain a significant CPU cost. View distance/detail were not reduced to hide that cost. The benchmark reports expose worker, queue, commit, water-grid and memory costs; the historical Mountain/Coast tables below are from their earlier implementation revisions, not this Beach baseline.

Known limits: heightfield/far-LOD simplification is still visible; this is not a photographic reconstruction of the references. No true undercuts, traversable caves, fluid erosion, groundwater/tide simulation, or foliage. **This checkout has no installed terrain collision system; collision validation and gameplay collision guarantees remain unavailable.** No export, commit, push, history rewrite or ZIP delivery.

Reproduce: `tools/beach/verify_project.ps1 -Review -Normal -Benchmark -Smoke`. Render review uses six sequential native batches and checks source hashes, actual committed terrain, native image dimensions and complete view coverage. Reports and full-resolution captures live under ignored `tools/beach/artifacts`. The prior sections below document their respective implementation revisions, not a new Beach baseline.

---

# Rocky Coast terrain and water (2026-10-17)

**Navigation:** F1 finds actual Rocky Coast in the saved world; Ctrl+F1 cycles 20 coastal diagnostics. F2 still finds Mountain Range, F8 Jungle, F9 Forest, F4 Savanna, and F3 Swamp. Inland locators reject coastal-overlay destinations, so an inland-biome shortcut cannot silently put the camera on Coast instead. Beaches now have startup priority; disable `start_in_beach` to restore Rocky Coast startup.

Rocky Coast is a geographic overlay, not a seventh competitor for inland region ownership. Its variable-width influence follows the existing warped island boundary and extends both inland and under the ocean. `rocky_coast_settings.tres` controls coverage, regional scale, influence width, headlands, inlets, cliffs, erosion, platforms, offshore remnants, pools, wetness, materials and supported detail quality. Disable **Rocky Coast Enabled** in Terrain Settings for the exact previous six-biome mesh path and original ocean shader. Existing island size/spacing, seed, quadtree, 50 km far plane, sun, sky, exposure and fog were retained. Desert/Snow/Stone remain retired; absent Volcano/Tropical/Sandy Beach implementations were not invented.

## Implemented geography and materials

Sixteen blended coastal identities cover tall cliffs, rugged shores, headlands, sheltered coves, wave-cut platforms, boulder/shingle terrain, sea-stack country, granite-like highlands, layered cliffs, dark rocky shores, fjord-like inlets, coastal plateaus, exposed coast, sheltered inlets, low rocky islands and coastal ravines. The target is built from the actual island field, regional profiles, exposure, finite-width cliff rises, broad shoreline offsets, erosion, inherited river carriers, rare offshore descriptors, and genuine pool depressions. It is not a circular cliff ring or a new inland coastline generator.

The 8 m canonical C1 field preserves geometry across chunk/LOD queries. A narrow C1 influence shoulder avoids hard-clamp derivative kinks. Global query coordinates remain double precision until the small cell remainder. Appearance fields use bounded bilinear interpolation; cached polynomial coefficients preserve the height/water/influence polynomials. Expensive hidden inland landforms are skipped only where the coastal weight is exactly one. Canonical nodes can skip coastal analysis only when the clamped-distance bound proves zero influence; off-lattice queries still evaluate their complete bicubic support. These optimizations are checked against local pre-optimization fixtures.

Offshore remnants are heightfield landforms, not decorative rock nodes. Their summits use a fixed 128 m world lattice, independent of camera/LOD/quality, so supported far grids retain their peaks. Their nearby silhouettes still simplify. Coastal far spacing is supported at 64–128 m with a 128-resolution cap; only conservatively classified coastal tiles are refined, not the entire world.

The dedicated coastal material selects at most three photographed source roles: Rock051, Rock042L, Rock055, Gravel040 and Ground108, all ambientCG CC0 scans already present after the Mountain pass. No duplicate textures were downloaded for Coast. `data/rocky_coast_material_sources.json` records source URLs, checksums and roles. These are appearance families, not certified mineral classifications. The existing normal collection is reused for bounded macro/meso overlays (some legacy normal sources are procedural); the coastal base palette is photographed PBR, not a procedural crack texture. Signed triplanar surface gradients, stable local-plus-wrapped-origin UV phase, roughness, source variation, sediment and exposure-dependent wetness/salt response are retained. No foliage, grass meshes, props, animals or separate boulders were added.

CUSTOM1.z/w use a negative sentinel to transport coastal influence/region/exposure/sediment while retaining byte-quantized Forest rock/water controls. Decode occurs in the vertex stage before interpolation. Only extended coastal chunks quantize those two legacy controls to 8 bits; with Coast disabled, complete prior mesh arrays compare exactly.

## Ocean, pools and limits

The original `ocean.gdshader` is preserved. When Coast is enabled, a small `coastal_ocean.gdshader` variant keeps its wave/color/roughness model and reads opaque terrain depth for shallow-water color and broken, exposure-modulated foam. It uses the documented [Compatibility depth-unprojection convention](https://docs.godotengine.org/en/4.4/tutorials/shaders/advanced_postprocessing.html). It is not a fluid/erosion simulation or an SSR reflection system.

Retained pools reuse one shared numerical water grid/material per terrain leaf (the compatibility node name remains `SwampWater`), with the same terrain topology and clipping heights. Marine water is owned exclusively by the ocean; duplicate sea-level coastal water is rejected. Overlapping basin lobes create real connected pools and a retaining lip. Pool water sits above the stable ocean reference, without one node/material per pool. Swamp flood stage does not raise coastal pools. There is no new physical tide simulation.

Heightfield limits remain: no true overhangs, sea arches, traversable caves, individual prop boulders, or physical hydraulic erosion. Narrow features simplify at distance and very small pools are near-field detail. The distance field is a first-order proxy from the actual warped island field, not an exact global Euclidean shoreline-distance solver. The visual result still shows heightfield/far-LOD simplification and is not a photographic reconstruction of the supplied images. This checkout has **no installed terrain collision system**; collision validation is unavailable, and no gameplay collision guarantee is claimed.

## Verification and performance

- 18,164 invariant checks passed: three seeds, reverse-order queries, actual cache eviction, C1 boundaries, adjacent height/normal/water/payload seams, six parent/child LOD levels, real flooded pools, offshore geometry, 300 polynomial-reference probes, 500 zero-influence-boundary reference probes, complete pre-pruning mesh geometry/normal/water comparison, and exact Coast-disabled meshes for all six inland biomes plus mixed coverage.
- GPU transport passed 47 positive tiles plus one intentional negative case; texture-origin precision passed 63 positive cases plus one negative case.
- All four Coast normal surfaces passed; normal-strength-zero versus normal-off maximum pixel error was 0.0.
- Isolated ocean test: 926 sampled water pixels changed with foam enabled, zero non-water pixels changed (104,822 ocean samples).
- Ten source-game launches passed: cliffs, pools, stack, all six existing inland transitions and the saved mixed world. Previous Jungle/Forest/Savanna/Swamp/Mountain normal-map regressions passed, along with shared cache/partition and biome-locator tests.
- The Sun basis was inspected in Godot and still casts downward, preserving the previously approved correction.
- Full camera review passed in four independently logged batches: 192 main captures across all 32 generated locations, plus two close pool views. `check_review.gd` audits native capture metadata, committed terrain, image dimensions and checksums. Compact per-batch contact sheets are generated for inspection.

Measured on Godot 4.6.1 Compatibility / RTX 3060 Laptop, 1280×720, same seed/XZ/controller, 80 m terrain-following camera, far 50,000 m, maximum LOD 6. Benchmarks were isolated from parallel camera captures.

| Mode | Initial fill | Teleport settle | Static GPU p50 | Static frame p50 |
| --- | ---: | ---: | ---: | ---: |
| Pre-Coast Grass baseline | 2.67 s | 1.85 s | 3.92 ms | 16.67 ms |
| Current Grass (Coast off) | 2.75 s | 1.76 s | 5.97 ms | 16.67 ms |
| Rocky Coast | 12.50 s | 4.10 s | 5.79 ms | 16.66 ms |

Coast cold 16/64/128-resolution worker chunk medians: 36.4/266.1/548.0 ms. The original provisional close-chunk implementation measured about 2.22 s; polynomial caching and exact hidden/zero-influence pruning reduced that cost without lowering detail or draw distance. Final 1000 height/water queries measured 22.6/19.6 ms. Static CPU memory: 109.6 MB; reported video memory: 386.2 MB; 109 draw calls versus baseline 90.1 MB/234.5 MB/104 calls. Regional static GPU median reached 8.60 ms. Maximum recorded plan/commit times: 4.69/8.68 ms.

**Cold loading is still a cost:** the saved mixed-world source launch took about 20.9 s to settle. The 60 FPS measurements are vsync-limited steady-state results, not a claim of free generation or zero stalls. Reports include walking, fast travel, queue/worker/commit times, water-array costs and memory. No export, commit, push or history rewrite was performed.

Reproduce: `tools/rocky_coast/verify_project.ps1 -Review -Normal -Benchmark -Smoke`. `review_all.ps1` runs two capture-only engines at a time with separate logs/reports; do not use overlapping capture processes to measure performance. A single batch can be retried through `run_test.ps1 -Script render_review -GPU -Extra '-- batch=4 feature=...'`. Generated reports/images and local baseline fixtures are ignored by Git. Git-eligible files were checked below 100 MB.

---

# Mountain Range terrain (2026-10-17)

Terrain/water only. Press **F2** to find Mountain in the saved six-biome world; **Ctrl+F2** cycles 18 Mountain views and Ctrl+F5 returns to shaded. Enable Terrain's Mountain Preview and choose a feature in the Inspector, or launch with `-- mountain-preview mountain-feature=glacial_country`. `data/mountain_previews.json` records 33 seed-73921 locations selected from the actual generator, including all 16 regional appearances, ridge/valley/water features and five live-biome transitions. Desert, Snow and Stone remain retired.

`mountain_settings.tres` controls connected warped ridge backbones, summit/saddle descriptors, descending secondary ridges, broad highland/granite profiles, V/U valleys, glacial shoulder hollows, protected tarns, elongated valley lakes, channels, scree/talus aprons and fans. These are deterministic geometric approximations, not physical erosion or glacier simulation. Finite watershed water potentials drain away from divides; this is not a global flow solver. The current 32 m C1 canonical field and heightfield cannot produce overhangs or caves. Very small details and narrow streams become coarser at distant LODs; silhouettes and far shading still have visible heightfield simplification and are not a photographic match to the references. No collision system is installed in this checkout, so collision validation is unavailable.

Mountain uses three new photographed ambientCG CC0 PBR sources: Rock051, Ground108 and Gravel040; it reuses existing Rock042L, Rock055, Ground030, Ground026, Ground048 and Rock064 roles. Source/checksum manifests: `data/mountain_material_sources.json` and `data/mountain_shared_sources.json`. New compressed layers total 20,971,680 GPU bytes. Maximum three base roles are selected per pixel (quality setting can reduce this to two); existing bounded macro/meso cliff-normal selection is reused with Mountain-only strengths and signed triplanar gradients. Wetness and roughness vary together. No synthetic crack texture or generated bitmap was added. Albedo gain is Mountain-specific; shared sun/sky/exposure/fog were preserved.

All existing custom banks remain available. Mountain-containing chunks use a negative CUSTOM0.x sentinel, byte-packed legacy geology and Mountain controls, plus packed UV2 channels decoded in the vertex shader BEFORE interpolation. This introduces 8-bit legacy geology/surface quantization only in extended chunks. With Mountain coverage zero, previous complete mesh arrays compare exactly. Shared water remains a single numerical grid/material per leaf (`SwampWater` is the compatibility node name), clipped against the same terrain vertices and included in transactional partition swaps. Mountain water has zero Swamp flood-stage weight. Caches are per worker and bounded: nodes 16384, regions/carriers 2048 each, summit descriptors 1024.

Validation on Godot 4.6.1, Compatibility, RTX 3060 Laptop:
- 6260 Mountain invariant checks, three seeds, reverse/cache eviction, C1 boundaries, adjacent land/water/normals/payload, six parent-child LODs, six-biome mass, independent inland water elevations, Mountain-disabled complete legacy-array equality.
- GPU extended payload: 143 positive tiles + one deliberately corrupt negative tile; zero errors. Texture-origin precision: 63 positive cases + one negative case.
- Normal-map visibility: all four surfaces passed; strength-zero versus normal-off maximum pixel error 0.0.
- 198 actual captures (33 locations × six views), plus focused tuning captures; eight source-game launches passed including the saved world. Reports/images are generated under ignored `tools/mountain/artifacts`.
- Existing quadtree partition and six-biome cache-order tests passed. Previous Jungle/Forest/Savanna/Swamp deterministic and PBR suites passed.
- Reproduce: `tools/mountain/verify_project.ps1 -Review -Normal -Benchmark -Smoke`. Local baseline fixtures are intentionally ignored; baseline profiling requires the local pre-change snapshot. No export or history rewrite was performed.

Comparable native benchmark (1280×720, same seed/XZ/controller, terrain-following at 80 m, far 50,000 m, maximum LOD 6):

| Mode | Initial fill | Teleport settle | Static GPU p50 | Static frame p50 |
| --- | ---: | ---: | ---: | ---: |
| Pre-Mountain Grass baseline | 3.96 s | 2.56 s | 6.71 ms | 16.66 ms |
| Current Grass | 4.07 s | 2.54 s | 7.70 ms | 16.67 ms |
| Mountain | 6.77 s | 4.26 s | 9.42 ms | 16.66 ms |

Mountain cold 16/64/128-resolution CPU chunk medians: 17.6/143.9/537.6 ms on workers. Static CPU memory 103.9 MB, reported video memory 366.6 MB, 130 draw calls versus baseline 89.5 MB/236.0 MB/102 calls. These measurements are hardware-specific and vsync-limited; 60 FPS does not mean generation or rendering is free. The larger Mountain footprint includes conditional far silhouette refinement and shared inland-water grids.

---

# Terrain tuning

## Current addition: Swamp terrain and local water

Swamp is the fifth active biome (Grass, Forest, Savanna, Swamp, Jungle).
It has independent low-relief wetland geography rather than a dark Grass tint.
Fifteen regional identities cover flooded lowlands, shallow water, mudflats,
river floodplains, blackwater, peat-like ground, muddy islands, bayous, seasonal
basins, hummock/hollow country, deeper backwaters, swamp lakes, rocky wetlands,
coastal lowlands and partially drained uplands. No trees, foliage, roots,
decorative props, animals or insects are created. Retired Stone/Desert/Snow stay
retired; no absent Tropical biome was invented.

**F3** locates actual raised Swamp ground in the mixed world. **Ctrl+F3** cycles
twenty Swamp diagnostics; Ctrl+F5 restores shading. The normal mixed-world
startup now prefers Swamp. Disable Start In Swamp (and the other biome starts)
to retain the saved camera start. Saved island sizes and the unusually large
Grass region scale remain unchanged. Swamp Coverage zero preserves the complete
previous four-biome terrain mesh channels, including their array layouts.

Tune `swamp_settings.tres` or Terrain Settings → Swamp Terrain. Regional scale,
coverage, relief, raised ground, hummocks, water depth, channel width, pools,
levees, sediment, material scales/strengths and far mesh spacing are exposed.
Restart after terrain-setting edits: workers use immutable resource snapshots.

### Swamp hydrology and rendering

The worker-owned sampler uses a bounded 16 m canonical lattice and C1 bicubic
interpolation. Main channels reuse existing river carriers. Side channels peel
off and rejoin those carriers; suitable floodplains have natural levees,
backswamps and rare partial abandoned bends. Irregular enclosed basin descriptors
use distinct inland water elevations with retaining rims. Connected channels
share a continuous gently graded regional water potential. This is a
deterministic approximation, not hydraulic simulation or a global flood fill.

Small elevation differences drive saturation, muddy shore zones, organic ground,
sediment and shallow flooding. Peat-like regions use a distinct photographed
organic muddy floor, not ordinary dirt tinted black. Raised corridors and islands
emerge from broad terrain fields and levees; a dry crossing is not guaranteed.

Each streamed terrain tile has at most one shared-material water child, with
numerical arrays produced off-thread and GPU resources installed on the main
thread. Its vertices use the same world water field and topology as its terrain
tile; fragments clip against the interpolated land height. No separate pond nodes
or materials are spawned. Water joins the same transactional LOD cut and bounded
mesh cache as terrain. Large-scale water and land locations are canonical;
coarse distant polygons still approximate small shoreline detail. Selective
Swamp-interior refinement retains the existing 50 km view distance and maximum
LOD; it does not globally increase resolution.

Swamp water has gentle normal-only ripples and context-dependent sediment,
organic tint, transparency and roughness. Shallow surfaces reveal actual
underwater terrain; deeper water becomes murkier. The shared ocean renderer,
Sun, sky and fog are unchanged. Coastal water blends toward the existing ocean;
there is no tidal simulation.

`Terrain.set_swamp_flood_stage(0..1)` adjusts local surface elevation and wet
material margins by up to one metre using existing buffers, without rebuilding
terrain or changing channel locations. It is a bounded appearance control, not
a weather/season simulation. It does not make every disconnected basin connected.
Exposed Season controls suitable drying-mud material; it never changes geometry.

### Swamp PBR sources

Three new CC0 ambientCG photogrammetry sources provide actual 2K color/roughness
and 1K OpenGL-normal maps: Ground036 mud, Ground083 wet river sediment and
Ground071 organic muddy woodland ground. Ground071 is used as a peat-like
appearance, **not a verified peat sample**. Four existing Jungle sources provide
organic soil, drying cracks, gravel and wet rock. Ground031 drying cracks are
catalogued PBRApproximated; the new sources are scans. No synthesized bitmap
textures were added. At most three active PBR roles are sampled per fragment.

The three new BC3 color/roughness + BC5 normal layers add 20,971,680 GPU bytes
(~20 MiB) including mipmaps, plus any shared Jungle array not already resident.
Source URLs, treatments and SHA-256 map checksums are in
`data/swamp_material_sources.json`; shared-role provenance is in
`data/swamp_shared_material_sources.json`. Offline fetch/packing helpers are
under `tools/swamp`; nothing downloads at runtime. Quarter-metre-quantized repeat
sizes and integer-wrapped origins preserve local texture phase at large coordinates.

### Swamp validation helpers

`data/swamp_previews.json` contains 27 seed/coordinate starts found from the actual
procedural generator, including active-biome transitions. Launch, for example,
`-- swamp-preview swamp-feature=bayou`. Set Terrain → Swamp Preview Feature to
any manifest name. These are procedural locations, not handcrafted showcase scenes.

Run `tools/swamp/verify_project.ps1` for CPU, PBR and native shader checks.
Optional `-Review -Normal -Flood -Benchmark -Smoke` adds rendered multiscale
captures, normal visibility, flood-stage buffer stability, matched performance
measurements and main-scene launches. Artifacts and local pre-change fixtures
are Git-ignored. No exports are performed. There is no terrain collision system
installed in this project, so no collision validation is claimed.

### Swamp verification recorded October 17, 2026

Godot 4.6.1 Compatibility / RTX 3060 Laptop / 1280×720 / 60 Hz vsync:

- 6,754 terrain/hydrology checks passed across three seeds: actual cache
  eviction, reverse order, C1 lattice boundaries, six parent/child LOD levels,
  adjacent land/water/control seams, varied local water elevations, and exact
  pre-Swamp mesh-array equality with Swamp disabled.
- All three scan layers passed compression, mipmap, checksum, albedo,
  roughness and normal-detail checks. GPU CUSTOM3 decoding passed 95 valid
  cases and detected the deliberately corrupt control case.
  Large-coordinate texture-phase checks passed 63 cases plus a deliberately
  failing control, including negative origins and positions beyond four million metres.
- All 27 actual-generator locations were rendered from ground, medium and
  aerial viewpoints plus material, normal and water-class diagnostics (162
  captures). Ground cameras were additionally reviewed with local-water
  clearance. Four source-normal visibility tests passed; zero strength exactly
  matched normal maps off in those comparisons.
- Flood stage visibly changed shallow margins (mean RGB difference 0.03977)
  while retaining all 150 terrain meshes, the partition revision, and 100
  sampled terrain heights.
- Seven source-game launches passed: bayou, swamp lake, four active-biome
  transitions and the saved mixed world. The saved-world start reported Swamp
  with 147 terrain leaves and 86 shared-material water tiles.
- Savanna, Forest and Jungle CPU/material/native-normal regression suites
  passed; all five active-biome locators passed. Retired biomes remain absent.
  The shared 3,000-sample cache-order check and all six hierarchical mesh checks
  also passed after integration.

Matched profile results (same seed, controller settings and world XZ):

| Mode | Initial fill | Teleport refill | Static GPU median | Frame p95 |
| --- | ---: | ---: | ---: | ---: |
| Pre-Swamp Grass | 3.84 s | 2.48 s | 6.02 ms | 16.77 ms |
| Current Grass | 3.73 s | 2.45 s | 6.76 ms | 16.83 ms |
| Swamp | 5.88 s | 4.05 s | 5.94 ms | 16.78 ms |

Swamp generation costs more than Grass. Water-array construction measured
0.37–0.46 ms at 16 resolution, 5.44–5.64 ms at 64, and 21.13–23.72 ms at 128,
on workers. A warm 1,000 local-water query pass took 31.66 ms. Measured Swamp
draw calls were 162 in the static view; video memory was ~331 MB static and
~334 MB after a regional teleport, with a ~364 MB travel peak. These are
specific test-scene measurements, not universal frame-rate or memory guarantees.

No Git-eligible working-tree file exceeded 100,000,000 bytes. The largest new
raw map was 9,995,566 bytes; Git history was not rewritten. There was no export,
collision test or full-project animal/source-asset reimport.

## Previous addition: Grass + Forest + Savanna + Jungle (terrain only)

Savanna has independent geography and materials, not a recolored Grass biome.
Its thirteen regional identities include golden plains, rolling and lush ground,
dry rocky plains, rugged hills, kopje country, highlands, dry valleys,
floodplains, semi-arid ground, red weathered soils, escarpments and basin country.
Terrain-only means no trees, grass meshes, shrubs, decorative rocks or animals
were added. Kopjes are continuous heightfield rock masses, not overhangs or
stacked prop meshes. The project still has no terrain collision system.

The normal mixed world now starts above actual Savanna land. **F4** finds it
again; F9 finds Forest and F8 finds Jungle. Disable Start In Savanna, Start In
Forest and Start In Jungle to retain the saved camera start. Existing huge Grass
region settings are preserved, so real biome locations can be far apart.
Savanna coverage zero restores pre-Savanna ownership and geometry. Retired Stone,
Desert and Snow biomes remain retired; transitions cover Grass, Forest and Jungle.

Tune `savanna_settings.tres` or Terrain Settings → Savanna: regional frequencies,
relief, kopjes, erosion, drainage, basin water, ground/rock scale, normal strength,
material quality, path wear and season. Restart after edits so workers receive
the new immutable snapshot. Season changes only surface appearance; it does not
move terrain, water or biome boundaries. Sun, sky, fog and ocean are unchanged.

The sampler uses deterministic 32 m C1 height interpolation with bounded caches.
Connected ridges, shallow plains hollows and weathered rock exposures coexist
with finite tributary gullies and the existing river/lake carriers. Most channels
and clay pans are dry; permanent water remains at the existing sea level. There
are no elevated lakes, hydraulic simulation or dynamic flooding. Worn paths use
the existing curved graph, noisy edge falloff and mixed ground materials.

Eight Savanna PBR layers plus three reused palette roles cover dry/green grass,
sparse grassy soil, red weathered soil, hardpan, cracked basin soil, bedrock,
gravel, organic wet ground and sandy sediment. Seven unique ambientCG sources
are CC0: five photogrammetry sources, Grass003 (catalogued PBRProcedural), and
Ground031 (PBRApproximated). Dry grass and red soil are documented color grades;
the latter is not a chemical laterite claim. Rock055's rectangular source maps
are normalized to square array layers. Sources, treatments and SHA-256 checksums
are recorded in `data/savanna_material_sources.json`.
The eight 2K BC3 color/roughness and 1K BC5 normal layers, with mipmaps, add
55,924,480 GPU bytes (~53.33 MiB), excluding the already-shared palette.
Chunk-local UVs plus integer-wrapped origins preserve photographed detail at
large coordinates; distant detail fades while geographical variation remains.

Terrain → Savanna Preview Feature offers 23 reproducible starts, including
kopjes, wet/dry channels, basins, trails and all three active transitions.
Source launch example: `-- savanna-preview savanna-feature=isolated_kopje`.
**Ctrl+F10** cycles fourteen Savanna diagnostics; Ctrl+F5 restores shading.
Coordinates and seed are in `data/savanna_previews.json`.

Verification: `tools/savanna/verify_project.ps1 -Review -Normal -Benchmark` and
`tools/savanna/smoke_launch.ps1`. These launch the source game, never an export.
Local screenshots, reports and pre-change benchmark fixtures are ignored test
artifacts. Selective distant rocky-region mesh refinement preserves the existing
50 km camera range and maximum LOD rather than reducing visibility.

### Savanna verification recorded October 17, 2026

Godot 4.6.1 Compatibility / RTX 3060 Laptop / 1280×720, source launches only:

- 11,349 invariant checks passed, including three seeds, shared LOD boundaries,
  season-independent geometry, disabled-biome baseline equality and exact
  support-culling optimization comparisons.
- All eight PBR layers, source checksums, nonconstant roughness/normal maps,
  95 packed GPU payload cases and 63 large-coordinate UV cases passed.
- Captured all 23 preview features at ground, medium and aerial distances plus
  material/normal diagnostics; located and recaptured an actual rendered trail.
- Normal-map visibility and zero-strength controls passed across five surfaces;
  three dry/wet appearance comparisons passed without geometry changes.
- All five main-scene smoke launches passed, including the saved mixed world
  and three active biome transitions. Forest/Jungle regression suites passed.
- An additional 3,000 cache-order samples and six parent/child LOD checks passed.
- Static GPU median was 5.73 ms, frame p95 16.73 ms (60 Hz vsync). Initial
  streaming fill was 7.36 s versus 3.64 s pre-Savanna and 3.79 s current Grass.
  Savanna is more expensive to generate; these are measured scene results,
  not a guarantee for every location/device. Teleport refill was 4.70 s.
- No Git-eligible working-tree file exceeded 100,000,000 bytes; largest was
  an existing animal Blender source (37,659,160 bytes). Git history was not rewritten.

There was no export, collision test or full-project asset reimport. Existing
unrelated animal-source import problems are outside this terrain validation.

## Forest implementation notes (pre-Savanna startup described below)

Forest is a separate temperate terrain biome, not a Jungle recolor. Its ten
regional identities cover deciduous lowlands, conifer uplands, mixed woodland,
old-growth basins, rolling hills, rocky woodland, mountain forest, sheltered
valleys, riparian flats and open meadows. These names describe geography and
floor materials; **no trees, understory, logs, roots, props or canopy were added**,
as requested. There is no terrain collision system in the current project.

The normal mixed world starts above actual Forest land. **F9** finds Forest
again and **F8** still finds Jungle. These locators do not force preview coverage.
Disable Terrain → Start In Forest (and Start In Jungle) to retain the saved
camera start. Your Grass region size of 940,000 metres is preserved, so regions
can be very far apart. Forest Coverage defaults to 20; set it to zero to restore
the pre-Forest ownership and geometry. Existing Grass/Jungle source geometry
is regression-tested against a local pre-Forest snapshot with Forest disabled.

Open `forest_settings.tres`, or Terrain → Settings → Forest Terrain → Forest,
to tune region frequencies, hills/mountains, erosion-shaped ravines, valleys,
rivers/streams, lakes, litter, moss, soil, clearings, rock exposure and trails.
Material tile sizes are metres per repeat, quantized to quarter metres for stable
large-world texture phases. Texture UVs use precise chunk-local positions plus
an integer-wrapped world origin; broad selectors stay world-anchored, so phase
does not reset at chunk boundaries. Normal Strength and Rock Normal
Strength independently control the real scanned normal maps. Restart after
editing: terrain workers use immutable settings snapshots. No global lighting,
Sun, sky, fog or ocean configuration was changed for Forest.

Deciduous ground uses CC0 ambientCG Ground023 broadleaf litter with Ground077
decomposed warm humus; conifer ground uses Ground070 mixed needle/root woodland
litter. Ground070 is **not a pure needle-only botanical scan**. Soil, moss, mud,
gravel and exposed/mossy rock reuse six existing CC0 Jungle scan layers, without
copying them into another GPU array. Source maps and SHA-256 provenance are in
`data/forest_material_sources.json`. Two new 2K BC3 albedo/roughness + 1K BC5
normal layers add 13,981,120 GPU bytes (~13.33 MiB), including mipmaps.
Source-detail fades to the same scans' average colors in the distance, reducing
repeat-pattern aliasing without adding procedural microtexture.

Forest river beds, finite tangent tributaries, floodplain terraces and irregular
lake basins reuse the existing deterministic water network. All visible water
remains at the shared sea level: there are no elevated lake surfaces, waterfall
meshes or hydraulic simulation. Globally disabling water/rivers/lakes also
disables the respective Forest carve. Trails reuse the existing curved path
network with Forest-specific width, noisy falloff and dirt/gravel/wet material
selection; they are material wear, not navigable road geometry.

Terrain → Forest Preview / Forest Preview Feature offers 18 reproducible starts.
Use `-- forest-preview forest-feature=mountain_forest` on a source-game launch.
F10 cycles the 11 Forest diagnostics (regional identity, conifer influence,
clearing, wetness, leaves, needles, moss, rock, trails, materials, normals).
Ctrl+F5 restores shading. `data/forest_previews.json` records seed/coordinates.
Swamp/Snow transitions are not supplied because those biomes are absent/retired.

Verification helpers: `tools/forest/verify_project.ps1 -Review -Normal -Benchmark`
and `tools/forest/smoke_launch.ps1`. They launch the source project, **not exports**.
Review artifacts are ignored local files in `tools/forest/artifacts`; the
pre-change baseline is a local ignored test fixture, not shipped game content.
Far Mesh Metres defaults to 256; 128 retains denser distant ridges but takes
longer to generate. The maximum LOD and 50 km camera range are unchanged.

### Forest verification recorded October 16, 2026

Godot 4.6.1 Compatibility / RTX 3060 Laptop / 1280×720, source launches only:

- Forest invariants: 9,583 checks passed across three seeds, including exact
  pre-Forest mesh comparisons with Forest disabled.
- Jungle invariants: 8,694 checks passed; active-biome and placement regressions
  passed. Cache-order regression: 3,000 points; shared parent/child meshes passed
  at all six LOD levels.
- GPU payload test: 63 valid tiles + one deliberately invalid tile passed.
  This caught/fixed the shared float24 decoder's erroneous `+0.5` rounding.
- GPU texture-phase test: 63 valid tiles + one deliberately invalid tile passed,
  including negative and >3.6-million-metre origins. Positive-magnitude integer
  wrapping avoids renderer-dependent negative remainder behavior.
- Eight material roles plus shared broadleaf litter: 27 source SHA-256 checks,
  compressed mip chains and nonconstant PBR channels passed.
- Rendered normal-strength tests passed in four Forest and three Jungle regions;
  zero strength exactly matched the normal-maps-off view on tested terrain.
- All 18 Forest previews were rendered at ground/medium/aerial/material/normal
  views (90 captures with 128 m far spacing). Deciduous was recaptured with the
  final precision fix and 256 m default. Four final source-game launches passed:
  mountains, both active-biome transitions, and the saved mixed world.
- Saved-world Forest start was verified at approximately (-625301, 127, 3642807),
  without forcing preview mode. F9 searches the actual mixed world.
- `git diff --check` passed. No Git-eligible working file exceeded 100,000,000
  bytes (1,229 checked at the audit; largest was an existing 37,659,160-byte model).
  This is a working-file check, not a Git-history rewrite or push test.

Final same-machine benchmark, including full streamed partitions:

| Case | Initial fill | Static GPU median | Static frame p95 | Reported video memory |
| --- | ---: | ---: | ---: | ---: |
| Pre-Forest Grass snapshot | 3.91 s | 5.78 ms | 16.72 ms | 225.1 MiB |
| Current Grass, Forest disabled | 4.05 s | 5.89 ms | 16.85 ms | 227.1 MiB |
| Forest, 256 m distant target | 9.00 s | 5.22 ms | 16.78 ms | 294.1 MiB |

Cold 16-resolution chunk median: 14.74 / 14.86 / 17.68 ms respectively;
64-resolution: 162.87 / 161.95 / 191.60 ms. Forest teleport settle was 5.05 s,
worst measured partition commit 11.12 ms, plan 3.22 ms. These are single-machine
samples, not platform guarantees; steady frames were vsync-limited near 60 FPS.
The earlier 128 m Forest target took 17.24 s to fill and 7.80 s to teleport;
the 256 m default reduces distant geometry cost. Forest still costs more to
generate than Grass. Forest-only tests also load the shared Jungle array;
already-Jungle-enabled worlds pay only the two new scan layers incrementally.

No export/build package, vegetation, collision, elevated-water rendering or
new lighting system was created or claimed tested. The global climate field is
still diagnostic, not a new temperate-climate biome ownership model.

## Previous Grass + Jungle state

Stone, Desert and Snow have been removed from the active generator, terrain
settings, preview controls and shader. Older sections below describe retired
implementations and historical test results, not the current game.

Before Forest was added, the normal world started over generated Jungle land. Press **F8** to jump
to Jungle again; this searches your actual mixed world, without forcing a
preview or changing its coverage. Disable Terrain → Start In Jungle to keep
your saved camera start. Your existing Grass region size/coverage are preserved;
Jungle has a nonzero default coverage. Terrain → Settings → Biome Regions now
contains only Grass and Jungle. Reduce Grass Region Size if you want less
travel between the huge regions in the saved preset.

Jungle is now dominated by vibrant green CC0 moss/ground cover. Edit
`jungle_settings.tres` → Materials → **Green Tint**, **Green Coverage**, and
**Albedo Gain**, save, then restart. Mud, leaf litter, soil and rock remain
independent secondary materials. Normal-map strength and tile-size controls
remain available. The tint is explicitly converted from sRGB to linear before
binding, avoiding the washed-out/neon result of treating Inspector colors as
linear RGB. The source PBR texture detail is retained.

F6 cycles Jungle diagnostics, F5 cycles all current views, Ctrl+F5 restores
shading. Terrain → Jungle Preview / Jungle Preview Feature also provides a
dropdown of reproducible region starts. Shared sand and rock **materials**
are retained for Grass beaches, paths, cliffs and Jungle; these are not removed
Desert/Stone biomes. Old standalone assets/tools are retained as inactive
historical work rather than deleting potentially shared source maps.

Current verification: `tools/jungle/verify_project.ps1 -Normal` and
`tools/jungle/smoke_launch.ps1`. The Snow/Desert regression suites are retired
with those biomes; earlier performance comparisons are historical.

## October 16: Snow biome

Open `snow_settings.tres` in Godot's Inspector, or expand Terrain → Settings →
Snow Terrain → Snow. Change **Regional Terrain**, **Accumulation**, **Wind and
Drifts**, **Glaciers**, **Frozen Water**, and **Materials**. Restart the running
scene after edits; workers use immutable settings snapshots. The separate
**Legacy Snow** fields are retained for old resources/baselines and no longer
control the new Snow terrain.

Texture sizes are metres per repeat: larger Powder/Crust/Ground/Rock Metres
make that source texture larger. Powder Strength, Crust/Rock/Ice/Ground Normal
Strength and Macro Strength are independent controls. Normal
Strength multiplies the powder/crust source maps. Master Normal Strength scales
all Snow overlays; set it to zero for a permanent normal-maps-off comparison.
Wind Texture Metres sets the scanned wind-detail repeat; Ice Metres sets the ice
repeat. The old synthetic ripple controls have been removed. Colour Variation affects only
broad shading variation, not a scattered high-frequency white/grey mask. Increase
Rock Exposure for more dark rock, or reduce Snow Depth/Sheltered Accumulation.
Slope Influence changes snow retention; it is not the sole material classifier.

For a repeatable inspection, enable **Snow Preview** on Terrain and select
**Snow Preview Feature** from its dropdown. Alternatively launch Godot with
`-- snow-preview snow-feature=valley_glacier`. All 17 names and discovered
coordinates are in `data/snow_previews.json`. Preview uses seed 73921 and does
not save over `terrain_settings.tres`. `partial_lake` uses a declared runtime
50% lake-ice setting; `grass_snow_transition` uses 50/50 Grass/Snow and 24 km
biome regions. Other previews retain the normal Snow resource defaults.

**Alt+F5** cycles 12 Snow debug views (regions, depth, flow/wind proxy, exposure,
accumulation, rock, glacier, ice strain, frozen water, materials, mapped normals,
LOD). **Ctrl+F5** returns to shaded. **F7** toggles the existing 1.80 m scale
reference; **P** places it. The HUD identifies the Snow geographic region.

Snow remains within the existing world sampler and streaming architecture.
Geometry uses a fixed 64 m Hermite field and common world-space 32 m normals;
fine frost, grains, and cracks are shader detail. Pure-Snow distant parents have
optional 512 m maximum edges (bounded to 64 vertices per edge); Grass and Desert
resolution policies are untouched. Fast Normal Sampling evaluates the exact
Hermite derivative at canonical 32 m normal nodes in dry pure-Snow interiors,
with a fixed 32 m fallback at coasts/mixed terrain. It does not use a separate
noise normal. Snow's unused Grass-curvature field is zero in those interiors.
Disable the option for central derivatives. Neither option changes view distance.
Specialize Pure Snow Shader compiles the same shader without unrelated biome
branches for tiles certified entirely Snow. Boundary/mixed tiles retain the
general shader. Textures, settings, debug controls and streaming remain shared;
the normal-visibility test also compares specialized/general rendered pixels.
Regional weights interpolate without per-cell easing, and knot tangents include
their changing weights. This avoids the former 512 m shelves/64 m ladder bands.

Frozen rivers/lakes reuse the existing river carriers and seeded lake sites.
The project currently has only sea-level water, so these are sea-level basins,
not invented elevated water planes. Solid ice is in the canonical heightfield
above the existing wave envelope; open leads expose the existing water plane.
Coastal ice is limited to cold local near-shore areas, not the whole ocean.
Water Enabled off disables frozen-water bodies but retains land glaciers.
Crevasses are finite surface depressions and shading, not tunnels or holes.
There is no terrain collider in this project; these tests do not claim walking
or collision validation.

Snow now uses CC0 AmbientCG Snow005 (clean powder), Snow006 (compacted crust),
Snow014 (wind/meso surface detail), and Ice004 (cracked ice). The three snow
sources are photogrammetry; Ice004 is an AmbientCG pre-baked procedural asset.
No runtime synthetic fracture, cosine ripple or analytic snow-relief generator
is used. Geography/accumulation remain procedural; low-cost masks blend samples
to suppress tiling, rather than inventing surface texture. Existing Rock035
and Gravel020 serve exposed rock and ground. Global sky, sun, weather and ocean
shader are unchanged. Provenance, CC0 links and SHA-256 hashes are recorded in
`data/snow_material_sources.json`.

The shared Snow palette uses 2K BC3 colour/linear roughness, 1K OpenGL BC5 normal
XY, and 1K BC4 height, all mipmapped/aniso filtered. Prepared GPU data totals
29.33 MiB, split into small external Image resources instead of one huge binary.
Raw sources are under `assets/textures/snow/` with `.gdignore`: they are retained
for reproducibility, not re-imported or converted during game startup. Run
`tools/snow/fetch_materials.ps1` only to restore the CC0 source downloads, then
run `tools/snow/build_materials.gd` headless to rebuild the prepared resources.
Restart the scene after rebuilding. Do not run the offline packer from the game.
Rejected grassy/boot-print candidates were moved to the ignored local
`.godot/snow_downloads/rejected_candidates/`, not retained as runtime assets.

Run `tools/snow/check_invariants.gd` and `tools/snow/check_materials.gd` headless, and
`tools/snow/check_gpu_channels.gd` with a real display. Run
`tools/snow/render_review.gd` for the 17 × 5 game-lighting captures, and
`tools/snow/benchmark_snow.gd` for native streaming/frame measurements.
Local generated evidence is ignored under `tools/snow/artifacts/`.
The pre-change baseline is local-only under `tools/snow/baseline/`; optional
baseline comparisons require that snapshot. No export is part of this workflow.
The free camera is raised above terrain/water at startup if its saved position
would be underground; subsequent movement and requested teleports are unchanged.
Terrain-fill measurements are not full cold-start timings: first-time shader
compilation and resource loading can add startup time.
Acceptance details and remaining gaps: `tools/snow/CLOSEOUT_20261016.txt`.

## September 28: current streaming controls

See `tools/MASTER_TERRAIN_REPORT.md` for results and limitations. Streaming now
uses variable-size quadtree leaves, not a fixed render-distance grid. Defaults:
base size 256 m, Maximum LOD 6, Split Distance Ratio 0.95, Merge Hysteresis 0.35.
The 3-by-3 root footprint is 49,152 m wide. Raising the split ratio increases fine
coverage and cost. Camera leaf resolution is 128, other level-zero leaves 64,
level one at least 32, larger leaves 16. Historical fixed-grid descriptions and
benchmark reports below are superseded by `tools/STREAMING.md` for scheduling.
Latest surface and distance results: `tools/REGIONAL_SURFACE_REPORT.md`.

Grass Geographic Scale (18,000 m) and Grass Geographic Variety control broad
landform provinces independently of island and biome size. These modify existing
terrain fields; they do not select a second generator.

F5 cycles shaded, material weights, IDs, unlit albedo, geometry normals,
wireframe, geology controls, normal maps off, mapped normals, and quadtree bounds.
Run with `-- grass-preview` for a Grass-only runtime snapshot without modifying
the saved preset. The normal-world biome HUD describes camera XZ, not view focus.

Use `Terrain.request_teleport(destination)` to hold the camera on existing terrain
until replacement coverage is ready. Direct camera position assignment bypasses
this guarantee. The complete old partition remains visible during streaming;
startup waits for the entire first partition. Coarse parents cannot resolve all
small biome boundaries, narrow cliffs or riverbanks.

## Temperature eligibility

Temperature is enabled by default. In the preset's Temperature group, adjust climate
region size, average temperature, variation, snow maximum and desert minimum.
The climate field is deterministic, broad, and automatically kept larger than hot/cold
region sizes. Snow requires the entire assigned region to be below its maximum;
desert requires the entire region to be above its minimum. The limits enforce at least
a 5 C gap. Unsuitable regions become grass (or stone if grass is disabled and stone
is enabled), rather than being split into small climate fragments. If neither neutral
biome is enabled, grass is still used as the separation fallback.

Coverage is a requested distribution before temperature eligibility. Eligible snow
and desert regions receive a local selection preference so they remain discoverable.
Climate restrictions still affect actual coverage; a small area need not contain all
biomes. Disable temperature to restore unrestricted coverage behavior.
This is a regional biome temperature model, not seasons, weather or player survival.
The debug bar displays temperature and the cold, temperate or hot zone at the camera's
horizontal position, or explicitly says climate OFF.

For accessible snow and desert, enable Temperature Enabled and use these defaults:

| Temperature setting | Default | Effect |
| --- | --- | --- |
| Average Temperature | 14 | Lower favors cold areas; higher favors hot areas. |
| Temperature Variation | 48 | Increase to make both cold and hot extremes more common. |
| Snow Max Temperature | 8 | Raise to allow snow in warmer regions. |
| Desert Min Temperature | 20 | Lower to allow desert in cooler regions. |
| Climate Biome Preference | 6 | Boost eligible snow/desert selection within suitable climates. |
| Temperature Region Size | 24000 | Climate wavelength before global biome scaling; automatically enlarged to fit complete hot/cold regions. |

The saved preset may override Temperature Enabled. Change settings while stopped,
save, and restart. These controls do not change island placement or island size.
The temperature field now repeats full-range cold/temperate/hot zones, bent by the
biome domain warp. Exact extrema over each region replace conservative derivative
estimates. Defaults yielded about 19% desert and 21% snow in the regression sample;
custom coverage, temperatures and extreme region sizes can change this distribution.

Select **Terrain** in main.tscn and expand **Terrain Preset → Settings**, or open `terrain_settings.tres` directly in Godot's Inspector. Edit while stopped, save, then restart the game. Settings are snapshotted on startup so worker threads, cached meshes, shaders and the scale marker stay consistent. Remote Inspector edits are not live regeneration controls.

Streaming, LOD, world seed and sea level are on the Terrain node; camera speed, sprint and sensitivity remain on FreeCamera. Duplicate the preset resource to keep alternative worlds.

Coverage is a nonnegative relative target for world-area share. Values normalize together: 50/20/20/10 means approximately 50% grass, 20% desert, 20% snow and 10% stone over a large area. Zero disables a biome; all zero falls back to grass. This measures biome assignment over the world plane, not exact visible land percentages (water, slope rock and beach overlays are separate).

Region Size sets a target region footprint independently of coverage. The world is partitioned hierarchically: large regions are assigned first, and only unassigned space is subdivided. A claimed large region cannot be punctured by smaller biomes. Coverage controls the probability of assigning entire regions at each scale. Region scales are rounded to powers-of-two multiples of the smallest enabled biome size (within about 41% of the requested scale); adjacent regions of the same biome can merge. Smooth invertible border distortion keeps regions connected and preserves expected area shares. Water can still divide a region into separate islands.

For example, Stone Coverage = 2 with other coverage values totaling 98 gives approximately 2% stone over large areas. Increasing Stone Region Size makes fewer, larger regions rather than increasing their coverage. Coverage changes the number of whole regions, not their assigned footprint. Global Biome Size scales all footprints; 0.05 makes regions twenty times smaller and does not zoom the camera. Very small regions may need higher mesh resolution; distant LOD now maintains a biome sampling floor up to the chosen maximum resolution.

The old competing seed-distance algorithm has been replaced. Saved sizes and coverage weights are preserved, but region locations change. The diagnostic map tool shows the saved settings beside small/large stone region comparisons; the regression test checks whole-region integrity in addition to percentages.

Start with Biome Size = 2 for broader regions, individual Region Size for one biome, and Texture Blend Sharpness for short/long borders (higher = shorter). Keep Detail Octaves low for generation speed. Increase resolution and near-detail radius cautiously because vertex cost grows quadratically. Terrain elevations are anchored to sea level; Ocean Depth and Height Multiplier change the geometry relative to it.

## Biome Regions

| Setting | Default | Effect |
| --- | --- | --- |
| biome_size | 1.0 | Global multiplier for all biome region sizes. |
| grass_region_size | 5000.0 | Typical grass region scale in metres. |
| desert_region_size | 4500.0 | Desert region scale in metres. |
| snow_region_size | 5500.0 | Snow region scale in metres. |
| stone_region_size | 3000.0 | Stone region scale in metres, independent of mountain detail. |
| grass_coverage | 50 | Relative world-area coverage weight; zero disables. |
| desert_coverage | 20 | Relative world-area coverage weight; zero disables. |
| snow_coverage | 20 | Relative world-area coverage weight; zero disables. |
| stone_coverage | 10 | Relative world-area coverage weight; zero disables. |
| height_blend | 4.0 | Regional weight sharpness for smoothly blending terrain heights. |
| texture_blend_sharpness | 4.0 | Higher values shorten the visible material transition. |

## Islands and Ocean Floor

Islands are irregular, warped cells separated by shoreline channels. Island Spacing
now controls typical water-channel width, not clearance between oversized
invisible disks. Values are reference metres at Island Size 1388.89: doubling island
size doubles all gaps as well. At spacing 1, land nearly touches; higher values widen
the channels. Island Spacing Variation gives each neighboring pair a deterministic
random width: default 0.75 ranges from 25% to 175% of the typical width before
coastline distortion. Set it to 0 for uniform channels. Oblique crossings and channel
junctions can have wider measured distances.
Coastline warping changes the exact local width. Island Size controls the typical
landmass scale, not a strict maximum diameter. Position jitter and area weights
produce varied sizes and irregular placement. Biome and temperature scales remain
independent. Land Threshold above 0.4 adds erosion and thus widens gaps further.
Coast Width changes slopes without pushing the sea-level shoreline inland.

A 1 m channel is below the default 4 m near-mesh vertex spacing and much smaller
than distant LOD spacing. The analytical terrain contains the channel, but meshes
can bridge it until resolution is increased. The overview should look almost all
land at this setting, not isolated islands surrounded by broad empty ocean.

| Setting | Default | Effect |
| --- | --- | --- |
| island_size | 1388.89 | Typical island scale in metres. |
| island_spacing | 250.0 | Typical channel width at reference Island Size 1388.89; scales with island size. |
| island_spacing_variation | 0.75 | Random pair-to-pair gap variation; 0 means uniform. |
| island_size_variation | 0.65 | Variation in neighboring island areas. |
| island_position_jitter | 1.0 | Center scattering; lower values expose more of the placement lattice. |
| island_coast_irregularity | 0.3 | Distortion of shared coastlines. |
| shoreline_detail_size | 350.0 | Local shoreline feature wavelength in metres; independent of island size. |
| shoreline_detail_strength | 90.0 | Local shoreline displacement in metres; 0 disables, capped at 30% of detail size. |
| island_octaves | 4 | More octaves add coastline detail. |
| land_threshold | 0.40 | Values above 0.40 additionally erode island radii. |
| coast_width | 0.13 | Coastal transition in fixed 694.445 m reference units; independent of island size. |
| land_height | 95.0 | Base continental height amplitude in metres. |
| ocean_depth | 24.0 | Ocean floor depth below sea level before height scaling. |
| seabed_relief | 3.0 | Seabed roughness amplitude. |
| height_multiplier | 1.0 | Scales terrain elevations relative to sea level. |

Large islands keep fixed-world-scale shoreline detail in addition to their broad
shape distortion. Lower Shoreline Detail Size for smaller, more frequent features;
increase Shoreline Detail Strength for deeper indentations. Fine coastline detail
can still be lost at distant mesh LOD or when zoomed far out. These settings do not
change biome scales or the size-relative island spacing controls.

## Grass Terrain

Grass now uses macro elevation, broad regional masks, elongated rolling forms,
multi-scale structural ridges and restrained local detail. Plains flatten these
layers; mountains fade through foothills. Plateau masks flatten elevated tops.
Drainage corridors lower the surrounding terrain before channel carving, and some
lake basins align with rivers. All sampling stays inside the existing worker-owned
builder: no alternate generator, terrain cache, scene nodes or chunk dependencies.

The existing water system is a single sea-level plane. Rivers, streams, ponds and
lakes therefore use sea-level beds, not elevated water surfaces. This is geometric
drainage approximation, not simulated downstream flow or hydraulic erosion. It does
not yet provide elevated mountain/plateau lakes. Narrow streams can disappear at
coarse LOD; their analytical positions/heights never depend on LOD.

River centerlines use multi-scale seeded noise with width variation and approximate
perpendicular bank distances through bends. Tributaries join one side of a trunk
rather than forming cross-shaped grid intersections. Lake shorelines combine unequal
lobes and local distortion. Mountain ridge crests use a smooth absolute-value curve
and suppress fine relief at the crest to avoid razor-edge/sawtooth silhouettes.

Regional wavelengths are independent of biome size: use a large Grass region and
large islands to see complete mountain/valley systems. Small Grass regions clip the
landform field through the existing biome blend, rather than shrinking the geography.

Key Inspector controls in **Grass Terrain**:

- Terrain Shape Scale: horizontal scale of all biome landforms and Grass drainage, independent of island/biome sizes. Height amplitudes stay unchanged.
- Landform Size and Macro Height: regional extent and broad elevation drift.
- Plains Frequency / Flatness: prevalence and suppression of relief.
- Rolling Strength, Hill Frequency, existing Hill Size / Height: countryside relief.
- Mountain Frequency / Height / Ruggedness, Ridge Strength, Foothill Size: ranges.
- Erosion Strength: medium directional cuts in mountain flanks. Escarpment Strength: sharper plateau margins without roughening plateau tops.
- Valley Strength, Plateau Frequency / Height: drainage relief and elevated flatter land.
- River Frequency / Width / Depth: 0 frequency disables river and tributary carving.
- Lake Frequency / Size / Depth: 0 frequency disables lakes; includes smaller ponds.
- Local Detail: metre-scale small relief, suppressed on plains and plateau tops.
- Grass Fractal Octaves (5), Gain (0.5), Lacunarity (2), Size (300 m), Strength (12 m): nested relief from broad surface undulations to finer erosion-like irregularities. Hills and mountains receive stronger detail, plains/plateau tops much less; valleys and lakes smooth it back down. Set Strength to 0 to disable. These are independent of Island Size, and follow Terrain Shape Scale. Very fine octaves cannot be resolved by distant LOD meshes; more octaves also increase sampling cost.

| Setting | Default | Effect |
| --- | --- | --- |
| grass_hill_size | 117.65 | Hill wavelength in metres. |
| grass_hill_height | 12.0 | Hill height amplitude. |

## Desert Terrain

The active implementation uses **Terrain > Settings > Desert Landscape > Desert**, backed by
`desert_settings.tres` and `scripts/desert_settings.gd`. Regions, Dunes, Sandstone,
Basins and Materials are separate Inspector groups. Older `dune_size`, `dune_height`,
`dune_warp` and `desert_roughness` fields remain stored for compatibility; they do not
control the active dedicated Desert sampler.

Occurrence controls select dune fields, complete canyon/wadi catchments and eligible
dry lakebeds. Their defaults are 1. Relief/incision/floor controls retain legacy saved
property names with readable Inspector aliases; they change strength rather than
occurrence. Settings apply at restart. Saved biome coverage/climate still determine
whether a normal world contains Desert.

An optional **Terrain > Desert Preview Feature** starts at one of thirteen previously
discovered seed-73921 coordinates using runtime biome overrides. Empty selection
retains normal startup. Shift+F5 cycles Desert debug views; Ctrl+F5 returns to shading.
See [the source review and manual inspection guide](tools/desert/SOURCE_REVIEW_20261014.md)
for exact coordinates, requirement map, asset provenance and remaining gaps.

The final continuation was run in Windows Godot 4.6.1: all 20 project checks passed,
with native streaming benchmarks, 39 geographical shaded plus 33 diagnostic captures,
and an additional 45 dune views covering five families in three signed seeds.
See [current fixes and verification](tools/desert/CLOSEOUT_20261015.txt).
Visual/performance limitations remain explicit, including slower CPU generation
than the simple-Desert baseline. No further exports are authorized or performed.

## Snow Terrain

| Setting | Default | Effect |
| --- | --- | --- |
| snow_hill_size | 117.65 | Snow drift terrain wavelength. |
| snow_hill_height | 8.0 | Snow hill amplitude. |
| snow_ridge_height | 12.0 | Additional snow ridge amplitude. |

## Stone Terrain

| Setting | Default | Effect |
| --- | --- | --- |
| mountain_size | 357.14 | Mountain ridge wavelength. |
| mountain_height | 170.0 | Mountain height amplitude. |
| mountain_sharpness | 1.6 | Higher values narrow the ridge peaks. |
| stone_roughness | 10.0 | Small stone terrain variation. |
| detail_octaves | 4 | Height detail layers. |
| detail_gain | 0.48 | Strength of successive height detail layers. |

## Surface Materials

| Setting | Default | Effect |
| --- | --- | --- |
| texture_tile_metres | Vector4(1.4, 3.5, 3.0, 4.0) | Metres per texture repeat: X grass, Y sand, Z snow, W stone. Keep positive. |
| sand_tint | Color(1.0, 0.82, 0.46) | Multiplies the ambientCG sand color. |
| normal_strength | 0.75 | Surface normal strength. |
| detail_distance | 180.0 | Normal/roughness textures fade out by this distance. |
| shore_width | 1.5 | Vertical sand band around sea level. |
| shore_strength | 0.75 | Beach sand blend strength. |
| slope_rock_start | 0.08 | Exposed rock starts around 23 degrees; parameter is 1 minus normal Y. |
| slope_rock_end | 0.30 | Full exposed rock around 46 degrees. |
| grass_roughness_floor | 0.94 | Minimum dry grass roughness, including distant rendering. |
| grass_specular | 0.06 | Grass reflectivity, independent of other surfaces. |
| grass_normal_scale | 0.4 | Grass normal-map relief relative to overall normal strength. |

## Water

| Setting | Default | Effect |
| --- | --- | --- |
| water_enabled | true | Show or hide the ocean surface. |
| wave_height | 1.0 | Wave amplitude multiplier. |
| wave_speed | 1.0 | Wave animation speed multiplier. |
| water_roughness | 0.32 | Ocean surface roughness. |
| shallow_color | Color(0.055, 0.19, 0.17) | Water base color. |
| deep_color | Color(0.025, 0.075, 0.10) | Water grazing-angle color. |

## Reference-quality pass and performance

The camera's single chunk defaults to Close Resolution 128 (2 m sampling at 256 m
chunk size). Existing near/middle/far rings stay 64/16/8; set Close Resolution to
64 to restore the previous nearest density. Mesh skirts remain enabled. Shared
LOD heights use exactly the same sampler, without camera-dependent octave removal.
The tiny surface detail stays in distance-faded normal maps. A continuous world-grid
normal field uses 32 m derivatives and interpolation for every vertex, not just chunk
edges. This removes the edge/interior derivative mismatch that caused stripe seams.
Grid heights reuse existing height samples where possible; a disposable halo handles
the remainder. Fine mesh geometry remains intact, while its lighting is smoother.

Biome weights and coastline masks computed during height sampling are reused by
mesh assembly in disposable packed arrays. No exploration-wide cache is added.
Workers still produce arrays only; ArrayMesh upload remains budgeted on the main
thread. The profiling tool reports array construction separately from mesh submission
(submission time is not GPU completion latency).

Grass landforms now use a ridge backbone with peak modulation, asymmetric faces,
secondary divides and negative drainage cuts. The regional masks still blend
smoothly, but the ridge profile no longer saturates into a rounded plateau.
Hills inherit elongated divides; plains retain subtle undulations. River corridors
include floodplain shelves, and lake basins grade into low shoreline terrain.

Height sampling also supplies mountain/drainage influence in UV2. UV.y contains
signed curvature from the existing normal-grid samples (no extra height queries).
These combine with slope, moisture and restrained world-space variation to select
grass, dry/highland grass, exposed soil, gravel banks and weathered rock. Existing
Grass001, Ground054 and Rock030 assets are reused, not new texture downloads.
Rock has a second 24 m triplanar layer using the actual asset color/normal maps;
fine 4 m detail remains underneath. Meso normals fade at 350–1100 m; micro normals
keep their existing distance setting. There is no height-skewed fake crack layer.
This is an approximation of the supplied landscape references, not full hydraulic
erosion, vegetation geometry, elevated water, or photographic parity.

River bank tangent-distance correction is restricted to the narrow water channel.
The broad valley and tributary floor masks use transverse distance instead: applying
the local tangent correction far from the river caused the repeated hillside fan
trenches/stripes. `tools/check_river_striping.gd` checks the isolated carving layer
against a river-disabled sampler to catch this regression.

Validation tools: `tools/check_grass_terrain.gd` (determinism, worker output, shared
LOD heights and edge normals), `tools/profile_visual_terrain.gd` (controlled Grass
render and stage timings), and `tools/benchmark_streaming.gd` (moving-camera load).

`profile_visual_terrain.gd -- after close` captures fixed overview and near views,
reports height/noise, normal-field and array assembly costs, a separate five-octave
noise microbenchmark, and ArrayMesh submission cost. Static full-material versus
simple-material frame time is an A/B rendering proxy, not isolated GPU timestamps.
There is no collision-generation stage in this freecam implementation. Profiling
is opt-in; production builds do not time individual samples. Tiny height octaves
are not dropped per LOD because shared vertex heights must stay identical; the
existing LOD vertex counts and shader-distance detail fade are preserved.

## Desert controls, feature starts and Windows builds

Select `Terrain` in `main.tscn`. Enable **Desert Preview** for an all-Desert world,
or select **Desert Preview Feature** for one of the 13 discovered landmarks.
Disabled/empty retains the saved biome world. These are runtime overrides;
`terrain_settings.tres` and the Grass preset are not rewritten.

Expand **Settings > Desert Landscape > Desert**, or open `desert_settings.tres`.
Tune regions, dune occurrence/width/height/spacing, canyon depth/incision,
basins, erosion, **Fracture Strength**, and **Wind Shelter Strength** there.
**Rock Relief Metres** controls the existing 95 m bedrock form field (default
24 m amplitude before ruggedness/exposure weighting). It does not add sand-grain
geometry, alter Grass, or override the graded drainage floor.
**Broad Rock Relief** in Materials controls continuous 180/620 m rock shading
after source normal-map grain mip-fades. Default 0.65; set 0 to disable. This
is a normal-only overlay, not an albedo noise mask or extra terrain geometry.
**Mesh Budget > Far Mesh Metres** limits distant Desert edge spacing (default
512 m, maximum parent resolution 64). Smaller values such as 256 add distant
silhouette detail but increase generation cost. Set 0 for the legacy parent
resolutions. Only rectangles certified entirely Desert are refined; Grass,
mixed-biome chunks, and all close-mesh resolutions are left unchanged.
**Fast Normal Sampling** uses two fixed-world forward height probes for dry
Desert lighting normals. It preserves geometry/material payloads and pure Grass;
disable it to compare the previous central-probe lighting. The setting is shared
by every LOD, not switched by camera distance.
Materials include **Albedo Gain** (Desert only), micro-normal strength,
macro-detail intensity, ripple wavelength/strength, gravel and salt coverage.
Save and restart to rebuild geometry/material settings. An occurrence control
selects complete fields; an incision/relief control changes their strength.

Shift+F5 cycles Desert diagnostics; Ctrl+F5 returns to shaded. New views include
dune-family mixtures (orange transverse, cyan longitudinal, yellow barchan,
purple star, green irregular), crest-direction proxy, upstream shelter and
canonical bedding. The crest direction is a field diagnostic, not an exact
survey of every branching ridge. F7/P toggles/places the 1.80 m scale marker.

Example standalone launch from the project directory:

```powershell
& .\builds\windows\PredatorIsle.exe -- desert-feature=major_canyon
```

`desert-feature=major_canyon` after `--` may be replaced with
`sand_sea`, `barchan_dunes`, `longitudinal_dunes`, `rocky_plain`,
`sandstone_highlands`, `badlands`, `dry_river_valley`, `alluvial_fan`, `salt_flat`,
`dry_lakebed`, `oasis_basin`, or `desert_grass_transition`.

The Windows Desktop release preset uses the matching official 4.6.1 release
template at `.godot/export_tools/windows_release_x86_64.exe`. Obtain it with
`python tools/desert/fetch_windows_template.py` if absent. Export with:

```powershell
& 'C:\Users\User1\Documents\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --export-release 'Windows Desktop'
& .\tools\desert\smoke_export.ps1
```

Keep the EXE and PCK together. Builds and large QA captures are excluded from
Git. Text-resource conversion stays disabled for export: converting GPU-backed
external-image arrays with the dummy headless renderer produced null layers.
The original salt recipe and source maps are in `assets/textures/desert/original_salt`;
it is an authored material, not a photoscan. Existing third-party assets remain
unchanged with their original provenance.

Current verification, measurements, commands and limitations are recorded in
`tools/desert/FINAL_VERIFICATION_20261015.txt` and `final_verification.json`.

## Jungle terrain — source-project preview and configuration

Jungle is a **fifth biome**; Stone has not been replaced. Saved biome coverage
is preserved: Jungle defaults to zero until you choose it. In Godot, select
Terrain → Settings and set Jungle Coverage above zero (weights are relative).
For example Grass 70 / Jungle 30 / other biomes 0 enables both. Jungle Region
Size controls biome ownership; the separate Jungle resource's Region Metres
controls the 13 geographic identities *inside* Jungle.

For an immediate reproducible preview without editing your saved world:

```powershell
& .\tools\jungle\launch_preview.ps1 -Feature jungle_mountains
```

Use `lowland_rainforest`, `rolling_jungle`, `rugged_hills`, `foothills`,
`jungle_mountains`, `river_rainforest`, `floodplain`, `rocky_jungle`, `karst`,
`jungle_plateau`, `jungle_gorge`, `humid_basin`, `upland_rainforest`,
`jungle_river`, `jungle_lake`, or `grass_jungle_transition`. These are discovered
coordinates in the seeded generator, not hand-sculpted showcase terrain.
Alternatively enable Terrain's Jungle Preview checkbox and set Jungle Preview
Feature, or pass `-- jungle-preview jungle-feature=jungle_mountains` to Godot.
F6 cycles eight Jungle diagnostics; Ctrl+F5 restores shading. F7/P is the
existing 1.80 m scale marker. Preview flags do not save coverage overrides.

Edit `jungle_settings.tres` in Godot's Inspector, save, then restart the scene:

- Regional Geography: region size and frequencies, hills, ruggedness, mountain height.
- Erosion: gully strength, incision depth, tributary occurrence.
- Hydrology: shared river influence, width, valley width, stream width/density,
  lake occurrence, floodplain terraces. River Frequency is an influence from
  0–1, **not** a separate river network's spacing. Global Grass River Frequency
  controls the existing shared carriers. Global Water Enabled disables actual
  channels/lakes; global river/lake frequency zero also disables that feature.
- Materials: albedo gain, source mixtures, wetness, subtle broad variation,
  physical tile sizes, ground and rock normal strengths. Set normal strengths
  to zero or use the existing normal-off diagnostic to compare.
- Distant Geometry: 128 m target spacing on certified Jungle tiles, capped at
  64 vertices per edge; 0 restores legacy density. This preserves major relief
  better but is not a guarantee that every narrow channel survives the farthest
  LOD. Maximum LOD and view distance are unchanged.
- Vegetation Hooks: canopy/emergent/understory/ground-cover/clearing controls
  affect placement data only. **There is no foliage renderer or Jungle plant
  asset library in this project. No canopy, trees, ferns or vines are rendered.**

The seven shared CC0 scan sets are Ground023 (litter), Ground048 (organic
soil), Ground031 (mud/silt), Gravel020 (banks), Rock030 (bare rock), Rock064
(mossy rock), and Ground037 (moss ground). Provenance and SHA256 checksums are
in `data/jungle_material_sources.json`. Raw maps are excluded from Godot's
import scan. Shared prepared arrays use 2K BC3 albedo/linear roughness-alpha
and 1K BC5 OpenGL XY normals with mipmaps, totaling 48,933,920 texture bytes.
No download, texture conversion, or material construction happens per chunk.

To replace a source, replace its actual Color / NormalGL / Roughness maps at
the paths in the manifest and run Godot headless with
`--script res://tools/jungle/build_materials.gd`. The packer rebuilds the
external layers and provenance. This seven-role palette is not an arbitrary
length Inspector list: adding/removing a material role also requires changing
the packer IDs/roles and `shaders/jungle_material.gdshaderinc` layer selection.

`scripts/jungle_placement.gd` exposes worker-safe numeric `habitat(builder,x,z)`
and paged `candidates(builder,bounds,spacing,max_candidates,scan_offset)`.
Each future foliage worker must own its builder/settings snapshot. Results
are globally jittered and stable, exclude water/steep slopes, and are capped at
512 probes and 256 results per call. Continue using `next_offset` until
`complete`. Small main-thread convenience wrappers are exposed on Terrain;
they are **not** called automatically during chunk generation or upload.
These are tested integration hooks, not a completed vegetation pipeline.

Water reuses the existing sea-level ocean mesh and seeded river/lake carriers.
Valleys, terraces, humid banks and tributary beds are terrain features, not a
flow simulation. No elevated river/lake surface or waterfall renderer exists.
Habitat queries expose downhill/drop/drainage data but explicitly return
`waterfall_candidate=false`; no unsupported falls are faked. Tropical and
Swamp biomes also do not exist, so transitions to them cannot be demonstrated.
Scene lighting, sky, fog, ocean shader, and the other biome presets are unchanged.

Run local tests (no export):

```powershell
& .\tools\jungle\verify_project.ps1 -Review -Benchmark -Regression
```

Results and native captures are under `tools/jungle/artifacts` (Git-ignored),
including per-feature ground/medium/aerial/material/normal views, PBR-normal
on/off comparisons, GPU control decoding and before/after benchmarks. Review
`tools/jungle/IMPLEMENTATION_STATUS.txt` for scope and verification limitations.
