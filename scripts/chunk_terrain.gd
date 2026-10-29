class_name ChunkTerrain
extends Node3D

## Deterministic, endless terrain streamed in reusable square chunks.
## Climate noise creates broad believable biome regions, while separate masks
## keep dramatic biomes smaller and rarer.

enum Biome { GRASS=0, FOREST=1, SAVANNA=2, SWAMP=3, JUNGLE=4, MOUNTAIN=5, TROPICAL=6, BADLANDS=7, QUARRY=8, WISE_MOUNTAINS=9, VOLCANIC=10, SPORE_FOREST=11, RADIATION_WASTELAND=12, CRYSTAL_WASTES=13, INSECT_COLONY=14, ALIEN_INFECTED=15 }

const BIOME_NAMES:Dictionary = {0:"Grass",1:"Forest",2:"Savanna",3:"Swamp",4:"Jungle",5:"Mountain Range",6:"Tropical",7:"Badlands",8:"Quarry",9:"Wise Chinese Mountains",10:"Volcanic",11:"Spore Forest",12:"Radiation Wasteland",13:"Crystal Wastes",14:"Insect Colony",15:"Alien-Infected"}

@export_category("Terrain Preset")
## Expand to tune biome regions, individual landforms, materials and water. Restart to apply.
@export var settings: TerrainSettings = preload("res://config/world/terrain_settings.tres")
## Explicit test override; saved biome settings remain untouched.
@export var grass_preview: bool = false
@export_enum("Disabled","quarry","wise_mountains","volcanic","spore_forest","radiation_wasteland","crystal_wastes","insect_colony","alien_infected") var extension_preview:String="Disabled"
@export var extension_preview_position:Vector2=Vector2.INF
var _extension_materials:Array[ShaderMaterial]=[]
var _feature_materials:Array[ShaderMaterial]=[]
var _extension_mesh_tiles:Dictionary={}
@export var badlands_preview:bool=false
@export var badlands_preview_feature:String=""
@export var start_in_badlands:bool=false
var _badlands_feature_active:bool=false
var _badlands_feature_position:=Vector2.ZERO
var _badlands_mesh_tiles:Dictionary={}
@export var jungle_preview: bool = false
@export var forest_preview:bool=false
@export var coast_preview:bool=false
@export var beach_preview:bool=false
@export var tropical_preview:bool=false
@export var tropical_preview_feature:String=""
@export var start_in_tropical:bool=false
var _tropical_feature_active:bool=false
var _tropical_feature_position:=Vector2.ZERO
var _tropical_mesh_tiles:Dictionary={}
@export var start_in_beach:bool=true
@export_enum("Disabled","wide_beach","narrow_beach","dune_field","high_foredunes","backdunes","parabolic_dunes","sandy_cove","barrier_beach","sand_spit","lagoon","tidal_flat","sandy_estuary","low_sandy_island","storm_scarps","mixed_rock_sand","sandbars","grass_beach_transition","forest_beach_transition","jungle_beach_transition","savanna_beach_transition","swamp_beach_transition","mountain_beach_transition") var beach_preview_feature:String="Disabled"
@export var start_in_coast:bool=true
@export_enum("Disabled","boulder_shingle","broad_platform","coastal_plateau","coastal_ravines","connected_pools","dark_rocky_coast","fjord_inlets","forest_coast_transition","granite_highlands","grass_coast_transition","headlands","isolated_stack","jungle_coast_transition","low_islands","mountain_coast_transition","offshore_group","river_mouth","rocky_estuary","rocky_islets","rugged_shore","savanna_coast_transition","sea_stacks","sedimentary_cliffs","sheltered_coves","sheltered_inlets","submerged_platform","swamp_coast_transition","tide_pools","towering_cliffs","underwater_cliff","wave_battered","wave_cut_platforms") var coast_preview_feature:String="Disabled"
var _coast_feature_active:bool=false
var _coast_feature_position:=Vector2.ZERO
var _coast_outward:=Vector2.RIGHT
var _coast_mesh_tiles:Dictionary={}
@export var mountain_preview:bool=false
@export var start_in_mountain:bool=true
@export_enum("Disabled","jagged_alpine","massive_ranges","rocky_mountains","ancient_highlands","glacial_country","granite_massifs","stratified_mountains","foothills","alpine_plateaus","basin_country","deep_valleys","escarpments","dry_mountains","scree_highlands","arete_country","meadow_valleys","ridge_system","secondary_ridge","high_pass","v_valley","u_valley","cirque","hanging_valley","tarn","valley_lake","mountain_river","cliff_face","alluvial_fan","grass_mountain_transition","forest_mountain_transition","jungle_mountain_transition","savanna_mountain_transition","swamp_mountain_transition") var mountain_preview_feature:String="Disabled"
var _mountain_feature_active:bool=false
var _mountain_feature_position:=Vector2.ZERO
var _mountain_mesh_tiles:Dictionary={}
@export var swamp_preview:bool=false
@export var start_in_swamp:bool=true
@export_enum("Disabled","backswamp_basin","bayou","blackwater","coastal_wetland","deep_backwater","drained_upland","flooded_lowland","forest_swamp_transition","grass_swamp_transition","hummock_hollow","irregular_ponds","jungle_swamp_transition","major_channel","muddy_islands","muddy_shore","mudflat","narrow_channels","natural_levee","oxbow","peatland","river_floodplain","rocky_wetland","savanna_swamp_transition","seasonal_basin","sediment_bank","shallow_water","swamp_lake") var swamp_preview_feature:String="Disabled"
var _swamp_feature_active:bool=false
var _swamp_feature_position:=Vector2.ZERO
var _swamp_water_material:ShaderMaterial
var _swamp_mesh_tiles:Dictionary={}
@export var savanna_preview:bool=false
@export var start_in_savanna:bool=true
@export_enum("Disabled","golden_plains","rolling","dry_rocky","lush","rugged_hills","kopje_country","highlands","dry_valley","floodplain","semi_arid","laterite","escarpment","basin_country","isolated_kopje","dry_riverbed","perennial_river","seasonal_lake","cracked_basin","worn_trail","rocky_soil_transition","grass_savanna_transition","forest_savanna_transition","jungle_savanna_transition") var savanna_preview_feature:String="Disabled"
var _savanna_feature_active:bool=false
var _savanna_feature_position:=Vector2.ZERO
## Discover real Forest in the mixed world; does not force coverage.
@export var start_in_forest:bool=true
@export_enum("Disabled","deciduous","conifer","mixed","old_growth","rolling_hills","rocky_woodland","mountain_forest","sheltered_valley","riparian","open_meadow","forest_river","forest_stream","forest_lake","forest_ravine","mossy_rock","forest_trail","grass_forest_transition","forest_jungle_transition") var forest_preview_feature:String="Disabled"
var _forest_feature_active:bool=false
var _forest_feature_position:=Vector2.ZERO
## Start the normal mixed world over actual Jungle land, without overriding biome weights.
@export var start_in_jungle:bool=true
## Runtime-only preset; use -- jungle-preview jungle-feature=river_rainforest.
@export_enum("Disabled","lowland_rainforest","rolling_jungle","rugged_hills","foothills","jungle_mountains","river_rainforest","floodplain","rocky_jungle","karst","jungle_plateau","jungle_gorge","humid_basin","upland_rainforest","jungle_river","jungle_lake","grass_jungle_transition") var jungle_preview_feature:String="Disabled"
var _jungle_feature_position:=Vector2.ZERO
var _jungle_feature_active:bool=false
@export_category("Cliff Normal Controls")
## Edit cliff_normals.tres. Saved changes reload automatically while running.
@export var cliff_normal_settings: CliffNormalSettings = preload("res://config/rendering/cliff_normals.tres")
@export var auto_reload_cliff_settings: bool = true
var _cliff_poll_time: float = 0.0
var _cliff_file_time: int = 0
var _cliff_uniform_cache: Dictionary = {}
var _cliff_texture_cache: Array = []
var _cliff_array: Texture2DArray
@export_category("Ground Material Controls")
@export var ground_material_settings: GroundMaterialSettings = preload("res://config/rendering/ground_materials.tres")
@export var auto_reload_ground_settings: bool = true
var _ground_file_time: int = 0
var _ground_uniform_cache: Dictionary = {}
var terrain_debug_view := 0
## Disable for the exact all-owner rendering reference. No terrain fields change.
@export var specialize_terrain_shader:bool=true

@export_category("World")
@export var world_seed: int = 73921
@export_range(-20.0, 20.0, 0.25) var water_level: float = 0.0

@export_category("Chunk Streaming")
@export_range(16.0, 256.0, 1.0) var chunk_size: float = 256.0
@export_range(8, 64, 1) var chunk_resolution: int = 64
@export_range(1, 32, 1) var chunks_created_per_frame: int = 16
@export var target: Node3D
@export_range(1, 6) var worker_count: int = 4
@export_range(1, 8) var distant_job_batch: int = 8
@export_range(0.5, 5.0) var upload_budget_ms: float = 1.5
@export_range(0, 128) var cached_mesh_limit: int = 64

@export_category("Detail Levels")
## Camera and adjacent leaves use 2 m vertices at the default 256 m base size.
@export_range(64, 128, 16) var close_resolution: int = 128
@export_range(0, 2) var close_detail_radius: int = 1
## Avoid a 2 m to 16 m/64 m jump immediately outside the closest leaves.
@export_range(32, 128, 16) var nearby_parent_resolution: int = 64
## Grid resolution for large distant parent chunks.
@export_range(4, 64) var middle_resolution: int = 16
@export var terrain_shadows: bool = true
## Close terrain and major structures only. Uses the transactional visible cut.
@export var terrain_collision_enabled:bool=true
@export var spatial_structure_collision:bool=true
var _last_structure_collision_cell:Vector3=Vector3.INF
@export_category("Underground Caves")
## Shared foundation is disabled until live portal/collision acceptance passes.
@export var cave_settings:Resource=preload("res://config/caves/cave_settings.tres")
var _cave_streamer

var _settings_snapshot: TerrainSettings
var _sampler: RefCounted
const MeshBuilder = preload("res://scripts/terrain_mesh_builder.gd")
var _jobs: Dictionary = {}
var _inflight: Dictionary = {}
var _ready_chunks: Array = []
var _wanted: Dictionary = {}
var _mesh_cache: Dictionary = {}

var _active_chunks: Dictionary = {}
var _chunk_pool: Array[MeshInstance3D] = []
var _pending_chunks: Array[Vector3i] = []
var _partition = preload("res://scripts/csharp/terrain/TerrainPartition.cs").new()
var _ready_cut = preload("res://scripts/csharp/terrain/TerrainReadyCut.cs").new()
var _collision = preload("res://scripts/csharp/terrain/TerrainCollision.cs").new()
var _staged: Dictionary = {}
var _last_plan_position:=Vector2(INF,INF)
var _last_plan_usec:int=0
@export_range(3, 7) var maximum_lod: int = 6
@export_range(0.5, 3.0) var split_distance_ratio: float = 0.95
@export_range(0.1, 1.0) var merge_hysteresis: float = 0.35
var partition_revision:=0
var committed_revision:=0
var _startup_coverage_complete:=false
var incremental_cut_swaps:int=0
var _last_incremental_frame:int=-1
var _last_incremental_attempt_frame:int=-1
var _staging_revision:int=0
var _ready_cut_cache_key:=Vector3i(-1,-1,-1)
var _ready_cut_cache:Dictionary={}
var _ready_cut_diagnostics:Dictionary={}
var _ready_edge_certificates:Dictionary={}
var _teleport_pending:=false
var _teleport_destination:=Vector3.ZERO
var _target_chunk := Vector2i(2147483647, 2147483647)
var _terrain_material: ShaderMaterial
var _lod_materials: Dictionary={}
var _last_material_debug: int=-1
var _water: MeshInstance3D
var profile_streaming := false
var streaming_records: Array[Dictionary] = []
var _queued_at: Dictionary = {}
var _idle_builders: Array[RefCounted] = []
var _jungle_mesh_tiles:Dictionary={}
var _forest_mesh_tiles:Dictionary={}
var _savanna_mesh_tiles:Dictionary={}
var max_plan_ms:=0.0
var max_partition_swap_ms:=0.0

