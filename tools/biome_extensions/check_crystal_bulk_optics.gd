extends SceneTree
const Candidate=preload("res://tools/biome_extensions/crystal_bulk_candidate.gd")
class Support:
	extends RefCounted
	func _get_height(_x:float,_z:float)->float:return 0.0
var checks:int=0
var failures:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label)
func throughput(kind:int,thickness:float,incidence:float,tint:Vector3)->Vector3:
	var path:float=maxf(thickness,.01)/maxf(incidence,.2);var amount:float=[.42,.28,.52,.18,.60,.04][kind]*exp(-[.15,.18,.18,.25,.12,.30][kind]*path)
	return Vector3(amount*exp(-(1-clampf(tint.x,0,1))*path*.035),amount*exp(-(1-clampf(tint.y,0,1))*path*.035),amount*exp(-(1-clampf(tint.z,0,1))*path*.035))
func _initialize()->void:call_deferred("run")
func run()->void:
	assert(DisplayServer.get_name()!="headless");var guards:Dictionary={}
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://tools/biome_extensions/crystal_bulk_candidate.gd","res://tools/biome_extensions/crystal_bulk_optics.gdshaderinc","res://tools/biome_extensions/crystal_bulk_candidate.gdshader","res://tools/biome_extensions/check_crystal_bulk_optics.gd"]:guards[path]=FileAccess.get_sha256(path)
	var b:=Support.new();var geometry:Array=[]
	for habit:int in range(6):
		for width:float in [2,24,80]:
			var original=preload("res://scripts/biome_extension_structures.gd").new();var candidate=Candidate.new()
			for g in [original,candidate]:g.prism(b,Vector3(30,-8,50),width,240,habit,.7,Vector2(.1,-.08),false,Color(.6,.4,.7))
			check(original.vertices==candidate.vertices and original.normals==candidate.normals and original.colors==candidate.colors,"Only optical UV metadata changes,not shape/normals/material tint")
			for uv:Vector2 in candidate.uvs:
				check(floori(uv.x)==habit and uv.x>=habit and uv.x<=habit+.25,"Stable six-habit semantic ID and normalized growth coordinate")
				check(is_equal_approx(uv.y,2*width*(.14 if habit==2 else 1)),"Optical thickness from actual emitted cross-section,including thin blades")
			geometry.append({"habit":habit,"width":width,"thickness":candidate.uvs[0].y,"vertices":candidate.vertices.size()})
	var viewport:=SubViewport.new();viewport.size=Vector2i(256,192);viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var shader:=Shader.new();shader.code='shader_type canvas_item;\n#include "res://tools/biome_extensions/crystal_bulk_optics.gdshaderinc"\nvoid fragment(){vec2 pixel=floor(UV*vec2(256,192));int kind=int(floor(pixel.y/32.0));float incidence=.2+mod(pixel.y,32.0)/31.0*.8;vec3 through=mineral_throughput(kind,.05+pixel.x*.25,incidence,vec3(.6,.4,.7));COLOR=vec4(through,1);}'
	var material:=ShaderMaterial.new();material.shader=shader;var rect:=ColorRect.new();rect.size=Vector2(256,192);rect.material=material;viewport.add_child(rect)
	for frame in range(12):await process_frame
	await RenderingServer.frame_post_draw;var image:Image=viewport.get_texture().get_image();var maximum:float=0;var negative_checks:int=0
	for y in range(192):
		for x in range(256):
			var kind:int=y/32;var expected:Vector3=throughput(kind,.05+x*.25,.2+float(y%32)/31*.8,Vector3(.6,.4,.7));var actual:Color=image.get_pixel(x,y)
			var error:float=maxf(absf(actual.r-expected.x),maxf(absf(actual.g-expected.y),absf(actual.b-expected.z)));maximum=maxf(maximum,error);check(error<=2.0/255,"Actual GPU mineral absorption matches independent physical-width formula")
			check(actual.r>=0 and actual.r<=.6+2.0/255 and actual.g>=0 and actual.g<=.6+2.0/255 and actual.b>=0 and actual.b<=.6+2.0/255,"Bounded nonnegative transmission")
			if x>160 and actual.r<.005 and actual.g<.005 and actual.b<.005:negative_checks+=1
	for habit:int in range(6):
		var thin:Vector3=throughput(habit,.1,1,Vector3(.6,.4,.7));var thick:Vector3=throughput(habit,40,1,Vector3(.6,.4,.7))
		check(thick.x<.005 and thick.y<.005 and thick.z<.005 and thin.x>thick.x,"Large masses opaque without making every thin crystal opaque")
	var capture:String="res://tools/biome_extensions/artifacts/crystal_bulk_optics_gpu.png";check(image.save_png(capture)==OK,"GPU absorption panel saved")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable optical trial source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_crystal_bulk_optics.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":{capture:FileAccess.get_sha256(capture)},"maximum_gpu_cpu_channel_error":maximum,"bulk_opaque_gpu_samples":negative_checks,"geometry_cases":geometry,"production_registration":false,"scope":"PRIVATE18complete six-habit/three-width primitive pairs,actual minimum physical cross-section/growth metadata,and49152 actual GPU Beer-Lambert samples versus independent CPU formula,unchanged2/255 bound. All geometry/normals/colors exact;only UV metadata added. Transmission bounded≤.6 and40m masses below.005 for every mineral,while thin sections retain transmission. Authored approximation,not measured PBR scans or ray-traced internal thickness. Native material/full-controller integration/visual acceptance separate."},"  "))
	print("CRYSTAL_BULK_OPTICS ",checks," error=",maximum," failures=",failures);viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
