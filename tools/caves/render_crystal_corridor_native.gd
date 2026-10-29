extends "res://tools/caves/render_crystal_normal_ravine.gd"
var corridor:Dictionary={}
var corridor_edge:Dictionary={}
func inspection_name()->String:return "crystal_corridor_native"
func additional_guards()->Dictionary:
	var guards:Dictionary=super.additional_guards();var parent_path:String="res://tools/caves/render_crystal_normal_ravine.gd";guards[parent_path]=FileAccess.get_sha256(parent_path);guards[get_script().resource_path]=FileAccess.get_sha256(get_script().resource_path);return guards
func inspection_views(data:Dictionary,largest:Dictionary)->Array:
	var views:Array=super.inspection_views(data,largest)
	for item:Dictionary in data.placements:
		if not item.get("corridor_crystal",false):continue
		var parts:PackedStringArray=str(item.id).split("/")
		if parts.size()<4 or (parts[1]!=str(data.room.id) and parts[2]!=str(data.room.id)):continue
		if corridor.is_empty() or item.root.distance_to(data.room.point)<corridor.root.distance_to(data.room.point):corridor=item
	check(not corridor.is_empty(),"First normal ravine has actual incident-edge crystal growth,not another room's mineral label")
	if not corridor.is_empty():
		var parts:PackedStringArray=str(corridor.id).split("/")
		for region:Dictionary in data.bundle.regions:
			for edge:Dictionary in region.get("edges",[])+region.get("pocket_passages",[]):
				if str(edge.get("from",""))==parts[1] and str(edge.get("to",""))==parts[2]:corridor_edge=edge
		var axis:Vector3=corridor.axis;views.append({"name":"incident_corridor_crystal","position":corridor.root+axis*(corridor.height+2),"target":corridor.root+axis*corridor.height*.5})
	return views
func inspection_routes(data:Dictionary,field)->Array:
	var routes:Array=super.inspection_routes(data,field);check(not corridor_edge.is_empty(),"Selected corridor growth belongs to a real original connected graph edge")
	if not corridor_edge.is_empty():
		var points:Array=[]
		for point:Vector3 in corridor_edge.points:points.append(point+Vector3.UP*.95)
		if str(corridor_edge.to)==str(data.room.id):points.reverse()
		var outward:Array=points.duplicate()
		for index in range(outward.size()-2,-1,-1):points.append(outward[index])
		routes.append({"label":"Actual incident mineral-bearing passage and exact same-way return","points":points})
	return routes
func inspection_material_checks(_data:Dictionary,nodes:Array,_camera:Camera3D,_light:OmniLight3D)->Dictionary:
	if corridor.is_empty():return {}
	var originals:Dictionary={};var old_threshold:float=inspection.mesh_lod_threshold;inspection.mesh_lod_threshold=0;var original:Image=await crystal_picture("selected_corridor_geometry_on");var hidden_triangles:int=0
	for node:MeshInstance3D in nodes:
		if Vector3i(node.position/64)!=corridor.owner:continue
		for child:Node in node.get_children():
			if not child is MeshInstance3D or not str(child.name).begins_with("CaveBiome_crystal_") or not str(child.name).contains(str(corridor.batch)):continue
			var mesh:ArrayMesh=child.mesh;check(mesh!=null and mesh.get_surface_count()==1,"Actual corridor batch has one inspectable native surface")
			if mesh==null or mesh.get_surface_count()!=1:continue
			var arrays:Array=mesh.surface_get_arrays(0);var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX];var keep:=PackedInt32Array()
			if indices.is_empty():
				for index in range(arrays[Mesh.ARRAY_VERTEX].size()):indices.append(index)
			for index:int in indices:
				if index<corridor.first_vertex or index>=corridor.first_vertex+corridor.vertex_count:keep.append(index)
			check((indices.size()-keep.size())%3==0,"Selected mineral removed as complete native triangles")
			hidden_triangles+=(indices.size()-keep.size())/3;originals[child]={"mesh":mesh,"visible":child.visible}
			if keep.is_empty():child.visible=false
			else:
				arrays[Mesh.ARRAY_INDEX]=keep;var filtered:=ArrayMesh.new();filtered.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);filtered.surface_set_material(0,mesh.surface_get_material(0));child.mesh=filtered
	var off:Image=await crystal_picture("selected_corridor_geometry_off")
	for child:MeshInstance3D in originals:child.mesh=originals[child].mesh;child.visible=originals[child].visible
	var restored:Image=await crystal_picture("selected_corridor_geometry_return");inspection.mesh_lod_threshold=old_threshold;check(hidden_triangles>0 and original.get_data()!=off.get_data(),"EXACT new incident corridor crystal is visible in actual native scene,not only other existing room formations");check(original.get_data()==restored.get_data(),"Exact full native scene restoration after selected-root triangle-only counterfactual")
	return {"selected_corridor":corridor,"hidden_native_triangles":hidden_triangles,"visible":original.get_data()!=off.get_data(),"exact_return":original.get_data()==restored.get_data(),"scope":"Only selected new root triangles hidden in existing native batches;original vertices/materials/scene/colliders/settings remain. All original meshes restored. Original full protected route and real incident edge receive ordinary two-way capsule walks."}
