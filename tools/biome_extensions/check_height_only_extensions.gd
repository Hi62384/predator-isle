extends "res://tools/biome_extensions/check_all.gd"
const Candidate=preload("res://tools/biome_extensions/height_only_extensions_candidate.gd")
func run()->void:
	var hashes:Dictionary={}
	for source:String in ["res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_sampler.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://tools/biome_extensions/height_only_extensions_candidate.gd","res://tools/biome_extensions/check_height_only_extensions.gd"]:hashes[source]=FileAccess.get_sha256(source)
	var cases:Array=[];var keys:Array=["grass","forest","savanna","swamp","jungle","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS
	for seed_id:int in [73921,17,92881]:
		for owner:int in range(17):
			var old=Builder.new();var trial=Candidate.new();old.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);old.world_seed=seed_id
			for key:String in keys:old.settings.set(key+"_coverage",0)
			if owner<16:old.settings.set(keys[owner]+"_coverage",100)
			else:
				for key:String in keys:old.settings.set(key+"_coverage",20)
				old.settings.alien_infected.overlay_strength=.7
			trial.settings=old.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);trial.world_seed=seed_id;old._configure_noise();trial._configure_noise()
			for i in range(40):
				var p:=Vector2(i*7919%200000-100000,i*11939%200000-100000)
				check(old._get_height(p.x,p.y,false)==trial._get_height(p.x,p.y,false),"Exact height-only owner/seed probe")
				check(old._get_height(p.x,p.y)==trial._get_height(p.x,p.y),"Exact next published height after height-only probe")
				check(old._last_extras==trial._last_extras and old._last_swamp_water==trial._last_swamp_water,"Exact next published controls/water")
			for span:int in [256,4096]:
				old.chunk_size=span;trial.chunk_size=span;var coordinate:=Vector2i(-23,-24);var a:Array=old.build(coordinate,16);var bytes:PackedByteArray=old.built_extension_data
				check(a==trial.build(coordinate,16),"Complete near/far terrain attribute arrays remain exact")
				check(bytes==trial.built_extension_data and old.built_extension_mask==trial.built_extension_mask and old.built_extension_rows==trial.built_extension_rows,"Complete atlas payload remains exact")
				check(old.build_swamp_water(a,16)==trial.build_swamp_water(a,16),"Complete water surface arrays remain exact")
			cases.append({"seed":seed_id,"owner":keys[owner] if owner<16 else "sixteen_owner_mix_plus_alien_overlay"})
	for source:String in hashes:check(FileAccess.get_sha256(source)==hashes[source],"Stable height-only trial source "+source)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_height_only_extensions.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"production_change_kept":false,"scope":"Private extension height-only publication trial: all sixteen individual owners and mixed/overlay configuration, three seeds, height-only probes followed by exact published height/control/water, complete near/far terrain/normal/metadata/water arrays. Height-only calls do not promise publication of water/semantic state. Dense structure equality and native timing remain separate."},"  "))
	print("HEIGHT_ONLY_EXTENSIONS_CHECK ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
