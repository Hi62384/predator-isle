extends SceneTree
var failures:Array=[]
var checks:int=0
func verify(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:call_deferred("run")
func picture()->Image:
	for frame in range(4):await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func error(a:Image,b:Image)->int:
	var aa:PackedByteArray=a.get_data();var bb:PackedByteArray=b.get_data();var result:int=0
	for i in range(aa.size()):result=maxi(result,absi(int(aa[i])-int(bb[i])))
	return result
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(384,192));root.size=Vector2i(384,192)
	var paths:Array[String]=[get_script().resource_path,"res://tools/biome_extensions/tissue_target_candidate.gd","res://shaders/biological_sampling.gdshaderinc","res://shaders/alien_tissue_flow.gdshaderinc","res://shaders/biome_structures.gdshader","res://materials/biological_colors_v3.tres"]
	var guards:Dictionary={}
	for path:String in paths:guards[path]=FileAccess.get_sha256(path)
	var historical:String="res://tools/biome_extensions/biological_pre_compact_targets.gdshaderinc.txt";guards[historical]=FileAccess.get_sha256(historical)
	var tissue:String=FileAccess.get_file_as_string(historical);var compact:String=load(paths[1]).apply_to(tissue)
	verify(compact==FileAccess.get_file_as_string(paths[2]),"Exact independently tested compact shader adopted in production")
	var shell:String=FileAccess.get_file_as_string(paths[4]);var begin:int=shell.find("float field(vec2 p)");var end:int=shell.find("#include",begin)
	var prefix:String="shader_type spatial;render_mode unshaded,cull_disabled,fog_disabled;uniform vec3 probe_origin=vec3(0);uniform vec3 probe_normal=vec3(0,1,0);uniform float probe_distance=0.0;uniform bool probe_rough=false;varying vec3 world_position;varying vec3 forest_local_position;varying vec3 forest_origin;\n"+shell.substr(begin,end-begin)
	var suffix:String="\nvoid vertex(){forest_origin=probe_origin;forest_local_position=vec3(UV.x*24.0,UV.y*13.0,UV.y*19.0);world_position=forest_local_position+probe_origin;}void fragment(){vec3 n=normalize(probe_normal);vec3 projection=pow(abs(n),vec3(6));projection/=dot(projection,vec3(1));vec3 c;float r;alien_tissue_sample(UV.x*6.0,probe_distance,dFdx(forest_local_position),dFdy(forest_local_position),projection,n,c,r);ALBEDO=probe_rough?vec3(r):c;}"
	var original:=ShaderMaterial.new();var candidate:=ShaderMaterial.new();var shader:=Shader.new();shader.code=prefix+tissue+suffix;original.shader=shader;var next:=Shader.new();next.code=prefix+compact+suffix;candidate.shader=next
	var atlas:=Image.create_empty(2,2,false,Image.FORMAT_RGBAF)
	atlas.set_pixel(0,0,Color(0,0,.7,1));atlas.set_pixel(1,0,Color(12,0,.8,1));atlas.set_pixel(0,1,Color(0,16,.6,2));atlas.set_pixel(1,1,Color(12,16,.9,3))
	var flow:=ImageTexture.create_from_image(atlas)
	for material:ShaderMaterial in [original,candidate]:
		material.set_shader_parameter("biological_colors",load(paths[5]));material.set_shader_parameter("alien_tissue_flow",flow);material.set_shader_parameter("alien_tissue_flow_span",Vector2(64,64));material.set_shader_parameter("alien_tissue_flow_offset",Vector2(-16,-16))
	var scene:=Node3D.new();root.add_child(scene);var node:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(2,1);node.mesh=quad;scene.add_child(node);var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1;camera.position.z=2;camera.current=true;scene.add_child(camera)
	var rows:Array=[];var worst:int=0;var captures:Dictionary={}
	for origin:Vector3 in [Vector3.ZERO,Vector3(-98304,32768,-65536)]:
		for normal:Vector3 in [Vector3.UP,Vector3(1,.7,-.4),Vector3(-1,-.3,.6)]:
			for distance:float in [0.0,400.0,1100.0,1800.0,2000.0]:
				for mode in range(3):
					for material:ShaderMaterial in [original,candidate]:
						material.set_shader_parameter("probe_origin",origin);material.set_shader_parameter("probe_normal",normal);material.set_shader_parameter("probe_distance",distance);material.set_shader_parameter("probe_rough",mode==2);material.set_shader_parameter("alien_tissue_flow_enabled",mode>0);material.set_shader_parameter("alien_tissue_variation_enabled",mode>0)
					node.material_override=original;var before:Image=await picture();node.material_override=candidate;var after:Image=await picture();node.material_override=original;var returned:Image=await picture();var maximum:int=error(before,after);worst=maxi(worst,maximum)
					verify(maximum<=2,"Original/compact actual RGB within declared2bytes for "+str(rows.size()));verify(before.get_data()==returned.get_data(),"Exact independent original return "+str(rows.size()))
					if rows.size() in [0,3,18,48,75]:
						for pair:Array in [["original",before],["compact",after]]:
							var path:String="res://tools/biome_extensions/artifacts/compact_tissue_"+str(rows.size())+"_"+pair[0]+".png";verify(pair[1].save_png(path)==OK,"Saved tissue comparison");captures[path]=FileAccess.get_sha256(path)
					rows.append({"origin":origin,"normal":normal,"distance":distance,"mode":mode,"maximum_rgba_byte_error":maximum})
	for path:String in guards:verify(FileAccess.get_sha256(path)==guards[path],"Stable independent tissue comparison "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_compact_tissue_gpu.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"cases":rows,"worst_rgba_byte_error":worst,"scope":"90 native original/compact/original helper panels across all six regional types continuously,positive/negative far origins,three signed projections,five near/fade/far distances,flow junction/variation ON/OFF and roughness. Same real authored textures and synthetic three-path atlas;predeclared2byte maximum,exact original return. Separate full mixed scene/cold memory test;not reference-art acceptance."},"  "))
	print("COMPACT_TISSUE_GPU ",checks," worst=",worst," failures=",failures.slice(0,5));scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
