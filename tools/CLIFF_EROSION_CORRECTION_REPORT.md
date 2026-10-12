# Cliff correction after carved-slab feedback

## Source fixes

1. Removed the bevelled rectangular primitives from the offline geology baker.
2. Removed runtime sampling/binding of the three drawn fracture-network maps.
   Historical files are retained, not deleted.
3. Removed screen derivatives of projection-blended height. The new signed
   slope texture is projected into world tangent directions independently for
   each axis before blending. No normal-dependent weight derivatives and no
   discrete third-projection selection remain in cliff relief.
4. Rebalanced macro relief, medium rock structure and micro grain. The real
   Rock034 source stays at a fixed 36 m scale; broad eroded relief and its
   smaller support layer have independent fixed scales.
5. Added restrained irregularity only inside the existing grass/cliff boundary.
   Unrelated grassland texturing, terrain geometry, biomes, water and streaming
   algorithms remain unchanged.

## Validation

- Rebuilt shared half-float relief and signed-slope maps.
- Asset test passed for finite nonempty channels, mipmaps and bindings.
- Five geographically separated cliff sites and diagnostic views rendered.
- Oblique views from both sides inspected: no earlier engraved rectangles or
  stretched-bar pattern observed in those views. Exact user camera coordinates
  are not available, so these are reproduction-oriented tests, not identical shots.
- An initial full-size multi-capture process failed with a Godot memory-allocation
  error. Smaller 1280x720 captures and one angle per process succeeded. Other
  user Godot processes were not stopped. This does not diagnose the Codex crash.
- Prior intermediate distance run measured 2.457 ms whole-viewport GPU average;
  it is not a final benchmark or an isolated cliff-shader measurement.
- Final 1280x720 test: CPU 1.353 ms / GPU 2.491 ms viewport means, after
  stopping fine source normal samples past 900 m (smooth fade from 350 m).
  Broad relief remains. The preceding same-resolution run was 4.137 ms GPU;
  background load varies, so these are observations, not controlled speedups.
- Final slope resource uses RGH (5.33 MiB); relief uses RGBAH (10.67 MiB).
  Final resource-format/data/binding checks passed.

## Remaining limitations

This is a surface-quality correction, not a claim of matching the reference.
Deep physical ledges, silhouette chips and rubble piles cannot be supplied by
this shading-only implementation. Existing base/talus transitions remain weak.
The new relief is continuous erosion-like structure rather than a geological
fracture simulation. Maps still repeat, although two independent projection
periods and existing source anti-tiling reduce obvious reuse. No claim of zero
repetition across an infinite world or zero popping at all mesh LODs is made.

Useful outputs: `erosion_cliff_oblique_0.png`, `_1.png`, `_2.png`, the five
`erosion_cliff_geology_site_*` captures and `erosion_macro_distance_*` captures.
Debug 27 now disables broad relief normals rather than the retired line overlay.
