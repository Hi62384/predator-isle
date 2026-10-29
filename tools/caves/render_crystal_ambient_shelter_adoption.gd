extends "res://tools/caves/render_crystal_world.gd"
const OriginalShader:String="res://tools/biome_extensions/artifacts/revisions/experiment_render_cave_crystal_ambient_shelter_candidate_1d1cfe93a2ad/sources/shaders/cave_crystal_feature.gdshader.txt"
func inspection_name()->String:return "crystal_ambient_shelter_adoption"
func selected_room_id()->String:return "6:-2:3:3:lobe:0"
func selection_label()->String:return "Original normal73921CrystalWastes(6,-2)quartz pocket;actual production ambient shelter"
func additional_guards()->Dictionary:return {OriginalShader:FileAccess.get_sha256(OriginalShader)}
func inspection_material_checks(data:Dictionary,nodes:Array,camera:Camera3D,light:OmniLight3D)->Dictionary:
	var expected:String=FileAccess.get_file_as_string(OriginalShader).replace("\r\n","\n");expected=expected.replace("uniform float cave_crystal_luminous_strength=0.0;","uniform float cave_crystal_luminous_strength=0.0;\nuniform float cave_crystal_ambient_shelter=0.08;");expected=expected.replace("AO=mix(.72,1.0,smoothstep(0.0,.22,t));","AO=mix(.72,1.0,smoothstep(0.0,.22,t))*cave_crystal_ambient_shelter;");check(expected==FileAccess.get_file_as_string("res://shaders/cave_crystal_feature.gdshader").replace("\r\n","\n"),"Actual production shader equals exact pretested private ambient transformation,normalized line endings only")
	var materials:Dictionary={};var target:Dictionary={}
	for form:Dictionary in data.placements:
		if form.kind=="crystal" and str(form.id).begins_with(str(data.room.id)+"/") and (target.is_empty() or form.height>target.height):target=form
	for node:Node in nodes:
		for child:Node in node.get_children():
			if child is MeshInstance3D and str(child.name).begins_with("CaveBiome_crystal_"):
				var material:ShaderMaterial=child.material_override if child.material_override!=null else child.mesh.surface_get_material(0);materials[material]=material.get_shader_parameter("cave_crystal_ambient_shelter")
	check(not materials.is_empty() and not target.is_empty(),"Actual production cave mineral batches and owned target positive")
	for material:ShaderMaterial in materials:check(is_equal_approx(float(materials[material]),.08),"Production material binds same.08shelter as host cave rock")
	if target.is_empty():return {"failed":"Original target missing"}
	camera.position=data.room.point+Vector3.UP*1.8;camera.look_at(target.bounds.get_center());light.visible=false;var sheltered:Image=await crystal_picture("actual_sheltered_natural")
	for material:ShaderMaterial in materials:material.set_shader_parameter("cave_crystal_ambient_shelter",1.0)
	var legacy:Image=await crystal_picture("actual_legacy_ambient_one");check(sheltered.get_data()!=legacy.get_data(),"Actual production ambient shelter visibly changes only sky response")
	var environment:Environment=camera.get_world_3d().environment;var ambient:int=environment.ambient_light_source;var reflected:int=environment.reflected_light_source;environment.ambient_light_source=Environment.AMBIENT_SOURCE_DISABLED;environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED;light.visible=true;light.position=camera.position+Vector3.UP*.5;var direct_old:Image=await crystal_picture("actual_direct_only_legacy")
	for material:ShaderMaterial in materials:material.set_shader_parameter("cave_crystal_ambient_shelter",materials[material])
	var direct_new:Image=await crystal_picture("actual_direct_only_sheltered");check(direct_old.get_data()==direct_new.get_data(),"Actual production direct-light image remains pixel-exact")
	environment.ambient_light_source=ambient;environment.reflected_light_source=reflected;light.visible=false;var restored:Image=await crystal_picture("actual_shelter_return");check(sheltered.get_data()==restored.get_data(),"All original actual production parameters and environment restore exact native image")
	return {"materials":materials.size(),"ambient_shelter":.08,"legacy_one_positive":sheltered.get_data()!=legacy.get_data(),"direct_only_exact":direct_old.get_data()==direct_new.get_data(),"exact_return":sheltered.get_data()==restored.get_data(),"scope":"Actual production ambient-only cave mineral shelter,exact pretested shader transformation and independent1mode,direct-only pixel equality,complete environment restore before original collision walk. No geometry/abilities/lighting nodes/particles changes,FPS or art-completion claim."}
