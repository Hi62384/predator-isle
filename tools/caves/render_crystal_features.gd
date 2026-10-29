extends "res://tools/caves/check_crystal_features.gd"
const Streamer=preload("res://scripts/caves/streamer.gd")
const Surface=preload("res://scripts/caves/surface_biomes.gd")
const Frontiers=preload("res://scripts/caves/stream_frontiers.gd")
var captures:Dictionary={}
var inspection:SubViewport
func picture(label:String)->Image:
	for frame in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=inspection.get_texture().get_image();check(image.get_size()==Vector2i(1280,720),"Fixed actual native1280x720 inspection target,independent of desktop window state");var path:String="res://tools/biome_extensions/artifacts/cave_crystal_features_"+label+".png";check(image.save_png(path)==OK,"Native actual mineral chamber image "+label);captures[path]=FileAccess.get_sha256(path);return image
func run()->void:
	assert(DisplayServer.get_name()!="headless");inspection=SubViewport.new();inspection.size=Vector2i(1280,720);inspection.own_world_3d=true;inspection.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(inspection);var guards:Dictionary={}
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/check_crystal_features.gd","res://tools/caves/check_frozen_features.gd","res://scripts/biome_extension_structures.gd","res://config/caves/biomes/crystal_cave_definition.tres","res://scenes/main.tscn"]:guards[path]=FileAccess.get_sha256(path)
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");var region:Dictionary=crystal_fixture()
	var height:Callable=func(_x:float,_z:float)->float:return 200.0
	region=Crystal.new().decorate_region(region,height,73921,definition.feature_configuration,400,10);var field=Field.new();field.include_surface_air=false;check(field.compile([region],height,[],region.cave_biome_regions),"Controlled shared-volume46m-high actual host rock for mineral inspection")
	var settings:Dictionary=definition.feature_configuration.duplicate();settings.density=1.0;var picks:Dictionary={};var seeds:Array=[73921,17,92881]
	for i in range(33):seeds.append(1000+i)
	for seed_id:int in seeds:
		var payload:Dictionary=Crystal.new().build(field,Vector3i.ZERO,seed_id,[region],settings,{})
		for placement:Dictionary in payload.placements:
			if placement.kind!="crystal" or placement.importance!=0:continue
			if not picks.has(str(placement.family)):picks[str(placement.family)]={"seed":seed_id,"family":placement.family,"target":placement.bounds.get_center(),"height":placement.height,"id":placement.id}
			elif picks[str(placement.family)].seed==seed_id and placement.height>picks[str(placement.family)].height:picks[str(placement.family)]={"seed":seed_id,"family":placement.family,"target":placement.bounds.get_center(),"height":placement.height,"id":placement.id}
	check(picks.size()==6,"Largest primary of FIRST positive seed of each family selected BEFORE rendering from same predeclared36seed ensemble,not seed rerolls")
	var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.remove_child(terrain);terrain.free();var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;inspection.add_child(scene);scene.get_node("Interface").hide();var light:=OmniLight3D.new();light.omni_range=120;light.light_energy=4;light.shadow_enabled=true;inspection.add_child(light)
	var records:Array=[];var lod_positive:int=0;var transmission_positive:int=0;var family_ids:Array=picks.keys();family_ids.sort()
	for family:String in family_ids:
		var chosen:Dictionary=picks[family];var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var stream=Streamer.new();stream.configuration=config;stream._bundle={"regions":[region]};var nodes:Array=[];var cells:Dictionary={};var feature_nodes:Array=[];var vertex_count:int=0;var collision_vertices:int=0;var placement_count:int=0;var first_clear:Dictionary={};var keys:Array=field.chunks.keys();keys.sort()
		for key:Vector3i in keys:
			var payload:Dictionary=Crystal.new().build(field,key,chosen.seed,[region],settings,{});check(payload.valid,"Actual inspection worker payload valid "+family);placement_count+=payload.placements.size();var tagged:Dictionary=Surface.bind(Mesher.new().build(field,key),field,key);var material:ShaderMaterial=stream.material_for(key,tagged.ids);check(material!=null and material.shader!=null,"Actual registered-provider host mineral shader positive "+family);var node:=MeshInstance3D.new();node.position=Vector3(key)*64;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
			for placement:Dictionary in payload.placements:
				if first_clear.is_empty() and placement.kind=="crystal" and placement.thin_transmission:first_clear=placement
			if not tagged.arrays.is_empty():var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,tagged.arrays);mesh.surface_set_material(0,material);node.mesh=mesh
			var body:=StaticBody3D.new();body.name="CaveCollision";node.add_child(body)
			for batch:Dictionary in payload.batches:batch["biome_id"]="crystal";vertex_count+=batch.arrays[Mesh.ARRAY_VERTEX].size();collision_vertices+=batch.collision_faces.size()
			check(Renderer.attach(node,payload.batches,config.biome_regions,true,true),"Actual native batched near/far optics/LOD/collision commit "+family);Frontiers.attach(node,Frontiers.build(field,key),material,true);inspection.add_child(node);nodes.append(node);cells[key]=node
			for child:Node in node.get_children():
				if str(child.name).begins_with("CaveBiome_"):feature_nodes.append(child)
		Frontiers.synchronize(cells);camera.position=Vector3(32,22,37);camera.look_at(chosen.target);check(field.sample(camera.position)<-.2,"Inspection camera is inside real constrained air");light.position=camera.position+Vector3(0,1,0);light.visible=false;inspection.mesh_lod_threshold=0;await picture(family+"_natural");light.visible=true;var original:Image=await picture(family+"_test_only_light");var near_primitives:int=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		for node:Node3D in feature_nodes:node.visible=false
		var off:Image=await picture(family+"_geometry_off")
		for node:Node3D in feature_nodes:node.visible=true
		var restored:Image=await picture(family+"_geometry_return");check(original.get_data()!=off.get_data(),"Positive visible physical mineral geometry "+family);check(original.get_data()==restored.get_data(),"Exact actual feature scene image return "+family)
		inspection.mesh_lod_threshold=10000;var far:Image=await picture(family+"_forced_far_index_lod");var far_primitives:int=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		if far_primitives<near_primitives:lod_positive+=1
		inspection.mesh_lod_threshold=0;var near_return:Image=await picture(family+"_near_index_return");check(original.get_data()==near_return.get_data(),"Native index LOD off restores exact full mineral geometry image")
		var clear_materials:Dictionary={}
		for node:MeshInstance3D in feature_nodes:
			if str(node.name).ends_with("mineral_clear"):
				clear_materials[node]=node.material_override
		if not clear_materials.is_empty():
			check(not first_clear.is_empty(),"Positive clear native batch has an actual preselected thin primitive")
			var axis:Vector3=first_clear.axis;var tangent:Vector3=Vector3.UP.cross(axis).normalized() if absf(axis.y)<.9 else Vector3.RIGHT.cross(axis).normalized();var target:Vector3=first_clear.root+axis*first_clear.height*.65;camera.position=target+axis*2+tangent*1.8
			if field.sample(camera.position)>=-.2:camera.position=target+axis*2
			check(field.sample(camera.position)<-.2,"Focused near camera is inside actual air,not clipping rock or forcing material selection");camera.look_at(target);light.position=camera.position+Vector3(0,.5,0);var thin_original:Image=await picture(family+"_first_selected_thin_near")
			for node:MeshInstance3D in clear_materials:node.material_override=CrystalSurface.new().feature_material("mineral_opaque",definition.material_configuration,true)
			var opaque:Image=await picture(family+"_selected_thin_forced_opaque")
			if thin_original.get_data()!=opaque.get_data():transmission_positive+=1
			for node:MeshInstance3D in clear_materials:node.material_override=clear_materials[node]
			var thin_return:Image=await picture(family+"_selected_thin_return");check(thin_original.get_data()==thin_return.get_data(),"Near selected transmission independent toggle exact return")
		records.append({"family":family,"seed":chosen.seed,"chosen_primary":chosen,"primary_camera":"(32,22,37)","first_selected_thin":first_clear,"final_camera":str(camera.position),"cells":nodes.size(),"feature_nodes":feature_nodes.size(),"placements":placement_count,"vertices":vertex_count,"collision_vertices":collision_vertices,"near_primitives":near_primitives,"forced_far_primitives":far_primitives,"image_lod_changed":original.get_data()!=far.get_data(),"clear_batches":clear_materials.size()})
		for node:Node in nodes:node.queue_free()
		stream.free();await process_frame
	check(lod_positive>=1,"Actual native renderer submits fewer primitives at lower index LOD,not metadata-only fake LOD")
	check(transmission_positive>=1,"Selected thin near optics visibly differ from opaque counterfactual;ordinary thick crystals remain opaque")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable native Crystal inspection source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_cave_crystal_features.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"records":records,"positive_native_lod_cases":lod_positive,"positive_selective_transmission_cases":transmission_positive,"scope":"First positive primaries of six mineral families from predeclared36seed controlled shared chamber,actual host PBR/native hard-facet crystal/vein meshes and batch materials,original main sky/sun/fog/camera50km,natural and explicit120m4energy TEST-ONLY light,geometry-off/exact-return,forced native index-LOD primitive count and selected thin-opaque counterfactual/exact return. Root viewport threshold0 disables index LOD;10000 diagnostic forces low detail,normal project unchanged. Density1 only isolates form breadth;normal world occurrence/.65density/live streaming and reference-quality art/FPS remain unproved."},"  "));print("CRYSTAL_RENDER ",checks," families=",picks.size()," lod=",lod_positive," transmission=",transmission_positive," failures=",failures);scene.queue_free();light.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
