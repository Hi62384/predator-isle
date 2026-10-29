extends "res://tools/caves/render_frozen_world.gd"
const Shallow=preload("res://tools/caves/shallow_chamber_candidate.gd")
const Scope=preload("res://tools/caves/inspection_scope.gd")
const Selection:String="res://tools/biome_extensions/artifacts/check_cave_shallow_chamber_candidate.json"
var inspection:SubViewport
func capture(label:String)->void:
	for frame in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var path:String="res://tools/biome_extensions/artifacts/cave_shallow_candidate_"+label+".png";check(inspection.get_texture().get_image().save_png(path)==OK,"Native actual shallow branch capture");captures[path]=FileAccess.get_sha256(path)
func run()->void:
	assert(DisplayServer.get_name()!="headless");var report=JSON.parse_string(FileAccess.get_file_as_string(Selection));check(report is Dictionary and report.get("passed",false),"Complete original36case shallow selection report exists")
	if not report is Dictionary or not report.get("passed",false):quit(1);return
	var guards:Dictionary=report.source_sha256.duplicate();guards[Selection]=FileAccess.get_sha256(Selection);guards[get_script().resource_path]=FileAccess.get_sha256(get_script().resource_path);guards["res://tools/caves/render_frozen_world.gd"]=FileAccess.get_sha256("res://tools/caves/render_frozen_world.gd");guards["res://tools/biome_extensions/route_probe.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/route_probe.gd")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Original shallow selection source unchanged "+path)
	if not failures.is_empty():quit(1);return
	var selected:Dictionary=report.first_positive;var site:=Vector2i(selected.site[0],selected.site[1]);var b=owner(selected.host,int(selected.seed));var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,load("res://config/caves/biomes/crystal_cave_definition.tres"));var work=Workload.new();check(work.configure(b.settings,config,int(selected.seed),0),"Same preselected actual host/seed settings");var output:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		var bundle:Dictionary=work.discover(site);var proposal:Dictionary={};var access:Dictionary={}
		for index in range(bundle.regions.size()):
			if bundle.regions[index].id!=site:continue
			access=bundle.regions[index].edges[0];proposal=Shallow.prepare(bundle.regions[index],work.builder._get_height);bundle.regions[index]=proposal;break
		var room:Dictionary=proposal.get("pockets",[])[-1];var branch:Dictionary=proposal.get("pocket_passages",[])[-1];var path:PackedVector3Array=branch.points;var junction:Vector3=path[-3];var nearest:int=0
		for index in range(access.points.size()):
			if access.points[index].distance_squared_to(junction)<access.points[nearest].distance_squared_to(junction):nearest=index
		var original_points:PackedVector3Array=access.points;var local_access:PackedVector3Array=original_points.slice(maxi(0,nearest-4),mini(original_points.size(),nearest+5));work.bundle_key=Vector2i(2147483647,2147483647);var valid:bool=work.use_bundle(bundle);var low:Vector3=room.point-Vector3(24,6,24);var high:Vector3=room.point+Vector3(24,24,24)
		for point:Vector3 in PackedVector3Array([path[-3],path[-2],path[-1]])+local_access:low=low.min(point-Vector3(10,6,10));high=high.max(point+Vector3(10,16,10))
		var first:Vector3i=work.field.cell(low);var last:Vector3i=work.field.cell(high);var cells:Array=[]
		for z in range(first.z,last.z+1):
			for y in range(first.y,last.y+1):
				for x in range(first.x,last.x+1):cells.append(work.build_cell(Vector3i(x,y,z)))
		output.append({"valid":valid,"bundle":bundle,"room":room,"branch":branch,"local_access":local_access,"cells":cells})
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);check(output.size()==1 and output[0].valid,"Private shallow addition compiles through actual shared worker")
	if output.is_empty():quit(1);return
	var data:Dictionary=output[0];check(str(data.room.id)==str(selected.room.id) and data.room.point.distance_to(str_to_var("Vector3"+str(selected.room.point)))<.01,"Exact FIRST descriptor retained without replacing site after physics")
	inspection=SubViewport.new();inspection.size=Vector2i(1280,720);inspection.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(inspection);var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.remove_child(terrain);terrain.free();check(Scope.isolate_environment(scene),"Unrelated workshop detached only in inspection instance");var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;inspection.add_child(scene);scene.get_node("Interface").hide();var light:=OmniLight3D.new();light.omni_range=120;light.light_energy=4;light.shadow_enabled=true;inspection.add_child(light);var stream=Streamer.new();stream.configuration=config;stream._bundle=data.bundle;var cells:Dictionary={};var nodes:Array=[];var vertices:int=0
	for cell:Dictionary in data.cells:
		check(cell.valid,"Actual complete native shallow worker payload valid");var node:=MeshInstance3D.new();node.position=Vector3(cell.key)*64;var material:ShaderMaterial=stream.material_for(cell.key,cell.get("biome_ids",[]));var body:=StaticBody3D.new();body.name="CaveCollision";body.collision_layer=1;body.collision_mask=0;node.add_child(body)
		if not cell.arrays.is_empty():
			var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,cell.arrays);mesh.surface_set_material(0,material);node.mesh=mesh;vertices+=cell.arrays[Mesh.ARRAY_VERTEX].size();var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(cell.arrays[Mesh.ARRAY_VERTEX]);child.shape=shape;body.add_child(child)
		check(FeatureRenderer.attach(node,cell.get("features",[]),config.biome_regions,true,true),"Original native formation collisions retained");WaterRenderer.attach(node,cell.water);Frontiers.attach(node,cell.get("frontiers",{}),material,true);root.add_child(node);cells[cell.key]=node;nodes.append(node)
	Frontiers.synchronize(cells);camera.position=data.room.point+Vector3.UP*1.8;camera.look_at(data.branch.points[-2]+Vector3.UP*2);light.position=camera.position+Vector3.UP*.5;light.visible=false;await capture("natural");light.visible=true;await capture("test_only_light");camera.position=data.branch.points[-3]+Vector3.UP*1.8;camera.look_at(data.room.point+Vector3.UP*2);light.position=camera.position+Vector3.UP*.5;await capture("original_access_junction_test_only_light");await physics_frame;await physics_frame
	var route:Array[Vector3]=[]
	for index in range(data.branch.points.size()-3,data.branch.points.size()):route.append(data.branch.points[index]+Vector3.UP*.95)
	for index in range(route.size()-2,-1,-1):route.append(route[index])
	var walks:Array=[await walk(route,"Existing access junction,new shallow branch and exact same-way return")];route=[]
	for point:Vector3 in data.local_access:route.append(point+Vector3.UP*.95)
	var count:int=route.size()
	for index in range(count-2,-1,-1):route.append(route[index])
	walks.append(await walk(route,"Original unchanged full-width access through branch junction and same-way return"))
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable actual shallow native source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_cave_shallow_chamber_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"first_positive":selected,"native_cells":data.cells.size(),"vertices":vertices,"walks":walks,"scope":"PRIVATE actual FIRST of36case shallow proposals at31.845m physical depth. Same complete shared field/workers/materials/formations/frontiers/rock and feature collisions,original main environment,test-only lamp. Native new branch AND original access junction no-jump same-way returns. Original biome assignment retained for this shared-core mechanism;not normal Crystal admission or adopted core/full main-node return/FPS/reference-art completion."},"  "));print("SHALLOW_NATIVE ",checks," walks=",walks," failures=",failures)
	for node:Node in nodes:node.queue_free()
	stream.free();inspection.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
