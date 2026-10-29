extends "res://tools/caves/check_frozen_world_cohort.gd"
func run()->void:
	var guards:Dictionary=FrozenFixture.guards()
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://config/caves/cave_biome_regions.tres","res://config/caves/cave_settings.tres","res://config/caves/biomes/magma_cave_definition.tres","res://config/caves/biomes/default_cave_definition.tres","res://config/caves/biomes/frozen_cave_definition.tres","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var config=Config.new();var saved:Resource=load("res://config/caves/cave_settings.tres");var ids:Array=[]
	for definition:Resource in config.biome_regions.definitions:ids.append(str(definition.biome_id))
	check(ids==["default","frozen","crystal","magma"] and config.validation_errors().is_empty() and saved.validation_errors().is_empty(),"Actual saved registry loads all four requested cave definitions and native providers")
	var magma:Resource=config.biome_regions.definitions[-1]
	check(magma.spawn_chance_percent==22 and magma.minimum_extent_metres==300 and magma.maximum_extent_metres==1100 and magma.depth_preferences==PackedFloat32Array([0,5,30,80,100]),"Exact requested independent Magma probability,extent and depth controls")
	check(magma.surface_preferences=={"volcanic":100.0,"mountain":35.0,"badlands":20.0,"quarry":15.0,"radiation_wasteland":15.0,"desert":10.0,"rocky_coast":5.0},"All seven requested surface affinities retained")
	check(magma.feature_configuration.cooled_deposits and magma.feature_configuration.cooled_intrusions and magma.feature_configuration.chamber_variety and magma.feature_configuration.large_lake_chance==.08 and magma.feature_configuration.active_pool_chance==.14,"Enabled physical volcanic geology and unchanged normal rare molten probabilities")
	check(saved.enabled and not config.enabled,"Saved game enables caves;new independent configuration retains explicit opt-in default")
	var roundtrip_path:String="res://.godot/magma_registered_roundtrip.tres";check(ResourceSaver.save(config.biome_regions,roundtrip_path)==OK,"Actual four-biome Resource saves")
	var restored:Resource=ResourceLoader.load(roundtrip_path,"",ResourceLoader.CACHE_MODE_IGNORE)
	check(restored!=null and restored.validation_errors().is_empty() and restored.definitions.size()==4 and restored.definitions[-1].feature_provider.resource_path=="res://scripts/caves/magma_features.gd" and restored.definitions[-1].surface_provider.resource_path=="res://scripts/caves/magma_surface.gd","Complete native provider/configuration roundtrip")
	var previous=Config.new();previous.biome_regions=previous.biome_regions.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);previous.biome_regions.definitions.remove_at(3)
	var cases:Array=[]
	for row:Array in [["spore_forest",73921,Vector2i(9,-3)],["crystal_wastes",73921,Vector2i(6,-2)]]:
		var builder=owner(row[0],row[1]);var old=Workload.new();var current=Workload.new();check(old.configure(builder.settings,previous,row[1],0) and current.configure(builder.settings,config,row[1],0),"Actual previous-three and saved-four provider workers configure")
		var a:Dictionary=old.discover(row[2]);var b:Dictionary=current.discover(row[2]);check(var_to_bytes(a)==var_to_bytes(b),"Full earlier-biome descriptor/connection/entrance geography exact where Magma affinity is zero")
		var region:Dictionary={}
		for candidate:Dictionary in b.regions:
			if candidate.id==row[2]:region=candidate;break
		var key:Vector3i=current.field.cell(region.nodes[1].point+Vector3.UP*2);var before:Dictionary=old.build_cell(key);var after:Dictionary=current.build_cell(key)
		check(after.valid and not after.arrays.is_empty() and var_to_bytes(before)==var_to_bytes(after),"Entire actual earlier-biome mesh/normals/UV/water/features/collision/frontier payload exact")
		cases.append({"host":row[0],"seed":row[1],"site":str(row[2]),"key":str(key),"vertices":after.arrays[Mesh.ARRAY_VERTEX].size()})
	var builder=owner("volcanic",17);var actual=Workload.new();check(actual.configure(builder.settings,config,17,0),"Actual saved Magma worker configures")
	var region:Dictionary=actual.network.region(Vector2i(-73,138));var pool:Dictionary={}
	for candidate:Dictionary in region.get("pools",[]):
		if str(candidate.id)=="-73:138:2:0:lobe:1:seepage":pool=candidate;break
	check(not pool.is_empty() and pool.get("fluid_kind","")=="magma","Same first normal source-backed molten pool survives actual saved registration")
	check(actual.use_bundle({"cell":region.id,"regions":[region],"connections":[]}),"Actual source-backed registered field compiles")
	var key:Vector3i=actual.field.cell(Vector3(pool.center.x,pool.water_y,pool.center.z));var payload:Dictionary=actual.build_cell(key);var molten_vertices:int=0
	for batch:Dictionary in payload.get("features",[]):
		if batch.biome_id=="magma" and batch.kind=="molten_volcanic":molten_vertices+=batch.arrays[Mesh.ARRAY_VERTEX].size()
	check(payload.valid and molten_vertices>0,"Positive actual registered retained molten shader geometry,not metadata-only registration")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable saved registration source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_registration.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"registered_ids":ids,"earlier_biome_cases":cases,"registered_molten_vertices":molten_vertices,"root_enabled":saved.enabled,"scope":"Actual four-biome editable native registry/providers/control roundtrip;full previous-three zero-affinity descriptor/payload parity at original Spore and Crystal sites;actual first normal source-backed Magma geometry positive. Root activation/global art/startup/FPS remain open;historical component archives not rebound."},"  "));print("MAGMA_REGISTRATION ",checks," vertices=",molten_vertices," failures=",failures);quit(0 if failures.is_empty() else 1)
