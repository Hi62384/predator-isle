extends "res://tools/biome_extensions/check_conduit_footings.gd"
const Candidate=preload("res://tools/biome_extensions/far_conduit_lod_candidate.gd")
func run()->void:
	var hashes:Dictionary={}
	for source:String in ["res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_sampler.gd","res://scripts/biome_extension_settings.gd","res://tools/biome_extensions/far_conduit_lod_candidate.gd","res://tools/biome_extensions/check_far_conduit_lod.gd"]:hashes[source]=FileAccess.get_sha256(source)
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		for scale_value:float in [.2,1,2]:
			var b=make_builder(7,seed_id);b.settings.alien_infected.feature_scale=scale_value;b._configure_noise();var field=b._extras[7];var a:Vector2=field.hive_node(Vector2i(-113,-103));var end:Vector2=field.hive_node(Vector2i(-112,-103))
			var old=Structures.new();old.origin=Vector3(a.x,0,a.y);old._support_steps=Structures.support_grids();old.conduit(b,a,end,24,.47,Color(.34,.28,.26))
			for span:int in [256,16384]:
				var trial=Candidate.new();trial.origin=old.origin;trial._support_steps=old._support_steps
				var cell:=Vector2i(floori(a.x/span),floori(a.y/span));var context:Dictionary={"bounds":Rect2(Vector2(cell)*span,Vector2.ONE*span),"ratio":.95,"floor":trial.global_floor(b)}
				check(is_finite(context.floor),"Supported pure-Alien analytic foundation bound")
				b.set_meta(trial.CONTEXT,context);trial.conduit(b,a,end,24,.47,Color(.34,.28,.26));b.remove_meta(trial.CONTEXT)
				var stride:int=trial.select_stride(a,end,24,context)
				if stride==1:
					check(trial.vertices==old.vertices and trial.normals==old.normals and trial.colors==old.colors and trial.uvs==old.uvs,"Exact full near conduit arrays")
				else:
					check(trial.vertices.size()<old.vertices.size(),"Actual distant triangle reduction, no root omission")
					var reference:Dictionary={}
					for i in range(old.vertices.size()):
						if old.colors[i].a>.9:reference[old.vertices[i]]=old.uvs[i]
					for i in range(trial.vertices.size()):
						var v:Vector3=trial.vertices[i]
						check(v.is_finite() and trial.normals[i].is_finite() and trial.normals[i].length_squared()>.99,"Finite far vertices and geometric normals")
						if trial.colors[i].a>.9:
							if v.y>context.floor:check(reference.has(v) and reference[v]==trial.uvs[i],"Every far exposed core sample preserves original position and material controls")
							else:
								var cap_point:=Vector2(v.x+trial.origin.x,v.z+trial.origin.z)
								check(v.y==context.floor-8 and (cap_point==a or cap_point==end),"Only the explicitly buried endpoint cap centres move with the deep far footer")
						if trial.colors[i].a<.1:
							check(v.y==context.floor,"Far root uses conservative constant terrain lower bound")
							var world:Vector3=v+trial.origin
							for step:float in trial._support_steps:check(world.y<=chord_height(b,Vector2(world.x,world.z),step)-31.9,"Far root remains buried below every supported terrain lattice")
				cases.append({"seed":seed_id,"scale":scale_value,"span":span,"stride":stride,"old_vertices":old.vertices.size(),"trial_vertices":trial.vertices.size(),"floor_m":context.floor})
			var unsupported=Candidate.new();b.settings.forest_coverage=100;b.settings.alien_infected_coverage=50;b._configure_noise();check(not is_finite(unsupported.global_floor(b)),"Mixed-owner worlds retain exact original geometry, no unsupported bound")
	for source:String in hashes:check(FileAccess.get_sha256(source)==hashes[source],"Stable private LOD source "+source)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_far_conduit_lod.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"production_change_kept":false,"scope":"Private pure-Alien coarse conduit LOD: exact near arrays, retained original exposed sample positions/controls, finite normals, reduced triangles and independent buried-footer chords over three seeds/scales. Closed topology, continuous edge support, actual landmark retention, native view/physics, cut stability and dense first-fill performance remain separate. Unsupported mixed/coastal/noise configurations fall back to original geometry."},"  "))
	print("FAR_CONDUIT_LOD_CHECK ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
