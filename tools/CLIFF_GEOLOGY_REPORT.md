# Cliff-only geological surface pass

## Changes

- Added independently baked bevelled rock masses, shelves, broad runoff and
  weathering. Blocks remain visible with the fracture overlay disabled.
- Bounded signed surface-gradient relief now responds to broad masses as well
  as joints. This is shading relief, not displaced terrain or physical shelves.
- Reduced joint albedo darkening from 0.65 to 0.23; mass lighting, recessed
  channels and coherent rock coloration carry more of the appearance.
- Reused already sampled Rock030/035-family ground rock alongside Rock034
  cliff structure for related but different surface patches, without another
  full triplanar material sample.
- Added two shared geology-map lookups in the cliff branch. Micro-normal
  distance optimization remains intact; macro relief has no distance fade.
- New F5 views: rock masses, structural joints, erosion, weathering, shelves,
  rock character, and shaded cliff structure with joint overlay disabled.

No terrain generator, chunk scheduling/partitioning, biome, river, grassland,
saved settings or lighting changes. Chunk script changes only bind the shared
texture and expose debug views. Existing scree classification is retained.

## Validation

Godot 4.6.1 Compatibility / RTX 3060 Laptop GPU.

Five separated sites rendered, with focus coordinates:

- (-18400, 250.04, -2720)
- (-14880, 249.57, -1440)
- (5120, 247.74, 3840)
- (-5760, 261.33, 17920)
- (1920, 247.05, 9440)

Inspected broad blocks and different lighting/face appearances in these views.
The cracks-disabled image retains faces and shelf edges. Initial compression
grid artifacts were corrected by using half-float height data. Initial runoff
was too densely streaked and was made broader, sparser and less prominent.

Fixed focus (5600,247.3867,3840) captured at horizontal offsets 80/300/900/2400 m.
Final 180-frame far-view viewport rendering means: CPU 1.117 ms / GPU 1.981 ms.
Previous pass: CPU 0.989 / GPU 1.921 ms. These are whole-viewport measurements,
not isolated shader timings; small differences include run-to-run variance.
No CPU mesh-generation path changed, and streaming was not re-benchmarked here.

`check_cliff_geology.gd` passed: RGBAH format, size, mipmaps, finite nonempty
channels and saved material binding. Runtime views compiled/rendered cleanly.

## Limits / remaining criteria

This improves surface structure but does not meet every reference criterion.
Cliff tops and existing talus still have clean/painted transitions. There are no
new physically protruding blocks, overhangs, collapsed geometry, or new debris
transport correlation with fractures above. Primary and secondary joints still
share the old structural mask/debug channel. One geology map with two projections
can repeat; sampled scenes are not proof of globally invisible repetition.
The five sites are geographic variety tests, not proof of all five requested
clean/fractured/eroded/weathered/collapsed archetypes. Discrete distance captures
also do not prove absence of every mesh-LOD or projection transition.

Artifacts: `erosion_cliff_geology_site_0.png` through `_4.png`, debug captures
`erosion_cliff_geology_debug_21.png` through `_27.png`, and the macro-distance
captures. The 27 capture is the important no-scratches structural test.