func _ready() -> void:
	_settings_snapshot = settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as TerrainSettings
	# Existing preview overrides must not silently include the new default biome.
	if grass_preview or jungle_preview or forest_preview or OS.get_cmdline_user_args().has("grass-preview") or OS.get_cmdline_user_args().has("jungle-preview") or OS.get_cmdline_user_args().has("forest-preview"):_settings_snapshot.savanna_coverage=0
	grass_preview=grass_preview or OS.get_cmdline_user_args().has("grass-preview")
	if grass_preview:
		_settings_snapshot.grass_coverage=100;_settings_snapshot.jungle_coverage=0;_settings_snapshot.forest_coverage=0
	jungle_preview=jungle_preview or OS.get_cmdline_user_args().has("jungle-preview")
	if jungle_preview_feature=="Disabled":jungle_preview_feature=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("jungle-feature="):jungle_preview_feature=argument.trim_prefix("jungle-feature=");jungle_preview=true
	if jungle_preview:
		grass_preview=false
		_settings_snapshot.savanna_coverage=0
		_settings_snapshot.forest_coverage=0
		_settings_snapshot.grass_coverage=0;_settings_snapshot.jungle_coverage=100
		_settings_snapshot.temperature_enabled=false
		if jungle_preview_feature=="grass_jungle_transition":_settings_snapshot.grass_coverage=50;_settings_snapshot.jungle_coverage=50
		if not jungle_preview_feature.is_empty():
			var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/jungle_previews.json"))
			if manifest is Dictionary and manifest.get("features",{}).has(jungle_preview_feature):
				var item:Dictionary=manifest.features[jungle_preview_feature]
				_jungle_feature_position=Vector2(float(item.x),float(item.z));_jungle_feature_active=true;world_seed=int(manifest.seed)
			else:push_warning("Unknown Jungle preview feature: "+jungle_preview_feature)
	forest_preview=forest_preview or OS.get_cmdline_user_args().has("forest-preview")
	if forest_preview_feature=="Disabled":forest_preview_feature=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("forest-feature="):forest_preview_feature=argument.trim_prefix("forest-feature=");forest_preview=true
	if forest_preview:
		grass_preview=false;jungle_preview=false;_jungle_feature_active=false
		_settings_snapshot.savanna_coverage=0
		_settings_snapshot.grass_coverage=0;_settings_snapshot.jungle_coverage=0;_settings_snapshot.forest_coverage=100
		if forest_preview_feature=="grass_forest_transition":_settings_snapshot.grass_coverage=50;_settings_snapshot.forest_coverage=50;_settings_snapshot.grass_region_size=8000
		if forest_preview_feature=="forest_jungle_transition":_settings_snapshot.jungle_coverage=50;_settings_snapshot.forest_coverage=50
		if not forest_preview_feature.is_empty():
			var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/forest_previews.json"))
			if manifest is Dictionary and manifest.get("features",{}).has(forest_preview_feature):
				var item:Dictionary=manifest.features[forest_preview_feature];_forest_feature_position=Vector2(item.x,item.z);_forest_feature_active=true;world_seed=int(manifest.seed)
			else:push_warning("Unknown Forest preview: "+forest_preview_feature)
	savanna_preview=savanna_preview or OS.get_cmdline_user_args().has("savanna-preview")
	if savanna_preview_feature=="Disabled":savanna_preview_feature=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("savanna-feature="):savanna_preview_feature=argument.trim_prefix("savanna-feature=");savanna_preview=true
	if savanna_preview:
		grass_preview=false;jungle_preview=false;forest_preview=false;_forest_feature_active=false;_jungle_feature_active=false
		_settings_snapshot.grass_coverage=0;_settings_snapshot.forest_coverage=0;_settings_snapshot.jungle_coverage=0;_settings_snapshot.savanna_coverage=100
		if savanna_preview_feature=="grass_savanna_transition":_settings_snapshot.grass_coverage=50;_settings_snapshot.savanna_coverage=50;_settings_snapshot.grass_region_size=10000
		if savanna_preview_feature=="forest_savanna_transition":_settings_snapshot.forest_coverage=50;_settings_snapshot.savanna_coverage=50
		if savanna_preview_feature=="jungle_savanna_transition":_settings_snapshot.jungle_coverage=50;_settings_snapshot.savanna_coverage=50
		if not savanna_preview_feature.is_empty():
			var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/savanna_previews.json"))
			if manifest is Dictionary and manifest.get("features",{}).has(savanna_preview_feature):
				var item:Dictionary=manifest.features[savanna_preview_feature];_savanna_feature_position=Vector2(item.x,item.z);_savanna_feature_active=true;world_seed=int(manifest.seed)
			else:push_warning("Unknown Savanna preview: "+savanna_preview_feature)
	if grass_preview or jungle_preview or forest_preview or savanna_preview:_settings_snapshot.swamp_coverage=0
	swamp_preview=swamp_preview or OS.get_cmdline_user_args().has("swamp-preview")
	if swamp_preview_feature=="Disabled":swamp_preview_feature=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("swamp-feature="):swamp_preview_feature=argument.trim_prefix("swamp-feature=");swamp_preview=true
	if swamp_preview:
		grass_preview=false;jungle_preview=false;forest_preview=false;savanna_preview=false
		_jungle_feature_active=false;_forest_feature_active=false;_savanna_feature_active=false
		_settings_snapshot.grass_coverage=0;_settings_snapshot.jungle_coverage=0;_settings_snapshot.forest_coverage=0;_settings_snapshot.savanna_coverage=0;_settings_snapshot.swamp_coverage=100
		for biome:String in ["grass","forest","jungle","savanna"]:
			if swamp_preview_feature==biome+"_swamp_transition":
				_settings_snapshot.set(biome+"_coverage",50);_settings_snapshot.set(biome+"_region_size",9000);_settings_snapshot.swamp_coverage=50
		if not swamp_preview_feature.is_empty():
			var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/swamp_previews.json"))
			if manifest is Dictionary and manifest.get("features",{}).has(swamp_preview_feature):
				var item:Dictionary=manifest.features[swamp_preview_feature];_swamp_feature_position=Vector2(item.x,item.z);_swamp_feature_active=true;world_seed=int(manifest.seed)
			else:push_warning("Unknown Swamp preview: "+swamp_preview_feature)
	if grass_preview or jungle_preview or forest_preview or savanna_preview or swamp_preview:_settings_snapshot.mountain_coverage=0
	mountain_preview=mountain_preview or OS.get_cmdline_user_args().has("mountain-preview")
	if mountain_preview_feature=="Disabled":mountain_preview_feature=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("mountain-feature="):mountain_preview_feature=argument.trim_prefix("mountain-feature=");mountain_preview=true
	if mountain_preview:
		grass_preview=false;jungle_preview=false;forest_preview=false;savanna_preview=false;swamp_preview=false
		_jungle_feature_active=false;_forest_feature_active=false;_savanna_feature_active=false;_swamp_feature_active=false
		_settings_snapshot.grass_coverage=0;_settings_snapshot.jungle_coverage=0;_settings_snapshot.forest_coverage=0;_settings_snapshot.savanna_coverage=0;_settings_snapshot.swamp_coverage=0;_settings_snapshot.mountain_coverage=100
		for biome:String in ["grass","forest","jungle","savanna","swamp"]:
			if mountain_preview_feature==biome+"_mountain_transition":
				_settings_snapshot.set(biome+"_coverage",50);_settings_snapshot.set(biome+"_region_size",16000);_settings_snapshot.mountain_coverage=50
		if not mountain_preview_feature.is_empty():
			var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/mountain_previews.json"))
			if manifest is Dictionary and manifest.get("features",{}).has(mountain_preview_feature):
				var item:Dictionary=manifest.features[mountain_preview_feature];_mountain_feature_position=Vector2(item.x,item.z);_mountain_feature_active=true;world_seed=int(manifest.seed)
			else:push_warning("Unknown Mountain preview: "+mountain_preview_feature)

	if grass_preview or jungle_preview or forest_preview or savanna_preview or swamp_preview or mountain_preview:
		_settings_snapshot.rocky_coast_enabled=false;_settings_snapshot.beaches_enabled=false
	coast_preview=coast_preview or OS.get_cmdline_user_args().has("coast-preview")
	if coast_preview_feature=="Disabled":coast_preview_feature=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("coast-feature="):coast_preview_feature=argument.trim_prefix("coast-feature=");coast_preview=true
	if coast_preview:
		_settings_snapshot.beaches_enabled=false
		grass_preview=false;jungle_preview=false;forest_preview=false;savanna_preview=false;swamp_preview=false;mountain_preview=false
		_jungle_feature_active=false;_forest_feature_active=false;_savanna_feature_active=false;_swamp_feature_active=false;_mountain_feature_active=false
		_settings_snapshot.rocky_coast_enabled=true;_settings_snapshot.rocky_coast.coverage=1
		for biome:String in ["grass","forest","jungle","savanna","swamp","mountain"]:_settings_snapshot.set(biome+"_coverage",0)
		var underlying:String="grass"
		for biome:String in ["grass","forest","jungle","savanna","swamp","mountain"]:
			if coast_preview_feature==biome+"_coast_transition":underlying=biome
		_settings_snapshot.set(underlying+"_coverage",100)
		if not coast_preview_feature.is_empty():
			var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/rocky_coast_previews.json"))
			if manifest is Dictionary and manifest.get("features",{}).has(coast_preview_feature):
				var item:Dictionary=manifest.features[coast_preview_feature];_coast_feature_position=Vector2(item.x,item.z);_coast_outward=Vector2(item.outward_x,item.outward_z);_coast_feature_active=true;world_seed=int(manifest.seed)
			else:push_warning("Unknown Rocky Coast feature: "+coast_preview_feature)
	beach_preview=beach_preview or OS.get_cmdline_user_args().has("beach-preview")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("beach-feature="):beach_preview_feature=argument.trim_prefix("beach-feature=");beach_preview=true
	if beach_preview:
		if beach_preview_feature=="Disabled" or beach_preview_feature.is_empty():beach_preview_feature="wide_beach"
		grass_preview=false;jungle_preview=false;forest_preview=false;savanna_preview=false;swamp_preview=false;mountain_preview=false;coast_preview=false
		_jungle_feature_active=false;_forest_feature_active=false;_savanna_feature_active=false;_swamp_feature_active=false;_mountain_feature_active=false
		_settings_snapshot.rocky_coast_enabled=true;_settings_snapshot.beaches_enabled=true;_settings_snapshot.rocky_coast.coverage=1;_settings_snapshot.beach.coverage=1
		for biome:String in ["grass","forest","jungle","savanna","swamp","mountain"]:_settings_snapshot.set(biome+"_coverage",100 if beach_preview_feature==biome+"_beach_transition" or (biome=="grass" and not beach_preview_feature.ends_with("_transition")) else 0)
		var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/beach_previews.json"))
		if manifest is Dictionary and manifest.get("features",{}).has(beach_preview_feature):
			var item:Dictionary=manifest.features[beach_preview_feature];_coast_feature_position=Vector2(item.x,item.z);_coast_outward=Vector2(item.outward_x,item.outward_z);_coast_feature_active=true;world_seed=int(manifest.seed)
		else:push_warning("Unknown beach feature: "+beach_preview_feature)
	if grass_preview or jungle_preview or forest_preview or savanna_preview or swamp_preview or mountain_preview or coast_preview or beach_preview:_settings_snapshot.tropical_coverage=0
	tropical_preview=tropical_preview or OS.get_cmdline_user_args().has("tropical-preview")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("tropical-feature="):tropical_preview_feature=argument.trim_prefix("tropical-feature=");tropical_preview=true
	if tropical_preview:
		grass_preview=false;jungle_preview=false;forest_preview=false;savanna_preview=false;swamp_preview=false;mountain_preview=false;coast_preview=false;beach_preview=false
		_jungle_feature_active=false;_forest_feature_active=false;_savanna_feature_active=false;_swamp_feature_active=false;_mountain_feature_active=false;_coast_feature_active=false
		_settings_snapshot.rocky_coast_enabled=false;_settings_snapshot.beaches_enabled=false
		for biome:String in ["grass","forest","jungle","savanna","swamp","mountain"]+TerrainSettings.EXTENSION_KEYS:_settings_snapshot.set(biome+"_coverage",0)
		_settings_snapshot.alien_infected.overlay_strength=0
		_settings_snapshot.tropical_coverage=100
		for biome:String in ["grass","forest","jungle","savanna","swamp","mountain","volcanic"]:
			if tropical_preview_feature==biome+"_tropical_transition":
				_settings_snapshot.set(biome+"_coverage",50);_settings_snapshot.set(biome+"_region_size",14000);_settings_snapshot.tropical_coverage=50
				if biome=="volcanic":_settings_snapshot.tropical_region_size=14000
		if tropical_preview_feature=="beach_tropical_transition" or tropical_preview_feature=="coast_tropical_transition" or tropical_preview_feature=="river_mouth":
			_settings_snapshot.rocky_coast_enabled=true;_settings_snapshot.beaches_enabled=tropical_preview_feature=="beach_tropical_transition"
		if not tropical_preview_feature.is_empty():
			var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/tropical_previews.json"))
			if manifest is Dictionary and manifest.get("features",{}).has(tropical_preview_feature):
				var item:Dictionary=manifest.features[tropical_preview_feature];_tropical_feature_position=Vector2(item.x,item.z);_tropical_feature_active=true;world_seed=int(manifest.seed)
			else:push_warning("Unknown Tropical feature: "+tropical_preview_feature)
	if grass_preview or jungle_preview or forest_preview or savanna_preview or swamp_preview or mountain_preview or coast_preview or beach_preview or tropical_preview:_settings_snapshot.badlands_coverage=0
	badlands_preview=badlands_preview or OS.get_cmdline_user_args().has("badlands-preview")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("badlands-feature="):badlands_preview_feature=argument.trim_prefix("badlands-feature=");badlands_preview=true
	if badlands_preview:
		grass_preview=false;jungle_preview=false;forest_preview=false;savanna_preview=false;swamp_preview=false;mountain_preview=false;coast_preview=false;beach_preview=false;tropical_preview=false
		_jungle_feature_active=false;_forest_feature_active=false;_savanna_feature_active=false;_swamp_feature_active=false;_mountain_feature_active=false;_coast_feature_active=false;_tropical_feature_active=false
		_settings_snapshot.rocky_coast_enabled=false;_settings_snapshot.beaches_enabled=false
		for biome:String in ["grass","forest","jungle","savanna","swamp","mountain","tropical"]:_settings_snapshot.set(biome+"_coverage",0)
		_settings_snapshot.badlands_coverage=100
		for biome:String in ["grass","forest","jungle","savanna","swamp","mountain","tropical"]:
			if badlands_preview_feature==biome+"_badlands_transition":
				_settings_snapshot.set(biome+"_coverage",50);_settings_snapshot.set(biome+"_region_size",14000);_settings_snapshot.badlands_coverage=50
		if not badlands_preview_feature.is_empty():
			var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/badlands_previews.json"))
			if manifest is Dictionary and manifest.get("features",{}).has(badlands_preview_feature):
				var item:Dictionary=manifest.features[badlands_preview_feature];_badlands_feature_position=Vector2(item.x,item.z);_badlands_feature_active=true;world_seed=int(manifest.seed)
			else:push_warning("Unknown Badlands feature: "+badlands_preview_feature)
	RenderingServer.set_debug_generate_wireframes(true)
	if extension_preview=="Disabled":extension_preview=""
	for argument:String in OS.get_cmdline_user_args():
		if argument.begins_with("biome="):extension_preview=argument.trim_prefix("biome=")
		if argument.begins_with("biome-position="):
			var components:PackedStringArray=argument.trim_prefix("biome-position=").split(",")
			if components.size()==2:extension_preview_position=Vector2(float(components[0]),float(components[1]))
		if argument=="all-biomes":
			for k:String in TerrainSettings.EXTENSION_KEYS:_settings_snapshot.set(k+"_coverage",20)
	if not extension_preview.is_empty() and TerrainSettings.EXTENSION_KEYS.has(extension_preview):
		grass_preview=false;jungle_preview=false;forest_preview=false;savanna_preview=false;swamp_preview=false;mountain_preview=false;coast_preview=false;beach_preview=false;tropical_preview=false;badlands_preview=false
		for k:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS:_settings_snapshot.set(k+"_coverage",0)
		_settings_snapshot.set(extension_preview+"_coverage",100);_settings_snapshot.beaches_enabled=false;_settings_snapshot.rocky_coast_enabled=false
		_settings_snapshot.island_size=100400;_settings_snapshot.island_spacing=585
	_configure_noise()
	_terrain_material = preload("res://materials/terrain.tres").duplicate() as ShaderMaterial
	_terrain_material.shader=preload("res://scripts/csharp/rendering/TerrainShaderVariants.cs").new().select(_terrain_material.shader,_settings_snapshot,specialize_terrain_shader)
	# Bind explicitly as well as in the resource: inspector material saves must
	# never silently turn an unbound array into white cliffs / invalid normals.
	_terrain_material.set_shader_parameter("palette_color",preload("res://materials/palette_color_roughness.tres"))
	_terrain_material.set_shader_parameter("palette_normal",preload("res://materials/palette_normals.tres"))
	_terrain_material.set_shader_parameter("cliff_ambient_normals",preload("res://materials/cliff_ambient_normals.tres"))
	_terrain_material.set_shader_parameter("cliff_world_seed",float(world_seed))
	_terrain_material.set_shader_parameter("grass_macro",preload("res://materials/grass_macro.res"))
	_terrain_material.set_shader_parameter("meso_mask",preload("res://materials/meso_macro.res"))
	assert(_terrain_material.get_shader_parameter("palette_color").get_layers()==9)
	assert(_terrain_material.get_shader_parameter("palette_normal").get_layers()==9)
	_terrain_material.set_shader_parameter("water_level", water_level)
	_apply_material_settings()
	if _settings_snapshot.mountain_coverage>0 or _settings_snapshot.rocky_coast_enabled or _settings_snapshot.beaches_enabled or _settings_snapshot.tropical_coverage>0 or _settings_snapshot.badlands_coverage>0:
		_terrain_material.set_shader_parameter("mountain_colors",load("res://materials/mountain_colors.tres"))
		_terrain_material.set_shader_parameter("mountain_normals",load("res://materials/mountain_normals.tres"))
		var config:Resource=_settings_snapshot.mountain if _settings_snapshot.mountain!=null else preload("res://scripts/mountain_settings.gd").new()
		for key in config.uniforms():_terrain_material.set_shader_parameter(key,config.uniforms()[key])
		if _settings_snapshot.swamp_coverage<=0:
			_swamp_water_material=ShaderMaterial.new();_swamp_water_material.shader=preload("res://shaders/swamp_water.gdshader")
	if _settings_snapshot.rocky_coast_enabled or _settings_snapshot.beaches_enabled:
		for key in _settings_snapshot.rocky_coast.uniforms():_terrain_material.set_shader_parameter(key,_settings_snapshot.rocky_coast.uniforms()[key])
	if _settings_snapshot.beaches_enabled:
		_terrain_material.set_shader_parameter("beach_colors",load("res://materials/beach_colors.tres"))
		_terrain_material.set_shader_parameter("beach_normals",load("res://materials/beach_normals.tres"))
		for key in _settings_snapshot.beach.uniforms():_terrain_material.set_shader_parameter(key,_settings_snapshot.beach.uniforms()[key])
	if _settings_snapshot.tropical_coverage>0:
		for key in _settings_snapshot.tropical.uniforms():_terrain_material.set_shader_parameter(key,_settings_snapshot.tropical.uniforms()[key])
	if _settings_snapshot.badlands_coverage>0:
		_terrain_material.set_shader_parameter("badlands_height_multiplier",maxf(_settings_snapshot.height_multiplier,.01))
		for key in _settings_snapshot.badlands.uniforms():_terrain_material.set_shader_parameter(key,_settings_snapshot.badlands.uniforms()[key])
		_terrain_material.set_shader_parameter("swamp_colors",load("res://materials/swamp_colors.tres"))
		_terrain_material.set_shader_parameter("swamp_normals",load("res://materials/swamp_normals.tres"))
	if _settings_snapshot.swamp_coverage>0:
		_terrain_material.set_shader_parameter("swamp_colors",load("res://materials/swamp_colors.tres"))
		_terrain_material.set_shader_parameter("swamp_normals",load("res://materials/swamp_normals.tres"))
		var config:Resource=_settings_snapshot.swamp if _settings_snapshot.swamp!=null else preload("res://scripts/swamp_settings.gd").new()
		for key in config.uniforms():_terrain_material.set_shader_parameter(key,config.uniforms()[key])
		_terrain_material.set_shader_parameter("swamp_flood_stage",config.flood_stage)
		_swamp_water_material=ShaderMaterial.new();_swamp_water_material.shader=preload("res://shaders/swamp_water.gdshader")
		_swamp_water_material.set_shader_parameter("swamp_water_opacity",config.water_opacity)
		_swamp_water_material.set_shader_parameter("swamp_ripple",config.ripple_strength)
		_swamp_water_material.set_shader_parameter("swamp_flood_stage",config.flood_stage)
	if _settings_snapshot.savanna_coverage>0 or _settings_snapshot.mountain_coverage>0 or _settings_snapshot.rocky_coast_enabled or _settings_snapshot.beaches_enabled or _settings_snapshot.tropical_coverage>0 or _settings_snapshot.badlands_coverage>0:
		_terrain_material.set_shader_parameter("savanna_colors",load("res://materials/savanna_colors.tres"))
		_terrain_material.set_shader_parameter("savanna_normals",load("res://materials/savanna_normals.tres"))
		var config:Resource=_settings_snapshot.savanna if _settings_snapshot.savanna!=null else preload("res://scripts/savanna_settings.gd").new()
		for key in config.uniforms():_terrain_material.set_shader_parameter(key,config.uniforms()[key])
	if _settings_snapshot.forest_coverage>0:
		_terrain_material.set_shader_parameter("forest_colors",load("res://materials/forest_colors.tres"))
		_terrain_material.set_shader_parameter("forest_normals",load("res://materials/forest_normals.tres"))
		var config:Resource=_settings_snapshot.forest if _settings_snapshot.forest!=null else preload("res://scripts/forest_settings.gd").new()
		for key in config.uniforms():_terrain_material.set_shader_parameter(key,config.uniforms()[key])
	if _settings_snapshot.jungle_coverage>0 or _settings_snapshot.forest_coverage>0 or _settings_snapshot.swamp_coverage>0 or _settings_snapshot.mountain_coverage>0 or _settings_snapshot.rocky_coast_enabled or _settings_snapshot.beaches_enabled or _settings_snapshot.tropical_coverage>0 or _settings_snapshot.badlands_coverage>0:
		_terrain_material.set_shader_parameter("jungle_colors",load("res://materials/jungle_colors.tres"))
		_terrain_material.set_shader_parameter("jungle_normals",load("res://materials/jungle_normals.tres"))
		var config:JungleSettings=_settings_snapshot.jungle if _settings_snapshot.jungle!=null else JungleSettings.new()
		for key in config.uniforms():_terrain_material.set_shader_parameter(key,config.uniforms()[key])
	var extension_enabled:bool=false
	var normal_settings:=PackedFloat32Array();var emission_settings:=PackedFloat32Array()
	for k:String in TerrainSettings.EXTENSION_KEYS:
		var config:Resource=_settings_snapshot.get(k);normal_settings.append(config.normal_strength);emission_settings.append(config.emission_strength)
		extension_enabled=extension_enabled or _settings_snapshot.get(k+"_coverage")>0 or (k=="alien_infected" and config.overlay_strength>0)
	if extension_enabled:
		for bank:String in ["mountain","savanna","jungle"]:
			_terrain_material.set_shader_parameter(bank+"_colors",load("res://materials/"+bank+"_colors.tres"));_terrain_material.set_shader_parameter(bank+"_normals",load("res://materials/"+bank+"_normals.tres"))
		_terrain_material.set_shader_parameter("extension_normals",normal_settings);_terrain_material.set_shader_parameter("extension_emission",emission_settings)
		if _swamp_water_material==null:_swamp_water_material=ShaderMaterial.new();_swamp_water_material.shader=preload("res://shaders/swamp_water.gdshader")
	var biology_enabled:bool=_settings_snapshot.spore_forest_coverage>0 or _settings_snapshot.alien_infected_coverage>0 or _settings_snapshot.alien_infected.overlay_strength>0
	if biology_enabled:
		_terrain_material.set_shader_parameter("biological_colors",load("res://materials/biological_colors_v3.tres"))
		_terrain_material.set_shader_parameter("alien_tissue_variation_enabled",_settings_snapshot.alien_infected.nerve_material_variation)
	_extension_materials.clear()
	_feature_materials.clear()
	for i in range(4):
		var material:=ShaderMaterial.new();material.shader=preload("res://shaders/terrain_features.gdshader");material.set_shader_parameter("kind",i);_feature_materials.append(material)
	for i in range(3):
		var material:=ShaderMaterial.new();material.shader=preload("res://shaders/biome_structures.gdshader");material.set_shader_parameter("family",5+i)
		if i==0:material.shader=preload("res://shaders/crystal_bulk.gdshader") if _settings_snapshot.crystal_wastes.crystal_bulk_material else preload("res://shaders/crystal_transmission.gdshader")
		if i==1:
			if _settings_snapshot.insect_colony.nest_earth_material:material.shader=preload("res://shaders/insect_earth.gdshader")
			material.set_shader_parameter("structure_colors",load("res://materials/savanna_colors.tres"));material.set_shader_parameter("structure_normals",load("res://materials/savanna_normals.tres"))
		if i==2 and biology_enabled:
			material.set_shader_parameter("biological_colors",load("res://materials/biological_colors_v3.tres"))
			material.set_shader_parameter("alien_tissue_variation_enabled",_settings_snapshot.alien_infected.nerve_material_variation)
		if i>0:material.set_shader_parameter("normal_strength",_settings_snapshot.get(TerrainSettings.EXTENSION_KEYS[i+5]).normal_strength)
		_extension_materials.append(material)
	_terrain_material.set_shader_parameter("chunk_size_metres",chunk_size)
	_lod_materials[0]=_terrain_material
	for level in range(1,maximum_lod+1):
		var material:=_terrain_material.duplicate() as ShaderMaterial
		material.set_shader_parameter("chunk_lod",float(level))
		material.set_shader_parameter("chunk_size_metres",chunk_size*float(1<<level))
		_lod_materials[level]=material
	_refresh_cliff_settings(true)
	_refresh_ground_settings(true)
	_create_water()

	if target == null:
		target = get_viewport().get_camera_3d()
	if target is Camera3D:
		# A saved camera position can be inside a generated highland.
		# Correct startup clearance without changing saved coordinates,
		# terrain, player bodies, or subsequent free-camera/teleport movement.
		var floor_height:float=get_height_at(target.global_position)
		if _settings_snapshot.water_enabled:floor_height=maxf(floor_height,water_level)
		target.global_position.y=maxf(target.global_position.y,floor_height+40.0)

	if not extension_preview.is_empty() and is_instance_valid(target):
		var focus:Vector3=find_extension_focus(extension_preview)
		if extension_preview_position.is_finite():focus=Vector3(extension_preview_position.x,0,extension_preview_position.y)
		focus.y=_get_height(focus.x,focus.z)+600;target.global_position=focus
	elif (_badlands_feature_active or badlands_preview or start_in_badlands) and is_instance_valid(target) and _settings_snapshot.badlands_coverage>0:
		var focus:Vector3=Vector3(_badlands_feature_position.x,0,_badlands_feature_position.y) if _badlands_feature_active else find_badlands_focus()
		if focus.is_finite():
			focus.y=get_height_at(focus);target.global_position=focus+Vector3(-800,500,-1000)
			if target is Camera3D:target.look_at(focus)
	elif (_tropical_feature_active or tropical_preview or start_in_tropical) and is_instance_valid(target) and _settings_snapshot.tropical_coverage>0:
		var focus:Vector3=Vector3(_tropical_feature_position.x,0,_tropical_feature_position.y) if _tropical_feature_active else find_tropical_focus()
		if focus.is_finite():
			focus.y=maxf(get_height_at(focus),_sampler.get_water_surface_height(focus.x,focus.z));target.global_position=focus+Vector3(-800,500,-1000)
			if target is Camera3D:target.look_at(focus)
	elif _coast_feature_active and is_instance_valid(target):
		var focus:=Vector3(_coast_feature_position.x,0,_coast_feature_position.y);focus.y=maxf(get_height_at(focus),water_level)
		target.global_position=focus+Vector3(_coast_outward.x*500,220,_coast_outward.y*500)
		target.global_position.y=maxf(target.global_position.y,get_height_at(target.global_position)+30)
		if target is Camera3D:target.look_at(focus)
	elif start_in_beach and _settings_snapshot.beaches_enabled and not beach_preview and not coast_preview and not grass_preview and not jungle_preview and not forest_preview and not savanna_preview and not swamp_preview and not mountain_preview:
		var focus:Vector3=find_coast_focus(true)
		if focus.is_finite():
			target.global_position=focus+Vector3(0,100,0)
			if target is Camera3D:target.look_at(focus+Vector3(200,-10,200))
	elif start_in_coast and not coast_preview and not grass_preview and not jungle_preview and not forest_preview and not savanna_preview and not swamp_preview and not mountain_preview and not coast_preview and _settings_snapshot.rocky_coast_enabled:
		var focus:Vector3=find_coast_focus()
		if focus.is_finite():
			target.global_position=focus+Vector3(0,150,0)
			if target is Camera3D:target.look_at(focus+Vector3(200,-20,200))
	elif _mountain_feature_active and is_instance_valid(target):
		var focus:=Vector3(_mountain_feature_position.x,0,_mountain_feature_position.y);focus.y=get_height_at(focus)
		target.global_position=focus+Vector3(-500,320,-700)
		target.global_position.y=maxf(target.global_position.y,get_height_at(target.global_position)+60)
		if target is Camera3D:target.look_at(focus)
	elif start_in_mountain and not grass_preview and not jungle_preview and not forest_preview and not savanna_preview and not swamp_preview and not mountain_preview and not coast_preview and _settings_snapshot.mountain_coverage>0:
		var focus:Vector3=find_mountain_focus()
		if focus.is_finite():
			target.global_position=focus+Vector3(0,140,0)
			if target is Camera3D:target.look_at(focus+Vector3(400,-30,400))
	elif _swamp_feature_active and is_instance_valid(target):
		var focus:=Vector3(_swamp_feature_position.x,0,_swamp_feature_position.y);focus.y=maxf(get_height_at(focus),_sampler.get_water_surface_height(focus.x,focus.z))
		target.global_position=focus+Vector3(-220,90,-300)
		if target is Camera3D:target.look_at(focus)
	elif start_in_swamp and not grass_preview and not jungle_preview and not forest_preview and not savanna_preview and not swamp_preview and not mountain_preview and not coast_preview and _settings_snapshot.swamp_coverage>0:
		var focus:Vector3=find_swamp_focus()
		if focus.is_finite():
			target.global_position=focus+Vector3(0,45,0)
			if target is Camera3D:target.look_at(focus+Vector3(180,0,180))
	elif _savanna_feature_active and is_instance_valid(target):
		var focus:=Vector3(_savanna_feature_position.x,0,_savanna_feature_position.y);focus.y=get_height_at(focus)
		target.global_position=focus+Vector3(-220,150,-300)
		target.global_position.y=maxf(target.global_position.y,get_height_at(target.global_position)+40)
		if target is Camera3D:target.look_at(focus)
	elif start_in_savanna and not grass_preview and not jungle_preview and not forest_preview and not savanna_preview and not swamp_preview and not mountain_preview and not coast_preview and _settings_snapshot.savanna_coverage>0:
		var focus:Vector3=find_savanna_focus()
		if focus.is_finite():
			target.global_position=focus+Vector3(0,80,0)
			if target is Camera3D:target.look_at(focus+Vector3(180,0,180))
	elif _forest_feature_active and is_instance_valid(target):
		var focus:=Vector3(_forest_feature_position.x,0,_forest_feature_position.y);focus.y=get_height_at(focus)
		target.global_position=focus+Vector3(-220,150,-300)
		target.global_position.y=maxf(target.global_position.y,get_height_at(target.global_position)+40)
		if target is Camera3D:target.look_at(focus)
	elif _jungle_feature_active and is_instance_valid(target):
		var focus:=Vector3(_jungle_feature_position.x,0,_jungle_feature_position.y);focus.y=get_height_at(focus)
		target.global_position=focus+Vector3(-220,150,-300)
		target.global_position.y=maxf(target.global_position.y,get_height_at(target.global_position)+40)
		if target is Camera3D:target.look_at(focus)
	elif start_in_forest and not grass_preview and not jungle_preview and not forest_preview and not savanna_preview and not swamp_preview and not mountain_preview and not coast_preview and _settings_snapshot.forest_coverage>0:
		var focus:Vector3=find_forest_focus()
		if focus.is_finite():
			target.global_position=focus+Vector3(0,80,0)
			if target is Camera3D:target.look_at(focus+Vector3(180,0,180))
	elif start_in_jungle and not grass_preview and not jungle_preview and not forest_preview and not savanna_preview and not swamp_preview and not mountain_preview and not coast_preview and _settings_snapshot.jungle_coverage>0:
		var focus:Vector3=find_jungle_focus()
		if focus.is_finite():
			target.global_position=focus+Vector3(0,80,0)
			if target is Camera3D:target.look_at(focus+Vector3(180,0,180))
	if cave_settings!=null and cave_settings.enabled:
		var errors:Array=cave_settings.validation_errors()
		if errors.is_empty():
			_cave_streamer=preload("res://scripts/caves/streamer.gd").new();_cave_streamer.name="CaveStreaming";add_child(_cave_streamer);_cave_streamer.initialize(self)
		else:push_warning("Cave foundation disabled: "+str(errors))
	_refresh_visible_chunks()
	if OS.get_cmdline_user_args().has("smoke-test"):
		add_child.call_deferred(preload("res://scripts/runtime_smoke.gd").new())


