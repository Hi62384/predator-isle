extends "res://tools/biome_extensions/check_all.gd"
func middle(values:Array)->float:values.sort();return values[values.size()/2]
func run()->void:
	var results:Dictionary={"note":"Isolated numerical work; fresh sampler for every mesh repeat. Same coordinates and settings except ownership. No rendering concurrently. Milliseconds, not FPS.","cases":{}}
	for family_id in range(-1,8):
		var key:String="grass" if family_id<0 else TerrainSettings.EXTENSION_KEYS[family_id];var cases:Array=[]
		for item:Array in [[256,64],[256,128],[16384,64]]:
			var times:Array=[]
			for repeat_id in range(3 if item[0]==256 else 1):
				var b=make_builder(maxi(family_id,0))
				if family_id<0:b.settings.quarry_coverage=0;b.settings.grass_coverage=100;b._configure_noise()
				b.chunk_size=item[0];var start:int=Time.get_ticks_usec();b.build(Vector2i(2,2),item[1]);times.append((Time.get_ticks_usec()-start)/1000.0)
			cases.append({"chunk_metres":item[0],"resolution":item[1],"repeats_ms":times,"median_ms":middle(times)})
		results.cases[key]=cases;print("EXTENSION_CPU ",key," ",cases)
	FileAccess.open("res://tools/biome_extensions/artifacts/benchmark_cpu.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"));quit()
