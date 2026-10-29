extends "res://tools/caves/check_frozen_features.gd"
const Streamer=preload("res://scripts/caves/streamer.gd")
const Surface=preload("res://scripts/caves/surface_biomes.gd")
const Frontiers=preload("res://scripts/caves/stream_frontiers.gd")
const WaterRenderer=preload("res://scripts/caves/water_renderer.gd")
var captures:Dictionary={}
func picture(label:String)->Image:
	for frame in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/cave_frozen_features_"+label+".png";check(image.save_png(path)==OK,"Actual Frozen geological feature render "+label);captures[path]=FileAccess.get_sha256(path);return image
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720);var guards:Dictionary=FrozenFixture.guards()
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/check_frozen_features.gd","res://config/caves/biomes/frozen_cave_definition.tres","res://scenes/main.tscn"]:guards[path]=FileAccess.get_sha256(path)
	var region:Dictionary=fixture();var height:Callable=func(_x:float,_z:float)->float:return 150.0
	var definition:Resource=load("res://config/caves/biomes/frozen_cave_definition.tres");region=Features.new().decorate_region(region,height,73921,definition.feature_configuration,400,10);var field=Field.new();field.include_surface_air=false;check(field.compile([region],height,[],region.cave_biome_regions),"Controlled large retained lake/real curved wall positive shared field")
	var config=Config.new();config.biome_regions=config.biome_regions.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var stream=Streamer.new();stream.configuration=config;stream._bundle={"regions":[region]};var nodes:Array=[];var cells:Dictionary={};var placements:Array=[];var vertices:int=0
	for key:Vector3i in [Vector3i(-1,0,-1),Vector3i(0,0,-1),Vector3i(-1,0,0),Vector3i.ZERO,Vector3i(1,0,0),Vector3i(0,-1,0)]:
		var water:Dictionary=Basins.water_cell([region],field,key);var payload:Dictionary=Features.new().build(field,key,73921,[region],{"density":1.0,"curtain_chance":1.0,"lake_ice":true},water);placements.append_array(payload.placements);var tagged:Dictionary=Surface.bind(Mesher.new().build(field,key),field,key);var material:ShaderMaterial=stream.material_for(key,tagged.ids);var node:=MeshInstance3D.new();node.position=Vector3(key)*64;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		if not tagged.arrays.is_empty():var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,tagged.arrays);mesh.surface_set_material(0,material);node.mesh=mesh
		var body:=StaticBody3D.new();body.name="CaveCollision";node.add_child(body)
		for batch:Dictionary in payload.batches:batch["biome_id"]="frozen";vertices+=batch.arrays[Mesh.ARRAY_VERTEX].size()
		check(Renderer.attach(node,payload.batches,config.biome_regions,true,true),"Physical provider material compiles on real native feature mesh");Frontiers.attach(node,Frontiers.build(field,key),material,true);var water_node:MeshInstance3D=WaterRenderer.attach(node,water)
		if water_node!=null:
			var water_material:ShaderMaterial=water_node.mesh.surface_get_material(0).duplicate();var water_shader:Shader=water_material.shader.duplicate();water_shader.code=water_shader.code.replace("TIME","0.0");water_material.shader=water_shader;water_node.material_override=water_material
		root.add_child(node);nodes.append(node);cells[key]=node
	Frontiers.synchronize(cells);var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.remove_child(terrain);terrain.free();var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;root.add_child(scene);scene.get_node("Interface").hide();var light:=OmniLight3D.new();light.omni_range=120;light.light_energy=4;light.shadow_enabled=true;root.add_child(light)
	var views:Array=[{"name":"lake","position":Vector3(32,22.6,37),"target":Vector3(32,19.6+Features.ICE_FREEBOARD,50)}];var waterfall:bool=false
	for placement:Dictionary in placements:
		if placement.kind=="frozen_waterfall":
			var row:int=placement.front.size()/2;var col:int=placement.front[row].size()/2;views.append({"name":"waterfall","position":Vector3(32,26,32),"target":placement.front[row][col]});waterfall=true
	check(waterfall and vertices>0,"Actual large waterfall,not a material-painted rectangle or empty render fixture")
	var records:Array=[]
	for view:Dictionary in views:
		camera.position=view.position;camera.look_at(view.target);check(field.sample(camera.position)<-.2,"Feature inspection camera sits in real constrained chamber air");light.position=camera.position+Vector3(0,.5,0);light.visible=false;await picture(view.name+"_natural");light.visible=true;var lit:Image=await picture(view.name+"_test_only_light")
		for node:MeshInstance3D in nodes:
			for child:Node in node.get_children():
				if str(child.name).begins_with("CaveBiome_"):child.visible=false
		var off:Image=await picture(view.name+"_geometry_off")
		for node:MeshInstance3D in nodes:
			for child:Node in node.get_children():
				if str(child.name).begins_with("CaveBiome_"):child.visible=true
		var restored:Image=await picture(view.name+"_geometry_return");check(lit.get_data()!=off.get_data(),"Positive visible physical feature geometry "+view.name);check(lit.get_data()==restored.get_data(),"Exact same-scene feature geometry return "+view.name);records.append({"name":view.name,"position":str(view.position),"target":str(view.target)})
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable controlled Frozen geological source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_cave_frozen_features.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"views":records,"vertices":vertices,"lake_radius":region.pools[0].radius,"scope":"Explicit CONTROLLED positive field with real rock/retained basin/actual curved wall,not a geographic occurrence claim. Density1/curtain chance1 only to inspect positive mechanisms,normal world settings unchanged. Actual opaque/native ice geometry/PBR with original main sky/sun/fog/camera50km,explicit120m4energy test-only light,natural/on/off/exactreturn images. Native returns separate;not complete Frozen art or broad performance."},"  "));print("FROZEN_FEATURE_RENDER ",checks," vertices=",vertices," failures=",failures)
	for node:Node in nodes:node.queue_free()
	stream.free();scene.queue_free();light.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
