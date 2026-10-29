extends SceneTree
func _initialize()->void:
	var checks:int=0;var negatives:int=0;var hashes:Dictionary={}
	for path:String in ["res://tools/biome_extensions/check_vertex_tissue_phase_math.gd","res://tools/biome_extensions/biological_vertex_phase_candidate.gd","res://shaders/biological_sampling.gdshaderinc","res://shaders/biome_extensions.gdshaderinc","res://shaders/biome_structures.gdshader","res://shaders/terrain_biomes.gdshader"]:hashes[path]=FileAccess.get_sha256(path)
	# Exact integer reference; independent of candidate-generated shader text.
	for ticks:int in [6,8,10]:
		for size:int in [256,512,1024,2048,4096,8192,16384]:
			for tile:int in [-2047,-1024,-513,-255,-31,-1,0,1,17,255,513,1024,2047]:
				for offset:int in [-119,-41,-1,0,1,37,119]:
					var q:int=tile*size*4+offset
					var remainder:int=((q%120)+120)%120
					var original:int=((q%ticks)+ticks)%ticks
					assert(remainder>=0 and remainder<120);checks+=1
					assert((q-remainder)%ticks==0);checks+=1
					if ticks==10:
						assert((q-remainder)%(ticks*2)==0);checks+=1
						if (q-original)%(ticks*2)!=0:negatives+=1
	assert(negatives>0)
	var source:String=FileAccess.get_file_as_string("res://shaders/biological_sampling.gdshaderinc")
	assert(source.contains("layer==2?2.0:1.5"))
	assert(FileAccess.get_file_as_string("res://shaders/biome_extensions.gdshaderinc").contains("biological_sample(0,2.5,"))
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path])
	FileAccess.open("res://tools/biome_extensions/artifacts/check_vertex_tissue_phase_math.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"checks":checks,"legacy_parity_negatives":negatives,"source_sha256":hashes,"production_registration":false,"scope":"Private exact common-period proof for all three current physical scales, signed chunk origins, and quarter-metre model-origin offsets. Not arbitrary configurable texture scales, GPU filtering, memory, performance or adoption."},"  "))
	print("VERTEX_TISSUE_PHASE_MATH ",checks," checks, ",negatives," legacy parity negatives");quit()
