extends "res://tools/biome_extensions/check_all.gd"
const Network=preload("res://tools/caves/cave_network_candidate.gd")
const Field=preload("res://tools/caves/cave_field_candidate.gd")
func edge(a:Vector3,b:Vector3)->Dictionary:return {"points":PackedVector3Array([a,b]),"half_width":4.0,"headroom":8.0,"from":"a","to":"b","entrance":false}
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://tools/caves/check_supported_junctions.gd","res://tools/caves/cave_network_candidate.gd","res://tools/caves/cave_route_solver_candidate.gd","res://tools/caves/cave_field_candidate.gd"]:guards[path]=FileAccess.get_sha256(path)
	var n=Network.new();var retained:Dictionary=edge(Vector3(-40,0,0),Vector3(40,0,0))
	check(n.supported_join(edge(Vector3(0,0,-40),Vector3(0,0,40)),[retained]),"Same-floor crossing remains an open supported junction")
	check(not n.supported_join(edge(Vector3(0,7,-40),Vector3(0,7,40)),[retained]),"Original seven-metre air-union floor-cut mechanism rejected")
	check(not n.supported_join(edge(Vector3(0,-7,-40),Vector3(0,-7,40)),[retained]),"Reversed vertical order equally rejected")
	check(n.supported_join(edge(Vector3(0,16,-40),Vector3(0,16,40)),[retained]),"True rock-separated overpass admitted")
	check(n.supported_join(edge(Vector3(0,0,20),Vector3(40,0,20)),[retained]),"Separated horizontal passage admitted")
	var b=make_builder(3,73921);n.configure(b._get_height,b.get_water_surface_height,73921);n.activity=1;var data:Dictionary=n.region(Vector2i(9,-3));check(data.valid and data.nodes.size()==17 and data.edges.size()==20,"Original Spore graph keeps all seventeen nodes/twenty edges,not a pruned positive substitute")
	var field=Field.new();check(field.compile([data],b._get_height),"All original graph geometry participates in floor-support validation")
	var observations:Array=[];var failure_points:Array=[];var minimum_field:float=0;var maximum_floor_loss:float=0
	for edge_id in range(data.edges.size()):
		var points:PackedVector3Array=data.edges[edge_id].points;var loss:float=0
		for i in range(points.size()-1):
			for fraction:float in [0.0,.5]:
				var p:Vector3=points[i].lerp(points[i+1],fraction);minimum_field=minf(minimum_field,field.sample(p));var depth:float=0
				while depth<12 and field.sample(p-Vector3.UP*depth)<-.001:depth+=.05
				loss=maxf(loss,depth);check(depth<=.35,"Whole-field floor support at original route edge%d/station%d/fraction%.1f"%[edge_id,i,fraction])
				if depth>.35:failure_points.append({"edge":edge_id,"station":i,"fraction":fraction,"point":str(p),"floor_loss_m":depth})
		maximum_floor_loss=maxf(maximum_floor_loss,loss);observations.append({"edge":edge_id,"points":points.size(),"maximum_floor_loss_m":loss})
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable junction source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_supported_junctions.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"failure_points":failure_points,"source_sha256":guards,"seed":73921,"region":"(9,-3)","observations":observations,"maximum_floor_loss_m":maximum_floor_loss,"minimum_field_at_planned_floor":minimum_field,"production_registration":false,"scope":"PRIVATE pure-field support validation at every station/midpoint of ALL20original graph routes,plus incompatible crossing negative controls. Same original geographic entrance and all17nodes,not mesh/native/capsule/streaming acceptance."},"  "));print("SUPPORTED_JUNCTIONS ",checks," max_loss=",maximum_floor_loss," failures=",failures," points=",failure_points);quit(0 if failures.is_empty() else 1)
