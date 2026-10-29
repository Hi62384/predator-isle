# Predator Isle blob generator v4 — implementation and validation

Implemented directly in the existing Godot project on 27 October 2026. The original concept sheet is the visual direction; this revision is still a procedural, stylized approximation rather than a photoreal match.

## Why the old geometry failed

The version 3 solver selected a nearest tissue region discontinuously, transported vertices through an angular surface chart and blended independently moving stiff patches. Adjacent vertices could select different maps. Total-volume calibration could compensate the overall signed volume while individual triangles stretched, folded or turned inside out. Earlier checks concentrated on counts, joints and total volume, so they missed these failures.

A retained version 3 solver and mesh audit reproduce the defect: maximum body-edge stretching reached **15.26×, 80.09×, 475.45× and 230.61×** in four inspected seeds. See `data/blobs_v4/v3_failure_audit.json` and `tools/blobs/audit_blob_v3_failures.gd`. These are measured old-solver failures, not a comparison of identical new/old anatomy.

Other root causes were different nearest-curve parameters around a single tube ring, unstable curve frames, membranes spanning unrelated full tendrils, unconstrained passive chain shapes, primitive terminal spheres and a lab that animated appendages while holding the organism in place. Raw extraction also produced extremely small corner triangles. Removing those faces afterwards opened the body; extraction needed conditioning before cleanup.

## What changed

- **Body mapping:** `blob_surface_circulation.gd` and its shader include now share one smooth Cartesian map. Determinant-one elliptic circulation, monotone chamber contractions with reciprocal lateral compensation, small idle shears and positive-derivative gravity response replace independent region maps and global volume calibration. Shader normals follow the deformation Jacobian. Sac pulses use bounded, spring-driven local fields.
- **Extraction:** `blob_stable_extractor.gd` conditions shared lattice crossings to 0.035–0.965 of an edge, limiting this approximation to 3.5% of a voxel. `blob_mesh_integrity.gd` checks indices, degeneracy, winding, connected components and manifold edges. Unconnected scraps are omitted with diagnostics. Unsafe bodies fail generation rather than being displayed.
- **Curves and attachments:** `blob_curve_frames.gd` supplies bounded Hermite curves and parallel-transported frames. A sweep ring shares one curve parameter. Branches are reanchored to the final parent curve; digits and sensory terminals follow its tip frame. Roots are placed on the extracted body. Main structures such as vessels, folds and porous bridges are fused into the implicit field.
- **Locomotion:** persistent world grips and five explicit contact phases drive actual translation through constrained root pull goals. Leg hinges seed fixed-length IK; active vine segments avoid coarse body obstacles. A mesh-pose guard evaluates actual sweep triangles before accepting motion. It can reduce a pose, release a grip or trigger a stalled-gait fallback. Compact anatomy alone receives full rolling circulation.
- **Secondary motion:** passive chains bend elastically around their grown rest shape. Large sacs visibly inflate at independent, irregular intervals; body idle remains active during locomotion.
- **Biology:** larger exposed sacs, deeper embedded facial masses, thick porous mantles, integrated folds and vessels, tapered irregular sweeps, small closed webs between coupled ribs and asymmetric hollow ribbed sensory cups replace several sparse or primitive details.
- **Materials:** shared rest-space tissue fields, reduced clearcoat and micro-normal strength, higher roughness and tissue-specific responses. Membranes are opaque shells with backlighting. Back-face culling remains enabled; materials do not hide inward geometry.
- **Inspection and integration:** the game positions creatures on terrain before configuring contacts. The lab allows actual travel, camera following, exact rest inspection, strain colors, feature focus, replay scrubbing and isolated idle/gait playback. The gait button cycles suitable modes. Versioned source-hashed caches replace v3 caches. Unvalidated automatic LOD generation is disabled.

The original archive and notices remain under `alien_foundry/`. The imported extractor itself was preserved; the new conditioned extractor extends it. Existing staged generation, metadata, cancellable worker and main-thread render upload remain in use.

## Geometry and animation evidence

All numbers below come from the saved JSON reports, rather than compilation alone.

