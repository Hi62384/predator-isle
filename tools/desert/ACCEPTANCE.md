# Desert implementation checkpoint

**Current native evidence:** [VERIFICATION_PROGRESS_20261014.md](VERIFICATION_PROGRESS_20261014.md)
records the 14 October current-core run: 1,839 exact comparisons across three seeds,
zero failures, native Godot 4.6.1, peak child working set 89,182,208 bytes. The heavy
slot was released. Full-project, material, visual and performance acceptance remains
pending; this core result is not end-to-end acceptance.

**Latest source-only continuation:** [SOURCE_REVIEW_20261014.md](SOURCE_REVIEW_20261014.md)
maps all 53 requirements, lists targeted follow-up edits and gives the manual
feature-selector workflow. No software verification was run for those edits.
Historical checks below do not qualify the current source.

**Current update: see [RECOVERY_20261014.md](RECOVERY_20261014.md).** Native PBR packing, native core checks and the RGBA_FLOAT GPU channel gate have since passed. Wind mapping and exact-output pure-sand optimization are applied. The historical narrative below records the earlier 13 October checkpoint; its pending packing/native statements and RGBA8 layout are superseded. Full visual and performance acceptance remains incomplete.

**Implementation applied; acceptance incomplete.** The original 53-section request
is retained in `USER_REQUIREMENTS.txt`; every section has an explicit status in
`requirements_status.json`. CPU nonregression and native visual/performance gates
remain open.

## Application state

The current 49-file checkpoint has been applied to Windows using fresh exact base
checks and readback verification. This includes five existing runtime integration
files, new modules, tests and documentation. `APPLY_STATUS.json` records the source
state and remaining gates. No Windows Godot import or execution has yet verified it.

The six official ambientCG archives downloaded successfully at 04:37:42 UTC, with
18 Color/NormalGL/Roughness maps and source/license/hash records. The downloaded
manifest and asset directory were freshly read on return. Actual map pixels,
archive-entry revalidation, PBR packing and native rendering remain pending.

Native validation is held until at least 3 GiB RAM is free and the serialized,
locally approved command window is available. The user has returned and authorized
application; there is no continuing user-away hold. Never overwrite later user
changes or unexpected generated resources.

The retained saved `terrain_settings.tres`, user coverage, Grass generation and
Grass cliff resources are not replaced. No commits, reset, push or ProjectBridge
archive was performed.

## Applied implementation

- Seven kilometre-scale regional identities on a globally fixed 256 m control lattice.
- Five asymmetric dune families, compound large crests and shared deterministic wind.
- Calm plains, rocky exposures, sandstone highlands, finite canyon walls, badlands,
  graded dry drainage, basin/salt fields, shallow fans and water-supported rare oases.
- Meandering trunks and staggered tributaries instead of radial hub valleys.
- Worker-owned bounded caches and the existing partition/WorkerThreadPool architecture.
- Three conditional RGBA8 Desert vertex channels, 12 bytes per Desert vertex;
  pure Grass retains its existing channels and exact tested mesh arrays.
- Six geography-led PBR families, signed triplanar normals, source rock structure at
  5/28/95 m scales, anti-tiling, filtered wind ripples and offline compressed arrays.
- Inactive rock-strata and distant-ripple shader work is bypassed. Small rock boundary
  perturbations cannot invent rock material in otherwise pure sand.
- Dedicated Inspector settings, region HUD, ten debug modes, deterministic discovery,
  native benchmark/capture scripts and source-map preparation/integrity checks.

## Cloud evidence

Engine: Godot 4.6.3.stable.official.7d41c59c4, Linux. Recorded Windows engine: 4.6.1,
not freshly verified. Cloud results do not establish laptop performance.

- Canonical heights/material controls agree across order, cache eviction and
  reconfiguration. Shared mixed-LOD and parent-child vertex heights agree exactly.
- Pure Grass height delta is zero; existing Grass geological controls and full-array
  comparisons pass. Saved-preset tests are recorded separately from pure-Desert tests.
- 314 graph edges share parent endpoints; maximum junction degree is 3. A 75-catchment,
  three-seed curve audit found no non-junction crossings at its sampled resolution.
- 48,156 dry-channel final-height steps across three seeds and both water modes had
  no downstream rise over 2 m. With water disabled, no rise was measured in these
  samples. With water enabled, the maximum dry rise was 0.0265 m; one oasis-shore
  carve produced a larger 2.7403 m rise and remains separately reported.
  These are finite diagnostics, **not a global hydraulic proof**.