func _process(_delta: float) -> void:
	_cliff_poll_time+=_delta
	if _cliff_poll_time>=0.5:
		_cliff_poll_time=0.0
		if auto_reload_cliff_settings and cliff_normal_settings and not cliff_normal_settings.resource_path.is_empty():
			var config_path:=cliff_normal_settings.resource_path
			var modified:=FileAccess.get_modified_time(config_path)
			if modified!=_cliff_file_time:
				var updated=ResourceLoader.load(config_path,"",ResourceLoader.CACHE_MODE_REPLACE)
				if updated is CliffNormalSettings: cliff_normal_settings=updated
				_cliff_file_time=modified
		_refresh_cliff_settings()
		_refresh_ground_settings()
	var mode: int=_terrain_material.get_shader_parameter("debug_view")
	if mode!=_last_material_debug:
		for material: ShaderMaterial in _material_variants(): material.set_shader_parameter("debug_view",mode)
		for material: ShaderMaterial in _structure_material_variants(): material.set_shader_parameter("debug_view",mode)
		_last_material_debug=mode
	if not is_instance_valid(target):
		target = get_viewport().get_camera_3d()
		if target == null:
			return

	var new_target_chunk := world_to_chunk(target.global_position)
	# Refresh active collider coverage independently of transactional terrain
	# cuts, including while a replacement cut is still loading.
	var collision_cell:Vector3=(target.global_position/256.0).floor()
	if collision_cell!=_last_structure_collision_cell:
		_last_structure_collision_cell=collision_cell
		for active_node:MeshInstance3D in _active_chunks.values():_update_near_collision(active_node,false,true)
	var moved:=Vector2(target.position.x,target.position.z).distance_to(_last_plan_position)
	if not _teleport_pending and (new_target_chunk != _target_chunk or moved>chunk_size*0.5):
		# Bound replanning during flight, while allowing near-detail interests
		# to catch up instead of waiting for an unrelated distant job tail.
		if committed_revision==partition_revision or moved>chunk_size*float(1<<maximum_lod)*0.5 or (moved>chunk_size*2 and Time.get_ticks_usec()-_last_plan_usec>1000000):
			_refresh_visible_chunks()

	_collect_jobs()
	if _cave_streamer!=null:
		var interest:Vector3=_teleport_destination if _teleport_pending else target.global_position
		_cave_streamer.tick(interest,target.global_position,maxi(0,worker_count-_jobs.size()),not _pending_chunks.is_empty())
	_dispatch_jobs()


