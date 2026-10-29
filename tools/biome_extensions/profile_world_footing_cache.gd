extends "res://tools/biome_extensions/check_all.gd"
const Candidate=preload("res://tools/biome_extensions/world_footing_cache_candidate.gd")
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/alien_infected_sampler.gd","res://tools/biome_extensions/world_footing_cache_candidate.gd","res://tools/biome_extensions/footing_sample_fixture.gd","res://tools/biome_extensions/profile_world_footing_cache.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var records:Array=[];var ratios:Array=[]
	for seed_id:int in [73921,17,92881]:
		for variant in range(2):
			for repeat in range(3):
				var pair:Dictionary={};var geometry:Array=[]
				for candidate:bool in ([false,true] if repeat%2==0 else [true,false]):
					var b=make_builder(7,seed_id);var field=b._extras[7];var a:Vector2=field.hive_node(Vector2i(-12,-11));var end:Vector2=field.hive_node(Vector2i(-11,-11))
					var g=Candidate.new() if candidate else Structures.new();g.origin=Vector3(a.x,0,a.y)
					g._support_steps=Structures.support_grids() if variant==0 else Structures.support_grids(128,96,20,7)
					var start:int=Time.get_ticks_usec();g.conduit(b,a,end,20,.4,Color(.34,.28,.26));var elapsed:float=(Time.get_ticks_usec()-start)/1000.0
					var arrays:Array=[g.vertices,g.normals,g.colors,g.uvs]
					if geometry.is_empty():geometry=arrays
					else:check(arrays==geometry,"Exact entire conduit geometry on default/fractional custom grids")
					pair[candidate]=elapsed
					records.append({"seed":seed_id,"variant":variant,"repeat":repeat,"candidate":candidate,"cpu_ms":elapsed,"support_cache_entries":g._support_heights.size(),"candidate_sample_misses":g.sample_misses if candidate else null,"candidate_hits":g.cache_hits if candidate else null})
				ratios.append(pair[true]/pair[false])
	# Cross-grid exact identity and cache-key overflow/fractional fallbacks.
	var builder=preload("res://tools/biome_extensions/footing_sample_fixture.gd").new();var reference=Structures.new();var test=Candidate.new()
	var grids:Array[float]=[2,4,8,16,2.5,128.0/96,1024]
	for index in range(grids.size()):
		var step:float=grids[index]
		for coordinate:Vector2i in [Vector2i(-12,8),Vector2i.ZERO,Vector2i(2147483647,-2147483647)]:
			var expected:float=reference._grid_height(builder,coordinate.x,coordinate.y,index,step);var actual:float=test._grid_height(builder,coordinate.x,coordinate.y,index,step)
			check(is_finite(expected) and expected==actual,"Exact finite grid sample/fallback "+str([coordinate,index,step]))
	ratios.sort()
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable experiment source "+path)
	var result:Dictionary={"passed":failures.is_empty(),"failures":failures,"checks":checks,"experimental_only":true,"production_change_kept":false,"records":records,"paired_median_ratio":ratios[ratios.size()/2],"source_sha256":hashes,"scope":"Eighteen alternating cold-builder pairs, three seeds, default/fractional custom grids and exact full-array comparisons. Candidate shares only exactly integral world-grid coordinates; no interpolation or canonical field change. Excludes actual worker/streaming/GPU/physics timings. Must show a meaningful measured benefit before any production adoption."}
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_world_footing_cache.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("WORLD_FOOTING_CACHE ",checks," failures=",failures," paired_median_ratio=",result.paired_median_ratio);quit(0 if failures.is_empty() else 1)
