extends "res://tools/biome_extensions/check_all.gd"
const BeforeShoulders=preload("res://tools/biome_extensions/reference_pre_junction_structures.gd")
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/biome_extension_structures.gd","res://tools/biome_extensions/reference_pre_junction_structures.gd","res://tools/biome_extensions/flat_conduit_builder.gd","res://tools/biome_extensions/check_conduit_shoulders.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[];var legacy_steep_faces:int=0;var preserved_crests:int=0
	for width:float in [8,12,20,40]:
		for phase:float in [.4,2.1,5.3]:
			var b=preload("res://tools/biome_extensions/flat_conduit_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.alien_infected_coverage=100;b._configure_noise()
			var g=Structures.new();g._support_steps=Structures.support_grids();g.conduit(b,Vector2.ZERO,Vector2(2000,0),width,phase,Color(.34,.28,.26))
			var old=BeforeShoulders.new();old._support_steps=g._support_steps;old.conduit(b,Vector2.ZERO,Vector2(2000,0),width,phase,Color(.34,.28,.26))
			var segments:int=clampi(ceili(2000.0/96),16,64);var side_vertex_count:int=segments*14*6
			var minimum_new_y:float=1;var minimum_old_y:float=1;var exposed:int=0
			for i in range(0,side_vertex_count,3):
				var top:float=maxf(g.vertices[i].y,maxf(g.vertices[i+1].y,g.vertices[i+2].y))
				if top>.01:
					var normal:Vector3=(g.vertices[i+2]-g.vertices[i]).cross(g.vertices[i+1]-g.vertices[i]).normalized()
					minimum_new_y=minf(minimum_new_y,normal.y);exposed+=1
					check(normal.y>cos(deg_to_rad(45)),"Exposed longitudinal shoulder below default capsule slope limit on flat ground")
				var old_top:float=maxf(old.vertices[i].y,maxf(old.vertices[i+1].y,old.vertices[i+2].y))
				if old_top>.01:
					var normal:Vector3=(old.vertices[i+2]-old.vertices[i]).cross(old.vertices[i+1]-old.vertices[i]).normalized();minimum_old_y=minf(minimum_old_y,normal.y)
					if normal.y<cos(deg_to_rad(45)):legacy_steep_faces+=1
			for i in range(g.vertices.size()):
				var v:Vector3=old.vertices[i];var t:float=v.x/2000
				var center_z:float=sin(t*PI)*width*.8
				if absf(v.z-center_z)<.0001 and v.y>.1:
					check(v==g.vertices[i],"Exact original ridge crest retained");preserved_crests+=1
			cases.append({"width":width,"phase":phase,"exposed_side_triangles":exposed,"new_maximum_face_slope_degrees":rad_to_deg(acos(clampf(minimum_new_y,-1,1))),"legacy_maximum_face_slope_degrees":rad_to_deg(acos(clampf(minimum_old_y,-1,1)))})
	check(legacy_steep_faces>100,"Legacy exposed steep-face negative control detected")
	check(preserved_crests>100,"Substantial exact crest comparisons")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable shoulder source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_conduit_shoulders.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"legacy_steep_faces_detected":legacy_steep_faces,"preserved_crest_vertices":preserved_crests,"source_sha256":hashes,"scope":"Four conduit widths and three phases on a test-only flat canonical field, actual exposed longitudinal triangle normals versus unchanged default 45-degree floor limit, with original-shape negative controls and exact crest preservation. End caps and arbitrary natural ground gradients are not asserted walkable; production route checks are separate."},"  "))
	print("CONDUIT_SHOULDERS ",checks," checks; failures=",failures);quit(0 if failures.is_empty() else 1)
