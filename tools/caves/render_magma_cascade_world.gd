extends "res://tools/caves/render_magma_intrusive_world.gd"
func index_path()->String:return "res://tools/biome_extensions/artifacts/check_cave_magma_cascade_index.json"
func selected_case(catalogue:Dictionary)->Dictionary:
	var row:Dictionary=catalogue.first_diagnostic
	if row.is_empty():return {}
	return {"ordinal":catalogue.cases.find(row),"host":row.host,"seed":int(row.seed),"site":row.site,"rooms":[{"room":{"id":str(row.pool_id).trim_suffix(":seepage")}}],"pool_id":row.pool_id}
func world_definition()->Resource:
	var definition:Resource=load("res://config/caves/biomes/magma_cave_definition.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);definition.feature_configuration.molten_cascade_chance=1.0;return definition
func report_basename()->String:return "render_cave_magma_cascade_world"
func capture_prefix()->String:return "magma_cascade_world"
func world_guards()->Dictionary:return {"res://tools/caves/render_magma_cascade_world.gd":FileAccess.get_sha256("res://tools/caves/render_magma_cascade_world.gd")}
func additional_native_checks(data:Dictionary,nodes:Array,camera:Camera3D,light:OmniLight3D)->Dictionary:
	check(data.pool.has("molten_cascade"),"Original fixed actual source-backed cascade survives normal neighbouring bundle")
	if not data.pool.has("molten_cascade"):return {}
	var cascade:Dictionary=data.pool.molten_cascade;var radial:Vector3=((data.pool.center-data.room.point)*Vector3(1,0,1)).normalized();var target:Vector3=cascade.bounds.get_center();var camera_before:Transform3D=camera.transform;var light_before:Transform3D=light.transform
	camera.position=target-radial*8+radial.cross(Vector3.UP)*3+Vector3.UP*1.5;camera.look_at(target);light.position=camera.position+Vector3.UP*.5
	var before:Image=await capture("supported_lip_and_short_fall_test_lamp");var selected:MeshInstance3D;var original:Mesh
	for node:Node in nodes:
		var child=node.get_node_or_null("CaveBiome_magma_molten_volcanic")
		if child==null or not child.get_meta("source_basins",[]).has(data.pool.id):continue
		var arrays:Array=child.mesh.surface_get_arrays(0);var count:int=cascade.vertices.size();var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var matches:bool=vertices.size()>=count
		if matches:
			for index in range(count):
				if vertices[vertices.size()-count+index]!=cascade.vertices[index]-node.position:matches=false;break
		check(matches,"Whole original cascade equals exact appended numeric suffix before isolated counterfactual")
		if not matches:continue
		original=child.mesh;selected=child
		for channel:int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:arrays[channel].resize(arrays[channel].size()-count)
		# Native ArrayMesh readback can include generated four-float tangents.
		if arrays[Mesh.ARRAY_TANGENT]!=null and not arrays[Mesh.ARRAY_TANGENT].is_empty():arrays[Mesh.ARRAY_TANGENT].resize(arrays[Mesh.ARRAY_TANGENT].size()-count*4)
		check(arrays[Mesh.ARRAY_INDEX]==null or arrays[Mesh.ARRAY_INDEX].is_empty(),"Original molten batch has no hidden index remap")
		var without:=ArrayMesh.new();without.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);without.surface_set_material(0,original.surface_get_material(0));child.mesh=without;break
	check(is_instance_valid(selected),"Actual uploaded original-source cascade selected")
	var off:Image=await capture("only_cascade_off_pool_retained")
	if is_instance_valid(selected):selected.mesh=original
	var returned:Image=await capture("cascade_exact_return");check(before.get_data()!=off.get_data() and before.get_data()==returned.get_data(),"Actual cascade independently visible while retained pool remains,with exact image return")
	var seen:Dictionary={};var rays:int=0;var maximum_gap:float=0
	for index in range(cascade.vertices.size()):
		var point:Vector3=cascade.vertices[index]
		if point.y<=cascade.supported_lip_height+.05 or seen.has(point):continue
		seen[point]=true;var axis:Vector3=cascade.normals[index];var hit:Dictionary=nodes[0].get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+axis*.5,point-axis*1.5,1));check(not hit.is_empty(),"Actual native rock backs the upper molten film")
		if not hit.is_empty():maximum_gap=maxf(maximum_gap,hit.position.distance_to(point));rays+=1
	check(rays>0 and maximum_gap<=.35,"Whole upper film has real2m-lattice native support within35cm,not scalar-only contact")
	camera.transform=camera_before;light.transform=light_before;return {"native_backing_rays":rays,"maximum_native_gap_m":maximum_gap,"free_fall_height_m":cascade.free_fall_height,"cascade_only_counterfactual":before.get_data()!=off.get_data()}
func scope_description()->String:return "Exact first diagnostic cascade among all eight original source-backed molten pools;all16normal6percent/diagnostic100percent outcomes retained. ONLY cascade chance is100percent;normal biome/source/molten/lake controls unchanged. Actual neighbouring production volume,retained pool plus supported film/short air fall,isolated cascade-only pixel counterfactual with pool retained and exact return,whole upper-film native rock rays and original protected passage return. Dedicated lava clock frozen only for diagnostic pixels/test-only lamp. Not normal-frequency cascade occurrence,full live cascade traversal,FPS or reference-art acceptance."