func _exit_tree() -> void:
	# Workers own their samplers and never access this node or the scene tree.
	for job: Dictionary in _jobs.values():
		WorkerThreadPool.wait_for_task_completion(job.task)
	_jobs.clear()
	if _cave_streamer!=null:_cave_streamer.shutdown()


func _refresh_cliff_settings(force: bool=false) -> void:
	if cliff_normal_settings==null: return
	var values:=cliff_normal_settings.uniforms()
	var signature:=cliff_normal_settings.texture_signature()
	if force or signature!=_cliff_texture_cache:
		var rebuilt:=cliff_normal_settings.build_texture_array()
		if rebuilt==null:
			push_error("Cliff normal texture array rebuild failed; previous settings retained")
			return
		_cliff_array=rebuilt
		_cliff_texture_cache=signature
		for material: ShaderMaterial in _material_variants(): material.set_shader_parameter("cliff_ambient_normals",_cliff_array)
	if force or values!=_cliff_uniform_cache:
		for material: ShaderMaterial in _material_variants():
			for parameter in values: material.set_shader_parameter(parameter,values[parameter])
		_cliff_uniform_cache=values
	if force and not cliff_normal_settings.resource_path.is_empty():
		_cliff_file_time=FileAccess.get_modified_time(cliff_normal_settings.resource_path)


func _refresh_ground_settings(force: bool = false) -> void:
	if ground_material_settings == null: return
	var path := ground_material_settings.resource_path
	if auto_reload_ground_settings and not path.is_empty():
		var modified := FileAccess.get_modified_time(path)
		if not force and modified != _ground_file_time:
			var updated = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
			if updated is GroundMaterialSettings: ground_material_settings = updated
		_ground_file_time = modified
	var values := ground_material_settings.uniforms()
	if force or values != _ground_uniform_cache:
		for material: ShaderMaterial in _material_variants():
			for parameter in values: material.set_shader_parameter(parameter, values[parameter])
		_ground_uniform_cache = values


func world_to_chunk(world_position: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_position.x / chunk_size),
		floori(world_position.z / chunk_size)
	)


func get_loaded_chunk_count() -> int:
	return _active_chunks.size()


func cycle_debug_view() -> void:
	set_debug_view((terrain_debug_view + 1) % 154)


func set_debug_view(view: int) -> void:
	terrain_debug_view = clampi(view, 0, 153)
	if _terrain_material == null:
		return
	var shader_view:int=terrain_debug_view+81 if terrain_debug_view>=99 else (terrain_debug_view+79 if terrain_debug_view>=61 else (terrain_debug_view+73 if terrain_debug_view>=47 else (terrain_debug_view+64 if terrain_debug_view>=36 else (terrain_debug_view+52 if terrain_debug_view>=28 else (0 if terrain_debug_view==5 or terrain_debug_view>=21 else terrain_debug_view)))))
	if terrain_debug_view>=131:shader_view=terrain_debug_view+89
	if terrain_debug_view>=141:shader_view=terrain_debug_view+99
	if terrain_debug_view>=149:shader_view=terrain_debug_view+111
	_terrain_material.set_shader_parameter("debug_view",shader_view)
	for material:ShaderMaterial in _structure_material_variants():material.set_shader_parameter("debug_view",shader_view)
	if _swamp_water_material!=null:
		var water_debug:int=terrain_debug_view+81 if terrain_debug_view>=99 else (terrain_debug_view+79 if terrain_debug_view>=61 else 0)
		if terrain_debug_view>=131:water_debug=172 if terrain_debug_view==137 or terrain_debug_view==145 else 0
		_swamp_water_material.set_shader_parameter("swamp_water_debug",water_debug)
	for material: ShaderMaterial in _material_variants():
		material.set_shader_parameter("cliff_normal_debug",terrain_debug_view-21 if terrain_debug_view>=21 and terrain_debug_view<28 else 0)
	get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME if terrain_debug_view==5 else Viewport.DEBUG_DRAW_DISABLED


func get_debug_view_name() -> String:
	if terrain_debug_view>=149:return ["Extension ownership","Extension regional identity","Extension feature intensity","Extension wetness","Extension geometric normals"][terrain_debug_view-149]
	if terrain_debug_view>=141:return ["Badlands region","Badlands influence","Sedimentary coordinate / hardness","Exposure / erosion / deposition","Major / secondary drainage","Sedimentary materials","Badlands normals","Badlands LOD"][terrain_debug_view-141]
	if terrain_debug_view>=131:return ["Tropical region","Tropical influence","Tropical moisture","Tropical elevation","Tropical slope","Tropical exposed rock","Tropical wetness / water / wear","Tropical material mix","Tropical mapped normals","Tropical LOD"][terrain_debug_view-131]
	if terrain_debug_view>=119:return ["Beach region","Sand influence","Sand wetness","Intertidal band","Sand elevation","Dune slope","Regional wind","Sandy water depth","Sand material mix","Sand mapped normals","Sand LOD","Sand chunk bounds"][terrain_debug_view-119]
	if terrain_debug_view>=99:return ["Coast region","Coast influence","Coast normal orientation","Coast wave exposure","Coast steep faces","Coast elevation","Coast low headland potential","Coast sheltered sediment","Coast platform classification","Coast pool depth","Coast geology","Coast bedrock coverage","Coast wetness","Coast intertidal zone","Coast sediment","Coast underwater depth","Coast material mix","Coast mapped normals","Coast LOD","Coast chunk bounds"][terrain_debug_view-99]
	if terrain_debug_view>=81:return ["Mountain region","Mountain elevation","Mountain primary ridges","Mountain secondary ridges","Mountain peaks/saddles","Mountain valleys","Mountain glacial influence","Mountain cliff slopes","Mountain exposed rock","Mountain scree","Mountain geology","Mountain erosion","Mountain drainage/depth","Mountain material mix","Mountain mapped normals","Mountain LOD","Mountain chunk bounds","Mountain macro/meso normals"][terrain_debug_view-81]
	if terrain_debug_view>=61:return ["Swamp region","Swamp height","Swamp local water level","Swamp relative elevation","Swamp depth","Swamp connectivity classes","Swamp basins","Swamp channels","Swamp levees","Swamp saturation","Swamp mud","Swamp peat","Swamp sediment","Swamp shoreline","Swamp islands","Swamp LOD","Swamp chunk bounds","Swamp material mix","Swamp normals","Swamp worn routes"][terrain_debug_view-61]
	if terrain_debug_view>=47:return ["Savanna regions","Savanna height","Savanna slope","Savanna bedrock","Savanna soil","Savanna aridity","Savanna moisture","Savanna drainage","Savanna dry channels","Savanna basins","Savanna material mix","Savanna macro variation","Savanna trails","Savanna mapped normals"][terrain_debug_view-47]
	if terrain_debug_view>=36:return ["Forest regions","Forest conifer litter influence","Forest meadow/clearing","Forest wetness","Forest leaf litter","Forest needle litter","Forest moss","Forest exposed rock","Forest trails","Forest material mixture","Forest mapped normals"][terrain_debug_view-36]
	if terrain_debug_view>=28:return ["Jungle regions","Jungle wetness","Jungle drainage","Jungle rock exposure","Jungle water corridors","Jungle material weights","Jungle mapped normals","Jungle canopy placement potential (no foliage)"][terrain_debug_view-28]
	if terrain_debug_view>=21:
		return ["Cliff ambient normals: combined","Cliff base normal only / overlays off","Cliff macro normals only","Cliff medium normals only","Cliff coverage: macro red / medium green","Cliff ambient texture IDs","Cliff combined world normal"][terrain_debug_view-21]
	return ["Shaded","Material weights","Dominant material ID","Unlit albedo","Geometry normals","Wireframe","Geology: red scree / green drainage / blue cliff","Normal maps OFF","Mapped normals","Quadtree LOD / bounds","Macro grass","Exposed soil","Drainage wetness","Dryness","Cliff coverage","Fracture recess","Scree","Meso controls","Micro detail disabled","Region fields: highland / drainage / exposure","Macro only (meso and micro disabled)"][terrain_debug_view]


func get_target_chunk() -> Vector2i:
	return _target_chunk


func get_biome_name_at(world_position: Vector3) -> String:
	if _sampler._coast!=null:
		_sampler._get_height(world_position.x,world_position.z)
		if _sampler._last_coast.x>.5:return "Coastal Dunes / Beaches" if _sampler._last_coast.w<0 and float(int(-_sampler._last_coast.w-1)&255)/255>.5 else "Rocky Coast"
	return BIOME_NAMES[_get_biome(world_position.x, world_position.z)]


func get_height_at(world_position: Vector3) -> float:
	return _get_height(world_position.x, world_position.z)


