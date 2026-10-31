using Godot;
using System;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;

/// <summary>Editable biome controls copied into private worker snapshots.</summary>
[Tool, GlobalClass]
public partial class BiomeExtensionSettings : Resource
{
    // Shared numerical controls; family-specific controls are consumed only by that family.
    [Export(PropertyHint.Range,"2000,20000,250")]
    public double region_metres { get; set; } = 6000;
    [Export(PropertyHint.Range,".1,2,.05")]
    public double relief { get; set; } = 1;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double weathering { get; set; } = .45;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double water_frequency { get; set; } = .12;
    [Export(PropertyHint.Range,".2,2,.05")]
    public double feature_scale { get; set; } = 1;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double structure_density { get; set; } = .65;
    [ExportGroup("Quarry")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double excavation_frequency { get; set; } = .4;
    [Export(PropertyHint.Range,"40,500,10")]
    public double pit_depth { get; set; } = 220;
    [Export(PropertyHint.Range,"20,90,5")]
    public double bench_height { get; set; } = 42;
    [Export(PropertyHint.Range,".03,.15,.01")]
    public double ramp_grade { get; set; } = .1;
    [ExportGroup("Wise Chinese Mountains")]
    [Export(PropertyHint.Range,"100,1800,25")]
    public double pillar_height { get; set; } = 850;
    [Export(PropertyHint.Range,"150,650,25")]
    public double pillar_width { get; set; } = 320;
    [ExportGroup("Volcanic")]
    [Export(PropertyHint.Range,"200,2400,50")]
    public double volcano_height { get; set; } = 1250;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double lava_coverage { get; set; } = .65;
    [Export(PropertyHint.Range,"0,.2,.01")]
    public double active_frequency { get; set; } = .04;
    [ExportGroup("Spore Forest")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double mycelium { get; set; } = .8;
    [Export(PropertyHint.Range,"0,80,2")]
    public double mound_height { get; set; } = 30;
    [Export(PropertyHint.Range,"0,.25,.01")]
    public double luminous_frequency { get; set; } = .08;
    [ExportGroup("Radiation Wasteland")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double catastrophe_frequency { get; set; } = .3;
    [Export(PropertyHint.Range,"50,650,10")]
    public double crater_depth { get; set; } = 280;
    [Export]
    public Vector2 fallout_wind { get; set; } = new Vector2((float)(.86),(float)(.3));
    [Export(PropertyHint.Range,"0,1,.05")]
    public double drainage_strength { get; set; } = .7;
    [ExportGroup("Crystal Wastes")]
    [Export(PropertyHint.Range,"40,650,10")]
    public double crystal_height { get; set; } = 240;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double broken_fraction { get; set; } = .25;
    // Extend only crystal bottom rings below every configured terrain-LOD chord.
    // Independent false restores the prior complete crystal arrays.
    [Export]
    public bool crystal_grounded_roots { get; set; } = true;
    // Mineral-specific physical-width absorption and mostly opaque bulk.
    // False restores the prior shader and complete decorative UV arrays.
    [Export]
    public bool crystal_bulk_material { get; set; } = true;
    [ExportGroup("Insect Colony")]
    // Filtered centimetre-scale apparent clay pitting using the existing soil bank.
    // Independent false restores the original complete structure shader.
    [Export]
    public bool nest_earth_material { get; set; } = true;
    // Unequal-height construction ribs retain original footers,summits and vents.
    // False restores the complete original mound geometry independently.
    [Export]
    public bool nest_construction_profiles { get; set; } = true;
    [Export(PropertyHint.Range,"20,350,10")]
    public double nest_height { get; set; } = 120;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double excavation_strength { get; set; } = .7;
    // Physical, thick summit ducts on selected mature cathedral/dome/rocky nests.
    // Blind recesses, not traversable colony entrances; zero preserves old caps.
    [Export(PropertyHint.Range,"0,1,.05")]
    public double nest_vent_frequency { get; set; } = .25;
    // Broad, low, asymmetric earth domes rather than stretched upright hemispheres.
    // Independent false restores the prior primary proportions and profile.
    [Export]
    public bool nest_broad_domes { get; set; } = true;
    // Keep complete supplemental mound complexes clear of finite burrow access.
    // False is an explicit unsafe-placement reference, not a traversal guarantee.
    [Export]
    public bool nest_protect_burrows { get; set; } = true;
    [ExportGroup("Alien-Infected")]
    // Independent of full-biome coverage. Zero preserves natural terrain exactly.
    [Export(PropertyHint.Range,"0,1,.05")]
    public double overlay_strength { get; set; } = 0;
    [Export(PropertyHint.Range,"0,150,5")]
    public double nerve_height { get; set; } = 45;
    // Broad physical fibres beside actual hive trunks, independent of trunk height.
    // Zero preserves the pre-fibre full-biome and partial-infection terrain exactly.
    [Export(PropertyHint.Range,"0,40,1")]
    public double nerve_fibre_height { get; set; } = 24;
    // Stable material coordinates along actual finite hive trunks. Independently
    // false restores the prior projection and avoids the numeric material atlas.
    [Export]
    public bool nerve_flow_texturing { get; set; } = true;
    // Mirrored offset blending and bounded continuous growth strain in the same
    // finite-path coordinates. False restores the original aligned lookup exactly.
    // No new texture/maps, physical displacement, or world projection period.
    [Export]
    public bool nerve_material_variation { get; set; } = true;
    [Export(PropertyHint.Range,"40,400,10")]
    public double breach_depth { get; set; } = 170;
    // Rare structural blades at real hive-node intersections, never random props.
    [Export(PropertyHint.Range,"0,.5,.01")]
    public double hive_junction_frequency { get; set; } = .12;
    [Export(PropertyHint.Range,"40,300,10")]
    public double hive_junction_height { get; set; } = 120;
    [Export(PropertyHint.Range,"20,160,5")]
    public double hive_junction_width { get; set; } = 75;
    [Export]
    public bool hive_longitudinal_ribs { get; set; } = true;
    // Keep conservative deep foundations from pulling visible arches underground.
    // False retains the original guide independently of rib/membrane controls.
    [Export]
    public bool hive_surface_guided_roots { get; set; } = true;
    // Ordinary conduit shoulders follow their actual ground with compact lips.
    // False restores the prior complete conduit geometry independently. Small
    // branches and protected finite-cave approaches keep the original profile.
    [Export]
    public bool hive_grounded_shoulders { get; set; } = true;
    // Simplify safely distant conduits without removing network paths/landmarks.
    // Mixed/coastal/noise hosts retain full original contacts; only far roofs simplify.
    [Export]
    public bool hive_structure_lod_enabled { get; set; } = true;
    // Conditional on a rare, dry, fully owned junction; zero keeps the open strut.
    [Export(PropertyHint.Range,"0,1,.05")]
    public double hive_membrane_frequency { get; set; } = .4;
    [Export(PropertyHint.Range,"0,.5,.01")]
    public double hive_carapace_frequency { get; set; } = .18;
    [Export(PropertyHint.Range,"80,420,10")]
    public double hive_carapace_width { get; set; } = 240;
    [Export(PropertyHint.Range,"40,240,10")]
    public double hive_carapace_height { get; set; } = 100;
    [ExportGroup("Materials")]
    [Export(PropertyHint.Range,"0,2,.05")]
    public double normal_strength { get; set; } = .7;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double emission_strength { get; set; } = .12;
    [ExportGroup("Finite underground features")]
    [Export]
    public bool caves_enabled { get; set; } = true;
    [Export(PropertyHint.Range,"0,.5,.01")]
    public double cave_frequency { get; set; } = .18;
    [Export]
    public bool special_liquids_enabled { get; set; } = true;
    [Export]
    public bool waterfalls_enabled { get; set; } = true;
    [ExportGroup("Performance")]
    // Alien-only adaptive spatial-query cache; zero-allocation in other samplers.
    // Disable for exact original network projection without retained query tiles.
    [Export]
    public bool network_query_cache_enabled { get; set; } = true;
    // Alien conduit numeric mesh cache per worker. Zero disables/reclaims it.
    // Other families do not allocate it. Metadata is separately capped at 32 entries.
    [Export(PropertyHint.Range,"0,16,1")]
    public int conduit_cache_mib { get; set; } = 8;
    // Local mesh refinement only where an extension owns the complete rectangle.
    [Export(PropertyHint.Range,"64,512,32")]
    public double far_mesh_metres { get; set; } = 256;
}
