@tool
extends Resource
## Shared numerical controls; family-specific controls are consumed only by that family.
@export_range(2000,20000,250) var region_metres:float=6000
@export_range(.1,2,.05) var relief:float=1
@export_range(0,1,.05) var weathering:float=.45
@export_range(0,1,.05) var water_frequency:float=.12
@export_range(.2,2,.05) var feature_scale:float=1
@export_range(0,1,.05) var structure_density:float=.65
@export_group("Quarry")
@export_range(0,1,.05) var excavation_frequency:float=.4
@export_range(40,500,10) var pit_depth:float=220
@export_range(20,90,5) var bench_height:float=42
@export_range(.03,.15,.01) var ramp_grade:float=.1
@export_group("Wise Chinese Mountains")
@export_range(100,1800,25) var pillar_height:float=850
@export_range(150,650,25) var pillar_width:float=320
@export_group("Volcanic")
@export_range(200,2400,50) var volcano_height:float=1250
@export_range(0,1,.05) var lava_coverage:float=.65
@export_range(0,.2,.01) var active_frequency:float=.04
@export_group("Spore Forest")
@export_range(0,1,.05) var mycelium:float=.8
@export_range(0,80,2) var mound_height:float=30
@export_range(0,.25,.01) var luminous_frequency:float=.08
@export_group("Radiation Wasteland")
@export_range(0,1,.05) var catastrophe_frequency:float=.3
@export_range(50,650,10) var crater_depth:float=280
@export var fallout_wind:Vector2=Vector2(.86,.3)
@export_range(0,1,.05) var drainage_strength:float=.7
@export_group("Crystal Wastes")
@export_range(40,650,10) var crystal_height:float=240
@export_range(0,1,.05) var broken_fraction:float=.25
## Extend only crystal bottom rings below every configured terrain-LOD chord.
## Independent false restores the prior complete crystal arrays.
@export var crystal_grounded_roots:bool=true
## Mineral-specific physical-width absorption and mostly opaque bulk.
## False restores the prior shader and complete decorative UV arrays.
@export var crystal_bulk_material:bool=true
@export_group("Insect Colony")
## Filtered centimetre-scale apparent clay pitting using the existing soil bank.
## Independent false restores the original complete structure shader.
@export var nest_earth_material:bool=true
## Unequal-height construction ribs retain original footers,summits and vents.
## False restores the complete original mound geometry independently.
@export var nest_construction_profiles:bool=true
@export_range(20,350,10) var nest_height:float=120
@export_range(0,1,.05) var excavation_strength:float=.7
## Physical, thick summit ducts on selected mature cathedral/dome/rocky nests.
## Blind recesses, not traversable colony entrances; zero preserves old caps.
@export_range(0,1,.05) var nest_vent_frequency:float=.25
## Broad, low, asymmetric earth domes rather than stretched upright hemispheres.
## Independent false restores the prior primary proportions and profile.
@export var nest_broad_domes:bool=true
## Keep complete supplemental mound complexes clear of finite burrow access.
## False is an explicit unsafe-placement reference, not a traversal guarantee.
@export var nest_protect_burrows:bool=true
@export_group("Alien-Infected")
## Independent of full-biome coverage. Zero preserves natural terrain exactly.
@export_range(0,1,.05) var overlay_strength:float=0
@export_range(0,150,5) var nerve_height:float=45
## Broad physical fibres beside actual hive trunks, independent of trunk height.
## Zero preserves the pre-fibre full-biome and partial-infection terrain exactly.
@export_range(0,40,1) var nerve_fibre_height:float=24
## Stable material coordinates along actual finite hive trunks. Independently
## false restores the prior projection and avoids the numeric material atlas.
@export var nerve_flow_texturing:bool=true
## Mirrored offset blending and bounded continuous growth strain in the same
## finite-path coordinates. False restores the original aligned lookup exactly.
## No new texture/maps, physical displacement, or world projection period.
@export var nerve_material_variation:bool=true
@export_range(40,400,10) var breach_depth:float=170
## Rare structural blades at real hive-node intersections, never random props.
@export_range(0,.5,.01) var hive_junction_frequency:float=.12
@export_range(40,300,10) var hive_junction_height:float=120
@export_range(20,160,5) var hive_junction_width:float=75
@export var hive_longitudinal_ribs:bool=true
## Keep conservative deep foundations from pulling visible arches underground.
## False retains the original guide independently of rib/membrane controls.
@export var hive_surface_guided_roots:bool=true
## Ordinary conduit shoulders follow their actual ground with compact lips.
## False restores the prior complete conduit geometry independently. Small
## branches and protected finite-cave approaches keep the original profile.
@export var hive_grounded_shoulders:bool=true
## Simplify safely distant conduits without removing network paths/landmarks.
## Mixed/coastal/noise hosts retain full original contacts; only far roofs simplify.
@export var hive_structure_lod_enabled:bool=true
## Conditional on a rare, dry, fully owned junction; zero keeps the open strut.
@export_range(0,1,.05) var hive_membrane_frequency:float=.4
@export_range(0,.5,.01) var hive_carapace_frequency:float=.18
@export_range(80,420,10) var hive_carapace_width:float=240
@export_range(40,240,10) var hive_carapace_height:float=100
@export_group("Materials")
@export_range(0,2,.05) var normal_strength:float=.7
@export_range(0,1,.05) var emission_strength:float=.12
@export_group("Finite underground features")
@export var caves_enabled:bool=true
@export_range(0,.5,.01) var cave_frequency:float=.18
@export var special_liquids_enabled:bool=true
@export var waterfalls_enabled:bool=true
@export_group("Performance")
## Alien-only adaptive spatial-query cache; zero-allocation in other samplers.
## Disable for exact original network projection without retained query tiles.
@export var network_query_cache_enabled:bool=true
## Alien conduit numeric mesh cache per worker. Zero disables/reclaims it.
## Other families do not allocate it. Metadata is separately capped at 32 entries.
@export_range(0,16,1) var conduit_cache_mib:int=8
## Local mesh refinement only where an extension owns the complete rectangle.
@export_range(64,512,32) var far_mesh_metres:float=256
