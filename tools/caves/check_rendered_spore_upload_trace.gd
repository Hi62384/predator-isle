extends "res://tools/caves/check_live_rendered_spore.gd"
var held:GDScript
func report_name()->String:return "check_cave_rendered_spore_upload_trace"
func capture_prefix()->String:return "cave_rendered_upload_trace"
func run()->void:
	held=load("res://scripts/caves/streamer.gd");var source:String=held.source_code
	assert(source.count("func collect()->void:\n")==1)
	source=source.replace("func collect()->void:\n","func collect()->void:\n\tvar profiler_start:int=Time.get_ticks_usec()\n")
	var marker:String="\trefresh_frontiers()\nfunc refresh_frontiers()"
	assert(source.count(marker)==1)
	source=source.replace(marker,'\trefresh_frontiers()\n\tvar profiler_us:int=Time.get_ticks_usec()-profiler_start\n\tif profiler_us>20000:print("CAVE_UPLOAD_PROFILE ms=",profiler_us/1000.0," ready=",_ready.size()," cells=",_cells.size())\n\tvar profile:Dictionary=get_tree().root.get_meta("cave_upload_trace",{})\n\tprofile["maximum_collect_ms"]=maxf(profile.get("maximum_collect_ms",0),profiler_us/1000.0);get_tree().root.set_meta("cave_upload_trace",profile)\nfunc refresh_frontiers()')
	var faces:String='shape.set_faces(data.arrays[Mesh.ARRAY_VERTEX])';assert(source.count(faces)==1)
	source=source.replace(faces,'_profile_faces(shape,data.arrays[Mesh.ARRAY_VERTEX])')
	source+='\nfunc _profile_faces(shape:ConcavePolygonShape3D,faces:PackedVector3Array)->void:\n\tvar start:int=Time.get_ticks_usec();shape.set_faces(faces);var ms:float=(Time.get_ticks_usec()-start)/1000.0\n\tvar profile:Dictionary=get_tree().root.get_meta("cave_upload_trace",{})\n\tprofile["maximum_shape_ms"]=maxf(profile.get("maximum_shape_ms",0),ms);profile["shape_builds"]=profile.get("shape_builds",0)+1;get_tree().root.set_meta("cave_upload_trace",profile)\n\tif ms>10:print("CAVE_SHAPE_PROFILE ms=",ms," triangles=",faces.size()/3)\n'
	held.source_code=source;assert(held.reload()==OK)
	await super.run()
func motion_measurements()->Dictionary:
	var result:Dictionary=super.motion_measurements();result["private_upload_profiling"]=root.get_meta("cave_upload_trace",{});result["private_instrumentation"]=true;return result
func motion_scope()->String:return super.motion_scope()+" Private timings instrument collect and native shape construction;no geometry,physics,route or loading-policy changes."
