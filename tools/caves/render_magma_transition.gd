extends "res://tools/caves/render_magma_world.gd"
var target_key:String="default_magma"
var selection:Dictionary={}
var window:Dictionary={}
func run()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("target="):target_key=arg.trim_prefix("target=")
	assert(target_key in ["default_magma","crystal_magma"])
	await super.run()
func index_path()->String:return "res://tools/biome_extensions/artifacts/index_cave_magma_transitions.json"
func selected_case(catalogue:Dictionary)->Dictionary:
	selection=catalogue.first[target_key]
	return {"ordinal":selection.ordinal,"host":selection.host,"seed":int(selection.seed),"site":selection.site,"rooms":[{"room":{"id":selection.room_id}}]}
func report_basename()->String:return "render_cave_magma_transition_"+target_key
func capture_prefix()->String:return "magma_transition_"+target_key
func requires_cooled_forms()->bool:return false
func requires_geometry_counterfactual()->bool:return false
func local_route_limit()->float:return 160
func chosen_route_edge(region:Dictionary,_room_id:String)->Dictionary:
	for edge:Dictionary in region.get("edges",[])+region.get("pocket_passages",[]):
		if str(edge.from)!=str(selection.parent_id) or str(edge.to)!=str(selection.room_id):continue
		var distances:Array=[0.0]
		for index in range(1,edge.points.size()):distances.append(float(distances[-1])+edge.points[index-1].distance_to(edge.points[index]))
		var best:int=0;var error:float=INF
		for index in range(edge.points.size()):
			var weights:Dictionary=Regions.along_edge(region.cave_biome_regions,str(edge.from),str(edge.to),distances[index],distances[-1]).weights
			var current:float=absf(float(weights.get("magma",0))-(float(selection.maximum_magma)+float(selection.minimum_magma))*.5)
			if current<error:error=current;best=index
		var first:int=best;var last:int=best
		while first>0 and distances[best]-distances[first-1]<=40:first-=1
		while last+1<distances.size() and distances[last+1]-distances[best]<=40:last+=1
		var result:Dictionary=edge.duplicate();result.points=edge.points.slice(first,last+1);window={"original_length_m":distances[-1],"window_length_m":distances[last]-distances[first],"selected_before_native_physics":true,"center_error":error};return result
	return {}
func native_bounds(_room:Dictionary,_pool:Dictionary,route:Array[Vector3])->AABB:
	var low:=Vector3.INF;var high:Vector3=-Vector3.INF
	for point:Vector3 in route:low=low.min(point-Vector3(10,5,10));high=high.max(point+Vector3(10,18,10))
	return AABB(low,high-low)
func additional_native_checks(data:Dictionary,nodes:Array,camera:Camera3D,light:OmniLight3D)->Dictionary:
	check(not window.is_empty() and window.window_length_m<=80 and window.center_error<.1,"Preselected original half-strength transition window")
	var ids:Dictionary={};var materials:Dictionary={}
	for cell:Dictionary in data.cells:
		for id:String in cell.get("biome_ids",[]):ids[id]=true
	for node:MeshInstance3D in nodes:
		if node.mesh==null:continue
		var material:ShaderMaterial=node.mesh.surface_get_material(0)
		if material.get_shader_parameter("cave_magma_cooled_strength")!=null:materials[material.get_instance_id()]={"material":material,"strength":material.get_shader_parameter("cave_magma_cooled_strength")}
	check(ids.has("magma") and (target_key!="crystal_magma" or ids.has("crystal")),"Original shared transition carries actual independent target material channels")
	var middle:int=data.route.size()/4;camera.position=data.route[middle]+Vector3.UP*.85;camera.look_at(data.route[mini(middle+3,data.route.size()-1)]+Vector3.UP);light.position=camera.position+Vector3.UP*.5
	var before:Image=await capture("actual_transition")
	for record:Dictionary in materials.values():record.material.set_shader_parameter("cave_magma_cooled_strength",0.0)
	var off:Image=await capture("magma_material_off")
	for record:Dictionary in materials.values():record.material.set_shader_parameter("cave_magma_cooled_strength",record.strength)
	var returned:Image=await capture("magma_material_exact_return")
	check(before.get_data()!=off.get_data() and before.get_data()==returned.get_data(),"Positive actual transition material effect and exact restoration")
	return {"window":window,"biome_ids":ids.keys(),"material_instances":materials.size(),"material_exact_return":before.get_data()==returned.get_data()}
func world_guards()->Dictionary:return {get_script().resource_path:FileAccess.get_sha256(get_script().resource_path)}
func scope_description()->String:return "First normal Default-Magma or Crystal-Magma edge from108predeclared cases. Original solved80m window centered before physics on half-range weight,actual3x3 field/material/collision and ordinary same-way capsule return. Not the whole multi-kilometre edge or isolated FPS."
