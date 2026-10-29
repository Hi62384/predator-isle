# Desert continuation: source delivery, 14 October 2026

**Later authorization update:** the user has lifted the no-tests restriction.
See [VERIFICATION_PROGRESS_20261014.md](VERIFICATION_PROGRESS_20261014.md) for the
prepared current-source checks and RAM/slot blockers. The source-only account below
records the earlier pass; it does not prohibit newly authorized verification.

Source implementation has advanced; Desert acceptance is **incomplete**. No engine,
editor, game, automated test, benchmark or capture was launched during this pass.
The user's no-software-tests instruction supersedes older validation instructions.
Source readback and inspection of existing image files are the only verification.
Even parser/compiler success for these changes is unverified.

## Workspace and inventory

Work used the actual Windows checkout, preserving its modified and untracked files.
No reset, discard, commit, push, patch ZIP, animal edit or new worker was performed.
The original specification is local in [USER_REQUIREMENTS.txt](USER_REQUIREMENTS.txt).
Root AGENTS.md, ProjectBridge delivery instructions, TERRAIN_TUNING.md, Grass
material/cliff documentation and tools/STREAMING.md were inspected. The named
`desert_occurrence_applied_receipt_20261014_0427.zip` was not found under the local
Desert tools; its exact archived bytes were not compared. Current occurrence source
and recovery records were inspected directly. No pending source archive was applied.

| Area | Actual source/resource |
| --- | --- |
| Canonical Desert geography, regions, wind, dunes, basins | scripts/desert_sampler.gd |
| Rooted catchments, curved trunks/tributaries, fan descriptors | scripts/desert_drainage.gd |
| Biome/Grass integration, height cache, mesh controls and normal/LOD interface | scripts/terrain_mesh_builder.gd |
| Worker scheduling, material binding, water plane, debug index mapping | scripts/chunk_terrain.gd |
| Settings groups and legacy aliases | scripts/desert_settings.gd; desert_settings.tres; scripts/terrain_settings.gd |
| Shared material shader and Desert specialization | shaders/terrain_biomes.gdshader; shaders/desert_material.gdshaderinc |
| Twelve control bytes in four exact float integers, decoded before interpolation | shaders/desert_control_decode.gdshaderinc; Mesh.ARRAY_CUSTOM1 in terrain_mesh_builder.gd |
| Interactive debug shortcuts and camera HUD | scripts/free_camera.gd |
| Fixed seed/feature coordinates and historical discovery | tools/desert/preview_locations.json; find_previews.gd |
| Optional existing capture/benchmark harnesses (not run) | tools/desert/preview_desert.gd; benchmark_desert_native.gd |
| PBR packing source and prepared arrays | tools/desert/build_palette.gd; materials/desert_color_roughness.tres; materials/desert_normals.tres |
| Exact source/license/hash records | assets/textures/desert/downloaded_manifest.json; catalog.json; download_plan.json |
| Historical application/acceptance | APPLY_STATUS.json; ACCEPTANCE.md; RECOVERY_20261014.md; requirements_status.json |

Each worker still owns its sampler and caches. The main-thread diagnostic sampler
is separate. Custom control layout, canonical mesh sampling, partitioning, skirts,
water architecture, existing settings names/defaults and Grass cliff code are retained.
Current settings resources were not rewritten.

## Changes in this pass

- `scripts/desert_sampler.gd`: retained the regional/geographical system and
  occurrence controls; added soft sedimentary shelves and resistant cap provinces
  to existing highlands/outcrops, leaving ridge provinces available. Shelf remapping
  is continuous and monotone, with finite slopes. Added crest-height variation and
  smooth interruptions using existing dune bend fields, plus asymmetric star arms.
  Reused the wind coordinate within pure-sand sampling. Directional valley shelter
  now affects sand supply/exposure. No additional noise query was added by these edits.
- `scripts/desert_drainage.gd`: reused closest-curve offset for leeward shelter and
  added finite diverging sediment ribbons to existing fans. Topology, root selection,
  graded floor and active-channel protection are retained. Fan ribbons affect shallow
  deposited relief and material drainage controls, not new simulated stream networks.
- `shaders/desert_material.gdshaderinc`: transported wind plus geometric slope and
  curvature classify windward, lee, crest and compact interdune surfaces. Source-map
  and analytic ripple normals now both attenuate on lee/compacted ground; windward
  surfaces suppress the shorter ripple harmonic. Crest tint is restrained. Compact
  sand and gravel use catalogued 3.5 m and 0.8 m physical repeats. Top-three material
  budget, normal projection, mipmapped arrays and distant shading are retained.
- `scripts/chunk_terrain.gd`: optional `desert_preview_feature` selection starts at
  an existing discovered location with the recorded seed and runtime biome overrides.
  It uses actual canonical heights for camera placement. Also exposes more existing
  diagnostic controls to the HUD. Empty selection leaves normal startup unchanged.
