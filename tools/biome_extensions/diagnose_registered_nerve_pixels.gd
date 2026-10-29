extends SceneTree
func _initialize()->void:
	var hashes:Dictionary={};var captures:Dictionary={};var comparisons:Array=[]
	for path:String in ["res://tools/biome_extensions/diagnose_registered_nerve_pixels.gd","res://tools/biome_extensions/render_registered_nerve_film.gd","res://tools/biome_extensions/render_all.gd","res://scripts/chunk_terrain.gd","res://shaders/biological_sampling.gdshaderinc","res://data/biological_material_sources.json","res://materials/biological_colors_v3.tres","res://.godot/extensions_render_registered_nerve_film.engine.log","res://.godot/extensions_render_registered_nerve_film.err.log","res://.godot/extensions_render_registered_nerve_film.out.log"]:hashes[path]=FileAccess.get_sha256(path)
	for seed_id:int in [73921,17]:
		var a_path:String="res://tools/biome_extensions/artifacts/registered_nerve_"+str(seed_id)+"_ground.png";var b_path:String="res://tools/biome_extensions/artifacts/nerve_film_packed_"+str(seed_id)+"_trial.png"
		var a:=Image.load_from_file(a_path);var b:=Image.load_from_file(b_path);assert(a.get_size()==b.get_size() and a.get_size()==Vector2i(1280,720))
		captures[a_path]=FileAccess.get_sha256(a_path);captures[b_path]=FileAccess.get_sha256(b_path)
		var changed:int=0;var over_two:int=0;var alpha_changed:int=0;var maximum:float=0;var examples:Array=[];var minimum:=Vector2i(1280,720);var greatest:=Vector2i(-1,-1)
		for y in range(720):
			for x in range(1280):
				var ac:Color=a.get_pixel(x,y);var bc:Color=b.get_pixel(x,y);var error:float=maxf(absf(ac.r-bc.r),maxf(absf(ac.g-bc.g),absf(ac.b-bc.b)));maximum=maxf(maximum,error)
				if ac.a!=bc.a:alpha_changed+=1
				if error>2.0/255:over_two+=1
				if error>0:
					changed+=1;minimum=Vector2i(mini(minimum.x,x),mini(minimum.y,y));greatest=Vector2i(maxi(greatest.x,x),maxi(greatest.y,y))
					if examples.size()<16:examples.append({"pixel":Vector2i(x,y),"actual":ac,"reference":bc,"maximum_rgb_error":error})
		comparisons.append({"seed":seed_id,"png_sha_equal":captures[a_path]==captures[b_path],"decoded_rgb_identical":changed==0,"changed_rgb_pixels":changed,"pixels_over_two_codes":over_two,"alpha_changed_pixels":alpha_changed,"maximum_rgb_error":maximum,"bounds_min":minimum,"bounds_max":greatest,"first_changed_examples":examples})
	for view:String in ["medium","aerial"]:
		var path:String="res://tools/biome_extensions/artifacts/registered_nerve_73921_"+view+".png";captures[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_registered_nerve_film_exact_failure.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":false,"failures":["The strict cross-run complete-image SHA predicate failed at seed17. Original failed run, source/log bytes and pixels preserved; this diagnostic does not relax or pass that predicate."],"source_sha256":hashes,"capture_sha256":captures,"comparisons":comparisons,"scope":"Post-failure full-image decoded RGB/alpha diagnostics for the two captured ground views. Counts and examples explain the failed cross-run SHA comparison; not adoption/full-scene acceptance or an excuse to exclude differing pixels."},"  "))
	print("REGISTERED_PIXEL_DIAG ",comparisons);quit()
