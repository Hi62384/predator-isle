extends SceneTree
## Godot 4.6 duplicate(true) retains external resource references. Immutable
## worker and test snapshots must explicitly include those biome resources.
const NESTED=["forest","savanna","swamp","rocky_coast","beach","mountain","tropical","badlands","quarry","wise_mountains","volcanic","spore_forest","radiation_wasteland","crystal_wastes","insect_colony","alien_infected"]
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var source:TerrainSettings=load("res://config/world/terrain_settings.tres")
	var before_hash:String=FileAccess.get_sha256("res://config/world/terrain_settings.tres")
	var a:TerrainSettings=source.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	var b:TerrainSettings=source.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	check(a!=source and b!=source and a!=b,"Independent root resources")
	for key:String in NESTED:
		var original:Resource=source.get(key);var first:Resource=a.get(key);var second:Resource=b.get(key)
		check(original!=first and original!=second and first!=second,"Independent external biome configuration: "+key)
		for property:Dictionary in original.get_property_list():
			if (int(property.usage)&PROPERTY_USAGE_STORAGE)==0 or property.name=="script":continue
			check(first.get(property.name)==original.get(property.name) and second.get(property.name)==original.get(property.name),"Snapshot value preserved: "+key+"/"+property.name)
	var old_gullies:float=source.badlands.secondary_gullies;var old_caves:float=source.wise_mountains.cave_frequency
	a.badlands.secondary_gullies=0;a.wise_mountains.cave_frequency=.99
	check(source.badlands.secondary_gullies==old_gullies and b.badlands.secondary_gullies==old_gullies,"A/B gullies cannot leak across snapshots")
	check(source.wise_mountains.cave_frequency==old_caves and b.wise_mountains.cave_frequency==old_caves,"Preview cave overrides cannot mutate saved defaults")
	var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain")
	scene.get_node("FreeCamera").set_script(null);terrain.badlands_preview=true;terrain.badlands_preview_feature="major_dry_wash"
	root.add_child(scene);scene.get_node("Interface").hide()
	var worker_ids:Dictionary={};var deadline:int=Time.get_ticks_msec()+30000
	while worker_ids.size()<terrain.worker_count and Time.get_ticks_msec()<deadline:
		await process_frame
		for job:Dictionary in terrain._jobs.values():worker_ids[job.builder.get_instance_id()]=job.builder
		for builder in terrain._idle_builders:worker_ids[builder.get_instance_id()]=builder
	check(worker_ids.size()>0,"Actual production worker builders observed")
	check(terrain._settings_snapshot!=source,"Production scene has its own root snapshot")
	for key:String in NESTED:
		var snapshot:Resource=terrain._settings_snapshot.get(key);var owners:Dictionary={}
		check(snapshot!=source.get(key),"Production scene owns external setting: "+key)
		for builder in worker_ids.values():
			var config:Resource=builder.settings.get(key)
			check(config!=snapshot and config!=source.get(key) and not owners.has(config.get_instance_id()),"Worker-private setting: "+key)
			owners[config.get_instance_id()]=true
	check(source.badlands.secondary_gullies==old_gullies and source.wise_mountains.cave_frequency==old_caves,"Production preview leaves original resources unchanged")
	check(FileAccess.get_sha256("res://config/world/terrain_settings.tres")==before_hash,"Saved terrain preset file remains unchanged")
	var report:Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty(),"production_workers_observed":worker_ids.size(),"nested_resources_per_snapshot":NESTED.size(),"mode":"duplicate_deep(Resource.DEEP_DUPLICATE_ALL)","documentation":"https://docs.godotengine.org/en/4.6/classes/class_resource.html#class-resource-method-duplicate-deep","source_sha256":{"res://scripts/chunk_terrain.gd":FileAccess.get_sha256("res://scripts/chunk_terrain.gd"),"res://scripts/terrain_settings.gd":FileAccess.get_sha256("res://scripts/terrain_settings.gd")}}
	FileAccess.open("res://data/terrain_settings_ownership_20261018.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("TERRAIN_SETTINGS_OWNERSHIP ",report)
	scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
