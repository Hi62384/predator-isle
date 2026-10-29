extends "res://tools/biome_extensions/check_all.gd"
func run()->void:
	assert(DisplayServer.get_name()!="headless");var guards:Dictionary={}
	for path:String in ["res://tools/biome_extensions/check_insect_earth_phase.gd","res://tools/biome_extensions/insect_earth_candidate.gdshader","res://tools/biome_extensions/insect_earth_optics.gdshaderinc"]:guards[path]=FileAccess.get_sha256(path)
	var viewport:=SubViewport.new();viewport.size=Vector2i(512,192);viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var shader:=Shader.new();shader.code='''shader_type canvas_item;
const bool OUTPUT_IS_SRGB=true;
#include "res://tools/biome_extensions/insect_earth_optics.gdshaderinc"
void fragment(){
 vec2 pixel=floor(UV*vec2(512,192));float x=mod(pixel.x,128.0),y=mod(pixel.y,32.0);int mode=int(floor(pixel.x/128.0)),row=int(floor(pixel.y/32.0));
 vec3 point=vec3((x-64.0)*.25,(y-16.0)*.25,(x+y-80.0)*.25);
 vec3 origin=vec3(-81920,0,-114688);
 if(row==1)origin=vec3(81920,256,114688);
 if(row==2)origin=vec3(-3840,-3840,-3840);
 if(row==3)origin=vec3(3840,3840,3840);
 if(row==4)origin=vec3(-256,512,-512);
 if(row==5)origin=vec3(1024,-256,256);
 vec3 world=origin+point,p=world;
 if(mode==1)p=point+mod(origin,vec3(3840.0));
 if(mode==2)p=world+vec3(3840.0,-3840.0,7680.0);
 if(mode==3)p=point+abs(mod(origin,vec3(3840.0)))+vec3(37.0,11.0,-29.0);
 COLOR=vec4(earth_noise(p,12.0),earth_noise(p,.8),earth_noise(p,.08),1);
}'''
	var material:=ShaderMaterial.new();material.shader=shader;var rect:=ColorRect.new();rect.size=Vector2(512,192);rect.material=material;viewport.add_child(rect)
	for frame in range(12):await process_frame
	await RenderingServer.frame_post_draw;var picture:Image=viewport.get_texture().get_image();var maximum:float=0;var negative:int=0
	for y in range(192):
		for x in range(128):
			var reference:Color=picture.get_pixel(x,y)
			for offset:int in [128,256]:
				var actual:Color=picture.get_pixel(x+offset,y);var error:float=maxf(absf(reference.r-actual.r),maxf(absf(reference.g-actual.g),absf(reference.b-actual.b)));maximum=maxf(maximum,error)
				check(error<=2.0/255,"Signed chunk reconstruction/common period preserves actual GPU noise at every scale")
			var wrong:Color=picture.get_pixel(x+384,y)
			if absf(reference.r-wrong.r)>.02 or absf(reference.g-wrong.g)>.02 or absf(reference.b-wrong.b)>.02:negative+=1
	check(negative>20000,"Deliberately wrong material phase is detected,not a blank panel")
	var capture:String="res://tools/biome_extensions/artifacts/insect_earth_phase_gpu.png";check(picture.save_png(capture)==OK,"Saved complete phase reference/control panel")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable private earth phase source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_insect_earth_phase.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":{capture:FileAccess.get_sha256(capture)},"maximum_gpu_phase_error":maximum,"detected_negative_pixels":negative,"scope":"Private49152GPU full-world/reference versus signed-chunk reconstruction/common3840mperiod comparisons at three actual material scales,six signed/distant origins.24576deliberately wrong controls. Unchanged2/255bound. This tests phase continuity,not independent CPU hash arithmetic,all-world art,normal mapping or performance."},"  "))
	print("INSECT_EARTH_PHASE ",checks," maximum=",maximum," negative=",negative," failures=",failures.size());viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
