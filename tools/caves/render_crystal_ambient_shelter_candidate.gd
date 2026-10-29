extends "res://tools/caves/render_crystal_world.gd"
func inspection_name()->String:return "crystal_ambient_shelter_candidate"
func selected_room_id()->String:return "6:-2:3:3:lobe:0"
func selection_label()->String:return "Original normal73921CrystalWastes(6,-2)quartz pocket;private ambient-only mineral shelter study"
func inspection_control_scope()->String:return "PRIVATE shader shelter comparison only. Original normal production field,geometry,materials,lights and collisions retained;temporary material/environment controls restore exactly before physics."
func inspection_material_checks(data:Dictionary,nodes:Array,camera:Camera3D,light:OmniLight3D)->Dictionary:
	var originals:Array=[];var copies:Dictionary={};var owned:Dictionary={}
	for form:Dictionary in data.placements:
		if form.kind=="crystal" and str(form.id).begins_with(str(data.room.id)+"/") and (owned.is_empty() or form.height>owned.height):owned=form
	check(not owned.is_empty(),"Original chosen room has its own real minerals")
	if owned.is_empty():return {"failed":"Original owned target missing"}
	camera.position=data.room.point+Vector3.UP*1.8;camera.look_at(owned.bounds.get_center());light.visible=false;var baseline:Image=await crystal_picture("original_natural_ambient")
	for node:Node in nodes:
		for child:Node in node.get_children():
			if not child is MeshInstance3D or not str(child.name).begins_with("CaveBiome_crystal_"):continue
			var source:ShaderMaterial=child.material_override if child.material_override!=null else child.mesh.surface_get_material(0)
			if not copies.has(source):
				var material:ShaderMaterial=source.duplicate();var shader:Shader=material.shader.duplicate();shader.code=shader.code.replace("uniform bool cave_crystal_bed=false;","uniform bool cave_crystal_bed=false;\nuniform float cave_crystal_ambient_shelter=1.0;");var before:String="AO=mix(.72,1.0,smoothstep(0.0,.22,t));";check(shader.code.contains(before),"Actual shared cave mineral shader exposes one original ambient term");shader.code=shader.code.replace(before,"AO=mix(.72,1.0,smoothstep(0.0,.22,t))*cave_crystal_ambient_shelter;");material.shader=shader;material.set_shader_parameter("cave_crystal_ambient_shelter",1.0);copies[source]=material
			originals.append({"node":child,"override":child.material_override});child.material_override=copies[source]
	check(not copies.is_empty(),"Actual native mineral batches participate in private shelter control");var legacy:Image=await crystal_picture("private_shelter_one");check(baseline.get_data()==legacy.get_data(),"Independent shelter one mode equals exact original actual native image")
	for material:ShaderMaterial in copies.values():material.set_shader_parameter("cave_crystal_ambient_shelter",.08)
	var sheltered:Image=await crystal_picture("private_shelter_eight_percent");check(sheltered.get_data()!=legacy.get_data(),"Shelter actually reduces visible unoccluded cave mineral sky contribution")
	var environment:Environment=camera.get_world_3d().environment;var ambient:int=environment.ambient_light_source;var reflected:int=environment.reflected_light_source;environment.ambient_light_source=Environment.AMBIENT_SOURCE_DISABLED;environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED;light.visible=true;light.position=camera.position+Vector3.UP*.5
	for material:ShaderMaterial in copies.values():material.set_shader_parameter("cave_crystal_ambient_shelter",1.0)
	var direct_old:Image=await crystal_picture("direct_light_only_original")
	for material:ShaderMaterial in copies.values():material.set_shader_parameter("cave_crystal_ambient_shelter",.08)
	var direct_new:Image=await crystal_picture("direct_light_only_sheltered");check(direct_old.get_data()==direct_new.get_data(),"Direct test light remains pixel-exact with sky diffuse/reflections disabled;AO_LIGHT_AFFECT stays zero")
	environment.ambient_light_source=ambient;environment.reflected_light_source=reflected;light.visible=false
	for item:Dictionary in originals:item.node.material_override=item.override
	var restored:Image=await crystal_picture("original_natural_return");check(baseline.get_data()==restored.get_data(),"Exact original materials,environment and native image restored before collision walk")
	return {"native_materials":copies.size(),"shelter":.08,"natural_visible":sheltered.get_data()!=legacy.get_data(),"direct_only_exact":direct_old.get_data()==direct_new.get_data(),"exact_original_return":baseline.get_data()==restored.get_data(),"scope":"PRIVATE ambient shelter multiplier matching existing cave rock's.08term. Shared actual mineral batches;independent1mode/exact original,positive sky response and exact direct-only lighting control,full environment/material restoration. No geometry/physics or light node additions,no adoption/FPS/art acceptance."}
