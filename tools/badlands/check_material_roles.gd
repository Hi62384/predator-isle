extends SceneTree
## Execute the production six-role weighting/top-three selection on the GPU.
func _initialize()->void:call_deferred("run")
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_size(Vector2i(512,512));root.size=Vector2i(512,512)
	var source:String=FileAccess.get_file_as_string("res://shaders/badlands_material.gdshaderinc")
	assert(source.count(" float w[6];")==1 and source.count(" int ids[3];")==1)
	var weights:String=source.get_slice(" float w[6];",1).get_slice(" int ids[3];",0)
	var select:String="int ids[3];"+source.get_slice(" int ids[3];",1).get_slice(" float pale_bed",0)
	var contexts:Array=[
		["hard_cap",Vector4(1,1,0,0),Vector3(0,0,0)],
		["soft_rock_face",Vector4(1,0,.65,0),Vector3(0,0,.2)],
		["flat_clay",Vector4(.2,0,.03,0),Vector3(1,0,0)],
		["wash_gravel",Vector4(.2,0,.01,1),Vector3(.3,0,0)],
		["compacted_plain",Vector4(.1,0,0,0),Vector3(0,1,0)],
		["talus_apron",Vector4(.7,0,.2,0),Vector3(0,0,0)],
		["hard_bed_clay",Vector4(1,1,.1,0),Vector3(1,0,0)],
		["quiet_fine_soil",Vector4(0,0,0,0),Vector3(.6,0,0)]]
	var a:=PackedVector4Array();var b:=PackedVector4Array();var labels:Array=[]
	for quality in [2,3]:
		for context:Array in contexts:
			a.append(context[1]);var control:Vector3=context[2];b.append(Vector4(control.x,control.y,control.z,quality));labels.append(context[0]+"/"+str(quality))
	a.append(Vector4(1,1,0,0));b.append(Vector4(0,0,0,3));labels.append("hard_cap/intentional_missing_rock")
	var shader:=Shader.new()
	var assertions:String="float sum=0.0;for(int i=0;i<6;i++)sum+=roles[i];bool ok=abs(sum-1.0)<.00001;int context=row==16?0:row%8;if(context==0 || context==6)ok=ok && roles[2]>.6;if(context==1)ok=ok && roles[2]>.25;if(context==2)ok=ok && roles[0]>.6 && roles[2]<.2;if(context==3)ok=ok && roles[4]>roles[0] && roles[4]>roles[2];if(context==4)ok=ok && roles[3]>.45;if(context==5)ok=ok && roles[5]>.1;if(context==7)ok=ok && roles[0]>.8;"
	shader.code="shader_type spatial;render_mode unshaded,fog_disabled;uniform vec4 input_a[17];uniform vec4 input_b[17];void fragment(){int row=clamp(int(UV.y*17.0),0,16);vec4 a=input_a[row],b=input_b[row];float exposed=a.x,hard=a.y,slope=a.z,deposit=a.w,clay=b.x,plain=b.y,red=b.z;int badlands_quality=int(b.w);float badlands_gravel=.65;float w[6];\n"+weights+"\n"+select+"\nfloat roles[6];for(int i=0;i<6;i++)roles[i]=0.0;for(int k=0;k<3;k++)roles[ids[k]]+=selected[k]/total;if(row==16){roles[0]=1.0;roles[1]=0.0;roles[2]=0.0;roles[3]=0.0;roles[4]=0.0;roles[5]=0.0;}"+assertions+"ALBEDO=UV.x<.333333?vec3(roles[0],roles[1],roles[2]):(UV.x<.666667?vec3(roles[3],roles[4],roles[5]):(ok?vec3(0,1,0):vec3(1,0,0)));}"
	var scene:=Node3D.new();root.add_child(scene);var quad:=MeshInstance3D.new();var mesh:=QuadMesh.new();mesh.size=Vector2(8,8);quad.mesh=mesh
	var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("input_a",a);material.set_shader_parameter("input_b",b);quad.material_override=material;scene.add_child(quad)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8;camera.position=Vector3(0,0,2);camera.current=true;scene.add_child(camera)
	for frame in range(15):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var failures:Array=[];var records:Array=[];var negative:bool=false
	for row in range(17):
		var y:int=int((row+.5)*512/17);var first:Color=image.get_pixel(85,y);var last:Color=image.get_pixel(256,y);var verdict_pixel:Color=image.get_pixel(426,y)
		var role:Array[float]=[first.r,first.g,first.b,last.r,last.g,last.b]
		var label:String=labels[row];var ok:bool=verdict_pixel.g>.98 and verdict_pixel.r<.02
		if row==16:negative=verdict_pixel.r>.98 and verdict_pixel.g<.02
		elif not ok:failures.append(label)
		records.append({"case":label,"display_encoded_roles":role,"passed":ok if row<16 else negative})
	var report:Dictionary={"actual_render":true,"renderer":RenderingServer.get_current_rendering_method(),"positive_cases":16,"intentional_negative_detected":negative,"failures":failures,"records":records,"shader_sha256":FileAccess.get_sha256("res://shaders/badlands_material.gdshaderinc"),"scope":"Actual production weighting/top-two or top-three selection for declared representative material contexts. Not a mineral certification, whole-world distribution or artistic sign-off."}
	report.weights_note="Role RGB columns are display-encoded visualizations, not linear numeric transport. Assertions run on the production weights in the shader before display conversion."
	image.save_png("res://tools/badlands/artifacts/check_material_roles.png")
	FileAccess.open("res://tools/badlands/artifacts/check_material_roles.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("BADLANDS_MATERIAL_ROLES ",failures," negative=",negative)
	scene.queue_free();await process_frame;quit(0 if failures.is_empty() and negative else 1)