func get_temperature_at(world_position: Vector3) -> float:
	return _sampler.get_temperature(world_position.x, world_position.z)


func get_climate_description(world_position: Vector3) -> String:
	if not _settings_snapshot.temperature_enabled:
		return "climate OFF"
	return "regional climate (Grass / Forest / Jungle / Savanna / Swamp / Mountains / Tropical)"


func _configure_noise() -> void:
	_badlands_mesh_tiles.clear()
	_coast_mesh_tiles.clear()
	_jungle_mesh_tiles.clear()
	_forest_mesh_tiles.clear()
	_savanna_mesh_tiles.clear();_swamp_mesh_tiles.clear();_mountain_mesh_tiles.clear()
	_tropical_mesh_tiles.clear()
	if _settings_snapshot == null:
		_settings_snapshot = settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as TerrainSettings
	_sampler = MeshBuilder.new()
	_sampler.settings = _settings_snapshot
	_sampler.water_level = water_level
	_sampler.world_seed = world_seed
	_sampler.chunk_size = chunk_size
	_sampler._configure_noise()


func _apply_material_settings() -> void:
	var config := _settings_snapshot
	_terrain_material.set_shader_parameter("tile_metres", Vector4(
		maxf(config.texture_tile_metres.x, 0.1), maxf(config.texture_tile_metres.y, 0.1),
		maxf(config.texture_tile_metres.z, 0.1), maxf(config.texture_tile_metres.w, 0.1)))
	for parameter in ["sand_tint", "normal_strength", "detail_distance", "texture_blend_sharpness", "shore_width", "shore_strength", "slope_rock_start", "slope_rock_end", "grass_roughness_floor", "grass_specular", "grass_normal_scale"]:
		_terrain_material.set_shader_parameter(parameter, config.get(parameter))


func _tile_resolution(key: Vector3i) -> int:
	var offset:=Vector2i(key.x,key.y)-_target_chunk
	var close:bool=key.z==0 and maxi(absi(offset.x),absi(offset.y))<=close_detail_radius
	var resolution:int=maxi(nearby_parent_resolution,middle_resolution) if key.z==1 else (maxi(32,middle_resolution) if key.z==2 else (middle_resolution if key.z>0 else (maxi(chunk_resolution,close_resolution) if close else chunk_resolution)))
	if _cave_streamer!=null and _cave_streamer.needs_fine_surface(key):resolution=maxi(resolution,mini(128,ceili(chunk_size/2.0)))
	if _sampler!=null and _sampler._extras_enabled and key.z>1:
		if not _extension_mesh_tiles.has(key):
			if _extension_mesh_tiles.size()>=2048:_extension_mesh_tiles.clear()
			var span:float=chunk_size*float(1<<key.z)
			_extension_mesh_tiles[key]=_sampler.pure_extension_rect(Rect2(Vector2(key.x,key.y)*span,Vector2.ONE*span))
			if _extension_mesh_tiles[key]<0:
				# Mixed leaves also retain narrow extension silhouettes. This only
				# raises their sampling density; ownership still uses the canonical field.
				var best:int=-1;var best_spacing:float=INF
				for z:float in [.05,.5,.95]:
					for x:float in [.05,.5,.95]:
						var p:Vector2=(Vector2(key.x,key.y)+Vector2(x,z))*span;_sampler._biome_weights(p.x,p.y)
						for i in range(8):
							if _sampler._extra_weights[i]<.15:continue
							var edge:float=_settings_snapshot.get(TerrainSettings.EXTENSION_KEYS[i]).far_mesh_metres
							if edge<best_spacing:best=i;best_spacing=edge
				_extension_mesh_tiles[key]=best
		var owner:int=_extension_mesh_tiles[key]
		if owner>=0:
			var span:float=chunk_size*float(1<<key.z);var edge:float=maxf(_settings_snapshot.get(TerrainSettings.EXTENSION_KEYS[owner]).far_mesh_metres,64)
			resolution=maxi(resolution,mini(128,int(pow(2,ceil(log(span/edge)/log(2))))))
	if _sampler!=null and _settings_snapshot.forest_coverage>0 and key.z>1 and _settings_snapshot.forest.far_mesh_metres>0:
		if not _forest_mesh_tiles.has(key):
			if _forest_mesh_tiles.size()>=2048:_forest_mesh_tiles.clear()
			var span:float=chunk_size*float(1<<key.z)
			_forest_mesh_tiles[key]=_sampler.is_pure_forest_rect(Rect2(Vector2(key.x,key.y)*span,Vector2.ONE*span))
		if _forest_mesh_tiles[key]:
			var span:float=chunk_size*float(1<<key.z);var edge:float=maxf(_settings_snapshot.forest.far_mesh_metres,128)
			resolution=maxi(resolution,mini(64,int(pow(2,ceil(log(span/edge)/log(2))))))
	if _sampler!=null and _settings_snapshot.jungle!=null and _settings_snapshot.jungle_coverage>0 and key.z>1 and _settings_snapshot.jungle.far_mesh_metres>0:
		if not _jungle_mesh_tiles.has(key):
			if _jungle_mesh_tiles.size()>=2048:_jungle_mesh_tiles.clear()
			var span:float=chunk_size*float(1<<key.z)
			_jungle_mesh_tiles[key]=_sampler.is_pure_jungle_rect(Rect2(Vector2(key.x,key.y)*span,Vector2.ONE*span))
		if _jungle_mesh_tiles[key]:
			var span:float=chunk_size*float(1<<key.z);var edge:float=maxf(_settings_snapshot.jungle.far_mesh_metres,128)
			resolution=maxi(resolution,mini(64,int(pow(2,ceil(log(span/edge)/log(2))))))
	if _sampler!=null and _settings_snapshot.savanna!=null and _settings_snapshot.savanna_coverage>0 and key.z>2 and _settings_snapshot.savanna.far_mesh_metres>0:
		if not _savanna_mesh_tiles.has(key):
			if _savanna_mesh_tiles.size()>=2048:_savanna_mesh_tiles.clear()
			var span:float=chunk_size*float(1<<key.z);var bounds:=Rect2(Vector2(key.x,key.y)*span,Vector2.ONE*span)
			var detail:bool=false
			if _sampler.is_pure_savanna_rect(bounds):
				for p:Vector2 in [bounds.position,bounds.end,bounds.position+Vector2(span,0),bounds.position+Vector2(0,span),bounds.get_center()]:
					var w:PackedFloat32Array=_sampler._savanna.region_weights(p)
					if w[2]+w[4]+w[5]+w[6]+w[11]>.25:detail=true;break
			_savanna_mesh_tiles[key]=detail
		if _savanna_mesh_tiles[key]:
			var span:float=chunk_size*float(1<<key.z);var edge:float=maxf(_settings_snapshot.savanna.far_mesh_metres,256)
			resolution=maxi(resolution,mini(64,int(pow(2,ceil(log(span/edge)/log(2))))))
	if _sampler!=null and _settings_snapshot.swamp_coverage>0 and key.z>1:
		if not _swamp_mesh_tiles.has(key):
			if _swamp_mesh_tiles.size()>=2048:_swamp_mesh_tiles.clear()
			var span:float=chunk_size*float(1<<key.z)
			_swamp_mesh_tiles[key]=_sampler.is_pure_swamp_rect(Rect2(Vector2(key.x,key.y)*span,Vector2.ONE*span))
		if _swamp_mesh_tiles[key]:
			var span:float=chunk_size*float(1<<key.z);var edge:float=maxf(_settings_snapshot.swamp.far_mesh_metres,128)
			resolution=maxi(resolution,mini(64,int(pow(2,ceil(log(span/edge)/log(2))))))
	if _sampler!=null and _settings_snapshot.mountain_coverage>0 and key.z>1:
		if not _mountain_mesh_tiles.has(key):
			if _mountain_mesh_tiles.size()>=2048:_mountain_mesh_tiles.clear()
			var span:float=chunk_size*float(1<<key.z)
			_mountain_mesh_tiles[key]=_sampler.is_pure_mountain_rect(Rect2(Vector2(key.x,key.y)*span,Vector2.ONE*span))
		if _mountain_mesh_tiles[key]:
			var span:float=chunk_size*float(1<<key.z);var edge:float=maxf(_settings_snapshot.mountain.far_mesh_metres,128)
			resolution=maxi(resolution,mini(128,int(pow(2,ceil(log(span/edge)/log(2))))))

	if _sampler!=null and _settings_snapshot.tropical_coverage>0 and key.z>1:
		if not _tropical_mesh_tiles.has(key):
			if _tropical_mesh_tiles.size()>=2048:_tropical_mesh_tiles.clear()
			var span:float=chunk_size*float(1<<key.z)
			var bounds:=Rect2(Vector2(key.x,key.y)*span,Vector2.ONE*span)
			var edge:float=0
			if _sampler.is_pure_tropical_rect(bounds):
				edge=maxf(_settings_snapshot.tropical.far_mesh_metres,128)
				var river:float=preload("res://scripts/tropical_river_detail.gd").spacing(_sampler,bounds,key.z)
				if river>0:edge=minf(edge,river)
			_tropical_mesh_tiles[key]=edge
		var edge:float=float(_tropical_mesh_tiles[key])
		if edge>0:
			var span:float=chunk_size*float(1<<key.z)
			var cap:int=128 if edge<maxf(_settings_snapshot.tropical.far_mesh_metres,128) else 64
			resolution=maxi(resolution,mini(cap,int(pow(2,ceil(log(span/edge)/log(2))))))
	if _sampler!=null and _settings_snapshot.badlands_coverage>0 and key.z>0:
		if not _badlands_mesh_tiles.has(key):
			if _badlands_mesh_tiles.size()>=2048:_badlands_mesh_tiles.clear()
			var span:float=chunk_size*float(1<<key.z)
			var bounds:=Rect2(Vector2(key.x,key.y)*span,Vector2.ONE*span)
			var pure:bool=_sampler.is_pure_badlands_rect(bounds)
			var edge:float=maxf(_settings_snapshot.badlands.far_mesh_metres,64) if pure else 0
			for point:Vector2 in [bounds.position,bounds.end,bounds.position+Vector2(span,0),bounds.position+Vector2(0,span),bounds.get_center()]:
				if _sampler._island_mask(point.x,point.y)<=.01:continue
				if not pure:
					_sampler._biome_weights(point.x,point.y)
					if _sampler._badlands_weight<.15:continue
				var weights:PackedFloat32Array=_sampler._badlands.region_weights(point)
				if weights[5]>.35 and _settings_snapshot.badlands.remnants>0:
					var remnant_detail:float=maxf(_settings_snapshot.badlands.remnant_mesh_metres*(.5 if key.z==1 else 1),8)
					edge=minf(edge,remnant_detail) if edge>0 else remnant_detail;break
				if weights[4]+weights[5]+weights[6]+weights[7]+weights[12]+weights[13]>.35:
					var detail:float=maxf(_settings_snapshot.badlands.dissected_mesh_metres,64)
					edge=minf(edge,detail) if edge>0 else detail;break
			_badlands_mesh_tiles[key]=edge
		if float(_badlands_mesh_tiles[key])>0:
			var span:float=chunk_size*float(1<<key.z);var edge:float=float(_badlands_mesh_tiles[key])
			resolution=maxi(resolution,mini(64,int(pow(2,ceil(log(span/edge)/log(2))))))
	if _sampler!=null and (_settings_snapshot.rocky_coast_enabled or _settings_snapshot.beaches_enabled) and key.z>1:
		if not _coast_mesh_tiles.has(key):
			if _coast_mesh_tiles.size()>=2048:_coast_mesh_tiles.clear()
			var span:float=chunk_size*float(1<<key.z);var center:Vector2=(Vector2(key.x,key.y)+Vector2.ONE*.5)*span
			var d:float=absf(_sampler._island_mask(center.x,center.y)*_settings_snapshot.island_size*.5)
			_coast_mesh_tiles[key]=d<span*2.2+_sampler._coast_limit
		if _coast_mesh_tiles[key]:
			var span:float=chunk_size*float(1<<key.z);var edge:float=clampf(_settings_snapshot.rocky_coast.far_mesh_metres,64,128)
			resolution=maxi(resolution,mini(128,int(pow(2,ceil(log(span/edge)/log(2))))))
	return resolution


func _material_variants()->Array:
	var variants:Array=_lod_materials.values()
	for collection:Dictionary in [_active_chunks,_staged]:
		for node:MeshInstance3D in collection.values():
			if node.mesh!=null and node.mesh.get_surface_count()>0:
				var material:Material=node.mesh.surface_get_material(0)
				if not variants.has(material):variants.append(material)
	for mesh:ArrayMesh in _mesh_cache.values():
		var material:Material=mesh.surface_get_material(0)
		if not variants.has(material):variants.append(material)
	if _cave_streamer!=null:
		for material:Material in _cave_streamer.surface_materials():
			if not variants.has(material):variants.append(material)
	return variants


func _tile_material(key:Vector3i)->ShaderMaterial:
	return _lod_materials[key.z]


func _structure_material_variants()->Array:
	var variants:Array=_extension_materials.duplicate();var meshes:Array=_mesh_cache.values()
	for collection:Dictionary in [_active_chunks,_staged]:
		for node:MeshInstance3D in collection.values():
			if node.mesh!=null:meshes.append(node.mesh)
	for mesh:ArrayMesh in meshes:
		if not mesh.has_meta("extension_structures"):continue
		var structures:ArrayMesh=mesh.get_meta("extension_structures")
		for surface in range(structures.get_surface_count()):
			var material:Material=structures.surface_get_material(surface)
			if not variants.has(material):variants.append(material)
	return variants


func _mesh_key(key: Vector3i) -> Vector4i:
	return Vector4i(key.x,key.y,key.z,_tile_resolution(key))


func request_teleport(destination: Vector3) -> void:
	if not destination.is_finite(): return
	_teleport_pending=true
	_teleport_destination=destination
	_refresh_visible_chunks(destination)


