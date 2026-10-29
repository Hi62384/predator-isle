extends "res://tools/biome_extensions/check_conduit_footings.gd"
const Web=preload("res://tools/biome_extensions/membrane_geometry_candidate.gd")
const Candidate=preload("res://tools/biome_extensions/membrane_junction_candidate.gd")
const Junction=preload("res://tools/biome_extensions/reference_pre_membrane_junction_geometry.gd")
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://tools/biome_extensions/reference_pre_membrane_junction_geometry.gd","res://scripts/alien_junction_geometry.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/check_conduit_footings.gd","res://tools/biome_extensions/junction_flutes_candidate.gd","res://tools/biome_extensions/membrane_geometry_candidate.gd","res://tools/biome_extensions/membrane_junction_candidate.gd","res://tools/biome_extensions/check_membrane_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		for scale:float in [.2,1,2]:
			var b=make_builder(7,seed_id);b.settings.alien_infected.feature_scale=scale;b._configure_noise();var field=b._extras[7]
			var p:Vector2=field.hive_node(Vector2i(-12,-12));var edges:PackedVector2Array=field.network_edges(Vector2i(-12,-12));var axis:Vector2=(edges[1]-p).normalized();var directions:Array[Vector2]=[axis,(edges[5]-p).normalized()]
			var width:float=75*scale;var height:float=120*scale;var base:float=b._get_height(p.x,p.y)
			var g=Structures.new();g.origin=Vector3(p.x,0,p.y);g._support_steps=Structures.support_grids();Web.new().emit(g,b,p,axis,width,height,.47)
			check(g.vertices.size()==5136,"Fixed bounded 1712-triangle closed membrane component")
			var edge_counts:Dictionary={};var feet:Dictionary={};var unique:Dictionary={};var minimum_y:float=INF;var maximum_y:float=-INF
			for i in range(0,g.vertices.size(),3):
				var outward:Vector3=(g.vertices[i+2]-g.vertices[i]).cross(g.vertices[i+1]-g.vertices[i]).normalized()
				check(outward.length()>.99,"No degenerate web triangles")
				for j in range(3):
					var v:Vector3=g.vertices[i+j]+g.origin;minimum_y=minf(minimum_y,v.y);maximum_y=maxf(maximum_y,v.y);unique[v]=true
					check(v.is_finite() and g.normals[i+j].is_finite() and absf(g.normals[i+j].length()-1)<.001,"Finite membrane vertices and unit geometric normals")
					check(outward.dot(g.normals[i+j])>.299,"Actual normals remain in outward hemisphere")
					check(g.uvs[i+j].x==3 and g.uvs[i+j].y>=0 and g.uvs[i+j].y<=1,"Actual membrane tissue role and canonical feature control")
					var a:String=str(g.vertices[i+j]);var c:String=str(g.vertices[i+(j+1)%3]);var key:String=a+"|"+c if a<c else c+"|"+a;edge_counts[key]=int(edge_counts.get(key,0))+1
					if g.colors[i+j].a<.1 and not feet.has(v):
						feet[v]=true
						for step:float in g._support_steps:check(v.y<=chord_height(b,Vector2(v.x,v.z),step)-31.5,"Membrane far root below every supported terrain chord")
			for count:int in edge_counts.values():check(count==2,"Every membrane edge has exactly two incident faces")
			check(feet.size()==26,"Complete buried far-root cross-section")
			check(maximum_y<=base+height*1.03 and maximum_y-minimum_y>height*.3,"Physical wall extent, not a flattened surface card")
			check(g._footing_vertices.is_empty() and g._conduit_uvs.is_empty(),"Transient maps cleared")
			var original=Structures.new();var disabled=Structures.new()
			for builder in [original,disabled]:builder.origin=g.origin;builder._support_steps=g._support_steps
			Junction.new().emit(original,b,p,directions,width,height,.47);var candidate=Candidate.new();candidate.membrane_enabled=false;candidate.longitudinal_ribs=false;candidate.emit(disabled,b,p,directions,width,height,.47)
			check(original.vertices==disabled.vertices and original.normals==disabled.normals and original.colors==disabled.colors and original.uvs==disabled.uvs,"Exact original junction when private membrane switch is disabled")
			cases.append({"seed":seed_id,"scale":scale,"vertices":g.vertices.size(),"triangles":1712,"closed_edges":edge_counts.size(),"unique_vertices":unique.size(),"buried_feet":feet.size(),"vertical_extent_m":maximum_y-minimum_y})
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable private geometry source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_membrane_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"private_reference_only":true,"mutates_production":false,"scope":"Private thick closed membrane between an existing junction blade and curved root strut, three seeds/scales, bounded geometry, outward geometric normals, membrane material role, complete buried far-root chord support and exact disabled original junction. Not production registration, attachment-envelope/native collision/walk, visual or performance acceptance."},"  "))
	print("MEMBRANE_CANDIDATE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
