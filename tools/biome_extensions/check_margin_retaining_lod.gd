extends "res://tools/biome_extensions/check_all.gd"
const Candidate=preload("res://tools/biome_extensions/margin_retaining_lod_candidate.gd")
func attributes(g)->Array:return [g.vertices,g.normals,g.colors,g.uvs]
func margin_attributes(g)->Array[String]:
	var values:Array[String]=[]
	for i in range(g.vertices.size()):
		if g.colors[i].a<.9:values.append(var_to_bytes([g.vertices[i],g.normals[i],g.colors[i],g.uvs[i]]).hex_encode())
	values.sort();return values
func boundary(g)->Dictionary:
	var incidence:Dictionary={};var endpoints:Dictionary={}
	for i in range(0,g.vertices.size(),3):
		for edge in range(3):
			var a:Vector3=g.vertices[i+edge];var b:Vector3=g.vertices[i+(edge+1)%3]
			var sa:String=var_to_bytes(a).hex_encode();var sb:String=var_to_bytes(b).hex_encode();var key:String=sa+sb if sa<sb else sb+sa
			incidence[key]=int(incidence.get(key,0))+1;endpoints[key]=[a,b]
	var result:Dictionary={}
	for key:String in incidence:
		if incidence[key]==1:result[key]=endpoints[key]
		else:check(incidence[key]==2,"No nonmanifold internal edge in retained-margin mesh")
	return result
func run()->void:
	var hashes:Dictionary={}
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	for path:String in ["res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/biome_extension_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://scripts/forest_sampler.gd","res://scripts/rocky_coast_sampler.gd","res://scripts/beach_sampler.gd","res://tools/biome_extensions/check_margin_retaining_lod.gd","res://tools/biome_extensions/margin_retaining_lod_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[];var reduced:int=0
	for seed_id:int in [73921,17,92881]:
		for scale_value:float in [.2,1,2]:
			for mode:String in ["mixed","coastal","alternate_noise"]:
				var b=make_builder(7,seed_id);b.settings.alien_infected.feature_scale=scale_value
				if mode=="mixed":b.settings.forest_coverage=100;b.settings.alien_infected_coverage=50
				if mode=="coastal":b.settings.rocky_coast_enabled=true;b.settings.beaches_enabled=true
				b._configure_noise()
				if mode=="alternate_noise":b._extras[7]._macro.noise_type=FastNoiseLite.TYPE_PERLIN
				var field=b._extras[7];var a:Vector2=field.hive_node(Vector2i(-113,-103));var end:Vector2=field.hive_node(Vector2i(-112,-103));var width:float=24*scale_value
				for phase:float in [0,.47,2.3,5.9]:
					var old=Structures.new();old.origin=Vector3(floorf(a.x/256)*256,0,floorf(a.y/256)*256);old._support_steps=Structures.support_grids();old.conduit(b,a,end,width,phase,Color(.34,.28,.26))
					var trial=Candidate.new();trial.origin=old.origin;trial._support_steps=old._support_steps
					check(not is_finite(trial.global_floor(b)),"No unsupported mixed/coastal/alternate-noise global height bound assumed")
					var span:int=16384;var owner:=Vector2i(floori(a.x/span),floori(a.y/span));var context:Dictionary={"bounds":Rect2(Vector2(owner)*span,Vector2.ONE*span),"ratio":.5,"floor":INF}
					b.set_meta(trial.CONTEXT,context);trial.conduit(b,a,end,width,phase,Color(.34,.28,.26));b.remove_meta(trial.CONTEXT)
					check(trial.vertices.size()<=old.vertices.size(),"Distant candidate adds no hidden triangles")
					check(margin_attributes(trial)==margin_attributes(old),"EVERY original full-resolution footing/apron position, normal, colour, UV and multiplicity remains exact")
					check(boundary(trial)==boundary(old),"Exact original buried boundary, no new open/T-junction edge")
					var original_positions:Dictionary={}
					for v:Vector3 in old.vertices:original_positions[v]=true
					for i in range(trial.vertices.size()):
						check(original_positions.has(trial.vertices[i]) and trial.normals[i].is_finite() and trial.normals[i].length_squared()>.99,"Retained actual positions and finite unit normals, no new displaced core")
					if trial.vertices.size()<old.vertices.size():reduced+=1
					cases.append({"seed":seed_id,"scale":scale_value,"mode":mode,"phase":phase,"span_m":span,"original_vertices":old.vertices.size(),"trial_vertices":trial.vertices.size(),"simplified_intervals":trial.retained_intervals,"full_winding_fallback_intervals":trial.fallback_intervals})
					# A near context and the independent public zero flag must both
					# retain complete original arrays, not merely matching feet.
					if phase==0:
						for disabled:bool in [false,true]:
							var near=Candidate.new();near.origin=old.origin;near._support_steps=old._support_steps
							b.settings.alien_infected.hive_structure_lod_enabled=not disabled
							var size:int=16384 if disabled else 256;var q:=Vector2i(floori(a.x/size),floori(a.y/size))
							b.set_meta(near.CONTEXT,{"bounds":Rect2(Vector2(q)*size,Vector2.ONE*size),"ratio":.5,"floor":INF});near.conduit(b,a,end,width,phase,Color(.34,.28,.26));b.remove_meta(near.CONTEXT)
							check(attributes(near)==attributes(old),"Complete near/zero-mode arrays remain exact")
						b.settings.alien_infected.hive_structure_lod_enabled=true
	check(cases.size()==108 and reduced>0,"All 108 declared seed/scale/host/phase cases, including real reductions")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable private margin LOD source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_margin_retaining_lod.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"reduced_cases":reduced,"source_sha256":hashes,"production_registration":false,"scope":"Private primitive tests across three seeds, three scales, mixed/shore-enabled/alternate-noise hosts and four phases. Exact all original full-resolution contact/apron attributes and boundary edges, near/zero arrays, retained original core samples and unit normals. New upper bands simplify only when projected winding is valid; otherwise original band retained. No analytic bound assumed for unsupported hosts. Full worker memo/cut ownership, whole tile performance, native views/physics and production registration remain separate."},"  "))
	print("MARGIN_RETAINING_LOD ",checks," reduced=",reduced," failures=",failures);quit(0 if failures.is_empty() else 1)
