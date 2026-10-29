extends "res://tools/caves/check_frozen_features.gd"
const SurfaceProvider=preload("res://scripts/caves/magma_surface.gd")
const Tubes=preload("res://scripts/caves/magma_tubes.gd")
const Magma=preload("res://scripts/caves/magma_features.gd")
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://config/caves/biomes/magma_cave_definition.tres","res://shaders/cave_magma_molten.gdshader"]:guards[path]=FileAccess.get_sha256(path)
	var definition:Resource=load("res://config/caves/biomes/magma_cave_definition.tres");var provider=SurfaceProvider.new();check(definition.validation_errors().is_empty(),"All exposed controls validate with original normal defaults")
	for key:String in ["lava_emission_strength","lava_animation_speed","lava_crust_strength","lava_normal_strength"]:
		for invalid in [-1,INF,NAN,"bad"]:
			var settings:Dictionary=definition.material_configuration.duplicate();settings[key]=invalid;check(not provider.validation_errors(settings,definition.feature_configuration).is_empty(),"Invalid molten material setting rejected "+key)
	for key:String in ["column_frequency","obsidian_lens_chance","tube_frequency","fissure_frequency"]:
		for invalid in [-.1,1.1,INF,NAN,"bad"]:
			var settings:Dictionary=definition.feature_configuration.duplicate();settings[key]=invalid;check(not provider.validation_errors(definition.material_configuration,settings).is_empty(),"Invalid volcanic geological frequency rejected "+key)
	var original:ShaderMaterial=provider.feature_material("molten_volcanic",definition.material_configuration,true);var zero:Dictionary=definition.material_configuration.duplicate();zero.lava_emission_strength=0.0;zero.lava_animation_speed=0.0;zero.lava_crust_strength=0.0;zero.lava_detail_quality=0
	var altered:ShaderMaterial=provider.feature_material("molten_volcanic",zero,true)
	check(original!=altered and original.get_shader_parameter("lava_emission_strength")==1.9 and altered.get_shader_parameter("lava_emission_strength")==0.0,"Independent parameterized materials do not mutate another active configuration")
	check(altered.get_shader_parameter("lava_animation_speed")==0.0 and altered.get_shader_parameter("lava_crust_strength")==0.0 and altered.get_shader_parameter("lava_detail_quality")==0,"Actual shader receives all OFF/quality controls")
	var texture:Texture2D=provider.feature_material("cooled_volcanic",definition.material_configuration,true).get_shader_parameter("volcanic_color")
	for index in range(24):
		var settings:Dictionary=definition.material_configuration.duplicate();settings.lava_emission_strength=float(index)/10
		check(provider.feature_material("cooled_volcanic",settings,index%2==0).get_shader_parameter("volcanic_color")==texture,"Every material configuration reuses the same resident photograph texture")
	check(SurfaceProvider._feature_materials.size()<=16 and SurfaceProvider._feature_textures.size()==2,"Material variants and image residency remain bounded")
	var region:Dictionary=fixture();region.erase("pools");region.cave_biome_regions.candidates[0].biome_id="magma";region.cave_biome_regions.candidates[0].id="A/magma";var flat:Callable=func(_x:float,_z:float)->float:return 200.0
	var settings:Dictionary=definition.feature_configuration.duplicate();settings.tube_frequency=0.0;check(var_to_bytes(Tubes.decorate(region,flat,17,settings,400,10))==var_to_bytes(region),"Zero tube frequency exact original solved graph")
	settings.tube_frequency=1.0;settings.fissure_frequency=1.0;var fissure:Dictionary=Tubes.decorate(region,flat,17,settings,400,10);check(fissure.edges[0].magma_tube_profile=="great_volcanic_fissure","Independent fissure frequency reaches actual whole-passage geometry")
	var field=Field.new();field.include_surface_air=false;check(field.compile([region],flat,[],region.cave_biome_regions),"Same host compiles column controls")
	settings.column_frequency=0.0;settings.obsidian_lens_chance=0.0;settings.cooled_intrusions=false
	var blocks:Dictionary=Magma.new().build(field,Vector3i.ZERO,73921,[region],settings,{})
	check(not blocks.placements.is_empty() and blocks.placements.all(func(p:Dictionary)->bool:return p.kind=="volcanic_block"),"Zero column and obsidian frequency keeps actual positive ordinary volcanic blocks")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable Magma control source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_controls.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"material_cache_size":SurfaceProvider._feature_materials.size(),"resident_feature_texture_count":SurfaceProvider._feature_textures.size(),"scope":"Actual validated material/frequency knobs,independent shader parameter configurations,shared image residency/bounded cache,zero-column/obsidian positive blocks,whole-tube OFF and forced fissure geometry. Native visual control counterfactuals separate;not FPS or art certification."},"  "));print("MAGMA_CONTROLS ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
