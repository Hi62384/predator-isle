extends "res://tools/biome_extensions/check_all.gd"
const Network=preload("res://tools/caves/cave_network_candidate.gd")
const Field=preload("res://tools/caves/cave_field_candidate.gd")
const Reference=preload("res://tools/caves/cave_mesher_candidate.gd")
const Candidate=preload("res://tools/caves/cave_gradient_mesher_candidate.gd")
func oriented_edges(positions:PackedVector3Array)->Dictionary:
	var edges:Dictionary={};var contradictory:int=0;var paired:int=0;var open:int=0;var nonmanifold:int=0
	for i in range(0,positions.size(),3):
		for j in range(3):
			var a:Vector3=positions[i+j];var b:Vector3=positions[i+(j+1)%3]
			for axis in range(3):
				if a[axis]==0:a[axis]=0.0
				if b[axis]==0:b[axis]=0.0
			var forward:bool=a.x<b.x or (a.x==b.x and (a.y<b.y or (a.y==b.y and a.z<b.z)));var id:String=PackedVector3Array([a,b] if forward else [b,a]).to_byte_array().hex_encode();var record:Vector2i=edges.get(id,Vector2i.ZERO);edges[id]=record+Vector2i(1,1 if forward else -1)
	for id:String in edges:
		var record:Vector2i=edges[id]
		if record.x==2:paired+=1;contradictory+=int(record.y!=0)
		elif record.x==1:open+=1
		else:nonmanifold+=1
	return {"paired":paired,"same_direction_pairs":contradictory,"single_edges_including_chunk_boundary":open,"nonmanifold":nonmanifold}
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://tools/caves/diagnose_gradient_winding.gd","res://tools/caves/cave_network_candidate.gd","res://tools/caves/cave_route_solver_candidate.gd","res://tools/caves/cave_field_candidate.gd","res://tools/caves/cave_mesher_candidate.gd","res://tools/caves/cave_gradient_mesher_candidate.gd","res://tools/biome_extensions/artifacts/profile_cave_gradient_mesher.json"]:guards[path]=FileAccess.get_sha256(path)
	var b=make_builder(3,73921);var network=Network.new();network.configure(b._get_height,b.get_water_surface_height,73921);network.activity=1;var data:Dictionary=network.region(Vector2i(9,-3));var field=Field.new();assert(field.compile([data],b._get_height));var report=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/profile_cave_gradient_mesher.json"));var records:Array=[];var total_old:int=0;var total_new:int=0
	for pair:Dictionary in report.paired_chunks:
		if pair.equal:continue
		var numbers:PackedStringArray=String(pair.key).trim_prefix("(").trim_suffix(")").split(",");var key:=Vector3i(int(numbers[0]),int(numbers[1]),int(numbers[2]));var a:Array=Reference.new().build(field,key,2);var c:Array=Candidate.new().build(field,key,2);var old:Dictionary=oriented_edges(a[Mesh.ARRAY_VERTEX]);var current:Dictionary=oriented_edges(c[Mesh.ARRAY_VERTEX]);var flipped:int=0;var position_changes:int=0;var normal_changes:int=0;var examples:Array=[];var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var w:PackedVector3Array=c[Mesh.ARRAY_VERTEX];check(v.size()==w.size(),"Same triangle count in differing orientation cell")
		for i in range(0,mini(v.size(),w.size()),3):
			if v[i]==w[i] and v[i+1]==w[i+2] and v[i+2]==w[i+1]:flipped+=1
			elif v[i]!=w[i] or v[i+1]!=w[i+1] or v[i+2]!=w[i+2]:position_changes+=1
			if a[Mesh.ARRAY_NORMAL][i]!=c[Mesh.ARRAY_NORMAL][i] or a[Mesh.ARRAY_NORMAL][i+1]!=c[Mesh.ARRAY_NORMAL][i+1] or a[Mesh.ARRAY_NORMAL][i+2]!=c[Mesh.ARRAY_NORMAL][i+2]:normal_changes+=1
			if examples.size()<8 and (v[i]!=w[i] or v[i+1]!=w[i+1] or v[i+2]!=w[i+2]):examples.append({"triangle":i/3,"world_centroid":str(Vector3(key)*64+(v[i]+v[i+1]+v[i+2])/3),"reference_face":str((v[i+2]-v[i]).cross(v[i+1]-v[i]).normalized()),"candidate_face":str((w[i+2]-w[i]).cross(w[i+1]-w[i]).normalized())})
		total_old+=old.same_direction_pairs;total_new+=current.same_direction_pairs;records.append({"cell":str(key),"reference_edges":old,"candidate_edges":current,"flipped_triangles":flipped,"other_position_changes":position_changes,"triangles_with_changed_normal_order_or_value":normal_changes,"examples":examples});print("WINDING_DIAGNOSTIC ",records[-1]);await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable winding diagnostic source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/diagnose_cave_gradient_winding.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":records,"reference_same_direction_internal_edge_pairs":total_old,"candidate_same_direction_internal_edge_pairs":total_new,"production_registration":false,"scope":"Diagnostic characterization of all9differing cells from failed exact-equivalence comparison. Internal edge winding only;single edges can be chunk boundaries. No adoption/exact-equivalence/full-topology certificate."},"  "));quit(0 if failures.is_empty() else 1)
