extends "res://tools/caves/render_crystal_world.gd"
const SelectionPath:String="res://tools/biome_extensions/artifacts/index_cave_crystal_transitions.json"
var selection:Dictionary={}
var target_key:String="frozen_crystal"
var actual_edge:Dictionary={}
var window:Dictionary={}
func inspection_requires_mineral_prisms()->bool:return target_key!="default_crystal"
func inspection_name()->String:return "crystal_transition_"+target_key
func inspection_host()->String:return selection.host
func inspection_seed()->int:return int(selection.seed)
func inspection_site()->Vector2i:return Vector2i(selection.site[0],selection.site[1])
func selected_room_id()->String:return selection.room_id
func inspection_parent_id(_room:Dictionary)->String:return str(selection.parent_id)
func selection_label()->String:return "First preselected normal "+target_key+" edge from complete36case transition inventory"
func inspection_control_scope()->String:return "Unchanged normal saved Frozen/Crystal settings and actual original solved producer edge. No forced biome weights,chance,extent,theme,ice or mineral density;all original negative cases retained. Original solved stations and same-way return. Default-Crystal uses a bounded144m window centered on the FIRST natural half-strength transition along the exact original3988m edge,selected before native physics;not the whole long edge. Localized mineralization may have zero major prisms and MUST show a positive host-material off/exact-return counterfactual."
func additional_guards()->Dictionary:return {SelectionPath:FileAccess.get_sha256(SelectionPath)}
func inspection_prepare_workload(work)->void:
	var previous:Callable=work.network.region_finalizer
	work.network.region_finalizer=func(region:Dictionary)->Dictionary:
		var result:Dictionary=previous.call(region)
		if result.id==inspection_site():
			for edge:Dictionary in result.get("edges",[])+result.get("pocket_passages",[]):
				if str(edge.from)==str(selection.parent_id) and str(edge.to)==str(selection.room_id):actual_edge=edge;break
			if target_key=="default_crystal" and not actual_edge.is_empty():
				var points:PackedVector3Array=actual_edge.points;var distances:Array=[0.0]
				for index in range(1,points.size()):distances.append(float(distances[-1])+points[index-1].distance_to(points[index]))
				var best:int=-1;var error:float=INF
				for index in range(points.size()):
					var weight:float=float(Regions.along_edge(result.cave_biome_regions,str(actual_edge.from),str(actual_edge.to),distances[index],float(distances[-1])).weights.get("crystal",0));var current:float=absf(weight-.5)
					if current<error:error=current;best=index
				var first:int=best;var last:int=best
				while first>0 and distances[best]-distances[first-1]<=72:first-=1
				while last+1<points.size() and distances[last+1]-distances[best]<=72:last+=1
				window={"original_edge_length_m":distances[-1],"center_station_m":distances[best],"first_index":first,"last_index":last,"half_strength_error":error,"window_length_m":distances[last]-distances[first],"selected_before_native_physics":true};actual_edge=actual_edge.duplicate();actual_edge.points=points.slice(first,last+1)
		return result
func inspection_bounds(room:Dictionary,parent:Dictionary,_pool:Dictionary)->AABB:
	if target_key=="default_crystal" and not actual_edge.is_empty():
		var low_window:=Vector3.INF;var high_window:Vector3=-Vector3.INF
		for point:Vector3 in actual_edge.points:low_window=low_window.min(point-Vector3(14,6,14));high_window=high_window.max(point+Vector3(14,18,14))
		return AABB(low_window,high_window-low_window)
	var low:Vector3=room.point-Vector3(room.chamber_radius+10,6,room.chamber_radius+10);var high:Vector3=room.point+Vector3(room.chamber_radius+10,room.chamber_height+12,room.chamber_radius+10)
	low=low.min(parent.point-Vector3(parent.chamber_radius+10,6,parent.chamber_radius+10));high=high.max(parent.point+Vector3(parent.chamber_radius+10,parent.chamber_height+12,parent.chamber_radius+10))
	for point:Vector3 in actual_edge.get("points",PackedVector3Array()):low=low.min(point-Vector3(10,6,10));high=high.max(point+Vector3(10,14,10))
	return AABB(low,high-low)
func inspection_views(_data:Dictionary,_largest:Dictionary)->Array:
	check(not actual_edge.is_empty() and actual_edge.points.size()>2,"Exact original solved transition edge available")
	if actual_edge.is_empty():return []
	var points:PackedVector3Array=actual_edge.points;var views:Array=[]
	for fraction:float in [.1,.5,.9]:
		var index:int=clampi(roundi((points.size()-1)*fraction),0,points.size()-2);var next:int=mini(points.size()-1,index+4);views.append({"name":"transition_"+str(roundi(fraction*100)),"position":points[index]+Vector3.UP*1.8,"target":points[next]+Vector3.UP*2})
	return views
