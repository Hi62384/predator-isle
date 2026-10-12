# Terrain tuning

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

| Setting | Default | Effect |
| --- | --- | --- |
| dune_size | 369.6 | Distance between dune crests in metres. |
| dune_height | 7.0 | Dune height amplitude. |
| dune_warp | 2.0 | How strongly fine noise bends dune crests. |
| desert_roughness | 3.0 | Small desert height variation. |

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
