extends "res://tools/caves/check_frozen_world_cohort.gd"
const Streamer=preload("res://scripts/caves/streamer.gd")
const Frontiers=preload("res://scripts/caves/stream_frontiers.gd")
const FeatureRenderer=preload("res://scripts/caves/feature_renderer.gd")
const WaterRenderer=preload("res://scripts/caves/water_renderer.gd")
var captures:Dictionary={}
func walk_probe_script()->Script:return preload("res://tools/biome_extensions/route_probe.gd")
func walk_extra_details(_walker)->Dictionary:return {}
func picture(label:String)->Image:
	for frame in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/cave_frozen_world_"+label+".png";check(image.save_png(path)==OK,"Actual normal-world Frozen capture "+label);captures[path]=FileAccess.get_sha256(path);return image
func walk(route:Array[Vector3],label:String)->Dictionary:
	var walker:=CharacterBody3D.new();walker.set_script(walk_probe_script());walker.set_physics_process(false);walker.floor_snap_length=.6;var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8;var child:=CollisionShape3D.new();child.shape=capsule;walker.add_child(child);root.add_child(walker);walker.set_physics_process(false);walker.position=route[0];walker.route=route
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=walker.global_transform;query.exclude=[walker.get_rid()];check(walker.get_world_3d().direct_space_state.intersect_shape(query,8).is_empty(),label+" original ordinary capsule start has no overlap")
	var started:int=Time.get_ticks_usec()
	for frame in range(18000):
		walker._physics_process(1.0/60);await physics_frame
		if walker.failed or walker.finished or Time.get_ticks_usec()-started>120000000:break
	var probe:Array=[];var state:PhysicsDirectSpaceState3D=walker.get_world_3d().direct_space_state
	for offset:int in range(-6,7):
		var direction:Vector3=(route[mini(walker.waypoint,route.size()-1)]-walker.position)*Vector3(1,0,1);direction=direction.normalized();var p:Vector3=walker.position+direction*offset*.25;var ray:=PhysicsRayQueryParameters3D.create(p+Vector3(0,3,0),p-Vector3(0,5,0),1);ray.exclude=[walker.get_rid()];var hit:Dictionary=state.intersect_ray(ray);var shape_name:String="none"
		if not hit.is_empty():var collider:CollisionObject3D=hit.collider;shape_name=str(collider.shape_owner_get_owner(collider.shape_find_owner(hit.shape)).name)
		probe.append({"offset":offset*.25,"position":str(hit.get("position","empty")),"shape":shape_name})
	check(walker.finished and not walker.failed and walker.waypoint==route.size() and walker.position.distance_to(route[0])<1.5 and walker.max_unsupported_drop<.75,label+" real ordinary no-jump/no-correction return")
	var result:Dictionary={"label":label,"finished":walker.finished,"failed":walker.failed,"distance_m":walker.horizontal_distance_m,"frames":walker.frames,"waypoint":walker.waypoint,"waypoints":route.size(),"maximum_unsupported_drop_m":walker.max_unsupported_drop,"wall_seconds":(Time.get_ticks_usec()-started)/1000000.0,"final":str(walker.position),"nearby_native_profile":probe};result.merge(walk_extra_details(walker));walker.queue_free();await process_frame;return result
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	var guards:Dictionary=FrozenFixture.guards()
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/check_frozen_world_cohort.gd","res://tools/biome_extensions/route_probe.gd","res://config/caves/biomes/frozen_cave_definition.tres","res://scenes/main.tscn"]:guards[path]=FileAccess.get_sha256(path)
	var config=Config.new();config.biome_regions=config.biome_regions.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);config.biome_regions=FrozenFixture.registry(config.biome_regions,load("res://config/caves/biomes/frozen_cave_definition.tres"));var b=owner("grass",17);var work=Workload.new();check(work.configure(b.settings,config,17,0),"Same normal45percent first wet Frozen world selected by predetermined72case cohort")
	var output:Array=[];var task:int=WorkerThreadPool.add_task(func()->void:
		var bundle:Dictionary=work.discover(Vector2i(9,-3));var target:Dictionary={};var room:Dictionary={};var parent:Dictionary={}
		for region:Dictionary in bundle.get("regions",[]):
			if region.id!=Vector2i(9,-3):continue
			for pool:Dictionary in region.get("pools",[]):
				if pool.id=="9:-3:1:3:lobe:1:seepage":target=pool
			for node:Dictionary in region.nodes+region.get("pockets",[]):
				if str(node.id)==str(target.get("id","")).trim_suffix(":seepage"):room=node
			for node:Dictionary in region.nodes:
				if str(node.id)==str(room.get("parent","")):parent=node
		var cells:Array=[];var kinds:Dictionary={};var statistics:Array=[];var bounds:AABB
		if not room.is_empty():
			var low:Vector3=room.point-Vector3(room.chamber_radius+10,6,room.chamber_radius+10);var high:Vector3=room.point+Vector3(room.chamber_radius+10,room.chamber_height+12,room.chamber_radius+10)
			if not parent.is_empty():low=low.min(parent.point-Vector3(10,4,10));high=high.max(parent.point+Vector3(10,12,10))
			var first:Vector3i=work.field.cell(low);var last:Vector3i=work.field.cell(high);bounds=AABB(low,high-low)
			for z in range(first.z,last.z+1):
				for y in range(first.y,last.y+1):
					for x in range(first.x,last.x+1):
						var key:=Vector3i(x,y,z);var data:Dictionary=work.build_cell(key);cells.append(data);var details:Dictionary=Features.new().build(work.field,key,17,bundle.regions,config.biome_regions.definitions[-1].feature_configuration,data.water)
						for placement:Dictionary in details.placements:kinds[placement.kind]=int(kinds.get(placement.kind,0))+1
						statistics.append({"key":str(key),"valid":data.valid,"feature_batches":data.get("features",[]).size(),"base_vertices":0 if data.arrays.is_empty() else data.arrays[Mesh.ARRAY_VERTEX].size()})
		output.append({"bundle":bundle,"pool":target,"room":room,"parent":parent,"cells":cells,"kinds":kinds,"statistics":statistics,"bounds":bounds})
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);check(output.size()==1 and not output[0].room.is_empty() and not output[0].parent.is_empty(),"Original first wet Frozen pocket/real parent/stream/basin retained in complete3x3world")
	if output.is_empty() or output[0].room.is_empty():quit(1);return
	var data:Dictionary=output[0];var stream=Streamer.new();stream.configuration=config;stream._bundle=data.bundle;var cells:Dictionary={};var nodes:Array=[];var ice_vertices:int=0;var rock_vertices:int=0
	for cell:Dictionary in data.cells:
		check(cell.valid,"Actual shared worker payload valid at fixed Frozen site");var node:=MeshInstance3D.new();node.position=Vector3(cell.key)*64;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED;var material:ShaderMaterial=stream.material_for(cell.key,cell.get("biome_ids",[]));check(material!=null,"Actual region material composition accepted")
		var body:=StaticBody3D.new();body.name="CaveCollision";body.collision_layer=1;body.collision_mask=0;node.add_child(body)
		if not cell.arrays.is_empty():
			var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,cell.arrays);mesh.surface_set_material(0,material);node.mesh=mesh;rock_vertices+=cell.arrays[Mesh.ARRAY_VERTEX].size();var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(cell.arrays[Mesh.ARRAY_VERTEX]);child.shape=shape;body.add_child(child)
		check(FeatureRenderer.attach(node,cell.get("features",[]),config.biome_regions,true,true),"Actual native ice material/collision linked to shared cave cell")
		for feature:Dictionary in cell.get("features",[]):ice_vertices+=feature.arrays[Mesh.ARRAY_VERTEX].size()
		WaterRenderer.attach(node,cell.water);Frontiers.attach(node,cell.get("frontiers",{}),material,true);root.add_child(node);cells[cell.key]=node;nodes.append(node)
	Frontiers.synchronize(cells);var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.remove_child(terrain);terrain.free();var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;root.add_child(scene);scene.get_node("Interface").hide();var light:=OmniLight3D.new();light.name="TestOnlyFrozenWorldInspectionLight";light.omni_range=120;light.light_energy=4;light.shadow_enabled=true;root.add_child(light)
	# Inspection-only static water removes TIME from repeated-image comparison;
	# production water resource/code is never edited or rebound in this test.
	for node:MeshInstance3D in nodes:
		if node.has_node("CaveSeepageWater"):
			var water:MeshInstance3D=node.get_node("CaveSeepageWater");var material:ShaderMaterial=water.mesh.surface_get_material(0).duplicate();var shader:Shader=material.shader.duplicate();shader.code=shader.code.replace("TIME","0.0");material.shader=shader;water.material_override=material
	var room:Dictionary=data.room;var pool:Dictionary=data.pool;var center:Vector3=room.point;var water_center:=Vector3(pool.center.x,pool.water_y+Features.ICE_FREEBOARD,pool.center.z);var records:Array=[];var visible_change:bool=false
	var poses:Array=[{"position":center+Vector3(0,1.8,0),"target":water_center},{"position":center+Vector3(-room.chamber_radius*.25,2.6,room.chamber_radius*.15),"target":center+Vector3(room.chamber_radius*.5,room.chamber_height*.55,-room.chamber_radius*.3)}]
	for pose:int in range(poses.size()):
		camera.position=poses[pose].position;camera.look_at(poses[pose].target);check(work.field.sample(camera.position)<-.2,"Native inspection camera is inside real cave air");light.position=camera.position+Vector3(0,.5,0);light.visible=false;await picture("pose%d_natural"%pose);light.visible=true;var lit:Image=await picture("pose%d_test_only_light"%pose)
		for node:MeshInstance3D in nodes:
			for child:Node in node.get_children():
				if str(child.name).begins_with("CaveBiome_"):child.visible=false
		var off:Image=await picture("pose%d_ice_geometry_off"%pose);visible_change=visible_change or off.get_data()!=lit.get_data()
		for node:MeshInstance3D in nodes:
			for child:Node in node.get_children():
				if str(child.name).begins_with("CaveBiome_"):child.visible=true
		var restored:Image=await picture("pose%d_ice_geometry_return"%pose);check(lit.get_data()==restored.get_data(),"Exact visible ice-geometry counterfactual return with static test-only water");records.append({"pose":pose,"position":str(camera.position),"target":str(poses[pose].target)})
	check(ice_vertices>0 and data.kinds.has("frozen_water") and visible_change,"Normal world contains visible real ice geometry and actual frozen basin/stream,not shader metadata alone")
	for frame in range(3):await physics_frame
	var parent:Vector3=data.parent.point+Vector3(0,.95,0);var room_start:Vector3=center+Vector3(0,.95,0);var lake_start:Vector3=water_center+Vector3(0,.95,0);var walks:Array=[]
	walks.append(await walk([parent,room_start,lake_start,room_start,parent],"Actual parent/flat geological neck/Frozen chamber/stream-lake/shore return"))
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable native Frozen world source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_cave_frozen_world.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"seed":17,"host":"grass","original_site":[9,-3],"pool_id":pool.id,"room_id":room.id,"room_center":str(center),"water_center":str(water_center),"feature_kinds":data.kinds,"native_cells":cells.size(),"rock_vertices":rock_vertices,"ice_vertices":ice_vertices,"cell_statistics":data.statistics,"views":records,"walks":walks,"engine_fixed_fps_marker":OS.get_environment("PREDATOR_TEST_ENGINE_FIXED_FPS"),"scope":"Normal45percent/150–700m/full depth/surface weights;first wet positive selected BEFORE rendering/native walks by complete fixed72case cohort,all its negatives retained. Actual full3x3canonical field and worker payloads,original main sky/sun/fog/camera50km;Terrain controller removed only bounded preloaded inspection. Explicit120m4energy test-only light and test-only TIME0water clone for exact geometry on/off/return. Ordinary capsule no jump/correction,preloaded route;fixed-fps acceleration labelled,not live streaming/FPS/whole Frozen reference-art completion. Saved world registry/root caves remain unchanged."},"  "));print("FROZEN_WORLD_NATIVE ",checks," kinds=",data.kinds," walks=",walks," failures=",failures)
	for node:Node in nodes:node.queue_free()
	stream.free();scene.queue_free();light.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
