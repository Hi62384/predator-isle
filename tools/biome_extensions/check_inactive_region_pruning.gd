extends "res://tools/biome_extensions/check_all.gd"
func run()->void:
	preload("res://tools/biome_extensions/inactive_region_patch_candidate.gd").apply()
	var maximum_delta:float=0;var saturated:int=0;var mesh_pairs:int=0
	for seed_id:int in [73921,17,92881]:
		for family:int in range(8):
			var old=make_builder(family,seed_id);var candidate=make_builder(family,seed_id)
			candidate._extras[family].skip_saturated_regions=true
			var rng:=RandomNumberGenerator.new();rng.seed=seed_id+family*101
			for sample:int in range(192):
				var p:=Vector2(rng.randi_range(-10000,10000)*16,rng.randi_range(-10000,10000)*16)
				if sample%3==1:p+=Vector2(3.25,7.75)
				var region:float=candidate._extras[family].region(p)
				if smoothstep(.25,.75,region-floorf(region))==1:saturated+=1
				old._extras[family].sample(p.x,p.y);candidate._extras[family].sample(p.x,p.y)
				for channel:int in range(5):
					var delta:float=absf(old._extras[family].state[channel]-candidate._extras[family].state[channel]);maximum_delta=maxf(maximum_delta,delta)
					check(delta<1e-9,"Canonical sample/state differs by less than one nanometre "+str([seed_id,family,p,channel]))
			var expected:Array=old.build(Vector2i(20,20),64);var actual:Array=candidate.build(Vector2i(20,20),64)
			check(var_to_bytes(expected)==var_to_bytes(actual),"Complete uploaded mesh arrays remain byte-exact "+str([seed_id,family]))
			check(old.built_extension_data==candidate.built_extension_data,"All material-control bytes unchanged "+str([seed_id,family]))
			check(old.built_alien_tissue_flow==candidate.built_alien_tissue_flow,"All tissue-coordinate bytes unchanged "+str([seed_id,family]));mesh_pairs+=1
	check(saturated>0,"Positive exact endpoint population across all families")
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://scripts/biome_extension_sampler.gd","res://scripts/alien_infected_sampler.gd","res://scripts/terrain_mesh_builder.gd"]:guards[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_inactive_region_pruning.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"maximum_double_delta":maximum_delta,"saturated_queries":saturated,"complete_mesh_pairs":mesh_pairs,"source_sha256":guards,"scope":"Independent unchanged full-evaluation branch versus exact-endpoint skipping;24 full64grid mesh/control/flow byte comparisons across eight families and three seeds. Not native timing or reference-art acceptance."},"  "))
	print("INACTIVE_REGION_PRUNING ",checks," pairs=",mesh_pairs," max_delta=",maximum_delta," failures=",failures);quit(0 if failures.is_empty() else 1)
