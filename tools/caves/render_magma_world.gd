extends "res://tools/caves/render_frozen_world.gd"
const Magma=preload("res://scripts/caves/magma_features.gd")
const Scope=preload("res://tools/caves/inspection_scope.gd")
var viewport:SubViewport
func index_path()->String:return "res://tools/biome_extensions/artifacts/check_cave_magma_world_index.json"
func selected_case(catalogue:Dictionary)->Dictionary:return catalogue.first_cooled
func selected_pool_id(_selected:Dictionary)->String:return ""
func report_basename()->String:return "render_cave_magma_world"
func capture_prefix()->String:return "magma_world"
func visibility_prefix()->String:return "CaveBiome_magma_"
func requires_cooled_forms()->bool:return true
func requires_geometry_counterfactual()->bool:return true
func native_bounds(room:Dictionary,pool:Dictionary,route:Array[Vector3])->AABB:
	var low:Vector3=room.point-Vector3(room.chamber_radius+8,5,room.chamber_radius+8);var high:Vector3=room.point+Vector3(room.chamber_radius+8,room.chamber_height+8,room.chamber_radius+8)
	for bank:Dictionary in pool.get("bank_lobes",[]):low=low.min(bank.point-Vector3(bank.chamber_radius+8,6,bank.chamber_radius+8));high=high.max(bank.point+Vector3(bank.chamber_radius+8,bank.chamber_height+8,bank.chamber_radius+8))
	for point:Vector3 in route:low=low.min(point-Vector3(6,5,6));high=high.max(point+Vector3(6,10,6))
	return AABB(low,high-low)
func world_configuration()->Resource:return Config.new()
func world_definition()->Resource:return load("res://config/caves/biomes/magma_cave_definition.tres")
func additional_routes(_data:Dictionary)->Array:return []
func local_route_limit()->float:return 60.0
func chosen_route_edge(region:Dictionary,room_id:String)->Dictionary:
	for edge:Dictionary in region.get("edges",[])+region.get("pocket_passages",[]):
		if not edge.entrance and (str(edge.from)==room_id or str(edge.to)==room_id):return edge
	return {}
