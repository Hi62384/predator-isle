extends RefCounted
static var held:GDScript
static func prepare(tree:SceneTree,settings:Resource)->void:
	# Diagnostic cohort only:these conservative programs cover the four
	# actual branch unions observed in the seed73921 startup cut. Compile
	# before image banks to distinguish transient compiler cost from steady RAM.
	var shaders:Dictionary={};var start:int=Time.get_ticks_usec()
	for mask:int in [128,4225,139,4122]:
		var selection:Resource=settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		var keys:Array[String]=preload("res://scripts/terrain_shader_variants.gd").LEGACY
		for i:int in range(keys.size()):selection.set(keys[i]+"_coverage",12 if mask&(1<<i) else 0)
		selection.rocky_coast_enabled=(mask&128)!=0;selection.beaches_enabled=(mask&128)!=0
		for i:int in range(TerrainSettings.EXTENSION_KEYS.size()):selection.set(TerrainSettings.EXTENSION_KEYS[i]+"_coverage",12 if mask&(1<<(i+8)) else 0)
		selection.alien_infected.overlay_strength=0
		print("PREPARED_TILE_BEGIN ",mask)
		shaders[mask]=await preload("res://scripts/terrain_shader_preparation.gd").prepare(tree,selection)
		print("PREPARED_TILE_END ",mask)
	tree.root.set_meta("prepared_tile_shaders",shaders)
	var metadata:Dictionary=tree.root.get_meta("terrain_shader_preparation");metadata["configured_mask"]=preload("res://scripts/terrain_shader_variants.gd").configured_mask(settings);metadata["prepared_tile_masks"]=shaders.keys();metadata["seconds"]=(Time.get_ticks_usec()-start)/1000000.0;tree.root.set_meta("terrain_shader_preparation",metadata)
static func apply()->void:
	held=load("res://scripts/chunk_terrain.gd");var source:String=held.source_code
	for marker:String in ['_terrain_material = preload("res://materials/terrain.tres").duplicate() as ShaderMaterial','_apply_material_settings()','_terrain_material.set_shader_parameter("chunk_size_metres",chunk_size)']:
		var line:String='\t'+marker+'\n'
		assert(source.contains(line))
		source=source.replace(line,line+'\tprint("TILE_MEMORY_STAGE '+marker.replace('"','')+' static=",Performance.get_monitor(Performance.MEMORY_STATIC)," textures=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED))\n')
	var old:String='_terrain_material.shader=preload("res://scripts/terrain_shader_variants.gd").select(_terrain_material.shader,_settings_snapshot,specialize_terrain_shader)'
	assert(source.count(old)==1);source=source.replace(old,'_terrain_material.shader=get_tree().root.get_meta("terrain_shader_preparation").shader')
	old='mesh.surface_set_material(0,terrain_material)';assert(source.count(old)==1)
	source=source.replace(old,'terrain_material=_prepared_tile_material(terrain_material,result.arrays,result.extension_mask)\n\t\t'+old)
	source+='\nfunc _prepared_tile_material(material:ShaderMaterial,arrays:Array,extensions:int)->ShaderMaterial:\n\tvar mask:int=preload("res://tools/biome_extensions/tile_owner_mask_candidate.gd").mask(arrays,extensions)\n\tvar shaders:Dictionary=get_tree().root.get_meta("prepared_tile_shaders")\n\tfor existing:int in shaders:\n\t\tif (existing & mask)==mask:\n\t\t\tmaterial=material.duplicate();material.shader=shaders[existing];return material\n\tassert(false,"Startup cohort not covered by prepared programs:"+str(mask));return material\n'
	held.source_code=source;assert(held.reload()==OK)
