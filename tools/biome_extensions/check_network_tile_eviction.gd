extends "res://tools/biome_extensions/check_production_network_tiles.gd"
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/reference_pre_network_tiles_alien_sampler.gd","res://tools/biome_extensions/check_network_tile_candidate.gd","res://tools/biome_extensions/check_production_network_tiles.gd","res://tools/biome_extensions/check_network_tile_eviction.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		for scale_value:float in [.2,1,2]:
			var b=candidate_builder(seed_id,scale_value,24);var actual=install(b);var original_builder=candidate_builder(seed_id,scale_value,24);var reference=original_builder._extras[7];var step:float=256*scale_value;var maximum_tiles:int=0;var metadata_bytes:int=0;var reset_observed:bool=false;var previous_size:int=0
			for index in range(600):
				# Four DISTINCT uncached queries admit every tile. This deliberately
				# exceeds the retained geometry cap, unlike random sparse probes.
				var p:=Vector2((index%30-15+.31)*step,(index/30-10+.37)*step)
				for offset in range(4):
					var q:Vector2=p+Vector2(offset*.75,offset*.5)*scale_value
					check(actual.nerve_fibre_relief(q)==reference.nerve_fibre_relief(q) and actual.network(q)==reference.network(q),"Exact original network/fibres through admitted tile eviction")
				var size:int=actual._query_tiles.size();maximum_tiles=maxi(maximum_tiles,size)
				if size<previous_size:reset_observed=true
				previous_size=size;check(size<=512 and actual._tile_probes.size()<=512,"Both retained geometry and admission maps bounded")
				metadata_bytes=maxi(metadata_bytes,var_to_bytes([actual._query_tiles,actual._tile_probes]).size())
			check(reset_observed and maximum_tiles==512 and actual.tile_builds>=600,"Actual full admitted-geometry cache rollover exercised")
			cases.append({"seed":seed_id,"scale":scale_value,"admitted_tiles":actual.tile_builds,"maximum_retained_tiles":maximum_tiles,"maximum_serialized_metadata_bytes":metadata_bytes,"geometry_reset_observed":reset_observed})
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable production tile-eviction source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_network_tile_eviction.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":hashes,"cases":cases,"scope":"Six hundred densely admitted tiles per seed/scale, actual 512-entry geometry rollover and bounded admission map, exact frozen-original network and fibres throughout. Serialized retained metadata is measured separately from allocator/process memory. Not native streaming or a speed measurement."},"  "))
	print("NETWORK_TILE_EVICTION ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