func _refresh_visible_chunks(destination: Vector3=Vector3.INF) -> void:
	if target==null: return
	# Keep the existing complete outdoor cut under deep closed cave cover.
	# Destination plans,teleports and required surface mouths always refresh.
	if not destination.is_finite() and not _teleport_pending and _cave_streamer!=null and not _active_chunks.is_empty() and _cave_streamer.defer_surface_plan(target.global_position):return
	var plan_start:=Time.get_ticks_usec()
	var point:=destination if destination.is_finite() else target.global_position
	_target_chunk=world_to_chunk(point)
	_last_plan_position=Vector2(point.x,point.z)
	_last_plan_usec=Time.get_ticks_usec()
	_partition.base_size=chunk_size
	_partition.maximum_level=maximum_lod
	_partition.split_ratio=split_distance_ratio
	_partition.merge_ratio=split_distance_ratio+merge_hysteresis
	if _cave_streamer!=null:_partition.forced_detail_regions=_cave_streamer.detail_rectangles()
	else:_partition.forced_detail_regions.clear()
	var plan: Dictionary=_partition.select(_last_plan_position,_wanted)
	_wanted=plan
	partition_revision+=1
	_pending_chunks.clear()
	for key: Vector3i in _staged.keys():
		if not _wanted.has(key) or int(_staged[key].get_meta("resolution"))!=_tile_resolution(key):
			_release_node(_staged[key]);_staged.erase(key)
	for key: Vector3i in _wanted:
		if _active_chunks.has(key) and int(_active_chunks[key].get_meta("resolution"))==_tile_resolution(key): continue
		if _staged.has(key) or _inflight.has(key): continue
		_pending_chunks.append(key)
	_pending_chunks.sort_custom(func(a: Vector3i,b: Vector3i) -> bool:
		return _partition.distance_to(a,_last_plan_position)<_partition.distance_to(b,_last_plan_position))
	if _startup_coverage_complete:
		var supports:Dictionary={}
		for parent:Vector3i in _active_chunks:
			if _partition.distance_to(parent,_last_plan_position)>chunk_size*16:continue
			var near_group:bool=_partition.distance_to(parent,_last_plan_position)<=chunk_size*2
			var children:Array[Vector3i]=[];var bounded:bool=true
			for child:Vector3i in _wanted:
				if not _ready_cut.contains(parent,child):continue
				# A nearby parent needs ALL replacement siblings, including LOD1,
				# before a safe local transaction can publish the camera's mesh.
				if not near_group and (child.z<2 or _estimated_sampling_work(_mesh_key(child))>8192):bounded=false;break
				children.append(child)
			if bounded:
				for child:Vector3i in children:supports[child]=true
		_pending_chunks.sort_custom(func(a:Vector3i,b:Vector3i)->bool:
			var da:float=_partition.distance_to(a,_last_plan_position);var db:float=_partition.distance_to(b,_last_plan_position)
			var pa:int=0 if a.z==0 and da==0 else (1 if supports.has(a) else 2)
			var pb:int=0 if b.z==0 and db==0 else (1 if supports.has(b) else 2)
			return pa<pb if pa!=pb else da<db)
	_queued_at.clear()
	for key in _pending_chunks: _queued_at[key]=Time.get_ticks_usec()
	_update_water_position()
	if profile_streaming: max_plan_ms=maxf(max_plan_ms,(Time.get_ticks_usec()-plan_start)/1000.0)


func _estimated_sampling_work(key: Vector4i) -> int:
	var vertices: int=(key.w+3)*(key.w+3)
	# Sparse parent meshes also need four canonical 32 m derivative probes per
	# vertex. Batch by sampling work, not just chunk count: eight such parents
	# monopolized a worker while other workers ran out of pending jobs.
	if chunk_size*float(1<<key.z)/key.w>32.0:vertices+=4*(key.w+1)*(key.w+1)
	return vertices

func _dispatch_jobs() -> void:
	var started:=Time.get_ticks_usec()
	while not _pending_chunks.is_empty() and _jobs.size()+(0 if _cave_streamer==null else _cave_streamer.job_count())<worker_count and _ready_chunks.size()<worker_count*distant_job_batch*2:
		var key: Vector3i=_pending_chunks.pop_front()
		if _inflight.has(key) or not _wanted.has(key): continue
		var cache_key:=_mesh_key(key)
		if _mesh_cache.has(cache_key):
			_stage_chunk(key,cache_key.w,_mesh_cache[cache_key])
			_mesh_cache.erase(cache_key)
		else:
			var builder: RefCounted
			if not _idle_builders.is_empty(): builder=_idle_builders.pop_back()
			else:
				builder=MeshBuilder.new()
				builder.settings=_settings_snapshot.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
				builder.water_level=water_level;builder.world_seed=world_seed
				builder._configure_noise()
			var batch: Array[Vector4i]=[cache_key]
			var sampling_work: int=_estimated_sampling_work(cache_key)
			_inflight[key]=true
			while key.z>0 and batch.size()<distant_job_batch and not _pending_chunks.is_empty():
				var next: Vector3i=_pending_chunks.front()
				if next.z==0: break
				var next_key: Vector4i=_mesh_key(next)
				var next_work: int=_estimated_sampling_work(next_key)
				if sampling_work+next_work>4096:break
				_pending_chunks.pop_front()
				if _inflight.has(next) or not _wanted.has(next): continue
				batch.append(next_key);_inflight[next]=true
				sampling_work+=next_work
			var result: Array=[]
			var job: Dictionary={"task":-1,"result":result,"builder":builder}
			var base_size:=chunk_size
			var index_structures:bool=spatial_structure_collision
			var support_steps:PackedFloat64Array=preload("res://scripts/biome_extension_structures.gd").support_grids(base_size,close_resolution,middle_resolution,maximum_lod)
			job.task=WorkerThreadPool.add_task(func() -> void:
				for item in batch:
					var begin:=Time.get_ticks_usec()
					builder.chunk_size=base_size*float(1<<item.z)
					var arrays: Array=builder.build(Vector2i(item.x,item.y),item.w)
					var edge_profiles:Dictionary=_ready_cut.edge_profiles(arrays,item.w)
					var has_features:bool=builder._extras_enabled or (builder._tropical!=null and builder.settings.tropical.waterfall_frequency>0 and builder.settings.water_enabled)
					var feature_mesher=preload("res://scripts/terrain_feature_meshes.gd").new()
					var features:Dictionary=feature_mesher.build(builder,Vector2i(item.x,item.y)) if has_features else {}
					if item.z<=1 and not features.is_empty() and not features.openings.is_empty():features["ground_collision"]=_collision.clipped_ground(arrays,features.openings,item.w)
					var structures:Array=preload("res://scripts/lod_biome_extension_structures.gd").new().build(builder,Vector2i(item.x,item.y),support_steps,feature_mesher.portal_sites) if builder._extras_enabled else []
					var structure_flow:Dictionary={}
					if structures.size()>2 and structures[2]!=null:
						structure_flow=preload("res://scripts/alien_tissue_coordinates.gd").structure_atlas(builder,structures[2],Vector2(item.x,item.y)*builder.chunk_size)
					var collision_data:Dictionary=_collision.prepare(arrays,item.w,item.z<=1,structures,features,index_structures)
					result.append({"key":Vector3i(item.x,item.y,item.z),"resolution":item.w,"arrays":arrays,"edge_profiles":edge_profiles,"swamp_water":builder.build_swamp_water(arrays,item.w),"extension_data":builder.built_extension_data,"extension_rows":builder.built_extension_rows,"alien_flow":builder.built_alien_tissue_flow,"alien_flow_rows":builder.built_alien_tissue_flow_rows,"structure_flow":structure_flow,"extension_mask":builder.built_extension_mask,"badlands_palette_slot":builder.built_badlands_palette_slot,"structures":structures,"features":features,"collision_data":collision_data,"begin":begin,"end":Time.get_ticks_usec()})
			)
			_jobs[key]=job
		if Time.get_ticks_usec()-started>=upload_budget_ms*1000.0: break
	_commit_partition()


func _collect_jobs() -> void:
	var started:=Time.get_ticks_usec()
	var installed:=0
	for key: Vector3i in _jobs.keys():
		var job: Dictionary=_jobs[key]
		if not WorkerThreadPool.is_task_completed(job.task): continue
		WorkerThreadPool.wait_for_task_completion(job.task)
		_idle_builders.append(job.builder);_jobs.erase(key)
		_ready_chunks.append_array(job.result)
	while not _ready_chunks.is_empty():
		var result: Dictionary=_ready_chunks.pop_front()
		var key: Vector3i=result.key
		_inflight.erase(key)
		if not _wanted.has(key): continue
		if result.resolution!=_tile_resolution(key):
			_pending_chunks.push_front(key);continue
		var commit_start:=Time.get_ticks_usec()
		var mesh:=ArrayMesh.new()
		var format_flags: int = Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		if result.arrays[Mesh.ARRAY_CUSTOM0].size()==result.arrays[Mesh.ARRAY_VERTEX].size()*4:
			format_flags=Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		if result.arrays[Mesh.ARRAY_CUSTOM1]!=null:format_flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
		if result.arrays[Mesh.ARRAY_CUSTOM2]!=null:format_flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT
		if result.arrays[Mesh.ARRAY_CUSTOM3]!=null:format_flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result.arrays,[],{},format_flags)
		mesh.set_meta("collision_data",result.collision_data)
		mesh.set_meta("edge_profiles",result.edge_profiles)
		if _cave_streamer!=null and key.z<=1:mesh.set_meta("terrain_cpu_arrays",result.arrays)
		var surface_end:int=Time.get_ticks_usec() if profile_streaming else 0
		var terrain_material:ShaderMaterial=_tile_material(key)
		var alien_flow_texture:ImageTexture=null
		if not result.extension_data.is_empty():
			terrain_material=terrain_material.duplicate() as ShaderMaterial
			var atlas_width:int=result.extension_data.size()/(result.extension_rows*4)
			var image:=Image.create_from_data(atlas_width,result.extension_rows,false,Image.FORMAT_RGBA8,result.extension_data)
			terrain_material.set_shader_parameter("extension_payload",ImageTexture.create_from_image(image));terrain_material.set_shader_parameter("extension_payload_enabled",true)
			terrain_material.set_shader_parameter("extension_active_mask",result.extension_mask)
		if result.badlands_palette_slot>=0:
			terrain_material.set_shader_parameter("badlands_palette_slot",result.badlands_palette_slot);terrain_material.set_shader_parameter("badlands_palette_enabled",true)
		if not result.alien_flow.is_empty():
			var flow_image:=Image.create_from_data(result.alien_flow_rows,result.alien_flow_rows,false,Image.FORMAT_RGBAF,result.alien_flow)
			alien_flow_texture=ImageTexture.create_from_image(flow_image)
			terrain_material.set_shader_parameter("alien_tissue_flow",alien_flow_texture);terrain_material.set_shader_parameter("alien_tissue_flow_enabled",true)
			terrain_material.set_shader_parameter("alien_tissue_flow_span",Vector2.ONE*chunk_size*float(1<<key.z))
			mesh.set_meta("alien_tissue_flow",alien_flow_texture)
		if not result.features.is_empty():
			if result.features.has("ground_collision"):mesh.set_meta("cavity_ground_faces",result.features.ground_collision)
			var openings:PackedVector4Array=result.features.openings
			if not openings.is_empty():
				if result.extension_data.is_empty():terrain_material=terrain_material.duplicate() as ShaderMaterial
				var data:=PackedFloat32Array()
				for p:Vector4 in openings:data.append_array(PackedFloat32Array([p.x,p.y,p.z,p.w]))
				var portal_image:=Image.create_from_data(openings.size(),1,false,Image.FORMAT_RGBAF,data.to_byte_array())
				terrain_material.set_shader_parameter("cavity_portals",ImageTexture.create_from_image(portal_image));terrain_material.set_shader_parameter("cavity_portal_count",openings.size());mesh.set_meta("cavity_portals",openings)
			var features:=ArrayMesh.new()
			for i in range(4):
				var a:Array=result.features.surfaces[i]
				if a.is_empty():continue
				features.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a);features.surface_set_material(features.get_surface_count()-1,_feature_materials[i])
			if features.get_surface_count()>0:mesh.set_meta("terrain_features",features)
		mesh.surface_set_material(0,terrain_material)
		if not result.structures.is_empty():
			var structures:=ArrayMesh.new()
			var structure_flow_texture:ImageTexture=null
			if not result.structure_flow.is_empty():
				var flow:Dictionary=result.structure_flow
				structure_flow_texture=ImageTexture.create_from_image(Image.create_from_data(flow.columns,flow.rows,false,Image.FORMAT_RGBAF,flow.data))
				structures.set_meta("alien_tissue_flow",structure_flow_texture);structures.set_meta("alien_tissue_flow_span",flow.span);structures.set_meta("alien_tissue_flow_offset",flow.offset)
			for i in range(3):
				if result.structures[i]==null:continue
				var structure_material:ShaderMaterial=_extension_materials[i]
				if i==2 and structure_flow_texture!=null:
					structure_material=structure_material.duplicate() as ShaderMaterial
					structure_material.set_shader_parameter("alien_tissue_flow",structure_flow_texture);structure_material.set_shader_parameter("alien_tissue_flow_enabled",true)
					structure_material.set_shader_parameter("alien_tissue_flow_span",result.structure_flow.span);structure_material.set_shader_parameter("alien_tissue_flow_offset",result.structure_flow.offset)
				structures.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result.structures[i]);structures.surface_set_material(structures.get_surface_count()-1,structure_material)
			if structures.get_surface_count()>0:mesh.set_meta("extension_structures",structures)
		if not result.swamp_water.is_empty():
			var water_mesh:=ArrayMesh.new();water_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result.swamp_water)
			water_mesh.surface_set_material(0,_swamp_water_material);mesh.set_meta("swamp_water_mesh",water_mesh)
		var resources_end:int=Time.get_ticks_usec() if profile_streaming else 0
		_stage_chunk(key,result.resolution,mesh)
		if profile_streaming:
			streaming_records.append({"lod":key.z,"resolution":result.resolution,"worker_ms":(result.end-result.begin)/1000.0,"queue_ms":(result.begin-_queued_at.get(key,result.begin))/1000.0,"commit_ms":(Time.get_ticks_usec()-commit_start)/1000.0,"surface_upload_ms":(surface_end-commit_start)/1000.0,"supplementary_resources_ms":(resources_end-surface_end)/1000.0,"node_and_collision_stage_ms":(Time.get_ticks_usec()-resources_end)/1000.0})
			if streaming_records.size()>4096: streaming_records.pop_front()
			streaming_records[-1]["collision_stage"]=_staged[key].get_meta("collision_stage_profile",{})
		_queued_at.erase(key)
		installed+=1
		if installed>=chunks_created_per_frame or Time.get_ticks_usec()-started>=upload_budget_ms*1000.0: break
	_commit_partition()


