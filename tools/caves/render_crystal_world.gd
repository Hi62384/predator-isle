extends "res://tools/caves/render_frozen_world.gd"
const Crystal=preload("res://scripts/caves/crystal_features.gd")
const InspectionScope=preload("res://tools/caves/inspection_scope.gd")
var inspection:SubViewport
func inspection_name()->String:return "crystal_world"
func inspection_host()->String:return "crystal_wastes"
func inspection_seed()->int:return 73921
func inspection_site()->Vector2i:return Vector2i(6,-2)
func additional_guards()->Dictionary:return {}
func inspection_material_checks(_data:Dictionary,_nodes:Array,_camera:Camera3D,_light:OmniLight3D)->Dictionary:return {}
func selected_room_id()->String:return "6:-2:1:2:lobe:1"
func selected_pool_id()->String:return ""
func selection_label()->String:return "FIRST positive normal Crystal anchor"
func inspection_cohort_label()->String:return "126case"
func inspection_configuration()->Resource:return Config.new()
func inspection_definition()->Resource:return load("res://config/caves/biomes/crystal_cave_definition.tres")
func inspection_control_scope()->String:return ""
func inspection_prepare_workload(_work)->void:pass
func inspection_requires_mineral_prisms()->bool:return true
func inspection_parent_id(room:Dictionary)->String:return str(room.get("parent",""))
func inspection_bounds(room:Dictionary,parent:Dictionary,pool:Dictionary)->AABB:
	var low:Vector3=room.point-Vector3(room.chamber_radius+10,6,room.chamber_radius+10);var high:Vector3=room.point+Vector3(room.chamber_radius+10,room.chamber_height+12,room.chamber_radius+10)
	if not parent.is_empty():low=low.min(parent.point-Vector3(10,4,10));high=high.max(parent.point+Vector3(10,12,10))
	if not pool.is_empty():low=low.min(pool.center-Vector3(pool.radius+3,6,pool.radius+3));high=high.max(pool.center+Vector3(pool.radius+3,10,pool.radius+3))
	for bank:Dictionary in pool.get("bank_lobes",[]):low=low.min(bank.point-Vector3(bank.chamber_radius+10,6,bank.chamber_radius+10));high=high.max(bank.point+Vector3(bank.chamber_radius+10,bank.chamber_height+12,bank.chamber_radius+10))
	return AABB(low,high-low)
func inspection_routes(data:Dictionary,_field)->Array:
	return [{"label":"First actual normal Crystal parent/flat neck/chamber and same-way dry return","points":[data.parent.point+Vector3(0,.95,0),data.room.point+Vector3(0,.95,0),data.parent.point+Vector3(0,.95,0)]}]
func inspection_views(data:Dictionary,largest:Dictionary)->Array:
	var center:Vector3=data.room.point
	return [{"name":"first_actual_room","position":center+Vector3(0,1.8,0),"target":largest.bounds.get_center() if not largest.is_empty() else center+Vector3(10,5,10)},{"name":"actual_neck","position":data.parent.point+Vector3(0,1.8,0),"target":center+Vector3(0,4,0)}]
func crystal_picture(label:String)->Image:
	for frame in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=inspection.get_texture().get_image();check(image.get_size()==Vector2i(1280,720),"Native normal Crystal world fixed1280x720 render target");var path:String="res://tools/biome_extensions/artifacts/cave_"+inspection_name()+"_"+label+".png";check(image.save_png(path)==OK,"Actual normal-settings Crystal world image "+label);captures[path]=FileAccess.get_sha256(path);return image
