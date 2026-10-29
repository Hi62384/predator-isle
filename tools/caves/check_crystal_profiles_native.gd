extends "res://tools/caves/check_crystal_features.gd"
## Positive mechanism controls, not a claim of normal-world occurrence.
const Streamer=preload("res://scripts/caves/streamer.gd")
const Surface=preload("res://scripts/caves/surface_biomes.gd")
const Frontiers=preload("res://scripts/caves/stream_frontiers.gd")
const Water=preload("res://scripts/caves/water_renderer.gd")
var captures:Dictionary={}
var inspection:SubViewport
func profile_styles()->Array[String]:return ["geode","ravine","large_basin"]
func native_report_name()->String:return "check_cave_crystal_profiles_native"
func before_profile_walk(_style:String,_cells:Dictionary)->void:pass
func seed_fixture()->Dictionary:
	var a:Dictionary={"id":"A","point":Vector3(32,20,32),"level":1,"chamber_radius":26.0,"chamber_height":46.0};var b:Dictionary={"id":"B","point":Vector3(-32,20,32),"level":1,"chamber_radius":8.0,"chamber_height":8.0};var edge:Dictionary={"from":"A","to":"B","points":PackedVector3Array([a.point,b.point]),"half_width":4.0,"headroom":8.0,"entrance":false};var candidate:Dictionary={"id":"A/crystal","biome_id":"crystal","anchor":"A","point":a.point,"reach_m":350.0,"extent_m":700.0,"transition_m":48.0,"distances":{"A":0.0,"B":64.0},"connected_growth":true}
	return {"valid":true,"id":Vector2i.ZERO,"nodes":[a,b],"edges":[edge],"pockets":[],"pocket_passages":[],"cave_biome_regions":{"fallback":"default","candidates":[candidate],"edges":[{"from":"A","to":"B","length":64.0}]}}
func graph_path(topology:Dictionary,source:String,target:String)->Array[String]:
	var queue:Array[String]=[source];var previous:Dictionary={source:source}
	while not queue.is_empty():
		var current:String=queue.pop_front()
		if current==target:break
		for index:int in topology.adjacency[current]:
			var edge:Dictionary=topology.edges[index];var other:String=edge.to if edge.from==current else edge.from
			if not previous.has(other):previous[other]=current;queue.append(other)
	if not previous.has(target):return []
	var path:Array[String]=[target]
	while path[0]!=source:path.push_front(previous[path[0]])
	return path
func append_graph_route(route:Array[Vector3],region:Dictionary,topology:Dictionary,source:String,target:String)->void:
	var ids:Array[String]=graph_path(topology,source,target);check(not ids.is_empty(),"Native route follows actual connecting edges,never a straight cross-wall jump")
	for index in range(ids.size()-1):
		for edge:Dictionary in region.edges+region.get("pocket_passages",[]):
			if not ((edge.from==ids[index] and edge.to==ids[index+1]) or (edge.to==ids[index] and edge.from==ids[index+1])):continue
			var points:PackedVector3Array=edge.points.duplicate()
			if edge.from!=ids[index]:points.reverse()
			for point:Vector3 in points:route.append(point+Vector3(0,.95,0))
			break
