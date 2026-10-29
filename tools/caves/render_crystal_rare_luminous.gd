extends "res://tools/caves/render_crystal_indexed_scene.gd"
func scene_index_path()->String:return "res://tools/biome_extensions/artifacts/index_cave_crystal_luminous_regions.json"
func inspection_cohort_label()->String:return "24576case"
func selection_label()->String:return "FIRST normally rare existing main/pocket descriptor in fixed24576case inventory;all channel and terrain rejections retained,before native imagery"
func inspection_routes(data:Dictionary,_field)->Array:
	var points:PackedVector3Array=PackedVector3Array()
	for region:Dictionary in data.bundle.regions:
		for edge:Dictionary in region.edges+region.get("pocket_passages",[]):
			if str(edge.from)==str(data.parent.id) and str(edge.to)==str(data.room.id):points=edge.points.duplicate();break
			if str(edge.to)==str(data.parent.id) and str(edge.from)==str(data.room.id):points=edge.points.duplicate();points.reverse();break
		if not points.is_empty():break
	check(points.size()>2,"Original solved producer edge,not only distant endpoints,available for main-chamber walking")
	var maximum_rise:float=0;var route:Array=[]
	for index in range(points.size()):
		if index>0:maximum_rise=maxf(maximum_rise,absf(points[index].y-points[index-1].y))
		route.append(points[index]+Vector3.UP*.95)
	check(maximum_rise<2.0,"Original solved per-station rise remains below unchanged walker12m fall guard")
	for index in range(route.size()-2,-1,-1):route.append(route[index])
	return [{"label":"Original solved normally rare mineral main-chamber edge and exact same-way return","points":route}]
func inspection_parent_id(_room:Dictionary)->String:return str(selection.parent_id)
func run()->void:
	target_key="rare_luminous"
	await super.run()
func inspection_material_checks(data:Dictionary,nodes:Array,camera:Camera3D,light:OmniLight3D)->Dictionary:
	var owned:Dictionary={};var selected:int=0;var total:int=0;var materials:Dictionary={}
	for form:Dictionary in data.placements:
		if form.kind=="crystal":total+=1
		if form.get("fictional_emission",false):
			selected+=1
			if str(form.id).begins_with(str(data.room.id)+"/") and (owned.is_empty() or str(form.id)<str(owned.id)):owned=form
	check(not owned.is_empty() and selected>0 and selected<=floori(total*.1),"FIRST normally rare descriptor has its own actual faint-emission crystals and majority ordinary minerals")
	if owned.is_empty():return {"selected":selected,"ordinary_crystals":total,"failed":"First descriptor retained;no native owned emission positive"}
	for node:Node in nodes:
		for child:Node in node.get_children():
			if child is MeshInstance3D and str(child.name)=="CaveBiome_crystal_mineral_opaque":
				var material:ShaderMaterial=child.mesh.surface_get_material(0);materials[material]=material.get_shader_parameter("cave_crystal_luminous_strength")
	camera.position=data.room.point+Vector3.UP*1.8;camera.look_at(owned.bounds.get_center());light.visible=false;var on:Image=await crystal_picture("normal_rare_faint_emission")
	for material:ShaderMaterial in materials:material.set_shader_parameter("cave_crystal_luminous_strength",0.0)
	var off:Image=await crystal_picture("normal_rare_emission_off")
	for material:ShaderMaterial in materials:material.set_shader_parameter("cave_crystal_luminous_strength",materials[material])
	var restored:Image=await crystal_picture("normal_rare_emission_return");check(on.get_data()!=off.get_data(),"Normally rare actual emission is visible in native low light");check(on.get_data()==restored.get_data(),"Normally rare material control restores exact original image")
	return {"selected":selected,"ordinary_crystals":total,"region_chance":.005,"form_chance":.12,"strength":.025,"owned_target":str(owned.id),"visible":on.get_data()!=off.get_data(),"exact_return":on.get_data()==restored.get_data(),"scope":"FIRST normally rare full-weight existing Crystal main/pocket descriptor from fixed24576case index. No biome,emission,theme,extent,density or region chance override;actual production fields/meshes/materials/colliders and original solved producer edge return. No added lights/particles or FPS/reference-art claim."}