- `scripts/free_camera.gd`: displays selected feature/seed and rock, drainage, basin,
  accumulation, salt and wetness values during Desert debug views.
- `TERRAIN_TUNING.md`: replaced obsolete simple-Desert tuning guidance with the actual
  dedicated resource and this manual review workflow.

These change Desert heights/materials. Previous slope probes, exact-output checks,
preview heights and visual panels cannot establish acceptance of this version.

## Requirement-to-code map

Status **Source** means a concrete source path implements the mechanism, not that
its behavior passed. **Partial** identifies a limited approximation or remaining
implementation gap. **Unverified** means acceptance requires running/looking at the
current result. Every Source/Partial row also has unverified runtime behavior.

Abbreviations: DS = desert_sampler.gd; DD = desert_drainage.gd; DM =
desert_material.gdshaderinc; MB = terrain_mesh_builder.gd; CT = chunk_terrain.gd.
Section numbers refer to the full original specification.

| # | Requirement | Source/status and remaining gap |
| --- | --- | --- |
| 1 | Geographic variation | Source: DS.sample seven distinct weighted constructions, now caps/shelves as well as ridges. Recognition/coverage unverified. |
| 2 | Regional identity | Source: DS._site/_region_node/region_weights, seven weighted types at 8 km default spacing. |
| 3 | Scale/transitions | Source: bounded domain warp and smooth 256 m control-lattice interpolation; retained core identities. Actual borders unverified. |
| 4 | Five dune families | Partial: DS._dunes/_isolated_dunes; asymmetry, crescent bow/horns, ridge families, asymmetric star arms, reversed parabolic bow. Star rarity and stabilization are mathematical approximations, not environmental simulation. |
| 5 | Wind/crest behavior | Source: DS.wind_coordinates, bend/bifurcation fields, new smooth interruptions/relief variation; DD leeward deposits; DM shared phase. Repose/silhouette unverified after edits. |
| 6 | Detail hierarchy | Source: compound 7+ km dunes, local crests/shoulders and shader-only sub-metre detail. |
| 7 | Far sand quality | Unverified: canonical macro crests exist; sparse parent meshes may miss smaller crests. |
| 8 | Plains | Source: DS calm base and sparse outcrop construction; occurrence=0 leaves sand sheets; DM compact/gravel. |
| 9 | Rocky terrain | Source: separate rock plain/highland/rim rules, exposed and sheltered controls. Weathered/gray family variety is limited by one dedicated rock source. |
| 10 | Sandstone mountains | Partial: ridged relief, meso flanks, capped provinces, shelves and existing drainage. No explicit fractured block geometry; fractures largely material relief. |
| 11 | Canyons/ravines | Source: DD rooted analytic arcs and DS finite walls/shelves/broad valley envelope. Width varies by segment/order; intra-segment width variation remains limited. |
| 12 | Cliff appearance | Partial: finite shelves, dedicated signed triplanar rock and multi-scale normals; physical recessed fractures/ledges require visual review. |
| 13 | Stratification | Source: DM variable/tilted/interrupted tonal beds; DS soft geometric shelves. Material/geometry beds are approximate and not a shared geological simulation. |
| 14 | Cliff macro detail | Partial: 28/95 m rock-source normal layers and weathering. Enlarged rock-source detail alone is not proof of believable large fracture systems. |
| 15 | Heightfield limitation | Source: finite smooth caps/walls/shelves; no fake overhang. Optional arch/overhang meshes remain absent and are deferred. Coarse-mesh representability unverified. |
| 16 | Badlands | Partial: DS denser ribs/gullies plus connected DD incision; local gullies are a field approximation, not a fully rooted fine tributary hierarchy. |
| 17 | Wadis | Source: DD trunks/tributaries share endpoints/graded floors; DS final channel envelope. Current downstream heights unverified. |
| 18 | Fans | Source: DD basin-junction deposits, new diverging ribbons, DS low-ground gate and bed exclusion. Ribbons approximate distributaries rather than full branching simulation. |
| 19 | Salt/dry lakebeds | Partial: DS eligible low basin/flatness/salt, DM cracked mud and pale deposits. Dedicated true salt-crust scan/structure is missing: Ground033 is pale granular sediment. |
| 20 | Oasis | Source: rare regional selection and supported lowland carve, CT existing sea-level plane, DM wet sediment. No elevated lakes/vegetation; water disabled prevents oasis carve/wetness. |
| 21 | Sand accumulation | Partial: drainage/basin/cliff-foot shelter plus wind-biased valley flanks and fan deposits. Full upstream obstruction/occlusion sampling is absent. |
| 22 | PBR families | Partial: six distinct imported sources; warm/red rock and sand variants use tints, not additional independent scanned materials. |
| 23 | Real PBR maps | Source: 18 actual source maps viewed during this pass; prepared arrays and packer inspected. New rendered normal signs/compression/roughness unverified. |
| 24 | Sand texturing | Source: source grain, wind-aligned map, analytic ripples, broad color and compact family. Visual tiling/grain scale unverified. |
| 25 | Ripple normals | Source: DM wind Jacobian and footprint-filtered analytic/source normals, with lee/compaction attenuation. |
| 26 | Sand color | Source: restrained macro tint and new subtle crest adjustment; material appearance unverified. |
| 27 | Dune face materials | Source: DM slope/wind/curvature classify stoss, lee, crests, compact lows; no extra vertex channels. Coarse normals can limit classification. |
| 28 | Macro/meso/micro | Partial: regional controls, sediment/bedding, separate map scales and ripples; quality of macro rock reuse unverified. |
| 29 | Geography-led distribution | Source: region, slope, elevation/water, curvature, shelter, rock, drain, basin and deposits; small boundary perturbation. |
| 30 | Transitions | Source: distinct deposition/slope/basin masks and smooth top-family selection; appearance unverified. |
| 31 | Anti-tiling | Partial: translated/scaled secondary lookup, nondirectional rotated variant and macro modulation. Visible repeats are not yet ruled out. |
| 32 | Directional detail | Source: common wind phase for dune/sand; directional deposits now use real drainage flank. Rock/mud are not wind-striped. |
| 33 | Natural routes | Partial: compact/gravel washes only; no independent route finding or road network. |
| 34 | Regional palettes | Source: region-led warm/muted rock and pale basin tints with six structures; visual contrast unverified. |
| 35 | Biome boundaries | Source: MB existing height weighting and terrain shader biome blending retained. Current transition appearance/Grass regression unverified. |
| 36 | Natural geography | Unverified: source avoids intentional spikes/discontinuities/circular region masks; realism cannot be accepted from source. |
| 37 | Calm regions | Source: low-relief base, sparse outcrops, basin flattening, optional occurrence controls; large quiet areas unverified visually. |
| 38 | Distant terrain | Unverified: canonical macro shapes and mipmapped color exist, no new LOD shape law. Actual horizons/canyon readability unaccepted. |
| 39 | LOD/canonical seams | Source: absolute coordinates, worker-local caches, existing MB normal/seam interface retained. No current invariants run; inherited skirts do not equal complete stitching/geomorphing. |
| 40 | Performance | Failed historical gate; current performance unknown. No demonstrated current Desert stage bottleneck or speedup. |
| 41 | Dune work bound | Source: cached fixed neighborhood, maximum nine candidates, inactive family skip; existing bend fields reused in new envelopes. |
| 42 | Detail filtering | Partial: DM footprint/distance filters; CPU keeps canonical local detail to avoid LOD shape shifts. CPU LOD detail cost remains. |
| 43 | Shader cost | Source: maximum three selected families, sparse projections, shared arrays, far normal/anti-tile fade. Actual GPU cost unmeasured. |
| 44 | Threading | Source: worker-owned DS/DD/MB caches, plain mesh arrays returned, CT commits in main thread; no new worker SceneTree access. Current concurrency behavior unverified. |
| 45 | Integrated debugging | Source: existing 40-49 shader modes / 28-37 UI indices and new scalar HUD. Family/orientation is HUD plus wind view; no dedicated per-vertex dune family attribute. |
| 46 | Configuration | Source: DesertSettings groups, preserved legacy storage aliases/defaults and occurrence controls; no preset rewrite. |
| 47 | Reproducible locations | Source: 13 discovered coordinates and new feature selector. Historical feature scores/heights are stale after edits; current suitability unverified. |
| 48 | Multi-view validation | Unverified: prohibited this pass; historical scientific panels/GPU channels are not current visual acceptance. |
| 49 | Comparable performance | Missing current measurements: sampling/chunk, commit, fill, geometry, RAM/VRAM, shader/GPU. Historical cloud reports retained unchanged. |
| 50 | Staged implementation | Source inspection and direct targeted edits performed; validation stage blocked by user's no-tests constraint. |
| 51 | Failure avoidance | Partial: hard CPU gate unresolved, salt source incomplete, realism/repetition/LOD checks unaccepted. |
| 52 | Final visual scenes | Unverified: same generator supports scene families; no current visual acceptance. |
| 53 | Success criteria | Incomplete: Source presence is not visual, functional or performance acceptance. |

