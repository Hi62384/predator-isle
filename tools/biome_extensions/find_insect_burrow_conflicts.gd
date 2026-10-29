extends "res://tools/biome_extensions/check_insect_vents.gd"
func run()->void:
	var wide:bool=OS.get_cmdline_user_args().has("wide")
	var half:float=524288 if wide else 65536
	var hashes:Dictionary={}
	for path:String in ["res://tools/biome_extensions/find_insect_burrow_conflicts.gd","res://tools/biome_extensions/check_insect_vents.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/insect_colony_sampler.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var records:Array=[];var searched:Array=[]
	for seed_id:int in [73921,17,92881]:
		var b=make_builder(6,seed_id);var guard=preload("res://scripts/terrain_feature_meshes.gd").new();guard.builder=b
		var portals:Array=guard.portal_sites(Rect2(Vector2.ONE*(-half),Vector2.ONE*half*2));var field=b._extras[6];var span:float=2100*field.settings.feature_scale
		for site:Dictionary in portals:
			var p:Vector2=site.position;var center:=Vector2i(floori(p.x/span),floori(p.y/span));var stop:bool=false
			for z in range(-1,2):
				if stop:break
				for x in range(-1,2):
					var d:Dictionary=field.descriptor(center+Vector2i(x,z),span);var q:Vector2=d.position
					if q.distance_to(p)>700 or d.chance>field.settings.structure_density or clampi(roundi(field.region(q)),0,5)==1 or b._island_mask(q.x,q.y)<.03:continue
					b.chunk_size=256;var cell:=Vector2i(floori(q.x/256),floori(q.y/256));var geometry:Array=build_structures(b,cell)
					if geometry[1]==null:continue
					var faces:PackedVector3Array=geometry[1][Mesh.ARRAY_VERTEX];var origin:=Vector3(cell.x*256,0,cell.y*256);var lowest:float=INF
					for vertex:Vector3 in faces:lowest=minf(lowest,vertex.y)
					var entry:float=96*(1+.1*sin(site.phase)-.06*sin(site.phase));var top_h:float=b._get_height(p.x+entry,p.y)+.15
					var probes:Array[Vector3]=[]
					for index in range(9):
						var distance:float=lerpf(70,entry+20,float(index)/8);var y:float=top_h if distance<entry-5 else b._get_height(p.x+distance,p.y)
						probes.append(Vector3(p.x+distance,y+.9,p.y))
					for probe:Vector3 in probes:
						var local:Vector3=probe-origin;var upper:float=top_height(faces,Vector2(local.x,local.z))
						if is_finite(upper) and upper>local.y+.9 and lowest<local.y-.9:
							records.append({"seed":seed_id,"portal_id":site.id,"portal_position":[p.x,p.y],"portal":site,"mound_id":d.id,"mound_position":[q.x,q.y],"structure_vertices":faces.size(),"probe":[probe.x,probe.y,probe.z],"upper_surface_world_y":upper,"scope":"Candidate vertical overlap only, NOT a demonstrated capsule obstruction; actual fixed-site physics return is required."});stop=true;break
					if stop:break
			if records.size()>=6:break
		searched.append({"seed":seed_id,"default_frequency":field.settings.cave_frequency,"portals":portals.size()})
		print("INSECT_BURROW_DISCOVERY ",searched[-1]," cumulative candidates=",records.size())
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable discovery source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/find_insect_burrow_conflicts"+("_wide" if wide else "")+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"checks":checks,"source_sha256":hashes,"production_registration":false,"searched":searched,"scan_half_extent_m":half,"candidates":records,"scope":"Bounded default-rarity finite-portal/mound near-overlap discovery over three seeds. Wide mode is a separately labelled larger extent, not a replacement for the original zero-candidate result. Vertical height intervals are only a conservative candidate filter, not a native obstruction proof, route acceptance, changed generation or infinite cave foundation."},"  "))
	print("INSECT_BURROW_CANDIDATES ",records.size());quit(0 if failures.is_empty() else 1)
