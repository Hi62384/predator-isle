extends "res://tools/biome_extensions/check_all.gd"
const Candidate=preload("res://tools/biome_extensions/insect_sculpted_mound_candidate.gd")
func arrays(g)->Array:return [g.vertices,g.normals,g.colors,g.uvs]
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/insect_vent_geometry.gd","res://tools/biome_extensions/insect_mound_profile_candidate.gd","res://tools/biome_extensions/insect_sculpted_mound_candidate.gd","res://tools/biome_extensions/check_insect_mound_profiles.gd"]:guards[path]=FileAccess.get_sha256(path)
	var b=preload("res://tools/biome_extensions/flat_conduit_builder.gd").new();b._configure_noise();var cases:Array=[]
	for kind in range(6):
		for phase:float in [.17,2.3,5.7]:
			var before=Structures.new();var after=Candidate.new();var anchor:=Vector3(0,-8,0);var width:float=42;var height:float=120;var vent:float=12 if kind in [0,3,5] else 0
			for g in [before,after]:g.mound(b,anchor,width,height,kind,phase,Color(.44,.27,.14),vent)
			check(before.vertices.size()==after.vertices.size() and before.colors==after.colors and before.uvs==after.uvs,"Original triangle/material budgets retained");var changed:int=0;var max_radius:float=0;var edges:Dictionary={}
			for i in range(after.vertices.size()):
				var p:Vector3=after.vertices[i];check(p.is_finite() and after.normals[i].is_finite() and absf(after.normals[i].length()-1)<.0001,"Finite unit native geometry/normals");check(p.y==before.vertices[i].y,"Every original elevation unchanged");changed+=int(p!=before.vertices[i]);max_radius=maxf(max_radius,Vector2(p.x,p.z).length());
				if before.vertices[i].y<=-8 or before.vertices[i].y>=112-.0001:check(p==before.vertices[i],"Every buried foundation and summit/rim vertex exact")
			for i in range(0,after.vertices.size(),3):
				var a:Vector3=after.vertices[i];var bv:Vector3=after.vertices[i+1];var c:Vector3=after.vertices[i+2];check((c-a).cross(bv-a).length_squared()>.00000001,"No new degenerate triangle");
				for pair:Array in [[a,bv],[bv,c],[c,a]]:
					var key:Array=pair if pair[0]<pair[1] else [pair[1],pair[0]];edges[key]=int(edges.get(key,0))+1
			for edge:Array in edges:check(edges[edge]==2 or (edges[edge]==1 and edge[0].y<=-8 and edge[1].y<=-8),"No new open boundary beyond original buried base")
			check(max_radius<width*1.9,"Complete radial envelope stays inside existing primary/satellite cave guards");check(arrays(after)==arrays(before) if kind==3 else changed>1000,"Dome exact;positive actual shell change for other construction forms");cases.append({"kind":kind,"phase":phase,"vertices":after.vertices.size(),"changed_vertices":changed,"maximum_radial_extent_m":max_radius})
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable mound profile source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_insect_mound_profiles.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":cases,"production_registration":false,"scope":"Private equal-budget shell study:18fixed6-archetype/3-phase controls,unequal-height construction ribs/erosion. Every vertex elevation/color/UV and all buried foot/summit/rim positions unchanged;complete finite unit normals,nondegenerate faces,closed seams and conservative footprint. Dome unchanged. Not yet actual worker/native art/collision/performance acceptance or adoption."},"  "));print("INSECT_MOUND_PROFILES ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
