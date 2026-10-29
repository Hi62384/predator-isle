extends "res://tools/biome_extensions/check_all.gd"
const Candidate=preload("res://tools/biome_extensions/conduit_sample_reuse_candidate.gd")
func run()->void:
	var hashes:Dictionary={}
	for source:String in ["res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_sampler.gd","res://tools/biome_extensions/conduit_sample_reuse_candidate.gd","res://tools/biome_extensions/check_conduit_sample_reuse.gd"]:hashes[source]=FileAccess.get_sha256(source)
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		for scale_value:float in [.2,1,2]:
			for mode:int in [0,1,2,3]:
				var b=make_builder(7,seed_id);b.settings.alien_infected.feature_scale=scale_value
				if mode in [1,3]:b.settings.alien_infected_coverage=25;b.settings.forest_coverage=75;b.settings.alien_infected.overlay_strength=.7
				if mode in [2,3]:b.settings.beaches_enabled=true;b.settings.rocky_coast_enabled=true
				b._configure_noise();var field=b._extras[7];var a:Vector2=field.hive_node(Vector2i(-113,-103));var end:Vector2=field.hive_node(Vector2i(-112,-103));var baseline:Array=[];var elapsed:Array=[]
				for variant:bool in [false,true]:
					# Independent canonical host/cache state for every geometry variant.
					var host=Builder.new();host.settings=b.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);host.world_seed=seed_id;host._configure_noise()
					var g=Candidate.new() if variant else Structures.new();g.origin=Vector3(a.x,0,a.y);g._support_steps=Structures.support_grids();var started:int=Time.get_ticks_usec()
					g.conduit(host,a,end,24,.47,Color(.34,.28,.26));elapsed.append((Time.get_ticks_usec()-started)/1000.0)
					var attributes:Array=[g.vertices,g.normals,g.colors,g.uvs]
					if not variant:baseline=attributes
					else:
						for attribute in range(4):check(attributes[attribute]==baseline[attribute],"Exact complete conduit attribute "+str([seed_id,scale_value,mode,attribute]))
				cases.append({"seed":seed_id,"scale":scale_value,"mode":mode,"original_ms":elapsed[0],"candidate_ms":elapsed[1],"vertices":baseline[0].size()})
	for source:String in hashes:check(FileAccess.get_sha256(source)==hashes[source],"Stable sample-reuse source "+source)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_conduit_sample_reuse.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"production_change_kept":false,"scope":"Private exact conduit row/outer-ground/control reuse over three seeds/scales, full Alien, mixed Forest/overlay and coast-enabled configurations. Separate canonical hosts, full vertices/normals/colors/UV equality. Single-order micro timings are diagnostic, not a speed certificate; actual dense tile/native test still required."},"  "))
	print("CONDUIT_SAMPLE_REUSE_CHECK ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
