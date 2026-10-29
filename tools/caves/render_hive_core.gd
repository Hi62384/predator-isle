extends "res://tools/biome_extensions/check_all.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Streamer=preload("res://scripts/caves/streamer.gd")
const Palette=preload("res://scripts/caves/material_palette.gd")
const Frontiers=preload("res://scripts/caves/stream_frontiers.gd")
var captures:Dictionary={}
func frontier_study()->bool:return false
func report_name()->String:return "render_cave_hive_core"
func image_prefix()->String:return "cave_hive_core"
func picture(label:String)->Image:
	for frame in range(8):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/"+image_prefix()+"_"+label+".png";check(image.save_png(path)==OK,"Native original Hive core image "+label);captures[path]=FileAccess.get_sha256(path);return image
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720);var guards:Dictionary={}
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in ["res://tools/caves/render_hive_core.gd",get_script().resource_path,"res://scenes/main.tscn","res://materials/biological_colors_v3.tres","res://scripts/alien_infected_sampler.gd"]:guards[path]=FileAccess.get_sha256(path)
	var b=make_builder(7,73921);var config=Config.new();config.regional_activity=1;config.seal_stream_frontiers=frontier_study();var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Original actual Hive core worker configured");var output:Array=[];var task:int=WorkerThreadPool.add_task(func()->void:
		var bundle:Dictionary=work.discover(Vector2i(-31,-31));var own:Dictionary={}
		for region:Dictionary in bundle.get("regions",[]):
			if region.id==Vector2i(-31,-31):own=region;break
		var keys:Dictionary={}
		if own.get("valid",false):
			var rooms:Array=own.pockets.duplicate()
			for room:Dictionary in own.nodes:
				if room.id==own.hive_core_node:rooms.append(room)
			for room:Dictionary in rooms:
				var radius:float=room.chamber_radius+4;var low:Vector3i=work.field.cell(room.point-Vector3(radius,4,radius));var high:Vector3i=work.field.cell(room.point+Vector3(radius,room.chamber_height+4,radius))
				for z in range(low.z,high.z+1):
					for y in range(low.y,high.y+1):
						for x in range(low.x,high.x+1):keys[Vector3i(x,y,z)]=true
		var cells:Array=[]
		for key:Vector3i in keys:cells.append(work.build_cell(key))
		output.append({"bundle":bundle,"region":own,"cells":cells})
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);check(output.size()==1 and output[0].region.get("valid",false),"Actual original multi-lobed core emits complete bounded worker geometry")
	if output.is_empty() or not output[0].region.get("valid",false):quit(1);return
	var data:Dictionary=output[0];var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.remove_child(terrain);terrain.free();var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;root.add_child(scene);scene.get_node("Interface").hide();var stream=Streamer.new();stream.configuration=config;stream._bundle=data.bundle;var nodes:Array=[];var materials:Array=[];var triangles:int=0;var cells:Dictionary={}
	for cell:Dictionary in data.cells:
		if cell.arrays.is_empty():cells[cell.key]=null;continue
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,cell.arrays);var material:ShaderMaterial=stream.material_for(cell.key);check(material.shader.resource_path=="res://shaders/hive_cave.gdshader","Actual core binds organic material,not recolored default rock");mesh.surface_set_material(0,material);var node:=MeshInstance3D.new();node.mesh=mesh;node.position=Vector3(cell.key)*64;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED;root.add_child(node);nodes.append(node);triangles+=cell.arrays[Mesh.ARRAY_VERTEX].size()/3
		if not materials.has(material):materials.append(material)
		cells[cell.key]=node
		if frontier_study():
			Frontiers.attach(node,cell.get("frontiers",{}),material,true);var body:=StaticBody3D.new();var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(cell.arrays[Mesh.ARRAY_VERTEX]);child.shape=shape;body.add_child(child);node.add_child(body)
	if frontier_study():Frontiers.synchronize(cells)
	stream.free();var core:Vector3=data.region.underground_hive_center;var first:Vector3=data.region.pockets[0].point;var poses:Array=[{"position":core+Vector3(5,3,5),"focus":first+Vector3(0,7,0)},{"position":first+Vector3(0,3,0),"focus":core+Vector3(0,7,0)},{"position":core+Vector3(-12,8,-8),"focus":core+Vector3(18,9,15)}];var light:=OmniLight3D.new();light.name="TestOnlyCoreInspectionLight";light.omni_range=120;light.light_energy=4;light.shadow_enabled=true;light.visible=false;root.add_child(light);var records:Array=[]
	for i in range(poses.size()):
		var pose:Dictionary=poses[i];check(work.field.sample(pose.position)<0,"Inspection camera lies in real compiled core air,not inside a wall");camera.position=pose.position;camera.look_at(pose.focus);light.position=camera.position+Vector3(0,.5,0);light.visible=false;await picture("pose%d_natural"%i);light.visible=true;var organic:Image=await picture("pose%d_test_only_debug_light"%i);var rock:=ShaderMaterial.new();rock.shader=load("res://shaders/default_cave_rock.gdshader");Palette.bind(rock,0)
		for node:MeshInstance3D in nodes:node.material_override=rock
		var negative:Image=await picture("pose%d_rock_material_negative"%i);check(organic.get_data()!=negative.get_data(),"Positive actual organic-versus-rock appearance control")
		for node:MeshInstance3D in nodes:node.material_override=null
		if frontier_study():
			for node:MeshInstance3D in nodes:
				if node.has_node("CaveFrontiers"):node.get_node("CaveFrontiers").visible=false
			var unsealed:Image=await picture("pose%d_unsealed_positive_sky_leak"%i)
			for node:MeshInstance3D in nodes:
				if node.has_node("CaveFrontiers"):node.get_node("CaveFrontiers").visible=true
			var sealed:Image=await picture("pose%d_sealed_loaded_boundary"%i);check(unsealed.get_data()!=sealed.get_data(),"Positive original-world frontier appearance change")
			var restored:Image=await picture("pose%d_sealed_return"%i);check(sealed.get_data()==restored.get_data(),"Exact same-scene frontier image repeat")
			for frame in range(3):await physics_frame
			var misses:int=0;var space=camera.get_world_3d().direct_space_state
			for ray in range(256):
				var vertical:float=1-2*(ray+.5)/256;var theta:float=ray*2.39996322972865;var direction:=Vector3(sqrt(1-vertical*vertical)*cos(theta),vertical,sqrt(1-vertical*vertical)*sin(theta));var hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(camera.position,camera.position+direction*5000))
				if hit.is_empty():misses+=1
			check(misses==0,"Actual bounded loaded core has no native escape rays through missing next-cell geometry")
		records.append({"pose":i,"position":str(pose.position),"focus":str(pose.focus)})
	# Same actual original core geometry;controlled palette variants are not
	# additional geographic worlds or claims of six separate traversal tests.
	for family in range(6):
		for material:ShaderMaterial in materials:material.set_shader_parameter("hive_region",float(family))
		await picture("controlled_tissue_region%d"%family)
	for material:ShaderMaterial in materials:material.set_shader_parameter("hive_region",data.region.hive_region)
	check(materials.size()>0 and nodes.size()>0 and data.region.pockets.size()==6,"Positive actual core/material integration with all original six lobes")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable actual Hive core image source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/"+report_name()+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"frontier_study":frontier_study(),"original_seed":73921,"original_region":"(-31,-31)","core":str(core),"lobes":data.region.pockets.size(),"native_cells":nodes.size(),"native_triangles":triangles,"poses":records,"scope":"Actual original shared Hive field/core geometry extracted on worker and displayed in native main-scene unchanged sun/sky/fog with terrain controller removed only for preloaded underground inspection. Three original-core air camera poses,natural darkness,separately labelled temporary120m inspection light and rock-material negative,plus six controlled tissue-region palettes on SAME geometry. Optional frontier study adds unsealed/sealed/repeat controls and256native escape rays per pose. Existing generated biological color bank and albedo-derived3mm apparent relief,not newly measured PBR scans. Real physical wall folds and unequal joined lobes are production geometry;native capsule controls separate. This is preloaded core appearance,not full live surface streaming/whole-world/full Alien/reference-art acceptance."},"  "));print("CAVE_HIVE_CORE_RENDER ",checks," cells=",nodes.size()," triangles=",triangles," failures=",failures);for node:Node in nodes:node.queue_free()
	scene.queue_free();light.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
