extends "res://tools/biome_extensions/render_margin_lod_shores.gd"
var worker_cache_proofs:Array=[]
func settle()->bool:
	var complete:bool=await super.settle()
	if not complete:return false
	assert(not terrain._idle_builders.is_empty(),"Actual completed worker builders required")
	var entries:int=0;var serialized_bytes:int=0;var capacities:Array=[]
	# Only idle builders are inspected; no data is read concurrently with a job.
	for b in terrain._idle_builders:
		assert(b.coastal_structure_height_cache_enabled and b._coast!=null and b._extras[7]!=null)
		var expected:int=65536 if b.chunk_size>=8192 else 8192
		assert(b._normal_height_cache_capacity==expected and b._normal_height_cache.size()<=expected)
		entries+=b._normal_height_cache.size();serialized_bytes+=var_to_bytes(b._normal_height_cache).size();capacities.append(expected)
	worker_cache_proofs.append({"seed":terrain.world_seed,"revision":terrain.committed_revision,"idle_builders":terrain._idle_builders.size(),"last_tile_capacities":capacities,"retained_entries":entries,"serialized_cache_bytes":serialized_bytes})
	return true
func run()->void:
	for path:String in ["res://tools/biome_extensions/render_coastal_cache_policy.gd","res://materials/biological_colors_v3.tres","res://materials/biological_color_nerve_v3.res","res://materials/biological_color_mycelium_v2.res","res://materials/biological_color_carapace.res","res://materials/biological_color_membrane.res"]:hashes[path]=FileAccess.get_sha256(path)
	await super.run()
	# The parent's quit request is deferred until the end of the current frame.
	# Retain its complete proof and bind the new actual idle-worker budget data.
	var report=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/render_margin_lod_shores.json"))
	assert(report.passed and report.captures.size()==9 and worker_cache_proofs.size()>=12)
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path])
	report["worker_cache_proofs"]=worker_cache_proofs
	report["scope"]+=" Additional current policy proof inspects only actual idle completed worker builders after every committed cut, requiring the registered coarse/fine capacities and retained-entry bounds. Current v3 tissue resources are source-bound. Settled timings are not an isolated performance comparison."
	FileAccess.open("res://tools/biome_extensions/artifacts/render_coastal_cache_policy.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("COASTAL_CACHE_NATIVE_DONE ",worker_cache_proofs.size()," actual idle-worker checks")
