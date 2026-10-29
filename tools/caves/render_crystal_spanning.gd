extends "res://tools/caves/render_crystal_features.gd"
const InspectionScope=preload("res://tools/caves/inspection_scope.gd")
func run()->void:
	assert(DisplayServer.get_name()!="headless");var guards:Dictionary={}
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			var path:String=folder+"/"+name
			if (name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc")) and InspectionScope.is_dependency(path):guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/render_crystal_features.gd","res://tools/caves/check_crystal_features.gd","res://tools/caves/check_frozen_features.gd","res://tools/caves/inspection_scope.gd","res://scenes/main.tscn","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	check(InspectionScope.dependency_closure_valid(guards),"Unrelated character shader has no dependency in this mineral inspection")
	inspection=SubViewport.new();inspection.size=Vector2i(1280,720);inspection.own_world_3d=true;inspection.render_target_update_mode=SubViewport.UPDATE_ALWAYS;inspection.mesh_lod_threshold=0;root.add_child(inspection)
	var region:Dictionary=crystal_fixture();region.nodes[0].chamber_height=24.0
	var height:Callable=func(_x:float,_z:float)->float:return 200.0
	var field=Field.new();field.include_surface_air=false;check(field.compile([region],height,[],region.cave_biome_regions),"Original actual shared24m chamber with protected8m route")
	var generator=Crystal.new();generator.build(field,Vector3i.ZERO,73921,[],{"density":0},{});var records:Array=[]
	for family:int in range(4):
		var root_point:Vector3=generator.boundary(field,Vector3(40+family*2,23,46),Vector3.DOWN,8);check(generator.spanning_form(field,root_point,Vector3(.06,1,.03).normalized(),.45,32,family,.2,"span/"+str(family),.2),"Same first controlled joined crystal,not image-selected substitute");records.append(generator.placements[-1])
	var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.remove_child(terrain);terrain.free();check(InspectionScope.isolate_environment(scene),"Inspection-only workshop detached before ready;original scene unchanged");scene.get_node("Interface").hide();var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;inspection.add_child(scene)
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var stream=Streamer.new();stream.configuration=config;stream._bundle={"regions":[region]};var nodes:Array=[]
	for key:Vector3i in field.chunks:
		var tagged:Dictionary=Surface.bind(Mesher.new().build(field,key),field,key)
		if tagged.arrays.is_empty():continue
		var node:=MeshInstance3D.new();node.position=Vector3(key)*64;var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,tagged.arrays);mesh.surface_set_material(0,stream.material_for(key,tagged.ids));node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED;inspection.add_child(node);nodes.append(node)
	var minerals:=Node3D.new();var body:=StaticBody3D.new();body.name="CaveCollision";minerals.add_child(body);inspection.add_child(minerals);var batches:Array=[]
	for kind:String in generator.batches:
		var b:Dictionary=generator.batches[kind];var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=b.vertices;arrays[Mesh.ARRAY_NORMAL]=b.normals;arrays[Mesh.ARRAY_COLOR]=b.colors;arrays[Mesh.ARRAY_TEX_UV]=b.uvs;arrays[Mesh.ARRAY_TEX_UV2]=b.growth_uvs;batches.append({"kind":kind,"biome_id":"crystal","arrays":arrays,"lods":{},"collision_faces":b.collision_faces,"shadows":true})
	check(Renderer.attach(minerals,batches,config.biome_regions,true,true),"Actual existing native mineral upload including real joined colliders")
	camera.position=Vector3(32,22,36);camera.look_at(Vector3(43,31,46));check(field.sample(camera.position)<-.2,"Camera in actual clear air");var light:=OmniLight3D.new();light.omni_range=120;light.light_energy=4;light.shadow_enabled=true;light.position=camera.position+Vector3.UP;inspection.add_child(light);light.visible=false;await picture("spanning_natural");light.visible=true;var original:Image=await picture("spanning_test_only_light");minerals.visible=false;var off:Image=await picture("spanning_geometry_off");minerals.visible=true;var restored:Image=await picture("spanning_geometry_return");check(original.get_data()!=off.get_data(),"True joined geometry visibly present in actual native scene");check(original.get_data()==restored.get_data(),"Exact original native image restored after independent geometry toggle")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable native spanning inspection source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_cave_crystal_spanning.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"records":records,"evidence_dependency_scope":InspectionScope.description(),"scope":"Same four controlled two-ended native mineral columns as physical mechanism test,original main lighting/environment,explicit test-only lamp,actual same-volume host material and geometry-off/exact-return image. Not normal occurrence/full native streaming/FPS/reference-quality art/all-user completion."},"  "));print("CRYSTAL_SPANNING_RENDER ",checks," failures=",failures);stream.free();quit(0 if failures.is_empty() else 1)
