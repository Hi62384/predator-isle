extends RefCounted
static var held:GDScript
static var held_preparation:GDScript
static func prepare(tree:SceneTree,settings:Resource)->void:
	held_preparation=load("res://scripts/terrain_shader_preparation.gd")
	var source:String=held_preparation.source_code
	var original:String='var shader:Shader=Variants.select(load("res://shaders/terrain_biomes.gdshader"),settings)'
	assert(source.count(original)==1)
	source=source.replace(original,'var shader:=Shader.new();shader.code=preload("res://tools/biome_extensions/pure_owner_shader_candidate.gd").source_for(load("res://shaders/terrain_biomes.gdshader").code,128,-4)')
	held_preparation.source_code=source;assert(held_preparation.reload()==OK)
	await held_preparation.prepare(tree,settings)
static func apply()->void:
	var tree=Engine.get_main_loop() as SceneTree
	var template:ShaderMaterial=load("res://materials/terrain.tres");template.shader=tree.root.get_meta("terrain_shader_preparation").shader
	held=load("res://scripts/chunk_terrain.gd");var source:String=held.source_code
	var old:String='_terrain_material.shader=preload("res://scripts/terrain_shader_variants.gd").select(_terrain_material.shader,_settings_snapshot,specialize_terrain_shader)'
	assert(source.count(old)==1);source=source.replace(old,'_terrain_material.shader=get_tree().root.get_meta("terrain_shader_preparation").shader')
	old='\t\t\t\t\tresult.append({"key":';assert(source.count(old)==1)
	source=source.replace(old,'\t\t\t\t\tvar shader_groups:Array=preload("res://tools/biome_extensions/pure_surface_partition_candidate.gd").partition(arrays,builder.chunk_size,builder.built_extension_data,builder.built_extension_rows,builder.built_extension_mask) if item.z>=3 else []\n'+old)
	source=source.replace('"edge_profiles":edge_profiles,"swamp_water":','"shader_groups":shader_groups,"edge_profiles":edge_profiles,"swamp_water":')
	old='mesh.surface_set_material(0,terrain_material)';assert(source.count(old)==1)
	source=source.replace(old,'_install_private_shader_groups(mesh,result,terrain_material,format_flags)')
	# All runtime debug/settings refreshes must reach every grouped surface.
	source=source.replace('var material:Material=node.mesh.surface_get_material(0)\n\t\t\t\tif not variants.has(material):variants.append(material)','for surface:int in range(node.mesh.get_surface_count()):\n\t\t\t\t\tvar material:Material=node.mesh.surface_get_material(surface)\n\t\t\t\t\tif not variants.has(material):variants.append(material)')
	source=source.replace('var material:Material=mesh.surface_get_material(0)\n\t\tif not variants.has(material):variants.append(material)','for surface:int in range(mesh.get_surface_count()):\n\t\t\tvar material:Material=mesh.surface_get_material(surface)\n\t\t\tif not variants.has(material):variants.append(material)')
	source+='\nvar _private_programs:Dictionary={}\nfunc _install_private_shader_groups(mesh:ArrayMesh,result:Dictionary,material:ShaderMaterial,flags:int)->void:\n\tvar groups:Array=result.shader_groups\n\tif groups.is_empty():\n\t\tvar mask:int=preload("res://tools/biome_extensions/tile_owner_mask_candidate.gd").mask(result.arrays,result.extension_mask)\n\t\tvar base:int=-1;var controls:PackedFloat32Array=result.arrays[Mesh.ARRAY_CUSTOM1] if result.arrays[Mesh.ARRAY_CUSTOM1]!=null else PackedFloat32Array();var coast:bool=not controls.is_empty()\n\t\tfor i:int in range(0,controls.size(),4):coast=coast and controls[i+2]<0 and ((int(-controls[i+2]-1)>>8)&255)==255\n\t\tif coast:base=-4;mask=128\n\t\tgroups=[{"mask":mask,"base":base,"arrays":result.arrays}]\n\tmesh.clear_surfaces()\n\tfor group:Dictionary in groups:\n\t\tvar key:=Vector2i(group.mask,group.base)\n\t\tif not _private_programs.has(key):\n\t\t\tvar shader:=Shader.new();shader.code=preload("res://tools/biome_extensions/pure_owner_shader_candidate.gd").source_for(load("res://shaders/terrain_biomes.gdshader").code,group.mask,group.base);_private_programs[key]=shader;print("PURE_SURFACE_PROGRAM ",key," count=",_private_programs.size())\n\t\tvar copy:ShaderMaterial=material.duplicate();copy.shader=_private_programs[key];mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,group.arrays,[],{},flags);mesh.surface_set_material(mesh.get_surface_count()-1,copy)\n'
	held.source_code=source;assert(held.reload()==OK)
