extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var integer_mode:bool=OS.get_cmdline_user_args().has("integer")
	var wide:bool=OS.get_cmdline_user_args().has("wide")
	var label:String=("integer_period_gpu" if integer_mode else "float_period_gpu")+("_wide" if wide else "")
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(256,256));root.size=Vector2i(256,256)
	# The project stretches a1280x720 canvas by default; explicitly make this
	# pixel-addressed arithmetic fixture256x256 too. The first attempt drew
	# only a51px square and is preserved as a failed fixture,not GPU evidence.
	root.content_scale_size=Vector2i(256,256)
	var values:=PackedFloat32Array();var negatives:Dictionary={};var origins:Array=[]
	for i in range(65536):
		var step:int=16384 if wide else 256
		var x:int=clampi((i*7919)%65537-32768,-32768,32767)*step;var z:int=clampi((i*11939)%65537-32768,-32768,32767)*step
		var rx:int=posmod(x,30);var rz:int=posmod(z,30)
		if i%29==0:rx=posmod(rx+1,30);negatives[i]=true
		values.append_array(PackedFloat32Array([x,z,rx,rz]));origins.append([x,z])
	var input:=Image.create_from_data(256,256,false,Image.FORMAT_RGBAF,values.to_byte_array());var texture:=ImageTexture.create_from_image(input)
	var shader:=Shader.new();shader.code="shader_type canvas_item;render_mode unshaded;uniform sampler2D inputs:filter_nearest,repeat_disable;void fragment(){vec4 a=texture(inputs,UV);vec2 d=abs(mod(a.xy,vec2(30.0))-a.zw);d=min(d,abs(d-vec2(30)));bool same=all(lessThan(d,vec2(.01)));COLOR=same?vec4(1):vec4(1,0,0,1);}"
	if integer_mode:
		# Execute the candidate's actual arithmetic,not a second implementation.
		var instructions:String=preload("res://tools/biome_extensions/biological_integer_period_candidate.gd").REPLACEMENT.get_slice("vec3 p=",0).replace("forest_origin","vec3(a.x,0,a.y)")
		shader.code=shader.code.replace("vec2 d=abs(",instructions+"vec2 d=abs(").replace("mod(a.xy,vec2(30.0))","vec2(float(biological_phase.x),float(biological_phase.z))")
	var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("inputs",texture)
	var panel:=ColorRect.new();panel.size=Vector2(256,256);panel.material=material;root.add_child(panel)
	for frame in range(8):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var failures:Array=[];var detected:int=0
	for i in range(65536):
		var color:Color=image.get_pixel(i%256,i/256);var same:bool=color.g>.9 and color.b>.9
		if negatives.has(i):
			if not same:detected+=1
			else:failures.append({"index":i,"negative_not_detected":true,"origin":origins[i]})
		elif not same:failures.append({"index":i,"incorrect_float_remainder":true,"origin":origins[i]})
	var path:String="res://tools/biome_extensions/artifacts/"+label+"_remainders.png";assert(image.save_png(path)==OK)
	var sources:Dictionary={}
	for source:String in ["res://tools/biome_extensions/check_float_period_gpu.gd","res://tools/biome_extensions/biological_float_period_candidate.gd","res://tools/biome_extensions/biological_integer_period_candidate.gd"]:sources[source]=FileAccess.get_sha256(source)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_"+label+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":sources,"capture_sha256":{path:FileAccess.get_sha256(path)},"integer_mode":integer_mode,"wide":wide,"origin_min_m":-536870912 if wide else -8388608,"origin_max_m":536854528 if wide else 8388352,"cases":65536,"detected_negatives":detected,"expected_negatives":negatives.size(),"production_registration":false,"scope":"Actual Compatibility GPU remainder versus exact signed CPU integer remainder,65536 paired XZ chunk-aligned origins in the explicitly recorded range. Injected one-metre phase errors must be detected. Current terrain/attached-shell origins have Y0; this is not arbitrary transformed geometry,out-of-range coordinates,complete tissue filtering or whole-scene resource acceptance."},"  "))
	print("FLOAT_PERIOD_GPU ",65536," cases / ",detected," negatives / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
