extends "res://tools/caves/check_frozen_features.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Heat=preload("res://scripts/caves/magma_heat.gd")
const Magma=preload("res://scripts/caves/magma_features.gd")
const Checkpoint:String="res://tools/biome_extensions/artifacts/revisions/experiment_cave_crystal_registered_checkpoint_3c7ec7dc5c1e/sources/"
class DiagnosticHeat extends RefCounted:
	var enabled:bool=true
	func sample(point:Vector3)->Dictionary:return {"heat":1.0 if enabled else 0.0,"id":"explicit_intrusion_mechanism_fixture","surface_witness":Vector3(point.x,200,point.z)}
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://config/caves/biomes/magma_cave_definition.tres","res://shaders/cave_magma_molten.gdshader",Checkpoint+"scripts/caves/workload.gd.txt",Checkpoint+"scripts/caves/frozen_features.gd.txt"]:guards[path]=FileAccess.get_sha256(path)
	var old_script:=GDScript.new();old_script.source_code=FileAccess.get_file_as_string(Checkpoint+"scripts/caves/workload.gd.txt");check(old_script.reload()==OK,"Independent immutable pre-Magma workload loads")
	var settings:Resource=load("res://config/world/terrain_settings.tres");var config:Resource=load("res://config/caves/cave_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);var baseline=old_script.new();var current=Workload.new()
	# Preserve this test's original three-definition baseline after saved
	# registration. Four-definition registration has its own positive proof.
	for index in range(config.biome_regions.definitions.size()-1,-1,-1):
		if config.biome_regions.definitions[index].biome_id==&"magma":config.biome_regions.definitions.remove_at(index)
	check(baseline.configure(settings,config,73921,0) and current.configure(settings,config,73921,0) and current._magma_heat==null,"Current registered three-biome configuration allocates no Magma heat context")
	var site:=Vector2i(6,-2);var original:Dictionary=baseline.network.region(site);var cold:Dictionary=current.network.region(site);check(var_to_bytes(original)==var_to_bytes(cold),"Entire fixed original region/Crystal/Frozen payload exact against independent pre-Magma workload")
	var off_cases:Array=[]
	for mode:String in ["disabled","zero_spawn"]:
		var modified:Resource=config.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);var definition:Resource=load("res://config/caves/biomes/magma_cave_definition.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		if mode=="disabled":definition.enabled=false
		else:definition.spawn_chance_percent=0.0
		modified.biome_regions.definitions.append(definition);var worker=Workload.new();check(worker.configure(settings,modified,73921,0) and worker._magma_heat==null,"Independent "+mode+" context is absent")
		check(var_to_bytes(worker.network.region(site))==var_to_bytes(cold),"Independent "+mode+" complete region exact");off_cases.append(mode)
	var hot_config:Resource=config.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);hot_config.biome_regions.definitions.append(load("res://config/caves/biomes/magma_cave_definition.tres"));var hot_worker=Workload.new();check(hot_worker.configure(settings,hot_config,73921,0) and hot_worker._magma_heat!=null,"Enabled normal Magma owns one bounded heat context in existing worker")
	var volcanic=make_builder(2);var heat=Heat.new();heat.configure(volcanic);var actual:Dictionary=heat.sample(Vector3(241955,290,-97306.7));check(actual.heat>.5 and actual.id=="2:33:-14","Original normal retained Volcanic source remains positive")
	var room:Dictionary={"id":"source_room","level":0,"point":Vector3(241955,285,-97306.7),"chamber_radius":20.0,"chamber_height":32.0};var region:Dictionary={"id":Vector2i.ZERO,"valid":true,"nodes":[room],"edges":[]};var annotated:Dictionary=heat.annotate_region(region);check(annotated.get("cave_thermal_sources",[]).size()==1 and not region.has("cave_thermal_sources"),"Actual source adds immutable localized room witness")
	var native=Field.new();native.include_surface_air=false;var height:Callable=volcanic._get_height;check(native.compile([annotated],height) and native.heat_at(room.point+Vector3.UP)>0,"Actual canonical source compiles into same localized numeric field")
	var diagnostic=DiagnosticHeat.new();var magma=Magma.new();var pool_region:Dictionary=fixture();pool_region.cave_biome_regions.candidates[0].biome_id="magma";pool_region.cave_biome_regions.candidates[0].id="A/magma";var feature_settings:Dictionary=load("res://config/caves/biomes/magma_cave_definition.tres").feature_configuration.duplicate();feature_settings.chamber_growth=false;feature_settings.active_pool_chance=1.0;var flat:Callable=func(_x:float,_z:float)->float:return 200.0
	var molten:Dictionary=magma.decorate_region_with_context(pool_region,flat,73921,feature_settings,400,10,diagnostic);check(molten.pools[0].get("fluid_kind","")=="magma" and not pool_region.pools[0].has("fluid_kind"),"Controlled witnessed intrusion converts retained basin without new carving or mutating input")
	diagnostic.enabled=false;check(var_to_bytes(magma.decorate_region_with_context(pool_region,flat,73921,feature_settings,400,10,diagnostic))==var_to_bytes(pool_region),"Source OFF restores entire original freshwater geography")
	var magma_field=Field.new();magma_field.include_surface_air=false;check(magma_field.compile([molten],flat,[],molten.cave_biome_regions),"Same bed compiles with explicit molten identity")
	var water:Dictionary=Basins.water_cell([molten],magma_field,Vector3i.ZERO);var lava:Dictionary=Basins.water_cell([molten],magma_field,Vector3i.ZERO,"magma");check(water.arrays.is_empty() and not lava.arrays.is_empty() and lava.ids==[molten.pools[0].id],"Molten surfaces never leak through freshwater renderer")
	var built:Dictionary=magma.build(magma_field,Vector3i.ZERO,73921,[molten],feature_settings,water);check(built.batches.any(func(batch:Dictionary)->bool:return batch.kind=="molten_volcanic" and batch.collision_faces.is_empty()),"Molten batch uses dedicated material and no invented walkable lava collider")
	var dry:Dictionary=pool_region.duplicate(true);dry.erase("pools");dry.geology=1;diagnostic.enabled=true;var dry_basins:int=0
	check(Basins.make(dry,73921,1.0).is_empty(),"Original groundwater policy keeps nonsoluble geology dry")
	for seed_id in range(32):
		var intrusive:Dictionary=magma.decorate_region_with_context(dry,flat,seed_id,feature_settings,400,10,diagnostic)
		for pool:Dictionary in intrusive.get("pools",[]):
			check(pool.get("fluid_kind","")=="magma" and pool.get("construction","")=="source_backed_magmatic_side_basin" and Basins.route_clear(pool.center,pool.radius,pool.bed_y,pool.water_y,dry),"Explicit hot magmatic basin reuses side-depression geometry without groundwater-geology shortcut or protected-route overlap");dry_basins+=1
	check(dry_basins>0,"Fixed32seed ensemble produces actual source-backed basins in otherwise dry intrusive rock")
	diagnostic.enabled=false;check(var_to_bytes(magma.decorate_region_with_context(dry,flat,73921,feature_settings,400,10,diagnostic))==var_to_bytes(dry),"No source restores entire original dry nonsoluble geography without invented water pools")
	var old_frozen:=GDScript.new();old_frozen.source_code=FileAccess.get_file_as_string(Checkpoint+"scripts/caves/frozen_features.gd.txt");check(old_frozen.reload()==OK,"Independent immutable pre-Magma Frozen provider loads")
	var ice_region:Dictionary=fixture();var ice_field=Field.new();ice_field.include_surface_air=false;check(ice_field.compile([ice_region],flat,[],ice_region.cave_biome_regions),"Original cold Frozen fixture compiles")
	var lake:Dictionary=Basins.water_cell([ice_region],ice_field,Vector3i.ZERO);var frozen_settings:Dictionary=load("res://config/caves/biomes/frozen_cave_definition.tres").feature_configuration
	for seed_id:int in [17,73921,92881]:check(var_to_bytes(old_frozen.new().build(ice_field,Vector3i.ZERO,seed_id,[ice_region],frozen_settings,lake))==var_to_bytes(Features.new().build(ice_field,Vector3i.ZERO,seed_id,[ice_region],frozen_settings,lake)),"Entire original ice arrays/placements/LOD/collision byte-exact with empty thermal field "+str(seed_id))
	var thermal:Dictionary=ice_region.duplicate(true);thermal["cave_thermal_sources"]=[{"id":"controlled_full_chamber_heat","point":Vector3(32,18,32),"radius":80.0,"height":60.0,"heat":1.0}];var ice_hot=Field.new();ice_hot.include_surface_air=false;check(ice_hot.compile([thermal],flat,[],thermal.cave_biome_regions),"Controlled hot Frozen overlap compiles")
	check(Features.new().build(ice_hot,Vector3i.ZERO,73921,[thermal],frozen_settings,lake).placements.is_empty(),"Whole hot chamber admits no Frozen formations or frozen water")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable integration source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_integration.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"off_cases":off_cases,"actual_source":actual,"molten_vertices":lava.arrays[Mesh.ARRAY_VERTEX].size() if not lava.arrays.is_empty() else 0,"scope":"One original region whole-payload old/three-biome/disabled/zero-spawn compatibility;actual normal retained source to room/compiled thermal field;controlled explicit intrusion basin conversion/dedicated molten payload;three entire cold Frozen payloads exact and hot exclusions. Not yet native normal molten-cave rendering or full Magma traversal."},"  "));print("MAGMA_INTEGRATION ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
