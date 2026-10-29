# Predator Isle organism foundry — version 4

The Blob 232 generator is integrated into the game through `scripts/blobs/blob_workshop.gd` in `main.tscn`. Original assets and notices remain under `alien_foundry/`. Generated creatures use a conditioned version of the imported implicit extractor, procedural anatomy and new deformation bindings. They do not replay the archive's bundled mesh.

## Running the game and workshop

Run the project, aim at terrain and press **B** to generate a creature. **Shift+B** advances the seed, **M** selects another suitable gait, **X** removes the creature and **Escape** cancels generation. Generation runs on a cancellable worker; render resources are created on the main thread. Version 4 caches include source fingerprints.

Open **blob_lab.tscn** and run the current scene to inspect creatures. The right panel controls seed, anatomy, quality and generation stage; generation settings apply when growing another creature. The left panel controls lighting, movement, diagnostics and playback. Creatures now actually travel across the reference grid, and the camera follows them.

Right-drag orbits, middle-drag pans, the wheel zooms, **F** frames, **R** resets, and **1–6** select orthogonal views. Feature focus follows the selected biological structure. Lighting presets include Studio, Daylight, Overcast, Low sun, Dark/rim and Clay, with manual lighting and exposure controls.

Pause, single-step, playback rate, signed speed, replay scrubbing and exact rest geometry are available. Scrubbing resets and replays the solver, yielding periodically so the interface stays responsive. Rest geometry bypasses deformation. Strain colors, contact targets, chain joints, body support points, feature selection and separate idle/gait controls help diagnose problems. The interface reports gait substitutions.

## Current architecture

The staged pipeline preserves biological metadata and adds features before final binding. Large sacs, embedded faces, porous mantles, vessels and folds are composed into the body field. Flexible limbs, tendrils, small supported webs and hollow sensory terminals receive shared curve frames. Roots are projected onto the final body and buried into their sockets. Branches, feet and terminals follow their actual parent curves.

The main body uses one smooth Cartesian deformation field shared by every tissue. Elliptic circulation, monotone muscle chambers and gravity response replace the old angle-chart/independent-patch system. Non-pulsing body motion approximately conserves volume locally; intentional sac inflation adds volume. Full circulation is allowed only for compact anatomy that passes the safety gate. Other creatures use compatible limb, vine or contraction modes.

Active limbs use persistent world-space grips, constrained curves and release/recover/reach/plant/pull phases. Planted appendages drive translation. Candidate curve poses are checked against their actual generated triangles; unsafe poses blend toward a valid pose or release the grip. A stalled gait can fall back to body contraction. Secondary appendages are explicitly identified and do not count as traction limbs.

Opaque tissue uses rest-space pigmentation and tissue-specific roughness. Membranes are small, thick, closed shells between coupled supports. Full transparent cloth simulation and universal welded appendage junctions are not implemented.

## Results and evidence

Read **[BLOB_V4_REPORT.md](BLOB_V4_REPORT.md)** for root causes, numerical results, performance, demonstrations, reproduction commands and limitations. Current outputs are in **data/blobs_v4/**. Earlier version 3 reports are historical; their count/joint/total-volume checks did not establish local mesh safety.
