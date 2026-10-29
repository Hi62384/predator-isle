extends "res://tools/biome_extensions/check_all.gd"
const Field=preload("res://scripts/caves/field.gd")
const Mesher=preload("res://scripts/caves/mesher.gd")
const Streamer=preload("res://scripts/caves/streamer.gd")
var captures:Dictionary={}
func sample(label:String)->float:
	for frame in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var picture:Image=root.get_texture().get_image();var sum:float=0;var count:int=0
	for y in range(picture.get_height()/3,picture.get_height()*4/5,8):
		for x in range(picture.get_width()/4,picture.get_width()*3/4,8):
			var color:Color=picture.get_pixel(x,y);sum+=color.r*.2126+color.g*.7152+color.b*.0722;count+=1
	var path:String="res://tools/biome_extensions/artifacts/cave_lighting_"+label+".png";check(picture.save_png(path)==OK,"Native cave lighting capture "+label);captures[path]=FileAccess.get_sha256(path);return sum/maxi(1,count)
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/field.gd","res://scripts/caves/mesher.gd","res://scripts/caves/streamer.gd","res://scripts/caves/surface_renderer.gd","res://scripts/caves/surface_shader.gd","res://shaders/default_cave_rock.gdshader","res://tools/caves/check_lighting.gd","res://scenes/main.tscn"]:guards[path]=FileAccess.get_sha256(path)
	var height:Callable=func(_x:float,_z:float)->float:return 120
	var field=Field.new();check(field.compile([{"valid":true,"nodes":[{"point":Vector3(32,20,32),"level":0,"chamber_radius":24.0,"chamber_height":24.0}],"edges":[]}],height),"Closed one-cell actual implicit chamber,not an open lighting backdrop")
	var arrays:Array=Mesher.new().build(field,Vector3i.ZERO,2);check(not arrays.is_empty(),"Real inward-facing cave volume extracted")
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);var stream=Streamer.new();mesh.surface_set_material(0,stream.material_for(Vector3i.ZERO));stream.free();var node:=MeshInstance3D.new();node.mesh=mesh;root.add_child(node)
	var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.remove_child(terrain);terrain.free();var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;root.add_child(scene);scene.get_node("Interface").hide();camera.position=Vector3(32,25,39);camera.look_at(Vector3(32,25,20));var sun:DirectionalLight3D=scene.get_node("Sun")
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;var unblocked:float=await sample("unblocked_negative")
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED;var blocked:float=await sample("double_sided_roof")
	sun.visible=false;var ambient:float=await sample("sun_off_control")
	check(unblocked>.07 and blocked<unblocked*.85,"Real closed roof occludes positive direct sunlight;no-cast negative visibly exposes it")
	check(blocked<=ambient+.015,"Sun-on roof result agrees with independent sun-off control within bounded render tolerance")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable cave lighting source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_lighting.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"mean_luminance":{"no_cast_negative":unblocked,"double_sided_roof":blocked,"sun_off":ambient},"scope":"Native GPU actual mesher/material in a closed synthetic one-cell chamber. Original main-scene sun/sky/fog/camera50kmfar;explicit no-cast and sun-off negatives isolate real roof shadowing. Material shelter term attenuates ambient only. Not an actual-world entrance/deepest-chamber art certificate."},"  "));print("CAVE_LIGHTING ",checks," mean=",unblocked,"/",blocked,"/",ambient," failures=",failures);node.queue_free();scene.queue_free();quit(0 if failures.is_empty() else 1)
