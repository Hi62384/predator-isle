extends "res://tools/biome_extensions/check_conduit_footings.gd"
const Junction=preload("res://tools/biome_extensions/surface_guided_complex_candidate.gd")
func run()->void:
	var hashes:Dictionary={}
	for source:String in ["res://tools/biome_extensions/surface_guided_junction_candidate.gd","res://tools/biome_extensions/surface_guided_membrane_candidate.gd"]:hashes[source]=FileAccess.get_sha256(source)
	for path:String in ["res://tools/biome_extensions/reference_pre_membrane_junction_geometry.gd","res://scripts/alien_junction_geometry.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://tools/biome_extensions/check_surface_guide_topology.gd","res://tools/biome_extensions/junction_flutes_candidate.gd","res://tools/biome_extensions/membrane_geometry_candidate.gd","res://tools/biome_extensions/surface_guided_complex_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		for scale:float in [.2,1.0,2.0]:
			var b=make_builder(7,seed_id);b.settings.alien_infected.feature_scale=scale;b._configure_noise()
			var field=b._extras[7];var p:Vector2=field.hive_node(Vector2i(-12,-12));var edges:PackedVector2Array=field.network_edges(Vector2i(-12,-12))
			var directions:Array[Vector2]=[(edges[1]-p).normalized(),(edges[5]-p).normalized()]
			var g=Structures.new();g.origin=Vector3(p.x,0,p.y);g._support_steps=Structures.support_grids()
			var height:float=120*scale;var width:float=75*scale;var base:float=b._get_height(p.x,p.y)
			Junction.new().emit(g,b,p,directions,width,height,.47)
			check(not g.vertices.is_empty(),"Actual rooted junction geometry")
			var edge_counts:Dictionary={};var feet:Dictionary={};var maximum_y:float=-INF
			for i in range(0,g.vertices.size(),3):
				var outward:Vector3=(g.vertices[i+2]-g.vertices[i]).cross(g.vertices[i+1]-g.vertices[i]).normalized()
				check(outward.length()>.99,"No degenerate junction triangles")
				for j in range(3):
					var v:Vector3=g.vertices[i+j]+g.origin;maximum_y=maxf(maximum_y,v.y)
					check(v.is_finite() and g.normals[i+j].is_finite() and absf(g.normals[i+j].length()-1)<.001,"Finite junction vertices/unit normals")
					check(outward.dot(g.normals[i+j])>.149,"Smoothed junction normal outside actual face")
					check(g.uvs[i+j].x>=0 and g.uvs[i+j].x<=5 and g.uvs[i+j].y>=0 and g.uvs[i+j].y<=1,"Actual semantic tissue controls")
					var a:String=str(g.vertices[i+j]);var c:String=str(g.vertices[i+(j+1)%3]);var key:String=a+"|"+c if a<c else c+"|"+a
					edge_counts[key]=int(edge_counts.get(key,0))+1
					if g.colors[i+j].a<.1 and not feet.has(v):
						feet[v]=true
						for step:float in g._support_steps:check(v.y<=chord_height(b,Vector2(v.x,v.z),step)-31.5,"Junction foot below every terrain lattice")
			for count:int in edge_counts.values():check(count==2,"Closed two-face junction edges, no fake openings")
			check(feet.size()==82,"Both blades, curved strut and membrane have complete buried roots")
			check(absf(maximum_y-(base+height))<.02,"Configured monument height, independent of LOD")
			check(g._footing_vertices.is_empty() and g._conduit_uvs.is_empty(),"Transient semantic maps cleared")
			cases.append({"seed":seed_id,"scale":scale,"position":p,"height_m":height,"triangles":g.vertices.size()/3,"buried_feet":feet.size(),"closed_edges":edge_counts.size()})
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_surface_guide_topology.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"scope":"Private fluted blades, curved strut and thick closed membrane along actual network directions, three seeds and three feature scales; normals, tissue controls, independent terrain support bounds, closed edge incidence and configured height. Not production registration, native staging/collision/walk or artistic acceptance."},"  "))
	print("MEMBRANE_JUNCTION_CANDIDATE ",checks," checks; failures=",failures);quit(0 if failures.is_empty() else 1)