func additional_native_checks(_data:Dictionary,_nodes:Array,_camera:Camera3D,_light:OmniLight3D)->Dictionary:return {}
func world_guards()->Dictionary:return {}
func scope_description()->String:return "Exact first normal cooled room from full144case inventory;actual neighbouring bundle,shared native worker/material/feature renderer/collision/frontiers;original main environment and explicit test-only lamp;geometry-off/exact-return images and localized original passage return. Preloaded fixed-fps test,not full live streaming/FPS,normal molten scene,reference art or all-user completion."
func capture(label:String)->Image:
	for frame in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=viewport.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/cave_"+capture_prefix()+"_"+label+".png";check(image.save_png(path)==OK,"Fixed native Magma capture "+label);captures[path]=FileAccess.get_sha256(path);return image
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	var catalogue_path:String=index_path();var catalogue:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(catalogue_path));check(catalogue.passed,"Complete predeclared catalogue passed")
	var guards:Dictionary=FrozenFixture.guards();guards.merge(world_guards());guards[catalogue_path]=FileAccess.get_sha256(catalogue_path);Scope.capture_terrain_dependencies(guards)
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			var path:String=folder+"/"+name
			if (name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc")) and Scope.is_dependency(path):guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/render_magma_world.gd","res://tools/caves/render_magma_intrusive_world.gd","res://tools/caves/render_magma_large_lake_world.gd","res://tools/caves/render_frozen_world.gd","res://tools/caves/check_frozen_world_cohort.gd","res://tools/biome_extensions/route_probe.gd","res://tools/caves/inspection_scope.gd","res://config/caves/biomes/magma_cave_definition.tres","res://scenes/main.tscn","res://materials/mountain_color_massive_rock.res","res://materials/cave_normal_Rock051.res","res://data/cave_material_sources.json"]:guards[path]=FileAccess.get_sha256(path)
	var selected:Dictionary=selected_case(catalogue);check(not selected.is_empty(),"Original selected normal case exists")
	if selected.is_empty():quit(1);return
	var room_id:String=selected.rooms[0].room.id;var site:=Vector2i(selected.site[0],selected.site[1]);var config:Resource=world_configuration();var definition:Resource=world_definition();config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var b=owner(selected.host,selected.seed);var work=Workload.new();check(work.configure(b.settings,config,selected.seed,0),"Original fixed site/seed/host controls configure;any diagnostic profile override explicitly declared")
	var volcanic_material:ShaderMaterial=definition.surface_provider.new().feature_material("cooled_volcanic",definition.material_configuration,false)
	for parameter:String in ["volcanic_color","volcanic_normal"]:
		var texture=volcanic_material.get_shader_parameter(parameter);check(texture is Texture2D and texture.get_width()==2048 and texture.get_height()==2048,"Actual shader binds real2048 PBR Texture2D,not an Image/default sampler "+parameter)
	var outputs:Array=[];var task:int=WorkerThreadPool.add_task(func()->void:
		var bundle:Dictionary=work.discover(site);var room:Dictionary={};var original_region:Dictionary={};var pool:Dictionary={}
		for region:Dictionary in bundle.regions:
			if region.id!=site:continue
			original_region=region
			for candidate:Dictionary in region.get("pools",[]):
				if str(candidate.id)==selected_pool_id(selected):pool=candidate
			for node:Dictionary in region.get("nodes",[])+region.get("pockets",[]):
				if str(node.id)==room_id:room=node
		var route:Array[Vector3]=[];var chosen_edge:Dictionary={}
		if not room.is_empty():
			# Pre-physics localized prefix of first original connected passage.
			chosen_edge=chosen_route_edge(original_region,room_id)
			if not chosen_edge.is_empty():
				var points:PackedVector3Array=chosen_edge.points.duplicate()
				if str(chosen_edge.to)==room_id:points.reverse()
				var distance:float=0
				for i in range(points.size()):
					if i>0:distance+=points[i-1].distance_to(points[i])
					if distance>local_route_limit():break
					route.append(points[i]+Vector3(0,.95,0))
				var outbound:int=route.size()
				for i in range(outbound-2,-1,-1):route.append(route[i])
		var cells:Array=[];var placements:Array=[]
		if not room.is_empty():
			var bounds:AABB=native_bounds(room,pool,route);var low:Vector3=bounds.position;var high:Vector3=bounds.end
			var first:Vector3i=work.field.cell(low);var last:Vector3i=work.field.cell(high)
			for z in range(first.z,last.z+1):
				for y in range(first.y,last.y+1):
					for x in range(first.x,last.x+1):
						var key:=Vector3i(x,y,z);var cell:Dictionary=work.build_cell(key);cells.append(cell);placements.append_array(definition.feature_provider.new().build(work.field,key,selected.seed,bundle.regions,definition.feature_configuration,cell.water).placements)
		outputs.append({"bundle":bundle,"room":room,"pool":pool,"cells":cells,"placements":placements,"route":route,"edge":chosen_edge})
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);check(outputs.size()==1 and not outputs[0].room.is_empty(),"Exact original first normal admitted room survives actual neighbour bundle")
	if outputs.is_empty() or outputs[0].room.is_empty():quit(1);return
	var data:Dictionary=outputs[0];var stream=Streamer.new();stream.configuration=config;stream._bundle=data.bundle;var nodes:Array=[];var cells:Dictionary={};var forms:int=0;var largest:Dictionary={};var vertices:int=0;var molten_vertices:int=0
	viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=false;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	for cell:Dictionary in data.cells:
		check(cell.valid,"Actual normal native Magma cell valid");var node:=MeshInstance3D.new();node.position=Vector3(cell.key)*64;var material:ShaderMaterial=stream.material_for(cell.key,cell.get("biome_ids",[]));check(material!=null,"Actual weighted host/Magma material adapter");var body:=StaticBody3D.new();body.name="CaveCollision";body.collision_layer=1;node.add_child(body)
		if not cell.arrays.is_empty():
			var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,cell.arrays);mesh.surface_set_material(0,material);node.mesh=mesh;var collision:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(cell.arrays[Mesh.ARRAY_VERTEX]);collision.shape=shape;body.add_child(collision)
		check(FeatureRenderer.attach(node,cell.get("features",[]),config.biome_regions,false,true),"Shared atomic renderer uploads actual Magma geometry and collision")
		for batch:Dictionary in cell.get("features",[]):
			if batch.biome_id=="magma":vertices+=batch.arrays[Mesh.ARRAY_VERTEX].size()
			if batch.get("kind","")=="molten_volcanic":molten_vertices+=batch.arrays[Mesh.ARRAY_VERTEX].size()
		for child:Node in node.get_children():
			if str(child.name)=="CaveBiome_magma_molten_volcanic":
				var material_lava:ShaderMaterial=child.mesh.surface_get_material(0);material_lava.set_shader_parameter("lava_time_override",0.0)
		if not selected_pool_id(selected).is_empty():check(not cell.water.ids.has(selected_pool_id(selected)),"Selected actual molten basin never rendered as freshwater")
		Frontiers.attach(node,cell.get("frontiers",{}),material,true);root.add_child(node);nodes.append(node);cells[cell.key]=node
	Frontiers.synchronize(cells)
	for placement:Dictionary in data.placements:
		forms+=1
		if largest.is_empty() or placement.height>largest.height:largest=placement
	var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.remove_child(terrain);terrain.free();check(Scope.isolate_environment(scene),"Inspection-only character isolation preserves concurrent user branch");viewport.add_child(scene);scene.get_node("Interface").hide();var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);camera.position=data.room.point+Vector3(0,1.8,0);camera.look_at(largest.bounds.get_center() if not largest.is_empty() else data.room.point+Vector3(10,4,0));var light:=OmniLight3D.new();light.omni_range=120;light.light_energy=4;light.shadow_enabled=true;light.position=camera.position+Vector3.UP*.5;viewport.add_child(light)
	if not selected_pool_id(selected).is_empty():
		check(not data.pool.is_empty() and molten_vertices>0,"Exact selected normal molten basin has a positive actual clipped native mesh")
		if not data.pool.is_empty():
			camera.look_at(Vector3(data.pool.center.x,data.pool.water_y,data.pool.center.z));var actual_source:Dictionary=work._magma_heat.sample(Vector3(data.pool.center.x,data.pool.water_y,data.pool.center.z));check(actual_source.heat>=.5 and actual_source.get("id","")==data.pool.thermal_source,"Exact native molten basin retains actual canonical geological source witness")
	check(work.field.sample(camera.position)<-.2,"Camera in actual generated cave air");light.visible=false;await capture("natural");light.visible=true;var before:Image=await capture("test_only_lamp")
	for node:Node in nodes:
		for child:Node in node.get_children():
			if str(child.name).begins_with(visibility_prefix()):child.visible=false
	var off:Image=await capture("volcanic_geometry_off")
	for node:Node in nodes:
		for child:Node in node.get_children():
			if str(child.name).begins_with(visibility_prefix()):child.visible=true
	var returned:Image=await capture("volcanic_geometry_return");check(before.get_data()==returned.get_data() and (not requires_geometry_counterfactual() or (before.get_data()!=off.get_data() and (forms>0 or not requires_cooled_forms()) and vertices>0)),"Exact geometry-off/return;positive volcanic geometry required by geometry fixtures")
	data["largest"]=largest;var native_checks:Dictionary=await additional_native_checks(data,nodes,camera,light)
	await physics_frame;await physics_frame;check(data.route.size()>=3,"Original connected route has positive localized prefix");var walks:Array=[]
	if data.route.size()>=3:walks.append(await walk(data.route,"First normal cooled Magma original60m passage prefix and same-way return"))
	for extra:Dictionary in additional_routes(data):walks.append(await walk(extra.points,extra.label))
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable normal Magma native source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/"+report_basename()+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"original_ordinal":selected.ordinal,"host":selected.host,"seed":selected.seed,"site":selected.site,"room_id":room_id,"forms":forms,"vertices":vertices,"native_cells":data.cells.size(),"largest":largest,"walks":walks,"pool":data.pool,"molten_vertices":molten_vertices,"native_checks":native_checks,"molten_clock_frozen_for_pixels":true,"scope":scope_description()},"  "));print("MAGMA_NATIVE_WORLD ",checks," forms=",forms," walks=",walks," failures=",failures)
	for node:Node in nodes:node.queue_free()
	stream.free();viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
