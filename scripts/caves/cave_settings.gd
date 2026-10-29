@tool
class_name CaveSettings
extends Resource
## Shared cave foundation settings. Runtime registration is kept disabled
## until its live surface/collision transaction and streaming gates pass.
@export_group("Shared Cave Foundation")
@export var enabled:bool=false
@export_range(350,450,1) var maximum_depth_metres:float=400
@export_range(0,1,.01) var regional_activity:float=.85
@export_range(8,24,.5) var minimum_rock_cover_metres:float=10
@export_range(6,16,.5) var main_route_width_metres:float=8
@export_range(6,16,.5) var main_route_height_metres:float=8
@export_range(.1,.25,.01) var maximum_route_grade:float=.2
@export_group("Graph-Aware Cave Biomes")
@export var biome_regions:Resource=preload("res://config/caves/cave_biome_regions.tres")
@export_group("Default Geology")
## Canonical joined chamber lobes; off restores the original room graph.
@export var chamber_variety:bool=true
## Coherent fracture,bedding and water-worn cross-sections;not new biomes.
@export var geological_morphology:bool=true
## Optional retained side pools. Zero leaves the complete original dry volume.
@export_range(0,1,.01) var seepage_density:float=.15
## Zero restores the unornamented cave mesh exactly. Growth is restricted to
## soluble rock and never occupies the graph's protected main passages.
@export_range(0,1,.05) var formation_density:float=.75
@export_group("Supported Surface Interiors")
## Uses the shared constrained network,never a second burrow engine.
@export var insect_networks:bool=true
## Reuses the same graph/volume for strongly infected regions and real cores.
@export var hive_networks:bool=true
## One identical clay layer instead of loading the eight-rock Default bank.
## False retains the complete previous material binding for comparisons.
@export var specialize_insect_palette:bool=true
@export_group("Sparse Streaming")
## Keep the full committed outdoor cut while deeply underground,outside all
## real mouth envelopes. Explicit destination/teleport plans never defer.
## False restores the original continuous overlying terrain replanning.
@export var retain_deep_surface_cut:bool=true
## Share only bit-identical render vertices;native collision stays unchanged.
## False preserves the original unindexed entrance material transport.
@export var indexed_entry_payload:bool=true
## Temporary rock/collision closures at unloaded cells; canonical cave graph
## and meshes remain unchanged. False retains the old open loading boundary.
@export var seal_stream_frontiers:bool=true
## Shared projection arithmetic across welded tiles;does not move native
## geometry/collision,change camera/far plane,or hide a view boundary.
@export var common_vertex_projection:bool=true
@export_range(96,256,32) var visible_radius_metres:float=160
@export_range(128,384,32) var preload_radius_metres:float=256
@export_range(32,256,16) var resident_cell_limit:int=128
@export_range(4,32,1) var pending_job_limit:int=12
func validation_errors()->Array[String]:
	var errors:Array[String]=[]
	if biome_regions==null or not biome_regions.has_method("validation_errors"):errors.append("Cave biome registry is required")
	else:errors.append_array(biome_regions.validation_errors())
	for value:float in [maximum_depth_metres,regional_activity,minimum_rock_cover_metres,main_route_width_metres,main_route_height_metres,maximum_route_grade,visible_radius_metres,preload_radius_metres,formation_density,seepage_density]:
		if not is_finite(value):errors.append("Cave settings must be finite");return errors
	if maximum_depth_metres<350 or maximum_depth_metres>450:errors.append("Maximum cave depth must be350–450m below the actual local surface")
	if regional_activity<0 or regional_activity>1:errors.append("Regional activity must be0–1")
	if formation_density<0 or formation_density>1:errors.append("Formation density must be0–1")
	if seepage_density<0 or seepage_density>1:errors.append("Seepage density must be0–1")
	if minimum_rock_cover_metres<8:errors.append("Closed routes require at least8m rock cover")
	if main_route_width_metres<6 or main_route_height_metres<6:errors.append("Main routes require at least6m width/headroom")
	if maximum_route_grade<.1 or maximum_route_grade>.25:errors.append("Protected main route grade must remain10–25percent")
	if visible_radius_metres<96 or preload_radius_metres<visible_radius_metres:errors.append("Preload radius must cover the complete visible cave radius")
	if resident_cell_limit<32 or resident_cell_limit>256 or pending_job_limit<4 or pending_job_limit>32:errors.append("Sparse cave cache/queue bounds exceeded")
	return errors