## Assets and source-map observations

Provenance is preserved in `assets/textures/desert/downloaded_manifest.json`, which
records original archive/map SHA256, byte sizes, download timestamps, official asset
links and CC0 1.0 license. The six source Color/NormalGL/Roughness sets were viewed as
existing local files. Packed resources were not regenerated or overwritten.

| Array layer | Official source | Observed role |
| --- | --- | --- |
| 0 | https://ambientcg.com/a/Ground092A | Pale sand grains and horizontal source ripple crests; texture V follows wind phase U. |
| 1 | https://ambientcg.com/a/Ground054 | Compacted grain/earth, no organized ripple relief; catalogued 350 cm width. |
| 2 | https://ambientcg.com/a/Gravel020 | Distinct pebbles/gravel, catalogued 80 cm width. |
| 3 | https://ambientcg.com/a/Rock061 | Weathered fractured/bedded brown-gray rock. |
| 4 | https://ambientcg.com/a/Ground031 | Irregular cracked clay/earth with grains/pebbles. |
| 5 | https://ambientcg.com/a/Ground033 | Pale granular beach sediment; not genuine salt-crust photogrammetry. |

License source: https://docs.ambientcg.com/license/ (retained manifest says CC0 1.0).
Packing source uses 2K BC3 albedo/linear roughness alpha, 1K BC5 OpenGL XY normals and
mipmaps. Shader uses source_color for color, hint_normal for normals, explicit
texture gradients and signed surface-gradient projection. Roughness alpha remains
linear. Current compressed appearance and exact normal lighting are unverified.

