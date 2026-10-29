extends "res://tools/biome_extensions/check_shader_variant_payloads.gd"
## Every legacy/coastal configured-mask subset,not just selected owner sets.
func run()->void:
	var sources:Dictionary={};var started:int=Time.get_ticks_usec();var nonzero:PackedInt32Array=PackedInt32Array([0,0,0,0,0,0,0,0])
	var inventory=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"))
	# Snapshot current bytes from the known inventory,not the old report's
	# success/hash values. This test does not stand in for refreshing that suite.
	for relative:String in inventory.source_sha256:
		var path:String="res://"+relative.replace("\\","/");sources[path]=FileAccess.get_sha256(path)
	for path:String in ["res://tools/biome_extensions/check_legacy_owner_matrix.gd","res://tools/biome_extensions/check_shader_variant_payloads.gd"]:sources[path]=FileAccess.get_sha256(path)
	for seed_id:int in [73921,17,92881]:
		var discovery=preload("res://scripts/terrain_mesh_builder.gd").new();discovery.world_seed=seed_id;discovery.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);discovery.settings.island_size=100400;discovery.settings.island_spacing=585;discovery._configure_noise()
		var cells:Array[Vector2i]=[]
		for i in range(1200):
			var point:=Vector2(i*7919%120000-60000,i*11939%120000-60000)
			if discovery._island_mask(point.x,point.y)<.2:continue
			var cell:=Vector2i(floori(point.x/256),floori(point.y/256))
			if not cells.has(cell):cells.append(cell)
			if cells.size()==3:break
		verify(cells.size()==3)
		for legacy in range(128):
			for coastal:bool in [false,true]:
				var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.world_seed=seed_id;b.settings=discovery.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
				for owner:String in ["grass"]+Variants.LEGACY+TerrainSettings.EXTENSION_KEYS:b.settings.set(owner+"_coverage",0)
				for bit in range(7):b.settings.set(Variants.LEGACY[bit]+"_coverage",20 if (legacy & (1<<bit))!=0 else 0)
				b.settings.beaches_enabled=coastal;b.settings.rocky_coast_enabled=coastal;b.settings.biome_size=.2;b._configure_noise()
				var mask:int=Variants.configured_mask(b.settings);verify(mask==legacy+(128 if coastal else 0));var vertices:int=0
				for cell:Vector2i in cells:
					var arrays:Array=b.build(cell,8);verify(b.built_extension_mask==0)
					for index in range(arrays[Mesh.ARRAY_VERTEX].size()):
						var weights:PackedFloat32Array=decoded_weights(arrays,index)
						for owner in range(8):
							if (mask & (1<<owner))==0:verify(weights[owner]==0)
							elif weights[owner]>0:nonzero[owner]+=1
						vertices+=1
				cases.append({"seed":seed_id,"mask":mask,"tiles":cells,"decoded_vertices_including_skirts":vertices})
	for owner in range(7):verify(nonzero[owner]>0)
	for path:String in sources:verify(FileAccess.get_sha256(path)==sources[path])
	FileAccess.open("res://tools/biome_extensions/artifacts/check_legacy_owner_matrix.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"assertions":checks,"source_sha256":sources,"cases":cases,"legacy_mask_subsets":128,"coastal_modes":2,"seeds":3,"real_meshes":2304,"enabled_owner_nonzero_vertices":nonzero,"seconds":(Time.get_ticks_usec()-started)/1000000.0,"production_registration":false,"scope":"All128 legacy-owner subsets with coasts on/off,three seeds,three fixed discovered inland tiles per seed:2304 actual packed meshes,including skirts. Every disabled owner must decode EXACT zero;all seven enabled legacy owners appear nonzero in actual tested vertices. No extension coverage or overlay;the existing separate extension/overlay payload proof remains required. Validates global dead-owner elimination,not per-tile specialization,shader pixels,performance or all-task completion."},"  "))
	print("LEGACY_OWNER_MATRIX ",checks," checks / ",cases.size()," configured cases");quit()
