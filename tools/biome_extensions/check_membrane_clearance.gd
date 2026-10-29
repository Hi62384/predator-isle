extends "res://tools/biome_extensions/check_membrane_collision.gd"
const Web=preload("res://scripts/alien_membrane_geometry.gd")
const OldWeb=preload("res://tools/biome_extensions/reference_8m_membrane_geometry.gd")
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/alien_membrane_geometry.gd","res://scripts/biome_extension_structures.gd","res://tools/biome_extensions/reference_8m_membrane_geometry.gd","res://tools/biome_extensions/flat_conduit_builder.gd","res://tools/biome_extensions/check_membrane_collision.gd","res://tools/biome_extensions/check_membrane_clearance.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[];var minimum_gap:float=INF;var obstructed:int=0
	var b=preload("res://tools/biome_extensions/flat_conduit_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.alien_infected_coverage=100;b._configure_noise()
	for width:float in [15,75,150]:
		for height:float in [40,75,120]:
			var g=Structures.new();g._support_steps=Structures.support_grids();Web.new().emit(g,b,Vector2.ZERO,Vector2.RIGHT,width,height,.47)
			var old=Structures.new();old._support_steps=g._support_steps;OldWeb.new().emit(old,b,Vector2.ZERO,Vector2.RIGHT,width,height,.47)
			var a2:=Vector2(width*.6*sin(.65*PI*.65),width*.07*sin(.65*PI+.47)*.65)
			var center:Vector2=(a2+Vector2(width*3,0)*2+Vector2(width*3.6,0))*.25
			var ceiling_parameter:float=ray_parameter(g.vertices,Vector3(center.x,0,center.y),Vector3(center.x,1000,center.y))
			check(is_finite(ceiling_parameter),"Actual closed membrane lower face above the central route")
			var ceiling:float=ceiling_parameter*1000;var highest_floor:float=0;var worst_phase:float=0
			for index in range(24):
				var phase:float=index*TAU/24;var pipe=Structures.new();pipe._support_steps=g._support_steps
				# Actual maximum-age production conduit width. Place its real
				# midpoint crest under the web; no analytic crest approximation.
				var start:Vector2=center-Vector2(768,28*.8);pipe.conduit(b,start,start+Vector2(1536,0),28,phase,Color(.34,.28,.26))
				var floor_height:float=maxf(0,visible_height(pipe.vertices,center))
				if floor_height>highest_floor:highest_floor=floor_height;worst_phase=phase
			var gap:float=ceiling-highest_floor;minimum_gap=minf(minimum_gap,gap)
			var old_gap:float=ray_parameter(old.vertices,Vector3(center.x,0,center.y),Vector3(center.x,1000,center.y))*1000-highest_floor
			if old_gap<2.05:obstructed+=1
			check(gap>2.05,"Actual corrected membrane/conduit gap fits the unchanged capsule and headroom")
			cases.append({"width_m":width,"height_m":height,"ceiling_m":ceiling,"actual_conduit_floor_m":highest_floor,"minimum_gap_m":gap,"old_gap_m":old_gap,"worst_phase":worst_phase,"capsule_height_m":1.8,"required_headroom_m":2.05})
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable clearance diagnostic source "+path)
	# Keep the original obstruction as a required negative control.
	check(obstructed>0,"Detect inadequate canonical-only clearance negative control")
	FileAccess.open("res://tools/biome_extensions/artifacts/check_membrane_clearance.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":hashes,"cases":cases,"minimum_gap_m":minimum_gap,"old_obstructed_cases":obstructed,"scope":"Synthetic flat canonical ground and actual maximum-age conduit triangles aligned beneath the actual membrane midpoint. Three widths/heights and 24 conduit phases, corrected physical gap and frozen 8m-guard negative control. Not arbitrary natural slopes, production-world placement probability or a native capsule certificate."},"  "))
	print("MEMBRANE_CLEARANCE_DIAGNOSTIC ",minimum_gap," obstructed=",obstructed," failures=",failures);quit(0 if failures.is_empty() else 1)
