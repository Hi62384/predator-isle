extends RefCounted
static var held:GDScript
static var prepared_mask:int=0
static func prepare_mask(settings:Resource)->int:
	var builder=load("res://scripts/terrain_mesh_builder.gd").new();builder.settings=settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);builder._configure_noise()
	var mask:int=128 if settings.rocky_coast_enabled or settings.beaches_enabled else 0
	var step:float=maxf(builder._minimum_region_size/(maxf(settings.height_blend,.1)*4),1)
	var radius:float=32768
	var first:int=floori(-radius/step)-1;var last:int=ceili(radius/step)+1
	for z:int in range(first,last+1):
		for x:int in range(first,last+1):
			var owner:int=builder._grid_owner(x,z,step)
			if owner==4:mask|=1
			elif owner>=1 and owner<=3:mask|=1<<owner
			elif owner>=5 and owner<=7:mask|=1<<(owner-1)
			elif owner>=8:mask|=1<<owner
	if settings.alien_infected.overlay_strength>0:mask|=32768
	prepared_mask=mask;print("PRIVATE_CONSERVATIVE_WINDOW_MASK ",mask);return mask
static func apply()->void:
	held=load("res://scripts/chunk_terrain.gd")
	var source:String=held.source_code
	var old:String='_terrain_material.shader=preload("res://scripts/terrain_shader_variants.gd").select(_terrain_material.shader,_settings_snapshot,specialize_terrain_shader)'
	assert(source.contains(old));source=source.replace(old,'_terrain_material.shader=get_tree().root.get_meta("terrain_shader_preparation").shader')
	old='mesh.surface_set_material(0,terrain_material)';assert(source.count(old)==1)
	source=source.replace(old,'terrain_material=_private_tile_material(terrain_material,result.arrays,result.extension_mask)\n\t\t'+old)
	source+='\nvar _private_tile_shaders:Dictionary={}\nfunc _private_tile_material(material:ShaderMaterial,arrays:Array,extensions:int)->ShaderMaterial:\n\tvar mask:int=preload("res://tools/biome_extensions/tile_owner_mask_candidate.gd").mask(arrays,extensions)\n\tif not _private_tile_shaders.has(mask):\n\t\tvar shader:=Shader.new();shader.code=preload("res://scripts/terrain_shader_variants.gd").source_for(load("res://shaders/terrain_biomes.gdshader").code,mask);_private_tile_shaders[mask]=shader;print("PRIVATE_TILE_SHADER ",mask)\n\tmaterial=material.duplicate();material.shader=_private_tile_shaders[mask];return material\n'
	if OS.get_cmdline_user_args().has("canonical-legacy"):
		source=source.replace('mask(arrays,extensions)\n\tif not _private_tile_shaders.has(mask):','mask(arrays,extensions)\n\tmask=(mask & 65280)|255\n\tif mask==255:\n\t\tmaterial=material.duplicate();material.shader=get_tree().root.get_meta("terrain_shader_preparation").shader;return material\n\tif not _private_tile_shaders.has(mask):')
	if OS.get_cmdline_user_args().has("reuse-supersets"):
		source=source.replace('mask(arrays,extensions)\n\tif not _private_tile_shaders.has(mask):','mask(arrays,extensions)\n\tif not _private_tile_shaders.has(mask):\n\t\tfor existing:int in _private_tile_shaders:\n\t\t\tif (existing & mask)==mask:\n\t\t\t\tmaterial=material.duplicate();material.shader=_private_tile_shaders[existing];return material\n\tif not _private_tile_shaders.has(mask):')
	if OS.get_cmdline_user_args().has("regional-window"):
		source=source.replace('mask(arrays,extensions)\n\tif not _private_tile_shaders.has(mask):','mask(arrays,extensions)\n\tif ('+str(prepared_mask)+' & mask)==mask:\n\t\tmaterial=material.duplicate();material.shader=get_tree().root.get_meta("terrain_shader_preparation").shader;return material\n\tif not _private_tile_shaders.has(mask):')
	held.source_code=source;assert(held.reload()==OK)