## Performance evidence and limitation

`cloud_cpu_final.json` records comparable historical inland simple-Desert versus
richer-Desert measurements in one Linux process. It reports candidate regressions
across sand, canyon, highland, badlands and far samples. `RECOVERY_20261014.md` records
a later exact-output sand fast-path improvement against the richer version, explicitly
without meeting the original simple-Desert gate. Neither measures this pass.

`tools/sampler_stages.json` and `profile_sampler_stages.gd` profile **Grass-only**
coverage. `hierarchy_profiled_final.json` predates this Desert continuation. Those
reports cannot identify a current Desert stage bottleneck. Repeated per-sample
region-array allocation, family evaluation, cold catchment construction and closest
curve work are source suspects, not measured rankings. No speculative cache/lattice
architecture replacement or performance claim was made. New features reuse fields
and add scalar work, whose net cost remains unknown.

## Manual inspection, performed by the user when desired

1. In `main.tscn`, select Terrain and choose `Desert Preview Feature`. Leave it empty
   for the normal saved world. A named feature uses seed 73921, pure Desert coverage
   and disabled climate in a runtime snapshot. The transition uses 50/50 Grass/Desert,
   equal 24 km regions and biome_size=1. Other saved terrain/Desert settings still
   apply. Coordinates are historical discovered anchors, not guaranteed current
   best examples. No settings asset needs replacement.
2. Start a normal game session yourself. The selected feature sets a medium-distance
   camera above canonical terrain. WASD/Q/E fly, wheel changes speed. Inspect near
   ground (~1.8 m above terrain), medium (hundreds of metres), and aerial/far
   (kilometres) for each location. Use F7/P for the 1.8 m reference where helpful.
3. Shift+F5 cycles Desert views: regions, dune supply, wind, exposure, drainage,
   basin, accumulation, salt/oasis, material weights and LOD bounds. Ctrl+F5 restores
   shading. The HUD identifies the sampled family/orientation and field values.
   Check crest endings/lee faces, cap/shelf slopes, fan-to-valley continuity, wet
   banks, material tiling and stepping; cross LOD boundaries in both directions.
4. Inspect the Grass/Desert transition, then clear feature selection and inspect
   the existing distant Grass/cliffs at your original coordinates/settings.
   Preserved source is not a substitute for that rendered regression check.
5. Do not run validate_desert.ps1, optical gates, capture scripts, tests or benchmarks
   unless the user separately re-enables those particular verification runs.
   Future comparisons must use matching seed/settings/view/LOD and record all
   requested CPU, commit, fill, geometry, memory and GPU measurements, including failures.

| Feature selector | World X | World Z |
| --- | ---: | ---: |
| sand_sea | -4608 | 8960 |
| barchan_dunes | -2048 | 9984 |
| longitudinal_dunes | -5376 | 9472 |
| rocky_plain | -53760 | -34048 |
| sandstone_highlands | -24832 | 13568 |
| major_canyon | 18432 | 29440 |
| badlands | 22528 | -5632 |
| dry_river_valley | 2304 | 3072 |
| alluvial_fan | 7680 | 27136 |
| salt_flat | -768 | 256 |
| dry_lakebed | -15616 | -4096 |
| oasis_basin | -2304 | 3840 |
| desert_grass_transition | 28032 | 10752 |

Remaining acceptance blockers: current parser/runtime verification, all visual
requirements, current deterministic/seam/LOD/Grass checks, downstream bed/slope checks,
native full-world/GPU/streaming performance, the historical CPU gate, dedicated
salt-crust structure and complete physical obstruction/geological realism.
