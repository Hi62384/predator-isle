# Sparse cliff structure correction

## Implemented

- Removed the blanket ridged/cavity field and its second smaller-scale copy.
- Baked finite, broad recessed seams and a few incomplete shelf breaks with
  tapered widths, varying lengths, related orientations and occasional branches.
  No bevelled rectangles, cell outlines or albedo-only black crack core.
- Preserved large quiet areas: 85.09% of the baked map is below 0.08 structural
  coverage. Added a 65% minimum quiet-area assertion in generation and tests.
- Retained precomputed per-projection signed slopes to avoid the previous
  orientation-derivative artifacts. Removed two runtime texture lookups.
- Lowered medium PBR normal strength and localized stronger breakup around
  recesses. Kept fine source detail, distance fade and world-space alignment.
- Replaced only cliff palette slot 8 with existing Rock028 color/NormalGL/
  roughness. Other eight material slots are unchanged; no new downloads.
- Used existing crest/convexity fields for patchy lip exposure and existing
  talus classification to blend competent stone into gravel/sparse ground.
  No terrain geometry, river, biome or chunk-system changes.

## Checks

- Sparse map, resource formats, finite slope data, mipmaps and bindings passed.
- Nine-layer palette test passed. Rock028 BC5 normal mean angular error 2.96°.
- Five established cliff sites and diagnostic views rendered before the final
  source swap; final Rock028 inspected in the close oblique view and fixed
  80/300/900/2400 m distance sequence.
- Final 1280x720 far-view viewport averages: CPU 0.990 ms, GPU 4.453 ms.
  GPU time is higher than the previous report's 2.491 ms, despite fewer slope
  samples. No controlled isolated shader benchmark was performed; do not infer
  improved performance or dismiss the difference as proven background noise.

## Remaining target gaps

The sponge-like coverage is removed from the macro bake, but this is not a
complete match to the supplied reference. Shelf relief is shading, not physical
ledges. There are no new fallen-block meshes or collapse simulation. Talus uses
the existing terrain field, not transport traced from each new fracture above.
Top/base transitions still need visual refinement. Reusable maps can repeat;
85% quiet coverage is not proof that every infinite-world cliff looks natural.
Close/mid screenshots should be judged for residual engraved seam appearance.

Preview: `erosion_cliff_oblique_1.png`; distance views:
`erosion_macro_distance_80.png` through `_2400.png`.
