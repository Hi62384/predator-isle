extends "res://tools/caves/check_frozen_features.gd"
const Streamer=preload("res://scripts/caves/streamer.gd")
const Surface=preload("res://scripts/caves/surface_biomes.gd")
const Frontiers=preload("res://scripts/caves/stream_frontiers.gd")
var captures:Dictionary={}
func picture(label:String)->Image:
	for frame in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/cave_frozen_columns_"+label+".png";check(image.save_png(path)==OK,"Actual generated column/thin-ice native image "+label);captures[path]=FileAccess.get_sha256(path);return image
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720);var guards:Dictionary=FrozenFixture.guards()
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/check_frozen_features.gd","res://config/caves/biomes/frozen_cave_definition.tres","res://scenes/main.tscn"]:guards[path]=FileAccess.get_sha256(path)
	var height:Callable=func(_x:float,_z:float)->float:return 150.0
	var definition:Resource=load("res://config/caves/biomes/frozen_cave_definition.tres");var region:Dictionary=Features.new().decorate_region(fixture(),height,73921,definition.feature_configuration,400,10);var field=Field.new();field.include_surface_air=false;check(field.compile([region],height,[],region.cave_biome_regions),"Same protected real chamber/basin as complete48seed ensemble")
	var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var stream=Streamer.new();stream.configuration=config;stream._bundle={"regions":[region]};var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.remove_child(terrain);terrain.free();var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;root.add_child(scene);scene.get_node("Interface").hide();var light:=OmniLight3D.new();light.omni_range=120;light.light_energy=4;light.shadow_enabled=true;root.add_child(light);var records:Array=[]
	# First positive examples in the COMPLETE predeclared ensemble,not a
	# geographic reroll after a failed native render. Density1 inspection only.
	for seed_id:int in [17,92881]:
		var generator=Features.new();var features:Dictionary=generator.build(field,Vector3i.ZERO,seed_id,[region],{"density":1.0,"curtain_chance":0.0,"lake_ice":false},{});var target:Dictionary={}
		for placement:Dictionary in features.placements:
			if (seed_id==17 and placement.kind=="ice_column") or (seed_id==92881 and placement.get("thin",false)):target=placement;break
		check(not target.is_empty(),"Retained first actual ensemble column/thin form remains generated")
		if target.is_empty():continue
		var nodes:Array=[];var cells:Dictionary={}
		for key:Vector3i in [Vector3i(-1,0,-1),Vector3i(0,0,-1),Vector3i(-1,0,0),Vector3i.ZERO,Vector3i(1,0,0),Vector3i(0,-1,0)]:
			var tagged:Dictionary=Surface.bind(Mesher.new().build(field,key),field,key);var material:ShaderMaterial=stream.material_for(key,tagged.ids);var node:=MeshInstance3D.new();node.position=Vector3(key)*64;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
			if not tagged.arrays.is_empty():var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,tagged.arrays);mesh.surface_set_material(0,material);node.mesh=mesh
			var body:=StaticBody3D.new();body.name="CaveCollision";node.add_child(body)
			if key==Vector3i.ZERO:
				for batch:Dictionary in features.batches:batch["biome_id"]="frozen"
				check(Renderer.attach(node,features.batches,config.biome_regions,true,true),"Native opaque/selected transparent feature materials upload with real geometry")
			Frontiers.attach(node,Frontiers.build(field,key),material,true);root.add_child(node);nodes.append(node);cells[key]=node
		Frontiers.synchronize(cells);var focus:Vector3=target.root+Vector3(0,target.up*target.height*.5,0);var inward:Vector3=(region.nodes[0].point-target.root)*Vector3(1,0,1);inward=inward.normalized();camera.position=region.nodes[0].point+inward*7+Vector3(0,4,0) if seed_id==17 else focus+inward*3-Vector3(0,.1,0);camera.look_at(focus);check(field.sample(camera.position)<-.1,"Native column/thin inspector inside genuine shared cave air");light.position=camera.position+Vector3(0,.5,0);light.visible=false;await picture(str(seed_id)+"_natural");light.visible=true;var reference:Image=await picture(str(seed_id)+"_test_only_light")
		if seed_id==92881:
			var thin_node:MeshInstance3D=cells[Vector3i.ZERO].get_node("CaveBiome_frozen_thin_ice");thin_node.material_override=definition.surface_provider.new().feature_material("ice",definition.material_configuration,true);var opaque:Image=await picture(str(seed_id)+"_opaque_negative_control");check(reference.get_data()!=opaque.get_data(),"Real selected thin-ice transparency visibly differs from same geometry forced opaque");thin_node.material_override=null
		else:
			for node:MeshInstance3D in nodes:
				for child:Node in node.get_children():
					if str(child.name).begins_with("CaveBiome_"):child.visible=false
			var absent:Image=await picture(str(seed_id)+"_geometry_off");check(absent.get_data()!=reference.get_data(),"Actual generated floor-to-ceiling ice column is visible,not an empty material registry")
			for node:MeshInstance3D in nodes:
				for child:Node in node.get_children():
					if str(child.name).begins_with("CaveBiome_"):child.visible=true
		var returned:Image=await picture(str(seed_id)+"_feature_return");check(returned.get_data()==reference.get_data(),"Exact geometry/transmission counterfactual image return");records.append({"seed":seed_id,"kind":target.kind,"height_m":target.height,"root":str(target.root),"camera":str(camera.position),"thin":target.get("thin",false)})
		for node:Node in nodes:node.queue_free()
		await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable actual generated Frozen column/transmission source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_cave_frozen_columns.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"records":records,"scope":"Actual generated first positive column(seed17)/thin form(seed92881)from retained complete48seed controlled field ensemble;not natural-world occurrence. Density1inspects mechanisms,all normal column probabilities/contact/clearance unchanged. Original main sky/sun/fog/camera50km,explicit120m4energy test-only light;positive geometry and same-geometry forced-opaque negative,exact returns. Selected thin ALPHA.82depthprepass,no all-wall/lake transparency,refraction or measured-volume-scattering claim. Not complete Frozen art,broad performance or all-user completion."},"  "));print("FROZEN_COLUMN_RENDER ",checks," records=",records," failures=",failures);stream.free();scene.queue_free();light.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
