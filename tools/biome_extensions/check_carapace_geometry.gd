extends "res://tools/biome_extensions/check_conduit_footings.gd"
const Carapace=preload("res://scripts/alien_carapace_geometry.gd")
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/alien_carapace_geometry.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://tools/biome_extensions/check_carapace_geometry.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		for scale:float in [.2,1.0,2.0]:
			for habit:int in [2,5]:
				var b=make_builder(7,seed_id);b.settings.alien_infected.feature_scale=scale;b._configure_noise();var field=b._extras[7]
				var p:Vector2=field.hive_node(Vector2i(-12,-12));var edges:PackedVector2Array=field.network_edges(Vector2i(-12,-12));var axis:Vector2=(edges[1]-p).normalized()
				var g=Structures.new();g.origin=Vector3(p.x,0,p.y);g._support_steps=Structures.support_grids()
				Carapace.new().emit(g,b,p,axis,240*scale,100*scale,.7,habit)
				check(g.vertices.size()==18000,"Three complete closed plate shells")
				var edge_counts:Dictionary={};var feet:Dictionary={}
				for i in range(0,g.vertices.size(),3):
					var normal:Vector3=(g.vertices[i+2]-g.vertices[i]).cross(g.vertices[i+1]-g.vertices[i]).normalized()
					check(normal.length()>.99,"No degenerate carapace faces")
					for j in range(3):
						var v:Vector3=g.vertices[i+j]+g.origin
						check(v.is_finite() and g.normals[i+j].is_finite() and absf(g.normals[i+j].length()-1)<.001,"Finite carapace geometry/unit normals")
						check(normal.dot(g.normals[i+j])>.699,"Hard/smoothed plate normals stay outward")
						check(g.uvs[i+j]==Vector2(habit,1),"Explicit hardened/mineralized tissue habit")
						check((g.colors[i+j].r>.5)==(habit==5),"Distinct dormant mineralized palette tag")
						var a:String=str(g.vertices[i+j]);var c:String=str(g.vertices[i+(j+1)%3]);var key:String=a+"|"+c if a<c else c+"|"+a
						edge_counts[key]=int(edge_counts.get(key,0))+1
						if g.colors[i+j].a<.1 and not feet.has(v):
							feet[v]=true
							for step:float in g._support_steps:check(v.y<=chord_height(b,Vector2(v.x,v.z),step)-31.5,"Plate margin buried below each terrain lattice")
				for count:int in edge_counts.values():check(count==2,"Closed two-face plate edges")
				check(feet.size()==120,"All three forty-sided roots checked")
				check(g._footing_vertices.is_empty() and g._conduit_uvs.is_empty(),"Transient plate controls cleared")
				cases.append({"seed":seed_id,"scale":scale,"habit":habit,"triangles":g.vertices.size()/3,"buried_feet":feet.size(),"closed_edges":edge_counts.size()})
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable plate source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_carapace_geometry.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"scope":"Three seeds, three feature extents, hardened/dormant habits, closed three-plate topology, outward unit normals, explicit material tags and independent terrain-lattice burial. Placement, native collision and full-scene visual review are separate."},"  "))
	print("CARAPACE_GEOMETRY ",checks," checks; failures=",failures);quit(0 if failures.is_empty() else 1)