func run()->void:
	assert(DisplayServer.get_name()!="headless");var guards:Dictionary=FrozenFixture.guards();guards.merge(additional_guards());var unrelated_before:Dictionary=InspectionScope.observations();guards["res://tools/caves/inspection_scope.gd"]=FileAccess.get_sha256("res://tools/caves/inspection_scope.gd")
	InspectionScope.capture_terrain_dependencies(guards)
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):
				var path:String=folder+"/"+name
				if InspectionScope.is_dependency(path):guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/render_crystal_world.gd","res://tools/caves/render_frozen_world.gd","res://tools/caves/check_frozen_world_cohort.gd","res://tools/biome_extensions/route_probe.gd","res://config/caves/biomes/crystal_cave_definition.tres","res://scenes/main.tscn"]:guards[path]=FileAccess.get_sha256(path)
	check(InspectionScope.dependency_closure_valid(guards),"All cave/terrain shader dependencies remain guarded")
	var config:Resource=inspection_configuration();var definition:Resource=inspection_definition();config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var seed_id:int=inspection_seed();var site:Vector2i=inspection_site();var b=owner(inspection_host(),seed_id);var work=Workload.new();check(work.configure(b.settings,config,seed_id,0),"Same preselected normal-settings host/seed/site,not a controlled forced-full-weight room");inspection_prepare_workload(work);var output:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		var bundle:Dictionary=work.discover(site);var room:Dictionary={};var parent:Dictionary={};var pool:Dictionary={}
		for region:Dictionary in bundle.regions:
			if region.id!=site:continue
			for body:Dictionary in region.get("pools",[]):
				if str(body.id)==selected_pool_id():pool=body
			for node:Dictionary in region.nodes+region.get("pockets",[]):
				if str(node.id)==selected_room_id():room=node
			for node:Dictionary in region.nodes+region.get("pockets",[]):
				if str(node.id)==inspection_parent_id(room):parent=node
		var cells:Array=[];var placements:Array=[];var statistics:Array=[];var bounds:AABB=inspection_bounds(room,parent,pool);var low:Vector3=bounds.position;var high:Vector3=bounds.end
		var first:Vector3i=work.field.cell(low);var last:Vector3i=work.field.cell(high)
		for z in range(first.z,last.z+1):
			for y in range(first.y,last.y+1):
				for x in range(first.x,last.x+1):
					var key:=Vector3i(x,y,z);var cell:Dictionary=work.build_cell(key);cells.append(cell);var details:Dictionary=Crystal.new().build(work.field,key,seed_id,bundle.regions,definition.feature_configuration,cell.water);placements.append_array(details.placements);statistics.append({"key":str(key),"valid":cell.valid,"batches":cell.get("features",[]).size(),"placements":details.placements.size(),"water_vertices":0 if cell.water.arrays.is_empty() else cell.water.arrays[Mesh.ARRAY_VERTEX].size(),"water_ids":cell.water.ids,"water_rejections":cell.water.get("rejection_reasons",{})})
		output.append({"bundle":bundle,"room":room,"parent":parent,"pool":pool,"cells":cells,"placements":placements,"statistics":statistics})
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);check(output.size()==1 and not output[0].room.is_empty() and not output[0].parent.is_empty(),"Same actual first positive Crystal lobe and original connected parent remain")
	if output.is_empty() or output[0].room.is_empty():quit(1);return
	var data:Dictionary=output[0];var stream=Streamer.new();stream.configuration=config;stream._bundle=data.bundle;var nodes:Array=[];var cells:Dictionary={};var rock_vertices:int=0;var mineral_vertices:int=0;var crystal_forms:int=0;var veins:int=0;var largest:Dictionary={};var water_vertices:int=0;var water_ids:Array=[]
	inspection=SubViewport.new();inspection.size=Vector2i(1280,720);inspection.own_world_3d=false;inspection.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(inspection)
	for cell:Dictionary in data.cells:
		check(cell.valid,"Actual normal-world numeric cell accepted");var node:=MeshInstance3D.new();node.position=Vector3(cell.key)*64;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED;var material:ShaderMaterial=stream.material_for(cell.key,cell.get("biome_ids",[]));check(material!=null,"Actual normal-world material adapter positive");var body:=StaticBody3D.new();body.name="CaveCollision";body.collision_layer=1;body.collision_mask=0;node.add_child(body)
		if not cell.arrays.is_empty():
			var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,cell.arrays);mesh.surface_set_material(0,material);node.mesh=mesh;rock_vertices+=cell.arrays[Mesh.ARRAY_VERTEX].size();var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(cell.arrays[Mesh.ARRAY_VERTEX]);child.shape=shape;body.add_child(child)
		check(FeatureRenderer.attach(node,cell.get("features",[]),config.biome_regions,true,true),"Actual Crystal native geometry and selective collision committed with rock cell")
		for batch:Dictionary in cell.get("features",[]):mineral_vertices+=batch.arrays[Mesh.ARRAY_VERTEX].size()
		var water_node:MeshInstance3D=WaterRenderer.attach(node,cell.water)
		if not cell.water.arrays.is_empty():water_vertices+=cell.water.arrays[Mesh.ARRAY_VERTEX].size();water_ids.append_array(cell.water.ids)
		if water_node!=null:var material_copy:ShaderMaterial=water_node.mesh.surface_get_material(0).duplicate();var water_shader:Shader=material_copy.shader.duplicate();water_shader.code=water_shader.code.replace("TIME","0.0");material_copy.shader=water_shader;water_node.material_override=material_copy
		Frontiers.attach(node,cell.get("frontiers",{}),material,true);root.add_child(node);nodes.append(node);cells[cell.key]=node
	for placement:Dictionary in data.placements:
		if placement.kind=="crystal":
			crystal_forms+=1
			if largest.is_empty() or placement.height>largest.height:largest=placement
		elif placement.kind=="mineral_vein":veins+=1
	if not selected_pool_id().is_empty():check(water_vertices>0 and water_ids.has(selected_pool_id()),"EXACT selected normal retained pool has a positive actual clipped native water mesh,not merely pool metadata")
	Frontiers.synchronize(cells);var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.remove_child(terrain);terrain.free();check(InspectionScope.isolate_environment(scene),"Inspection-only character branch detached before ready;user main scene unchanged");var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;inspection.add_child(scene);scene.get_node("Interface").hide();var light:=OmniLight3D.new();light.omni_range=120;light.light_energy=4;light.shadow_enabled=true;inspection.add_child(light)
	var center:Vector3=data.room.point;var views:Array=inspection_views(data,largest);var records:Array=[];var visible:bool=false
	for view:Dictionary in views:
		camera.position=view.position;camera.look_at(view.target);check(work.field.sample(camera.position)<-.2,"Camera lies in actual normal generated cave air");light.position=camera.position+Vector3(0,.5,0);light.visible=false;await crystal_picture(view.name+"_natural");light.visible=true;var original:Image=await crystal_picture(view.name+"_test_only_light")
		for node:Node in nodes:
			for child:Node in node.get_children():
				if str(child.name).begins_with("CaveBiome_"):child.visible=false
		var off:Image=await crystal_picture(view.name+"_mineral_geometry_off");visible=visible or original.get_data()!=off.get_data()
		for node:Node in nodes:
			for child:Node in node.get_children():
				if str(child.name).begins_with("CaveBiome_"):child.visible=true
		var restored:Image=await crystal_picture(view.name+"_mineral_geometry_return");check(original.get_data()==restored.get_data(),"Same native normal generated mineral scene exact image return");records.append({"name":view.name,"position":str(camera.position),"target":str(view.target)})
	if inspection_requires_mineral_prisms():check(crystal_forms>0 and mineral_vertices>0 and visible,"Actual normal generated crystal prisms are visible,not only vein bars or biome metadata")
	else:check(rock_vertices>0,"Localized mineralization-transition fixture contains positive native host rock;its own visible material counterfactual is required separately")
	var material_checks:Dictionary=await inspection_material_checks(data,nodes,camera,light)
	await physics_frame;await physics_frame;var walks:Array=[]
	for route:Dictionary in inspection_routes(data,work.field):
		var points:Array[Vector3]=[]
		for point:Vector3 in route.points:points.append(point)
		walks.append(await walk(points,route.label))
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable original actual Crystal world source "+path)
	var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"selection":selection_label(),"seed":seed_id,"host":inspection_host(),"original_site":[site.x,site.y],"room_id":data.room.id,"parent_id":data.parent.id,"pool":data.pool,"room_center":str(center),"cell_statistics":data.statistics,"native_cells":cells.size(),"rock_vertices":rock_vertices,"mineral_vertices":mineral_vertices,"actual_crystal_prisms":crystal_forms,"vein_segments":veins,"largest_actual_crystal":largest,"views":records,"walks":walks,"engine_fixed_fps_marker":OS.get_environment("PREDATOR_TEST_ENGINE_FIXED_FPS"),"scope":selection_label()+" from full normal18percent/.65density"+inspection_cohort_label()+" cohort,all its negatives retained. Complete canonical field/actual native worker rock/crystal/vein/colliders/frontiers and retained-water renderer. Original main sky/sun/fog/camera50km,explicit TEST-ONLY120m4energy light,natural/geometry-off/exactreturn at fixed1280x720 target. Ordinary no-jump measured routes and same-way dry return,preloaded/fixed-fps acceleration clearly separate from full live streaming/FPS or reference-art/all-user completion. Saved registry remains Default+Frozen/root disabled."}
	report["evidence_dependency_scope"]=InspectionScope.description();report["unrelated_character_shader_observations"]={"before":unrelated_before,"after":InspectionScope.observations()}
	report["material_checks"]=material_checks
	if not inspection_control_scope().is_empty():report["scope"]=selection_label()+" "+inspection_control_scope()+" Actual shared procedural field/native rock/mineral/water/frontier/collision output,original main environment and explicit test-only lamp,ordinary same-way capsule walks. No normal-frequency/FPS/reference-art/all-user completion claim. Saved registry remains Default+Frozen/root disabled."
	FileAccess.open("res://tools/biome_extensions/artifacts/render_cave_"+inspection_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("CRYSTAL_WORLD_NATIVE ",inspection_name()," ",checks," crystals=",crystal_forms," veins=",veins," walks=",walks," failures=",failures)
	for node:Node in nodes:node.queue_free()
	stream.free();inspection.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