func _stage_chunk(key: Vector3i,resolution: int,mesh: ArrayMesh) -> void:
	var node: MeshInstance3D
	if _chunk_pool.is_empty():
		node=MeshInstance3D.new();node.visible=false;add_child(node)
	else: node=_chunk_pool.pop_back()
	var size: float=chunk_size*float(1<<key.z)
	node.position=Vector3(key.x*size,0,key.y*size)
	node.mesh=mesh;node.visible=false
	var feature_node:MeshInstance3D=node.get_node_or_null("TerrainFeatures")
	if mesh.has_meta("terrain_features"):
		if feature_node==null:feature_node=MeshInstance3D.new();feature_node.name="TerrainFeatures";node.add_child(feature_node)
		feature_node.mesh=mesh.get_meta("terrain_features");feature_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	elif feature_node!=null:feature_node.mesh=null
	var structure_node:MeshInstance3D=node.get_node_or_null("BiomeStructures")
	if mesh.has_meta("extension_structures"):
		if structure_node==null:structure_node=MeshInstance3D.new();structure_node.name="BiomeStructures";node.add_child(structure_node)
		structure_node.mesh=mesh.get_meta("extension_structures");structure_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if key.z<=1 and terrain_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elif structure_node!=null:structure_node.mesh=null
	var local_water:MeshInstance3D=node.get_node_or_null("SwampWater")
	if mesh.has_meta("swamp_water_mesh"):
		if local_water==null:
			local_water=MeshInstance3D.new();local_water.name="SwampWater";local_water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.add_child(local_water)
		local_water.mesh=mesh.get_meta("swamp_water_mesh")
	elif local_water!=null:local_water.mesh=null
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if terrain_shadows and key.z<=1 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("resolution",resolution);node.set_meta("tile",key)
	node.set_meta("published_usec",0)
	node.set_meta("edge_profiles",mesh.get_meta("edge_profiles",{}))
	node.set_meta("profile_collision",profile_streaming)
	_update_near_collision(node,true)
	_staged[key]=node
	_staging_revision+=1

func _update_near_collision(node:MeshInstance3D,force:bool=false,active_position:bool=false)->void:
	var key:Vector3i=node.get_meta("tile");var near_terrain:bool=terrain_collision_enabled and key.z<=1;var near_structures:bool=false
	var local_point:Vector3=Vector3.INF
	if is_instance_valid(target):local_point=(_teleport_destination if _teleport_pending and not active_position else target.global_position)-node.position
	if terrain_collision_enabled and node.mesh.has_meta("extension_structures") and is_instance_valid(target):
		var mesh:ArrayMesh=node.mesh.get_meta("extension_structures");var point:Vector3=local_point
		near_structures=mesh.get_aabb().grow(600).has_point(point)
	var state:=Vector2i(int(near_terrain),int(near_structures))
	if terrain_collision_enabled and node.mesh.has_meta("cavity_collision") and is_instance_valid(target):
		var cavity:ArrayMesh=node.mesh.get_meta("cavity_collision");var point:Vector3=local_point
		near_structures=near_structures or cavity.get_aabb().grow(600).has_point(point)
		state=Vector2i(int(near_terrain),int(near_structures))
	if terrain_collision_enabled and node.mesh.has_meta("collision_data") and is_instance_valid(target):
		var data:Dictionary=node.mesh.get_meta("collision_data")
		if not data.cavity_faces.is_empty():
			var point:Vector3=local_point
			near_structures=near_structures or data.cavity_bounds.grow(600).has_point(point)
			state=Vector2i(int(near_terrain),int(near_structures))
	if force or node.get_meta("collision_state",Vector2i(-1,-1))!=state:
		_collision.stage(node,chunk_size*float(1<<key.z),node.get_meta("resolution"),near_terrain,near_structures,local_point if spatial_structure_collision else Vector3.INF);node.set_meta("collision_state",state)
		if _active_chunks.get(key)==node:_collision.activate(node,terrain_collision_enabled)
	elif spatial_structure_collision and (near_terrain or near_structures):
		_collision.refresh_structure_subset(node,local_point)
	if _cave_streamer!=null:_cave_streamer.apply_parent(node)

func _release_node(node: MeshInstance3D) -> void:
	if _cave_streamer!=null:_cave_streamer.release_parent(node)
	_collision.release(node)
	var key: Vector3i=node.get_meta("tile")
	if cached_mesh_limit>0:
		_mesh_cache[Vector4i(key.x,key.y,key.z,int(node.get_meta("resolution")))]=node.mesh
		while _mesh_cache.size()>cached_mesh_limit: _mesh_cache.erase(_mesh_cache.keys()[0])
	node.visible=false;node.mesh=null
	var features:MeshInstance3D=node.get_node_or_null("TerrainFeatures")
	if features!=null:features.mesh=null
	var structures:MeshInstance3D=node.get_node_or_null("BiomeStructures")
	if structures!=null:structures.mesh=null
	var local_water:MeshInstance3D=node.get_node_or_null("SwampWater")
	if local_water!=null:local_water.mesh=null
	if _chunk_pool.size()<128: _chunk_pool.append(node)
	else: node.queue_free()


func _commit_partition() -> void:
	# Finished local groups may refine the old cut before distant jobs finish.
	# Every group is complete and balanced; teleports and final root-extent
	# changes still require the entire requested cut. No partial sibling split.
	if committed_revision==partition_revision: return
	_publish_startup_chunks()
	for key: Vector3i in _wanted:
		if _staged.has(key): continue
		if _active_chunks.has(key) and int(_active_chunks[key].get_meta("resolution"))==_tile_resolution(key): continue
		_commit_ready_region()
		return
	if _teleport_pending and _cave_streamer!=null and not _cave_streamer.position_ready(_teleport_destination):return
	if _cave_streamer!=null:
		var candidates:Array=[]
		for key:Vector3i in _wanted:candidates.append(_staged[key] if _staged.has(key) else _active_chunks[key])
		if not _cave_streamer.partition_ready(candidates):return
	var swap_start:=Time.get_ticks_usec()
	var next: Dictionary={}
	for key: Vector3i in _wanted:
		if _staged.has(key):
			next[key]=_staged[key];_staged.erase(key)
		else: next[key]=_active_chunks[key]
	for key: Vector3i in _active_chunks:
		if not next.has(key) or next[key]!=_active_chunks[key]: _release_node(_active_chunks[key])
	for node: MeshInstance3D in next.values():
		if not node.visible:node.set_meta("published_usec",Time.get_ticks_usec())
		node.visible=true;_update_near_collision(node);_collision.activate(node,terrain_collision_enabled)
	_active_chunks=next
	committed_revision=partition_revision
	_ready_edge_certificates.clear()
	_startup_coverage_complete=true
	if _cave_streamer!=null:_cave_streamer.partition_committed()
	if _teleport_pending:
		target.global_position=_teleport_destination
		_teleport_pending=false
		_update_water_position()
	if profile_streaming: max_partition_swap_ms=maxf(max_partition_swap_ms,(Time.get_ticks_usec()-swap_start)/1000.0)


func _commit_ready_region()->void:
	var frame:int=Engine.get_process_frames()
	if not _startup_coverage_complete or _teleport_pending or _staged.is_empty() or _last_incremental_attempt_frame==frame:return
	_last_incremental_attempt_frame=frame
	var cache_key:=Vector3i(partition_revision,_staging_revision,incremental_cut_swaps)
	if cache_key!=_ready_cut_cache_key:
		var active_resolutions:Dictionary={};var ready_resolutions:Dictionary={};var wanted_resolutions:Dictionary={};var active_profiles:Dictionary={};var ready_profiles:Dictionary={}
		for key:Vector3i in _active_chunks:active_resolutions[key]=int(_active_chunks[key].get_meta("resolution"));active_profiles[key]=_active_chunks[key].get_meta("edge_profiles",{})
		for key:Vector3i in _staged:ready_resolutions[key]=int(_staged[key].get_meta("resolution"));ready_profiles[key]=_staged[key].get_meta("edge_profiles",{})
		for key:Vector3i in _wanted:wanted_resolutions[key]=_tile_resolution(key)
		_ready_cut_cache=_ready_cut.choose(_active_chunks,_wanted,_staged,_partition,_last_plan_position,active_resolutions,ready_resolutions,wanted_resolutions,active_profiles,ready_profiles,_ready_cut_diagnostics)
		_ready_cut_cache_key=cache_key
	var change:Dictionary=_ready_cut_cache
	if change.is_empty():return
	var next:Dictionary=_active_chunks.duplicate()
	for key:Vector3i in change.remove:next.erase(key)
	for key:Vector3i in change.add:next[key]=_staged[key]
	if _cave_streamer!=null and not _cave_streamer.partition_ready(next.values()):return
	var began:int=Time.get_ticks_usec()
	for key:Vector3i in change.remove:_release_node(_active_chunks[key])
	for key:Vector3i in change.add:_staged.erase(key)
	_active_chunks=next
	for id:String in _ready_edge_certificates.keys():
		var old:Dictionary=_ready_edge_certificates[id]
		if not _active_chunks.has(old.a) or not _active_chunks.has(old.b) or _active_chunks[old.a].get_instance_id()!=old.a_instance or _active_chunks[old.b].get_instance_id()!=old.b_instance:_ready_edge_certificates.erase(id)
	for certificate:Dictionary in change.get("edge_certificates",[]):
		certificate=certificate.duplicate();certificate.a_instance=_active_chunks[certificate.a].get_instance_id();certificate.b_instance=_active_chunks[certificate.b].get_instance_id()
		_ready_edge_certificates[_ready_cut.edge_id(certificate.a,certificate.b)]=certificate
	for key:Vector3i in change.add:
		var node:MeshInstance3D=_active_chunks[key];node.set_meta("published_usec",Time.get_ticks_usec());node.visible=true
		_update_near_collision(node);_collision.activate(node,terrain_collision_enabled)
	if _cave_streamer!=null:_cave_streamer.partition_committed()
	_last_incremental_frame=Engine.get_process_frames();incremental_cut_swaps+=1
	if profile_streaming:max_partition_swap_ms=maxf(max_partition_swap_ms,(Time.get_ticks_usec()-began)/1000.0)

func is_active_edge_certified(a:Vector3i,b:Vector3i)->bool:
	if absi(a.z-b.z)<=1:return true
	var record:Dictionary=_ready_edge_certificates.get(_ready_cut.edge_id(a,b),{})
	return not record.is_empty() and _active_chunks.has(record.a) and _active_chunks.has(record.b) and _active_chunks[record.a].get_instance_id()==record.a_instance and _active_chunks[record.b].get_instance_id()==record.b_instance


func _publish_startup_chunks() -> void:
	# Before the first complete world exists, display completed final leaves
	# immediately. They are disjoint members of the requested cut; no temporary
	# coarse mesh or duplicate generation is needed. Later cut swaps remain atomic.
	if _startup_coverage_complete or _teleport_pending or _staged.is_empty():return
	var candidates:Array=_active_chunks.values()
	var publish:Array[Vector3i]=[]
	for key:Vector3i in _staged:
		if not _wanted.has(key) or _active_chunks.has(key):continue
		var overlaps:=false
		for active:Vector3i in _active_chunks:
			if _partition.bounds(key).intersects(_partition.bounds(active)) or (_partition.adjacent(key,active) and absi(key.z-active.z)>1):
				overlaps=true;break
		if overlaps:continue
		publish.append(key);candidates.append(_staged[key])
	if publish.is_empty():return
	# An already discovered entrance must retain its complete prepared patch.
	if _cave_streamer!=null and not _cave_streamer.partition_ready(candidates):return
	for key:Vector3i in publish:
		var node:MeshInstance3D=_staged[key];_staged.erase(key)
		node.set_meta("published_usec",Time.get_ticks_usec())
		_active_chunks[key]=node;node.visible=true
		_update_near_collision(node)
		_collision.activate(node,terrain_collision_enabled)
	if _cave_streamer!=null:_cave_streamer.partition_committed()


func get_partition_debug() -> String:
	var count: Array[int]=[]
	count.resize(maximum_lod+1)
	for key: Vector3i in _active_chunks: count[key.z]+=1
	var point:=Vector2(target.position.x,target.position.z) if target!=null else Vector2.ZERO
	var detail:="awaiting coverage"
	for key: Vector3i in _active_chunks:
		var rect: Rect2=_partition.bounds(key)
		if not rect.has_point(point): continue
		detail="active L%d (%d,%d) bounds %s parent %s children %d" % [key.z,key.x,key.y,str(rect),str(_partition.parent(key)),4 if key.z>0 else 0]
		break
	return "LOD counts %s | staging %d jobs %d | cut %d/%d\n%s" % [str(count),_staged.size(),_jobs.size(),committed_revision,partition_revision,detail]+("\n"+_cave_streamer.debug_text() if _cave_streamer!=null else "")


func _biome_weights(x: float, z: float) -> Vector4:
	return _sampler._biome_weights(x, z)


func _get_height(x: float, z: float) -> float:
	return _sampler._get_height(x, z)


func _get_biome(world_x: float, world_z: float) -> int:
	var weights := _biome_weights(world_x, world_z)
	var strongest := 0
	for i in range(1, 4):
		if weights[i] > weights[strongest]:
			strongest = i
	var best_weight:float=maxf(maxf(maxf(weights[strongest],_sampler._jungle_weight),maxf(_sampler._mountain_weight,_sampler._tropical_weight)),_sampler._badlands_weight)
	var extra_id:int=-1
	for i in range(8):
		if _sampler._extra_weights[i]>best_weight:best_weight=_sampler._extra_weights[i];extra_id=i
	if extra_id>=0:return extra_id+8
	if _sampler._badlands_weight>maxf(maxf(maxf(weights[strongest],_sampler._jungle_weight),_sampler._mountain_weight),_sampler._tropical_weight):return Biome.BADLANDS
	if _sampler._tropical_weight>maxf(maxf(weights[strongest],_sampler._jungle_weight),_sampler._mountain_weight):return Biome.TROPICAL
	if _sampler._mountain_weight>maxf(weights[strongest],_sampler._jungle_weight):return Biome.MOUNTAIN
	if _sampler._jungle_weight>weights[strongest]:return Biome.JUNGLE
	return strongest


## Deterministic world-space placement masks, not spawned vegetation. Main thread only.
func get_jungle_habitat_at(position:Vector3)->Dictionary:
	return preload("res://scripts/jungle_placement.gd").habitat(_sampler,position.x,position.z)


