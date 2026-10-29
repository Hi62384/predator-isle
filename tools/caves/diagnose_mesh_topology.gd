extends SceneTree
func _initialize()->void:
	var original:String="res://tools/caves/check_mesh_native.gd";var source:String=FileAccess.get_file_as_string(original)
	var marker:String='\tcheck(positive_seams>=6,';assert(source.count(marker)==1)
	source=source.replace(marker,'''\tvar edge_counts:Dictionary={}
	for key:Vector3i in meshes:
		if meshes[key].is_empty():continue
		var positions:PackedVector3Array=meshes[key][Mesh.ARRAY_VERTEX]
		for i in range(0,positions.size(),3):
			for j in range(3):
				var a:Vector3=positions[i+j]+Vector3(key)*64;var b:Vector3=positions[i+(j+1)%3]+Vector3(key)*64
				for axis:int in range(3):
					if a[axis]==0:a[axis]=0.0
					if b[axis]==0:b[axis]=0.0
				if a.x>b.x or (a.x==b.x and (a.y>b.y or (a.y==b.y and a.z>b.z))):var swap:Vector3=a;a=b;b=swap
				var id:String=PackedVector3Array([a,b]).to_byte_array().hex_encode();edge_counts[id]=int(edge_counts.get(id,0))+1
	var topology_counts:Dictionary={};var bad_edges:Array=[]
	for id:String in edge_counts:
		var count:int=edge_counts[id];topology_counts[str(count)]=int(topology_counts.get(str(count),0))+1
		if count!=2 and bad_edges.size()<8:bad_edges.append({"edge":str(edge_counts[id]),"key":id})
	print("CAVE_GLOBAL_EDGE_INCIDENCE ",topology_counts," unmatched_examples=",bad_edges)
'''+marker)
	source=source.replace('"positive_shared_seams":positive_seams','"global_edge_incidence":topology_counts,"bad_edge_examples":bad_edges,"positive_shared_seams":positive_seams')
	source=source.replace('res://tools/caves/check_mesh_native.gd','res://tools/caves/diagnose_mesh_topology.gd').replace('check_cave_mesh_native.json','diagnose_cave_mesh_topology.json')
	var guard:String='var guards:Dictionary={}';assert(source.count(guard)==1);source=source.replace(guard,guard+';guards["'+original+'"]=FileAccess.get_sha256("'+original+'")')
	var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK);set_script(script);call_deferred("run")
