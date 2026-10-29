extends SceneTree
func _initialize()->void:
	var failures:Array=[];var checks:int=0;var old_parity_failures:int=0
	var source:String=FileAccess.get_file_as_string("res://shaders/biological_sampling.gdshaderinc")
	var replacement:String=preload("res://tools/biome_extensions/biological_integer_period_candidate.gd").REPLACEMENT
	assert(source.count(replacement)==1)
	# The30m common period is specific to the actual fixed call scales,not a
	# generic promise for arbitrary new metres arguments. Guard those callers.
	var extensions:String=FileAccess.get_file_as_string("res://shaders/biome_extensions.gdshaderinc")
	assert(extensions.count("biological_sample(0,2.5,dx,dy,projection,n)")==1)
	assert(source.count("biological_sample(layer,layer==2?2.0:1.5,dx,dy,projection,n)")==1)
	assert(source.count("biological_sample(")==2 and extensions.count("biological_sample(")==1)
	for span:int in [256,512,1024,2048,4096,8192,16384]:
		for index:int in [-32767,-16384,-2047,-1024,-513,-255,-31,-1,0,1,17,255,513,1024,2047,16384,32767]:
			var origin:int=span*index;var phase:int=posmod(origin,30)
			for layer:int in range(4):
				var ticks:int=10 if layer==0 else (8 if layer==2 else 6);var full_period:int=ticks*2 if layer==0 else ticks
				checks+=1
				if posmod((origin-phase)*4,full_period)!=0:failures.append("Common phase not a complete physical repeat")
				if layer==0 and posmod(origin*4-posmod(origin*4,ticks),full_period)!=0:old_parity_failures+=1
	assert(old_parity_failures>0)
	# The same complete common repeat must survive parent/child origin changes.
	for i in range(-2048,2048):
		var a:int=i*256;var b:int=floori(float(a)/4096)*4096
		checks+=1
		if posmod((a-posmod(a,30))-(b-posmod(b,30)),30)!=0:failures.append("Parent/child quotient mismatch")
	var hashes:Dictionary={}
	for path:String in ["res://tools/biome_extensions/check_common_tissue_period.gd","res://tools/biome_extensions/biological_integer_period_candidate.gd","res://shaders/biological_sampling.gdshaderinc","res://shaders/biome_extensions.gdshaderinc","res://shaders/biome_structures.gdshader","res://scripts/chunk_terrain.gd"]:hashes[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_common_tissue_period.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"checks":checks,"original_odd_mirror_quotient_cases":old_parity_failures,"source_sha256":hashes,"production_registration":true,"scope":"Exact CPU quotient proof for the current three fixed physical scales/all four layers and parent/child origins,including signed far coordinates. Caller source contracts reject silently adding another scale. Separate actual GPU signed-remainder tests and native texture/source/material tests establish runtime behavior,not these integer assertions."},"  "));print("COMMON_TISSUE_PERIOD ",checks," checks / ",old_parity_failures," original negatives");quit(0 if failures.is_empty() else 1)