func inspection_routes(_data:Dictionary,_field)->Array:
	var route:Array=[]
	for point:Vector3 in actual_edge.get("points",PackedVector3Array()):route.append(point+Vector3.UP*.95)
	for index in range(route.size()-2,-1,-1):route.append(route[index])
	return [{"label":"Actual normal "+target_key+" solved edge and exact same-way ordinary return","points":route}]
func inspection_material_checks(data:Dictionary,nodes:Array,_camera:Camera3D,_light:OmniLight3D)->Dictionary:
	var frozen_nodes:int=0;var crystal_nodes:int=0;var ids:Dictionary={}
	for cell:Dictionary in data.cells:
		for id:String in cell.get("biome_ids",[]):ids[id]=true
	for node:Node in nodes:
		for child:Node in node.get_children():
			frozen_nodes+=int(child is MeshInstance3D and str(child.name).begins_with("CaveBiome_frozen_"));crystal_nodes+=int(child is MeshInstance3D and str(child.name).begins_with("CaveBiome_crystal_"))
	check(ids.has("crystal") and (crystal_nodes>0 or target_key=="default_crystal"),"Actual normal transition commits positive Crystal shader controls;core/overlap fixture also requires native minerals")
	if target_key=="frozen_crystal":check(ids.has("frozen"),"Actual compiled transition carries BOTH admitted Frozen and Crystal material adapters,not renamed Default")
	var material_control:Dictionary={}
	if target_key=="default_crystal":
		check(not window.is_empty() and window.window_length_m<=144 and window.half_strength_error<.1,"Same first original3988m edge,predeclared local half-strength window and unchanged short-walk budget")
		var materials:Dictionary={}
		for node:Node in nodes:
			if not node is MeshInstance3D or node.mesh==null:continue
			var material=node.mesh.surface_get_material(0)
			if not material is ShaderMaterial:continue
			for uniform:Dictionary in material.shader.get_shader_uniform_list():
				if str(uniform.name)=="cave_crystal_mineral_strength":materials[material]=material.get_shader_parameter("cave_crystal_mineral_strength");break
		var original:Image=await crystal_picture("local_transition_mineral_material_on")
		for material:ShaderMaterial in materials:material.set_shader_parameter("cave_crystal_mineral_strength",0.0)
		var off:Image=await crystal_picture("local_transition_mineral_material_off")
		for material:ShaderMaterial in materials:material.set_shader_parameter("cave_crystal_mineral_strength",materials[material])
		var restored:Image=await crystal_picture("local_transition_mineral_material_return");check(not materials.is_empty() and original.get_data()!=off.get_data(),"Actual localized host mineral material visibly changes under independent off control");check(original.get_data()==restored.get_data(),"Actual localized host mineral material returns exact original pixels");material_control={"native_materials":materials.size(),"visible":original.get_data()!=off.get_data(),"exact_return":original.get_data()==restored.get_data()}
	return {"original_inventory_ordinal":selection.original_ordinal,"normal_edge_length_m":selection.length_m,"bounded_transition_window":window,"local_material_counterfactual":material_control,"actual_material_ids":ids.keys(),"actual_frozen_mesh_nodes":frozen_nodes,"actual_crystal_mesh_nodes":crystal_nodes,"minimum_graph_weights":selection.minimum_weights,"maximum_graph_weights":selection.maximum_weights,"scope":"Actual natural graph transition material controls and native geometry counts. Frozen ice only forms where real groundwater permits;zero ice nodes is recorded honestly,not replaced by forced water. Existing partial-blend GPU proofs cover independent raw-weight material composition;this fixture adds actual native route imagery and ordinary two-way physics."}
func run()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("target="):target_key=arg.trim_prefix("target=")
	check(target_key in ["default_crystal","frozen_crystal"],"Explicit original transition target")
	var report=JSON.parse_string(FileAccess.get_file_as_string(SelectionPath));check(report is Dictionary and report.get("passed",false),"Complete source-bound normal transition inventory exists")
	if not report is Dictionary or not report.get("passed",false):quit(1);return
	for path:String in report.source_sha256:check(FileAccess.get_sha256(path)==report.source_sha256[path],"Unchanged original transition descriptor source "+path)
	selection=report.first_transitions.get(target_key,{});check(not selection.is_empty(),"Same original selected edge retained without replacement")
	if selection.is_empty() or not failures.is_empty():print("TRANSITION_NATIVE_PREFLIGHT ",failures);quit(1);return
	await super.run()
