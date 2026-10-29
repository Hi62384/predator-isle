extends "res://tools/biome_extensions/check_all.gd"
func run()->void:
	for id in range(8):
		var b=make_builder(id);var sampler=b._extras[id]
		sampler.sample(0,0);var before:PackedFloat64Array=sampler._node(Vector2i.ZERO).duplicate()
		sampler.sample(3,5)
		check(before==sampler._node(Vector2i.ZERO),"Fractional publishing must not mutate canonical node "+str(id))
		var fresh=make_builder(id);var expected:float=fresh._extras[id].sample(0,0)
		check(sampler.sample(0,0)==expected,"Canonical height unchanged by fractional query "+str(id))
		var left:Array=b.build(Vector2i(20,20),64);var right:Array=fresh.build(Vector2i(21,20),64)
		for z in range(65):
			check(left[Mesh.ARRAY_VERTEX][z*65+64].y==right[Mesh.ARRAY_VERTEX][z*65].y,"Dense fractional mesh seam, independent samplers "+str(id))
			check(left[Mesh.ARRAY_NORMAL][z*65+64].is_equal_approx(right[Mesh.ARRAY_NORMAL][z*65]),"Dense fractional normal seam "+str(id))
	FileAccess.open("res://tools/biome_extensions/artifacts/check_sample_alias.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Cached node aliasing and dense fractional height/normal seams with independent samplers"},"\t"))
	print("SAMPLE_ALIAS ",checks," ",failures);quit(0 if failures.is_empty() else 1)
