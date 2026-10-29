extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540)
	var scene:=Node3D.new();root.add_child(scene);var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2;camera.position.z=2;camera.current=true;scene.add_child(camera)
	var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded;void fragment(){ALBEDO=vec3(1,0,0);}"
	var material:=ShaderMaterial.new();material.shader=shader;var records:Array=[];var failures:Array=[];var negative_detected:int=0;var captures:Dictionary={}
	for point:Vector3 in [Vector3(-.6,.3,0),Vector3(.6,-.2,0),Vector3(.1,.55,0)]:
		var node:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.04,.04);node.mesh=quad;node.material_override=material;node.position=point;scene.add_child(node)
		for idle in range(16):await process_frame
		await RenderingServer.frame_post_draw;var image:Image=root.get_texture().get_image();var raster:=Vector2(image.get_size());var logical:Vector2=camera.get_viewport().get_visible_rect().size;var projected:Vector2=camera.unproject_position(point);var expected:Vector2=projected*raster/logical
		var sum:=Vector2.ZERO;var count:int=0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var color:Color=image.get_pixel(x,y)
				if color.r>.6 and color.g<.2 and color.b<.2:sum+=Vector2(x+.5,y+.5);count+=1
		assert(count>0);var actual:Vector2=sum/count;var corrected_error:float=actual.distance_to(expected);var wrong_error:float=actual.distance_to(projected)
		if corrected_error>1:failures.append("Corrected logical-to-raster projection misses GPU centroid "+str(point))
		if wrong_error>20:negative_detected+=1
		var path:String="res://tools/biome_extensions/artifacts/raster_camera_%d.png"%records.size();assert(image.save_png(path)==OK);captures[path]=FileAccess.get_sha256(path)
		records.append({"point":str(point),"raster_size":str(raster),"logical_viewport_size":str(logical),"camera_unproject_logical":str(projected),"expected_raster_center":str(expected),"actual_red_quad_centroid":str(actual),"corrected_error_pixels":corrected_error,"unscaled_error_pixels":wrong_error});node.queue_free();await process_frame
	if negative_detected<2:failures.append("Unscaled camera-coordinate negative must be independently detected at two GPU-known points")
	var guards:Dictionary={}
	for path:String in ["res://tools/biome_extensions/check_raster_camera_coordinates.gd","res://project.godot"]:guards[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_raster_camera_coordinates.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":guards,"capture_sha256":captures,"cases":records,"detected_unscaled_negatives":negative_detected,"scope":"Actual GPU centroid of three known small orthographic quads at960x540 under the UNCHANGED project's canvas_items1280x720 logical stretch. Camera projection coordinates compare with raster dimensions. Corrected conversion must match within one pixel;unscaled negative must miss by20pixels at two sites. No terrain/collision/art claim."},"  "));scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
