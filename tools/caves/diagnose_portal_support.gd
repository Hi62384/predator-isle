extends "res://tools/biome_extensions/check_all.gd"
const Network=preload("res://tools/caves/cave_network_candidate.gd")
const Field=preload("res://tools/caves/cave_portal_field_candidate.gd")
func run()->void:
	var b=make_builder(3,73921);var n=Network.new();n.configure(b._get_height,b.get_water_surface_height,73921);n.activity=1;var data:Dictionary=n.region(Vector2i(9,-3));var field=Field.new();assert(field.compile([data],b._get_height));var access:PackedVector3Array=data.edges[0].points
	var records:Array=[]
	for i in range(access.size()):
		var p:Vector3=access[i];var center:float=field.sample(p);var floor_hit:float=NAN
		for step in range(200):
			var y:float=p.y+1-step*.1
			if field.sample(Vector3(p.x,y,p.z))>=0:floor_hit=y;break
		var nearby:Array=[]
		if center<-.1:
			for edge_id in range(data.edges.size()):
				var edge:Dictionary=data.edges[edge_id];var points:PackedVector3Array=edge.points
				for j in range(points.size()-1):
					var a:Vector3=points[j];var bv:Vector3=points[j+1];var q:=Vector2(p.x-a.x,p.z-a.z);var ab:=Vector2(bv.x-a.x,bv.z-a.z);var t:float=clampf(q.dot(ab)/maxf(ab.length_squared(),.000001),0,1);var radial:float=(q-ab*t).length();var floor_y:float=lerpf(a.y,bv.y,t)
					if radial<edge.half_width and p.y>floor_y+.1 and p.y<floor_y+edge.headroom:nearby.append({"edge":edge_id,"segment":j,"floor_y":floor_y,"radial":radial})
		var record:Dictionary={"station":i,"point":str(p),"ground":b._get_height(p.x,p.z),"field_at_planned_floor":center,"first_solid_below":floor_hit,"overlaps":nearby};records.append(record)
		if center<-.1:print("UNSUPPORTED_STATION ",record)
	var failed=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_cave_portal_actual_terrain.json"));print("ACCESS_STATIONS ",access.size()," FAILED ",failed.walk)
	FileAccess.open("res://tools/biome_extensions/artifacts/diagnose_cave_portal_support.json",FileAccess.WRITE).store_string(JSON.stringify({"records":records,"scope":"Diagnostic only, original failed entrance; no acceptance or substituted geography."},"  "));quit()