| Test | Result | Evidence |
| --- | --- | --- |
| Generated batch | 24 seeds, all 12 profiles and 10 body plans; 10,816–43,080 triangles at draft quality | `generation_validation.json` |
| Final body topology | All 24 have zero boundary, nonmanifold and inconsistent edges; zero degenerate-face removal in the final conditioned extraction | `generation_validation.json` |
| Animated mesh suite | **6,480 checks, zero failures**; 180 simulation steps per creature, 96 sampled complete mesh poses; forward, stop, reverse and turning | `motion_mesh_validation.json` |
| Sampled deformed geometry | Zero confirmed inverted or collapsed triangles; maximum edge ratio 2.200×; minimum area ratio 0.179 | `motion_mesh_validation.json` |
| Non-pulsing body volume | 24 bodies × eight configurations; maximum relative error **0.0357%** | `volume_idle_validation.json` |
| Sac idle | Eight seconds, 1,301 exposed sac vertices; radial extent change **5.55%** | `volume_idle_validation.json` |
| Vine motor control | Four seconds: **0.680 m**, six contact cycles, all five phases; disabling gait gives zero travel | `pull_control_validation.json` |
| Leg motor control | Four seconds: **0.304 m**, 11 contact cycles, all five phases; disabling gait gives zero travel | `pull_control_validation.json` |
| Long terrain run | Five creatures at offset world coordinates on a sloped, wavy height field; compact rollers tested for 24 seconds; zero sampled inversions | `long_terrain_validation.json` |
| Terrain accuracy | Worst dense sampled body penetration **4.62 cm**, worst stance error **1.50 cm**; coarse terrain support remains a limitation | `long_terrain_validation.json` |
| Recorded locomotion | 12 seconds, 180 video frames, four panels; sampled meshes have zero inversions, maximum edge ratio 2.203× | `capture_validation.json` |
| Recorded organ motion | Six seconds, all 90 frames checked: zero inversions, maximum edge ratio 1.023×, minimum area ratio 0.961 | `organ_validation.json` |
| Workshop interaction | Six lighting presets, views, rest mode, paused replay seek and gait selection exercised successfully | `generator_interface.png`, `.godot/blob_v4_ui.log` |

Full circulation was tested only on the two safe compact bodies; the other volume configurations use contractions with unsafe circulation suppressed. Volume numbers exclude appendages and deliberate sac inflation. Mesh safety is established for the sampled seeds/poses, not a proof over every future seed or control setting. The CPU oracle reproduces the production shader equations, with facet-normal transport for inversion checks; actual GPU renders and recordings supply separate visual evidence.

Pose fallback is part of the safety strategy, not a perfect gait result. Nine batch creatures used at least one rejected-pose fallback; several awkward anatomies switch to contraction when traction stalls. Counts are included in `motion_mesh_validation.json`. This revision deliberately favors bounded motion over stretching a limb to reach an impossible grip.

## Demonstrations and renders

All files below are under `data/blobs_v4/`:

- **`locomotion.mp4`** — rolling, vine traction, leg motion and idle sac pulsing in four panels, with a world reference grid. Twelve seconds at 15 fps, solver stepping at 60 Hz. The camera follows travel.
- **`organs.mp4`** — close inspection of the supported closed membrane and attached hollow sensory terminal. Six seconds at 15 fps.
- **`clay_24.png`** — 24-creature geometry/diversity comparison.
- **`biology_12.png`** — final textured comparison across the first 12 specimens.
- **`detail_6.png`** — higher-detail textured examples, including sacs, holes, sensory anatomy and limbs.
- **`clay_before_after.png`** — four paired stage-4/stage-7 clay examples showing geometry added by later stages. These are generation-stage comparisons, not old-v3/new-v4 identical-camera screenshots; each creature is framed separately.
- **`generator_interface.png`** — the current inspection interface.
- **`motion_*.png` / `organs_*.png`** — stills from the recorded demonstrations.

## Performance

Godot **4.6.1**, Compatibility renderer, **NVIDIA GeForce RTX 3060 Laptop GPU**. A fresh isolated benchmark of seed 5101 used the final source, with no concurrent validation/capture jobs:

| Measurement | Result |
| --- | --- |
| Draft cold generation | **1.907 s**, 27,776 triangles, 2,147,960 packed geometry bytes |
| Higher-detail cold generation | **5.291 s**, 59,648 triangles, 4,508,288 packed geometry bytes |
| Cancel before extraction | Honored; 1.466 s from build start to return, including planning |
| Draft active vine simulation, 120 steps | **17.02 ms mean**, 19.65 ms p95, 22.81 ms maximum |
| Frame wall time, one 1280×720 creature viewport | **19.39 ms mean**, 21.97 ms p95; includes simulation, render, root viewport, scheduling and vsync |
| Draw calls | 8 |
| Process static / reported video memory | 81.2 MB / 43.5 MB, including benchmark data/resources |

