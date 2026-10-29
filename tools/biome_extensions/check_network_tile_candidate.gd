extends "res://tools/biome_extensions/check_all.gd"
const Candidate=preload("res://tools/biome_extensions/network_tile_candidate.gd")
const Original=preload("res://tools/biome_extensions/reference_pre_network_tiles_alien_sampler.gd")
var output_basename:String="check_network_tile_candidate"
var private_candidate_only:bool=true
var extra_guards:Array[String]=[]
func candidate_builder(seed_id:int,scale_value:float,strength:float,partial:bool=false):
	var b=make_builder(7,seed_id);b.settings.alien_infected.feature_scale=scale_value;b.settings.alien_infected.nerve_fibre_height=strength
	if partial:b.settings.alien_infected_coverage=0;b.settings.forest_coverage=100;b.settings.alien_infected.overlay_strength=.8
	b._configure_noise();var field=Original.new();field.configure(b.settings.alien_infected,seed_id,b,7);b._extras[7]=field;return b
func install(b):
	var field=Candidate.new();field.configure(b.settings.alien_infected,b.world_seed,b,7);b._extras[7]=field;return field
func lifecycle_checks(_b,_reference)->void:pass
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_sampler.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/network_tile_candidate.gd","res://tools/biome_extensions/check_network_tile_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)
	for path:String in extra_guards+["res://scripts/biome_extension_settings.gd","res://tools/biome_extensions/reference_pre_network_tiles_alien_sampler.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		for scale_value:float in [.2,1,2]:
			var actual=candidate_builder(seed_id,scale_value,24);var trial=install(actual);var expected=candidate_builder(seed_id,scale_value,24);var original=expected._extras[7]
			var points:Array[Vector2]=[];var tile_step:float=256*scale_value;var hive_step:float=4096*scale_value
			for i in range(700):points.append(Vector2(i*7919%1600000-800000,i*11939%1600000-800000))
			for i in range(-5,6):
				for delta:float in [-.02,0,.02]:
					points.append(Vector2(i*tile_step+delta,(i+1)*tile_step-delta));points.append(Vector2(i*hive_step+delta,(i-1)*hive_step-delta))
			var node:Vector2=original.hive_node(Vector2i(-12,-11));var edges:PackedVector2Array=original.network_edges(Vector2i(-12,-11))
			for i in range(200):
				points.append(node+Vector2(i*16-1600,i%17*16-128)*scale_value)
				points.append(edges[1].lerp(edges[5],float(i)/199)+Vector2(.01,-.01))
			for p:Vector2 in points:
				check(trial.network(p)==original.network(p),"Exact original public network after conservative tile pruning")
				check(trial.nerve_fibre_relief(p)==original.nerve_fibre_relief(p),"Exact nearest/second-path fibre isolation")
				check(trial.sample(p.x,p.y)==original.sample(p.x,p.y) and trial.state==original.state,"Exact complete field and material controls")
				check(trial._query_tiles.size()<=512 and trial._tile_probes.size()<=512,"Bounded worker-local query/admission tiles")
			check(trial.probe_resets>0 and trial.tile_builds>0 and trial.uncached_queries>0,"Exercise bounded admission eviction, sparse fallback and actual dense tiles")
			points.reverse();trial._network_cache.clear();original._network_cache.clear();trial._nodes.clear();original._nodes.clear()
			for p:Vector2 in points:check(trial.nerve_fibre_relief(p)==original.nerve_fibre_relief(p) and trial.network(p)==original.network(p),"Reverse query/eviction order exactness")
			lifecycle_checks(actual,expected)
			for partial:bool in [false,true]:
				for strength:float in [0,24,40]:
					var a=candidate_builder(seed_id,scale_value,strength,partial);var accelerated=install(a);var b=candidate_builder(seed_id,scale_value,strength,partial)
					for size:int in [256,2048,16384]:
						a.chunk_size=size;b.chunk_size=size;var cell:=Vector2i(floori(node.x/size),floori(node.y/size));var arrays:Array=a.build(cell,16);var atlas:PackedByteArray=a.built_extension_data.duplicate();var water:Array=a.build_swamp_water(arrays,16);var original_arrays:Array=b.build(cell,16)
						check(arrays==original_arrays and atlas==b.built_extension_data and water==b.build_swamp_water(original_arrays,16),"Exact full near/far terrain/normals/atlas/water: zero/default/max and Forest overlay")
						if size==256 and not partial and strength==24:check(build_structures(a,cell)==build_structures(b,cell),"Exact complete normal-guard production structures")
					check(accelerated._query_tiles.size()<=512,"Bounded cache through complete builders")
			trial.configure(actual.settings.alien_infected,seed_id+1,actual,7);check(trial._query_tiles.is_empty() and trial._tile_probes.is_empty() and trial.tile_builds==0 and trial.tile_hits==0 and trial.uncached_queries==0,"Reconfigure clears used tile cache")
			var fresh=candidate_builder(seed_id+1,scale_value,24)
			for p:Vector2 in points.slice(0,64):check(trial.network(p)==fresh._extras[7].network(p) and trial.nerve_fibre_relief(p)==fresh._extras[7].nerve_fibre_relief(p),"Reused sampler equals fresh seed")
			cases.append({"seed":seed_id,"scale":scale_value,"points":points.size(),"maximum_tiles":512,"full_array_pairs":18,"partial_Forest_overlay":true})
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable private query study source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/"+output_basename+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"private_candidate_only":private_candidate_only,"scope":"Exact public network, raw fibres, full field/controls and near/far builder arrays against current production across three seeds/scales, query/hive boundaries, path transitions, ±800km probes, eviction/reverse order, zero/default/max fibres, partial Forest overlays, normal-guard structures and used-sampler reconfiguration. No production adoption or speed/streaming claim."},"  "))
	print("NETWORK_TILE_CANDIDATE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
