extends "res://tools/biome_extensions/check_all_owner_runtime_loop.gd"
var boot_script:GDScript
func report_basename()->String:return "check_all_owner_rendering_device_candidate"
func intervention()->Dictionary:return {"private_candidate":true,"production_adoption":false,"all_sixteen_owners":true,"rendering_method":RenderingServer.get_current_rendering_method(),"change":"Four unchanged scalar interpolants packed into one vec4; original full shading functions on RenderingDevice"}
func extra_guards()->Dictionary:return {"res://tools/biome_extensions/packed_terrain_varyings_candidate.gd":FileAccess.get_sha256("res://tools/biome_extensions/packed_terrain_varyings_candidate.gd")}
func run()->void:
	held_shader=load("res://shaders/terrain_biomes.gdshader")
	held_shader.code=preload("res://tools/biome_extensions/packed_terrain_varyings_candidate.gd").source_for(held_shader.code)
	boot_script=load("res://scripts/world_startup.gd");var needle:String='\tget_tree().change_scene_to_file('
	assert(boot_script.source_code.count(needle)==1)
	boot_script.source_code=boot_script.source_code.replace(needle,'\tpreload("res://tools/biome_extensions/instance_origin_patch_candidate.gd").apply()\n'+needle);assert(boot_script.reload()==OK)
	await super.run()
