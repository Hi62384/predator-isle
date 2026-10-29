extends "res://tools/biome_extensions/check_all.gd"
const Golden=preload("res://tools/biome_extensions/reference_pre_conduit_memo_structures.gd")
const Candidate=preload("res://tools/biome_extensions/conduit_geometry_cache_candidate.gd")
func digest(value)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(value));return hash.finish().hex_encode()
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://tools/biome_extensions/reference_pre_conduit_memo_structures.gd","res://scripts/biome_extension_structures.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/alien_infected_sampler.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_carapace_geometry.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/biome_extension_settings.gd","res://tools/biome_extensions/conduit_geometry_cache_candidate.gd","res://tools/biome_extensions/profile_conduit_geometry_cache.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var records:Array=[];var ratios:Array=[];var structure_ratios:Array=[]
	var admission_path:String="res://tools/biome_extensions/artifacts/check_carapace_admission.json";hashes[admission_path]=FileAccess.get_sha256(admission_path)
	var admission=JSON.parse_string(FileAccess.get_file_as_string(admission_path));check(admission.passed,"Actual default-admitted fixtures")
	for item:Dictionary in admission.cases:
		if int(item.habit)!=2:continue
		var seed_id:int=item.seed
		for repeat in range(3):
			var pair:Dictionary={};var expected:Array=[]
			for candidate:bool in ([false,true] if repeat%2==0 else [true,false]):
				var b=make_builder(7,seed_id);var p:=Vector2(item.position[0],item.position[1]);var parent:=Vector2i(floori(p.x/4096),floori(p.y/4096))
				var guard=preload("res://scripts/terrain_feature_meshes.gd").new();guard.builder=b;var leaves:Array[Vector3i]=[Vector3i(parent.x,parent.y,4096)]
				for z in range(2):
					for x in range(2):leaves.append(Vector3i(parent.x*2+x,parent.y*2+z,2048))
				leaves.append(Vector3i(parent.x,parent.y,4096))
				var terrain_ms:float=0;var structures_ms:float=0;var signatures:Array=[];var leaf_records:Array=[]
				for leaf:Vector3i in leaves:
					b.chunk_size=leaf.z;var coordinate:=Vector2i(leaf.x,leaf.y)
					var start:int=Time.get_ticks_usec();var arrays:Array=b.build(coordinate,16);var middle:int=Time.get_ticks_usec()
					var g=Candidate.new() if candidate else Golden.new();var structures:Array=g.build(b,coordinate,PackedFloat64Array(),guard.portal_sites);var end:int=Time.get_ticks_usec()
					terrain_ms+=(middle-start)/1000.0;structures_ms+=(end-middle)/1000.0
					# Hashing is deliberately outside the numeric-generation timers.
					signatures.append(digest([arrays,b.built_extension_data,b.built_extension_rows,b.built_extension_mask,b.build_swamp_water(arrays,16),structures]))
					leaf_records.append({"leaf":leaf,"terrain_ms":(middle-start)/1000.0,"structures_ms":(end-middle)/1000.0})
				if expected.is_empty():expected=signatures
				else:check(signatures==expected,"Exact complete terrain/control/water/structure outputs through split/rejoin sequence")
				var memo:Dictionary=b.get_meta(Candidate.META_KEY,{})
				if candidate:check(memo.hits>=6 and memo.bytes<=8*1024*1024 and memo.entries.size()<=32,"Actual warm reuse inside strict numeric cache bounds")
				pair[candidate]={"terrain_ms":terrain_ms,"structures_ms":structures_ms}
				records.append({"seed":seed_id,"repeat":repeat,"candidate":candidate,"terrain_ms":terrain_ms,"structures_ms":structures_ms,"combined_ms":terrain_ms+structures_ms,"cache_hits":memo.get("hits",0),"cache_misses":memo.get("misses",0),"cache_numeric_bytes":memo.get("bytes",0),"leaves":leaf_records})
			ratios.append((pair[true].terrain_ms+pair[true].structures_ms)/(pair[false].terrain_ms+pair[false].structures_ms));structure_ratios.append(pair[true].structures_ms/pair[false].structures_ms)
	ratios.sort();structure_ratios.sort()
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable performance experiment source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_conduit_geometry_cache.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"checks":checks,"experimental_only":true,"production_change_kept":false,"records":records,"paired_median_combined_ratio":ratios[ratios.size()/2],"paired_median_structure_ratio":structure_ratios[structure_ratios.size()/2],"source_sha256":hashes,"scope":"Nine alternating cold-builder pairs, three seeds, actual 4096m parent/four 2048m children/rejoined parent numeric-generation sequence. Exact full terrain, water, control atlas and structure hashes. Warm conduit reuse is part of the explicit workload, not a claimed cold-start gain. Excludes actual workers, features, resource upload, physics, GPU and uninterrupted streaming."},"  "))
	print("CONDUIT_GEOMETRY_CACHE_PROFILE ",checks," failures=",failures," paired_median_combined_ratio=",ratios[ratios.size()/2]," structure_ratio=",structure_ratios[structure_ratios.size()/2]);quit(0 if failures.is_empty() else 1)
