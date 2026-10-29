extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var rows:Array=[]
	for coordinate:Vector2i in [Vector2i(-1,1),Vector2i(1,-1),Vector2i(1,1)]:
		var b=load("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		for key:String in ["badlands"]+TerrainSettings.EXTENSION_KEYS:b.settings.set(key+"_coverage",12.0)
		b.profile_build=true;b._configure_noise();b.chunk_size=16384
		var started:int=Time.get_ticks_usec();var arrays:Array=b.build(coordinate,128);var surface_end:int=Time.get_ticks_usec()
		var mesher=load("res://scripts/terrain_feature_meshes.gd").new();var features:Dictionary=mesher.build(b,coordinate);var feature_end:int=Time.get_ticks_usec()
		var support:PackedFloat64Array=load("res://scripts/biome_extension_structures.gd").support_grids(256,128,16,6)
		var structures:Array=load("res://scripts/lod_biome_extension_structures.gd").new().build(b,coordinate,support,mesher.portal_sites);var structure_end:int=Time.get_ticks_usec()
		var flow:Dictionary={}
		if structures.size()>2 and structures[2]!=null:flow=load("res://scripts/alien_tissue_coordinates.gd").structure_atlas(b,structures[2],Vector2(coordinate)*b.chunk_size)
		var flow_end:int=Time.get_ticks_usec();var collision:Dictionary=load("res://scripts/terrain_collision.gd").prepare(arrays,128,false,structures,features,true)
		var row:Dictionary={"coordinate":str(coordinate),"surface_ms":(surface_end-started)/1000.0,"surface_stages":b.last_build_profile,"features_ms":(feature_end-surface_end)/1000.0,"structures_ms":(structure_end-feature_end)/1000.0,"flow_ms":(flow_end-structure_end)/1000.0,"collision_ms":(Time.get_ticks_usec()-flow_end)/1000.0,"extension_mask":b.built_extension_mask,"vertices":arrays[Mesh.ARRAY_VERTEX].size(),"flow_maps":flow.size(),"collision_valid":not collision.is_empty()}
		rows.append(row);print("ALL_OWNER_WORKER_PROFILE ",row)
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_all_owner_workers.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":rows,"scope":"Instrumented cold workers at actual LOD6 dimensions and full128 grid;all owner coverages12. CPU phase diagnosis only,not a timing improvement or live rendering pass."},"  "));quit()
