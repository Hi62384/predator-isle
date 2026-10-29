extends "res://tools/biome_extensions/check_all.gd"
const FrozenFixture=preload("res://tools/caves/frozen_fixture.gd")
const Field=preload("res://scripts/caves/portal_field.gd")
const Mesher=preload("res://scripts/caves/mesher.gd")
const Surface=preload("res://scripts/caves/surface_biomes.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Streamer=preload("res://scripts/caves/streamer.gd")
const BiomeMaterials=preload("res://scripts/caves/biome_materials.gd")
var captures:Dictionary={}
func picture(label:String)->Image:
	for frame in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/cave_frozen_surface_"+label+".png";check(image.save_png(path)==OK,"Frozen native material image "+label);captures[path]=FileAccess.get_sha256(path);return image
func run()->void:
	assert(DisplayServer.get_name()!="headless");var guards:Dictionary=FrozenFixture.guards()
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://config/caves/biomes/frozen_cave_definition.tres","res://data/cave_frozen_material_sources.json","res://scenes/main.tscn"]:guards[path]=FileAccess.get_sha256(path)
	var definition:Resource=load("res://config/caves/biomes/frozen_cave_definition.tres");check(definition.validation_errors().is_empty() and definition.biome_id==&"frozen" and definition.spawn_chance_percent==45 and definition.minimum_extent_metres==150 and definition.maximum_extent_metres==700 and definition.depth_preferences==PackedFloat32Array([100,80,40,5,0]),"Exact requested initial Frozen controls,not world-volume percentages");check(definition.surface_preferences=={"snow":100.0,"mountain":50.0,"wise_mountains":25.0,"forest":5.0,"grass":5.0},"Actual current surface names plus dormant Snow preference,all others0")
	var room:Dictionary={"id":"A","point":Vector3(32,20,32),"level":0,"chamber_radius":24.0,"chamber_height":24.0}
	var edge:Dictionary={"from":"A","to":"B","points":PackedVector3Array([Vector3(-16,20,32),Vector3(96,20,32)]),"half_width":4.0,"headroom":8.0,"entrance":false}
	var region:Dictionary={"id":Vector2i.ZERO,"valid":true,"nodes":[room],"edges":[edge],"geology":0}
	var height:Callable=func(_x:float,_z:float)->float:return 150.0
	var candidate:Dictionary={"id":"A/frozen","biome_id":"frozen","distances":{"A":0.0,"B":112.0},"reach_m":350.0,"transition_m":32.0}
	var assignment:Dictionary={"fallback":"default","candidates":[candidate]}
	var reference=Field.new();reference.include_surface_air=false
	var field=Field.new();field.include_surface_air=false
	check(reference.compile([region],height) and field.compile([region],height,[],assignment),"Same constrained volume with independent specialized scalar fields");var old:Array=Mesher.new().build(reference,Vector3i.ZERO);var arrays:Array=Mesher.new().build(field,Vector3i.ZERO);check(var_to_bytes(old)==var_to_bytes(arrays),"Frozen geography does not move any original extracted position/normal/color or walking geometry");var tagged:Dictionary=Surface.bind(arrays,field,Vector3i.ZERO);check(tagged.valid and tagged.ids==["frozen"] and tagged.arrays[Mesh.ARRAY_TEX_UV].size()==arrays[Mesh.ARRAY_VERTEX].size(),"Positive local channel atlas on actual complete native cave mesh");var maximum:float=0
	for value:Vector2 in tagged.arrays[Mesh.ARRAY_TEX_UV]:maximum=maxf(maximum,value.x)
	check(maximum==1,"Actual frozen interior has positive full-strength—not only metadata—vertex controls")
	for slot:int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR]:check(var_to_bytes(tagged.arrays[slot])==var_to_bytes(old[slot]),"All original physical/material mineral geometry channels exact")
	var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);check(config.validation_errors().is_empty(),"Existing registry accepts a new provider-backed definition without a new terrain owner");var stream=Streamer.new();stream.configuration=config;stream._bundle={"regions":[region]};var original:ShaderMaterial=stream.material_for(Vector3i.ZERO);var frozen:ShaderMaterial=stream.material_for(Vector3i.ZERO,["frozen"]);check(frozen.shader!=null and frozen.shader.code.contains("cave_frozen_sample") and frozen.shader.code.contains("cave_project_vertex"),"Actual material adapter composes existing rock/PBR/shared projection with selected ice/frost")
	var uniforms:Dictionary={}
	for uniform:Dictionary in frozen.shader.get_shader_uniform_list():uniforms[uniform.name]=true
	check(uniforms.has("cave_frozen_colors") and uniforms.has("cave_frozen_normals"),"Native renderer compiles both physical ice/frost texture banks")
	for path:String in ["res://materials/cave_frozen_colors.tres","res://materials/cave_frozen_normals.tres"]:
		var bank:Texture2DArray=load(path);check(bank.get_layers()==2 and bank.get_width()==2048 and bank.get_height()==2048,"Actual compact ice/frost bank has native2Klayers")
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,tagged.arrays);var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=original;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED;root.add_child(node);stream.free();var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.remove_child(terrain);terrain.free();var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;root.add_child(scene);camera.position=Vector3(32,23,40);camera.look_at(Vector3(25,26,22));scene.get_node("Interface").hide();var light:=OmniLight3D.new();light.position=camera.position;light.omni_range=120;light.light_energy=4;light.shadow_enabled=true;root.add_child(light)
	var original_picture:Image=await picture("original_rock");node.material_override=frozen;var ice:Image=await picture("registered_ice");check(original_picture.get_data()!=ice.get_data(),"Positive real compiled physical ice/frost shader—not a recorded biome ID only");node.material_override=original;var restored:Image=await picture("original_rock_return");check(original_picture.get_data()==restored.get_data(),"Exact same-scene material counterfactual return")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable Frozen scalar/material source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_frozen_surface.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"scope":"PRIVATE controlled full-weight Frozen region on real shared field/mesher;no saved world/owner activation. Original geometry/collision-source/mineral channels exact,local generic blend channels,provider-based actual shader/native2Kverified ice/frost banks and rock/ice/rock images with labelled test-only light. Material/geography component,not Frozen formations/waterfalls/lake/native return/live world/full biome completion."},"  "));print("FROZEN_SURFACE ",checks," max_weight=",maximum," failures=",failures);node.queue_free();scene.queue_free();light.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