- The retained 2 cm tile-boundary check and finite unit-normal checks pass.
- Pure-sand slope probes found 32.425 degrees at defaults and 34.039 degrees in an
  extreme tested configuration. This is not an exhaustive global bound.
- Actual controller source with maximum LOD 6 and four workers committed balanced
  partitions of 150/147/150 leaves and completed two teleports, with a bounded cache.
  The isolated headless fixture uses synthetic 4x4 textures; it proves function only.
- Shader source parses with 87 uniforms. Native helper GDScripts parse. The newer
  PowerShell orchestration/integrity changes still need native execution.
- All 13 feature locations were discovered procedurally with seed 73921. All 39
  final 129x129 shaded heightfield panels were inspected at 256/2048/16384 m spans.
  Fan carving and radial junction defects were corrected using these diagnostics.
  These are plan-view scientific images, **not game/PBR screenshots**.

## Performance gate: failed

Latest same-process cloud medians, original simple Desert versus retained candidate:

| Inland case | Original ms/chunk | Candidate ms/chunk |
|---|---:|---:|
| Sand sea, 64 cells | 28.484 | 64.491 |
| Sand sea, 128 cells | 101.448 | 255.586 |
| Canyon, 64 cells | 27.963 | 81.633 |
| Highlands, 64 cells | 28.728 | 78.979 |
| Badlands, 64 cells | 28.857 | 78.811 |
| Far 1024 m vertex step, 16 cells | 12.329 | 55.560 |

Warm query costs: original 4.39–4.90 microseconds, candidate 10.21–14.58 microseconds
for the recorded sand/canyon/highland footprints. All these benchmark cases contain
inland above-water vertices. The separate underwater control is not evidence of
Desert speed. Earlier underwater-only results are explicitly superseded.

Two exact-output optimization passes reduced allocation, repeated configuration
math and candidate/cache work. The improved drainage graph also reduces its cost.
A further fixed 8 m height-lattice experiment was **rejected**: its largest sampled
geometric error was 3.24 m, memory increased, and far sampling slowed. The staged
candidate retains exact sampling. Further optimization is not claimed impossible.

Raw timings, payload bytes, parameters and limitations are in `cloud_cpu_final.json`
and `saved_preset_grass_cloud.json`. Small changes in cloud timings are noisy. Native
cold fill, frame percentiles, GPU, upload/commit and VRAM acceptance remain pending.

## Remaining acceptance work

1. Run the applied checkpoint through native import and regression checks after the
   3 GiB free-RAM guard and local command approval. Serialize heavy project jobs.
2. Review every actual downloaded source and license record, verify archive/map
   identity, pack the six shared arrays and inspect normal orientation/compression.
   Ground033 is a pale beach-sand/mineral-like variant, not claimed salt photogrammetry.
3. Run the native baseline/current benchmark and inspect every ground/medium/aerial
   and debug capture. Review dune silhouettes and slip faces; canyon proportions,
   sandstone bands/fractures and badlands erosion; fan deposits; calm ground;
   salt/oasis boundaries; material repetition, normal signs, seams and LOD transitions.
4. Resolve the hard CPU regression or obtain an explicit revised acceptance budget.
   A completed native test job alone does not satisfy that requirement.
5. Do not treat endpoint connectivity, number of region types or successful script
   parsing as proof of reference-level realism or GPU quality.

All six supplied reference-image files were properly materialized and their actual
pixels inspected: asymmetric golden crests, sparse rocks and calm sand, stratified
canyon/talus, immense pale basin, banded badlands, and chalk outcrops with ripples.
The mushroom overhang cannot be represented faithfully by this heightfield and was
not faked with stretched triangles.

## Native workflow

`NATIVE_WORKFLOW.json` lists exact fixed commands and preconditions.
`validate_desert.ps1 -FetchAssets` performs CPU/import/integrity checks and offline
packing. Existing verified archives are reused. Packing refuses to overwrite
preexisting generated material resources. `-Render` runs sequential native
baseline/current tests and captures. Every command retains local approval.

The script checks at least 3 GiB free RAM, writes project-local logs, and times out
only its own Godot child. Engine path is configurable. The benchmark uses matching
seed/settings and a 1440x810 viewport; unavailable timing counters are null. Baseline
sources were captured before edits, but benchmark execution occurs afterward: no
historical pre-edit timing was invented.

Rendering API reference: https://docs.godotengine.org/en/stable/classes/class_renderingserver.html
Asset license: https://docs.ambientcg.com/license/