See `performance_benchmark.json`. This is not a promise of 60 fps gameplay. Contact guards are expensive in GDScript; crowds need lower update rates, certified LODs and further optimization. `render_performance.json` separately records much heavier multi-viewport comparison-sheet workloads; those include viewport/readback overhead and are not game FPS. Generation validation timings were recorded before the final extraction early-exit optimization and under variable load, so the isolated benchmark is the current representative measurement.

## Reproducing the tests

From the project directory, run Godot with an explicit writable log path. Replace `GODOT` with the installed console executable:

```powershell
& GODOT --headless --path . --log-file .godot/v4_batch.log --script tools/blobs/build_blob_v4_batch.gd
& GODOT --headless --path . --log-file .godot/v4_mesh.log --script tools/blobs/validate_blob_v4.gd
& GODOT --headless --path . --log-file .godot/v4_volume.log --script tools/blobs/check_blob_v4_volume_idle.gd
& GODOT --headless --path . --log-file .godot/v4_pull.log --script tools/blobs/check_blob_v4_pull_control.gd
& GODOT --headless --path . --log-file .godot/v4_terrain.log --script tools/blobs/check_blob_v4_long_terrain.gd
& GODOT --path . --log-file .godot/v4_render.log --script tools/blobs/render_blob_v4_sheets.gd
& GODOT --path . --log-file .godot/v4_motion.log --script tools/blobs/record_blob_v4_motion.gd
& GODOT --path . --log-file .godot/v4_organs.log --script tools/blobs/record_blob_v4_organs.gd
& GODOT --path . --log-file .godot/v4_perf.log --script tools/blobs/benchmark_blob_v4.gd
& GODOT --path . --log-file .godot/v4_ui.log --script tools/blobs/preview_blob_v4_ui.gd
```

Build the batch first. Render/capture commands require a working GPU. Capture scripts save numbered PNG frames; the delivered MP4s were encoded with ffmpeg at 15 fps using H.264, CRF 19 and yuv420p. Source-hashed detail caches are regenerated when relevant geometry sources change.

Final successful logs contain no script or shader compilation errors. This environment emits Windows certificate-store and shader-cache write-permission warnings; those remain environmental issues. `git diff --check` passes. Unrelated existing terrain/project edits were preserved.

## Remaining limitations

1. **Visual fidelity:** forms remain visibly procedural. Embedded faces are relief anatomy; there is no fully sculptural free humanoid head or independently articulated jaw. The reference sheet's photoreal tissue detail is not matched.
2. **Locomotion scope:** the system is kinematic contact-driven animation, not a force-balanced soft-body/FEM simulation. Full rolling with tall stalks, external legs, embedded faces or broad membranes is not certified; compatible crawling or contraction is used. Blocked or awkward gaits can pause or fall back.
3. **Collision:** coarse ellipsoids and joint repulsion protect active limbs, with intentional root/hip overlap. There is no universal triangle-level self-collision or arbitrary environment collision. Terrain support is approximate, with the measured penetration above; climbing, overhangs and navigation are outside this implementation.
4. **Junctions:** structural vessel/fold/porous geometry is fused. Flexible sweeps still use buried intersecting sockets rather than universally welded boolean unions. Close views can expose junctions or small self-intersections.
5. **Membranes:** small thick opaque shells with coupled supports and transported normals; not transparent physically simulated cloth. Incompatible spans are omitted.
6. **Budgets:** 16 chains with eight controls each, 32 tissue metadata regions and eight pulse cells. Additional appendages use bounded secondary motion. Automatic render LODs are withheld until their custom bindings can be validated.
7. **Volume and extraction:** the low volume-error result applies to non-pulsing locomotion only. Local sac inflation deliberately changes volume. Conditioned extraction approximates the surface and can discard disconnected scraps. Extremely unusual anatomy can fail generation instead of yielding an unsafe mesh.
8. **Performance:** active contact guards are currently too costly for large crowds at full update frequency. The benchmark documents this cost rather than claiming a production crowd budget.
