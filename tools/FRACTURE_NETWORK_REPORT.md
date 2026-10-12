# Cliff fracture replacement — September 29

Replaced the runtime stripe mask with three independently seeded offline path
networks, each 2048px BC3 with mipmaps. Generator:
`tools/build_fracture_networks.gd`. Seeds 87131, 96304, 105477.

Each network contains five irregular clusters, primary paths with random origins,
lengths and orientation, recursive secondary/tertiary branches, tapering widths,
variable recess strength, interruptions, and cross-joints connecting paths.
Variants contain 74/65/66 finite paths. Rasterization wraps at texture edges;
there are no periodic stripe functions in fracture generation. Large clean areas
remain between clusters. R = structural fractures, G = broad erosion grooves,
B = occasional ledges. Three masks cost about 16 MiB including mipmaps.

Shader blends fixed world-space masks with broad spatial selection and cliff-face
orientation. Grazing projections are suppressed after a render revealed they
could turn cracks into horizontal marks. Convexity favors structural cracks;
concavity/drainage favors erosion. Ledges interrupt structural cracks. Masks
affect albedo and roughness/wetness, not geometry or parallax. Dedicated crack
normal displacement is not implemented; fine rock normal maps remain separate.

Saved material and startup bindings point to the new assets. The old
cliff_macro.res remains on disk as an unused historical asset; its generator
branch was removed, and it is no longer bound by terrain.

Rendered checks: four distances 80/300/900/2400m at the existing cliff test
location, and the three province viewpoints. Masks and rendered cliff/ridge
images were inspected. Initial projection variant measured static viewport
CPU/GPU means 0.794/1.770ms; those are whole viewport numbers and do not isolate
shader cost. Projection correction received an additional province render.

Limits: texture placement remains reusable and periodic over sufficiently large
distances, not mathematically aperiodic. Terrain normals/curvature change with
geometry LOD and can affect mask strength despite fixed world coordinates.
Finite captures do not establish absence of every repetition or LOD artifact.
The full terrain is still below the photographic reference quality.

Changed: terrain_biomes.gdshader, terrain.tres, chunk_terrain.gd (bindings),
build_macro_masks.gd (obsolete stripe generator removed), new generator and
materials/fracture_network_0/1/2.res plus diagnostic PNGs. No height changes.
