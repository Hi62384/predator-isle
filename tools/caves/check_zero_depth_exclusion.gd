extends "res://tools/biome_extensions/check_all.gd"
const Definition=preload("res://scripts/caves/biome_definition.gd")
const Original=preload("res://tools/caves/references/magma_pre_zero_band_definition.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://scripts/caves/biome_definition.gd","res://tools/caves/references/magma_pre_zero_band_definition.gd","res://config/caves/biomes/magma_cave_definition.tres","res://config/caves/biomes/frozen_cave_definition.tres","res://config/caves/biomes/crystal_cave_definition.tres","res://config/caves/cave_biome_regions.tres"]:guards[path]=FileAccess.get_sha256(path)
	var bands:PackedFloat32Array=load("res://config/caves/cave_biome_regions.tres").depth_bands;var magma:Resource=load("res://config/caves/biomes/magma_cave_definition.tres");var old=Original.new();old.depth_preferences=magma.depth_preferences
	check(magma.exclude_zero_depth_bands,"Saved Magma explicitly excludes whole zero-weight depth band")
	var old_leaks:int=0;var zero_errors:int=0;var unchanged_errors:int=0
	for index in range(3201):
		var depth:float=float(index)/8;var value:float=magma.depth_preference(depth,bands)
		check(is_finite(value) and value>=0 and value<=1,"Bounded normalized depth preference")
		if depth<40:old_leaks+=int(old.depth_preference(depth,bands)>0);zero_errors+=int(value!=0)
		if depth>=70:unchanged_errors+=int(value!=old.depth_preference(depth,bands))
	check(old_leaks>0 and zero_errors==0 and unchanged_errors==0,"Actual old L1 interpolation leak reproduced;all L1 zero;L2centre and deeper preferences exact")
	check(magma.depth_preference(40,bands)==0 and magma.depth_preference(40.01,bands)>0 and magma.depth_preference(40.01,bands)<.000001,"Continuous zero-valued boundary and smooth ramp inside allowed band")
	for weights:PackedFloat32Array in [PackedFloat32Array([5,20,50,80,100]),PackedFloat32Array([100,80,40,5,0]),PackedFloat32Array([0,100,0,100,0])]:
		var actual=Definition.new();actual.depth_preferences=weights;var prior=Original.new();prior.depth_preferences=weights
		for index in range(801):
			var depth:float=float(index)*.5;check(actual.depth_preference(depth,bands)==prior.depth_preference(depth,bands),"Complete prior policy exact when explicit exclusion OFF")
		actual.exclude_zero_depth_bands=true
		for band in range(5):
			if weights[band]>0:continue
			for step in range(101):
				var depth:float=lerpf(bands[band],bands[band+1]-.0001,float(step)/100);check(actual.depth_preference(depth,bands)==0,"Every point of every explicitly excluded interior or outer band remains zero")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable zero-band exclusion source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_zero_depth_exclusion.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"old_leaking_samples":old_leaks,"zero_band_errors":zero_errors,"unchanged_deeper_samples_errors":unchanged_errors,"scope":"Explicit whole-zero-band policy on saved Magma;actual original shallow leak retained,full L1zero/continuous allowed-side ramp/exact deeper preference,all original OFF curves exact including Frozen and Crystal defaults. Other definitions retain prior policy unless explicitly opted in. Normal-world candidate survey and full physical return are separate."},"  "));print("ZERO_DEPTH_EXCLUSION ",checks," old_leaks=",old_leaks," failures=",failures);quit(0 if failures.is_empty() else 1)