func picture(label:String)->Image:
	for frame in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=inspection.get_texture().get_image()
	check(image.get_size()==Vector2i(1280,720),"Native fixed1280x720 positive profile inspection")
	var path:String="res://tools/biome_extensions/artifacts/"+native_report_name()+"_"+label+".png"
	check(image.save_png(path)==OK,"Native actual connected profile image "+label);captures[path]=FileAccess.get_sha256(path);return image
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	var guards:Dictionary=FrozenFixture.guards()
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/check_crystal_profiles_native.gd","res://tools/caves/check_crystal_features.gd","res://tools/caves/check_frozen_features.gd","res://tools/caves/check_crystal_connected_profiles.gd","res://tools/biome_extensions/route_probe.gd","res://scenes/main.tscn","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	inspection=SubViewport.new();inspection.size=Vector2i(1280,720);inspection.own_world_3d=false;inspection.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(inspection)
	var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.remove_child(terrain);terrain.free();var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;inspection.add_child(scene);scene.get_node("Interface").hide()
	var light:=OmniLight3D.new();light.omni_range=120;light.light_energy=4;light.shadow_enabled=true;inspection.add_child(light)
	var records:Array=[];var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");var height:Callable=func(_x:float,_z:float)->float:return 200.0
	for style:String in profile_styles():
		var settings:Dictionary=definition.feature_configuration.duplicate(true);settings.geode_frequency=1.0 if style=="geode" else 0.0;settings.ravine_frequency=1.0 if style=="ravine" else 0.0;settings.large_lake_frequency=1.0 if style=="large_basin" else 0.0
		var seed_region:Dictionary=seed_fixture()
		if style=="large_basin":
			# A valid broad LOW host stays below the unchanged128-bin primitive
			# bound. The first40m/46m host failed compile and is preserved.
			seed_region.nodes[0].chamber_radius=40.0;seed_region.nodes[0].chamber_height=28.0
			seed_region["pools"]=[{"id":"A:seepage","center":Vector3(32,20,50),"radius":5.0,"water_radius":4.0,"water_y":19.6,"bed_y":17.0,"depth":3.0,"bed":{"id":"A:bed","point":Vector3(32,17,50),"level":1,"chamber_radius":4.25,"chamber_height":4.5},"bed_lobes":[]}]
		var region:Dictionary=Crystal.ConnectedProfiles.decorate(seed_region,height,73921,settings,400,10) if style=="large_basin" else Crystal.new().decorate_region(seed_region,height,73921,settings,400,10)
		check(region.get("crystal_connected_profiles_version",0)==1,"Positive production generator connected profile "+style)
		var field=Field.new();field.include_surface_air=false;check(field.compile([region],height,[],region.cave_biome_regions),"Same production finite field for entire joined profile "+style)
		var keys:Array=field.chunks.keys();keys.sort();var output:Array=[]
		var task:int=WorkerThreadPool.add_task(func()->void:
			var cells:Array=[]
			for key:Vector3i in keys:
				var water:Dictionary=Basins.water_cell([region],field,key);var payload:Dictionary=Crystal.new().build(field,key,73921,[region],settings,water);var tagged:Dictionary=Surface.bind(Mesher.new().build(field,key),field,key)
				cells.append({"key":key,"tagged":tagged,"payload":payload,"water":water,"frontiers":Frontiers.build(field,key)})
			output.append(cells)
		)
		while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
		WorkerThreadPool.wait_for_task_completion(task)
		var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var stream=Streamer.new();stream.configuration=config;stream._bundle={"regions":[region]};var cells:Dictionary={};var features:Array=[];var forms:int=0;var vertices:int=0;var water_vertices:int=0;var water_ids:Array=[];var largest:Dictionary={}
		for data:Dictionary in output[0]:
			check(data.payload.valid,"Production measured mineral payload positive "+style);var node:=MeshInstance3D.new();node.position=Vector3(data.key)*64;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED;var material:ShaderMaterial=stream.material_for(data.key,data.tagged.ids);check(material!=null,"Actual production profile material adapter")
			var body:=StaticBody3D.new();body.name="CaveCollision";node.add_child(body)
			if not data.tagged.arrays.is_empty():
				var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data.tagged.arrays);mesh.surface_set_material(0,material);node.mesh=mesh;var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(data.tagged.arrays[Mesh.ARRAY_VERTEX]);var child:=CollisionShape3D.new();child.shape=shape;body.add_child(child)
			for batch:Dictionary in data.payload.batches:batch["biome_id"]="crystal";vertices+=batch.arrays[Mesh.ARRAY_VERTEX].size()
			check(Renderer.attach(node,data.payload.batches,config.biome_regions,true,true),"Real complete batched mineral LOD and collision upload "+style)
			for placement:Dictionary in data.payload.placements:
				if placement.kind=="crystal":
					forms+=1
					if largest.is_empty() or placement.height>largest.height:largest=placement
			var water_node:MeshInstance3D=Water.attach(node,data.water)
			if not data.water.arrays.is_empty():water_vertices+=data.water.arrays[Mesh.ARRAY_VERTEX].size();water_ids.append_array(data.water.ids)
			if water_node!=null:
				var copy:ShaderMaterial=water_node.mesh.surface_get_material(0).duplicate();var shader:Shader=copy.shader.duplicate();shader.code=shader.code.replace("TIME","0.0");copy.shader=shader;water_node.material_override=copy
			Frontiers.attach(node,data.frontiers,material,true);root.add_child(node);cells[data.key]=node
			for child:Node in node.get_children():
				if str(child.name).begins_with("CaveBiome_"):features.append(child)
		Frontiers.synchronize(cells);check(forms>0 and vertices>0,"New profile contains positive physically measured mineral geometry "+style)
		var rooms:Array=region.pockets.duplicate();rooms.push_front(region.nodes[0]);var view_count:int=0
		for room:Dictionary in rooms:
			camera.position=room.point+Vector3(0,1.8,0);var target:Vector3=largest.bounds.get_center() if not largest.is_empty() else camera.position+Vector3(10,3,10)
			if camera.position.distance_to(target)<1:target+=Vector3(3,2,3)
			camera.look_at(target);check(field.sample(camera.position)<-.2,"Profile camera in actual joined air,not outside or a staged facade")
			light.position=camera.position+Vector3(0,.5,0);light.visible=false;await picture(style+"_"+str(view_count)+"_natural");light.visible=true;var original:Image=await picture(style+"_"+str(view_count)+"_test_only_light")
			for feature:Node3D in features:feature.visible=false
			var off:Image=await picture(style+"_"+str(view_count)+"_minerals_off")
			for feature:Node3D in features:feature.visible=true
			var restored:Image=await picture(style+"_"+str(view_count)+"_return");check(original.get_data()==restored.get_data(),"Native mineral geometry exact rendered return "+style);check(original.get_data()!=off.get_data(),"Positive visible mineral geometry in each geological profile view "+style);view_count+=1
		await physics_frame;await physics_frame
		var route:Array[Vector3]=[region.nodes[1].point+Vector3(0,.95,0)];var topology:Dictionary=Crystal.Regions.graph(region);append_graph_route(route,region,topology,"B","A")
		if style in ["ravine","geode"]:
			var previous:String="A"
			for room:Dictionary in region.pockets:append_graph_route(route,region,topology,previous,room.id);previous=room.id
			append_graph_route(route,region,topology,previous,"B")
		else:
			var pool:Dictionary=region.pools[0];check(pool.get("crystal_large_lake",false) and pool.radius>=8 and pool.radius<=12 and water_ids.has(pool.id) and water_vertices>0,"Actual enlarged retained8–12m basin has positive clipped native water geometry")
			var radius:float=pool.radius+2.0
			for index in range(33):
				var angle:float=-PI*.5+TAU*index/32;var p:Vector3=pool.center+Vector3(cos(angle)*radius,0,sin(angle)*radius);var hit:Dictionary=root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*6,p-Vector3.UP*4,1));check(not hit.is_empty() and hit.normal.y>cos(PI/4),"Every bank waypoint measured on actual walkable native rock,not assumed room-centre height")
				if not hit.is_empty():p.y=hit.position.y
				route.append(p+Vector3.UP*.95)
			route.append(region.nodes[0].point+Vector3(0,.95,0));route.append(route[0])
		before_profile_walk(style,cells);await physics_frame;await physics_frame;RenderingServer.render_loop_enabled=false
		await walk(route,"Production "+style+" original passage/all new necks or dry retained-basin perimeter and same-way return")
		RenderingServer.render_loop_enabled=true
		records.append({"profile":style,"seed":73921,"controlled_frequencies":settings,"new_rooms":region.pockets,"native_cells":cells.size(),"forms":forms,"vertices":vertices,"views":view_count,"water_vertices":water_vertices,"water_ids":water_ids,"walk":walks[-1]})
		for node:Node in cells.values():node.queue_free()
		stream.free();await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable production connected-profile source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/"+native_report_name()+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"records":records,"scope":"Production generator/field/material/mesher/feature/basin/frontier/native collision and ordinary1.8m/.4m/5mps/45degree/.6snap/no-jump/no-correction full two-way neck/perimeter returns. FIRST seed73921 for all forced positive mechanism controls,normal.65mineral density. Original main sky/sun/fog/camera50km,natural and explicit4energy120m TEST-ONLY light at fixed1280x720. Basin controlled broad34m/28mLOW valid host invokes production connected-profile decorator directly,not generic chamber enlargement;first40m/46m invalid host preserved. Not normal occurrence,reference art/full live streaming/uninterrupted FPS/registry activation or whole-user completion."},"  "));print("CRYSTAL_PROFILES_NATIVE ",native_report_name()," ",checks," walks=",walks," failures=",failures);scene.queue_free();light.queue_free();inspection.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
