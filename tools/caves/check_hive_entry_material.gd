extends "res://tools/biome_extensions/check_all.gd"
const Surface=preload("res://scripts/caves/surface_shader.gd")
const Payload=preload("res://scripts/caves/surface_payload.gd")
const Variants=preload("res://scripts/terrain_shader_variants.gd")
var captures:Dictionary={}
func picture(label:String)->Image:
	for frame in range(8):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/cave_hive_entry_material_"+label+".png";check(image.save_png(path)==OK,"Actual native biological entry transport image "+label);captures[path]=FileAccess.get_sha256(path);return image
func max_byte_difference(a:Image,b:Image)->int:
	var first:PackedByteArray=a.get_data();var second:PackedByteArray=b.get_data();if first.size()!=second.size():return 255
	var difference:int=0
	for i in range(first.size()):difference=maxi(difference,absi(int(first[i])-int(second[i])))
	return difference
func atlas(values:PackedFloat32Array,depth:float)->Texture2D:
	var data:PackedFloat32Array=values.duplicate()
	for i in range(data.size()/68):data[i*68+67]=depth
	var packed:Dictionary=Payload.atlas(data);return ImageTexture.create_from_image(Image.create_from_data(packed.width,packed.height,false,Image.FORMAT_RGBAF,packed.bytes))
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720);var guards:Dictionary={}
	for path:String in ["res://tools/caves/check_hive_entry_material.gd","res://scripts/caves/surface_shader.gd","res://scripts/caves/surface_payload.gd","res://scripts/terrain_shader_variants.gd","res://shaders/terrain_biomes.gdshader","res://shaders/biome_extensions.gdshaderinc","res://shaders/biological_sampling.gdshaderinc","res://shaders/alien_tissue_flow.gdshaderinc","res://materials/biological_colors_v3.tres","res://scenes/main.tscn"]:guards[path]=FileAccess.get_sha256(path)
	var b=make_builder(7,73921);var coordinate:=Vector2i(-186,-186);var arrays:Array=b.build(coordinate,128);var extension:PackedByteArray=b.built_extension_data;var rows:int=b.built_extension_rows;var mesh:=ArrayMesh.new();var format:int=0
	for slot in range(4):
		var channel=arrays[Mesh.ARRAY_CUSTOM0+slot]
		if channel!=null:
			var stride:int=channel.size()/arrays[Mesh.ARRAY_VERTEX].size();check(stride==3 or stride==4,"Original native custom channel has declared RGB/RGBA stride");format|=(Mesh.ARRAY_CUSTOM_RGB_FLOAT if stride==3 else Mesh.ARRAY_CUSTOM_RGBA_FLOAT)<<(Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT+slot*Mesh.ARRAY_FORMAT_CUSTOM_BITS)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},format);var node:=MeshInstance3D.new();node.mesh=mesh;node.position=Vector3(coordinate.x*256,0,coordinate.y*256);root.add_child(node);var geometry:PackedByteArray=var_to_bytes(mesh.surface_get_arrays(0));var original:ShaderMaterial=load("res://materials/terrain.tres").duplicate();original.shader=Variants.select(original.shader,b.settings,true);original.set_shader_parameter("extension_payload",ImageTexture.create_from_image(Image.create_from_data(rows*8,rows,false,Image.FORMAT_RGBA8,extension)));original.set_shader_parameter("extension_payload_enabled",true);original.set_shader_parameter("extension_active_mask",b.built_extension_mask);original.set_shader_parameter("biological_colors",load("res://materials/biological_colors_v3.tres"));original.set_shader_parameter("alien_tissue_variation_enabled",true);var normal_values:=PackedFloat32Array();normal_values.resize(8);normal_values.fill(.7);var emission_values:=PackedFloat32Array();emission_values.resize(8);original.set_shader_parameter("extension_normals",normal_values);original.set_shader_parameter("extension_emission",emission_values)
	for bank:String in ["mountain","savanna","jungle"]:
		original.set_shader_parameter(bank+"_colors",load("res://materials/"+bank+"_colors.tres"));original.set_shader_parameter(bank+"_normals",load("res://materials/"+bank+"_normals.tres"))
	var material:ShaderMaterial=original.duplicate();var shader:=Shader.new();shader.code=Surface.code(original.shader.code,true,true,true);check(shader.code.count("alien_tissue_sample(")==1 and not shader.code.contains("shade_hive_tissue("),"Actual entry source reuses one existing biological sample instead of duplicating tissue shading");material.shader=shader;material.set_shader_parameter("cave_parent_origin",node.position);material.set_shader_parameter("cave_parent_offset",Vector3.ZERO);material.set_shader_parameter("cave_hive_entry_material",true);var values:=PackedFloat32Array()
	for i in range(arrays[Mesh.ARRAY_VERTEX].size()):values.append_array(Payload.decode(arrays,i,true))
	var surface:Texture2D=atlas(values,0);var deep:Texture2D=atlas(values,12);material.set_shader_parameter("cave_surface_payload",surface);var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.remove_child(terrain);terrain.free();var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;root.add_child(scene);scene.get_node("Interface").hide();var middle:Vector3=node.position+Vector3(128,0,128);middle.y=b._get_height(middle.x,middle.z);var poses:Array=[middle+Vector3(-180,140,-240),middle+Vector3(130,70,160),middle+Vector3(-25,8,-35)];var records:Array=[]
	for pose in range(poses.size()):
		var point:Vector3=poses[pose];point.y=maxf(point.y,b._get_height(point.x,point.z)+4);camera.position=point;camera.look_at(middle);var reference:Image;var transported:Image;var maximum:int=0
		for phase in range(5):
			node.material_override=original if phase in [0,2] else material;material.set_shader_parameter("cave_surface_payload",deep if phase==3 else surface);var image:Image=await picture("pose%d_%s"%[pose,["original","depth0_transport","original_return","depth12","depth0_return"][phase]])
			if phase==0:reference=image
			elif phase==1:transported=image;maximum=max_byte_difference(reference,image);check(maximum<=2,"Predeclared2/255full-image rounding bound for actual original/zero-depth biological entry")
			elif phase==2:check(image.get_data()==reference.get_data(),"Exact unchanged original full-image return")
			elif phase==3:check(image.get_data()!=transported.get_data(),"Positive actual physical-depth material/shelter transition")
			else:check(image.get_data()==transported.get_data(),"Exact original zero-depth full-image restoration")
		records.append({"pose":pose,"camera":str(point),"maximum_original_transport_byte_difference":maximum})
	check(var_to_bytes(mesh.surface_get_arrays(0))==geometry,"All actual native geometry/normal/color/custom/index arrays unchanged by shader transport")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable native entry material source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_hive_entry_material.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"poses":records,"scope":"Actual original Alien seed73921/fixed(-186,-186)fine parent/native full packed terrain arrays and original numeric extension atlas,configured original terrain shader versus actual single-biological-sample Hive replacement transport. Same geometry/material banks/camera/light,three controlled parent views/15images. Zero-depth output has predeclared2/255full-image rounding tolerance;original and transported counterfactual returns exact;12mdepth positive. No lowered texture/geometry/view-distance or changed production animation;fixture emission controls zero to isolate static PBR. This is preloaded material/transport proof,not full live breach streaming or reference-art acceptance."},"  "));print("CAVE_HIVE_ENTRY_MATERIAL ",checks," poses=",records," failures=",failures);node.queue_free();scene.queue_free();quit(0 if failures.is_empty() else 1)
