# Regional surface pass — September 28, 2026

This is a partial implementation, not a completed match to the reference boards.

## Changes

- `scripts/terrain_mesh_builder.gd`: humid provinces gate rivers; lakes favor
  basin provinces. Dry lowlands can remain dry. Uplift belts retain mountain
  coverage where the local hill mask is weak. Plateau caps gain shallow drainage
  depressions and gentle rolling relief, shared with the edge profile.
- `shaders/terrain_biomes.gdshader`: aerial ground previously became constant
  material averages when micro textures faded. Source-texture macro luminance
  now remains, with terrain-height/drainage variation and more soil coverage.
  This adds shader cost; it is not a free optimization.
- `scripts/chunk_terrain.gd`: maximum LOD increased from five to six. Default
  footprint doubles from 24.576 to 49.152 km across, using 117 initial leaves
  instead of 99. Near resolutions are unchanged; far parents remain coarse.
- `shaders/ocean.gdshader`: derivative filtering attenuates subpixel wave normals.
  Regular resolved wave patterns remain visible.
- `tools/check_hierarchical_mesh.gd`: shared-sample tests extended through LOD6.

No new textures, architecture replacement, foliage, lighting or fog changes.
Existing ambientCG assets and manifest are unchanged.

## Measurements

Seed 73921, saved preset, four workers, Godot 4.6.1 Compatibility, RTX 3060 Laptop
GPU, 2560x1346. Existing benchmark route and assertions.

| Run | Width | Initial fill | Leaves | Moving p95 / maximum |
| --- | --- | --- | --- | --- |
| regional_surface | 24.576 km | 1.583 s | 99 | 8.418 / 21.292 ms |
| regional_far | 49.152 km | 4.345 s | 117 | 7.033 / 58.138 ms |
| regional_far_final | 49.152 km | 2.789 s | 117 | 7.623 / 164.500 ms |
| regional_far_repeat | 49.152 km | 1.890 s | 117 | 8.526 / 24.085 ms |

Raw `hierarchy_*.json` files retain per-job records. The 164.5 ms outlier is
unresolved; plan/swap maxima (4.050/6.795 ms) do not explain it. Compilation
is not established as its cause. GPU cost is not isolated. This does not prove
a consistent generation speedup over the previous smaller footprint. Coverage
area quadrupled with 18 additional initial leaves; rendering became costlier.

## Tests and visual evidence

Fixed Grass sample: wet samples decreased from 264 to 104; mountain samples
increased from 3,235 to 4,510. These are not world coverage percentages.
Determinism/thread/edge tests passed. Shared parent/child height, normal and
surface values passed through six levels. Geological controls passed: 66 cuts,
149 scree samples, 23 strong walls and 105 gentle aprons. Sampled 35-degree route
passed (1,206 nodes, not physics testing). Streaming assertions passed at
1.5/7/1500/5000 m/s and three queued teleports.

`preview_provinces.gd` was rendered and images inspected with explicit Grass
preview, seed 73921 and saved settings otherwise unchanged:

- Plain camera (40300,611.78,8200), focus (39200,11.78,7000).
- Ridge camera (-17800,1183.14,18000), focus (-18900,583.14,16800).
- Drainage camera (15100,608.87,24300), focus (14000,8.87,23100).

Outputs: `erosion_province_plain.png`, `erosion_province_ridge.png`,
`erosion_province_basin.png`. These contain this pass's renders; older reports'
coordinates describe historical snapshots.

## Unfinished

Materials remain too procedural and broad. Cliff structure and regional variety
do not yet meet the references. Coarse cliff silhouettes, LOD popping, independent
subtree commits, elevated water, connected lakes, collision and complete region
debug views remain unfinished. Skirts remain instead of full stitching. Nearby
startup visibility still waits for the whole partition. Greater distance does
not preserve every narrow far feature. The frame-time outlier needs diagnosis.
