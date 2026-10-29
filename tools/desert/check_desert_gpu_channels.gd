extends SceneTree
## Tests attribute transport and shared vertex-stage decoder. Binary endpoint
## colors avoid GL's approximate display gamma causing false numerical failures.
## This fixture does not certify the full terrain material or world performance.
const ROWS: int = 8
const COLS: int = 23
const SIZE := Vector2i(1472, 512)
var report: Dictionary = {"completed":false,"actual_render":false,"positive_cases":183,"negative_cases":1,"pixel_checks":0,"negative_detected":false,"failures":[]}
var begun: int

func _initialize() -> void:
	call_deferred("run")

func save_report() -> void:
	report["elapsed_s"] = (Time.get_ticks_msec()-begun)/1000.0
	var file := FileAccess.open("res://tools/diagnostics/artifacts/channel_report.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"\t"))

func fail(message: String) -> void:
	report.failures.append(message)
	push_error(message)
	save_report()
	quit(1)

func byte_row(row: int) -> PackedInt32Array:
	var values := PackedInt32Array()
	for col in range(COLS):
		var value: int = (row * 47 + col * 73) % 256
		if row == 0: value = 0
		if row == 1: value = 255
		if row == 2: value = (col % 10) + 3
		if row == 7: value = (13 + col * 12) % 256
		values.append(value)
	return values

func run() -> void:
	begun = Time.get_ticks_msec()
	var headless: bool = DisplayServer.get_name() == "headless"
	if not headless:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(SIZE)
		root.size=SIZE
	if headless: root.size=SIZE # Synthetic dimensions for structural checking only.
	report.merge({"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"viewport":[root.size.x,root.size.y],"decoder_sha256":FileAccess.get_sha256("res://shaders/desert_control_decode.gdshaderinc")})
	if OS.get_cmdline_user_args().has("require-render") and headless:
		fail("Actual GL display required"); return
	if root.size != SIZE:
		fail("Unexpected viewport dimensions"); return
	if not headless and RenderingServer.get_current_rendering_method() != "gl_compatibility":
		fail("GL compatibility renderer required"); return
	var shader := Shader.new()
	shader.code = '''shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
#include "res://shaders/desert_control_decode.gdshaderinc"
varying float verified;
void vertex() {
 vec4 r,s,w; decode_desert_controls(CUSTOM1,r,s,w);
 int channel=int(UV.x+0.5);
 float actual=0.0;
 if(channel<4)actual=r[channel];
 else if(channel<8)actual=s[channel-4];
 else if(channel<12)actual=w[channel-8];
 else if(channel<15)actual=CUSTOM0[channel-12];
 else if(channel==15)actual=CUSTOM2.x;
 else if(channel<19)actual=desert_unpack24(CUSTOM2.y)[channel-16];
 else if(channel<22)actual=desert_unpack24(CUSTOM2.z)[channel-19];
 else actual=CUSTOM2.w;
 verified=abs(actual-UV.y/255.0)<0.001?1.0:0.0;
}
void fragment(){ ALBEDO=verified>0.5?vec3(0.0,1.0,0.0):vec3(1.0,0.0,0.0); }
'''
	shader.get_shader_uniform_list()
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var geology := PackedFloat32Array()
	var packed := PackedFloat32Array()
	var detail := PackedFloat32Array()
	var indices := PackedInt32Array()
	var cpu_positive: int = 0
	var cpu_negative: int = 0
	for row in range(ROWS):
		var expected := byte_row(row)
		for col in range(COLS):
			var actual := expected.duplicate()
			var intentional: bool = row == 7 and col == 7
			if intentional: actual[7] += 37 # Only surface.w changes, with no byte carry.
			var encoded := PackedFloat32Array()
			for i in range(4): encoded.append(actual[i*3]+actual[i*3+1]*256+actual[i*3+2]*65536)
			var decoded: int = actual[col] if col >= 12 else ((int(encoded[col/3]) >> ((col%3)*8)) & 255)
			if decoded == expected[col]: cpu_positive += 1
			else: cpu_negative += 1
			var offset: int = vertices.size()
			var x: float = -float(COLS)*0.5 + col
			var y: float = 4.0 - row
			for p in [Vector2(x+0.04,y-0.04),Vector2(x+0.96,y-0.04),Vector2(x+0.96,y-0.96),Vector2(x+0.04,y-0.96)]:
				vertices.append(Vector3(p.x,p.y,0.0))
				uvs.append(Vector2(col,expected[col]))
				colors.append(Color(1.0,0.0 if row%2==0 else 1.0,0.0,0.0))
				for i in range(3): geology.append(actual[12+i]/255.0)
				packed.append_array(encoded)
				detail.append_array(PackedFloat32Array([actual[15]/255.0,float(actual[16]+actual[17]*256+actual[18]*65536),float(actual[19]+actual[20]*256+actual[21]*65536),actual[22]/255.0]))
			indices.append_array(PackedInt32Array([offset,offset+1,offset+2,offset,offset+2,offset+3]))
	if cpu_positive != 183 or cpu_negative != 1:
		fail("Numeric control fixture construction failed"); return
	report["cpu_fixture_positive"] = cpu_positive
	report["cpu_fixture_negative"] = cpu_negative
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_TEX_UV]=uvs; arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_CUSTOM0]=geology; arrays[Mesh.ARRAY_CUSTOM1]=packed; arrays[Mesh.ARRAY_INDEX]=indices
	arrays[Mesh.ARRAY_CUSTOM2]=detail
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},(Mesh.ARRAY_CUSTOM_RGB_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)|(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)|(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT))
	var material := ShaderMaterial.new(); material.shader=shader
	var scene := Node3D.new(); root.add_child(scene)
	var instance := MeshInstance3D.new(); instance.mesh=mesh; instance.material_override=material; scene.add_child(instance)
	var camera := Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=8.0; camera.position=Vector3(0,0,5); scene.add_child(camera); camera.current=true
	var world := WorldEnvironment.new(); var environment := Environment.new()
	environment.background_mode=Environment.BG_COLOR; environment.background_color=Color(0.1,0.1,0.1)
	environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR; world.environment=environment; scene.add_child(world)
	for i in range(8): await process_frame
	if not headless:
		await RenderingServer.frame_post_draw
		var image: Image=root.get_texture().get_image()
		if image==null or image.get_size()!=SIZE:
			fail("Invalid actual framebuffer"); return
		if image.save_png("res://tools/diagnostics/artifacts/channel_probe.png")!=OK:
			fail("Cannot save actual framebuffer"); return
		var max_error: int=0
		for row in range(ROWS):
			for col in range(COLS):
				var intentional: bool=row==7 and col==7
				var color: Color=image.get_pixel(col*64+32,row*64+32)
				var desired:=Color.RED if intentional else Color.GREEN
				var error: int=0
				for channel in range(3):
					error=maxi(error,absi(roundi(color[channel]*255)-roundi(desired[channel]*255)))
					report.pixel_checks+=1
				max_error=maxi(max_error,error)
				if intentional: report.negative_detected=error<=2
			report["max_pixel_error_bytes"]=max_error
		report.actual_render=true
		if max_error>2 or not report.negative_detected:
			fail("GPU channel gate failed; inspect binary control tiles"); return
	report.merge({"completed":true,"rendered_frames":Engine.get_frames_drawn(),"vertices":vertices.size(),"static_memory_bytes":OS.get_static_memory_usage(),"gpu_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"scope":"Headless only validates structure; actual_render plus 552 framebuffer checks is required for GPU acceptance."},true)
	save_report(); print(JSON.stringify(report)); scene.queue_free(); await process_frame; quit()
