# Ground material controls

Open `res://ground_materials.tres` in Godot's FileSystem panel. Edit its Inspector
properties and save the root resource. Running terrain picks up saved changes
within about a second, across every LOD. No terrain regeneration is needed.
You can also expand **Terrain → Ground Material Controls** in the scene.

These controls are separate from `cliff_normals.tres`; cliff normal layers and
their tuning have not been changed. This resource contains only small numeric
settings, not texture pixels.

| Setting | Effect |
| --- | --- |
| Region Size Metres | Size of broad lush/dry regional variation |
| Macro Color Strength | Visibility of regional color differences |
| Grass Variation Strength | Amount of dry-grass material and local grass variation |
| Moisture Darkening | How much damp grass darkens |
| Patch Size Metres | Size of irregular bare-ground patches |
| Dirt Coverage | Maximum contribution of inland exposed soil |
| Dirt Cutoff | Raise to make soil patches rarer; lower for more coverage |
| Patch Softness | Raise for broader, gentler patch edges |
| Path Coverage | Surface opacity of the connected path network; zero disables it |
| Wear Size Metres | Junction spacing is approximately 2.5 times this value; increase for fewer paths |
| Wear Width Metres | Nominal path half-width, varied along each curve |
| Path Sand Mix | Amount of pale sediment mixed into compact dirt |
| Path Gravel Mix | Pebbly breakup, biased toward worn shoulders |
| Path Dry Earth Mix | Warm, dry compact-earth variation inside the path |
| Path Mud Mix | Darker, smoother damp-earth pockets inside the path |
| Path Normal Strength | Path-specific PBR relief intensity |
| Path Texture Metres | Fixed world-space texture scale for path detail |
| Path Wander Strength | Curvature and broad side-to-side meandering; zero makes links direct |
| Path Edge Noise Strength | Irregularity of the path outline; zero gives a clean edge |
| Path Edge Noise Metres | World-space size of edge bumps and recesses |
| Path Edge Softness Metres | Width of the feathered transition into surrounding grass |
| Erosion Strength | Exposed soil in sloping drainage/concave ground |
| Ridge Soil Strength | Broken soil along dry convex crests |
| Grass Texture Metres | Fixed world-space size of the near grass texture |
| Grass Normal Strength | Strength of grass-ground surface relief |
| Shoreline Width Metres | Approximate wet mud/silt/gravel margin |
| Damp Margin Metres | Extent of darker ground beyond the water edge |
| Debug Mode | Grass, dirt, wear, shore, moisture, macro, or dryness mask |

Start with Dirt Coverage, Dirt Cutoff, and Grass Variation Strength. To inspect
shore placement, set Debug Mode to Shore; switch back to Off for normal rendering.
Leave the terrain's other debug modes off while using these ground debug views.

Regional Type and Grass Family Weights show environmental mixtures of meadow,
ordinary, wet, highland, dry and sparse grass. Bare Patches, Erosion, Ridge Soil
and Meso isolate their separate contributions. Family differences combine
environmental color/value with the existing healthy/dry/soil PBR structures;
there are not six newly downloaded grass textures.

Dirt Coverage defaults to 0.24 and is further limited by a dry/sparse regional
budget. Lush plains can therefore remain almost soil-free. Paths now form a
shared-tangent cubic network with broad world-space meandering,
sparser cross-branches, independently noisy outlines and feathered shoulders.
Their surface mixes existing ambientCG Ground048 compact dirt, Ground054 sand,
Gravel020, dry-earth mixtures and darker/smoother damp-earth variants, including
their roughness and normal data. Current preset: opacity 0.95, spacing control
340 m, nominal half-width 3.5 m. The previous straight links and hard Y corners
are replaced.

Paths are masked out on steep slopes and water. The graph does not perform
terrain-aware route finding: a link can stop at a cliff or water rather than
rerouting around it. No terrain geometry or navigation data is modified.

Macro values now primarily follow altitude, existing highland/drainage fields,
curvature, exposure and moisture. Existing atmospheric fog is unchanged; it still
attenuates very distant terrain. No saturation boost or negative mip bias is used.

Ground positions and scales are fixed in world space. Distance only removes fine
PBR sampling; it does not move patches or resize textures. Existing Grass001 and
Ground037 supply distinct healthy/dry surface structure, with Ground048 soil,
Ground054 sediment, and Gravel020 gravel. No new assets or terrain geometry.

Shore distance is estimated from height above the existing water surface and
local slope, not a true distance-to-water map. The project currently renders
connected sea-level water, including its inland channels/basins; this pass does
not add elevated lake levels or modify water geometry.

Visual regression: run Godot with `--path . --resolution 1280x720 --script
tools/preview_ground_materials.gd`. It captures aerial, hillside, near-ground,
shoreline and mask views at fixed locations in `tools/erosion_ground_*.png`.
