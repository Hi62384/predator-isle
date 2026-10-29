extends "res://tools/caves/render_crystal_world.gd"
func inspection_name()->String:return "crystal_luminous_adoption"
func selected_room_id()->String:return "6:-2:3:3:lobe:0"
func selection_label()->String:return "Original fixed73921 CrystalWastes(6,-2) quartz pocket;complete production luminous provider/material"
func inspection_control_scope()->String:return "Production mechanism diagnostic forces only luminous region/form selection1,hard10percent cap retained. Saved normal.005/.12 and original18percent/.65density unchanged."
func inspection_definition()->Resource:
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);definition.feature_configuration.luminous_region_chance=1.0;definition.feature_configuration.luminous_form_chance=1.0;return definition
func inspection_material_checks(data:Dictionary,nodes:Array,camera:Camera3D,light:OmniLight3D)->Dictionary:
	var target:Dictionary={};var tagged:int=0;var total:int=0;var materials:Dictionary={}
	for form:Dictionary in data.placements:
		if form.kind=="crystal":total+=1
		if form.get("fictional_emission",false):
			tagged+=1
			if str(form.id).begins_with(str(data.room.id)+"/") and (target.is_empty() or str(form.id)<str(target.id)):target=form
	for node:Node in nodes:
		for child:Node in node.get_children():
			if child is MeshInstance3D and str(child.name)=="CaveBiome_crystal_mineral_opaque":
				var material:ShaderMaterial=child.mesh.surface_get_material(0);materials[material]=material.get_shader_parameter("cave_crystal_luminous_strength")
	check(tagged>0 and tagged<=floori(total*.1) and not target.is_empty() and not materials.is_empty(),"Actual complete provider tags selected owned prisms while keeping at least90percent ordinary")
	for material:ShaderMaterial in materials:check(is_equal_approx(float(materials[material]),.025),"Production material binds requested faint.025emission")
	if target.is_empty():return {"failed":"No owned target;original fixed case retained"}
	camera.position=data.room.point+Vector3.UP*1.8;camera.look_at(target.bounds.get_center());light.visible=false;var on:Image=await crystal_picture("actual_production_faint_emission")
	for material:ShaderMaterial in materials:material.set_shader_parameter("cave_crystal_luminous_strength",0.0)
	var off:Image=await crystal_picture("actual_production_emission_off")
	for material:ShaderMaterial in materials:material.set_shader_parameter("cave_crystal_luminous_strength",materials[material])
	var restored:Image=await crystal_picture("actual_production_emission_return");check(on.get_data()!=off.get_data(),"Actual production shader visibly emits only selected flags in low light");check(on.get_data()==restored.get_data(),"Production shader strength restores exact original native image")
	return {"tagged":tagged,"ordinary_crystals":total,"strength":.025,"target":str(target.id),"visible":on.get_data()!=off.get_data(),"exact_return":on.get_data()==restored.get_data(),"scope":"Actual production generator/material/native opaque batches,lossless sign flag,no new Light3D nodes/particles. Diagnostic selection1 only;not normal rare occurrence. All original rock/crystal collisions and ordinary return retained."}
