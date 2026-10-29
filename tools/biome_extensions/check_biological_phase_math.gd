extends SceneTree
func signed_remainder(q:int,period:int)->int:
	var r:int=absi(q)%period
	return period-r if q<0 and r>0 else r
func _initialize()->void:
	var hashes:Dictionary={};var failures:Array=[];var checks:int=0;var original_odd_parity:int=0
	for path:String in ["res://shaders/biological_sampling.gdshaderinc","res://tools/biome_extensions/check_biological_phase_math.gd","res://tools/biome_extensions/biological_period_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var candidate:String=preload("res://tools/biome_extensions/biological_period_candidate.gd").apply_to(FileAccess.get_file_as_string("res://shaders/biological_sampling.gdshaderinc"))
	assert(candidate.contains("int period=int(round(metres*4.0))*2;"))
	# All declared inputs fit the shader's signed 32-bit quarter-metre key.
	# Compare exact integer quotient parity, independent of floating tolerance.
	for base_ticks:int in range(1,33):
		for size:int in [256,512,1024,2048,4096,8192,16384]:
			for tile:int in [-2047,-1024,-513,-255,-31,-1,0,1,17,255,513,1024,2047]:
				var q:int=tile*size*4;assert(q>-2147483648 and q<2147483647)
				var corrected:int=signed_remainder(q,base_ticks*2);var original:int=signed_remainder(q,base_ticks)
				checks+=3
				if corrected<0 or corrected>=base_ticks*2:failures.append("Signed remainder out of range")
				if (q-corrected)%(base_ticks*2)!=0:failures.append("Mirrored phase does not retain even integer UV quotient")
				if (corrected-original)%base_ticks!=0:failures.append("Ordinary repeat differs by a non-integer UV shift")
				if (q-original)%(base_ticks*2)!=0:original_odd_parity+=1
	assert(original_odd_parity>0,"Original mirrored-phase parity defect must be detected")
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path])
	FileAccess.open("res://tools/biome_extensions/artifacts/check_biological_phase_math.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":hashes,"production_registration":false,"original_odd_parity_cases":original_odd_parity,"scale_quarter_ticks":[1,32],"chunk_sizes_m":[256,512,1024,2048,4096,8192,16384],"scope":"PRIVATE candidate exact integer phase arithmetic across signed valid chunk origins and quarter-metre scales .25–8m. Mirrored UV quotients remain even; ordinary repeating layers differ only by integer UV shifts. Original one-unit parity failures required. The production sampler is restored; this does not prove adoption, floating interpolation, native compilation memory, filtering or whole-scene rendering."},"  "))
	print("BIOLOGICAL_PHASE_MATH ",checks," checks; original odd-parity negatives=",original_odd_parity," failures=",failures);quit(0 if failures.is_empty() else 1)
