extends RefCounted
static var held:GDScript
static func prepare(tree:SceneTree,settings:Resource)->void:
	var selection:Resource=settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	for key:String in preload("res://scripts/terrain_shader_variants.gd").LEGACY+TerrainSettings.EXTENSION_KEYS:selection.set(key+"_coverage",0)
	selection.alien_infected.overlay_strength=0
	await preload("res://scripts/terrain_shader_preparation.gd").prepare(tree,selection)
	var data:Dictionary=tree.root.get_meta("terrain_shader_preparation");data["configured_mask"]=preload("res://scripts/terrain_shader_variants.gd").configured_mask(settings);tree.root.set_meta("terrain_shader_preparation",data)
static func apply()->void:
	# Replace the unloaded template before its first duplicate is made, so no
	# temporary material can register the universal terrain program.
	var template:ShaderMaterial=load("res://materials/terrain.tres")
	template.shader=(Engine.get_main_loop() as SceneTree).root.get_meta("terrain_shader_preparation").shader
	held=load("res://scripts/chunk_terrain.gd");var source:String=held.source_code
	var old:String='_terrain_material.shader=preload("res://scripts/terrain_shader_variants.gd").select(_terrain_material.shader,_settings_snapshot,specialize_terrain_shader)'
	assert(source.count(old)==1);source=source.replace(old,'_terrain_material.shader=get_tree().root.get_meta("terrain_shader_preparation").shader')
	old='mesh.surface_set_material(0,terrain_material)';assert(source.count(old)==1)
	source=source.replace(old,'mesh.set_meta("visible_owner_mask",preload("res://tools/biome_extensions/tile_owner_mask_candidate.gd").mask(result.arrays,result.extension_mask))\n\t\t'+old)
	assert(source.count('\t_active_chunks=next')==2)
	source=source.replace('\t_active_chunks=next','\t_update_visible_owner_program(next.values())\n\t_active_chunks=next')
	old='\tfor key:Vector3i in publish:';assert(source.count(old)==1)
	source=source.replace(old,'\t_update_visible_owner_program(candidates)\n'+old)
	source+='\nvar _visible_owner_mask:int=-1\nfunc _update_visible_owner_program(nodes:Array)->void:\n\tvar mask:int=0\n\tfor node:MeshInstance3D in nodes:\n\t\tassert(node.mesh.has_meta("visible_owner_mask"));mask|=int(node.mesh.get_meta("visible_owner_mask"))\n\tif mask==_visible_owner_mask:return\n\t_visible_owner_mask=mask\n\t_terrain_material.shader.code=preload("res://tools/biome_extensions/unreachable_shader_blocks_candidate.gd").compact(load("res://shaders/terrain_biomes.gdshader").code,mask)\n\tget_tree().root.set_meta("visible_owner_mask",mask)\n\tprint("VISIBLE_OWNER_PROGRAM ",mask," nodes=",nodes.size())\n'
	held.source_code=source;assert(held.reload()==OK)