## Bounded search in the actual mixed world, not a pure-Jungle preview override.
func find_jungle_focus()->Vector3:
	if _settings_snapshot.jungle_coverage<=0:return Vector3(INF,INF,INF)
	var origin:Vector2=Vector2(target.global_position.x,target.global_position.z) if is_instance_valid(target) and target.is_inside_tree() else Vector2.ZERO
	var step:float=maxf(_settings_snapshot.jungle_region_size*_settings_snapshot.biome_size,500)
	for ring in range(28):
		var radius:float=0 if ring==0 else step*pow(1.55,ring-1)
		for index in range(12):
			var p:Vector2=origin+Vector2.from_angle(float(index)*TAU/12+.17)*radius
			_sampler._biome_weights(p.x,p.y)
			if _sampler._jungle_weight<.98:continue
			if _sampler._island_mask(p.x,p.y)<.025:continue
			var h:float=get_height_at(Vector3(p.x,0,p.y))
			if _sampler._last_coast.x>.35:continue
			if h>water_level+3:return Vector3(p.x,h,p.y)
	return Vector3(INF,INF,INF)


func jump_to_jungle()->bool:
	var focus:Vector3=find_jungle_focus()
	if not focus.is_finite():push_warning("No Jungle land found; enable Jungle Coverage in Terrain Settings.");return false
	request_teleport(focus+Vector3(0,80,0))
	return true


func find_forest_focus()->Vector3:
	if _settings_snapshot.forest_coverage<=0:return Vector3(INF,INF,INF)
	var origin:Vector2=Vector2(target.global_position.x,target.global_position.z) if is_instance_valid(target) and target.is_inside_tree() else Vector2.ZERO
	var step:float=maxf(_settings_snapshot.forest_region_size*_settings_snapshot.biome_size,500)
	for ring in range(28):
		var radius:float=0 if ring==0 else step*pow(1.55,ring-1)
		for index in range(12):
			var p:Vector2=origin+Vector2.from_angle(float(index)*TAU/12+.17)*radius
			var weights:Vector4=_sampler._biome_weights(p.x,p.y)
			if weights.y<.98:continue
			if _sampler._island_mask(p.x,p.y)<.025:continue
			var h:float=get_height_at(Vector3(p.x,0,p.y))
			if _sampler._last_coast.x>.35:continue
			if h>water_level+3:return Vector3(p.x,h,p.y)
	return Vector3(INF,INF,INF)


func jump_to_forest()->bool:
	var focus:Vector3=find_forest_focus()
	if not focus.is_finite():push_warning("No Forest land found; enable Forest Coverage in Terrain Settings.");return false
	request_teleport(focus+Vector3(0,80,0))
	return true


func find_savanna_focus()->Vector3:
	if _settings_snapshot.savanna_coverage<=0:return Vector3(INF,INF,INF)
	var origin:Vector2=Vector2(target.global_position.x,target.global_position.z) if is_instance_valid(target) and target.is_inside_tree() else Vector2.ZERO
	var step:float=maxf(_settings_snapshot.savanna_region_size*_settings_snapshot.biome_size,500)
	for ring in range(28):
		var radius:float=0 if ring==0 else step*pow(1.55,ring-1)
		for index in range(12):
			var p:Vector2=origin+Vector2.from_angle(float(index)*TAU/12+.17)*radius
			var weights:Vector4=_sampler._biome_weights(p.x,p.y)
			if weights.z<.98:continue
			if _sampler._island_mask(p.x,p.y)<.025:continue
			var h:float=get_height_at(Vector3(p.x,0,p.y))
			if _sampler._last_coast.x>.35:continue
			if h>water_level+3:return Vector3(p.x,h,p.y)
	return Vector3(INF,INF,INF)


func jump_to_savanna()->bool:
	var focus:Vector3=find_savanna_focus()
	if not focus.is_finite():push_warning("No Savanna land found; enable Savanna Coverage in Terrain Settings.");return false
	request_teleport(focus+Vector3(0,80,0))
	return true

func find_swamp_focus()->Vector3:
	if _settings_snapshot.swamp_coverage<=0:return Vector3(INF,INF,INF)
	var origin:Vector2=Vector2(target.global_position.x,target.global_position.z) if is_instance_valid(target) and target.is_inside_tree() else Vector2.ZERO
	var step:float=maxf(_settings_snapshot.swamp_region_size*_settings_snapshot.biome_size,500)
	for ring in range(28):
		var radius:float=0 if ring==0 else step*pow(1.55,ring-1)
		for index in range(12):
			var p:Vector2=origin+Vector2.from_angle(float(index)*TAU/12+.17)*radius
			var weights:Vector4=_sampler._biome_weights(p.x,p.y)
			if weights.w<.98:continue
			if _sampler._island_mask(p.x,p.y)<.025:continue
			var h:float=get_height_at(Vector3(p.x,0,p.y))
			if _sampler._last_coast.x>.35:continue
			var local_water:float=_sampler.get_water_surface_height(p.x,p.y)
			if h>local_water+.2:return Vector3(p.x,h,p.y)
	return Vector3(INF,INF,INF)


func jump_to_swamp()->bool:
	var focus:Vector3=find_swamp_focus()
	if not focus.is_finite():push_warning("No Swamp land found; enable Swamp Coverage in Terrain Settings.");return false
	request_teleport(focus+Vector3(0,45,0))
	return true

func find_mountain_focus()->Vector3:
	if _settings_snapshot.mountain_coverage<=0:return Vector3(INF,INF,INF)
	var origin:Vector2=Vector2(target.global_position.x,target.global_position.z) if is_instance_valid(target) and target.is_inside_tree() else Vector2.ZERO
	var step:float=maxf(_settings_snapshot.mountain_region_size*_settings_snapshot.biome_size,500)
	for ring in range(28):
		var radius:float=0 if ring==0 else step*pow(1.55,ring-1)
		for index in range(12):
			var p:Vector2=origin+Vector2.from_angle(float(index)*TAU/12+.17)*radius
			var weights:Vector4=_sampler._biome_weights(p.x,p.y)
			if _sampler._mountain_weight<.98:continue
			if _sampler._island_mask(p.x,p.y)<.025:continue
			var h:float=get_height_at(Vector3(p.x,0,p.y))
			if _sampler._last_coast.x>.35:continue
			var local_water:float=_sampler.get_water_surface_height(p.x,p.y)
			if h>local_water+.2:return Vector3(p.x,h,p.y)
	return Vector3(INF,INF,INF)


func find_badlands_focus()->Vector3:
	if _settings_snapshot.badlands_coverage<=0:return Vector3(INF,INF,INF)
	var origin:Vector2=Vector2(target.global_position.x,target.global_position.z) if is_instance_valid(target) and target.is_inside_tree() else Vector2.ZERO
	var step:float=maxf(_settings_snapshot.badlands_region_size*_settings_snapshot.biome_size,500)
	for ring in range(28):
		var radius:float=0 if ring==0 else step*pow(1.55,ring-1)
		for index in range(12):
			var p:Vector2=origin+Vector2.from_angle(float(index)*TAU/12+.17)*radius
			_sampler._biome_weights(p.x,p.y)
			if _sampler._badlands_weight<.98 or _sampler._island_mask(p.x,p.y)<.025:continue
			var h:float=get_height_at(Vector3(p.x,0,p.y))
			if _sampler._last_coast.x>.35:continue
			if h>_sampler.get_water_surface_height(p.x,p.y)+.2:return Vector3(p.x,h,p.y)
	return Vector3(INF,INF,INF)
func jump_to_badlands()->bool:
	var focus:Vector3=find_badlands_focus()
	if not focus.is_finite():push_warning("No Badlands land found; enable Badlands Coverage in Terrain Settings.");return false
	request_teleport(focus+Vector3(0,100,0));return true

func find_tropical_focus()->Vector3:
	if _settings_snapshot.tropical_coverage<=0:return Vector3(INF,INF,INF)
	var origin:Vector2=Vector2(target.global_position.x,target.global_position.z) if is_instance_valid(target) and target.is_inside_tree() else Vector2.ZERO
	var step:float=maxf(_settings_snapshot.tropical_region_size*_settings_snapshot.biome_size,500)
	for ring in range(28):
		var radius:float=0 if ring==0 else step*pow(1.55,ring-1)
		for index in range(12):
			var p:Vector2=origin+Vector2.from_angle(float(index)*TAU/12+.17)*radius
			_sampler._biome_weights(p.x,p.y)
			if _sampler._tropical_weight<.98 or _sampler._island_mask(p.x,p.y)<.025:continue
			var h:float=get_height_at(Vector3(p.x,0,p.y))
			if _sampler._last_coast.x>.35:continue
			if h>_sampler.get_water_surface_height(p.x,p.y)+.2:return Vector3(p.x,h,p.y)
	return Vector3(INF,INF,INF)

func jump_to_tropical()->bool:
	var focus:Vector3=find_tropical_focus()
	if not focus.is_finite():push_warning("No Tropical land found; enable Tropical Coverage in Terrain Settings.");return false
	request_teleport(focus+Vector3(0,100,0));return true

func jump_to_mountain()->bool:
	var focus:Vector3=find_mountain_focus()
	if not focus.is_finite():push_warning("No Mountain Range land found; enable Mountain Range Coverage in Terrain Settings.");return false
	request_teleport(focus+Vector3(0,140,0))
	return true


## Bounded first-order projection onto the actual island boundary.
func find_coast_focus(sandy:bool=false)->Vector3:
	if not _settings_snapshot.rocky_coast_enabled and not _settings_snapshot.beaches_enabled:return Vector3(INF,INF,INF)
	var origin:Vector2=Vector2(target.global_position.x,target.global_position.z) if is_instance_valid(target) and target.is_inside_tree() else Vector2.ZERO
	var radius:float=maxf(_settings_snapshot.island_size*.5,1000)
	for ring in range(12):
		for index in range(16):
			var p:Vector2=origin+Vector2.from_angle(float(index)*TAU/16+.17)*radius*float(ring)/3
			for iteration in range(24):
				var frame:Vector3=_sampler._coast.coast_frame(p);p-=Vector2(frame.y,frame.z)*clampf(frame.x*.25,-radius*.25,radius*.25)
			var frame:Vector3=_sampler._coast.coast_frame(p);p+=Vector2(frame.y,frame.z)*80
			var h:float=_get_height(p.x,p.y)
			var sand:float=float(int(-_sampler._last_coast.w-1)&255)/255 if _sampler._last_coast.w<0 else 0
			if _sampler._last_coast.x>.75 and h>water_level+.5 and (sand>.7 if sandy else sand<.3):return Vector3(p.x,h,p.y)
	return Vector3(INF,INF,INF)

func jump_to_coast()->bool:
	var focus:Vector3=find_coast_focus()
	if not focus.is_finite():push_warning("No Rocky Coast found; enable Rocky Coast and coverage.");return false
	request_teleport(focus+Vector3(0,150,0));return true

func jump_to_beach()->bool:
	var focus:Vector3=find_coast_focus(true)
	if not focus.is_finite():push_warning("No sandy coast found; enable Beaches and coverage.");return false
	request_teleport(focus+Vector3(0,100,0));return true

## Runtime flood-stage appearance uses existing canonical surface buffers, no rebuild.
func set_swamp_flood_stage(stage:float)->void:
	stage=clampf(stage,0,1)
	for material:ShaderMaterial in _material_variants():material.set_shader_parameter("swamp_flood_stage",stage)
	if _swamp_water_material!=null:_swamp_water_material.set_shader_parameter("swamp_flood_stage",stage)

## Optional small query. Future vegetation workers should call JunglePlacement
## directly with their own builder, not this main-thread convenience wrapper.
func get_jungle_spawn_candidates(bounds:Rect2,spacing:float=24,max_candidates:int=128,scan_offset:int=0)->Dictionary:
	return preload("res://scripts/jungle_placement.gd").candidates(_sampler,bounds,spacing,max_candidates,scan_offset)


func _create_water() -> void:
	if not _settings_snapshot.water_enabled:
		return
	_water = MeshInstance3D.new()
	_water.name = "InfiniteWater"
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := PlaneMesh.new()
	var water_span := chunk_size * float(1<<maximum_lod) * 5.0
	plane.size = Vector2(water_span, water_span)
	plane.subdivide_width = 96
	plane.subdivide_depth = 96
	var water_material := ShaderMaterial.new()
	water_material.shader = preload("res://shaders/ocean.gdshader")
	if _settings_snapshot.rocky_coast_enabled or _settings_snapshot.beaches_enabled:water_material.shader=preload("res://shaders/coastal_ocean.gdshader")
	for parameter in ["wave_height", "wave_speed", "water_roughness", "shallow_color", "deep_color"]:
		water_material.set_shader_parameter(parameter, _settings_snapshot.get(parameter))
	plane.material = water_material
	_water.mesh = plane
	add_child(_water)


func _update_water_position() -> void:
	if _water == null or _teleport_pending:
		return
	_water.position = Vector3(
		(_target_chunk.x + 0.5) * chunk_size,
		water_level,
		(_target_chunk.y + 0.5) * chunk_size
	)


func find_extension_focus(biome:String)->Vector3:
	var index:int=TerrainSettings.EXTENSION_KEYS.find(biome)
	if index<0 or _sampler._extras[index]==null:return Vector3(INF,INF,INF)
	var span:float=_settings_snapshot.get(biome+"_region_size")*_settings_snapshot.biome_size
	for ring in range(1,45):
		for direction:Vector2 in [Vector2(1,.37),Vector2(-.51,1),Vector2(-1,-.61),Vector2(.29,-1)]:
			var p:Vector2=direction*span*ring;_sampler._biome_weights(p.x,p.y)
			if _sampler._extra_weights[index]>.98 and _sampler._island_mask(p.x,p.y)>.03:return Vector3(p.x,_get_height(p.x,p.y),p.y)
	return Vector3(INF,INF,INF)

func jump_to_extension(biome:String)->bool:
	var focus:Vector3=find_extension_focus(biome)
	if not focus.is_finite():return false
	request_teleport(focus+Vector3(0,500,0));return true

func get_extension_descriptor_at(position:Vector3,biome:String)->Dictionary:
	var i:int=TerrainSettings.EXTENSION_KEYS.find(biome)
	if i<0 or _sampler._extras[i]==null:return {}
	return _sampler._extras[i].describe(Vector2(position.x,position.z))
